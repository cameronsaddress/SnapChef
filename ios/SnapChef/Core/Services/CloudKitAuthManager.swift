import Foundation
import CloudKit
import AuthenticationServices
import GoogleSignIn
import SwiftUI

@MainActor
class CloudKitAuthManager: ObservableObject {
    static let shared = CloudKitAuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: CloudKitUser?
    @Published var isLoading = false
    @Published var showAuthSheet = false
    @Published var showUsernameSelection = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Auth completion callback
    var authCompletionHandler: (() -> Void)?
    
    private let container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
    private let database = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase
    
    private init() {
        checkAuthStatus()
    }
    
    // MARK: - Check Current Auth Status
    
    func checkAuthStatus() {
        Task {
            // Check if we have a stored user ID
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
        
        // Check if user exists in CloudKit
        let recordID = CKRecord.ID(recordName: userID)
        
        do {
            // Try to fetch existing user
            let existingRecord = try await database.record(for: recordID)
            
            // Update last login
            existingRecord[CKField.User.lastLoginAt] = Date()
            try await database.save(existingRecord)
            
            // Convert to user object
            self.currentUser = CloudKitUser(from: existingRecord)
            self.isAuthenticated = true
            
            // Store user ID (use both keys for compatibility)
            UserDefaults.standard.set(userID, forKey: "currentUserRecordID")
            UserDefaults.standard.set(userID, forKey: "currentUserID")
            
            // Check if user has a username set
            if self.currentUser?.username == nil || self.currentUser?.username?.isEmpty == true {
                // Show username selection for users without username
                self.showUsernameSelection = true
            } else {
                // User has username, close auth sheet and call completion handler
                self.showAuthSheet = false
                
                // Call completion handler if set (e.g., to join challenge after auth)
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
            
            // Save new user
            try await database.save(newRecord)
            
            // Convert to user object
            self.currentUser = CloudKitUser(from: newRecord)
            self.isAuthenticated = true
            
            // Store user ID (use both keys for compatibility)
            UserDefaults.standard.set(userID, forKey: "currentUserRecordID")
            UserDefaults.standard.set(userID, forKey: "currentUserID")
            
            // Show username selection for new users
            self.showUsernameSelection = true
        }
    }
    
    func signInWithGoogle(user: GIDGoogleUser) async throws {
        // Use Google user ID with prefix to ensure uniqueness
        let userID = "google_\(user.userID ?? UUID().uuidString)"
        await signInWithProvider(
            userID: userID,
            provider: "google",
            email: user.profile?.email,
            displayName: user.profile?.name,
            profileImageURL: user.profile?.imageURL(withDimension: 200)?.absoluteString
        )
    }
    
    func signInWithFacebook(userID: String, email: String?, name: String?, profileImageURL: String?) async throws {
        // Use Facebook user ID with prefix to ensure uniqueness
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
            let existingRecord = try await database.record(for: recordID)
            
            // Update last login
            existingRecord[CKField.User.lastLoginAt] = Date()
            if let profileImageURL = profileImageURL {
                existingRecord[CKField.User.profileImageURL] = profileImageURL
            }
            try await database.save(existingRecord)
            
            // Convert to user object
            self.currentUser = CloudKitUser(from: existingRecord)
            self.isAuthenticated = true
            
            // Store user ID (use both keys for compatibility)
            UserDefaults.standard.set(userID, forKey: "currentUserRecordID")
            UserDefaults.standard.set(userID, forKey: "currentUserID")
            
            // Check if user has a username set
            if self.currentUser?.username == nil || self.currentUser?.username?.isEmpty == true {
                // Show username selection for users without username
                self.showUsernameSelection = true
            } else {
                // User has username, close auth sheet and call completion handler
                self.showAuthSheet = false
                
                // Call completion handler if set (e.g., to join challenge after auth)
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
            
            // Save new user
            do {
                try await database.save(newRecord)
                
                // Convert to user object
                self.currentUser = CloudKitUser(from: newRecord)
                self.isAuthenticated = true
                
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
            
            // Call completion handler if set (e.g., to join challenge after auth)
            if let handler = authCompletionHandler {
                handler()
                authCompletionHandler = nil
            }
        } else {
            // Show username selection for new users
            self.showUsernameSelection = true
        }
    }
    
    // MARK: - Username Management
    
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
        let record = try await database.record(for: CKRecord.ID(recordName: recordID))
        
        // Update username
        record[CKField.User.username] = username.lowercased()
        
        // Save
        try await database.save(record)
        
        // Update local user
        self.currentUser?.username = username
        
        // Close username selection
        self.showUsernameSelection = false
        
        // Now close the auth sheet since we have a username
        self.showAuthSheet = false
        
        // Call completion handler if set (e.g., to join challenge after auth)
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
        
        let record = try await database.record(for: CKRecord.ID(recordName: recordID))
        
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
        try await database.save(record)
        
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
        UserDefaults.standard.removeObject(forKey: "currentUserRecordID")
    }
    
    // MARK: - Social Methods
    
    func followUser(_ userID: String) async throws {
        guard let currentUserID = currentUser?.recordID,
              let currentUserName = currentUser?.displayName else {
            throw CloudKitAuthError.notAuthenticated
        }
        
        // Check if already following
        let isFollowing = try await isFollowing(userID)
        if isFollowing {
            return // Already following
        }
        
        // Create follow record
        let follow = CKRecord(recordType: CloudKitConfig.followRecordType)
        follow[CKField.Follow.followerID] = currentUserID
        follow[CKField.Follow.followingID] = userID
        follow[CKField.Follow.followedAt] = Date()
        follow[CKField.Follow.isActive] = Int64(1)
        
        try await database.save(follow)
        
        // Update counts
        await updateSocialCounts()
        
        // Update followed user's follower count
        await updateUserFollowerCount(userID, increment: true)
        
        // Create activity for the followed user
        try await CloudKitSyncService.shared.createActivity(
            type: "follow",
            actorID: currentUserID,
            actorName: currentUserName,
            targetUserID: userID
        )
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
        
        let results = try await database.records(matching: query)
        
        // Soft delete the follow record
        for (_, result) in results.matchResults {
            if case .success(let record) = result {
                record[CKField.Follow.isActive] = Int64(0)
                try await database.save(record)
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
        
        let results = try await database.records(matching: query)
        return !results.matchResults.isEmpty
    }
    
    func updateSocialCounts() async {
        guard let currentUserID = currentUser?.recordID else { return }
        
        do {
            // Count followers
            let followersPredicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                               CKField.Follow.followingID, currentUserID,
                                               CKField.Follow.isActive, 1)
            let followersQuery = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: followersPredicate)
            let followerResults = try await database.records(matching: followersQuery)
            let followerCount = followerResults.matchResults.count
            
            // Count following
            let followingPredicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                               CKField.Follow.followerID, currentUserID,
                                               CKField.Follow.isActive, 1)
            let followingQuery = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: followingPredicate)
            let followingResults = try await database.records(matching: followingQuery)
            let followingCount = followingResults.matchResults.count
            
            // Update user record
            let updates = UserStatUpdates(
                followerCount: followerCount,
                followingCount: followingCount
            )
            try await updateUserStats(updates)
        } catch {
            print("Failed to update social counts: \(error)")
        }
    }
    
    private func updateUserFollowerCount(_ userID: String, increment: Bool) async {
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: userID))
            let currentCount = record[CKField.User.followerCount] as? Int64 ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            record[CKField.User.followerCount] = newCount
            try await database.save(record)
        } catch {
            print("Failed to update follower count for user \(userID): \(error)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func loadUser(recordID: String) async {
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            self.currentUser = CloudKitUser(from: record)
            self.isAuthenticated = true
            
            // Update last active
            record[CKField.User.lastActiveAt] = Date()
            try await database.save(record)
        } catch {
            // User not found or error
            UserDefaults.standard.removeObject(forKey: "currentUserRecordID")
            self.isAuthenticated = false
        }
    }
    
    // MARK: - User Discovery Methods
    
    func searchUsers(query: String) async throws -> [CloudKitUser] {
        let predicate = NSPredicate(format: "%K BEGINSWITH %@ OR %K CONTAINS %@",
                                  CKField.User.username, query.lowercased(),
                                  CKField.User.displayName, query)
        let ckQuery = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: CKField.User.followerCount, ascending: false)]
        
        let results = try await database.records(matching: ckQuery)
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
        
        database.add(operation)
        
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
        
        database.add(operation)
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
        
        database.add(operation)
        return users
    }
    
    private func getFollowingIDs(_ userID: String) async -> Set<String> {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                  CKField.Follow.followerID, userID,
                                  CKField.Follow.isActive, 1)
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
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

// MARK: - CloudKit User Model

struct CloudKitUser: Identifiable {
    let id = UUID()
    let recordID: String?
    var username: String?
    let displayName: String
    let email: String?
    let profileImageURL: String?
    let authProvider: String
    var totalPoints: Int
    var currentStreak: Int
    let longestStreak: Int
    var challengesCompleted: Int
    var recipesShared: Int
    let recipesCreated: Int
    var coinBalance: Int
    var followerCount: Int
    var followingCount: Int
    let isProfilePublic: Bool
    let showOnLeaderboard: Bool
    let isVerified: Bool
    let subscriptionTier: String
    let createdAt: Date
    let lastLoginAt: Date
    
    init(from record: CKRecord) {
        self.recordID = record.recordID.recordName
        self.username = record[CKField.User.username] as? String
        self.displayName = record[CKField.User.displayName] as? String ?? "Anonymous Chef"
        self.email = record[CKField.User.email] as? String
        self.profileImageURL = record[CKField.User.profileImageURL] as? String
        self.authProvider = record[CKField.User.authProvider] as? String ?? "unknown"
        self.totalPoints = Int(record[CKField.User.totalPoints] as? Int64 ?? 0)
        self.currentStreak = Int(record[CKField.User.currentStreak] as? Int64 ?? 0)
        self.longestStreak = Int(record[CKField.User.longestStreak] as? Int64 ?? 0)
        self.challengesCompleted = Int(record[CKField.User.challengesCompleted] as? Int64 ?? 0)
        self.recipesShared = Int(record[CKField.User.recipesShared] as? Int64 ?? 0)
        self.recipesCreated = Int(record[CKField.User.recipesCreated] as? Int64 ?? 0)
        self.coinBalance = Int(record[CKField.User.coinBalance] as? Int64 ?? 0)
        self.followerCount = Int(record[CKField.User.followerCount] as? Int64 ?? 0)
        self.followingCount = Int(record[CKField.User.followingCount] as? Int64 ?? 0)
        self.isProfilePublic = (record[CKField.User.isProfilePublic] as? Int64 ?? 1) == 1
        self.showOnLeaderboard = (record[CKField.User.showOnLeaderboard] as? Int64 ?? 1) == 1
        self.isVerified = (record[CKField.User.isVerified] as? Int64 ?? 0) == 1
        self.subscriptionTier = record[CKField.User.subscriptionTier] as? String ?? "free"
        self.createdAt = record[CKField.User.createdAt] as? Date ?? Date()
        self.lastLoginAt = record[CKField.User.lastLoginAt] as? Date ?? Date()
    }
}

// MARK: - Helper Types

struct UserStatUpdates {
    var totalPoints: Int?
    var currentStreak: Int?
    var challengesCompleted: Int?
    var recipesShared: Int?
    var recipesCreated: Int?
    var coinBalance: Int?
    var followerCount: Int?
    var followingCount: Int?
}

// Google and Facebook user info are handled by their respective SDKs
// GoogleSignIn provides GIDGoogleUser
// Facebook SDK provides similar user objects

enum CloudKitAuthError: LocalizedError {
    case invalidCredential
    case networkError
    case notAuthenticated
    case usernameUnavailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid authentication credentials"
        case .networkError:
            return "Network error. Please try again."
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .usernameUnavailable:
            return "This username is already taken"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}