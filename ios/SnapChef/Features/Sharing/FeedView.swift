import SwiftUI
import CloudKit

struct FeedView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var gamificationManager = GamificationManager.shared
    @State private var showingDiscoverUsers = false
    @State private var showingChallengePopup = false
    @State private var selectedTab: FeedTab = .activity
    @State private var isRefreshing = false
    @State private var didAutoPresentDiscoverUsers = false

    enum FeedTab: String, CaseIterable {
        case activity = "Activity"
        case following = "Following"
        case discover = "Discover"

        var icon: String {
            switch self {
            case .activity: return "bell"
            case .following: return "person.2"
            case .discover: return "sparkles"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Social Stats Header (only show for Activity tab)
                    if selectedTab == .activity {
                        socialStatsHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, 16)
                    }

                    // Tab Selector
                    tabSelector
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // Tab Content
                    tabContent
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingChallengePopup = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#ffa726"), Color(hex: "#ff7043")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Challenges")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingDiscoverUsers = true
                    }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showingDiscoverUsers) {
            // Refresh counts when sheet is dismissed
            Task {
                await refreshUserStats()
            }
        } content: {
            DiscoverUsersView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingChallengePopup) {
            ChallengeQuickPopup()
                .environmentObject(appState)
        }
        .onAppear {
            print("🔍 DEBUG: FeedView appeared")
        }
        .task {
            #if DEBUG
            if !didAutoPresentDiscoverUsers,
               ProcessInfo.processInfo.arguments.contains("-presentDiscoverChefs") {
                didAutoPresentDiscoverUsers = true
                // Present after the first frame so the navigation stack is ready.
                try? await Task.sleep(nanoseconds: 250_000_000)
                await MainActor.run {
                    showingDiscoverUsers = true
                }
            }
            #endif

            // Load initial data in parallel
            async let userStatsTask = refreshUserStats()
            
            // No need to pre-warm here since each tab view manages its own loading
            await userStatsTask
        }
        .refreshable {
            // Pull to refresh - get latest data
            await refreshUserStats()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh when app becomes active
            Task {
                await refreshUserStats()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.userProfileUpdated)) { notification in
            // Refresh when a user profile is updated
            Task {
                await refreshUserStats()
            }
        }
    }

    private func refreshUserStats() async {
        // Only refresh if authenticated
        guard UnifiedAuthManager.shared.isAuthenticated else {
            print("⚠️ FeedView: Skipping refresh - user not authenticated")
            return
        }
        
        isRefreshing = true
        // Update social counts (followers/following)
        await UnifiedAuthManager.shared.updateSocialCounts()
        // Update recipe counts
        await UnifiedAuthManager.shared.updateRecipeCounts()
        // Reload user data
        await UnifiedAuthManager.shared.refreshCurrentUser()
        isRefreshing = false
    }

    private var socialStatsHeader: some View {
        VStack(spacing: 16) {
            // User Info Row
            HStack(spacing: 16) {
                // Profile Image
                if let user = UnifiedAuthManager.shared.currentUser {
                    UserAvatarView(
                        userID: user.recordID,
                        username: user.username,
                        displayName: user.displayName,
                        size: 60
                    )
                }

                // Stats
                HStack(spacing: 24) {
                    socialStatItem(
                        count: UnifiedAuthManager.shared.currentUser?.followerCount ?? 0,
                        label: "Followers"
                    )

                    socialStatItem(
                        count: UnifiedAuthManager.shared.currentUser?.followingCount ?? 0,
                        label: "Following"
                    )

                    socialStatItem(
                        count: UnifiedAuthManager.shared.currentUser?.recipesCreated ?? 0,
                        label: "Recipes"
                    )
                }

                Spacer()
            }

            // Discover Button
            Button(action: {
                showingDiscoverUsers = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Discover Chefs")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private func socialStatItem(count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FeedTab.allCases, id: \.self) { tab in
                    tabPill(tab)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func tabPill(_ tab: FeedTab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(selectedTab == tab ? Color(hex: "#667eea") : Color.white.opacity(0.1))
            )
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .activity:
            ActivityFeedView()
                .environmentObject(appState)
        case .following:
            SocialRecipeFeedView()
                .environmentObject(appState)
        case .discover:
            DiscoverUsersView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Challenge Quick Popup

struct ChallengeQuickPopup: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var gamificationManager = GamificationManager.shared
    @StateObject private var authManager = UnifiedAuthManager.shared
    @State private var selectedChallenge: Challenge?
    @State private var animationScale: CGFloat = 0.8
    @State private var animationOpacity: Double = 0
    
    private var featuredChallenges: [Challenge] {
        Array(gamificationManager.activeChallenges.prefix(3))
    }
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dismiss()
                    }
                }
            
            // Popup content
            VStack(spacing: 0) {
                // Handle bar
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                // Header
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#ffa726"), Color(hex: "#ff7043")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Active Challenges")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Text("Join challenges and earn rewards!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 24)
                
                if featuredChallenges.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "target")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("No Active Challenges")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Check back soon for new challenges!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                } else {
                    // Challenges list
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(featuredChallenges) { challenge in
                                ChallengeQuickCard(challenge: challenge) {
                                    selectedChallenge = challenge
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxHeight: 300)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    // View All Challenges button
                    NavigationLink(destination: ChallengeHubView()) {
                        HStack(spacing: 8) {
                            Image(systemName: "trophy.circle")
                                .font(.headline)
                            Text("View All Challenges")
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
                    
                    // Cancel button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dismiss()
                        }
                    }) {
                        Text("Close")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(radius: 20)
            )
            .padding(.horizontal, 16)
            .scaleEffect(animationScale)
            .opacity(animationOpacity)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    animationScale = 1.0
                    animationOpacity = 1.0
                }
            }
        }
        .sheet(item: $selectedChallenge) { challenge in
            ChallengeDetailView(challenge: challenge)
        }
    }
}

// MARK: - Challenge Quick Card

struct ChallengeQuickCard: View {
    let challenge: Challenge
    let onTap: () -> Void
    
    private var progressColor: Color {
        switch challenge.type {
        case .daily:
            return Color(hex: "#4facfe")
        case .weekly:
            return Color(hex: "#f093fb")
        case .special:
            return Color(hex: "#fa709a")
        case .community:
            return Color(hex: "#feca57")
        }
    }
    
    private var typeIcon: String {
        switch challenge.type {
        case .daily:
            return "sun.max.fill"
        case .weekly:
            return "calendar.badge.clock"
        case .special:
            return "star.fill"
        case .community:
            return "person.3.fill"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Type icon
                ZStack {
                    Circle()
                        .fill(progressColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: typeIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(progressColor)
                }
                
                // Challenge info
                VStack(alignment: .leading, spacing: 6) {
                    Text(challenge.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(challenge.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 12) {
                        Label("\(challenge.points) pts", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(progressColor)
                        
                        Label(challenge.timeRemaining, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Progress indicator
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .trim(from: 0, to: challenge.currentProgress)
                            .stroke(progressColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(challenge.currentProgress * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(progressColor)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(progressColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let userProfileUpdated = Notification.Name("userProfileUpdated")
}

#Preview {
    FeedView()
        .environmentObject(AppState())
}
