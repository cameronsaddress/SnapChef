@preconcurrency import Foundation
@preconcurrency import UserNotifications
import SwiftUI

/// Global notification manager that handles all notification scheduling with comprehensive limits and controls
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    // MARK: - Published Properties
    @Published var preferences = NotificationPreferences()
    @Published var isEnabled = false
    @Published var dailyNotificationCount = 0
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    // MARK: - Constants
    private let maxWeeklyNotifications = 1  // Only 1 notification per week
    private let quietHoursStart = 22 // 10 PM
    private let quietHoursEnd = 8    // 8 AM
    
    // MARK: - Private Properties
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private var weeklyResetTimer: Timer?
    private var midnightTimer: Timer?
    
    // UserDefaults Keys
    private let weeklyNotificationDateKey = "last_weekly_notification_date"
    private let weeklyNotificationCountKey = "weekly_notification_count"
    private let preferencesKey = "notification_preferences"
    private let pendingNotificationsKey = "pending_notifications_queue"
    
    private init() {
        loadPreferences()
        checkNotificationAuthorization()
        setupWeeklyResetTimer()
        resetWeeklyCountIfNeeded()
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
    
    // MARK: - Core Notification Scheduling
    
    /// Schedule a notification with weekly limit and smart selection
    func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        subtitle: String? = nil,
        category: NotificationCategory,
        userInfo: [String: Any] = [:],
        trigger: UNNotificationTrigger?,
        priority: NotificationPriority = .medium
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
        
        // Check weekly limit - ONLY 1 notification per week
        if !canSendWeeklyNotification() {
            print("📅 Weekly notification already sent this week - queuing: \(title)")
            // Queue this notification for smart selection later
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
        
        // Check quiet hours for scheduled notifications
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger,
           isInQuietHours(dateComponents: calendarTrigger.dateComponents) {
            print("🌙 Notification scheduled during quiet hours - rescheduling to optimal time")
            // Reschedule to next optimal time (tomorrow at 10 AM)
            if let rescheduledTrigger = rescheduleToOptimalTime(originalTrigger: calendarTrigger) {
                return scheduleNotification(
                    identifier: identifier,
                    title: title,
                    body: body,
                    subtitle: subtitle,
                    category: category,
                    userInfo: userInfo,
                    trigger: rescheduledTrigger,
                    priority: priority
                )
            }
            return false
        }
        
        // This is our ONE weekly notification - make it count!
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.subtitle = subtitle ?? ""
        content.sound = .default
        content.categoryIdentifier = category.rawValue
        content.userInfo = userInfo
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        Task { @MainActor in
            do {
                try await notificationCenter.add(request)
                markWeeklyNotificationSent()
                await updatePendingNotifications()
                print("✅ Sent weekly notification: \(title)")
            } catch {
                print("❌ Failed to schedule notification: \(error)")
            }
        }
        
        return true
    }
    
    /// Schedule immediate notification (respects daily limits but bypasses quiet hours)
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
            priority: .high
        )
    }
    
    // MARK: - Challenge Notifications
    
    func scheduleJoinedChallengeReminders() {
        guard preferences.challengeReminders else { return }
        
        let joinedChallenges = GamificationManager.shared.activeChallenges
            .filter { $0.isJoined }
            .prefix(3) // Limit to 3 max
        
        // Clear existing challenge notifications first
        cancelChallengeNotifications()
        
        for challenge in joinedChallenges {
            let reminderTime = challenge.endDate.addingTimeInterval(-7_200) // 2 hours before
            guard reminderTime > Date() else { continue }
            
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            _ = scheduleNotification(
                identifier: "challenge_reminder_\(challenge.id)",
                title: "🏆 Challenge Ending Soon!",
                body: "\"\(challenge.title)\" ends in 2 hours. Complete it now to earn \(challenge.points) points!",
                category: .challengeReminder,
                userInfo: [
                    "challengeId": challenge.id,
                    "challengeType": challenge.type.rawValue
                ],
                trigger: trigger
            )
        }
        
        print("📱 Scheduled reminders for \(joinedChallenges.count) joined challenges (max 3)")
    }
    
    // MARK: - Streak Notifications
    
    func scheduleDailyStreakReminder() {
        guard preferences.streakReminders else { return }
        
        // Cancel existing streak notifications first
        cancelNotification(identifier: "daily_streak_reminder")
        
        var dateComponents = DateComponents()
        dateComponents.hour = preferences.streakReminderTime.hour
        dateComponents.minute = preferences.streakReminderTime.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        _ = scheduleNotification(
            identifier: "daily_streak_reminder",
            title: "🔥 Keep Your Streak Alive!",
            body: "Don't forget to complete today's activities to maintain your streak!",
            category: .streakReminder,
            userInfo: [:],
            trigger: trigger
        )
    }
    
    // MARK: - Notification Bundling
    
    func scheduleBundledNotification(
        bundleId: String,
        notifications: [(title: String, body: String)],
        category: NotificationCategory,
        trigger: UNNotificationTrigger?
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
            trigger: trigger
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
        
        Task { @MainActor in
            await updatePendingNotifications()
        }
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
        
        if quietHoursStart < quietHoursEnd {
            // Same day quiet hours (not typical)
            return hour >= quietHoursStart && hour < quietHoursEnd
        } else {
            // Overnight quiet hours (10 PM to 8 AM)
            return hour >= quietHoursStart || hour < quietHoursEnd
        }
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
        // Re-schedule streak reminders if preferences changed
        if preferences.streakReminders {
            scheduleDailyStreakReminder()
        } else {
            cancelNotification(identifier: "daily_streak_reminder")
        }
        
        // Update challenge reminders
        if preferences.challengeReminders {
            scheduleJoinedChallengeReminders()
        } else {
            cancelChallengeNotifications()
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

// MARK: - Weekly Notification Management

extension NotificationManager {
    
    /// Check if we can send a notification this week
    private func canSendWeeklyNotification() -> Bool {
        if let lastNotificationDate = userDefaults.object(forKey: weeklyNotificationDateKey) as? Date {
            let calendar = Calendar.current
            let weeksSince = calendar.dateComponents([.weekOfYear], from: lastNotificationDate, to: Date()).weekOfYear ?? 0
            return weeksSince >= 1
        }
        return true // No notification sent yet
    }
    
    /// Mark that we've sent our weekly notification
    private func markWeeklyNotificationSent() {
        userDefaults.set(Date(), forKey: weeklyNotificationDateKey)
        userDefaults.set(1, forKey: weeklyNotificationCountKey)
    }
    
    /// Reset weekly count if a week has passed
    private func resetWeeklyCountIfNeeded() {
        if let lastNotificationDate = userDefaults.object(forKey: weeklyNotificationDateKey) as? Date {
            let calendar = Calendar.current
            let weeksSince = calendar.dateComponents([.weekOfYear], from: lastNotificationDate, to: Date()).weekOfYear ?? 0
            if weeksSince >= 1 {
                userDefaults.set(0, forKey: weeklyNotificationCountKey)
                print("📅 Weekly notification count reset")
            }
        }
    }
    
    /// Setup timer to reset weekly count
    private func setupWeeklyResetTimer() {
        let calendar = Calendar.current
        let nextMonday = calendar.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0, weekday: 2), matchingPolicy: .nextTime) ?? Date()
        let timeInterval = nextMonday.timeIntervalSince(Date())
        
        weeklyResetTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
            Task { @MainActor in
                self.resetWeeklyCountIfNeeded()
                self.setupWeeklyResetTimer() // Reschedule for next week
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
        queue.append(queueItem)
        saveNotificationQueue(queue)
        
        // Run smart selection at the start of next week
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
    
    /// Smart selection of best notification for the week
    private func scheduleSmartSelection() {
        // Run smart selection on Monday morning
        let calendar = Calendar.current
        let nextMonday = calendar.nextDate(after: Date(), matching: DateComponents(hour: 10, minute: 0, weekday: 2), matchingPolicy: .nextTime) ?? Date()
        
        Task {
            try? await Task.sleep(until: .now + .seconds(nextMonday.timeIntervalSinceNow))
            await selectAndSendBestNotification()
        }
    }
    
    /// Select the best notification from the queue
    @MainActor
    private func selectAndSendBestNotification() async {
        var queue = getNotificationQueue()
        guard !queue.isEmpty else { return }
        
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
        
        // Send the best notification
        if let best = queue.first {
            _ = scheduleNotification(
                identifier: best.identifier,
                title: best.title,
                body: best.body,
                category: best.category,
                userInfo: [:],
                trigger: nil, // Send immediately
                priority: best.priority
            )
            
            // Clear the queue after sending
            saveNotificationQueue([])
        }
    }
    
    /// Reschedule to optimal time (next day at 10 AM)
    private func rescheduleToOptimalTime(originalTrigger: UNCalendarNotificationTrigger) -> UNCalendarNotificationTrigger? {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 10
        components.minute = 0
        
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}

// MARK: - Notification Priority

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

// MARK: - Notification Preferences

struct NotificationPreferences: Codable {
    var challengeReminders = true
    var streakReminders = true
    var leaderboardUpdates = true
    var teamInvites = true
    var quietHoursEnabled = true
    var streakReminderTime = NotificationTime(hour: 20, minute: 0) // 8 PM
    
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