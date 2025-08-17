import Foundation
import CloudKit
import AuthenticationServices
import SwiftUI

/// Authentication module for CloudKit operations
/// Handles user authentication, profiles, and social features
@MainActor
final class AuthModule: ObservableObject {
    
    // MARK: - Properties
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private weak var parent: CloudKitService?
    
    @Published var isAuthenticated = false
    @Published var currentUser: CloudKitUser?
    @Published var isLoading = false
    @Published var showAuthSheet = false
    @Published var showUsernameSelection = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Auth completion callback
    var authCompletionHandler: (() -> Void)?
    
    // MARK: - Initialization
    init(container: CKContainer, publicDB: CKDatabase, privateDB: CKDatabase, parent: CloudKitService) {
        self.container = container
        self.publicDatabase = publicDB
        self.privateDatabase = privateDB
        self.parent = parent
    }
    
    // MARK: - Authentication Status
    func checkAuthStatus() {
        Task {
            if let storedUserID = UserDefaults.standard.string(forKey: "currentUserRecordID") {
                await loadUser(recordID: storedUserID)
            }
        }
    }
    
    // MARK: - Sign In Methods
    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw CloudKitAuthError.invalidCredential
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let userID = appleIDCredential.user
        let email = appleIDCredential.email
        let fullName = appleIDCredential.fullName
        
        let recordID = CKRecord.ID(recordName: userID)
        
        do {
            // Try to fetch existing user
            let existingRecord = try await publicDatabase.record(for: recordID)
            
            // Update last login
            existingRecord[CKField.User.lastLoginAt] = Date()
            try await publicDatabase.save(existingRecord)
            
            // Convert to user object
            self.currentUser = CloudKitUser(from: existingRecord)
            self.isAuthenticated = true
            parent?.isAuthenticated = true
            parent?.currentUser = self.currentUser
            
            // Store user ID
            UserDefaults.standard.set(userID, forKey: "currentUserRecordID")
            UserDefaults.standard.set(userID, forKey: "currentUserID")
            
            // Check if user has a username set
            if self.currentUser?.username == nil || self.currentUser?.username?.isEmpty == true {
                self.showUsernameSelection = true
            } else {
                self.showAuthSheet = false
                
                if let handler = authCompletionHandler {
                    handler()
                    authCompletionHandler = nil
                }
            }
        } catch {
            // User doesn't exist, create new
            let newRecord = CKRecord(recordType: CloudKitConfig.userRecordType, recordID: recordID)
            
            // Set initial values
            newRecord[CKField.User.authProvider] = "apple"
            newRecord[CKField.User.email] = email ?? ""
            newRecord[CKField.User.displayName] = fullName?.formatted() ?? "Anonymous Chef"
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
            
            try await publicDatabase.save(newRecord)
            
            // Convert to user object
            self.currentUser = CloudKitUser(from: newRecord)
            self.isAuthenticated = true
            parent?.isAuthenticated = true
            parent?.currentUser = self.currentUser
            
            // Store user ID
            UserDefaults.standard.set(userID, forKey: "currentUserRecordID")
            UserDefaults.standard.set(userID, forKey: "currentUserID")
            
            // Show username selection for new users
            self.showUsernameSelection = true
        }
    }
    
    func signInWithFacebook(userID: String, email: String?, name: String?, profileImageURL: String?) async throws {
        let cloudKitUserID = "facebook_\(userID)"
        await signInWithProvider(
            userID: cloudKitUserID,
            provider: "facebook",
            email: email,
            displayName: name,
            profileImageURL: profileImageURL
        )
    }
    
    private func signInWithProvider(
        userID: String,
        provider: String,
        email: String?,
        displayName: String?,
        profileImageURL: String? = nil
    ) async {
        isLoading = true
        defer { isLoading = false }
        
        let recordID = CKRecord.ID(recordName: userID)
        
        do {
            // Try to fetch existing user
            let existingRecord = try await publicDatabase.record(for: recordID)
            
            // Update last login
            existingRecord[CKField.User.lastLoginAt] = Date()
            if let profileImageURL = profileImageURL {
                existingRecord[CKField.User.profileImageURL] = profileImageURL
            }
            try await publicDatabase.save(existingRecord)
            
            // Convert to user object
            self.currentUser = CloudKitUser(from: existingRecord)
            self.isAuthenticated = true
            parent?.isAuthenticated = true
            parent?.currentUser = self.currentUser
            
            // Store user ID
            UserDefaults.standard.set(userID, forKey: "currentUserRecordID")
            UserDefaults.standard.set(userID, forKey: "currentUserID")
            
            // Check if user has a username set
            if self.currentUser?.username == nil || self.currentUser?.username?.isEmpty == true {
                self.showUsernameSelection = true
            } else {
                self.showAuthSheet = false
                
                if let handler = authCompletionHandler {
                    handler()
                    authCompletionHandler = nil
                }
            }
        } catch {
            // Create new user
            let newRecord = CKRecord(recordType: CloudKitConfig.userRecordType, recordID: recordID)
            
            // Set initial values
            newRecord[CKField.User.authProvider] = provider
            newRecord[CKField.User.email] = email ?? ""
            newRecord[CKField.User.displayName] = displayName ?? "Anonymous Chef"
            newRecord[CKField.User.profileImageURL] = profileImageURL ?? ""
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
            
            do {
                try await publicDatabase.save(newRecord)
                
                // Convert to user object
                self.currentUser = CloudKitUser(from: newRecord)
                self.isAuthenticated = true
                parent?.isAuthenticated = true
                parent?.currentUser = self.currentUser
                
                // Store user ID
                UserDefaults.standard.set(userID, forKey: "currentUserRecordID")
            } catch {
                print("Failed to create new user: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
        
        // Only close auth sheet if we have a username
        if let username = currentUser?.username, !username.isEmpty {
            self.showAuthSheet = false
            
            if let handler = authCompletionHandler {
                handler()
                authCompletionHandler = nil
            }
        } else {
            self.showUsernameSelection = true
        }
    }
    
    // MARK: - Username Management
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let predicate = NSPredicate(format: "%K == %@", CKField.User.username, username.lowercased())
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        
        do {
            let results = try await publicDatabase.records(matching: query)
            return results.matchResults.isEmpty
        } catch {
            throw CloudKitAuthError.networkError
        }
    }
    
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
        
        // Fetch current record
        let record = try await publicDatabase.record(for: CKRecord.ID(recordName: recordID))
        
        // Update username
        record[CKField.User.username] = username.lowercased()
        
        // Save
        try await publicDatabase.save(record)
        
        // Update local user
        self.currentUser?.username = username
        parent?.currentUser = self.currentUser
        
        // Close username selection
        self.showUsernameSelection = false
        
        // Now close the auth sheet since we have a username
        self.showAuthSheet = false
        
        // Call completion handler if set
        if let handler = authCompletionHandler {
            handler()
            authCompletionHandler = nil
        }
    }
    
    // MARK: - User Stats Updates
    func updateUserStats(_ updates: UserStatUpdates) async throws {
        guard let currentUser = currentUser,
              let recordID = currentUser.recordID else {
            throw CloudKitAuthError.notAuthenticated
        }
        
        let record = try await publicDatabase.record(for: CKRecord.ID(recordName: recordID))
        
        // Apply updates
        if let totalPoints = updates.totalPoints {
            record[CKField.User.totalPoints] = Int64(totalPoints)
        }
        if let currentStreak = updates.currentStreak {
            record[CKField.User.currentStreak] = Int64(currentStreak)
        }
        if let challengesCompleted = updates.challengesCompleted {
            record[CKField.User.challengesCompleted] = Int64(challengesCompleted)
        }
        if let recipesShared = updates.recipesShared {
            record[CKField.User.recipesShared] = Int64(recipesShared)
        }
        if let coinBalance = updates.coinBalance {
            record[CKField.User.coinBalance] = Int64(coinBalance)
        }
        if let followerCount = updates.followerCount {
            record[CKField.User.followerCount] = Int64(followerCount)
        }
        if let followingCount = updates.followingCount {
            record[CKField.User.followingCount] = Int64(followingCount)
        }
        
        record[CKField.User.lastActiveAt] = Date()
        
        // Save
        try await publicDatabase.save(record)
        
        // Update local user
        if let totalPoints = updates.totalPoints {
            self.currentUser?.totalPoints = totalPoints
        }
        if let currentStreak = updates.currentStreak {
            self.currentUser?.currentStreak = currentStreak
        }
        if let challengesCompleted = updates.challengesCompleted {
            self.currentUser?.challengesCompleted = challengesCompleted
        }
        if let recipesShared = updates.recipesShared {
            self.currentUser?.recipesShared = recipesShared
        }
        if let coinBalance = updates.coinBalance {
            self.currentUser?.coinBalance = coinBalance
        }
        if let followerCount = updates.followerCount {
            self.currentUser?.followerCount = followerCount
        }
        if let followingCount = updates.followingCount {
            self.currentUser?.followingCount = followingCount
        }
        
        parent?.currentUser = self.currentUser
    }
    
    // MARK: - Feature Access
    func isAuthRequiredFor(feature: AuthRequiredFeature) -> Bool {
        switch feature {
        case .challenges, .leaderboard, .socialSharing, .teams, .streaks, .premiumFeatures:
            return !isAuthenticated
        case .basicRecipes:
            return false
        }
    }
    
    func promptAuthForFeature(_ feature: AuthRequiredFeature) {
        if isAuthRequiredFor(feature: feature) {
            showAuthSheet = true
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        parent?.isAuthenticated = false
        parent?.currentUser = nil
        UserDefaults.standard.removeObject(forKey: "currentUserRecordID")
        UserDefaults.standard.removeObject(forKey: "currentUserID")
    }
    
    // MARK: - Social Methods
    func followUser(_ userID: String) async throws {
        guard let currentUserID = currentUser?.recordID,
              let currentUserName = currentUser?.displayName else {
            throw CloudKitAuthError.notAuthenticated
        }
        
        // Check if already following
        let isFollowing = try await self.isFollowing(userID)
        if isFollowing {
            return // Already following
        }
        
        // Create follow record
        let follow = CKRecord(recordType: CloudKitConfig.followRecordType)
        follow[CKField.Follow.followerID] = currentUserID
        follow[CKField.Follow.followingID] = userID
        follow[CKField.Follow.followedAt] = Date()
        follow[CKField.Follow.isActive] = Int64(1)
        
        try await publicDatabase.save(follow)
        
        // Update counts
        await updateSocialCounts()
        
        // Update followed user's follower count
        await updateUserFollowerCount(userID, increment: true)
        
        // Create activity for the followed user
        if let syncModule = parent?.syncModule {
            try await syncModule.createActivity(
                type: "follow",
                actorID: currentUserID,
                actorName: currentUserName,
                targetUserID: userID
            )
        }
    }
    
    func unfollowUser(_ userID: String) async throws {
        guard let currentUserID = currentUser?.recordID else {
            throw CloudKitAuthError.notAuthenticated
        }
        
        // Find the follow record
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@ AND %K == %d",
                                  CKField.Follow.followerID, currentUserID,
                                  CKField.Follow.followingID, userID,
                                  CKField.Follow.isActive, 1)
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        let results = try await publicDatabase.records(matching: query)
        
        // Soft delete the follow record
        for (_, result) in results.matchResults {
            if case .success(let record) = result {
                record[CKField.Follow.isActive] = Int64(0)
                try await publicDatabase.save(record)
            }
        }
        
        // Update counts
        await updateSocialCounts()
        
        // Update unfollowed user's follower count
        await updateUserFollowerCount(userID, increment: false)
    }
    
    func isFollowing(_ userID: String) async throws -> Bool {
        guard let currentUserID = currentUser?.recordID else {
            throw CloudKitAuthError.notAuthenticated
        }
        
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@ AND %K == %d",
                                  CKField.Follow.followerID, currentUserID,
                                  CKField.Follow.followingID, userID,
                                  CKField.Follow.isActive, 1)
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        let results = try await publicDatabase.records(matching: query)
        return !results.matchResults.isEmpty
    }
    
    func updateRecipeCounts() async {
        guard let currentUserID = currentUser?.recordID else { return }
        
        do {
            // Count user's created recipes
            let createdPredicate = NSPredicate(format: "ownerID == %@", currentUserID)
            let createdQuery = CKQuery(recordType: "Recipe", predicate: createdPredicate)
            let createdResults = try await publicDatabase.records(matching: createdQuery)
            let recipesCreated = createdResults.matchResults.count
            
            // Count user's shared recipes (public recipes)
            let sharedPredicate = NSPredicate(format: "ownerID == %@ AND isPublic == 1", currentUserID)
            let sharedQuery = CKQuery(recordType: "Recipe", predicate: sharedPredicate)
            let sharedResults = try await publicDatabase.records(matching: sharedQuery)
            let recipesShared = sharedResults.matchResults.count
            
            // Update user record in CloudKit
            let updates = UserStatUpdates(
                recipesShared: recipesShared,
                recipesCreated: recipesCreated
            )
            try await updateUserStats(updates)
            
            // Update local currentUser object immediately for UI refresh
            await MainActor.run {
                self.currentUser?.recipesShared = recipesShared
                self.currentUser?.recipesCreated = recipesCreated
                parent?.currentUser = self.currentUser
            }
        } catch {
            print("Failed to update recipe counts: \(error)")
        }
    }
    
    func updateSocialCounts() async {
        guard let currentUserID = currentUser?.recordID else { return }
        
        do {
            // Count followers
            let followersPredicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                               CKField.Follow.followingID, currentUserID,
                                               CKField.Follow.isActive, 1)
            let followersQuery = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: followersPredicate)
            let followerResults = try await publicDatabase.records(matching: followersQuery)
            let followerCount = followerResults.matchResults.count
            
            // Count following
            let followingPredicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                               CKField.Follow.followerID, currentUserID,
                                               CKField.Follow.isActive, 1)
            let followingQuery = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: followingPredicate)
            let followingResults = try await publicDatabase.records(matching: followingQuery)
            let followingCount = followingResults.matchResults.count
            
            // Update user record in CloudKit
            let updates = UserStatUpdates(
                followerCount: followerCount,
                followingCount: followingCount
            )
            try await updateUserStats(updates)
            
            // Update local currentUser object immediately for UI refresh
            await MainActor.run {
                self.currentUser?.followerCount = followerCount
                self.currentUser?.followingCount = followingCount
                parent?.currentUser = self.currentUser
            }
        } catch {
            print("Failed to update social counts: \(error)")
        }
    }
    
    private func updateUserFollowerCount(_ userID: String, increment: Bool) async {
        do {
            let record = try await publicDatabase.record(for: CKRecord.ID(recordName: userID))
            let currentCount = record[CKField.User.followerCount] as? Int64 ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            record[CKField.User.followerCount] = newCount
            try await publicDatabase.save(record)
        } catch {
            print("Failed to update follower count for user \(userID): \(error)")
        }
    }
    
    // MARK: - Private Helpers
    private func loadUser(recordID: String) async {
        do {
            let record = try await publicDatabase.record(for: CKRecord.ID(recordName: recordID))
            self.currentUser = CloudKitUser(from: record)
            self.isAuthenticated = true
            parent?.isAuthenticated = true
            parent?.currentUser = self.currentUser
            
            // Update last active
            record[CKField.User.lastActiveAt] = Date()
            try await publicDatabase.save(record)
        } catch {
            // User not found or error
            UserDefaults.standard.removeObject(forKey: "currentUserRecordID")
            self.isAuthenticated = false
            parent?.isAuthenticated = false
        }
    }
    
    /// Public method to refresh the current user's data from CloudKit
    func refreshCurrentUser() async {
        guard let userID = currentUser?.recordID else { return }
        await loadUser(recordID: userID)
    }
    
    // MARK: - User Discovery Methods
    func searchUsers(query: String) async throws -> [CloudKitUser] {
        let predicate = NSPredicate(format: "%K BEGINSWITH %@ OR %K CONTAINS %@",
                                  CKField.User.username, query.lowercased(),
                                  CKField.User.displayName, query)
        let ckQuery = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: CKField.User.followerCount, ascending: false)]
        
        let results = try await publicDatabase.records(matching: ckQuery)
        var users: [CloudKitUser] = []
        
        for (_, result) in results.matchResults {
            if case .success(let record) = result {
                if let user = parseUserRecord(record) {
                    users.append(user)
                }
            }
        }
        
        return users
    }
    
    func getSuggestedUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        // Get users with high follower count that current user isn't following
        let predicate = NSPredicate(format: "%K > %d", CKField.User.followerCount, 100)
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.User.followerCount, ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = limit
        
        var users: [CloudKitUser] = []
        
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                if let user = self.parseUserRecord(record) {
                    users.append(user)
                }
            }
        }
        
        publicDatabase.add(operation)
        
        // Filter out users already being followed
        if let currentUserID = currentUser?.recordID {
            let followedUsers = await getFollowingIDs(currentUserID)
            return users.filter { user in
                if let userID = user.recordID {
                    return !followedUsers.contains(userID) && userID != currentUserID
                }
                return true
            }
        }
        
        return users
    }
    
    func getTrendingUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        // Get users who have been active recently
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let predicate = NSPredicate(format: "%K > %@", CKField.User.lastActiveAt, oneWeekAgo as NSDate)
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.User.recipesShared, ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = limit
        
        var users: [CloudKitUser] = []
        
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                if let user = self.parseUserRecord(record) {
                    users.append(user)
                }
            }
        }
        
        publicDatabase.add(operation)
        return users
    }
    
    func getVerifiedUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        let predicate = NSPredicate(format: "%K == %d", CKField.User.isVerified, 1)
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.User.followerCount, ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = limit
        
        var users: [CloudKitUser] = []
        
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                if let user = self.parseUserRecord(record) {
                    users.append(user)
                }
            }
        }
        
        publicDatabase.add(operation)
        return users
    }
    
    private func getFollowingIDs(_ userID: String) async -> Set<String> {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                  CKField.Follow.followerID, userID,
                                  CKField.Follow.isActive, 1)
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        do {
            let results = try await publicDatabase.records(matching: query)
            var followingIDs = Set<String>()
            
            for (_, result) in results.matchResults {
                if case .success(let record) = result,
                   let followingID = record[CKField.Follow.followingID] as? String {
                    followingIDs.insert(followingID)
                }
            }
            
            return followingIDs
        } catch {
            print("Failed to get following IDs: \(error)")
            return []
        }
    }
    
    private func parseUserRecord(_ record: CKRecord) -> CloudKitUser? {
        return CloudKitUser(from: record)
    }
}

// MARK: - Auth Required Features
enum AuthRequiredFeature {
    case challenges
    case leaderboard
    case socialSharing
    case teams
    case streaks
    case premiumFeatures
    case basicRecipes
}