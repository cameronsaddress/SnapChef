import Foundation
import SwiftUI
import UserNotifications

// MARK: - Challenge Notification Manager

@MainActor
final class ChallengeNotificationManager: ObservableObject {
    static let shared = ChallengeNotificationManager()

    @Published var notificationsEnabled = false
    @Published var pendingNotifications: [UNNotificationRequest] = []

    private lazy var gamificationManager = GamificationManager.shared

    // Notification Categories
    enum NotificationCategory: String {
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
        await ensureSetup()

        let authorized = await withCheckedContinuation { continuation in
            Task.detached {
                let center = UNUserNotificationCenter.current()
                do {
                    let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                    continuation.resume(returning: granted)
                } catch {
                    print("Notification permission error: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }

        self.notificationsEnabled = authorized

        if authorized {
            await setupDefaultNotifications()
        }

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
                identifier: NotificationCategory.challengeReminder.rawValue,
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
                identifier: NotificationCategory.streakReminder.rawValue,
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
                identifier: NotificationCategory.teamChallenge.rawValue,
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

        // Capture values needed for notification
        let challengeId = challenge.id
        let challengeTitle = challenge.title
        let challengeTimeRemaining = challenge.timeRemaining
        let challengePoints = challenge.points
        let challengeTypeRawValue = challenge.type.rawValue
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)

        Task.detached {
            let center = UNUserNotificationCenter.current()

            let content = UNMutableNotificationContent()
            content.title = "Challenge Ending Soon! ⏰"
            content.body = "\"\(challengeTitle)\" ends in \(challengeTimeRemaining). Complete it now to earn \(challengePoints) points!"
            content.sound = .default
            content.categoryIdentifier = NotificationCategory.challengeReminder.rawValue
            content.userInfo = [
                "challengeId": challengeId,
                "challengeType": challengeTypeRawValue
            ]

            // Skip attachment for now - would need to create it inside the Task

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: NotificationIdentifier.challengeReminder(challengeId),
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                print("Error scheduling challenge reminder: \(error)")
            }
        }
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
            content.categoryIdentifier = NotificationCategory.challengeComplete.rawValue

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
        guard notificationsEnabled else { return }

        let currentStreak = gamificationManager.userStats.currentStreak

        Task.detached {
            let center = UNUserNotificationCenter.current()

            let content = UNMutableNotificationContent()
            content.title = "Keep Your Streak Alive! 🔥"
            content.body = "You're on a \(currentStreak)-day streak. Don't break it now!"
            content.sound = .default
            content.categoryIdentifier = NotificationCategory.streakReminder.rawValue

            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)

            let request = UNNotificationRequest(
                identifier: NotificationIdentifier.dailyStreak,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
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
            content.categoryIdentifier = NotificationCategory.leaderboardUpdate.rawValue

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
            content.categoryIdentifier = NotificationCategory.teamChallenge.rawValue
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
            content.categoryIdentifier = NotificationCategory.newChallenge.rawValue

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
        Task.detached {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let challengeIdentifiers = pending
                .filter { $0.identifier.contains("challenge_") }
                .map { $0.identifier }

            center.removePendingNotificationRequests(withIdentifiers: challengeIdentifiers)
        }
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
        // Schedule daily streak reminder at 7 PM
        var streakTime = DateComponents()
        streakTime.hour = 19
        streakTime.minute = 0
        scheduleDailyStreakReminder(at: streakTime)

        // Schedule weekly leaderboard update
        scheduleWeeklyLeaderboardUpdate()

        // Schedule reminders for active challenges
        for challenge in gamificationManager.activeChallenges {
            // Remind 2 hours before challenge ends
            let reminderTime = challenge.endDate.addingTimeInterval(-7_200)
            if reminderTime > Date() {
                scheduleChallengeReminder(for: challenge, reminderTime: reminderTime)
            }
        }
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

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @StateObject private var notificationManager = ChallengeNotificationManager.shared
    @State private var challengeReminders = UserDefaults.standard.bool(forKey: "notifications.challengeReminders")
    @State private var streakReminders = UserDefaults.standard.bool(forKey: "notifications.streakReminders")
    @State private var leaderboardUpdates = UserDefaults.standard.bool(forKey: "notifications.leaderboardUpdates")
    @State private var teamInvites = UserDefaults.standard.bool(forKey: "notifications.teamInvites")

    var body: some View {
        List {
            Section {
                Toggle("Challenge Reminders", isOn: $challengeReminders)
                Toggle("Streak Reminders", isOn: $streakReminders)
                Toggle("Leaderboard Updates", isOn: $leaderboardUpdates)
                Toggle("Team Invites", isOn: $teamInvites)
            } header: {
                Text("Notification Preferences")
            } footer: {
                Text("Customize which notifications you'd like to receive")
            }

            if !notificationManager.notificationsEnabled {
                Section {
                    Button(action: {
                        Task {
                            await notificationManager.requestNotificationPermission()
                        }
                    }) {
                        Label("Enable Notifications", systemImage: "bell.badge")
                            .foregroundColor(.blue)
                    }
                } footer: {
                    Text("Notifications are currently disabled. Enable them to stay updated on your challenges.")
                }
            }
        }
        .onChange(of: challengeReminders) { _ in updateSettings() }
        .onChange(of: streakReminders) { _ in updateSettings() }
        .onChange(of: leaderboardUpdates) { _ in updateSettings() }
        .onChange(of: teamInvites) { _ in updateSettings() }
    }

    private func updateSettings() {
        notificationManager.updateNotificationSettings(
            challengeReminders: challengeReminders,
            streakReminders: streakReminders,
            leaderboardUpdates: leaderboardUpdates,
            teamInvites: teamInvites
        )
    }
}

// MARK: - Helper Function
@MainActor
private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}
