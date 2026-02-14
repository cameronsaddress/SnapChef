import SwiftUI
import CloudKit
import UIKit

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
    // SINGLETON: Shared instance for background preloading
    static let shared = SimpleDiscoverUsersManager()
    
    @Published var users: [UserProfile] = []
    @Published var searchResults: [UserProfile] = []
    
    // Memory management limits
    private let maxUsers = 100
    private let maxSearchResults = 50
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var hasMore = false
    @Published var selectedUser: UserProfile?
    @Published var showingSkeletonViews = false
    
    // Cache configuration
    private let cacheKey = "DiscoverUsersCache"
    private let cacheTimestampKey = "DiscoverUsersCacheTimestamp"
    // Cache CloudKit discovery for a while to keep the UI snappy, but still allow periodic freshness.
    private let cacheTTL: TimeInterval = 6 * 60 * 60 // 6 hours
    private var lastRefreshTime: Date?
    private let minimumRefreshInterval: TimeInterval = 30 // 30 seconds
    private var currentCategory: DiscoverUsersView.DiscoverCategory = .suggested

    private func fallbackUsers(for category: DiscoverUsersView.DiscoverCategory) -> [UserProfile] {
        let now = Date()

        let suggested = [
            UserProfile(id: "local_alex", username: "alexplates", displayName: "Alex Plates", profileImageURL: nil, followerCount: 12400, followingCount: 312, recipesCreated: 186, isVerified: true, isFollowing: false, bio: "Weeknight meals under 20 minutes.", joinedDate: now.addingTimeInterval(-86400 * 320), lastActive: now.addingTimeInterval(-60 * 18), cuisineSpecialty: "Quick Meals", cookingLevel: "Pro", profileImage: nil),
            UserProfile(id: "local_maya", username: "mayaspice", displayName: "Maya Spice", profileImageURL: nil, followerCount: 9800, followingCount: 220, recipesCreated: 142, isVerified: false, isFollowing: false, bio: "Flavor-heavy, pantry-friendly recipes.", joinedDate: now.addingTimeInterval(-86400 * 240), lastActive: now.addingTimeInterval(-60 * 35), cuisineSpecialty: "Global Fusion", cookingLevel: "Advanced", profileImage: nil),
            UserProfile(id: "local_ryan", username: "ryanroasts", displayName: "Ryan Roasts", profileImageURL: nil, followerCount: 7600, followingCount: 145, recipesCreated: 97, isVerified: false, isFollowing: false, bio: "Big trays, low effort, huge flavor.", joinedDate: now.addingTimeInterval(-86400 * 180), lastActive: now.addingTimeInterval(-60 * 42), cuisineSpecialty: "Roasting", cookingLevel: "Intermediate", profileImage: nil)
        ]

        let trending = [
            UserProfile(id: "local_lena", username: "lenasizzle", displayName: "Lena Sizzle", profileImageURL: nil, followerCount: 22300, followingCount: 410, recipesCreated: 228, isVerified: true, isFollowing: false, bio: "High-protein comfort food.", joinedDate: now.addingTimeInterval(-86400 * 410), lastActive: now.addingTimeInterval(-60 * 7), cuisineSpecialty: "High Protein", cookingLevel: "Pro", profileImage: nil),
            UserProfile(id: "local_jules", username: "julesbakes", displayName: "Jules Bakes", profileImageURL: nil, followerCount: 17900, followingCount: 298, recipesCreated: 211, isVerified: true, isFollowing: false, bio: "Desserts that actually work at home.", joinedDate: now.addingTimeInterval(-86400 * 510), lastActive: now.addingTimeInterval(-60 * 11), cuisineSpecialty: "Desserts", cookingLevel: "Pro", profileImage: nil),
            UserProfile(id: "local_kai", username: "kaifirewok", displayName: "Kai Firewok", profileImageURL: nil, followerCount: 15100, followingCount: 260, recipesCreated: 165, isVerified: false, isFollowing: false, bio: "One-pan meals with big crunch.", joinedDate: now.addingTimeInterval(-86400 * 270), lastActive: now.addingTimeInterval(-60 * 26), cuisineSpecialty: "Wok Cooking", cookingLevel: "Advanced", profileImage: nil)
        ]

        let newChefs = [
            UserProfile(id: "local_nia", username: "niakitchen", displayName: "Nia Kitchen", profileImageURL: nil, followerCount: 1200, followingCount: 94, recipesCreated: 34, isVerified: false, isFollowing: false, bio: "Fresh takes on family classics.", joinedDate: now.addingTimeInterval(-86400 * 18), lastActive: now.addingTimeInterval(-60 * 9), cuisineSpecialty: "Family Meals", cookingLevel: "Intermediate", profileImage: nil),
            UserProfile(id: "local_omar", username: "omartastes", displayName: "Omar Tastes", profileImageURL: nil, followerCount: 980, followingCount: 76, recipesCreated: 29, isVerified: false, isFollowing: false, bio: "Street-food flavor at home.", joinedDate: now.addingTimeInterval(-86400 * 11), lastActive: now.addingTimeInterval(-60 * 13), cuisineSpecialty: "Street Food", cookingLevel: "Intermediate", profileImage: nil),
            UserProfile(id: "local_sam", username: "sammealprep", displayName: "Sam Meal Prep", profileImageURL: nil, followerCount: 860, followingCount: 55, recipesCreated: 26, isVerified: false, isFollowing: false, bio: "Budget meal prep for busy weeks.", joinedDate: now.addingTimeInterval(-86400 * 7), lastActive: now.addingTimeInterval(-60 * 21), cuisineSpecialty: "Meal Prep", cookingLevel: "Beginner", profileImage: nil)
        ]

        let verified = (suggested + trending).filter(\.isVerified)

        switch category {
        case .suggested:
            return suggested
        case .trending:
            return trending
        case .newChefs:
            return newChefs
        case .verified:
            return verified
        }
    }

    private func applyLocalFallback(for category: DiscoverUsersView.DiscoverCategory) {
        users = fallbackUsers(for: category)
        searchResults = []
        hasMore = false
        showingSkeletonViews = false
        isLoading = false
    }

    // MARK: - CloudKit Read-Only Discovery

    private func publicUserQuery(for category: DiscoverUsersView.DiscoverCategory) -> CKQuery {
        switch category {
        case .suggested:
            let predicate = NSPredicate(format: "%K == %d", CKField.User.isProfilePublic, 1)
            let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: CKField.User.followerCount, ascending: false)]
            return query
        case .trending:
            let predicate = NSPredicate(format: "%K == %d", CKField.User.isProfilePublic, 1)
            let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: CKField.User.recipesShared, ascending: false)]
            return query
        case .newChefs:
            let predicate = NSPredicate(format: "%K == %d", CKField.User.isProfilePublic, 1)
            let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: CKField.User.createdAt, ascending: false)]
            return query
        case .verified:
            let predicate = NSPredicate(
                format: "%K == %d AND %K == %d",
                CKField.User.isVerified, 1,
                CKField.User.isProfilePublic, 1
            )
            let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: CKField.User.followerCount, ascending: false)]
            return query
        }
    }

    private func fetchPublicUsers(for category: DiscoverUsersView.DiscoverCategory, limit: Int) async throws -> [CloudKitUser] {
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            throw UnifiedAuthError.cloudKitNotAvailable
        }

        guard let container = CloudKitRuntimeSupport.makeContainer() else {
            throw UnifiedAuthError.cloudKitNotAvailable
        }

        let query = publicUserQuery(for: category)
        do {
            let results = try await container.publicCloudDatabase.records(matching: query)
            let users = results.matchResults.compactMap { result in
                switch result.1 {
                case .success(let record):
                    return CloudKitUser(from: record)
                case .failure:
                    return nil
                }
            }
            return Array(users.prefix(limit))
        } catch {
            if let ckError = error as? CKError,
               ckError.code == .networkUnavailable || ckError.code == .networkFailure {
                throw UnifiedAuthError.networkError
            }
            throw UnifiedAuthError.cloudKitError(error)
        }
    }

    private func searchPublicUsers(query: String, limit: Int = 50) async throws -> [CloudKitUser] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            throw UnifiedAuthError.cloudKitNotAvailable
        }

        guard let container = CloudKitRuntimeSupport.makeContainer() else {
            throw UnifiedAuthError.cloudKitNotAvailable
        }

        let predicate = NSPredicate(
            format: "(%K CONTAINS[cd] %@ OR %K CONTAINS[cd] %@) AND %K == %d",
            CKField.User.username, trimmedQuery,
            CKField.User.displayName, trimmedQuery,
            CKField.User.isProfilePublic, 1
        )

        let queryObj = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        queryObj.sortDescriptors = [NSSortDescriptor(key: CKField.User.followerCount, ascending: false)]

        do {
            let results = try await container.publicCloudDatabase.records(matching: queryObj)
            let users = results.matchResults.compactMap { result in
                switch result.1 {
                case .success(let record):
                    return CloudKitUser(from: record)
                case .failure:
                    return nil
                }
            }
            return Array(users.prefix(limit))
        } catch {
            if let ckError = error as? CKError,
               ckError.code == .networkUnavailable || ckError.code == .networkFailure {
                throw UnifiedAuthError.networkError
            }
            throw UnifiedAuthError.cloudKitError(error)
        }
    }
    
    func loadUsers(for category: DiscoverUsersView.DiscoverCategory, forceRefresh: Bool = false) async {
        currentCategory = category
        
        // Try to load from cache first
        if !forceRefresh, loadCachedUsers(for: category) {
            print("✅ Loaded \(users.count) users from cache")
            // Still refresh in background if cache is getting old
            if needsRefresh(for: category) {
                Task {
                    await fetchUsersInBackground(for: category)
                }
            }
            return
        }

        // Avoid triggering iCloud system prompts in guest flows.
        // If the device isn't signed into iCloud, show demo profiles instead of attempting CloudKit.
        if FileManager.default.ubiquityIdentityToken == nil {
            applyLocalFallback(for: category)
            saveCachedUsers(users, for: category)
            lastRefreshTime = Date()
            return
        }
        
        showingSkeletonViews = users.isEmpty
        isLoading = true
        
        do {
            var fetchedUsers: [CloudKitUser] = []
            
            switch category {
            case .suggested:
                fetchedUsers = try await fetchPublicUsers(for: category, limit: 20)
            case .trending:
                fetchedUsers = try await fetchPublicUsers(for: category, limit: 20)
            case .newChefs:
                fetchedUsers = try await fetchPublicUsers(for: category, limit: 20)
            case .verified:
                fetchedUsers = try await fetchPublicUsers(for: category, limit: 20)
            }
            
            // Convert to UserProfile with parallel follow state checking
            var convertedUsers: [UserProfile] = []
            
            if UnifiedAuthManager.shared.isAuthenticated {
                // Parallel follow state checking for better performance
                await withTaskGroup(of: UserProfile.self) { group in
                    for cloudKitUser in fetchedUsers {
                        // Capture the values we need before the task
                        let userID = cloudKitUser.recordID ?? ""
                        let username = cloudKitUser.username
                        let displayName = cloudKitUser.displayName
                        let followerCount = cloudKitUser.followerCount
                        let followingCount = cloudKitUser.followingCount
                        let recipesCreated = cloudKitUser.recipesCreated
                        let profileImageURL = cloudKitUser.profileImageURL
                        let isVerified = cloudKitUser.isVerified
                        
                        group.addTask {
                            var userProfile = UserProfile(
                                id: userID,
                                username: username ?? displayName.lowercased().replacingOccurrences(of: " ", with: ""),
                                displayName: displayName,
                                profileImageURL: profileImageURL,
                                followerCount: followerCount,
                                followingCount: followingCount,
                                recipesCreated: recipesCreated,
                                isVerified: isVerified,
                                isFollowing: false,
                                bio: nil
                            )
                            let isFollowing = await UnifiedAuthManager.shared.isFollowing(userID: userProfile.id)
                            userProfile.isFollowing = isFollowing
                            return userProfile
                        }
                    }
                    
                    // Collect results in order
                    for await userProfile in group {
                        convertedUsers.append(userProfile)
                    }
                }
            } else {
                // No authentication, just convert without follow status
                for cloudKitUser in fetchedUsers {
                    let userProfile = convertToUserProfile(cloudKitUser)
                    convertedUsers.append(userProfile)
                }
            }
            
            let sanitized = sanitizedUniqueUsers(convertedUsers)
            if sanitized.isEmpty {
                // CloudKit can legitimately return no rows (no iCloud account, no public profiles yet, etc).
                // Never ship an empty "Discover" screen; fall back to curated demo profiles.
                applyLocalFallback(for: category)
                saveCachedUsers(users, for: category)
                lastRefreshTime = Date()
            } else {
                users = sanitized
                // Maintain memory limits after setting users
                maintainMemoryLimits()

                // Save to cache
                saveCachedUsers(users, for: category)
                lastRefreshTime = Date()
            }
            
        } catch {
            print("❌ Failed to load users: \(error)")
            applyLocalFallback(for: category)
            saveCachedUsers(users, for: category)
        }
        
        showingSkeletonViews = false
        isLoading = false
    }
    
    // MARK: - Cache Methods
    
    private func cachedTimestamp(for category: DiscoverUsersView.DiscoverCategory) -> Date? {
        UserDefaults.standard.object(forKey: "\(cacheKey)_\(category.rawValue)_timestamp") as? Date
    }

    func needsRefresh(for category: DiscoverUsersView.DiscoverCategory? = nil) -> Bool {
        if let lastRefreshTime, Date().timeIntervalSince(lastRefreshTime) < minimumRefreshInterval {
            return false
        }

        // If iCloud isn't available, never attempt background CloudKit refreshes.
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            return false
        }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            return false
        }

        let effectiveCategory = category ?? currentCategory
        guard let timestamp = cachedTimestamp(for: effectiveCategory) else {
            return true
        }

        let cacheAge = Date().timeIntervalSince(timestamp)
        if cacheAge > cacheTTL {
            return true
        }

        // If we're showing local fallback profiles, re-attempt CloudKit discovery once iCloud is available.
        let showingLocalFallback = !users.isEmpty && users.allSatisfy { $0.id.hasPrefix("local_") }
        if showingLocalFallback,
           CloudKitRuntimeSupport.hasCloudKitEntitlement,
           FileManager.default.ubiquityIdentityToken != nil {
            return true
        }

        return false
    }
    
    private func loadCachedUsers(for category: DiscoverUsersView.DiscoverCategory) -> Bool {
        let key = "\(cacheKey)_\(category.rawValue)"
        
        guard let data = UserDefaults.standard.data(forKey: key),
              UserDefaults.standard.object(forKey: "\(key)_timestamp") as? Date != nil else {
            return false
        }
        
        // Check if cache is still valid
        // Never expire cache - always valid
        // Was: if Date().timeIntervalSince(timestamp) > cacheTTL { return false }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([UserProfile].self, from: data)
            guard !decoded.isEmpty else {
                return false
            }
            users = decoded
            return true
        } catch {
            print("❌ Failed to decode cached users: \(error)")
            return false
        }
    }
    
    private func saveCachedUsers(_ users: [UserProfile], for category: DiscoverUsersView.DiscoverCategory) {
        guard !users.isEmpty else { return }
        let key = "\(cacheKey)_\(category.rawValue)"
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(users)
            UserDefaults.standard.set(data, forKey: key)
            UserDefaults.standard.set(Date(), forKey: "\(key)_timestamp")
            UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
        } catch {
            print("❌ Failed to cache users: \(error)")
        }
    }
    
    private func fetchUsersInBackground(for category: DiscoverUsersView.DiscoverCategory) async {
        print("🔄 Background refresh of discover users...")
        
        do {
            var fetchedUsers: [CloudKitUser] = []
            
            switch category {
            case .suggested:
                fetchedUsers = try await fetchPublicUsers(for: category, limit: 20)
            case .trending:
                fetchedUsers = try await fetchPublicUsers(for: category, limit: 20)
            case .newChefs:
                fetchedUsers = try await fetchPublicUsers(for: category, limit: 20)
            case .verified:
                fetchedUsers = try await fetchPublicUsers(for: category, limit: 20)
            }
            
            // Convert to UserProfile with parallel follow state checking
            var convertedUsers: [UserProfile] = []
            
            if UnifiedAuthManager.shared.isAuthenticated {
                // Parallel follow state checking for better performance
                await withTaskGroup(of: UserProfile.self) { group in
                    for cloudKitUser in fetchedUsers {
                        // Capture the values we need before the task
                        let userID = cloudKitUser.recordID ?? ""
                        let username = cloudKitUser.username
                        let displayName = cloudKitUser.displayName
                        let followerCount = cloudKitUser.followerCount
                        let followingCount = cloudKitUser.followingCount
                        let recipesCreated = cloudKitUser.recipesCreated
                        let profileImageURL = cloudKitUser.profileImageURL
                        let isVerified = cloudKitUser.isVerified
                        
                        group.addTask {
                            var userProfile = UserProfile(
                                id: userID,
                                username: username ?? displayName.lowercased().replacingOccurrences(of: " ", with: ""),
                                displayName: displayName,
                                profileImageURL: profileImageURL,
                                followerCount: followerCount,
                                followingCount: followingCount,
                                recipesCreated: recipesCreated,
                                isVerified: isVerified,
                                isFollowing: false,
                                bio: nil
                            )
                            let isFollowing = await UnifiedAuthManager.shared.isFollowing(userID: userProfile.id)
                            userProfile.isFollowing = isFollowing
                            return userProfile
                        }
                    }
                    
                    // Collect results in order
                    for await userProfile in group {
                        convertedUsers.append(userProfile)
                    }
                }
            } else {
                // No authentication, just convert without follow status
                for cloudKitUser in fetchedUsers {
                    let userProfile = convertToUserProfile(cloudKitUser)
                    convertedUsers.append(userProfile)
                }
            }
            
            let sanitized = sanitizedUniqueUsers(convertedUsers)
            guard !sanitized.isEmpty else {
                // Don't wipe existing content with an empty refresh.
                return
            }

            users = sanitized
            // Maintain memory limits after setting users
            maintainMemoryLimits()
            saveCachedUsers(users, for: category)
            
        } catch {
            print("❌ Background refresh failed: \(error)")
        }
    }
    
    func searchUsers(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        // If CloudKit isn't available (simulator/offline/no iCloud), fall back to local filtering
        // without attempting any network calls that could trigger system prompts.
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement,
              FileManager.default.ubiquityIdentityToken != nil else {
            let allFallbackUsers = fallbackUsers(for: currentCategory)
            searchResults = allFallbackUsers.filter {
                $0.username.localizedCaseInsensitiveContains(query) ||
                $0.displayName.localizedCaseInsensitiveContains(query)
            }
            return
        }
        
        Task {
            isSearching = true
            
            do {
                let cloudKitResults = try await searchPublicUsers(query: query, limit: maxSearchResults)
                
                var convertedResults: [UserProfile] = []
                for cloudKitUser in cloudKitResults {
                    var userProfile = convertToUserProfile(cloudKitUser)
                    
                    if UnifiedAuthManager.shared.isAuthenticated {
                        userProfile.isFollowing = await UnifiedAuthManager.shared.isFollowing(userID: userProfile.id)
                    }
                    
                    convertedResults.append(userProfile)
                }
                let sanitizedResults = self.sanitizedUniqueUsers(convertedResults)
                
                await MainActor.run {
                    searchResults = sanitizedResults
                    isSearching = false
                }
                
            } catch {
                print("❌ Search failed: \(error)")
                await MainActor.run {
                    let allFallbackUsers = fallbackUsers(for: currentCategory)
                    searchResults = allFallbackUsers.filter {
                        $0.username.localizedCaseInsensitiveContains(query) ||
                        $0.displayName.localizedCaseInsensitiveContains(query)
                    }
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
    
    // MARK: - Memory Management
    
    /// Maintain memory limits by keeping only the newest items
    private func maintainMemoryLimits() {
        // Keep only the maxUsers newest users
        if users.count > maxUsers {
            users = Array(users.prefix(maxUsers))
            print("📊 Trimmed users to \(maxUsers) newest items")
        }
        
        // Keep only the maxSearchResults newest search results
        if searchResults.count > maxSearchResults {
            searchResults = Array(searchResults.prefix(maxSearchResults))
            print("📊 Trimmed search results to \(maxSearchResults) items")
        }
    }
    
    /// Reset singleton for logout
    func reset() {
        print("🔄 Resetting SimpleDiscoverUsersManager singleton")
        users.removeAll()
        searchResults.removeAll()
        hasMore = false
        isLoading = false
        isSearching = false
        showingSkeletonViews = false
        lastRefreshTime = nil
        selectedUser = nil
        currentCategory = .suggested
        
        // Clear all category caches
        let categories = DiscoverUsersView.DiscoverCategory.allCases
        for category in categories {
            let key = "\(cacheKey)_\(category.rawValue)"
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults.standard.removeObject(forKey: "\(key)_timestamp")
        }
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
    }
    
    private func convertToUserProfile(_ cloudKitUser: CloudKitUser) -> UserProfile {
        let resolvedID = canonicalUserID(for: cloudKitUser)
        let finalUsername = cloudKitUser.username ?? cloudKitUser.displayName.lowercased().replacingOccurrences(of: " ", with: "")
        
        return UserProfile(
            id: resolvedID,
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

    private func canonicalUserID(for cloudKitUser: CloudKitUser) -> String {
        if let recordID = cloudKitUser.recordID?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !recordID.isEmpty {
            return recordID
        }

        let fallbackSource = [
            cloudKitUser.username,
            cloudKitUser.displayName,
            cloudKitUser.email
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        guard let fallbackSource else { return "" }
        let sanitized = fallbackSource
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        guard !sanitized.isEmpty else { return "" }
        return "user-\(sanitized)"
    }

    private func sanitizedUniqueUsers(_ input: [UserProfile]) -> [UserProfile] {
        var seenIDs = Set<String>()
        var result: [UserProfile] = []

        for user in input {
            let trimmedID = user.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty else { continue }
            guard !seenIDs.contains(trimmedID) else { continue }
            seenIDs.insert(trimmedID)
            result.append(user)
        }

        return result
    }
    
    /// Clear all cached data (for account deletion)
    func clearCache() {
        reset()
        print("✅ SimpleDiscoverUsersManager: Cache cleared")
    }
}

// MARK: - Discover Users View
struct DiscoverUsersView: View {
    // Use shared singleton instance for preloaded data
    @StateObject private var manager = SimpleDiscoverUsersManager.shared
    @EnvironmentObject var appState: AppState
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

                    // If CloudKit public discovery isn't available, we fall back to local demo profiles.
                    // Show an iCloud hint only when we're actually showing fallback users.
                    let showingLocalFallback = !manager.users.isEmpty && manager.users.allSatisfy { $0.id.hasPrefix("local_") }
                    if CloudKitRuntimeSupport.hasCloudKitEntitlement, showingLocalFallback, !manager.isLoading {
                        iCloudSetupCard
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                    }

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
                                            let trimmedID = user.id.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !trimmedID.isEmpty {
                                                manager.selectedUser = user
                                            }
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
                            await manager.loadUsers(for: selectedCategory, forceRefresh: true)
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
            if CloudKitRuntimeSupport.hasCloudKitEntitlement,
               !user.id.hasPrefix("local_") {
                UserProfileView(
                    userID: user.id,
                    userName: user.username  // Always use username, not displayName
                )
                .environmentObject(appState)
            } else {
                LocalChefPreviewView(user: user)
            }
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

    private var iCloudSetupCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: "icloud.slash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Sign in to iCloud to browse real chefs")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text("Without iCloud, SnapChef shows demo profiles. Follow, likes, and saved recipes sync require iCloud.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: openAppSettings) {
                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsUrl)
    }
}

// MARK: - Local Chef Preview (Simulator / Offline)
struct LocalChefPreviewView: View {
    let user: UserProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#f6d365"),
                                                Color(hex: "#fda085")
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 104, height: 104)

                                Text(String(user.displayName.prefix(1)).uppercased())
                                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(user.displayName)
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    if user.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(Color(hex: "#43e97b"))
                                    }
                                }

                                Text("@\(user.username)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.75))

                                if let bio = user.bio, !bio.isEmpty {
                                    Text(bio)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.72))
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.top, 14)

                        HStack(spacing: 0) {
                            statPill(value: "\(user.followerCount)", label: "Followers")
                            statPill(value: "\(user.followingCount)", label: "Following")
                            statPill(value: "\(user.recipesCreated)", label: "Recipes")
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )
                        )

                        VStack(spacing: 10) {
                            Text("Preview Mode")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))

                            Text("Follow, likes, and real profiles require iCloud + CloudKit. Run on a real device (or enable CloudKit for simulator testing) to see live chefs.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)

                            Button {
                                UnifiedAuthManager.shared.promptAuthForFeature(.socialSharing)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Sign In")
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
                                .cornerRadius(14)
                                .shadow(color: Color(hex: "#667eea").opacity(0.35), radius: 14, y: 8)
                            }
                            .padding(.top, 8)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Chef Preview")
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
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
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

    @ObservedObject private var authManager = UnifiedAuthManager.shared
    @State private var isFollowing: Bool

    init(user: UserProfile, onFollow: @escaping () -> Void, onTap: @escaping () -> Void) {
        self.user = user
        self.onFollow = onFollow
        self.onTap = onTap
        self._isFollowing = State(initialValue: user.isFollowing)
    }
    
    // Computed properties to simplify type-checking
    private var buttonText: String {
        if !authManager.isAuthenticated {
            return "Sign In to Follow"
        } else if isFollowing {
            return "Following"
        } else {
            return "Follow"
        }
    }
    
    private var buttonTextColor: Color {
        return (isFollowing || !authManager.isAuthenticated) ? .white : .black
    }
    
    private var buttonMinWidth: CGFloat {
        return authManager.isAuthenticated ? 80 : 120
    }
    
    private var buttonBackgroundColor: Color {
        if !authManager.isAuthenticated {
            return Color(hex: "#667eea") // Simplified to single color
        } else if isFollowing {
            return Color.white.opacity(0.2)
        } else {
            return Color.white
        }
    }
    
    private var shouldShowGradient: Bool {
        return !authManager.isAuthenticated
    }
    
    private var buttonBorderColor: Color {
        return (isFollowing && authManager.isAuthenticated) ? Color.white.opacity(0.5) : Color.clear
    }

    var body: some View {
        HStack(spacing: 16) {
            // Split: tappable card content + separate follow button (avoid nested Button crash).
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
                            Text(user.displayName)
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

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)

            // Follow Button
            Button(action: {
                if authManager.isAuthenticated {
                    withAnimation(.spring(response: 0.3)) {
                        isFollowing.toggle()
                        onFollow()
                    }
                } else {
                    // Show authentication prompt
                    authManager.promptAuthForFeature(.socialSharing)
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
