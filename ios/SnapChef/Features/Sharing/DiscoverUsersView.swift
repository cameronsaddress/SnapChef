import SwiftUI
import CloudKit

// MARK: - User Profile Model
struct UserProfile: Identifiable {
    let id: String
    let username: String
    let displayName: String
    let profileImageURL: String?
    let profileImage: UIImage?
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

// MARK: - Discover Users View
struct DiscoverUsersView: View {
    @StateObject private var viewModel = DiscoverUsersViewModel()
    @StateObject private var cloudKitAuth = CloudKitAuthManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: DiscoverCategory = .suggested

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
                            // Debounced search
                            Task {
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                if searchText == newValue {
                                    await viewModel.searchUsers(newValue)
                                }
                            }
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
                                                await viewModel.loadUsers(for: category)
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
                    if viewModel.isLoading && viewModel.users.isEmpty {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Spacer()
                    } else if viewModel.users.isEmpty {
                        EmptyDiscoverView(category: selectedCategory)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredUsers) { user in
                                    UserDiscoveryCard(
                                        user: user,
                                        onFollow: {
                                            if cloudKitAuth.isAuthenticated {
                                                Task {
                                                    await viewModel.toggleFollow(user)
                                                }
                                            } else {
                                                cloudKitAuth.promptAuthForFeature(.socialSharing)
                                            }
                                        },
                                        onTap: {
                                            // Navigate to user profile
                                            viewModel.selectedUser = user
                                        }
                                    )
                                }

                                if viewModel.hasMore {
                                    ProgressView()
                                        .tint(.white)
                                        .padding()
                                        .onAppear {
                                            Task {
                                                await viewModel.loadMore()
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Discover Chefs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Invite friends
                    }) {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .task {
            await viewModel.loadUsers(for: selectedCategory)
        }
        .onAppear {
            Task {
                await viewModel.refreshFollowStatus()
            }
        }
        .sheet(item: $viewModel.selectedUser) { user in
            // User profile view not implemented - showing basic info
            Text("User Profile: \(user.username ?? user.displayName)")
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $cloudKitAuth.showAuthSheet) {
            CloudKitAuthView()
        }
    }

    private var filteredUsers: [UserProfile] {
        if !searchText.isEmpty && !viewModel.searchResults.isEmpty {
            return viewModel.searchResults
        } else if searchText.isEmpty {
            return viewModel.users
        } else {
            // Local filtering as fallback
            return viewModel.users.filter {
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

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Profile Image
                ZStack {
                    if let profileImage = user.profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
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
                                Text((user.username ?? user.displayName).prefix(1).uppercased())
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }

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
                        Text(user.username ?? user.displayName)
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
                        Text(user.followerText)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(user.recipesCreated) recipes")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                // Follow Button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isFollowing.toggle()
                        onFollow()
                    }
                }) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isFollowing ? .white : .black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(isFollowing ? Color.white.opacity(0.2) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isFollowing ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
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

// MARK: - Discover Users View Model
@MainActor
class DiscoverUsersViewModel: ObservableObject {
    @Published var users: [UserProfile] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var selectedUser: UserProfile?
    @Published var searchResults: [UserProfile] = []
    @Published var isSearching = false

    private let cloudKitAuth = CloudKitAuthManager.shared
    private let cloudKitSync = CloudKitSyncService.shared
    private var lastFetchedRecord: CKRecord?
    private var cloudKitUsers: [UserProfile] = []

    func loadUsers(for category: DiscoverUsersView.DiscoverCategory) async {
        isLoading = true
        users = []
        lastFetchedRecord = nil

        // Load CloudKit users only
        await loadCloudKitUsers(for: category)

        // Use only CloudKit users
        users = cloudKitUsers

        hasMore = false
        isLoading = false
    }

    private func loadCloudKitUsers(for category: DiscoverUsersView.DiscoverCategory) async {
        do {
            var fetchedUsers: [CloudKitUser] = []
            
            switch category {
            case .suggested:
                fetchedUsers = try await cloudKitAuth.getSuggestedUsers(limit: 20)
            case .trending:
                fetchedUsers = try await cloudKitAuth.getTrendingUsers(limit: 20)
            case .newChefs:
                // Get the newest 100 users based on recent activity
                fetchedUsers = try await cloudKitAuth.getNewUsers(limit: 100)
            case .verified:
                fetchedUsers = try await cloudKitAuth.getVerifiedUsers(limit: 20)
            }
            
            // Convert to UserProfile and check follow status for each user
            var convertedUsers: [UserProfile] = []
            for cloudKitUser in fetchedUsers {
                var userProfile = convertToUserProfile(cloudKitUser)
                
                // Check actual follow status if authenticated
                if cloudKitAuth.isAuthenticated {
                    userProfile.isFollowing = await cloudKitAuth.isFollowing(userID: userProfile.id)
                }
                
                convertedUsers.append(userProfile)
            }
            
            cloudKitUsers = convertedUsers
        } catch {
            print("Failed to load CloudKit users: \(error)")
            cloudKitUsers = []
        }
    }


    private func convertToUserProfile(_ cloudKitUser: CloudKitUser) -> UserProfile {
        UserProfile(
            id: cloudKitUser.recordID ?? "",
            username: cloudKitUser.username ?? cloudKitUser.displayName.lowercased().replacingOccurrences(of: " ", with: ""),
            displayName: cloudKitUser.displayName,
            profileImageURL: cloudKitUser.profileImageURL,
            profileImage: nil,
            followerCount: cloudKitUser.followerCount,
            followingCount: cloudKitUser.followingCount,
            recipesCreated: cloudKitUser.recipesShared,
            isVerified: cloudKitUser.isVerified,
            isFollowing: false, // Updated after creation based on actual follow status
            bio: nil,
            joinedDate: cloudKitUser.createdAt,
            lastActive: cloudKitUser.lastLoginAt,
            cuisineSpecialty: nil,
            cookingLevel: nil
        )
    }

    func searchUsers(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        // Search CloudKit users only
        do {
            let cloudKitResults = try await cloudKitAuth.searchUsers(query: query)
            
            // Convert to UserProfile and check follow status for each user
            var convertedResults: [UserProfile] = []
            for cloudKitUser in cloudKitResults {
                var userProfile = convertToUserProfile(cloudKitUser)
                
                // Check actual follow status if authenticated
                if cloudKitAuth.isAuthenticated {
                    userProfile.isFollowing = await cloudKitAuth.isFollowing(userID: userProfile.id)
                }
                
                convertedResults.append(userProfile)
            }
            
            searchResults = convertedResults
        } catch {
            print("Failed to search CloudKit users: \(error)")
            searchResults = []
        }

        isSearching = false
    }

    func loadMore() async {
        guard hasMore && !isLoading else { return }

        isLoading = true

        // CloudKit pagination not implemented - using mock data

        isLoading = false
    }

    func toggleFollow(_ user: UserProfile) async {
        // Perform follow/unfollow for CloudKit users
        do {
            if user.isFollowing {
                try await cloudKitAuth.unfollowUser(userID: user.id)
            } else {
                try await cloudKitAuth.followUser(userID: user.id)
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

            print("✅ Toggle follow completed for user: \(user.username ?? user.displayName)")
        } catch {
            print("Failed to toggle follow: \(error)")
        }
    }
    
    /// Refresh follow status for all users when returning to the view
    func refreshFollowStatus() async {
        guard cloudKitAuth.isAuthenticated else { return }
        
        // Refresh follow status for main users list
        for i in 0..<users.count {
            users[i].isFollowing = await cloudKitAuth.isFollowing(userID: users[i].id)
        }
        
        // Refresh follow status for search results
        for i in 0..<searchResults.count {
            searchResults[i].isFollowing = await cloudKitAuth.isFollowing(userID: searchResults[i].id)
        }
    }
}

#Preview {
    DiscoverUsersView()
        .environmentObject(AppState())
}
