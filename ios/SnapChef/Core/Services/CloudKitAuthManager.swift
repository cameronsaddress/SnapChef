import Foundation
import CloudKit
import AuthenticationServices
import SwiftUI

@MainActor
final class CloudKitAuthManager: ObservableObject {
    // Fix for Swift concurrency issue with @MainActor singletons
    static let shared: CloudKitAuthManager = {
        let instance = CloudKitAuthManager()
        return instance
    }()

    @Published var isAuthenticated = false
    @Published var currentUser: CloudKitUser?
    @Published var isLoading = false
    @Published var showAuthSheet = false
    @Published var showUsernameSelection = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let container = CKContainer.default()
    private var database: CKDatabase { container.publicCloudDatabase }
    
    init() {
        print("CloudKitAuthManager initialized")
        // Check for existing authentication on initialization
        checkExistingAuth()
    }
    
    /// Check if user is already authenticated with CloudKit
    private func checkExistingAuth() {
        Task {
            do {
                let accountStatus = try await container.accountStatus()
                guard accountStatus == .available else {
                    print("⚠️ CloudKit account not available: \(accountStatus)")
                    return
                }
                
                // Check if we have a stored user ID
                if let storedUserID = UserDefaults.standard.string(forKey: "currentUserRecordID") {
                    print("🔍 Checking existing CloudKit user: \(storedUserID)")
                    
                    // Try to fetch the user record
                    let record = try await database.record(for: CKRecord.ID(recordName: storedUserID))
                    
                    await MainActor.run {
                        self.currentUser = CloudKitUser(from: record)
                        self.isAuthenticated = true
                        print("✅ CloudKit user restored from storage: \(storedUserID)")
                    }
                    
                    // Update last active
                    record[CKField.User.lastActiveAt] = Date()
                    _ = try await database.save(record)
                } else {
                    print("ℹ️ No stored CloudKit user ID found")
                }
            } catch {
                print("❌ Failed to restore CloudKit auth: \(error)")
                // Clear invalid stored data
                UserDefaults.standard.removeObject(forKey: "currentUserRecordID")
                UserDefaults.standard.removeObject(forKey: "currentUserID")
                await MainActor.run {
                    self.isAuthenticated = false
                    self.currentUser = nil
                }
            }
        }
    }
    
    /// Calculate exponential backoff delay for auth operations
    private func calculateAuthBackoffDelay(attempt: Int) -> TimeInterval {
        return 1.0 // Simplified implementation
    }
    
    /// Sign in with Apple ID for CloudKit authentication
    func signInWithApple(authorization: Any) async throws {
        print("🔑 Starting CloudKit Sign in with Apple...")
        
        // First check CloudKit account status
        let accountStatus = try await container.accountStatus()
        guard accountStatus == .available else {
            throw CloudKitAuthError.notAuthenticated
        }
        
        // Get the CloudKit user record ID
        let userRecord = try await container.userRecordID()
        let cloudKitUserID = userRecord.recordName
        
        print("✅ CloudKit userRecordID: \(cloudKitUserID)")
        
        // Store the CloudKit user ID (this is the persistent ID we need)
        UserDefaults.standard.set(cloudKitUserID, forKey: "currentUserRecordID")
        UserDefaults.standard.set(cloudKitUserID, forKey: "currentUserID") // For compatibility
        
        // Try to fetch existing user profile
        do {
            let existingRecord = try await database.record(for: CKRecord.ID(recordName: cloudKitUserID))
            self.currentUser = CloudKitUser(from: existingRecord)
            
            // Update last login
            existingRecord[CKField.User.lastLoginAt] = Date()
            _ = try await database.save(existingRecord)
            
            // Check if user needs username setup
            if self.currentUser?.username == nil || self.currentUser?.username?.isEmpty == true {
                showUsernameSelection = true
            }
            
            print("✅ Existing CloudKit user loaded: \(cloudKitUserID)")
        } catch {
            // Create new user profile if it doesn't exist
            print("📝 Creating new CloudKit user profile for: \(cloudKitUserID)")
            try await createNewUserProfile(cloudKitUserID: cloudKitUserID, authorization: authorization)
        }
        
        // Set authenticated status
        isAuthenticated = true
        print("🎉 CloudKit authentication completed successfully")
    }
    
    /// Create a new user profile in CloudKit
    private func createNewUserProfile(cloudKitUserID: String, authorization: Any) async throws {
        let newRecord = CKRecord(recordType: CloudKitConfig.userRecordType, recordID: CKRecord.ID(recordName: cloudKitUserID))
        
        // Extract user info from Apple ID authorization if available
        var displayName = "Anonymous Chef"
        var generatedUsername: String? = nil
        
        if let appleAuth = authorization as? ASAuthorization,
           let appleIDCredential = appleAuth.credential as? ASAuthorizationAppleIDCredential {
            newRecord[CKField.User.email] = appleIDCredential.email ?? ""
            
            // Use the formatted name from Apple ID
            if let fullName = appleIDCredential.fullName {
                displayName = fullName.formatted()
                // Generate username from the full name
                generatedUsername = try await generateUsernameFromName(fullName)
            }
        }
        
        newRecord[CKField.User.displayName] = displayName
        
        // Set the generated username if we have one
        if let username = generatedUsername {
            newRecord[CKField.User.username] = username
        }
        
        // Set initial values
        newRecord[CKField.User.authProvider] = "apple"
        newRecord[CKField.User.createdAt] = Date()
        newRecord[CKField.User.lastLoginAt] = Date()
        newRecord[CKField.User.totalPoints] = Int64(0)
        newRecord[CKField.User.currentStreak] = Int64(0)
        newRecord[CKField.User.longestStreak] = Int64(0)
        newRecord[CKField.User.challengesCompleted] = Int64(0)
        newRecord[CKField.User.recipesShared] = Int64(0)
        newRecord[CKField.User.recipesCreated] = Int64(0)
        newRecord[CKField.User.coinBalance] = Int64(100) // Starting bonus
        newRecord[CKField.User.followerCount] = Int64(0)
        newRecord[CKField.User.followingCount] = Int64(0)
        newRecord[CKField.User.isProfilePublic] = Int64(1)
        newRecord[CKField.User.showOnLeaderboard] = Int64(1)
        newRecord[CKField.User.isVerified] = Int64(0)
        newRecord[CKField.User.subscriptionTier] = "free"
        
        try await database.save(newRecord)
        self.currentUser = CloudKitUser(from: newRecord)
        
        // Show username selection if we couldn't generate one automatically
        if generatedUsername == nil {
            showUsernameSelection = true
        }
        
        print("✅ New CloudKit user profile created: \(cloudKitUserID)")
        if let username = generatedUsername {
            print("✅ Generated username: \(username)")
        } else {
            print("⚠️ No username generated, will show username selection")
        }
    }
    
    /// Generate a unique username from Apple ID name
    private func generateUsernameFromName(_ personNameComponents: PersonNameComponents) async throws -> String? {
        // Create a base username from the name
        let firstName = personNameComponents.givenName?.lowercased() ?? ""
        let lastName = personNameComponents.familyName?.lowercased() ?? ""
        
        // Remove special characters and spaces
        let cleanFirstName = firstName.replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
        let cleanLastName = lastName.replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
        
        // Create potential usernames in order of preference
        var potentialUsernames: [String] = []
        
        if !cleanFirstName.isEmpty && !cleanLastName.isEmpty {
            potentialUsernames.append(cleanFirstName + cleanLastName)
            potentialUsernames.append(cleanFirstName + "." + cleanLastName)
            potentialUsernames.append(cleanFirstName + "_" + cleanLastName)
        }
        
        if !cleanFirstName.isEmpty {
            potentialUsernames.append(cleanFirstName)
        }
        
        if !cleanLastName.isEmpty {
            potentialUsernames.append(cleanLastName)
        }
        
        // Try each potential username
        for baseUsername in potentialUsernames {
            // Make sure it meets minimum length requirement
            guard baseUsername.count >= 3 else { continue }
            
            // Check if base username is available
            let isBaseAvailable = try await checkUsernameAvailability(baseUsername)
            if isBaseAvailable {
                return baseUsername
            }
            
            // Try with numbers appended (1-999)
            for suffix in 1...999 {
                let numberedUsername = baseUsername + String(suffix)
                if numberedUsername.count <= 20 {
                    let isAvailable = try await checkUsernameAvailability(numberedUsername)
                    if isAvailable {
                        return numberedUsername
                    }
                }
            }
        }
        
        // If we still can't find one, return nil to show manual selection
        return nil
    }
    
    /// Check if a username is available
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let predicate = NSPredicate(format: "%K == %@", CKField.User.username, username.lowercased())
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            return results.matchResults.isEmpty
        } catch {
            throw CloudKitAuthError.networkError
        }
    }
    
    /// Set username for the current user
    func setUsername(_ username: String) async throws {
        guard let currentUser = currentUser,
              let recordID = currentUser.recordID else {
            throw CloudKitAuthError.notAuthenticated
        }
        
        // Check availability first
        let isAvailable = try await checkUsernameAvailability(username)
        guard isAvailable else {
            throw CloudKitAuthError.usernameUnavailable
        }
        
        // Update the user record
        let ckRecordID = CKRecord.ID(recordName: recordID)
        let record = try await database.record(for: ckRecordID)
        record[CKField.User.username] = username.lowercased()
        
        _ = try await database.save(record)
        
        // Update local user object
        await MainActor.run {
            var updatedUser = currentUser
            updatedUser.username = username
            self.currentUser = updatedUser
        }
    }
    
    /// Update user statistics
    func updateUserStats(_ updates: UserStatUpdates) async throws {
        guard let currentUser = currentUser,
              let recordID = currentUser.recordID else {
            throw CloudKitAuthError.notAuthenticated
        }
        
        let ckRecordID = CKRecord.ID(recordName: recordID)
        let record = try await database.record(for: ckRecordID)
        
        // Apply updates
        if let totalLikes = updates.totalLikes {
            record["totalLikes"] = Int64(totalLikes)
        }
        if let totalShares = updates.totalShares {
            record["totalShares"] = Int64(totalShares)
        }
        if let streakCount = updates.streakCount {
            record["streakCount"] = Int64(streakCount)
        }
        if let challengesCompleted = updates.challengesCompleted {
            record["challengesCompleted"] = Int64(challengesCompleted)
        }
        if let level = updates.level {
            record["level"] = Int64(level)
        }
        if let experiencePoints = updates.experiencePoints {
            record["experiencePoints"] = Int64(experiencePoints)
        }
        if let recipesShared = updates.recipesShared {
            record["recipesShared"] = Int64(recipesShared)
        }
        if let followerCount = updates.followerCount {
            record["followerCount"] = Int64(followerCount)
        }
        if let followingCount = updates.followingCount {
            record["followingCount"] = Int64(followingCount)
        }
        
        _ = try await database.save(record)
        
        // Update local user object
        await MainActor.run {
            var updatedUser = currentUser
            if let totalLikes = updates.totalLikes {
                updatedUser.totalLikes = totalLikes
            }
            if let totalShares = updates.totalShares {
                updatedUser.totalShares = totalShares
            }
            if let streakCount = updates.streakCount {
                updatedUser.streakCount = streakCount
            }
            if let challengesCompleted = updates.challengesCompleted {
                updatedUser.challengesCompleted = challengesCompleted
            }
            if let level = updates.level {
                updatedUser.level = level
            }
            if let experiencePoints = updates.experiencePoints {
                updatedUser.experiencePoints = experiencePoints
            }
            if let recipesShared = updates.recipesShared {
                updatedUser.recipesShared = recipesShared
            }
            if let followerCount = updates.followerCount {
                updatedUser.followerCount = followerCount
            }
            if let followingCount = updates.followingCount {
                updatedUser.followingCount = followingCount
            }
            self.currentUser = updatedUser
        }
    }
    
    /// Check if authentication is required for a specific feature
    func isAuthRequiredFor(feature: AuthRequiredFeature) -> Bool {
        switch feature {
        case .challenges, .leaderboard, .socialSharing, .teams, .streaks, .premiumFeatures:
            return !isAuthenticated
        case .basicRecipes:
            return false
        }
    }
    
    /// Prompt authentication for a specific feature
    func promptAuthForFeature(_ feature: AuthRequiredFeature) {
        if isAuthRequiredFor(feature: feature) {
            showAuthSheet = true
        }
    }
    
    /// Sign out the current user
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "currentUserRecordID")
    }
    
    // MARK: - Social Features
    
    /// Check if the current user is following another user
    func isFollowing(userID: String) async -> Bool {
        guard let currentUser = currentUser,
              let currentUserID = currentUser.recordID else {
            return false
        }
        
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %@ AND %K == %d",
            CKField.Follow.followerID, currentUserID,
            CKField.Follow.followingID, userID,
            CKField.Follow.isActive, 1
        )
        
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            return !results.matchResults.isEmpty
        } catch {
            print("Error checking follow status: \(error)")
            return false
        }
    }
    
    /// Follow a user
    func followUser(userID: String) async throws {
        guard let currentUser = currentUser,
              let currentUserID = currentUser.recordID else {
            throw CloudKitAuthError.notAuthenticated
        }
        
        // Check if already following
        let isAlreadyFollowing = await isFollowing(userID: userID)
        if isAlreadyFollowing {
            return // Already following
        }
        
        // Create follow record
        let followRecord = CKRecord(recordType: CloudKitConfig.followRecordType)
        followRecord[CKField.Follow.followerID] = currentUserID
        followRecord[CKField.Follow.followingID] = userID
        followRecord[CKField.Follow.followedAt] = Date()
        followRecord[CKField.Follow.isActive] = Int64(1)
        
        _ = try await database.save(followRecord)
        
        // Create activity for the followed user
        try await CloudKitSyncService.shared.createActivity(
            type: "follow",
            actorID: currentUserID,
            targetUserID: userID
        )
        
        // Update local follower count
        await MainActor.run {
            var updatedUser = currentUser
            updatedUser.followerCount += 1
            self.currentUser = updatedUser
        }
    }
    
    /// Unfollow a user
    func unfollowUser(userID: String) async throws {
        guard let currentUser = currentUser,
              let currentUserID = currentUser.recordID else {
            throw CloudKitAuthError.notAuthenticated
        }
        
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %@ AND %K == %d",
            CKField.Follow.followerID, currentUserID,
            CKField.Follow.followingID, userID,
            CKField.Follow.isActive, 1
        )
        
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            
            for result in results.matchResults {
                switch result.1 {
                case .success(let record):
                    // Soft delete by setting isActive to 0
                    record[CKField.Follow.isActive] = Int64(0)
                    _ = try await database.save(record)
                case .failure(let error):
                    print("Error processing follow record: \(error)")
                }
            }
            
            // Create activity for the unfollowed user
            try await CloudKitSyncService.shared.createActivity(
                type: "unfollow",
                actorID: currentUserID,
                targetUserID: userID
            )
            
            // Update local follower count
            await MainActor.run {
                var updatedUser = currentUser
                updatedUser.followerCount = max(0, updatedUser.followerCount - 1)
                self.currentUser = updatedUser
            }
        } catch {
            throw CloudKitAuthError.networkError
        }
    }
    
    // MARK: - User Discovery Methods
    
    /// Get suggested users for discovery - smart recommendations based on activity and engagement
    func getSuggestedUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        // CloudKit doesn't support OR predicates, so we need to make two separate queries
        // and merge the results, removing duplicates
        
        // Query 1: Users who have created recipes
        let recipeCreatorsPredicate = NSPredicate(format: "%K >= %d", CKField.User.recipesCreated, 1)
        let recipeCreatorsQuery = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: recipeCreatorsPredicate)
        recipeCreatorsQuery.sortDescriptors = [
            NSSortDescriptor(key: CKField.User.totalPoints, ascending: false),
            NSSortDescriptor(key: CKField.User.recipesCreated, ascending: false)
        ]
        
        // Query 2: Users who have moderate engagement (points)
        let activeUsersPredicate = NSPredicate(format: "%K >= %d", CKField.User.totalPoints, 100)
        let activeUsersQuery = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: activeUsersPredicate)
        activeUsersQuery.sortDescriptors = [
            NSSortDescriptor(key: CKField.User.totalPoints, ascending: false),
            NSSortDescriptor(key: CKField.User.recipesCreated, ascending: false)
        ]
        
        do {
            // Execute both queries concurrently
            async let recipeCreatorsResults = database.records(matching: recipeCreatorsQuery)
            async let activeUsersResults = database.records(matching: activeUsersQuery)
            
            let (recipeCreatorsResponse, activeUsersResponse) = try await (recipeCreatorsResults, activeUsersResults)
            
            // Process results from both queries and merge
            var userMap: [String: CloudKitUser] = [:] // Use map to automatically handle duplicates
            
            // Process recipe creators
            for result in recipeCreatorsResponse.matchResults {
                switch result.1 {
                case .success(let record):
                    let user = CloudKitUser(from: record)
                    if let recordID = user.recordID {
                        userMap[recordID] = user
                    }
                case .failure(let error):
                    print("❌ Failed to process recipe creator record: \(error)")
                }
            }
            
            // Process active users
            for result in activeUsersResponse.matchResults {
                switch result.1 {
                case .success(let record):
                    let user = CloudKitUser(from: record)
                    if let recordID = user.recordID {
                        userMap[recordID] = user // Duplicates will be overwritten automatically
                    }
                case .failure(let error):
                    print("❌ Failed to process active user record: \(error)")
                }
            }
            
            // Convert map to array and sort by total points (highest activity first)
            var users = Array(userMap.values).sorted { user1, user2 in
                let points1 = user1.totalPoints
                let points2 = user2.totalPoints
                if points1 == points2 {
                    return user1.recipesShared > user2.recipesShared
                }
                return points1 > points2
            }
            
            // If current user is authenticated, filter out users they already follow
            if let currentUserID = currentUser?.recordID {
                // Get list of users the current user already follows
                let followingUsers = await getUsersFollowedBy(userID: currentUserID)
                let followingIDs = Set(followingUsers.compactMap { $0.recordID })
                
                // Filter out already followed users and the current user
                users = users.filter { user in
                    guard let userID = user.recordID else { return false }
                    return userID != currentUserID && !followingIDs.contains(userID)
                }
            }
            
            let limitedUsers = Array(users.prefix(limit))
            print("✅ Found \(limitedUsers.count) suggested chefs (active users with recipes)")
            return limitedUsers
        } catch {
            print("❌ Failed to fetch suggested users: \(error)")
            if let ckError = error as? CKError {
                print("   CloudKit error code: \(ckError.code)")
                print("   CloudKit error description: \(ckError.localizedDescription)")
            }
            throw CloudKitAuthError.networkError
        }
    }
    
    /// Get users that the current user is following - helper method for suggestions
    private func getUsersFollowedBy(userID: String) async -> [CloudKitUser] {
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %d",
            CKField.Follow.followerID, userID,
            CKField.Follow.isActive, 1
        )
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            var followedUserIDs: [String] = []
            
            for result in results.matchResults {
                switch result.1 {
                case .success(let record):
                    if let followingID = record[CKField.Follow.followingID] as? String {
                        followedUserIDs.append(followingID)
                    }
                case .failure:
                    continue
                }
            }
            
            // Fetch the actual user records
            var followedUsers: [CloudKitUser] = []
            for userID in followedUserIDs {
                do {
                    let userRecord = try await database.record(for: CKRecord.ID(recordName: userID))
                    followedUsers.append(CloudKitUser(from: userRecord))
                } catch {
                    print("Failed to fetch followed user: \(userID)")
                }
            }
            
            return followedUsers
        } catch {
            print("Failed to fetch following list: \(error)")
            return []
        }
    }
    
    /// Get trending users based on follower count - top 20 users with at least 5 followers
    func getTrendingUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        // Filter for users with at least 5 followers and sort by follower count
        let predicate = NSPredicate(format: "%K >= %d", CKField.User.followerCount, 5)
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        
        // Sort by follower count descending to get most popular users first
        query.sortDescriptors = [NSSortDescriptor(key: CKField.User.followerCount, ascending: false)]
        
        do {
            let results = try await database.records(matching: query)
            let users = results.matchResults.compactMap { result in
                switch result.1 {
                case .success(let record):
                    return CloudKitUser(from: record)
                case .failure(let error):
                    print("❌ Failed to process user record: \(error)")
                    return nil
                }
            }
            let limitedUsers = Array(users.prefix(limit))
            print("✅ Found \(limitedUsers.count) trending chefs (minimum 5 followers)")
            return limitedUsers
        } catch {
            print("❌ Failed to fetch trending users: \(error)")
            if let ckError = error as? CKError {
                print("   CloudKit error code: \(ckError.code)")
                print("   CloudKit error description: \(ckError.localizedDescription)")
            }
            throw CloudKitAuthError.networkError
        }
    }
    
    /// Get verified users
    func getVerifiedUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        // Since isVerified is not queryable, we'll get users with high totalPoints as a proxy for verified status
        // This is a workaround until the CloudKit schema is updated to make isVerified queryable
        let predicate = NSPredicate(format: "%K >= %d", CKField.User.totalPoints, 1000)
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.User.totalPoints, ascending: false)]
        
        do {
            let results = try await database.records(matching: query)
            let users = results.matchResults.compactMap { result in
                switch result.1 {
                case .success(let record):
                    return CloudKitUser(from: record)
                case .failure(let error):
                    print("❌ Failed to process user record: \(error)")
                    return nil
                }
            }
            let limitedUsers = Array(users.prefix(limit))
            print("✅ Found \(limitedUsers.count) suggested users")
            return limitedUsers
        } catch {
            print("❌ Failed to fetch suggested users: \(error)")
            if let ckError = error as? CKError {
                print("   CloudKit error code: \(ckError.code)")
                print("   CloudKit error description: \(ckError.localizedDescription)")
            }
            throw CloudKitAuthError.networkError
        }
    }
    
    /// Get new users (recently joined) for discovery - latest 100 users based on lastLoginAt or createdAt
    func getNewUsers(limit: Int = 100) async throws -> [CloudKitUser] {
        // Get the newest 100 users based on most recent activity (lastLoginAt) or creation date
        // Use lastLoginAt as primary sort since it shows recent activity, fallback to createdAt
        let predicate = NSPredicate(format: "%K >= %d", CKField.User.totalPoints, 0) // Get all users with valid profiles
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        
        // Sort by lastLoginAt (most recent activity first), then by createdAt as secondary sort
        query.sortDescriptors = [
            NSSortDescriptor(key: CKField.User.lastLoginAt, ascending: false),
            NSSortDescriptor(key: CKField.User.createdAt, ascending: false)
        ]
        
        do {
            let results = try await database.records(matching: query)
            let users = results.matchResults.compactMap { result in
                switch result.1 {
                case .success(let record):
                    return CloudKitUser(from: record)
                case .failure(let error):
                    print("❌ Failed to process user record: \(error)")
                    return nil
                }
            }
            let limitedUsers = Array(users.prefix(limit))
            print("✅ Found \(limitedUsers.count) new chefs (sorted by recent activity)")
            return limitedUsers
        } catch {
            print("❌ Failed to fetch new users: \(error)")
            if let ckError = error as? CKError {
                print("   CloudKit error code: \(ckError.code)")
                print("   CloudKit error description: \(ckError.localizedDescription)")
            }
            throw CloudKitAuthError.networkError
        }
    }
    
    /// Search users by username or display name
    func searchUsers(query: String) async throws -> [CloudKitUser] {
        guard !query.isEmpty else {
            return []
        }
        
        // Use BEGINSWITH instead of CONTAINS for better performance with queryable fields
        let predicate = NSPredicate(
            format: "%K BEGINSWITH[cd] %@ OR %K BEGINSWITH[cd] %@",
            CKField.User.username, query.lowercased(),
            CKField.User.displayName, query
        )
        
        let queryObj = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        queryObj.sortDescriptors = [NSSortDescriptor(key: CKField.User.totalPoints, ascending: false)]
        
        do {
            let results = try await database.records(matching: queryObj)
            let users = results.matchResults.compactMap { result in
                switch result.1 {
                case .success(let record):
                    return CloudKitUser(from: record)
                case .failure:
                    return nil
                }
            }
            return users
        } catch {
            throw CloudKitAuthError.networkError
        }
    }
    
    /// Refresh current user data from CloudKit
    func refreshCurrentUser() async {
        guard let currentUser = currentUser,
              let recordID = currentUser.recordID else {
            return
        }
        
        do {
            let ckRecordID = CKRecord.ID(recordName: recordID)
            let record = try await database.record(for: ckRecordID)
            let updatedUser = CloudKitUser(from: record)
            
            await MainActor.run {
                self.currentUser = updatedUser
            }
        } catch {
            print("Failed to refresh current user: \(error)")
        }
    }
    
    /// Update social counts for current user
    func updateSocialCounts() async {
        guard let currentUser = currentUser,
              let currentUserID = currentUser.recordID else {
            return
        }
        
        // For now, just refresh the current user data
        // In a full implementation, this would calculate follower counts, etc.
        await refreshCurrentUser()
        
        print("Social counts updated for user: \(currentUserID)")
    }
    
    /// Track anonymous user actions
    func trackAnonymousAction(_ action: AnonymousAction) {
        // For now, just log the action
        // In a full implementation, this would store analytics data
        print("📊 Anonymous action tracked: \(action.rawValue)")
    }
}

// MARK: - CloudKit User Model

struct CloudKitUser: Identifiable {
    let id = UUID()
    let recordID: String?
    var username: String?
    let displayName: String
    var profilePictureData: Data?
    var totalLikes: Int
    var totalShares: Int
    var streakCount: Int
    var joinDate: Date
    var lastActiveDate: Date
    var isVerified: Bool
    var bio: String?
    var favoriteRecipes: [String] // Recipe IDs
    var challengesCompleted: Int
    var level: Int
    var experiencePoints: Int
    var recipesShared: Int
    var followerCount: Int
    var followingCount: Int
    var profileImageURL: String?
    var createdAt: Date
    var lastLoginAt: Date
    var totalPoints: Int
    var currentStreak: Int
    
    init(from record: CKRecord) {
        self.recordID = record.recordID.recordName
        self.username = record[CKField.User.username] as? String
        self.displayName = record[CKField.User.displayName] as? String ?? "Anonymous Chef"
        self.profilePictureData = record["profilePictureData"] as? Data
        self.totalLikes = record["totalLikes"] as? Int ?? 0
        self.totalShares = record["totalShares"] as? Int ?? 0
        self.streakCount = Int(record[CKField.User.currentStreak] as? Int64 ?? 0)
        self.joinDate = record[CKField.User.createdAt] as? Date ?? Date()
        self.lastActiveDate = record[CKField.User.lastActiveAt] as? Date ?? Date()
        self.isVerified = (record[CKField.User.isVerified] as? Int64 ?? 0) == 1
        self.bio = record["bio"] as? String
        self.favoriteRecipes = record["favoriteRecipes"] as? [String] ?? []
        self.challengesCompleted = Int(record[CKField.User.challengesCompleted] as? Int64 ?? 0)
        self.level = record["level"] as? Int ?? 1
        self.experiencePoints = record["experiencePoints"] as? Int ?? 0
        self.recipesShared = Int(record[CKField.User.recipesShared] as? Int64 ?? 0)
        self.followerCount = Int(record[CKField.User.followerCount] as? Int64 ?? 0)
        self.followingCount = Int(record[CKField.User.followingCount] as? Int64 ?? 0)
        self.profileImageURL = record[CKField.User.profileImageURL] as? String
        self.createdAt = record[CKField.User.createdAt] as? Date ?? Date()
        self.lastLoginAt = record[CKField.User.lastLoginAt] as? Date ?? Date()
        self.totalPoints = Int(record[CKField.User.totalPoints] as? Int64 ?? 0)
        self.currentStreak = Int(record[CKField.User.currentStreak] as? Int64 ?? 0)
    }
}

struct UserStatUpdates {
    var totalLikes: Int?
    var totalShares: Int?
    var streakCount: Int?
    var challengesCompleted: Int?
    var level: Int?
    var experiencePoints: Int?
    var recipesShared: Int?
    var followerCount: Int?
    var followingCount: Int?
}

enum CloudKitAuthError: LocalizedError {
    case notAuthenticated
    case networkError
    case usernameUnavailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to iCloud to sync your data"
        case .networkError:
            return "Network connection error. Please try again."
        case .usernameUnavailable:
            return "This username is already taken"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}