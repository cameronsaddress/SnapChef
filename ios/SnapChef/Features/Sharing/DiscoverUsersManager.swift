import SwiftUI
import CloudKit

import Combine

@MainActor
class DiscoverUsersManager: ObservableObject {
    @Published var users: [UserProfile] = []
    @Published var searchResults: [UserProfile] = []
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var hasMore = false
    @Published var selectedUser: UserProfile?
    @Published var showingSkeletonViews = false
    
    private let cloudKitSync = CloudKitSyncService.shared
    private let cloudKitActor = CloudKitSyncService.shared.cloudKitActor
    private var lastFetchedRecord: CKRecord?
    private var currentCategory: DiscoverUsersView.DiscoverCategory = .suggested
    
    // Cache configuration
    private let usersCacheKey = "DiscoverUsersCache"
    private let usersCacheTimestampKey = "DiscoverUsersCacheTimestamp"
    private let usersCacheTTL: TimeInterval = 600 // 10 minutes
    
    private let followStateCacheKey = "FollowStateCache"
    private let followStateCacheTimestampKey = "FollowStateCacheTimestamp"
    private let followStateTTL: TimeInterval = 300 // 5 minutes
    
    // Memory management
    private let maxCacheSize = 200
    private let pageSize = 20
    
    // Smart refresh
    private var lastRefreshTime: Date?
    private let minimumRefreshInterval: TimeInterval = 30 // 30 seconds
    
    // Search debouncing
    private var searchTask: Task<Void, Never>?
    
    // Memory management
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupMemoryWarningHandler()
    }
    
    private func setupMemoryWarningHandler() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryWarning() {
        print("⚠️ Memory warning received - clearing caches")
        
        // Clear image cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear user caches
        let cacheKeys = [
            "\(usersCacheKey)_Suggested",
            "\(usersCacheKey)_Trending",
            "\(usersCacheKey)_New Chefs",
            "\(usersCacheKey)_Verified",
            followStateCacheKey
        ]
        
        for key in cacheKeys {
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults.standard.removeObject(forKey: "\(key)Timestamp")
        }
        
        // Reduce in-memory users if needed
        if users.count > pageSize {
            let keepCount = min(pageSize, users.count)
            users = Array(users.prefix(keepCount))
        }
        
        if searchResults.count > pageSize {
            searchResults = Array(searchResults.prefix(pageSize))
        }
        
        print("✅ Memory cleanup complete")
    }
    
    func loadUsers(for category: DiscoverUsersView.DiscoverCategory) async {
        print("🔍 DEBUG: loadUsers started for category: \(category)")
        
        // Don't reload if already loading
        guard !isLoading else {
            print("⚠️ Already loading, skipping...")
            return
        }
        
        currentCategory = category
        currentPage = 0
        allLoadedUsers = []
        hasMore = true
        
        // Check if we have valid cached data first
        if loadCachedUsers(for: category) {
            print("⚡ Using cached data for \(category)")
            // Still refresh in background if cache is getting old
            if shouldRefreshInBackground() {
                Task {
                    await fetchUsersInBackground(for: category)
                }
            }
            return
        }
        
        // Show skeleton views for initial load
        await MainActor.run {
            showingSkeletonViews = users.isEmpty
            isLoading = true
        }
        
        await fetchUsers(for: category)
    }
    
    private func fetchUsers(for category: DiscoverUsersView.DiscoverCategory) async {
        do {
            // PHASE 1: Parallel data loading with async let
            async let usersTask = fetchCategoryUsers(category, page: 0)
            async let followStatesTask = fetchBatchFollowStates()
            
            // Wait for both operations to complete
            let (fetchedUsers, followStates) = await (usersTask, followStatesTask)
            
            // Process and update UI
            let processedUsers = await processUsers(fetchedUsers, with: followStates)
            
            await MainActor.run {
                self.users = processedUsers
                self.showingSkeletonViews = false
                self.isLoading = false
                self.lastRefreshTime = Date()
            }
            
            // Cache the results
            cacheUsers(processedUsers, for: category)
            
        } catch {
            print("❌ Failed to fetch users: \(error)")
            await MainActor.run {
                self.users = []
                self.showingSkeletonViews = false
                self.isLoading = false
            }
        }
    }
    
    
    private func fetchBatchFollowStates() async -> [String: Bool] {
        guard UnifiedAuthManager.shared.isAuthenticated else {
            return [:]
        }
        
        // Get all user IDs from current users and any cached users
        var userIds = Set<String>()
        for user in users {
            userIds.insert(user.id)
        }
        
        // Batch fetch follow states
        return await batchCheckFollowStatus(Array(userIds))
    }
    
    private func batchCheckFollowStatus(_ userIds: [String]) async -> [String: Bool] {
        guard !userIds.isEmpty else { return [:] }
        
        do {
            // Create batch query for all follow states
            let database = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase
            let currentUserID = UnifiedAuthManager.shared.currentUser?.recordID ?? ""
            
            // CloudKit has a limit on predicate complexity, so we'll chunk if needed
            let chunkSize = 50
            var allFollowStates: [String: Bool] = [:]
            
            for chunk in userIds.chunked(into: chunkSize) {
                let predicate = NSPredicate(
                    format: "followerID == %@ AND followingID IN %@ AND isActive == 1",
                    currentUserID,
                    chunk
                )
                let query = CKQuery(recordType: "Follow", predicate: predicate)
                
                let results = try await cloudKitActor.executeQuery(query, in: database)
                
                // Mark followed users
                for result in results {
                    if let followingID = result["followingID"] as? String {
                        allFollowStates[followingID] = true
                    }
                }
            }
            
            // Fill in false for users not being followed
            for userId in userIds {
                if allFollowStates[userId] == nil {
                    allFollowStates[userId] = false
                }
            }
            
            return allFollowStates
            
        } catch {
            print("❌ Failed to batch fetch follow states: \(error)")
            return [:]
        }
    }
    
    private func processUsers(_ cloudKitUsers: [CloudKitUser], with followStates: [String: Bool]) async -> [UserProfile] {
        var processedUsers: [UserProfile] = []
        
        for cloudKitUser in cloudKitUsers {
            // Get actual social counts from Follow records
            var updatedUser = cloudKitUser
            if let userID = cloudKitUser.recordID {
                async let followerCount = getActualFollowerCount(userID: userID)
                async let followingCount = getActualFollowingCount(userID: userID)
                
                let (followers, following) = await (followerCount, followingCount)
                updatedUser.followerCount = followers
                updatedUser.followingCount = following
            }
            
            // Convert to UserProfile
            var userProfile = convertToUserProfile(updatedUser)
            
            // Set follow state
            userProfile.isFollowing = followStates[userProfile.id] ?? false
            
            processedUsers.append(userProfile)
        }
        
        return processedUsers
    }
    
    private func convertToUserProfile(_ cloudKitUser: CloudKitUser) -> UserProfile {
        let finalUsername = cloudKitUser.username ?? cloudKitUser.displayName.lowercased().replacingOccurrences(of: " ", with: "")
        
        return UserProfile(
            id: cloudKitUser.recordID ?? "",
            username: finalUsername,
            displayName: cloudKitUser.displayName,
            profileImageURL: cloudKitUser.profilePictureURL,
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
    
    private func getActualFollowerCount(userID: String) async -> Int {
        do {
            let database = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase
            let predicate = NSPredicate(format: "followingID == %@ AND isActive == 1", userID)
            let query = CKQuery(recordType: "Follow", predicate: predicate)
            
            let results = try await cloudKitActor.executeQuery(query, in: database)
            return results.count
        } catch {
            print("❌ Failed to get follower count: \(error)")
            return 0
        }
    }
    
    private func getActualFollowingCount(userID: String) async -> Int {
        do {
            let database = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase
            let predicate = NSPredicate(format: "followerID == %@ AND isActive == 1", userID)
            let query = CKQuery(recordType: "Follow", predicate: predicate)
            
            let results = try await cloudKitActor.executeQuery(query, in: database)
            return results.count
        } catch {
            print("❌ Failed to get following count: \(error)")
            return 0
        }
    }
    
    // MARK: - Caching
    
    private func loadCachedUsers(for category: DiscoverUsersView.DiscoverCategory) -> Bool {
        let cacheKey = "\(usersCacheKey)_\(category.rawValue)"
        let timestampKey = "\(usersCacheTimestampKey)_\(category.rawValue)"
        
        guard let cacheTimestamp = UserDefaults.standard.object(forKey: timestampKey) as? Date else {
            return false
        }
        
        let cacheAge = Date().timeIntervalSince(cacheTimestamp)
        if cacheAge > usersCacheTTL {
            return false
        }
        
        guard let cachedData = UserDefaults.standard.data(forKey: cacheKey),
              let cachedUsers = try? JSONDecoder().decode([UserProfile].self, from: cachedData) else {
            return false
        }
        
        users = cachedUsers
        return true
    }
    
    private func cacheUsers(_ users: [UserProfile], for category: DiscoverUsersView.DiscoverCategory) {
        let cacheKey = "\(usersCacheKey)_\(category.rawValue)"
        let timestampKey = "\(usersCacheTimestampKey)_\(category.rawValue)"
        
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: timestampKey)
        }
    }
    
    private func shouldRefreshInBackground() -> Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: "\(usersCacheTimestampKey)_\(currentCategory.rawValue)") as? Date else {
            return true
        }
        
        let cacheAge = Date().timeIntervalSince(timestamp)
        return cacheAge > (usersCacheTTL / 2) // Refresh if cache is halfway to expiry
    }
    
    private func fetchUsersInBackground(for category: DiscoverUsersView.DiscoverCategory) async {
        // Silently fetch fresh data without updating UI
        do {
            async let usersTask = fetchCategoryUsers(category, page: 0)
            async let followStatesTask = fetchBatchFollowStates()
            
            let (fetchedUsers, followStates) = await (usersTask, followStatesTask)
            let processedUsers = await processUsers(fetchedUsers, with: followStates)
            
            // Only update cache, not UI
            cacheUsers(processedUsers, for: category)
            
        } catch {
            print("❌ Background refresh failed: \(error)")
        }
    }
    
    // MARK: - Search
    
    func searchUsers(_ query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            // Debounce for 300ms
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isSearching = true
            }
            
            await performSearch(query)
        }
    }
    
    private func performSearch(_ query: String) async {
        do {
            let cloudKitResults = try await UnifiedAuthManager.shared.searchUsers(query: query)
            
            // Get follow states for search results
            let userIds = cloudKitResults.compactMap { $0.recordID }
            let followStates = await batchCheckFollowStatus(userIds)
            
            let processedResults = await processUsers(cloudKitResults, with: followStates)
            
            await MainActor.run {
                searchResults = processedResults
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
    
    // MARK: - Follow Actions
    
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
            
            // Invalidate follow state cache
            UserDefaults.standard.removeObject(forKey: followStateCacheKey)
            UserDefaults.standard.removeObject(forKey: followStateCacheTimestampKey)
            
        } catch {
            print("❌ Failed to toggle follow: \(error)")
        }
    }
    
    func refreshFollowStatus() async {
        guard UnifiedAuthManager.shared.isAuthenticated else { return }
        
        let allUserIds = Array(Set(users.map { $0.id } + searchResults.map { $0.id }))
        let followStates = await batchCheckFollowStatus(allUserIds)
        
        // Update main users list
        for i in 0..<users.count {
            users[i].isFollowing = followStates[users[i].id] ?? false
        }
        
        // Update search results
        for i in 0..<searchResults.count {
            searchResults[i].isFollowing = followStates[searchResults[i].id] ?? false
        }
    }
    
    // MARK: - Pagination
    
    private var currentPage = 0
    private var allLoadedUsers: [UserProfile] = []
    
    func loadMore() async {
        guard !isLoading && hasMore else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Fetch next page of users
            let nextPageUsers = try await fetchCategoryUsers(currentCategory, page: currentPage + 1)
            
            if nextPageUsers.isEmpty {
                await MainActor.run {
                    hasMore = false
                    isLoading = false
                }
                return
            }
            
            // Get follow states for new users
            let userIds = nextPageUsers.compactMap { $0.recordID }
            let followStates = await batchCheckFollowStatus(userIds)
            
            // Process new users
            let processedUsers = await processUsers(nextPageUsers, with: followStates)
            
            await MainActor.run {
                // Append to users list
                self.users.append(contentsOf: processedUsers)
                self.allLoadedUsers.append(contentsOf: processedUsers)
                self.currentPage += 1
                self.hasMore = processedUsers.count >= pageSize
                self.isLoading = false
                
                // Memory management - keep only recent users
                if self.users.count > maxCacheSize {
                    let excess = self.users.count - maxCacheSize
                    self.users.removeFirst(excess)
                }
            }
            
        } catch {
            print("❌ Failed to load more users: \(error)")
            await MainActor.run {
                self.hasMore = false
                self.isLoading = false
            }
        }
    }
    
    private func fetchCategoryUsers(_ category: DiscoverUsersView.DiscoverCategory, page: Int = 0) async throws -> [CloudKitUser] {
        // Note: Pagination with offset to be implemented in UnifiedAuthManager
        // For now, we'll get the first page only
        if page > 0 {
            return [] // Return empty for subsequent pages until offset is implemented
        }
        
        switch category {
        case .suggested:
            return try await UnifiedAuthManager.shared.getSuggestedUsers(limit: pageSize)
        case .trending:
            return try await UnifiedAuthManager.shared.getTrendingUsers(limit: pageSize)
        case .newChefs:
            return try await UnifiedAuthManager.shared.getNewUsers(limit: pageSize * 5) // Get more for new users
        case .verified:
            return try await UnifiedAuthManager.shared.getVerifiedUsers(limit: pageSize)
        }
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}