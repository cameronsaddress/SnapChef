import SwiftUI
import CloudKit

// MARK: - User Profile Model
struct UserProfile: Identifiable, Codable {
    let id: String
    let username: String
    let displayName: String
    let profileImageURL: String?
    var followerCount: Int
    var followingCount: Int
    let recipesCreated: Int
    let isVerified: Bool
    var isFollowing: Bool
    let bio: String?

    // Additional properties for enhanced profiles
    var joinedDate: Date?
    var lastActive: Date?
    var cuisineSpecialty: String?
    var cookingLevel: String?
    
    // Non-codable properties
    var profileImage: UIImage? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, username, displayName, profileImageURL
        case followerCount, followingCount, recipesCreated
        case isVerified, isFollowing, bio
        case joinedDate, lastActive, cuisineSpecialty, cookingLevel
    }

    var followerText: String {
        if followerCount == 1 {
            return "1 follower"
        } else if followerCount > 1_000_000 {
            return "\(followerCount / 1_000_000)M followers"
        } else if followerCount > 1_000 {
            return "\(followerCount / 1_000)K followers"
        } else {
            return "\(followerCount) followers"
        }
    }
}

// MARK: - Simple Discover Users Manager
@MainActor
class SimpleDiscoverUsersManager: ObservableObject {
    @Published var users: [UserProfile] = []
    @Published var searchResults: [UserProfile] = []
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var hasMore = false
    @Published var selectedUser: UserProfile?
    @Published var showingSkeletonViews = false
    
    func loadUsers(for category: DiscoverUsersView.DiscoverCategory) async {
        showingSkeletonViews = users.isEmpty
        isLoading = true
        
        do {
            var fetchedUsers: [CloudKitUser] = []
            
            switch category {
            case .suggested:
                fetchedUsers = try await UnifiedAuthManager.shared.getSuggestedUsers(limit: 20)
            case .trending:
                fetchedUsers = try await UnifiedAuthManager.shared.getTrendingUsers(limit: 20)
            case .newChefs:
                fetchedUsers = try await UnifiedAuthManager.shared.getNewUsers(limit: 100)
            case .verified:
                fetchedUsers = try await UnifiedAuthManager.shared.getVerifiedUsers(limit: 20)
            }
            
            // Convert to UserProfile
            var convertedUsers: [UserProfile] = []
            for cloudKitUser in fetchedUsers {
                var userProfile = convertToUserProfile(cloudKitUser)
                
                // Check actual follow status if authenticated
                if UnifiedAuthManager.shared.isAuthenticated {
                    userProfile.isFollowing = await UnifiedAuthManager.shared.isFollowing(userID: userProfile.id)
                }
                
                convertedUsers.append(userProfile)
            }
            
            users = convertedUsers
            
        } catch {
            print("❌ Failed to load users: \(error)")
            users = []
        }
        
        showingSkeletonViews = false
        isLoading = false
    }
    
    func searchUsers(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        Task {
            isSearching = true
            
            do {
                let cloudKitResults = try await UnifiedAuthManager.shared.searchUsers(query: query)
                
                var convertedResults: [UserProfile] = []
                for cloudKitUser in cloudKitResults {
                    var userProfile = convertToUserProfile(cloudKitUser)
                    
                    if UnifiedAuthManager.shared.isAuthenticated {
                        userProfile.isFollowing = await UnifiedAuthManager.shared.isFollowing(userID: userProfile.id)
                    }
                    
                    convertedResults.append(userProfile)
                }
                
                await MainActor.run {
                    searchResults = convertedResults
                    isSearching = false
                }
                
            } catch {
                print("❌ Search failed: \(error)")
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
    
    func toggleFollow(_ user: UserProfile) async {
        do {
            if user.isFollowing {
                try await UnifiedAuthManager.shared.unfollowUser(userID: user.id)
            } else {
                try await UnifiedAuthManager.shared.followUser(userID: user.id)
            }
            
            // Update local state
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index].isFollowing.toggle()
                users[index].followerCount += users[index].isFollowing ? 1 : -1
            }
            if let index = searchResults.firstIndex(where: { $0.id == user.id }) {
                searchResults[index].isFollowing.toggle()
                searchResults[index].followerCount += searchResults[index].isFollowing ? 1 : -1
            }
            
        } catch {
            print("❌ Failed to toggle follow: \(error)")
        }
    }
    
    func refreshFollowStatus() async {
        guard UnifiedAuthManager.shared.isAuthenticated else { return }
        
        for i in 0..<users.count {
            users[i].isFollowing = await UnifiedAuthManager.shared.isFollowing(userID: users[i].id)
        }
        
        for i in 0..<searchResults.count {
            searchResults[i].isFollowing = await UnifiedAuthManager.shared.isFollowing(userID: searchResults[i].id)
        }
    }
    
    func loadMore() async {
        // Simple implementation - for now just return since pagination is not fully implemented
        hasMore = false
    }
    
    private func convertToUserProfile(_ cloudKitUser: CloudKitUser) -> UserProfile {
        let finalUsername = cloudKitUser.username ?? cloudKitUser.displayName.lowercased().replacingOccurrences(of: " ", with: "")
        
        return UserProfile(
            id: cloudKitUser.recordID ?? "",
            username: finalUsername,
            displayName: cloudKitUser.displayName,
            profileImageURL: cloudKitUser.profileImageURL,
            followerCount: cloudKitUser.followerCount,
            followingCount: cloudKitUser.followingCount,
            recipesCreated: cloudKitUser.recipesCreated,
            isVerified: cloudKitUser.isVerified,
            isFollowing: false,
            bio: nil,
            joinedDate: cloudKitUser.createdAt,
            lastActive: cloudKitUser.lastLoginAt,
            cuisineSpecialty: nil,
            cookingLevel: nil,
            profileImage: nil
        )
    }
}

// MARK: - Discover Users View
struct DiscoverUsersView: View {
    @StateObject private var manager = SimpleDiscoverUsersManager()
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedCategory: DiscoverCategory = .suggested
    @State private var showAuthSheet = false

    enum DiscoverCategory: String, CaseIterable {
        case suggested = "Suggested"
        case trending = "Trending"
        case newChefs = "New Chefs"
        case verified = "Verified"

        var icon: String {
            switch self {
            case .suggested: return "sparkles"
            case .trending: return "flame"
            case .newChefs: return "person.badge.plus"
            case .verified: return "checkmark.seal.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    SearchBarView(searchText: $searchText)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .onChange(of: searchText) { newValue in
                            manager.searchUsers(newValue)
                        }

                    // Category Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(DiscoverCategory.allCases, id: \.self) { category in
                                DiscoverCategoryPill(
                                    title: category.rawValue,
                                    icon: category.icon,
                                    isSelected: selectedCategory == category,
                                    action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedCategory = category
                                            Task {
                                                await manager.loadUsers(for: category)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)

                    // Users List
                    if manager.showingSkeletonViews && manager.users.isEmpty {
                        // Show skeleton views during initial load
                        DiscoverUsersSkeletonList()
                    } else if manager.isLoading && manager.users.isEmpty {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Spacer()
                    } else if manager.users.isEmpty && !manager.isLoading {
                        EmptyDiscoverView(category: selectedCategory)
                    } else {
                        ScrollView {
                            // Subtle refresh indicator when refreshing with cached data
                            if manager.isLoading && !manager.users.isEmpty {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                    Text("Updating...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)
                            }
                            
                            LazyVStack(spacing: 16) {
                                ForEach(filteredUsers) { user in
                                    UserDiscoveryCard(
                                        user: user,
                                        onFollow: {
                                            if UnifiedAuthManager.shared.isAuthenticated {
                                                Task {
                                                    await manager.toggleFollow(user)
                                                }
                                            } else {
                                                UnifiedAuthManager.shared.promptAuthForFeature(.socialSharing)
                                            }
                                        },
                                        onTap: {
                                            // Navigate to user profile
                                            manager.selectedUser = user
                                        }
                                    )
                                }

                                if manager.hasMore {
                                    ProgressView()
                                        .tint(.white)
                                        .padding()
                                        .onAppear {
                                            Task {
                                                await manager.loadMore()
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        .refreshable {
                            await manager.loadUsers(for: selectedCategory)
                        }
                    }
                }
            }
            .navigationTitle("Discover Chefs")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await manager.loadUsers(for: selectedCategory)
        }
        .onAppear {
            Task {
                await manager.refreshFollowStatus()
            }
        }
        .sheet(item: $manager.selectedUser) { user in
            UserProfileView(
                userID: user.id,
                userName: user.username  // Always use username, not displayName
            )
            .environmentObject(appState)
        }
        .sheet(isPresented: $showAuthSheet) {
            UnifiedAuthView()
        }
    }

    private var filteredUsers: [UserProfile] {
        if !searchText.isEmpty && !manager.searchResults.isEmpty {
            return manager.searchResults
        } else if searchText.isEmpty {
            return manager.users
        } else {
            // Local filtering as fallback
            return manager.users.filter {
                $0.username.localizedCaseInsensitiveContains(searchText) ||
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Search Bar View
struct SearchBarView: View {
    @Binding var searchText: String
    @State private var isEditing = false

    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))

                TextField("Search chefs...", text: $searchText)
                    .foregroundColor(.white)
                    .accentColor(.white)
                    .onTapGesture {
                        withAnimation {
                            isEditing = true
                        }
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )

            if isEditing {
                Button("Cancel") {
                    withAnimation {
                        isEditing = false
                        searchText = ""
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                      to: nil, from: nil, for: nil)
                    }
                }
                .foregroundColor(.white)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.3), value: isEditing)
    }
}

// MARK: - Discover Category Pill
struct DiscoverCategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color(hex: "#667eea") : Color.white.opacity(0.1))
            )
        }
    }
}

// MARK: - User Discovery Card
struct UserDiscoveryCard: View {
    let user: UserProfile
    let onFollow: () -> Void
    let onTap: () -> Void

    @State private var isFollowing: Bool

    init(user: UserProfile, onFollow: @escaping () -> Void, onTap: @escaping () -> Void) {
        self.user = user
        self.onFollow = onFollow
        self.onTap = onTap
        self._isFollowing = State(initialValue: user.isFollowing)
    }
    
    // Computed properties to simplify type-checking
    private var buttonText: String {
        if !UnifiedAuthManager.shared.isAuthenticated {
            return "Sign In to Follow"
        } else if isFollowing {
            return "Following"
        } else {
            return "Follow"
        }
    }
    
    private var buttonTextColor: Color {
        return (isFollowing || !UnifiedAuthManager.shared.isAuthenticated) ? .white : .black
    }
    
    private var buttonMinWidth: CGFloat {
        return UnifiedAuthManager.shared.isAuthenticated ? 80 : 120
    }
    
    private var buttonBackgroundColor: Color {
        if !UnifiedAuthManager.shared.isAuthenticated {
            return Color(hex: "#667eea") // Simplified to single color
        } else if isFollowing {
            return Color.white.opacity(0.2)
        } else {
            return Color.white
        }
    }
    
    private var shouldShowGradient: Bool {
        return !UnifiedAuthManager.shared.isAuthenticated
    }
    
    private var buttonBorderColor: Color {
        return (isFollowing && UnifiedAuthManager.shared.isAuthenticated) ? Color.white.opacity(0.5) : Color.clear
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Profile Image using UserAvatarView (same as SocialFeedView)
                ZStack {
                    UserAvatarView(
                        userID: user.id,
                        username: user.username,
                        displayName: user.displayName,
                        size: 60
                    )

                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .background(Circle().fill(Color.white).frame(width: 24, height: 24))
                            .offset(x: 20, y: 20)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    // Name and Username
                    HStack {
                        Text(user.username)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                    }

                    Text("@\(user.username)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)

                    // Stats
                    HStack(spacing: 12) {
                        Text({
                            let text = user.followerText
                            print("🔍 DEBUG DiscoverUsersView Card - User: \(user.username)")
                            print("    └─ Followers field: user.followerCount = \(user.followerCount)")
                            print("    └─ UserProfile struct field mapping from CloudKit: CKField.User.followerCount")
                            return text
                        }())
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)

                        Text({
                            let text = "\(user.recipesCreated) recipes"
                            print("    └─ Recipes field: user.recipesCreated = \(user.recipesCreated)")
                            print("    └─ UserProfile struct field mapping from CloudKit: CKField.User.recipesCreated")
                            return text
                        }())
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                // Follow Button
                Button(action: {
                    if UnifiedAuthManager.shared.isAuthenticated {
                        withAnimation(.spring(response: 0.3)) {
                            isFollowing.toggle()
                            onFollow()
                        }
                    } else {
                        // Show authentication prompt
                        UnifiedAuthManager.shared.showAuthSheet = true
                    }
                }) {
                    Text(buttonText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(buttonTextColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: buttonMinWidth)
                        .background(
                            Group {
                                if shouldShowGradient {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(buttonBackgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(buttonBorderColor, lineWidth: 1)
                                        )
                                }
                            }
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: user.isFollowing) { newValue in
            isFollowing = newValue
        }
    }
}

// MARK: - Empty Discover View
struct EmptyDiscoverView: View {
    let category: DiscoverUsersView.DiscoverCategory
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: categoryIcon)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))

            Text(categoryTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text(categoryMessage)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
    
    private var categoryIcon: String {
        switch category {
        case .suggested:
            return "sparkles"
        case .trending:
            return "flame"
        case .newChefs:
            return "person.badge.plus"
        case .verified:
            return "checkmark.seal.fill"
        }
    }
    
    private var categoryTitle: String {
        switch category {
        case .suggested:
            return "No suggested chefs"
        case .trending:
            return "No trending chefs"
        case .newChefs:
            return "No new chefs"
        case .verified:
            return "No verified chefs"
        }
    }
    
    private var categoryMessage: String {
        switch category {
        case .suggested:
            return "We're still building our chef\ncommunity. Check back soon!"
        case .trending:
            return "No trending activity yet.\nBe the first to create and share!"
        case .newChefs:
            return "No new chefs have joined recently.\nInvite your friends to join SnapChef!"
        case .verified:
            return "No verified chefs available.\nStay tuned for chef partnerships!"
        }
    }
}

// MARK: - Skeleton Views
struct DiscoverUsersSkeletonList: View {
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { _ in
                DiscoverUserSkeletonCard()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

struct DiscoverUserSkeletonCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image Skeleton
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.1), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                )
            
            VStack(alignment: .leading, spacing: 6) {
                // Name skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 120, height: 16)
                
                // Username skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 80, height: 14)
                
                // Stats skeleton
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 60, height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 50, height: 12)
                }
            }
            
            Spacer()
            
            // Follow button skeleton
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .frame(width: 80, height: 32)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(
                .linear(duration: 2)
                .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    DiscoverUsersView()
        .environmentObject(AppState())
}
