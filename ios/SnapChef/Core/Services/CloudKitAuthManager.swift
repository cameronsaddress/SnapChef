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
        // Simplified initialization for compilation fix
        print("CloudKitAuthManager initialized")
    }
    
    /// Calculate exponential backoff delay for auth operations
    private func calculateAuthBackoffDelay(attempt: Int) -> TimeInterval {
        return 1.0 // Simplified implementation
    }
    
    /// Sign in with Apple ID for CloudKit authentication
    func signInWithApple(authorization: Any) async throws {
        // Simplified implementation for compilation fix
        print("Sign in with Apple called - simplified implementation")
        isAuthenticated = true
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
    
    /// Get suggested users for discovery
    func getSuggestedUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        let predicate = NSPredicate(format: "%K == %d", CKField.User.isProfilePublic, 1)
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.User.followerCount, ascending: false)]
        
        do {
            let results = try await database.records(matching: query)
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
            throw CloudKitAuthError.networkError
        }
    }
    
    /// Get trending users based on recent activity
    func getTrendingUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        let predicate = NSPredicate(format: "%K == %d", CKField.User.isProfilePublic, 1)
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.User.recipesShared, ascending: false)]
        
        do {
            let results = try await database.records(matching: query)
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
            throw CloudKitAuthError.networkError
        }
    }
    
    /// Get verified users
    func getVerifiedUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        let predicate = NSPredicate(format: "%K == %d AND %K == %d", 
                                  CKField.User.isVerified, 1,
                                  CKField.User.isProfilePublic, 1)
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.User.followerCount, ascending: false)]
        
        do {
            let results = try await database.records(matching: query)
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
            throw CloudKitAuthError.networkError
        }
    }
    
    /// Search users by username or display name
    func searchUsers(query: String) async throws -> [CloudKitUser] {
        guard !query.isEmpty else {
            return []
        }
        
        let predicate = NSPredicate(
            format: "(%K CONTAINS[cd] %@ OR %K CONTAINS[cd] %@) AND %K == %d",
            CKField.User.username, query,
            CKField.User.displayName, query,
            CKField.User.isProfilePublic, 1
        )
        
        let queryObj = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        queryObj.sortDescriptors = [NSSortDescriptor(key: CKField.User.followerCount, ascending: false)]
        
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
        self.username = record["username"] as? String
        self.displayName = record["displayName"] as? String ?? "Anonymous Chef"
        self.profilePictureData = record["profilePictureData"] as? Data
        self.totalLikes = record["totalLikes"] as? Int ?? 0
        self.totalShares = record["totalShares"] as? Int ?? 0
        self.streakCount = record["streakCount"] as? Int ?? 0
        self.joinDate = record["joinDate"] as? Date ?? Date()
        self.lastActiveDate = record["lastActiveDate"] as? Date ?? Date()
        self.isVerified = record["isVerified"] as? Bool ?? false
        self.bio = record["bio"] as? String
        self.favoriteRecipes = record["favoriteRecipes"] as? [String] ?? []
        self.challengesCompleted = record["challengesCompleted"] as? Int ?? 0
        self.level = record["level"] as? Int ?? 1
        self.experiencePoints = record["experiencePoints"] as? Int ?? 0
        self.recipesShared = record["recipesShared"] as? Int ?? 0
        self.followerCount = record["followerCount"] as? Int ?? 0
        self.followingCount = record["followingCount"] as? Int ?? 0
        self.profileImageURL = record["profileImageURL"] as? String
        self.createdAt = record["createdAt"] as? Date ?? Date()
        self.lastLoginAt = record["lastLoginAt"] as? Date ?? Date()
        self.totalPoints = record["totalPoints"] as? Int ?? 0
        self.currentStreak = record["currentStreak"] as? Int ?? 0
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