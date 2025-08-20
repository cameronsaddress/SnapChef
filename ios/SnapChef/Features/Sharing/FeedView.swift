import SwiftUI
import CloudKit

struct FeedView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cloudKitAuth = CloudKitAuthManager.shared
    @State private var showingDiscoverUsers = false
    @State private var selectedTab: FeedTab = .activity
    @State private var isRefreshing = false

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
        .onAppear {
            print("🔍 DEBUG: FeedView appeared")
        }
        .task {
            // Load initial data
            await refreshUserStats()
        }
        .refreshable {
            // Pull to refresh
            await refreshUserStats()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh when app becomes active
            Task {
                await refreshUserStats()
            }
        }
    }

    private func refreshUserStats() async {
        isRefreshing = true
        // Update social counts (followers/following)
        await cloudKitAuth.updateSocialCounts()
        // Update recipe counts
        await cloudKitAuth.updateRecipeCounts()
        // Reload user data
        await cloudKitAuth.refreshCurrentUser()
        isRefreshing = false
    }

    private var socialStatsHeader: some View {
        VStack(spacing: 16) {
            // User Info Row
            HStack(spacing: 16) {
                // Profile Image
                if let user = cloudKitAuth.currentUser {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text((user.username ?? user.displayName ?? "U").prefix(1).uppercased())
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        )
                }

                // Stats
                HStack(spacing: 24) {
                    socialStatItem(
                        count: cloudKitAuth.currentUser?.followerCount ?? 0,
                        label: "Followers"
                    )

                    socialStatItem(
                        count: cloudKitAuth.currentUser?.followingCount ?? 0,
                        label: "Following"
                    )

                    socialStatItem(
                        count: cloudKitAuth.currentUser?.recipesShared ?? 0,
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

#Preview {
    FeedView()
        .environmentObject(AppState())
}
