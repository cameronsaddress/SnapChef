import SwiftUI

/// Compact streak indicator for displaying in HomeView and other locations
struct StreakIndicatorView: View {
    @StateObject private var streakManager = StreakManager.shared
    let streakType: StreakType
    let showDetails: Bool

    init(streakType: StreakType, showDetails: Bool = true) {
        self.streakType = streakType
        self.showDetails = showDetails
    }

    private var streak: StreakData? {
        streakManager.currentStreaks[streakType]
    }

    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Text(streakType.icon)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                // Streak count
                HStack(spacing: 4) {
                    Text("\(streak?.currentStreak ?? 0)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("🔥")
                        .font(.system(size: 16))
                        .opacity(streak?.isActive ?? false ? 1 : 0.3)

                    if streak?.isFrozen ?? false {
                        Text("❄️")
                            .font(.system(size: 14))
                    }
                }

                if showDetails {
                    Text(streakType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Status indicator
            if let streak = streak {
                VStack(alignment: .trailing, spacing: 2) {
                    if streak.isActive {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Active")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }

                        if showDetails {
                            Text("\(streak.hoursUntilBreak)h left")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    } else {
                        Text("Inactive")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    // Multiplier
                    if streak.multiplier > 1.0 {
                        Text("\(String(format: "%.1fx", streak.multiplier))")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            streak?.isActive ?? false ?
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [.gray.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

/// Compact horizontal list of all streaks
struct AllStreaksIndicator: View {
    @StateObject private var streakManager = StreakManager.shared

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StreakType.allCases, id: \.self) { type in
                    StreakBadge(type: type)
                }
            }
            .padding(.horizontal)
        }
    }
}

/// Individual streak badge
struct StreakBadge: View {
    @StateObject private var streakManager = StreakManager.shared
    let type: StreakType

    private var streak: StreakData? {
        streakManager.currentStreaks[type]
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        streak?.isActive ?? false ?
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .red.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Text(type.icon)
                    .font(.system(size: 28))

                // Streak count badge
                if let streak = streak, streak.currentStreak > 0 {
                    Text("\(streak.currentStreak)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(streak.isActive ? Color.red : Color.gray)
                        )
                        .offset(x: 20, y: -20)
                }

                // Frozen indicator
                if streak?.isFrozen ?? false {
                    Text("❄️")
                        .font(.system(size: 12))
                        .offset(x: -20, y: -20)
                }
            }

            Text(type.displayName.split(separator: " ").first ?? "")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

/// Streak summary card for profile
struct StreakSummaryCard: View {
    @StateObject private var streakManager = StreakManager.shared

    private var activeStreakCount: Int {
        streakManager.currentStreaks.values.filter { $0.isActive }.count
    }

    private var totalStreakDays: Int {
        streakManager.currentStreaks.values.reduce(0) { $0 + $1.currentStreak }
    }

    private var longestStreak: Int {
        streakManager.currentStreaks.values.map { $0.longestStreak }.max() ?? 0
    }

    var body: some View {
        NavigationLink(destination: StreakDetailView()) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("🔥 Streak Summary")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                HStack(spacing: 20) {
                    StatItem(
                        value: "\(activeStreakCount)",
                        label: "Active",
                        color: .green
                    )

                    StatItem(
                        value: "\(totalStreakDays)",
                        label: "Total Days",
                        color: .orange
                    )

                    StatItem(
                        value: "\(longestStreak)",
                        label: "Longest",
                        color: .purple
                    )

                    StatItem(
                        value: String(format: "%.1fx", streakManager.globalMultiplier),
                        label: "Multiplier",
                        color: .blue
                    )
                }

                // Quick streak badges
                AllStreaksIndicator()
                    .padding(.top, 8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.orange.opacity(0.3),
                                        Color.red.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct StatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 20) {
        StreakIndicatorView(streakType: .dailySnap)
        AllStreaksIndicator()
        StreakSummaryCard()
    }
    .padding()
}
