import SwiftUI

struct NotificationSettingsView: View {
    @State private var challengeReminders = true
    @State private var streakReminders = true
    @State private var leaderboardUpdates = true
    @State private var teamInvites = true
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle("Challenge Reminders", isOn: $challengeReminders)
                    Toggle("Streak Reminders", isOn: $streakReminders)
                    Toggle("Leaderboard Updates", isOn: $leaderboardUpdates)
                    Toggle("Team Invites", isOn: $teamInvites)
                } header: {
                    Text("Notification Preferences")
                } footer: {
                    Text("Configure your notification preferences. The comprehensive notification management system prevents spam and respects quiet hours.")
                }
                
                Section {
                    HStack {
                        Label("Daily Limit", systemImage: "bell.badge")
                        Spacer()
                        Text("5 notifications max")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Label("Quiet Hours", systemImage: "moon")
                        Spacer()
                        Text("10 PM - 8 AM")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("Smart Controls")
                } footer: {
                    Text("Notifications are automatically limited to prevent spam and respect your sleep schedule.")
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Save preferences via NotificationManager
                        let manager = NotificationManager.shared
                        var prefs = manager.preferences
                        prefs.challengeReminders = challengeReminders
                        prefs.streakReminders = streakReminders  
                        prefs.leaderboardUpdates = leaderboardUpdates
                        prefs.teamInvites = teamInvites
                        manager.updatePreferences(prefs)
                    }
                }
            }
        }
        .onAppear {
            // Load current preferences
            let manager = NotificationManager.shared
            let prefs = manager.preferences
            challengeReminders = prefs.challengeReminders
            streakReminders = prefs.streakReminders
            leaderboardUpdates = prefs.leaderboardUpdates
            teamInvites = prefs.teamInvites
        }
    }
}

#Preview {
    NotificationSettingsView()
}