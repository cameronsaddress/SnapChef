import SwiftUI
import CloudKit

// MARK: - User Profile Model
struct UserProfile: Identifiable {
    let id: String
    let username: String
    let displayName: String
    let profileImageURL: String?
    let profileImage: UIImage?
    let followerCount: Int
    let followingCount: Int
    let recipesShared: Int
    let isVerified: Bool
    let isFollowing: Bool
    let bio: String?
    
    var followerText: String {
        if followerCount == 1 {
            return "1 follower"
        } else if followerCount > 1000000 {
            return "\(followerCount / 1000000)M followers"
        } else if followerCount > 1000 {
            return "\(followerCount / 1000)K followers"
        } else {
            return "\(followerCount) followers"
        }
    }
}

// MARK: - Discover Users View
struct DiscoverUsersView: View {
    @StateObject private var viewModel = DiscoverUsersViewModel()
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
                        EmptyDiscoverView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredUsers) { user in
                                    UserDiscoveryCard(
                                        user: user,
                                        onFollow: {
                                            Task {
                                                await viewModel.toggleFollow(user)
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
        .sheet(item: $viewModel.selectedUser) { user in
            // TODO: Show user profile view
            Text("User Profile: \(user.displayName)")
                .presentationDetents([.medium, .large])
        }
    }
    
    private var filteredUsers: [UserProfile] {
        if searchText.isEmpty {
            return viewModel.users
        } else {
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
                                Text(user.displayName.prefix(1).uppercased())
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
                
                VStack(alignment: .leading, spacing: 6) {
                    // Name and Username
                    HStack {
                        Text(user.displayName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text("@\(user.username)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    
                    // Stats
                    HStack(spacing: 16) {
                        Text(user.followerText)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("\(user.recipesShared) recipes")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
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
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
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
    }
}

// MARK: - Empty Discover View
struct EmptyDiscoverView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No chefs found")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Try adjusting your search or\ncheck back later for new chefs")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Discover Users View Model
@MainActor
class DiscoverUsersViewModel: ObservableObject {
    @Published var users: [UserProfile] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var selectedUser: UserProfile?
    
    private let cloudKitAuth = CloudKitAuthManager.shared
    private let cloudKitSync = CloudKitSyncService.shared
    private var lastFetchedRecord: CKRecord?
    
    func loadUsers(for category: DiscoverUsersView.DiscoverCategory) async {
        isLoading = true
        users = []
        lastFetchedRecord = nil
        
        // For now, load mock data
        // TODO: Implement CloudKit queries for different categories
        users = generateMockUsers(for: category)
        hasMore = false
        
        isLoading = false
    }
    
    func loadMore() async {
        guard hasMore && !isLoading else { return }
        
        isLoading = true
        
        // TODO: Implement pagination with CloudKit
        
        isLoading = false
    }
    
    func toggleFollow(_ user: UserProfile) async {
        do {
            if user.isFollowing {
                try await cloudKitAuth.unfollowUser(user.id)
            } else {
                try await cloudKitAuth.followUser(user.id)
            }
            
            // Update local state
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index] = UserProfile(
                    id: user.id,
                    username: user.username,
                    displayName: user.displayName,
                    profileImageURL: user.profileImageURL,
                    profileImage: user.profileImage,
                    followerCount: user.followerCount + (user.isFollowing ? -1 : 1),
                    followingCount: user.followingCount,
                    recipesShared: user.recipesShared,
                    isVerified: user.isVerified,
                    isFollowing: !user.isFollowing,
                    bio: user.bio
                )
            }
        } catch {
            print("Failed to toggle follow: \(error)")
        }
    }
    
    private func generateMockUsers(for category: DiscoverUsersView.DiscoverCategory) -> [UserProfile] {
        switch category {
        case .suggested:
            return [
                UserProfile(
                    id: "user1",
                    username: "chefjulia",
                    displayName: "Julia Child",
                    profileImageURL: nil,
                    profileImage: nil,
                    followerCount: 125000,
                    followingCount: 50,
                    recipesShared: 342,
                    isVerified: true,
                    isFollowing: false,
                    bio: "Bringing French cuisine to your kitchen"
                ),
                UserProfile(
                    id: "user2",
                    username: "ramseycooks",
                    displayName: "Gordon Ramsay",
                    profileImageURL: nil,
                    profileImage: nil,
                    followerCount: 2500000,
                    followingCount: 100,
                    recipesShared: 1523,
                    isVerified: true,
                    isFollowing: false,
                    bio: "Michelin star chef | Hell's Kitchen"
                ),
                UserProfile(
                    id: "user3",
                    username: "homecookjoe",
                    displayName: "Joe's Kitchen",
                    profileImageURL: nil,
                    profileImage: nil,
                    followerCount: 850,
                    followingCount: 432,
                    recipesShared: 67,
                    isVerified: false,
                    isFollowing: false,
                    bio: "Weekend warrior in the kitchen"
                )
            ]
        case .trending:
            return [
                UserProfile(
                    id: "user4",
                    username: "tiktokvegan",
                    displayName: "Vegan Vibes",
                    profileImageURL: nil,
                    profileImage: nil,
                    followerCount: 45000,
                    followingCount: 200,
                    recipesShared: 128,
                    isVerified: false,
                    isFollowing: false,
                    bio: "Plant-based recipes that don't suck"
                )
            ]
        case .newChefs:
            return [
                UserProfile(
                    id: "user5",
                    username: "newbiechef",
                    displayName: "Kitchen Newbie",
                    profileImageURL: nil,
                    profileImage: nil,
                    followerCount: 12,
                    followingCount: 85,
                    recipesShared: 3,
                    isVerified: false,
                    isFollowing: false,
                    bio: "Learning one recipe at a time"
                )
            ]
        case .verified:
            return [
                UserProfile(
                    id: "user6",
                    username: "jamieoliver",
                    displayName: "Jamie Oliver",
                    profileImageURL: nil,
                    profileImage: nil,
                    followerCount: 1800000,
                    followingCount: 150,
                    recipesShared: 892,
                    isVerified: true,
                    isFollowing: false,
                    bio: "Making cooking accessible for everyone"
                )
            ]
        }
    }
}

#Preview {
    DiscoverUsersView()
        .environmentObject(AppState())
}