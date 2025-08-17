import SwiftUI
import UIKit

/// Calendar view showing streak history
struct StreakCalendarView: View {
    let streakType: StreakType
    @StateObject private var streakManager = StreakManager.shared
    @State private var selectedMonth = Date()
    @Environment(\.dismiss) var dismiss

    private var streak: StreakData? {
        streakManager.currentStreaks[streakType]
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month selector
                MonthSelector(selectedMonth: $selectedMonth)
                    .padding()

                // Calendar grid
                CalendarGrid(
                    month: selectedMonth,
                    streakType: streakType,
                    streak: streak
                )

                // Legend
                CalendarLegend()
                    .padding()

                Spacer()
            }
            .navigationTitle("\(streakType.displayName) Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MonthSelector: View {
    @Binding var selectedMonth: Date
    private let calendar = Calendar.current

    var body: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.blue)
            }

            Spacer()

            Text(monthYearString)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .disabled(calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    private func previousMonth() {
        withAnimation {
            selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        }
    }

    private func nextMonth() {
        withAnimation {
            selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        }
    }
}

struct CalendarGrid: View {
    let month: Date
    let streakType: StreakType
    let streak: StreakData?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 8) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)

            // Days grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(getDaysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            streakType: streakType,
                            streak: streak
                        )
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func getDaysInMonth() -> [Date?] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        // Fill remaining days to complete the grid
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }
}

struct DayCell: View {
    let date: Date
    let streakType: StreakType
    let streak: StreakData?

    private let calendar = Calendar.current

    private var dayStatus: DayStatus {
        guard let streak = streak else { return .inactive }

        // Check if date is in the future
        if date > Date() {
            return .future
        }

        // Check if date is today
        if calendar.isDateInToday(date) {
            return streak.isActive && calendar.isDateInToday(streak.lastActivityDate) ? .completed : .today
        }

        // Check if date is within streak period
        if date >= streak.streakStartDate && date <= streak.lastActivityDate {
            // Check if this day was completed
            let daysSinceStart = calendar.dateComponents([.day], from: streak.streakStartDate, to: date).day ?? 0
            if daysSinceStart < streak.currentStreak {
                return .completed
            }
        }

        return .inactive
    }

    private enum DayStatus {
        case completed
        case today
        case missed
        case future
        case inactive

        var backgroundColor: Color {
            switch self {
            case .completed:
                return .green
            case .today:
                return .blue
            case .missed:
                return .red.opacity(0.3)
            case .future, .inactive:
                return Color(UIColor.tertiarySystemBackground)
            }
        }

        var textColor: Color {
            switch self {
            case .completed, .today:
                return .white
            case .missed:
                return .red
            case .future:
                return .secondary
            case .inactive:
                return .primary
            }
        }

        var icon: String? {
            switch self {
            case .completed:
                return "checkmark"
            case .today:
                return "circle.fill"
            case .missed:
                return "xmark"
            default:
                return nil
            }
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(dayStatus.backgroundColor)
                .frame(height: 40)

            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: dayStatus == .today ? .bold : .regular))
                    .foregroundColor(dayStatus.textColor)

                if let icon = dayStatus.icon {
                    Image(systemName: icon)
                        .font(.system(size: 8))
                        .foregroundColor(dayStatus.textColor)
                }
            }
        }
    }
}

struct CalendarLegend: View {
    var body: some View {
        HStack(spacing: 20) {
            LegendItem(color: .green, label: "Completed")
            LegendItem(color: .blue, label: "Today")
            LegendItem(color: .red.opacity(0.3), label: "Missed")
            LegendItem(color: Color(UIColor.tertiarySystemBackground), label: "Inactive")
        }
        .font(.caption)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Views

/// Streak history list view
struct StreakHistoryView: View {
    @StateObject private var streakManager = StreakManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(groupedHistory.keys), id: \.self) { type in
                    Section(header: Label(type.displayName, systemImage: "flame")) {
                        ForEach(groupedHistory[type] ?? []) { history in
                            StreakHistoryRow(history: history)
                        }
                    }
                }
            }
            .navigationTitle("Streak History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var groupedHistory: [StreakType: [StreakHistory]] {
        Dictionary(grouping: streakManager.streakHistory, by: { $0.type })
    }
}

struct StreakHistoryRow: View {
    let history: StreakHistory

    private var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let start = formatter.string(from: history.startDate)
        let end = formatter.string(from: history.endDate)
        return "\(start) - \(end)"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(history.streakLength) days")
                        .font(.headline)

                    if history.wasRestored {
                        Label("Restored", systemImage: "arrow.uturn.backward")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                Text(dateRangeString)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let reason = history.breakReason {
                    Text(reason.displayText)
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            Text("🔥")
                .font(.title2)
                .opacity(history.wasRestored ? 1 : 0.3)
        }
        .padding(.vertical, 4)
    }
}

/// Insurance options view
struct StreakInsuranceView: View {
    let streakType: StreakType
    @StateObject private var streakManager = StreakManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Text("🛡")
                        .font(.system(size: 60))

                    Text("Streak Insurance")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Protect your \(streakType.displayName) streak from accidental breaks")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                // Benefits
                VStack(alignment: .leading, spacing: 12) {
                    InsuranceBenefitRow(icon: "checkmark.shield", text: "Auto-restore streak if broken")
                    InsuranceBenefitRow(icon: "calendar", text: "Valid for 7 days")
                    InsuranceBenefitRow(icon: "bolt.shield", text: "Instant activation")
                    InsuranceBenefitRow(icon: "arrow.clockwise", text: "One-time use per purchase")
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                Spacer()

                // Purchase button
                Button(action: purchaseInsurance) {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "cart.fill")
                            Text("Purchase for 200 Chef Coins")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(isPurchasing || !ChefCoinsManager.shared.canAfford(200))

                if !ChefCoinsManager.shared.canAfford(200) {
                    Text("Not enough Chef Coins")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func purchaseInsurance() {
        isPurchasing = true

        if streakManager.purchaseInsurance(for: streakType) {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            dismiss()
        } else {
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)
            isPurchasing = false
        }
    }
}

struct InsuranceBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 30)

            Text(text)
                .font(.body)

            Spacer()
        }
    }
}

/// Power-up store
struct StreakPowerUpStore: View {
    let streakType: StreakType
    @StateObject private var streakManager = StreakManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(StreakPowerUp.availablePowerUps, id: \.id) { powerUp in
                        PowerUpCard(powerUp: powerUp, streakType: streakType)
                    }
                }
                .padding()
            }
            .navigationTitle("Power-Ups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PowerUpCard: View {
    let powerUp: StreakPowerUp
    let streakType: StreakType
    @StateObject private var streakManager = StreakManager.shared
    @State private var isPurchasing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(powerUp.icon)
                    .font(.title)

                VStack(alignment: .leading, spacing: 4) {
                    Text(powerUp.name)
                        .font(.headline)

                    Text(powerUp.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack {
                Label("\(powerUp.costInCoins) coins", systemImage: "bitcoinsign.circle.fill")
                    .font(.callout)
                    .foregroundColor(.yellow)

                Spacer()

                Button(action: { purchasePowerUp(powerUp) }) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                    } else {
                        Text("Buy")
                            .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(ChefCoinsManager.shared.canAfford(powerUp.costInCoins) ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(!ChefCoinsManager.shared.canAfford(powerUp.costInCoins) || isPurchasing)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func purchasePowerUp(_ powerUp: StreakPowerUp) {
        isPurchasing = true

        if streakManager.activatePowerUp(powerUp, for: streakType) {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            isPurchasing = false
        } else {
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)
            isPurchasing = false
        }
    }
}

#Preview {
    StreakCalendarView(streakType: .dailySnap)
}
