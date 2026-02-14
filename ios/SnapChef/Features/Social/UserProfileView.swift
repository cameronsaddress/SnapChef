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
                            if let profileRecordID = user.recordID,
                               !profileRecordID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               profileRecordID != cloudKitAuth.currentUser?.recordID {
                                followButton(userID: profileRecordID)
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
            .navigationTitle(profileNavTitle)
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
        .task {
            await viewModel.loadUserProfile(userID: userID)
            // Update social counts when profile view appears
            await UnifiedAuthManager.shared.updateSocialCounts()
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

    private var profileNavTitle: String {
        if let user = viewModel.userProfile {
            return resolvedDisplayName(for: user)
        }
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "Anonymous Chef" {
            return "Chef"
        }
        return trimmed
    }

    private func isGeneratedHandle(_ rawHandle: String) -> Bool {
        let handle = rawHandle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard handle.hasPrefix("user") else { return false }
        return handle.count <= 10
    }

    private func sanitizedHandle(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutAt = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        let normalized = withoutAt.lowercased()
        let cleaned = normalized.replacingOccurrences(
            of: #"[^a-z0-9_-]+"#,
            with: "",
            options: .regularExpression
        )
        return cleaned.isEmpty ? "chef" : cleaned
    }

    private func resolvedHandle(for user: CloudKitUser) -> String {
        let cloudHandle = (user.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cloudHandle.isEmpty, !isGeneratedHandle(cloudHandle) {
            return sanitizedHandle(from: cloudHandle)
        }

        let passed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !passed.isEmpty, passed != "Anonymous Chef" {
            return sanitizedHandle(from: passed)
        }

        let derived = sanitizedHandle(from: user.displayName)
        return derived
    }

    private func resolvedDisplayName(for user: CloudKitUser) -> String {
        let cloudHandle = (user.username ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cloudHandle.isEmpty, !isGeneratedHandle(cloudHandle) {
            return cloudHandle
        }

        let passed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !passed.isEmpty, passed != "Anonymous Chef" {
            return passed
        }

        let display = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !display.isEmpty {
            return display
        }

        if !cloudHandle.isEmpty {
            return cloudHandle
        }

        return "Chef"
    }

    // MARK: - Profile Header
    private func profileHeader(user: CloudKitUser) -> some View {
        VStack(spacing: 16) {
            // Profile Image using UserAvatarView (same as DiscoverUsersView and SocialFeedView)
            ZStack {
                UserAvatarView(
                    userID: user.recordID,
                    username: user.username,
                    displayName: user.displayName,
                    size: 100
                )

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
                Text(resolvedDisplayName(for: user))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("@\(resolvedHandle(for: user))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

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
                Text("\(user.recipesCreated)")
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
    private func followButton(userID: String) -> some View {
        Button(action: {
            if !cloudKitAuth.isAuthenticated {
                UnifiedAuthManager.shared.promptAuthForFeature(.socialSharing)
                return
            }

            Task {
                await viewModel.toggleFollow(userID: userID)
            }
        }) {
            HStack(spacing: 8) {
                if cloudKitAuth.isAuthenticated {
                    Image(systemName: viewModel.isFollowing ? "person.badge.minus" : "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text(viewModel.isFollowing ? "Unfollow" : "Follow")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Sign In to Follow")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        cloudKitAuth.isAuthenticated
                            ? (viewModel.isFollowing ? Color.gray.opacity(0.3) : Color(hex: "#667eea"))
                            : Color(hex: "#667eea")
                    )
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
    @State private var showingDetail = false
    @State private var fullRecipe: Recipe?
    @State private var isLoadingRecipe = false
    @State private var isLikeAnimating = false
    @StateObject private var cloudKitRecipeManager = CloudKitService.shared
    @StateObject private var likeManager = RecipeLikeManager.shared
    
    // Computed properties for like state from manager
    private var isLiked: Bool {
        likeManager.isRecipeLiked(recipe.id)
    }
    
    private var likeCount: Int {
        likeManager.getLikeCount(for: recipe.id)
    }

    var body: some View {
        Button(action: {
            loadFullRecipe()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Recipe Image with Before/After photos
                ZStack {
                    if let fullRecipe = fullRecipe {
                        // Show RecipePhotoView once we have the full recipe
                        RecipePhotoView(
                            recipe: fullRecipe,
                            height: 120,
                            showLabels: true
                        )
                        .aspectRatio(1, contentMode: .fit)
                        .allowsHitTesting(false) // Prevent nested button interactions
                    } else {
                        // Show gradient placeholder while loading
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
                                Group {
                                    if isLoadingRecipe {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                }
                            )
                    }
                    
                    // Like button overlay
                    VStack {
                        HStack {
                            Spacer()
                            // Interactive like button
                            Button(action: {
                                toggleLike()
                            }) {
                                ZStack {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(isLiked ? .pink : .white)
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(isLiked ? Color.pink.opacity(0.15) : Color.black.opacity(0.3))
                                        )
                                        .scaleEffect(isLikeAnimating ? 1.3 : 1.0)
                                    
                                    // Like count badge - always show to see immediate updates
                                    if likeCount > 0 {
                                        Text("\(likeCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(isLiked ? Color.pink : Color.gray)
                                            )
                                            .offset(x: 18, y: -15)
                                    }
                                }
                            }
                            .padding(8)
                        }
                        Spacer()
                    }
                }

                Text(recipe.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(recipe.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            // Preload the full recipe when the view appears
            await loadFullRecipeAsync()
        }
        .sheet(isPresented: $showingDetail) {
            if let fullRecipe = fullRecipe {
                NavigationStack {
                    RecipeDetailView(recipe: fullRecipe)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingDetail = false
                                }
                                .foregroundColor(.white)
                            }
                        }
                }
            }
        }
    }
    
    private func loadFullRecipe() {
        guard fullRecipe == nil && !isLoadingRecipe else {
            // If we already have the recipe or are loading, just show the sheet
            if fullRecipe != nil {
                showingDetail = true
            }
            return
        }
        
        isLoadingRecipe = true
        Task {
            do {
                // Fetch the full recipe from CloudKit
                let fetchedRecipe = try await cloudKitRecipeManager.fetchRecipe(by: recipe.id)
                await MainActor.run {
                    self.fullRecipe = fetchedRecipe
                    self.isLoadingRecipe = false
                    self.showingDetail = true
                }
            } catch {
                print("Failed to fetch full recipe: \(error)")
                await MainActor.run {
                    // Create a basic recipe as fallback
                    self.fullRecipe = createBasicRecipe(from: recipe)
                    self.isLoadingRecipe = false
                    self.showingDetail = true
                }
            }
        }
    }
    
    private func loadFullRecipeAsync() async {
        guard fullRecipe == nil && !isLoadingRecipe else { return }
        
        isLoadingRecipe = true
        do {
            // Fetch the full recipe from CloudKit
            let fetchedRecipe = try await cloudKitRecipeManager.fetchRecipe(by: recipe.id)
            await MainActor.run {
                self.fullRecipe = fetchedRecipe
                self.isLoadingRecipe = false
            }
        } catch {
            print("Failed to preload full recipe: \(error)")
            await MainActor.run {
                self.isLoadingRecipe = false
            }
        }
    }
    
    private func toggleLike() {
        // Haptic feedback immediately
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Animate button
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            isLikeAnimating = true
        }
        
        // Animate button scale back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isLikeAnimating = false
            }
        }
        
        // Update via manager (handles auth check and optimistic updates)
        Task {
            await likeManager.toggleLike(for: recipe.id)
        }
    }
    
    private func createBasicRecipe(from data: RecipeData) -> Recipe {
        // Note: This is a fallback - the actual Recipe should be loaded from CloudKit
        // The Recipe struct is quite different from RecipeData, so we can't create a proper one
        // This should never actually be shown to the user
        return Recipe(
            id: UUID(uuidString: data.id) ?? UUID(),
            ownerID: nil,
            name: data.title,
            description: "",
            ingredients: [],
            instructions: [],
            cookTime: 30,
            prepTime: 0,
            servings: 2,
            difficulty: .medium,
            nutrition: Nutrition(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: nil, sugar: nil, sodium: nil),
            imageURL: data.imageURL,
            createdAt: data.createdAt,
            tags: [],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false),
            isDetectiveRecipe: false,
            cookingTechniques: [],
            flavorProfile: nil,
            secretIngredients: [],
            proTips: [],
            visualClues: [],
            shareCaption: ""
        )
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
                        Text((user.username ?? user.displayName).prefix(1).uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(user.username ?? user.displayName)
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
                    Text("\(user.recipesCreated)")
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
            UserProfileView(userID: user.recordID ?? "", userName: user.username ?? user.displayName)
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
