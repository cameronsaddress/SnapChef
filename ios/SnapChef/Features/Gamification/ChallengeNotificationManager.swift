import Foundation
import SwiftUI

// MARK: - Challenge Notification Manager
// TODO: Enable when UserNotifications framework is properly linked
/*
import UserNotifications

@MainActor
class ChallengeNotificationManager: ObservableObject {
    static let shared = ChallengeNotificationManager()
    
    @Published var notificationsEnabled = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    private let notificationCenter = UNNotificationCenter.current()
    private let gamificationManager = GamificationManager.shared
    
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
        static func challengeReminder(_ challengeId: UUID) -> String {
            "challenge_reminder_\(challengeId.uuidString)"
        }
        
        static func challengeComplete(_ challengeId: UUID) -> String {
            "challenge_complete_\(challengeId.uuidString)"
        }
        
        static let dailyStreak = "daily_streak_reminder"
        static let weeklyLeaderboard = "weekly_leaderboard_update"
        static let teamChallengeInvite = "team_challenge_invite"
    }
    
    private init() {
        checkNotificationAuthorization()
        setupNotificationCategories()
    }
    
    // MARK: - Authorization
    
    func requestNotificationPermission() async -> Bool {
        do {
            let authorized = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.notificationsEnabled = authorized
            }
            
            if authorized {
                await setupDefaultNotifications()
            }
            
            return authorized
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }
    
    private func checkNotificationAuthorization() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            await MainActor.run {
                self.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Setup Categories
    
    private func setupNotificationCategories() {
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
        
        notificationCenter.setNotificationCategories([challengeCategory, streakCategory, teamCategory])
    }
    
    // MARK: - Challenge Notifications
    
    func scheduleChallengeReminder(for challenge: Challenge, reminderTime: Date) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Challenge Ending Soon! ⏰"
        content.body = "\"\(challenge.title)\" ends in \(challenge.timeRemaining). Complete it now to earn \(challenge.reward.points) points!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.challengeReminder.rawValue
        content.userInfo = [
            "challengeId": challenge.id.uuidString,
            "challengeType": challenge.type.rawValue
        ]
        
        // Add attachment if possible
        if let imageAttachment = createChallengeImageAttachment(for: challenge) {
            content.attachments = [imageAttachment]
        }
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.challengeReminder(challenge.id),
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling challenge reminder: \(error)")
            }
        }
    }
    
    func notifyChallengeComplete(_ challenge: Challenge, reward: ChallengeReward) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Challenge Complete! 🎉"
        content.body = "You've completed \"\(challenge.title)\" and earned \(reward.points) points!"
        
        if let badge = reward.badge {
            content.subtitle = "New badge unlocked: \(badge)"
        }
        
        content.sound = UNNotificationSound(named: UNNotificationSoundName("celebration.wav"))
        content.categoryIdentifier = NotificationCategory.challengeComplete.rawValue
        
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.challengeComplete(challenge.id),
            content: content,
            trigger: nil // Immediate notification
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Streak Notifications
    
    func scheduleDailyStreakReminder(at time: DateComponents) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Keep Your Streak Alive! 🔥"
        content.body = "You're on a \(gamificationManager.userStats.currentStreak)-day streak. Don't break it now!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakReminder.rawValue
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.dailyStreak,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Leaderboard Notifications
    
    func scheduleWeeklyLeaderboardUpdate() {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Leaderboard Update 📊"
        
        if let rank = gamificationManager.userStats.weeklyRank {
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
        
        notificationCenter.add(request)
    }
    
    // MARK: - Team Challenge Notifications
    
    func notifyTeamChallengeInvite(from userName: String, teamName: String, challengeName: String) {
        guard notificationsEnabled else { return }
        
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
            identifier: "\(NotificationIdentifier.teamChallengeInvite)_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - New Challenge Notifications
    
    func notifyNewChallengeAvailable(_ challenge: Challenge) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "New \(challenge.type.rawValue) Available! ✨"
        content.body = "\"\(challenge.title)\" - \(challenge.description)"
        content.subtitle = "Reward: \(challenge.reward.points) points"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.newChallenge.rawValue
        
        let request = UNNotificationRequest(
            identifier: "new_challenge_\(challenge.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Helper Methods
    
    private func createChallengeImageAttachment(for challenge: Challenge) -> UNNotificationAttachment? {
        // In a real app, this would create or fetch an image for the challenge
        // For now, return nil
        return nil
    }
    
    func cancelNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAllChallengeNotifications() {
        Task {
            let pending = await notificationCenter.pendingNotificationRequests()
            let challengeIdentifiers = pending
                .filter { $0.identifier.contains("challenge_") }
                .map { $0.identifier }
            
            notificationCenter.removePendingNotificationRequests(withIdentifiers: challengeIdentifiers)
        }
    }
    
    func updatePendingNotifications() {
        Task {
            let pending = await notificationCenter.pendingNotificationRequests()
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
            let reminderTime = challenge.endDate.addingTimeInterval(-7200)
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
*/

// Temporary stub implementation
@MainActor
class ChallengeNotificationManager: ObservableObject {
    static let shared = ChallengeNotificationManager()
    
    @Published var notificationsEnabled = false
    @Published var pendingNotifications: [Any] = []
    
    private init() {}
    
    func requestNotificationPermission() async -> Bool {
        return false
    }
    
    func scheduleChallengeReminder(for challenge: Challenge, reminderTime: Date) {}
    
    func notifyChallengeComplete(_ challenge: Challenge, reward: ChallengeReward) {}
    
    func scheduleDailyStreakReminder(at time: DateComponents) {}
    
    func scheduleWeeklyLeaderboardUpdate() {}
    
    func notifyTeamChallengeInvite(from userName: String, teamName: String, challengeName: String) {}
    
    func notifyNewChallengeAvailable(_ challenge: Challenge) {}
    
    func cancelNotification(identifier: String) {}
    
    func cancelAllChallengeNotifications() {}
    
    func updatePendingNotifications() {}
    
    func updateNotificationSettings(
        challengeReminders: Bool,
        streakReminders: Bool,
        leaderboardUpdates: Bool,
        teamInvites: Bool
    ) {}
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
private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}