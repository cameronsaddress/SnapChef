import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var challengeReminders = true
    @State private var streakReminders = true
    @State private var leaderboardUpdates = true
    @State private var teamInvites = true
    @State private var quietHoursEnabled = true
    @State private var monthlySendTime = Date()
    @State private var auditReport: NotificationAuditReport?
    @State private var isRefreshingAudit = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Challenge Reminders", isOn: $challengeReminders)
                    Toggle("Streak Reminders", isOn: $streakReminders)
                    Toggle("Leaderboard Updates", isOn: $leaderboardUpdates)
                    Toggle("Team Invites", isOn: $teamInvites)
                } header: {
                    Text("Notification Preferences")
                } footer: {
                    Text("Configure your notification preferences. Push delivery is capped to one notification per month.")
                }
                
                Section {
                    HStack {
                        Label("Monthly Limit", systemImage: "bell.badge")
                        Spacer()
                        Text("1 notification max")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    HStack {
                        Label("Monthly Day", systemImage: "calendar")
                        Spacer()
                        Text("1st of month")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    DatePicker(
                        "Send Time",
                        selection: $monthlySendTime,
                        displayedComponents: .hourAndMinute
                    )

                    Toggle("Quiet Hours (10 PM - 8 AM)", isOn: $quietHoursEnabled)

                    HStack {
                        Label("Next Scheduled", systemImage: "clock")
                        Spacer()
                        Text(nextScheduleDisplay)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("Monthly Schedule")
                } footer: {
                    Text("Monthly engagement notifications are normalized to daytime hours (9:00 AM to 6:00 PM local time). Quiet hours are \(quietHoursEnabled ? "enabled" : "disabled").")
                }
                
                Section {
                    HStack {
                        Label("Policy Status", systemImage: auditReport?.isHealthy == false ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        Spacer()
                        Text(auditReport?.isHealthy == false ? "Needs attention" : "Healthy")
                            .foregroundColor(auditReport?.isHealthy == false ? .orange : .green)
                            .font(.caption.weight(.semibold))
                    }
                    
                    HStack {
                        Label("Authorization", systemImage: "hand.raised.fill")
                        Spacer()
                        Text(authorizationText(auditReport?.authorizationStatus))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Label("Pending Requests", systemImage: "tray.full.fill")
                        Spacer()
                        Text("\(auditReport?.pendingCount ?? 0)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Label("Queued for Future", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        Spacer()
                        Text("\(auditReport?.queueCount ?? 0)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Label("Reserved Month Slot", systemImage: "calendar.badge.clock")
                        Spacer()
                        Text(reservationDisplay)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    if let report = auditReport, !report.items.isEmpty {
                        ForEach(report.items.prefix(6)) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.identifier)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(item.title.isEmpty ? "No title" : item.title)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                HStack(spacing: 8) {
                                    Text(item.deliveryPolicy == .monthlyEngagement ? "Monthly" : "Transactional")
                                    Text(item.nextTriggerDate.map(formatDate) ?? "No next trigger")
                                    Text(item.repeats ? "Repeats" : "One-shot")
                                    Text(item.appearsMonthlyCompliant ? "Monthly window" : "Outside monthly window")
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if let report = auditReport, !report.violations.isEmpty {
                        ForEach(report.violations, id: \.self) { violation in
                            Label(violation, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Button {
                        Task {
                            await refreshAudit()
                        }
                    } label: {
                        HStack {
                            if isRefreshingAudit {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh Audit")
                        }
                    }
                    .disabled(isRefreshingAudit)
                    
                    Button {
                        notificationManager.scheduleMonthlyEngagementNotification()
                        Task {
                            try? await Task.sleep(nanoseconds: 350_000_000)
                            await refreshAudit()
                        }
                    } label: {
                        Label("Rebuild Monthly Schedule", systemImage: "wand.and.stars")
                    }
                } header: {
                    Text("Delivery Audit")
                } footer: {
                    Text("Runtime validation of pending notifications and monthly anti-spam policy.")
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: saveAndDismiss)
                }
            }
        }
        .onAppear {
            let manager = NotificationManager.shared
            let prefs = manager.preferences
            challengeReminders = prefs.challengeReminders
            streakReminders = prefs.streakReminders
            leaderboardUpdates = prefs.leaderboardUpdates
            teamInvites = prefs.teamInvites
            quietHoursEnabled = prefs.quietHoursEnabled
            monthlySendTime = calendarDate(
                hour: prefs.streakReminderTime.hour,
                minute: prefs.streakReminderTime.minute
            )
            Task {
                await refreshAudit()
            }
        }
    }

    private var nextScheduleDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: nextMonthlyDate())
    }

    private func saveAndDismiss() {
        var prefs = notificationManager.preferences
        prefs.challengeReminders = challengeReminders
        prefs.streakReminders = streakReminders
        prefs.leaderboardUpdates = leaderboardUpdates
        prefs.teamInvites = teamInvites
        prefs.quietHoursEnabled = quietHoursEnabled

        let components = Calendar.current.dateComponents([.hour, .minute], from: monthlySendTime)
        prefs.streakReminderTime.hour = components.hour ?? 10
        prefs.streakReminderTime.minute = components.minute ?? 30

        notificationManager.updatePreferences(prefs)
        dismiss()
    }
    
    private var reservationDisplay: String {
        guard let report = auditReport, let date = report.monthlyReservationDate else {
            return "None"
        }
        return "\(formatDate(date)) (\(report.monthlyReservationCount))"
    }
    
    private func authorizationText(_ status: UNAuthorizationStatus?) -> String {
        guard let status else { return "Unknown" }
        switch status {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @MainActor
    private func refreshAudit() async {
        isRefreshingAudit = true
        await notificationManager.refreshPendingNotifications()
        auditReport = await notificationManager.generateAuditReport()
        isRefreshingAudit = false
    }

    private func nextMonthlyDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let time = Calendar.current.dateComponents([.hour, .minute], from: monthlySendTime)
        let preferredHour = time.hour ?? 10
        let preferredMinute = time.minute ?? 30

        let normalizedHour = (9...18).contains(preferredHour) ? preferredHour : 10
        let normalizedMinute = min(max(preferredMinute, 0), 59)

        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = 1
        components.hour = normalizedHour
        components.minute = normalizedMinute

        let currentMonthCandidate = calendar.date(from: components) ?? now
        if currentMonthCandidate > now {
            return currentMonthCandidate
        }

        let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        var nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
        nextComponents.day = 1
        nextComponents.hour = normalizedHour
        nextComponents.minute = normalizedMinute
        return calendar.date(from: nextComponents) ?? now
    }

    private func calendarDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

#Preview {
    NotificationSettingsView()
}
