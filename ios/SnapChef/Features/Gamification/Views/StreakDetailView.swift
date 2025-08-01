import SwiftUI

/// Full-screen view for managing and viewing all streak details
struct StreakDetailView: View {
    @StateObject private var streakManager = StreakManager.shared
    @State private var selectedStreak: StreakType = .dailySnap
    @State private var showingPowerUpStore = false
    @State private var showingHistory = false
    @State private var showingInsuranceOptions = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with multiplier
                StreakHeaderView()
                
                // Streak selector
                StreakTypeSelector(selectedType: $selectedStreak)
                
                // Selected streak details
                if let streak = streakManager.currentStreaks[selectedStreak] {
                    StreakDetailCard(streak: streak, type: selectedStreak)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                
                // Quick actions
                QuickActionsSection(
                    streakType: selectedStreak,
                    showingPowerUpStore: $showingPowerUpStore,
                    showingInsuranceOptions: $showingInsuranceOptions
                )
                
                // Achievements
                if !streakManager.unclaimedAchievements.isEmpty {
                    UnclaimedAchievementsSection()
                }
                
                // History button
                Button(action: { showingHistory = true }) {
                    Label("View Streak History", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Streaks")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingPowerUpStore) {
            StreakPowerUpStore(streakType: selectedStreak)
        }
        .sheet(isPresented: $showingHistory) {
            StreakHistoryView()
        }
        .sheet(isPresented: $showingInsuranceOptions) {
            StreakInsuranceView(streakType: selectedStreak)
        }
    }
}

/// Header showing global multiplier and stats
struct StreakHeaderView: View {
    @StateObject private var streakManager = StreakManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Global Multiplier")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(String(format: "%.2fx", streakManager.globalMultiplier))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Earn more points and coins with active streaks!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

/// Horizontal selector for streak types
struct StreakTypeSelector: View {
    @Binding var selectedType: StreakType
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StreakType.allCases, id: \.self) { type in
                    StreakTypeButton(
                        type: type,
                        isSelected: selectedType == type,
                        action: { 
                            withAnimation(.spring()) {
                                selectedType = type
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct StreakTypeButton: View {
    let type: StreakType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(type.icon)
                    .font(.system(size: 24))
                
                Text(type.displayName)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(width: 80, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color(UIColor.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Detailed card for selected streak
struct StreakDetailCard: View {
    let streak: StreakData
    let type: StreakType
    @State private var showingCalendar = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Current streak
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Streak")
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Text("\(streak.currentStreak)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("days")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    if streak.isActive {
                        Label("\(streak.hoursUntilBreak) hours left", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Label("Inactive", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                // Visual indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: streak.progressToNextMilestone)
                        .stroke(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    Text(type.icon)
                        .font(.system(size: 36))
                }
            }
            
            Divider()
            
            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StreakStatCard(
                    title: "Longest",
                    value: "\(streak.longestStreak)",
                    subtitle: "days",
                    color: .purple
                )
                
                StreakStatCard(
                    title: "Total Active",
                    value: "\(streak.totalDaysActive)",
                    subtitle: "days",
                    color: .green
                )
                
                StreakStatCard(
                    title: "Multiplier",
                    value: String(format: "%.2fx", streak.multiplier),
                    subtitle: "bonus",
                    color: .blue
                )
                
                StreakStatCard(
                    title: "Freezes",
                    value: "\(streak.freezesRemaining)",
                    subtitle: "remaining",
                    color: .cyan
                )
            }
            
            // Next milestone
            if let nextMilestone = streak.nextMilestone {
                NextMilestoneCard(
                    milestone: nextMilestone,
                    currentStreak: streak.currentStreak
                )
            }
            
            // Calendar button
            Button(action: { showingCalendar = true }) {
                Label("View Calendar", systemImage: "calendar")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
        .sheet(isPresented: $showingCalendar) {
            StreakCalendarView(streakType: type)
        }
    }
}

struct StreakStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

struct NextMilestoneCard: View {
    let milestone: StreakMilestone
    let currentStreak: Int
    
    private var daysToGo: Int {
        milestone.days - currentStreak
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Next Milestone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text(milestone.badge)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(milestone.title)
                            .font(.headline)
                        Text("\(daysToGo) days to go")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(milestone.coins)")
                    .font(.headline)
                    .foregroundColor(.yellow)
                Text("coins")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
}

/// Quick actions section
struct QuickActionsSection: View {
    let streakType: StreakType
    @Binding var showingPowerUpStore: Bool
    @Binding var showingInsuranceOptions: Bool
    @StateObject private var streakManager = StreakManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Freeze button
                    if let streak = streakManager.currentStreaks[streakType],
                       !streak.isFrozen && streak.freezesRemaining > 0 {
                        StreakActionButton(
                            icon: "❄️",
                            title: "Freeze",
                            subtitle: "\(streak.freezesRemaining) left",
                            color: .cyan,
                            action: {
                                _ = streakManager.freezeStreak(type: streakType)
                            }
                        )
                    }
                    
                    // Insurance button
                    StreakActionButton(
                        icon: "🛡",
                        title: "Insurance",
                        subtitle: "Protect streak",
                        color: .green,
                        action: { showingInsuranceOptions = true }
                    )
                    
                    // Power-ups button
                    StreakActionButton(
                        icon: "⚡",
                        title: "Power-Ups",
                        subtitle: "Boost streak",
                        color: .purple,
                        action: { showingPowerUpStore = true }
                    )
                }
                .padding(.horizontal)
            }
        }
    }
}

struct StreakActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(icon)
                    .font(.title2)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, height: 80)
            .background(color.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Unclaimed achievements section
struct UnclaimedAchievementsSection: View {
    @StateObject private var streakManager = StreakManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unclaimed Rewards")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(streakManager.unclaimedAchievements) { achievement in
                UnclaimedAchievementRow(achievement: achievement)
            }
        }
    }
}

struct UnclaimedAchievementRow: View {
    let achievement: StreakAchievement
    @StateObject private var streakManager = StreakManager.shared
    @State private var isClaimed = false
    
    var body: some View {
        HStack {
            Text(achievement.milestoneBadge)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.milestoneTitle)
                    .font(.headline)
                Text("\(achievement.type.displayName) - \(achievement.milestoneDays) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isClaimed {
                Button(action: {
                    withAnimation {
                        streakManager.claimAchievementRewards(achievement)
                        isClaimed = true
                    }
                }) {
                    VStack(spacing: 2) {
                        Text("+\(achievement.milestoneCoins)")
                            .font(.headline)
                            .foregroundColor(.yellow)
                        Text("Claim")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    NavigationView {
        StreakDetailView()
    }
}