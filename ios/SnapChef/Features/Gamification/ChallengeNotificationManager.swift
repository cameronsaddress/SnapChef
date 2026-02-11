import Foundation
import SwiftUI
import UserNotifications

// MARK: - Challenge Notification Manager
// DEPRECATED: Use NotificationManager.shared instead for new implementations
// This manager is kept for backward compatibility but delegates to NotificationManager

@MainActor
final class ChallengeNotificationManager: ObservableObject {
    static let shared = ChallengeNotificationManager()

    @Published var notificationsEnabled = false
    @Published var pendingNotifications: [UNNotificationRequest] = []

    private lazy var gamificationManager = GamificationManager.shared
    let notificationManager = NotificationManager.shared

    // DEPRECATED: Use NotificationManager.NotificationCategory instead
    // This enum is kept for backward compatibility only
    private enum LegacyNotificationCategory: String {
        case challengeReminder = "CHALLENGE_REMINDER"
        case challengeComplete = "CHALLENGE_COMPLETE"
        case streakReminder = "STREAK_REMINDER"
        case newChallenge = "NEW_CHALLENGE"
        case leaderboardUpdate = "LEADERBOARD_UPDATE"
        case teamChallenge = "TEAM_CHALLENGE"
    }

    // Notification Identifiers
    struct NotificationIdentifier {
        static func challengeReminder(_ challengeId: String) -> String {
            "challenge_reminder_\(challengeId)"
        }

        static func challengeComplete(_ challengeId: String) -> String {
            "challenge_complete_\(challengeId)"
        }

        static let dailyStreak = "daily_streak_reminder"
        static let weeklyLeaderboard = "weekly_leaderboard_update"
        static let teamChallengeInvite = "team_challenge_invite"
    }

    private init() {
        // Don't do any notification setup in init to avoid dispatch queue issues
        // Setup will happen lazily when first accessed
    }

    private var hasSetupCategories = false

    @MainActor
    private func ensureSetup() async {
        guard !hasSetupCategories else { return }
        hasSetupCategories = true
        checkNotificationAuthorization()
        await setupNotificationCategories()
    }

    // MARK: - Authorization

    func requestNotificationPermission() async -> Bool {
        // Delegate to NotificationManager for centralized handling
        let authorized = await notificationManager.requestNotificationPermission()
        self.notificationsEnabled = authorized
        return authorized
    }

    private func checkNotificationAuthorization() {
        notificationsEnabled = notificationManager.isEnabled
    }

    // MARK: - Setup Categories

    private func setupNotificationCategories() async {
        await withCheckedContinuation { continuation in
            // Challenge reminder actions
            let viewAction = UNNotificationAction(
                identifier: "VIEW_CHALLENGE",
                title: "View Challenge",
                options: [.foreground]
            )

            let snoozeAction = UNNotificationAction(
                identifier: "SNOOZE_REMINDER",
                title: "Remind me later",
                options: []
            )

            let challengeCategory = UNNotificationCategory(
                identifier: LegacyNotificationCategory.challengeReminder.rawValue,
                actions: [viewAction, snoozeAction],
                intentIdentifiers: [],
                options: []
            )

            // Streak reminder actions
            let cookNowAction = UNNotificationAction(
                identifier: "COOK_NOW",
                title: "Let's Cook! 🔥",
                options: [.foreground]
            )

            let streakCategory = UNNotificationCategory(
                identifier: LegacyNotificationCategory.streakReminder.rawValue,
                actions: [cookNowAction],
                intentIdentifiers: [],
                options: []
            )

            // Team challenge actions
            let acceptAction = UNNotificationAction(
                identifier: "ACCEPT_TEAM",
                title: "Join Team",
                options: [.foreground]
            )

            let declineAction = UNNotificationAction(
                identifier: "DECLINE_TEAM",
                title: "Not Now",
                options: [.destructive]
            )

            let teamCategory = UNNotificationCategory(
                identifier: LegacyNotificationCategory.teamChallenge.rawValue,
                actions: [acceptAction, declineAction],
                intentIdentifiers: [],
                options: []
            )

            Task.detached {
                let center = UNUserNotificationCenter.current()
                center.setNotificationCategories([challengeCategory, streakCategory, teamCategory])
                continuation.resume()
            }
        }
    }

    // MARK: - Challenge Notifications

    func scheduleChallengeReminder(for challenge: Challenge, reminderTime: Date) {
        guard notificationsEnabled else { return }
        
        // Only schedule for challenges the user has joined
        guard challenge.isJoined else {
            print("⏭️ Skipping notification for non-joined challenge: \(challenge.title)")
            return
        }

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        _ = notificationManager.scheduleNotification(
            identifier: NotificationIdentifier.challengeReminder(challenge.id),
            title: "🏆 Challenge Ending Soon!",
            body: "\"\(challenge.title)\" ends in \(challenge.timeRemaining). Complete it now to earn \(challenge.points) points!",
            category: .challengeReminder,
            userInfo: [
                "challengeId": challenge.id,
                "challengeType": challenge.type.rawValue
            ],
            trigger: trigger,
            deliveryPolicy: .transactional
        )
    }

    func notifyChallengeComplete(_ challenge: Challenge, reward: ChallengeReward) {
        guard notificationsEnabled else { return }

        var subtitle = ""
        if let badge = reward.badge {
            subtitle = "New badge unlocked: \(badge)"
        }

        _ = notificationManager.scheduleNotification(
            identifier: NotificationIdentifier.challengeComplete(challenge.id),
            title: "Challenge Complete! 🎉",
            body: "You've completed \"\(challenge.title)\" and earned \(reward.points) points!",
            subtitle: subtitle,
            category: .challengeComplete,
            userInfo: ["challengeId": challenge.id],
            trigger: nil,
            priority: .high,
            deliveryPolicy: .transactional
        )
    }

    // MARK: - Streak Notifications

    func scheduleDailyStreakReminder(at time: DateComponents) {
        // DEPRECATED: Use NotificationManager.scheduleDailyStreakReminder() instead
        print("⚠️ Warning: Using deprecated scheduleDailyStreakReminder. Use NotificationManager instead.")
        
        // Delegate to NotificationManager to avoid duplicate streak notifications
        notificationManager.scheduleDailyStreakReminder()
    }

    // MARK: - Leaderboard Notifications

    func scheduleWeeklyLeaderboardUpdate() {
        guard notificationsEnabled else { return }

        let weeklyRank = gamificationManager.userStats.weeklyRank
        let body: String
        if let rank = weeklyRank {
            body = "You're currently ranked #\(rank). Tap in and climb this month."
        } else {
            body = "Your ranking has moved. Check your position and keep cooking."
        }

        _ = notificationManager.scheduleNotification(
            identifier: NotificationIdentifier.weeklyLeaderboard,
            title: "Leaderboard Update 📊",
            body: body,
            category: .leaderboardUpdate,
            userInfo: [:],
            trigger: nil,
            priority: .low,
            deliveryPolicy: .monthlyEngagement
        )
    }

    // MARK: - Team Challenge Notifications

    func notifyTeamChallengeInvite(from userName: String, teamName: String, challengeName: String) {
        guard notificationsEnabled else { return }

        let identifier = "\(NotificationIdentifier.teamChallengeInvite)_\(UUID().uuidString)"

        _ = notificationManager.scheduleNotification(
            identifier: identifier,
            title: "Team Challenge Invite! 👥",
            body: "\(userName) invited you to join \"\(teamName)\" for \(challengeName).",
            category: .teamChallenge,
            userInfo: [
                "teamName": teamName,
                "challengeName": challengeName,
                "inviterName": userName
            ],
            trigger: nil,
            priority: .medium,
            deliveryPolicy: .transactional
        )
    }

    // MARK: - New Challenge Notifications

    func notifyNewChallengeAvailable(_ challenge: Challenge) {
        guard notificationsEnabled else { return }

        _ = notificationManager.scheduleNotification(
            identifier: "new_challenge_\(challenge.id)",
            title: "New \(challenge.type.rawValue) Available! ✨",
            body: "\"\(challenge.title)\" - \(challenge.description)",
            subtitle: "Reward: \(challenge.points) points",
            category: .newChallenge,
            userInfo: ["challengeId": challenge.id],
            trigger: nil,
            priority: .medium,
            deliveryPolicy: .monthlyEngagement
        )
    }

    // MARK: - Helper Methods

    private func createChallengeImageAttachment(for challenge: Challenge) -> UNNotificationAttachment? {
        // In a real app, this would create or fetch an image for the challenge
        // For now, return nil
        return nil
    }

    func cancelNotification(identifier: String) {
        notificationManager.cancelNotification(identifier: identifier)
    }

    func cancelAllChallengeNotifications() {
        // Delegate to NotificationManager for centralized handling
        notificationManager.cancelChallengeNotifications()
    }

    func updatePendingNotifications() {
        Task { @MainActor in
            await notificationManager.refreshPendingNotifications()
            pendingNotifications = notificationManager.pendingNotifications
        }
    }

    // MARK: - Default Notifications Setup

    private func setupDefaultNotifications() async {
        notificationManager.scheduleMonthlyEngagementNotification()
        print("✅ Setup default notifications with monthly scheduling")
    }

    // MARK: - Settings

    func updateNotificationSettings(
        challengeReminders: Bool,
        streakReminders: Bool,
        leaderboardUpdates: Bool,
        teamInvites: Bool
    ) {
        var preferences = notificationManager.preferences
        preferences.challengeReminders = challengeReminders
        preferences.streakReminders = streakReminders
        preferences.leaderboardUpdates = leaderboardUpdates
        preferences.teamInvites = teamInvites
        notificationManager.updatePreferences(preferences)
    }
}

// MARK: - Legacy Notification Settings View (REMOVED)
// This view has been moved to Features/Profile/NotificationSettingsView.swift
// and replaced with a comprehensive notification management system with spam prevention

// MARK: - Helper Function
@MainActor
private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}
