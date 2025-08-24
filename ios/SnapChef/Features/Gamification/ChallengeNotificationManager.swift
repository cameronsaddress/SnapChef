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
    private lazy var notificationManager = NotificationManager.shared

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
        Task.detached {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let isAuthorized = settings.authorizationStatus == .authorized
            await MainActor.run {
                self.notificationsEnabled = isAuthorized
            }
        }
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
            trigger: trigger
        )
    }

    func notifyChallengeComplete(_ challenge: Challenge, reward: ChallengeReward) {
        guard notificationsEnabled else { return }

        // Capture values
        let challengeId = challenge.id
        let challengeTitle = challenge.title
        let rewardPoints = reward.points
        let rewardBadge = reward.badge

        Task.detached {
            let center = UNUserNotificationCenter.current()

            let content = UNMutableNotificationContent()
            content.title = "Challenge Complete! 🎉"
            content.body = "You've completed \"\(challengeTitle)\" and earned \(rewardPoints) points!"

            if let badge = rewardBadge {
                content.subtitle = "New badge unlocked: \(badge)"
            }

            content.sound = UNNotificationSound(named: UNNotificationSoundName("celebration.wav"))
            content.categoryIdentifier = LegacyNotificationCategory.challengeComplete.rawValue

            let request = UNNotificationRequest(
                identifier: NotificationIdentifier.challengeComplete(challengeId),
                content: content,
                trigger: nil // Immediate notification
            )
            try? await center.add(request)
        }
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

        Task.detached {
            let center = UNUserNotificationCenter.current()

            let content = UNMutableNotificationContent()
            content.title = "Weekly Leaderboard Update 📊"

            if let rank = weeklyRank {
                content.body = "You're currently ranked #\(rank) this week! Check the leaderboard to see who you're competing against."
            } else {
                content.body = "The weekly leaderboard has been updated. See where you stand!"
            }

            content.sound = .default
            content.categoryIdentifier = LegacyNotificationCategory.leaderboardUpdate.rawValue

            // Schedule for every Sunday at 6 PM
            var dateComponents = DateComponents()
            dateComponents.weekday = 1 // Sunday
            dateComponents.hour = 18
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(
                identifier: NotificationIdentifier.weeklyLeaderboard,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    // MARK: - Team Challenge Notifications

    func notifyTeamChallengeInvite(from userName: String, teamName: String, challengeName: String) {
        guard notificationsEnabled else { return }

        let identifier = "\(NotificationIdentifier.teamChallengeInvite)_\(UUID().uuidString)"

        Task.detached {
            let center = UNUserNotificationCenter.current()

            let content = UNMutableNotificationContent()
            content.title = "Team Challenge Invite! 👥"
            content.body = "\(userName) invited you to join \"\(teamName)\" for the \(challengeName) challenge"
            content.sound = .default
            content.categoryIdentifier = LegacyNotificationCategory.teamChallenge.rawValue
            content.userInfo = [
                "teamName": teamName,
                "challengeName": challengeName,
                "inviterName": userName
            ]

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }

    // MARK: - New Challenge Notifications

    func notifyNewChallengeAvailable(_ challenge: Challenge) {
        guard notificationsEnabled else { return }

        let challengeType = challenge.type.rawValue
        let challengeTitle = challenge.title
        let challengeDescription = challenge.description
        let challengePoints = challenge.points
        let identifier = "new_challenge_\(challenge.id)"

        Task.detached {
            let center = UNUserNotificationCenter.current()

            let content = UNMutableNotificationContent()
            content.title = "New \(challengeType) Available! ✨"
            content.body = "\"\(challengeTitle)\" - \(challengeDescription)"
            content.subtitle = "Reward: \(challengePoints) points"
            content.sound = .default
            content.categoryIdentifier = LegacyNotificationCategory.newChallenge.rawValue

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }

    // MARK: - Helper Methods

    private func createChallengeImageAttachment(for challenge: Challenge) -> UNNotificationAttachment? {
        // In a real app, this would create or fetch an image for the challenge
        // For now, return nil
        return nil
    }

    func cancelNotification(identifier: String) {
        Task.detached {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
        }
    }

    func cancelAllChallengeNotifications() {
        // Delegate to NotificationManager for centralized handling
        notificationManager.cancelChallengeNotifications()
    }

    func updatePendingNotifications() {
        Task.detached {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            await MainActor.run {
                self.pendingNotifications = pending
            }
        }
    }

    // MARK: - Default Notifications Setup

    private func setupDefaultNotifications() async {
        // CRITICAL FIX: Only schedule for JOINED challenges to prevent notification bomb
        // Delegate to NotificationManager for centralized handling
        
        // Schedule streak reminder (handled by NotificationManager)
        notificationManager.scheduleDailyStreakReminder()
        
        // Schedule weekly leaderboard update
        scheduleWeeklyLeaderboardUpdate()
        
        // Schedule challenge reminders ONLY for joined challenges (max 3)
        notificationManager.scheduleJoinedChallengeReminders()
        
        print("✅ Setup default notifications with spam prevention")
    }

    // MARK: - Settings

    func updateNotificationSettings(
        challengeReminders: Bool,
        streakReminders: Bool,
        leaderboardUpdates: Bool,
        teamInvites: Bool
    ) {
        UserDefaults.standard.set(challengeReminders, forKey: "notifications.challengeReminders")
        UserDefaults.standard.set(streakReminders, forKey: "notifications.streakReminders")
        UserDefaults.standard.set(leaderboardUpdates, forKey: "notifications.leaderboardUpdates")
        UserDefaults.standard.set(teamInvites, forKey: "notifications.teamInvites")

        // Update scheduled notifications based on preferences
        if !streakReminders {
            cancelNotification(identifier: NotificationIdentifier.dailyStreak)
        }

        if !leaderboardUpdates {
            cancelNotification(identifier: NotificationIdentifier.weeklyLeaderboard)
        }
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
