@preconcurrency import Foundation
@preconcurrency import UserNotifications
import SwiftUI

/// Global notification manager that handles all notification scheduling with strict monthly limits and controls.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    // MARK: - Published Properties
    @Published var preferences = NotificationPreferences()
    @Published var isEnabled = false
    @Published var dailyNotificationCount = 0
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    // MARK: - Constants
    private let maxMonthlyNotifications = 1  // Hard cap: 1 notification per month
    private let monthlyScheduleDay = 1       // First day of month
    private let monthlyScheduleHour = 10     // 10 AM local time
    private let monthlyScheduleMinute = 30
    private let preferredWindowStartHour = 9
    private let preferredWindowEndHour = 18
    private let quietHoursStart = 22 // 10 PM
    private let quietHoursEnd = 8    // 8 AM
    
    // MARK: - Private Properties
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private var monthlyResetTimer: Timer?
    private var midnightTimer: Timer?
    
    // UserDefaults Keys
    private let monthlyNotificationDateKey = "last_monthly_notification_date"
    private let monthlyNotificationCountKey = "monthly_notification_count"
    private let preferencesKey = "notification_preferences"
    private let pendingNotificationsKey = "pending_notifications_queue"
    private let deliveryPolicyUserInfoKey = "snapchef_delivery_policy"
    
    private init() {
        loadPreferences()
        checkNotificationAuthorization()
        setupMonthlyResetTimer()
        resetMonthlyCountIfNeeded()
        setupMidnightTimer()
        Task { @MainActor in
            await updatePendingNotifications()
            await purgeLegacyNotificationSchedules()
        }
    }
    
    // MARK: - Authorization
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            isEnabled = granted
            
            if granted {
                await setupNotificationCategories()
                await updatePendingNotifications()
            }
            
            return granted
        } catch {
            print("❌ Notification permission error: \(error)")
            return false
        }
    }
    
    private func checkNotificationAuthorization() {
        Task { @Sendable @MainActor in
            let settings = await notificationCenter.notificationSettings()
            isEnabled = settings.authorizationStatus == .authorized
        }
    }

    /// App-launch bootstrap that does not prompt. Schedules monthly notifications only if already authorized.
    func bootstrapMonthlyScheduleIfAuthorized() async {
        let settings = await notificationCenter.notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        isEnabled = isAuthorized
        guard isAuthorized else { return }

        await setupNotificationCategories()
        scheduleMonthlyEngagementNotification()
    }
    
    // MARK: - Core Notification Scheduling
    
    /// Schedule a notification with policy-aware delivery controls.
    func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        subtitle: String? = nil,
        category: NotificationCategory,
        userInfo: [String: Any] = [:],
        trigger: UNNotificationTrigger?,
        priority: NotificationPriority = .medium,
        deliveryPolicy: NotificationDeliveryPolicy = .transactionalNudge
    ) -> Bool {
        guard isEnabled else {
            print("🔕 Notifications disabled - skipping: \(title)")
            return false
        }
        
        // Check if notification type is enabled in preferences
        guard isNotificationTypeEnabled(category) else {
            print("🔕 Notification type disabled in preferences: \(category.rawValue)")
            return false
        }
        
        let effectivePolicy = normalizedDeliveryPolicy(deliveryPolicy)
        let resolvedTrigger: UNNotificationTrigger?
        var monthlyReservationDate: Date?

        switch effectivePolicy {
        case .monthlyEngagement:
            let monthlyTrigger = resolveTriggerForMonthlyPolicy(trigger: trigger, category: category)
            resolvedTrigger = monthlyTrigger
            let targetDate = notificationTargetDate(for: monthlyTrigger)

            // Reserve the monthly slot up front to prevent duplicate scheduling from concurrent calls.
            guard reserveMonthlySlot(for: targetDate) else {
                print("📅 Monthly notification already reserved for \(targetDate) - queuing: \(title)")
                queueNotificationForSmartSelection(
                    identifier: identifier,
                    title: title,
                    body: body,
                    category: category,
                    priority: priority,
                    trigger: trigger
                )
                return false
            }
            monthlyReservationDate = targetDate
        case .transactionalCritical:
            fallthrough
        case .transactionalNudge, .transactional:
            // SnapChef policy: all pushes are monthly-capped and normalized into a single monthly window.
            let monthlyTrigger = resolveTriggerForMonthlyPolicy(trigger: trigger, category: category)
            resolvedTrigger = monthlyTrigger
            let targetDate = notificationTargetDate(for: monthlyTrigger)
            guard reserveMonthlySlot(for: targetDate) else {
                print("📅 Monthly notification already reserved for \(targetDate) - queuing: \(title)")
                queueNotificationForSmartSelection(
                    identifier: identifier,
                    title: title,
                    body: body,
                    category: category,
                    priority: priority,
                    trigger: trigger
                )
                return false
            }
            monthlyReservationDate = targetDate
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.subtitle = subtitle ?? ""
        content.sound = .default
        content.categoryIdentifier = category.rawValue
        var mergedUserInfo = userInfo
        mergedUserInfo[deliveryPolicyUserInfoKey] = effectivePolicy.rawValue
        content.userInfo = mergedUserInfo
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: resolvedTrigger
        )
        
        notificationCenter.add(request) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    if let monthlyReservationDate {
                        self.releaseMonthlyReservation(for: monthlyReservationDate)
                    }
                    print("❌ Failed to schedule notification: \(error)")
                } else {
                    await self.updatePendingNotifications()
                    print("✅ Scheduled \(effectivePolicy.rawValue) notification: \(title)")
                }
            }
        }
        
        return true
    }
    
    /// Convenience API that routes through monthly-capped delivery.
    func scheduleImmediateNotification(
        identifier: String,
        title: String,
        body: String,
        subtitle: String? = nil,
        category: NotificationCategory,
        userInfo: [String: Any] = [:]
    ) -> Bool {
        return scheduleNotification(
            identifier: identifier,
            title: title,
            body: body,
            subtitle: subtitle,
            category: category,
            userInfo: userInfo,
            trigger: nil,
            priority: .high,
            deliveryPolicy: .transactionalCritical
        )
    }
    
    // MARK: - Challenge Notifications
    
    @discardableResult
    func scheduleJoinedChallengeReminders() -> Bool {
        guard preferences.challengeReminders else { return false }
        
        let joinedChallenges = GamificationManager.shared.activeChallenges
            .filter { $0.isJoined }
            .sorted { $0.endDate < $1.endDate }

        guard let topChallenge = joinedChallenges.first else {
            return false
        }

        return scheduleNotification(
            identifier: "challenge_monthly_checkin",
            title: "🏆 Monthly Challenge Check-In",
            body: "Keep momentum on \"\(topChallenge.title)\" and lock in your points this month.",
            category: .challengeReminder,
            userInfo: [
                "challengeId": topChallenge.id,
                "challengeType": topChallenge.type.rawValue
            ],
            trigger: nil,
            priority: .medium,
            deliveryPolicy: .monthlyEngagement
        )
    }
    
    // MARK: - Streak Notifications
    
    func scheduleDailyStreakReminder() {
        scheduleMonthlyStreakReminder()
    }

    func scheduleMonthlyStreakReminder() {
        guard preferences.streakReminders else { return }

        _ = scheduleNotification(
            identifier: "monthly_streak_reminder",
            title: "🔥 Monthly Streak Check-In",
            body: "Quick check-in: keep your cooking streak alive this month.",
            category: .streakReminder,
            userInfo: [:],
            trigger: nil,
            priority: .medium,
            deliveryPolicy: .monthlyEngagement
        )
    }

    func scheduleMonthlyEngagementNotification() {
        let challengeEnabled = preferences.challengeReminders
        let streakEnabled = preferences.streakReminders

        guard challengeEnabled || streakEnabled else { return }
        
        let preferredDate = nextMonthlyScheduleDate(
            preferredHour: preferences.streakReminderTime.hour,
            preferredMinute: preferences.streakReminderTime.minute
        )
        
        // Keep the current month schedule intact; don't replace it with a next-month candidate.
        guard canSendMonthlyNotification(for: preferredDate) else {
            print("📅 Monthly slot already reserved for \(preferredDate); preserving existing notification.")
            return
        }

        if challengeEnabled {
            let didScheduleChallenge = scheduleJoinedChallengeReminders()
            if didScheduleChallenge {
                return
            }
        }

        if streakEnabled {
            scheduleMonthlyStreakReminder()
        }
    }
    
    // MARK: - Notification Bundling
    
    func scheduleBundledNotification(
        bundleId: String,
        notifications: [(title: String, body: String)],
        category: NotificationCategory,
        trigger: UNNotificationTrigger?,
        deliveryPolicy: NotificationDeliveryPolicy = .transactionalNudge
    ) -> Bool {
        guard !notifications.isEmpty else { return false }
        
        let bundledTitle: String
        var bundledBody: String
        
        if notifications.count == 1 {
            bundledTitle = notifications[0].title
            bundledBody = notifications[0].body
        } else {
            bundledTitle = "\(notifications.count) Updates"
            bundledBody = notifications.prefix(3).map { $0.body }.joined(separator: " • ")
            if notifications.count > 3 {
                bundledBody += " and \(notifications.count - 3) more..."
            }
        }
        
        return scheduleNotification(
            identifier: bundleId,
            title: bundledTitle,
            body: bundledBody,
            category: category,
            userInfo: ["bundled_count": notifications.count],
            trigger: trigger,
            deliveryPolicy: deliveryPolicy
        )
    }
    
    // MARK: - Notification Management
    
    func cancelNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        Task { @MainActor in
            await updatePendingNotifications()
        }
    }
    
    func cancelChallengeNotifications() {
        Task { @MainActor in
            let pending = await notificationCenter.pendingNotificationRequests()
            let challengeIdentifiers = pending
                .filter { $0.identifier.contains("challenge_") }
                .map { $0.identifier }
            
            notificationCenter.removePendingNotificationRequests(withIdentifiers: challengeIdentifiers)
            
            // Reset challenge notification count
            userDefaults.set(0, forKey: "challenge_notification_count")
            
            await updatePendingNotifications()
        }
    }
    
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        dailyNotificationCount = 0
        userDefaults.set(0, forKey: "daily_notification_count")
        userDefaults.set(0, forKey: "challenge_notification_count")
        userDefaults.set(0, forKey: monthlyNotificationCountKey)
        userDefaults.removeObject(forKey: monthlyNotificationDateKey)
        
        Task { @MainActor in
            await updatePendingNotifications()
        }
    }
    
    /// Public refresh hook used by settings/audit screens.
    func refreshPendingNotifications() async {
        await updatePendingNotifications()
    }
    
    /// Runtime validation report for monthly notification policy.
    func generateAuditReport() async -> NotificationAuditReport {
        let settings = await notificationCenter.notificationSettings()
        let pending = await notificationCenter.pendingNotificationRequests()
        let calendar = Calendar.current
        
        let reservedDate = userDefaults.object(forKey: monthlyNotificationDateKey) as? Date
        let monthlyCount = userDefaults.integer(forKey: monthlyNotificationCountKey)
        let queueCount = getNotificationQueue().count
        
        let items: [NotificationAuditItem] = pending.map { request in
            let deliveryPolicy = deliveryPolicy(for: request)
            let nextDate: Date? = {
                if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                    return calendarTrigger.nextTriggerDate()
                }
                if let intervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    return Date().addingTimeInterval(intervalTrigger.timeInterval)
                }
                return nil
            }()
            let repeats: Bool = {
                if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                    return calendarTrigger.repeats
                }
                if let intervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    return intervalTrigger.repeats
                }
                return false
            }()
            
            let appearsMonthlyCompliant: Bool = {
                switch deliveryPolicy {
                case .monthlyEngagement:
                    guard let nextDate else { return false }
                    let day = calendar.component(.day, from: nextDate)
                    let hour = calendar.component(.hour, from: nextDate)
                    return day == monthlyScheduleDay && !repeats && (preferredWindowStartHour...preferredWindowEndHour).contains(hour)
                case .transactionalNudge, .transactional:
                    return !repeats
                case .transactionalCritical:
                    return true
                }
            }()
            
            return NotificationAuditItem(
                identifier: request.identifier,
                title: request.content.title,
                categoryIdentifier: request.content.categoryIdentifier,
                deliveryPolicy: deliveryPolicy,
                nextTriggerDate: nextDate,
                repeats: repeats,
                appearsMonthlyCompliant: appearsMonthlyCompliant
            )
        }
        .sorted {
            let lhs = $0.nextTriggerDate ?? .distantFuture
            let rhs = $1.nextTriggerDate ?? .distantFuture
            return lhs < rhs
        }
        
        var violations: [String] = []
        if items.contains(where: { $0.deliveryPolicy.enforcesOneShotDelivery && $0.repeats }) {
            violations.append("Found repeating pending notification(s); monthly and nudge policies require one-shot delivery.")
        }
        if items.contains(where: { $0.deliveryPolicy == .monthlyEngagement && $0.nextTriggerDate == nil }) {
            violations.append("Found pending request(s) with no next trigger date.")
        }
        let scheduledDates = items
            .filter { $0.deliveryPolicy.enforcesMonthlyCap }
            .compactMap(\.nextTriggerDate)
        if let overloaded = NotificationPolicyDebug.firstMonthlyOverload(
            for: scheduledDates,
            maxPerMonth: maxMonthlyNotifications,
            calendar: calendar
        ) {
            violations.append("Monthly cap exceeded for \(overloaded.key): \(overloaded.count) notifications scheduled.")
        }
        if let reservedDate, monthlyCount > maxMonthlyNotifications {
            violations.append("Monthly reservation count exceeds cap for \(reservedDate).")
        }
        
        return NotificationAuditReport(
            generatedAt: Date(),
            authorizationStatus: settings.authorizationStatus,
            pendingCount: items.count,
            monthlyReservationDate: reservedDate,
            monthlyReservationCount: monthlyCount,
            queueCount: queueCount,
            items: items,
            violations: violations
        )
    }
    
    // MARK: - Helper Methods
    
    private func isNotificationTypeEnabled(_ category: NotificationCategory) -> Bool {
        switch category {
        case .challengeReminder, .challengeComplete, .newChallenge:
            return preferences.challengeReminders
        case .streakReminder:
            return preferences.streakReminders
        case .leaderboardUpdate:
            return preferences.leaderboardUpdates
        case .teamChallenge:
            return preferences.teamInvites
        }
    }
    
    private func isInQuietHours(dateComponents: DateComponents) -> Bool {
        guard let hour = dateComponents.hour else { return false }
        return NotificationPolicyDebug.isInQuietHours(
            hour: hour,
            quietHoursStart: quietHoursStart,
            quietHoursEnd: quietHoursEnd
        )
    }
    
    private func incrementDailyCount() {
        dailyNotificationCount += 1
        userDefaults.set(dailyNotificationCount, forKey: "daily_notification_count")
    }
    
    private func resetDailyCountIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastResetDate = userDefaults.object(forKey: "last_notification_reset_date") as? Date {
            let lastReset = calendar.startOfDay(for: lastResetDate)
            
            if today > lastReset {
                // New day, reset counts
                dailyNotificationCount = 0
                userDefaults.set(0, forKey: "daily_notification_count")
                userDefaults.set(0, forKey: "challenge_notification_count")
                userDefaults.set(today, forKey: "last_notification_reset_date")
                print("🔄 Reset daily notification count for new day")
            }
        } else {
            // First time, set reset date
            userDefaults.set(today, forKey: "last_notification_reset_date")
        }
        
        dailyNotificationCount = userDefaults.integer(forKey: "daily_notification_count")
    }
    
    private func setupMidnightTimer() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let midnight = calendar.startOfDay(for: tomorrow)
        let timeInterval = midnight.timeIntervalSince(Date())
        
        self.midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
            Task { @MainActor in
                self.resetDailyCountIfNeeded()
                self.setupMidnightTimer() // Setup for next midnight
            }
        }
    }
    
    private func updatePendingNotifications() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        pendingNotifications = pending
        print("📱 \(pending.count) pending notifications")
    }

    private func purgeLegacyNotificationSchedules() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let calendar = Calendar.current
        let legacyIDs = pending.compactMap { request -> String? in
            let identifier = request.identifier
            let hasLegacyIdentifier =
                identifier == "daily_streak_reminder" ||
                identifier == "weekly_leaderboard_update" ||
                identifier.hasPrefix("challenge_reminder_") ||
                (identifier.hasPrefix("challenge_") && identifier != "challenge_monthly_checkin")

            let hasPolicyTag = request.content.userInfo[deliveryPolicyUserInfoKey] as? String != nil
            let policy = deliveryPolicy(for: request)
            let isPolicyManaged = policy.enforcesMonthlyCap
            let repeats = {
                if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                    return calendarTrigger.repeats
                }
                if let intervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    return intervalTrigger.repeats
                }
                return false
            }()
            let isLegacy8PM: Bool = {
                guard let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger,
                      let nextDate = calendarTrigger.nextTriggerDate() else {
                    return false
                }
                return calendar.component(.hour, from: nextDate) == 20
            }()
            let nextDate = nextTriggerDate(for: request.trigger)
            let violatesMonthlyWindow: Bool = {
                guard policy == .monthlyEngagement, let nextDate else { return false }
                let day = calendar.component(.day, from: nextDate)
                let hour = calendar.component(.hour, from: nextDate)
                return day != monthlyScheduleDay || !(preferredWindowStartHour...preferredWindowEndHour).contains(hour)
            }()

            if hasLegacyIdentifier ||
                (policy.enforcesOneShotDelivery && repeats) ||
                (!hasPolicyTag && isLegacy8PM && isPolicyManaged) ||
                violatesMonthlyWindow {
                return identifier
            }
            return nil
        }
        guard !legacyIDs.isEmpty else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: legacyIDs)
        await updatePendingNotifications()
    }
    
    private func setupNotificationCategories() async {
        let categories = NotificationCategory.allCases.map { category in
            UNNotificationCategory(
                identifier: category.rawValue,
                actions: category.actions,
                intentIdentifiers: [],
                options: category.options
            )
        }
        
        notificationCenter.setNotificationCategories(Set(categories))
    }
    
    // MARK: - Preferences Management
    
    func updatePreferences(_ newPreferences: NotificationPreferences) {
        preferences = newPreferences
        savePreferences()
        
        // Update scheduled notifications based on new preferences
        updateScheduledNotifications()
    }
    
    private func updateScheduledNotifications() {
        Task { @MainActor in
            let pending = await notificationCenter.pendingNotificationRequests()
            let managedMonthlyIdentifiers = pending.compactMap { request -> String? in
                guard isManagedMonthlyRequest(request) else { return nil }
                return request.identifier
            }

            if !managedMonthlyIdentifiers.isEmpty {
                notificationCenter.removePendingNotificationRequests(withIdentifiers: managedMonthlyIdentifiers)
            }

            userDefaults.set(0, forKey: monthlyNotificationCountKey)
            userDefaults.removeObject(forKey: monthlyNotificationDateKey)
            await updatePendingNotifications()
            scheduleMonthlyEngagementNotification()
        }
    }
    
    private func loadPreferences() {
        if let data = userDefaults.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            preferences = decoded
        }
    }
    
    private func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            userDefaults.set(encoded, forKey: preferencesKey)
        }
    }
}

// MARK: - Monthly Notification Management

extension NotificationManager {
    
    /// Reserve a monthly slot before async scheduling begins.
    private func reserveMonthlySlot(for targetDate: Date) -> Bool {
        guard canSendMonthlyNotification(for: targetDate) else { return false }
        markMonthlyNotificationSent(for: targetDate)
        return true
    }

    /// Release reservation when adding request fails.
    private func releaseMonthlyReservation(for targetDate: Date) {
        guard let reservedDate = userDefaults.object(forKey: monthlyNotificationDateKey) as? Date else {
            return
        }

        let calendar = Calendar.current
        guard calendar.isDate(reservedDate, equalTo: targetDate, toGranularity: .month) else {
            return
        }

        if pendingNotificationCount(forMonthOf: targetDate) >= maxMonthlyNotifications {
            userDefaults.set(targetDate, forKey: monthlyNotificationDateKey)
            userDefaults.set(maxMonthlyNotifications, forKey: monthlyNotificationCountKey)
            return
        }

        userDefaults.set(0, forKey: monthlyNotificationCountKey)
        userDefaults.removeObject(forKey: monthlyNotificationDateKey)
    }

    /// Check if we can schedule a notification for the target month.
    private func canSendMonthlyNotification(for targetDate: Date) -> Bool {
        let reservedDate = userDefaults.object(forKey: monthlyNotificationDateKey) as? Date
        let pendingDates = pendingMonthlyCapDates()
        return NotificationPolicyDebug.canScheduleMonthlyNotification(
            targetDate: targetDate,
            reservedDate: reservedDate,
            pendingDates: pendingDates,
            maxPerMonth: maxMonthlyNotifications,
            calendar: Calendar.current
        )
    }
    
    /// Mark that we've consumed the slot for this target month.
    private func markMonthlyNotificationSent(for targetDate: Date) {
        userDefaults.set(targetDate, forKey: monthlyNotificationDateKey)
        userDefaults.set(maxMonthlyNotifications, forKey: monthlyNotificationCountKey)
    }
    
    /// Reset monthly count if we've crossed into a new month.
    private func resetMonthlyCountIfNeeded() {
        guard let lastNotificationDate = userDefaults.object(forKey: monthlyNotificationDateKey) as? Date else {
            return
        }

        let calendar = Calendar.current
        let now = Date()
        if !calendar.isDate(lastNotificationDate, equalTo: now, toGranularity: .month) {
            userDefaults.set(0, forKey: monthlyNotificationCountKey)
            print("📅 Monthly notification count reset")
        }
    }
    
    /// Setup timer to reset monthly count exactly at the next month boundary.
    private func setupMonthlyResetTimer() {
        let calendar = Calendar.current
        let now = Date()
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfCurrentMonth) ?? now
        let timeInterval = nextMonth.timeIntervalSince(now)
        
        monthlyResetTimer = Timer.scheduledTimer(withTimeInterval: max(1, timeInterval), repeats: false) { _ in
            Task { @MainActor in
                self.resetMonthlyCountIfNeeded()
                self.scheduleMonthlyEngagementNotification()
                self.setupMonthlyResetTimer()
            }
        }
    }
    
    /// Queue notification for smart selection
    private func queueNotificationForSmartSelection(
        identifier: String,
        title: String,
        body: String,
        category: NotificationCategory,
        priority: NotificationPriority,
        trigger: UNNotificationTrigger?
    ) {
        var queue = getNotificationQueue()
        let queueItem = NotificationQueueItem(
            identifier: identifier,
            title: title,
            body: body,
            category: category,
            priority: priority,
            trigger: trigger,
            queuedAt: Date()
        )
        if let existingIndex = queue.firstIndex(where: { $0.identifier == identifier }) {
            queue[existingIndex] = queueItem
        } else {
            queue.append(queueItem)
        }
        if queue.count > 25 {
            queue = Array(queue.suffix(25))
        }
        saveNotificationQueue(queue)
        
        // Keep exactly one queued notification for next month's slot.
        scheduleSmartSelection()
    }
    
    /// Get queued notifications
    private func getNotificationQueue() -> [NotificationQueueItem] {
        if let data = userDefaults.data(forKey: pendingNotificationsKey),
           let queue = try? JSONDecoder().decode([NotificationQueueItem].self, from: data) {
            return queue
        }
        return []
    }
    
    /// Save notification queue
    private func saveNotificationQueue(_ queue: [NotificationQueueItem]) {
        if let encoded = try? JSONEncoder().encode(queue) {
            userDefaults.set(encoded, forKey: pendingNotificationsKey)
        }
    }
    
    /// Smart selection of best queued notification for next month.
    private func scheduleSmartSelection() {
        Task { @MainActor in
            let queue = getNotificationQueue()
            guard let best = selectBestNotification(from: queue) else { return }

            let content = UNMutableNotificationContent()
            content.title = best.title
            content.body = best.body
            content.sound = .default
            content.categoryIdentifier = best.category.rawValue
            content.userInfo = [deliveryPolicyUserInfoKey: NotificationDeliveryPolicy.monthlyEngagement.rawValue]

            let nextDate = nextMonthlyScheduleDate(
                preferredHour: preferences.streakReminderTime.hour,
                preferredMinute: preferences.streakReminderTime.minute
            )
            let targetDate: Date
            if canSendMonthlyNotification(for: nextDate) {
                targetDate = nextDate
            } else {
                targetDate = Calendar.current.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
            }

            guard reserveMonthlySlot(for: targetDate) else { return }
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "monthly_smart_selection",
                content: content,
                trigger: trigger
            )

            do {
                notificationCenter.removePendingNotificationRequests(
                    withIdentifiers: [
                        "monthly_smart_selection"
                    ]
                )
                try await notificationCenter.add(request)
                saveNotificationQueue([])
                await updatePendingNotifications()
            } catch {
                releaseMonthlyReservation(for: targetDate)
                print("❌ Failed to schedule queued monthly notification: \(error)")
            }
        }
    }
    
    /// Select the best notification from the queue.
    private func selectBestNotification(from queue: [NotificationQueueItem]) -> NotificationQueueItem? {
        var queue = queue
        guard !queue.isEmpty else { return nil }
        
        // Sort by priority and relevance
        queue.sort(by: { item1, item2 in
            // Priority first
            if item1.priority != item2.priority {
                return item1.priority.rawValue > item2.priority.rawValue
            }
            
            // Then by category importance
            let categoryOrder: [NotificationCategory] = [
                .challengeReminder,  // Most important - time-sensitive
                .streakReminder,     // Keep engagement
                .teamChallenge,      // Social engagement
                .leaderboardUpdate   // Least urgent
            ]
            
            let index1 = categoryOrder.firstIndex(of: item1.category) ?? 999
            let index2 = categoryOrder.firstIndex(of: item2.category) ?? 999
            return index1 < index2
        })
        
        return queue.first
    }
    
    /// Build a one-shot monthly trigger; repeating triggers are normalized to this policy.
    private func resolveTriggerForMonthlyPolicy(trigger: UNNotificationTrigger?, category: NotificationCategory) -> UNNotificationTrigger {
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            let preferredHour = calendarTrigger.dateComponents.hour ?? preferences.streakReminderTime.hour
            let preferredMinute = calendarTrigger.dateComponents.minute ?? preferences.streakReminderTime.minute
            let nextDate = nextMonthlyScheduleDate(preferredHour: preferredHour, preferredMinute: preferredMinute)
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        if trigger is UNTimeIntervalNotificationTrigger {
            let nextDate = nextMonthlyScheduleDate(
                preferredHour: preferences.streakReminderTime.hour,
                preferredMinute: preferences.streakReminderTime.minute
            )
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        let _ = category // Explicitly ignore category: all notifications use monthly normalization.
        let nextDate = nextMonthlyScheduleDate(
            preferredHour: preferences.streakReminderTime.hour,
            preferredMinute: preferences.streakReminderTime.minute
        )
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    /// Transactional notifications keep immediate/custom timing and are not monthly-normalized.
    private func resolveTriggerForTransactionalPolicy(trigger: UNNotificationTrigger?) -> UNNotificationTrigger? {
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            // Normalize repeating calendar requests into one-shot transactional reminders.
            if calendarTrigger.repeats, let nextDate = calendarTrigger.nextTriggerDate() {
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
                return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            }
            return calendarTrigger
        }

        if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            let clampedInterval = max(1, intervalTrigger.timeInterval)
            if intervalTrigger.repeats || clampedInterval != intervalTrigger.timeInterval {
                return UNTimeIntervalNotificationTrigger(timeInterval: clampedInterval, repeats: false)
            }
            return intervalTrigger
        }

        // nil trigger means immediate delivery.
        return nil
    }

    private func nextMonthlyScheduleDate(preferredHour: Int, preferredMinute: Int) -> Date {
        NotificationPolicyDebug.nextMonthlyScheduleDate(
            now: Date(),
            calendar: Calendar.current,
            preferredHour: preferredHour,
            preferredMinute: preferredMinute,
            monthlyScheduleDay: monthlyScheduleDay,
            monthlyScheduleHour: monthlyScheduleHour,
            monthlyScheduleMinute: monthlyScheduleMinute,
            preferredWindowStartHour: preferredWindowStartHour,
            preferredWindowEndHour: preferredWindowEndHour,
            quietHoursEnabled: preferences.quietHoursEnabled,
            quietHoursStart: quietHoursStart,
            quietHoursEnd: quietHoursEnd
        )
    }

    private func normalizedMonthlyTime(preferredHour: Int, preferredMinute: Int) -> (hour: Int, minute: Int) {
        NotificationPolicyDebug.normalizedMonthlyTime(
            preferredHour: preferredHour,
            preferredMinute: preferredMinute,
            preferredWindowStartHour: preferredWindowStartHour,
            preferredWindowEndHour: preferredWindowEndHour,
            fallbackHour: monthlyScheduleHour,
            fallbackMinute: monthlyScheduleMinute
        )
    }

    private func notificationTargetDate(for trigger: UNNotificationTrigger?) -> Date {
        return nextTriggerDate(for: trigger) ?? Date()
    }

    private func nextTriggerDate(for trigger: UNNotificationTrigger?) -> Date? {
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            return calendarTrigger.nextTriggerDate()
        }

        if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            return Date().addingTimeInterval(intervalTrigger.timeInterval)
        }

        return nil
    }

    private func pendingNotificationCount(forMonthOf targetDate: Date) -> Int {
        let calendar = Calendar.current
        return pendingNotifications.reduce(into: 0) { count, request in
            guard deliveryPolicy(for: request).enforcesMonthlyCap else { return }
            guard let nextDate = nextTriggerDate(for: request.trigger) else { return }
            guard calendar.isDate(nextDate, equalTo: targetDate, toGranularity: .month) else { return }
            count += 1
        }
    }

    private func isManagedMonthlyRequest(_ request: UNNotificationRequest) -> Bool {
        if deliveryPolicy(for: request).enforcesMonthlyCap {
            return true
        }

        let identifier = request.identifier
        if identifier == "monthly_streak_reminder" ||
            identifier == "monthly_smart_selection" ||
            identifier == "challenge_monthly_checkin" {
            return true
        }

        return false
    }

    private func pendingMonthlyCapDates() -> [Date] {
        pendingNotifications.compactMap { request in
            guard deliveryPolicy(for: request).enforcesMonthlyCap else { return nil }
            return nextTriggerDate(for: request.trigger)
        }
    }

    private func deliveryPolicy(for request: UNNotificationRequest) -> NotificationDeliveryPolicy {
        if let rawValue = request.content.userInfo[deliveryPolicyUserInfoKey] as? String,
           let parsed = NotificationDeliveryPolicy(rawValue: rawValue) {
            return normalizedDeliveryPolicy(parsed)
        }

        // Legacy requests without an explicit policy tag:
        // - Known monthly IDs stay monthly-engagement.
        // - nil trigger means immediate/transactional.
        // - everything else defaults to capped nudge behavior.
        if isLegacyMonthlyIdentifier(request.identifier) {
            return .monthlyEngagement
        }
        if request.trigger == nil {
            return .transactionalCritical
        }
        return .transactionalNudge
    }

    private func isLegacyMonthlyIdentifier(_ identifier: String) -> Bool {
        identifier == "monthly_streak_reminder" ||
            identifier == "monthly_smart_selection" ||
            identifier == "challenge_monthly_checkin"
    }

    private func normalizedDeliveryPolicy(_ policy: NotificationDeliveryPolicy) -> NotificationDeliveryPolicy {
        switch policy {
        case .transactional:
            return .transactionalCritical
        default:
            return policy
        }
    }
}

// MARK: - Notification Priority

enum NotificationDeliveryPolicy: String, Codable {
    case monthlyEngagement = "monthly_engagement"
    case transactionalNudge = "transactional_nudge"
    case transactionalCritical = "transactional_critical"
    case transactional = "transactional" // Legacy alias for immediate transactional delivery.

    var enforcesMonthlyCap: Bool {
        switch self {
        case .monthlyEngagement, .transactionalNudge, .transactionalCritical, .transactional:
            return true
        }
    }

    var enforcesOneShotDelivery: Bool {
        switch self {
        case .monthlyEngagement, .transactionalNudge, .transactionalCritical, .transactional:
            return true
        }
    }
}

enum NotificationPolicyDebug {
    static func monthBucketKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    static func firstMonthlyOverload(
        for dates: [Date],
        maxPerMonth: Int,
        calendar: Calendar
    ) -> (key: String, count: Int)? {
        var buckets: [String: Int] = [:]
        for date in dates {
            let key = monthBucketKey(for: date, calendar: calendar)
            buckets[key, default: 0] += 1
        }
        return buckets.first(where: { $0.value > maxPerMonth }).map { ($0.key, $0.value) }
    }

    static func canScheduleMonthlyNotification(
        targetDate: Date,
        reservedDate: Date?,
        pendingDates: [Date],
        maxPerMonth: Int,
        calendar: Calendar
    ) -> Bool {
        let pendingInMonth = pendingDates.filter {
            calendar.isDate($0, equalTo: targetDate, toGranularity: .month)
        }.count

        guard pendingInMonth < maxPerMonth else {
            return false
        }

        guard let reservedDate else {
            return true
        }

        return !calendar.isDate(reservedDate, equalTo: targetDate, toGranularity: .month)
    }

    static func isInQuietHours(hour: Int, quietHoursStart: Int, quietHoursEnd: Int) -> Bool {
        if quietHoursStart < quietHoursEnd {
            return hour >= quietHoursStart && hour < quietHoursEnd
        }
        return hour >= quietHoursStart || hour < quietHoursEnd
    }

    static func normalizedMonthlyTime(
        preferredHour: Int,
        preferredMinute: Int,
        preferredWindowStartHour: Int,
        preferredWindowEndHour: Int,
        fallbackHour: Int,
        fallbackMinute: Int
    ) -> (hour: Int, minute: Int) {
        let minute = min(max(preferredMinute, 0), 59)
        guard preferredWindowStartHour...preferredWindowEndHour ~= preferredHour else {
            return (fallbackHour, fallbackMinute)
        }
        return (preferredHour, minute)
    }

    static func nextMonthlyScheduleDate(
        now: Date,
        calendar: Calendar,
        preferredHour: Int,
        preferredMinute: Int,
        monthlyScheduleDay: Int,
        monthlyScheduleHour: Int,
        monthlyScheduleMinute: Int,
        preferredWindowStartHour: Int,
        preferredWindowEndHour: Int,
        quietHoursEnabled: Bool,
        quietHoursStart: Int,
        quietHoursEnd: Int
    ) -> Date {
        let normalizedTime = normalizedMonthlyTime(
            preferredHour: preferredHour,
            preferredMinute: preferredMinute,
            preferredWindowStartHour: preferredWindowStartHour,
            preferredWindowEndHour: preferredWindowEndHour,
            fallbackHour: monthlyScheduleHour,
            fallbackMinute: monthlyScheduleMinute
        )

        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = monthlyScheduleDay
        components.hour = normalizedTime.hour
        components.minute = normalizedTime.minute

        guard let thisMonthDate = calendar.date(from: components) else {
            return now
        }

        var candidate = thisMonthDate
        if candidate <= now {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            var nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
            nextComponents.day = monthlyScheduleDay
            nextComponents.hour = normalizedTime.hour
            nextComponents.minute = normalizedTime.minute
            candidate = calendar.date(from: nextComponents) ?? now
        }

        if quietHoursEnabled {
            let hour = calendar.component(.hour, from: candidate)
            if isInQuietHours(hour: hour, quietHoursStart: quietHoursStart, quietHoursEnd: quietHoursEnd) {
                var adjusted = calendar.dateComponents([.year, .month, .day], from: candidate)
                adjusted.hour = monthlyScheduleHour
                adjusted.minute = monthlyScheduleMinute
                return calendar.date(from: adjusted) ?? candidate
            }
        }

        return candidate
    }
}

enum NotificationPriority: Int, Codable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
}

// MARK: - Notification Queue Item

struct NotificationQueueItem: Codable {
    let identifier: String
    let title: String
    let body: String
    let category: NotificationCategory
    let priority: NotificationPriority
    let trigger: Data? // Encoded trigger
    let queuedAt: Date
    
    init(identifier: String, title: String, body: String, category: NotificationCategory, priority: NotificationPriority, trigger: UNNotificationTrigger?, queuedAt: Date) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.category = category
        self.priority = priority
        self.trigger = nil // Simplified for now
        self.queuedAt = queuedAt
    }
}

struct NotificationAuditItem: Identifiable {
    var id: String { identifier }
    let identifier: String
    let title: String
    let categoryIdentifier: String
    let deliveryPolicy: NotificationDeliveryPolicy
    let nextTriggerDate: Date?
    let repeats: Bool
    let appearsMonthlyCompliant: Bool
}

struct NotificationAuditReport {
    let generatedAt: Date
    let authorizationStatus: UNAuthorizationStatus
    let pendingCount: Int
    let monthlyReservationDate: Date?
    let monthlyReservationCount: Int
    let queueCount: Int
    let items: [NotificationAuditItem]
    let violations: [String]
    
    var isHealthy: Bool {
        violations.isEmpty
    }
}

// MARK: - Notification Preferences

struct NotificationPreferences: Codable {
    var challengeReminders = true
    var streakReminders = true
    var leaderboardUpdates = true
    var teamInvites = true
    var quietHoursEnabled = true
    var streakReminderTime = NotificationTime(hour: 10, minute: 30) // 10:30 AM
    
    struct NotificationTime: Codable {
        var hour: Int
        var minute: Int
        
        var displayString: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            
            if let date = Calendar.current.date(from: components) {
                return formatter.string(from: date)
            }
            return "\(hour):\(String(format: "%02d", minute))"
        }
    }
}

// MARK: - Notification Categories

enum NotificationCategory: String, CaseIterable, Codable {
    case challengeReminder = "CHALLENGE_REMINDER"
    case challengeComplete = "CHALLENGE_COMPLETE"
    case streakReminder = "STREAK_REMINDER"
    case newChallenge = "NEW_CHALLENGE"
    case leaderboardUpdate = "LEADERBOARD_UPDATE"
    case teamChallenge = "TEAM_CHALLENGE"
    
    var actions: [UNNotificationAction] {
        switch self {
        case .challengeReminder:
            return [
                UNNotificationAction(
                    identifier: "VIEW_CHALLENGE",
                    title: "View Challenge",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "SNOOZE_REMINDER",
                    title: "Remind me later",
                    options: []
                )
            ]
        case .streakReminder:
            return [
                UNNotificationAction(
                    identifier: "COOK_NOW",
                    title: "Let's Cook! 🔥",
                    options: [.foreground]
                )
            ]
        case .teamChallenge:
            return [
                UNNotificationAction(
                    identifier: "ACCEPT_TEAM",
                    title: "Join Team",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DECLINE_TEAM",
                    title: "Not Now",
                    options: [.destructive]
                )
            ]
        default:
            return []
        }
    }
    
    var options: UNNotificationCategoryOptions {
        switch self {
        case .challengeReminder, .streakReminder:
            return []
        default:
            return []
        }
    }
}
