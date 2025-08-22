import SwiftUI
import CloudKit

struct UserProfileView: View {
    let userID: String
    let userName: String

    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = UserProfileViewModel()
    @StateObject private var cloudKitAuth = UnifiedAuthManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab = 0
    @State private var showingFollowers = false
    @State private var showingFollowing = false

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.userProfile == nil {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else if let user = viewModel.userProfile {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Profile Header
                            profileHeader(user: user)

                            // Stats Section
                            statsSection(user: user)

                            // Follow/Following Button
                            if user.recordID != cloudKitAuth.currentUser?.recordID {
                                followButton(user: user)
                            }

                            // Content Tabs
                            contentTabs(user: user)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        Text("Unable to load profile")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .navigationTitle(userName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            print("🔍 DEBUG: UserProfileView appeared")
        }
        .task {
            await viewModel.loadUserProfile(userID: userID)
        }
        .sheet(isPresented: $showingFollowers) {
            FollowListView(userID: userID, mode: .followers)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingFollowing) {
            FollowListView(userID: userID, mode: .following)
                .environmentObject(appState)
        }
    }

    // MARK: - Profile Header
    private func profileHeader(user: CloudKitUser) -> some View {
        VStack(spacing: 16) {
            // Profile Image
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Text((user.username ?? user.displayName ?? "U").prefix(1).uppercased())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)

                if user.isVerified {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "#43e97b"))
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 30, height: 30)
                                )
                        }
                        Spacer()
                    }
                    .frame(width: 100, height: 100)
                }
            }

            // User Info
            VStack(spacing: 8) {
                Text(user.username ?? user.displayName ?? "Chef")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let username = user.username {
                    Text("@\(username)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                // Member Since
                Text("Member since \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Stats Section
    private func statsSection(user: CloudKitUser) -> some View {
        HStack(spacing: 0) {
            // Followers
            Button(action: { showingFollowers = true }) {
                VStack(spacing: 4) {
                    Text("\(user.followerCount)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Followers")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            // Following
            Button(action: { showingFollowing = true }) {
                VStack(spacing: 4) {
                    Text("\(user.followingCount)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Following")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            // Recipes
            VStack(spacing: 4) {
                Text("\(user.recipesShared)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Recipes")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Follow Button
    private func followButton(user: CloudKitUser) -> some View {
        Button(action: {
            Task {
                await viewModel.toggleFollow(userID: user.recordID!)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isFollowing ? "person.badge.minus" : "person.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                Text(viewModel.isFollowing ? "Unfollow" : "Follow")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.isFollowing ? Color.gray.opacity(0.3) : Color(hex: "#667eea"))
            )
        }
        .disabled(viewModel.isLoadingFollow)
    }

    // MARK: - Content Tabs
    private func contentTabs(user: CloudKitUser) -> some View {
        VStack(spacing: 0) {
            // Tab Selector
            HStack(spacing: 0) {
                ForEach(0..<3) { index in
                    Button(action: { selectedTab = index }) {
                        VStack(spacing: 8) {
                            Image(systemName: index == 0 ? "fork.knife" : index == 1 ? "trophy" : "chart.bar.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(selectedTab == index ? .white : .white.opacity(0.5))

                            Text(index == 0 ? "Recipes" : index == 1 ? "Achievements" : "Stats")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(selectedTab == index ? .white : .white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedTab == index ?
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                            : nil
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )

            // Tab Content
            Group {
                switch selectedTab {
                case 0:
                    recipesTab
                case 1:
                    achievementsTab(user: user)
                case 2:
                    statsTab(user: user)
                default:
                    EmptyView()
                }
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Recipes Tab
    private var recipesTab: some View {
        Group {
            if viewModel.userRecipes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No recipes shared yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(minHeight: 200)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(viewModel.userRecipes) { recipe in
                        RecipeGridItem(recipe: recipe)
                    }
                }
            }
        }
    }

    // MARK: - Achievements Tab
    private func achievementsTab(user: CloudKitUser) -> some View {
        VStack(spacing: 20) {
            // Achievement badges
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.achievements) { achievement in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(achievement.isUnlocked ? Color(hex: "#43e97b").opacity(0.2) : Color.white.opacity(0.1))
                                .frame(width: 60, height: 60)

                            Text(achievement.icon)
                                .font(.system(size: 28))
                                .opacity(achievement.isUnlocked ? 1 : 0.3)
                        }

                        Text(achievement.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(achievement.isUnlocked ? .white : .white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
            }

            // Level Progress
            VStack(spacing: 12) {
                HStack {
                    Text("Chef Level")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Level \(viewModel.calculateLevel(points: user.totalPoints))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#43e97b"))
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#43e97b"), Color(hex: "#38f9d7")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * viewModel.levelProgress(points: user.totalPoints), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(user.totalPoints) XP")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("\(viewModel.pointsToNextLevel(points: user.totalPoints)) to next level")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    // MARK: - Stats Tab
    private func statsTab(user: CloudKitUser) -> some View {
        VStack(spacing: 16) {
            StatRow(icon: "flame.fill", label: "Current Streak", value: "\(user.currentStreak) days", color: Color(hex: "#f093fb"))
            StatRow(icon: "star.fill", label: "Total Points", value: "\(user.totalPoints)", color: Color(hex: "#667eea"))
            StatRow(icon: "trophy.fill", label: "Challenges Won", value: "\(user.challengesCompleted)", color: Color(hex: "#ffd93d"))
            StatRow(icon: "heart.fill", label: "Total Likes", value: "\(viewModel.totalLikes)", color: Color(hex: "#ff6b6b"))
            StatRow(icon: "clock.fill", label: "Cooking Time", value: "\(viewModel.totalCookingTime) mins", color: Color(hex: "#4facfe"))
        }
    }
}

// MARK: - Recipe Grid Item
struct RecipeGridItem: View {
    let recipe: RecipeData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Recipe Image
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 12))
                                Text("\(recipe.likeCount)")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.5))
                            )
                            .padding(8)
                        }
                    }
                )

            Text(recipe.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(recipe.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
            }

            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Follow List View
struct FollowListView: View {
    let userID: String
    let mode: FollowMode

    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = FollowListViewModel()
    @Environment(\.dismiss) var dismiss

    enum FollowMode {
        case followers
        case following

        var title: String {
            switch self {
            case .followers: return "Followers"
            case .following: return "Following"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else if viewModel.users.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: mode == .followers ? "person.2.slash" : "person.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        Text(mode == .followers ? "No followers yet" : "Not following anyone")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.users) { user in
                                UserListRow(user: user)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            print("🔍 DEBUG: FollowListView appeared")
        }
        .task {
            await viewModel.loadUsers(userID: userID, mode: mode)
        }
    }
}

// MARK: - User List Row
struct UserListRow: View {
    let user: CloudKitUser
    @State private var showingProfile = false

    var body: some View {
        Button(action: { showingProfile = true }) {
            HStack(spacing: 16) {
                // Profile Image
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text((user.username ?? user.displayName ?? "U").prefix(1).uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(user.username ?? user.displayName ?? "Chef")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#43e97b"))
                        }
                    }

                    if let username = user.username {
                        Text("@\(username)")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Stats
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(user.recipesShared)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("recipes")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingProfile) {
            UserProfileView(userID: user.recordID ?? "", userName: user.username ?? user.displayName ?? "Chef")
        }
    }
}

// MARK: - Recipe Data Model
struct RecipeData: Identifiable {
    let id: String
    let title: String
    let imageURL: String?
    let likeCount: Int
    let createdAt: Date
}

// MARK: - Achievement Model
struct UserAchievement: Identifiable {
    let id: String
    let title: String
    let icon: String
    let isUnlocked: Bool
}

#Preview {
    UserProfileView(userID: "test-user", userName: "Test Chef")
        .environmentObject(AppState())
}
