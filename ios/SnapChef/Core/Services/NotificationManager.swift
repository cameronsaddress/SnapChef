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
    private let maxDailyNotifications = 5
    private let quietHoursStart = 22 // 10 PM
    private let quietHoursEnd = 8    // 8 AM
    private let maxChallengeNotifications = 3
    
    // MARK: - Private Properties
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private var midnightTimer: Timer?
    
    // UserDefaults Keys
    private let dailyCountKey = "notification_daily_count"
    private let lastResetDateKey = "notification_last_reset_date"
    private let preferencesKey = "notification_preferences"
    private let challengeNotificationCountKey = "challenge_notification_count"
    
    private init() {
        loadPreferences()
        checkNotificationAuthorization()
        setupMidnightTimer()
        resetDailyCountIfNeeded()
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
    
    /// Schedule a notification with global limits and quiet hours enforcement
    func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        subtitle: String? = nil,
        category: NotificationCategory,
        userInfo: [String: Any] = [:],
        trigger: UNNotificationTrigger?,
        bypassQuietHours: Bool = false
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
        
        // Check daily limit
        guard dailyNotificationCount < maxDailyNotifications else {
            print("📈 Daily notification limit reached (\(maxDailyNotifications)) - skipping: \(title)")
            return false
        }
        
        // Check quiet hours for scheduled notifications
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger,
           !bypassQuietHours && isInQuietHours(dateComponents: calendarTrigger.dateComponents) {
            print("🌙 Notification scheduled during quiet hours - skipping: \(title)")
            return false
        }
        
        // Check challenge notification limits
        if case .challengeReminder = category {
            let challengeCount = userDefaults.integer(forKey: challengeNotificationCountKey)
            guard challengeCount < maxChallengeNotifications else {
                print("🏆 Challenge notification limit reached (\(maxChallengeNotifications)) - skipping: \(title)")
                return false
            }
            userDefaults.set(challengeCount + 1, forKey: challengeNotificationCountKey)
        }
        
        // Create and schedule notification
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
                incrementDailyCount()
                await updatePendingNotifications()
                print("✅ Scheduled notification: \(title)")
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
            bypassQuietHours: true
        )
    }
    
    // MARK: - Challenge Notifications
    
    func scheduleJoinedChallengeReminders() {
        guard preferences.challengeReminders else { return }
        
        let joinedChallenges = GamificationManager.shared.activeChallenges
            .filter { $0.isJoined }
            .prefix(maxChallengeNotifications) // Limit to 3 max
        
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
        
        print("📱 Scheduled reminders for \(joinedChallenges.count) joined challenges (max \(maxChallengeNotifications))")
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
            userDefaults.set(0, forKey: challengeNotificationCountKey)
            
            await updatePendingNotifications()
        }
    }
    
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        dailyNotificationCount = 0
        userDefaults.set(0, forKey: dailyCountKey)
        userDefaults.set(0, forKey: challengeNotificationCountKey)
        
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
        userDefaults.set(dailyNotificationCount, forKey: dailyCountKey)
    }
    
    private func resetDailyCountIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastResetDate = userDefaults.object(forKey: lastResetDateKey) as? Date {
            let lastReset = calendar.startOfDay(for: lastResetDate)
            
            if today > lastReset {
                // New day, reset counts
                dailyNotificationCount = 0
                userDefaults.set(0, forKey: dailyCountKey)
                userDefaults.set(0, forKey: challengeNotificationCountKey)
                userDefaults.set(today, forKey: lastResetDateKey)
                print("🔄 Reset daily notification count for new day")
            }
        } else {
            // First time, set reset date
            userDefaults.set(today, forKey: lastResetDateKey)
        }
        
        dailyNotificationCount = userDefaults.integer(forKey: dailyCountKey)
    }
    
    private func setupMidnightTimer() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let midnight = calendar.startOfDay(for: tomorrow)
        let timeInterval = midnight.timeIntervalSince(Date())
        
        midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
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

enum NotificationCategory: String, CaseIterable {
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