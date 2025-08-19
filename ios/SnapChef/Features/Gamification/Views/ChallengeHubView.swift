import SwiftUI

struct ChallengeHubView: View {
    @StateObject private var gamificationManager = GamificationManager.shared
    @StateObject private var premiumManager = PremiumChallengeManager.shared
    @StateObject private var authManager = CloudKitAuthManager.shared
    @StateObject private var authTrigger = AuthPromptTrigger.shared
    @EnvironmentObject var appState: AppState
    @State private var selectedFilter: ChallengeFilter = .all
    @State private var showingDailyCheckIn = false
    @State private var selectedChallenge: Challenge?
    @State private var refreshID = UUID()
    @State private var hasPromptedForNotifications = false
    @State private var showingPremiumView = false
    @State private var showingAuthPrompt = false

    private enum ChallengeFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case completed = "Completed"
        case premium = "Premium"

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .active: return "flame.fill"
            case .completed: return "checkmark.circle.fill"
            case .premium: return "crown.fill"
            }
        }
    }

    private var filteredChallenges: [Challenge] {
        let challenges: [Challenge]
        switch selectedFilter {
        case .all:
            let allChallenges = gamificationManager.activeChallenges + gamificationManager.completedChallenges
            challenges = premiumManager.isPremiumUser ? allChallenges + premiumManager.premiumChallenges : allChallenges
        case .active:
            challenges = gamificationManager.activeChallenges
        case .completed:
            challenges = gamificationManager.completedChallenges
        case .premium:
            challenges = premiumManager.premiumChallenges
        }

        // Apply blur overlay for non-authenticated users
        return challenges
    }

    private var shouldBlurChallenges: Bool {
        return !authManager.isAuthenticated
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
                            .blur(radius: shouldBlurChallenges ? 3 : 0)
                            .overlay(
                                shouldBlurChallenges ? challengeAuthOverlay : nil
                            )
                    }
                    .padding()
                }
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        NavigationLink(destination: LeaderboardView()) {
                            Image(systemName: "trophy.fill")
                                .font(.body)
                                .foregroundColor(.primary)
                        }

                        // Analytics view not implemented in production
                        // Challenge analytics are tracked locally via UserDefaults

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
            }
            .sheet(isPresented: $showingDailyCheckIn) {
                DailyCheckInView()
            }
            .sheet(item: $selectedChallenge) { challenge in
                ChallengeDetailView(challenge: challenge)
            }
            .sheet(isPresented: $showingPremiumView) {
                PremiumFeaturesView()
            }
            .sheet(isPresented: $authManager.showAuthSheet) {
                CloudKitAuthView(requiredFor: .challenges)
            }
            .sheet(isPresented: $showingAuthPrompt) {
                ProgressiveAuthPrompt()
            }
        }
        .onAppear {
            print("🔍 DEBUG: ChallengeHubView appeared")
            // Track that user viewed challenges for progressive auth
            appState.trackAnonymousAction(.challengeViewed)

            // Note: Basic challenge viewing is allowed for anonymous users
            // Premium features require authentication

            // Create mock challenges if needed
            if gamificationManager.activeChallenges.isEmpty {
                Task {
                    await ChallengeService.shared.createMockChallenges()
                }
            }

            // Trigger challenge sync when challenges page is visited
            Task {
                await CloudKitSyncService.shared.triggerChallengeSync()
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
                        Text("\(gamificationManager.userStats.totalPoints % 1_000)/1000 XP")
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
                                    width: geometry.size.width * Double(gamificationManager.userStats.totalPoints % 1_000) / 1_000.0,
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
        ScrollView(.horizontal, showsIndicators: false) {
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
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Challenges List
    private var challengesList: some View {
        VStack(spacing: 16) {
            // Premium banner for non-premium users
            if !premiumManager.isPremiumUser && selectedFilter == .all {
                premiumBanner
            }

            if filteredChallenges.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredChallenges) { challenge in
                    if challenge.isPremium {
                        PremiumChallengeCard(
                            challenge: challenge,
                            isLocked: !premiumManager.isPremiumUser
                        ) {
                            if premiumManager.isPremiumUser {
                                handleChallengeInteraction(challenge: challenge)
                            } else {
                                showingPremiumView = true
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    } else {
                        ChallengeCardView(challenge: challenge) {
                            handleChallengeInteraction(challenge: challenge)
                        }
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
            }
        }
    }

    // MARK: - Premium Banner
    private var premiumBanner: some View {
        Button(action: { showingPremiumView = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(Color(hex: "#FFD700"))
                        Text("Unlock Premium Challenges")
                            .font(.headline)
                            .foregroundColor(.white)
                    }

                    Text("Get 2x rewards and exclusive challenges")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FFD700").opacity(0.3),
                                Color(hex: "#FFD700").opacity(0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#FFD700"), lineWidth: 1)
                    )
            )
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
        case .premium:
            return premiumManager.premiumChallenges.count
        }
    }

    private func refreshChallenges() {
        Task {
            try? await ChallengeService.shared.syncChallenges()
            refreshID = UUID()
        }
    }

    // MARK: - Progressive Authentication Methods

    private func handleChallengeInteraction(challenge: Challenge) {
        if !authManager.isAuthenticated {
            // Track the interaction
            appState.trackAnonymousAction(.challengeViewed)

            // Trigger progressive authentication prompt
            authTrigger.onChallengeInterest()

            // Show the prompt if conditions are met
            if authTrigger.shouldShowPrompt {
                showingAuthPrompt = true
            }
        } else {
            selectedChallenge = challenge
        }
    }

    // MARK: - Challenge Auth Overlay

    private var challengeAuthOverlay: some View {
        VStack(spacing: 20) {
            Spacer()

            GlassmorphicCard(content: {
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#ffa726"), Color(hex: "#ff7043")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Join Cooking Challenges")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Sign in to participate in daily challenges, earn rewards, and compete with other chefs!")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    Button(action: {
                        authTrigger.onChallengeInterest()
                        showingAuthPrompt = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.headline)
                            Text("Sign In to Join")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#ffa726"), Color(hex: "#ff7043")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(24)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }, glowColor: Color(hex: "#ffa726"))
            .padding(.horizontal, 20)

            Spacer()
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
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 15))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? Color(hex: "#667eea") : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white : Color.gray.opacity(0.3))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : Color.primary.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minWidth: 80)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color(hex: "#667eea") : Color.gray.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Analytics View (Not Implemented)
// Challenge analytics service not available in production
// Analytics data is stored locally in UserDefaults for potential future use
/*
struct AnalyticsView: View {
    // Analytics service not implemented
    
    var body: some View {
        ZStack {
            MagicalBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header Stats
                    HStack(spacing: 16) {
                        AnalyticsStatCard(
                            title: "Challenges",
                            value: "\(analytics.userEngagement.totalChallengesStarted)",
                            icon: "target",
                            color: Color(hex: "#667eea")
                        )
                        
                        AnalyticsStatCard(
                            title: "Completion",
                            value: String(format: "%.0f%%", analytics.userEngagement.completionRate * 100),
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }
                    
                    HStack(spacing: 16) {
                        AnalyticsStatCard(
                            title: "Coins Earned",
                            value: "\(analytics.userEngagement.totalCoinsEarned)",
                            icon: "bitcoinsign.circle.fill",
                            color: .yellow
                        )
                        
                        AnalyticsStatCard(
                            title: "Daily Avg",
                            value: "\(Int(analytics.userEngagement.averageDailyTime / 60))m",
                            icon: "clock.fill",
                            color: .orange
                        )
                    }
                    
                    // Daily Metrics
                    GlassmorphicCard(content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Activity")
                                .font(.headline)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Started")
                                    Text("\(analytics.dailyMetrics.challengesStarted)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading) {
                                    Text("Completed")
                                    Text("\(analytics.dailyMetrics.challengesCompleted)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading) {
                                    Text("Coins")
                                    Text("\(analytics.dailyMetrics.coinsEarned)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        .padding()
                    }, glowColor: Color(hex: "#667eea"))
                    
                    // Performance Insights
                    if !analytics.performanceInsights.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Insights")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(analytics.performanceInsights.prefix(3)) { insight in
                                HStack(spacing: 12) {
                                    Image(systemName: insight.icon)
                                        .font(.title3)
                                        .foregroundColor(insight.type.color)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            Circle()
                                                .fill(insight.type.color.opacity(0.2))
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(insight.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text(insight.message)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.1))
                                )
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
    }
}
*/

private struct AnalyticsStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        GlassmorphicCard(content: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                    Spacer()
                }

                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }, glowColor: color.opacity(0.3))
    }
}

// MARK: - Preview
struct ChallengeHubView_Previews: PreviewProvider {
    static var previews: some View {
        ChallengeHubView()
    }
}
