import SwiftUI

struct ChallengeHubView: View {
    @StateObject private var gamificationManager = GamificationManager.shared
    @State private var selectedFilter: ChallengeFilter = .all
    @State private var showingDailyCheckIn = false
    @State private var selectedChallenge: Challenge?
    @State private var refreshID = UUID()
    @State private var hasPromptedForNotifications = false
    
    private enum ChallengeFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case completed = "Completed"
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .active: return "flame.fill"
            case .completed: return "checkmark.circle.fill"
            }
        }
    }
    
    private var filteredChallenges: [Challenge] {
        switch selectedFilter {
        case .all:
            return gamificationManager.activeChallenges + gamificationManager.completedChallenges
        case .active:
            return gamificationManager.activeChallenges
        case .completed:
            return gamificationManager.completedChallenges
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Stats Card
                        headerStatsCard
                        
                        // Daily Check-in Banner
                        if !gamificationManager.hasCheckedInToday {
                            dailyCheckInBanner
                        }
                        
                        // Filter Tabs
                        filterTabs
                        
                        // Challenges List
                        challengesList
                    }
                    .padding()
                }
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            refreshChallenges()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingDailyCheckIn) {
                DailyCheckInView()
            }
            .sheet(item: $selectedChallenge) { challenge in
                ChallengeDetailView(challenge: challenge)
            }
        }
        .onAppear {
            // Create mock challenges if needed
            if gamificationManager.activeChallenges.isEmpty {
                Task {
                    await ChallengeService.shared.createMockChallenges()
                }
            }
            
            // Prompt for notifications if not already enabled
            if !hasPromptedForNotifications && !ChallengeNotificationManager.shared.notificationsEnabled {
                hasPromptedForNotifications = true
                Task {
                    await ChallengeNotificationManager.shared.requestNotificationPermission()
                }
            }
        }
        .id(refreshID)
    }
    
    // MARK: - Header Stats Card
    private var headerStatsCard: some View {
        GlassmorphicCard(content: {
            VStack(spacing: 16) {
                HStack {
                    Text("Your Progress")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Level Badge
                    HStack(spacing: 4) {
                        Image(systemName: "shield.fill")
                            .font(.title3)
                            .foregroundColor(Color(hex: "#667eea"))
                        Text("Level \(gamificationManager.userStats.level)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                
                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatItem(
                        icon: "flame.fill",
                        value: "\(gamificationManager.userStats.currentStreak)",
                        label: "Day Streak",
                        color: .orange
                    )
                    
                    StatItem(
                        icon: "trophy.fill",
                        value: "\(gamificationManager.userStats.challengesCompleted)",
                        label: "Completed",
                        color: .yellow
                    )
                    
                    StatItem(
                        icon: "star.fill",
                        value: "\(gamificationManager.userStats.totalPoints)",
                        label: "Points",
                        color: Color(hex: "#667eea")
                    )
                }
                
                // Progress to next level
                VStack(spacing: 8) {
                    HStack {
                        Text("Level Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(gamificationManager.userStats.totalPoints % 1000)/1000 XP")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geometry.size.width * Double(gamificationManager.userStats.totalPoints % 1000) / 1000.0,
                                    height: 6
                                )
                                .animation(.spring(), value: gamificationManager.userStats.totalPoints)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding()
        }, glowColor: Color(hex: "#667eea"))
    }
    
    // MARK: - Daily Check-in Banner
    private var dailyCheckInBanner: some View {
        Button(action: {
            showingDailyCheckIn = true
        }) {
            GlassmorphicCard(content: {
                HStack {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Check-in Available!")
                            .font(.headline)
                        Text("Keep your streak alive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
                .padding()
            }, glowColor: .orange)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Filter Tabs
    private var filterTabs: some View {
        HStack(spacing: 12) {
            ForEach(ChallengeFilter.allCases, id: \.self) { filter in
                FilterTab(
                    title: filter.rawValue,
                    icon: filter.icon,
                    isSelected: selectedFilter == filter,
                    count: getCountForFilter(filter)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedFilter = filter
                    }
                }
            }
        }
    }
    
    // MARK: - Challenges List
    private var challengesList: some View {
        VStack(spacing: 16) {
            if filteredChallenges.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredChallenges) { challenge in
                    ChallengeCardView(challenge: challenge) {
                        selectedChallenge = challenge
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No challenges found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Check back soon for new challenges!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Helper Methods
    private func getCountForFilter(_ filter: ChallengeFilter) -> Int {
        switch filter {
        case .all:
            return gamificationManager.activeChallenges.count + gamificationManager.completedChallenges.count
        case .active:
            return gamificationManager.activeChallenges.count
        case .completed:
            return gamificationManager.completedChallenges.count
        }
    }
    
    private func refreshChallenges() {
        Task {
            try? await ChallengeService.shared.syncChallenges()
            refreshID = UUID()
        }
    }
}

// MARK: - Supporting Views
private struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

private struct FilterTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white : Color.gray.opacity(0.3))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "#667eea") : Color.gray.opacity(0.2))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct ChallengeHubView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengeHubView()
    }
}