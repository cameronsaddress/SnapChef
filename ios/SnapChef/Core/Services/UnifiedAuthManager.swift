//
//  UnifiedAuthManager.swift
//  SnapChef
//
//  Consolidated authentication system combining CloudKit, TikTok, and progressive auth
//  Simplifies the auth flow while maintaining all functionality
//

import Foundation
import CloudKit
import AuthenticationServices
import SwiftUI
import TikTokOpenAuthSDK
import os

/// Unified authentication manager that handles all authentication flows
/// Combines CloudKit, TikTok, and progressive authentication into a single, clean interface
@MainActor
final class UnifiedAuthManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = UnifiedAuthManager()
    
    // MARK: - Published State
    
    @Published var isAuthenticated = false
    @Published var currentUser: CloudKitUser?
    @Published var tikTokUser: TikTokUser?
    @Published var isLoading = false
    @Published var showAuthSheet = false
    @Published var showUsernameSetup = false
    @Published var showUsernameSelection = false  // Added for CloudKitAuthView compatibility
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Progressive Auth State
    @Published var anonymousProfile: AnonymousUserProfile?
    @Published var shouldShowProgressivePrompt = false
    
    // MARK: - Dependencies
    
    private let cloudKitContainer = CKContainer(identifier: CloudKitConfig.containerIdentifier)
    private let cloudKitDatabase = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase
    internal let profileManager = KeychainProfileManager.shared
    private let tikTokAuthManager = TikTokAuthManager.shared
    
    // MARK: - Auth completion callback
    var authCompletionHandler: (() -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        // Load anonymous profile async
        Task { @MainActor in
            self.anonymousProfile = await profileManager.getOrCreateProfile()
        }
        
        // Check existing auth status
        checkAuthStatus()
    }
    
    // MARK: - Auth Status Management
    
    func checkAuthStatus() {
        // Check CloudKit auth - silently on app launch
        if let storedUserID = UserDefaults.standard.string(forKey: "currentUserRecordID") {
            print("🔍 Found stored CloudKit userRecordID: \(storedUserID)")
            Task {
                await loadCloudKitUser(recordID: storedUserID, silent: true)
            }
        } else if let legacyUserID = UserDefaults.standard.string(forKey: "currentUserID") {
            print("🔍 Found legacy currentUserID: \(legacyUserID)")
            Task {
                await loadCloudKitUser(recordID: legacyUserID, silent: true)
            }
        } else {
            print("ℹ️ No stored CloudKit user ID found")
        }
        
        // Check TikTok auth
        Task {
            if tikTokAuthManager.isAuthenticatedUser() {
                do {
                    self.tikTokUser = try await tikTokAuthManager.getUserProfile()
                } catch {
                    // TikTok auth expired, handle silently
                }
            }
        }
    }
    
    // MARK: - CloudKit Authentication
    
    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw UnifiedAuthError.invalidCredential
        }
        
        isLoading = true
        defer { 
            isLoading = false
            showError = false
            errorMessage = ""
        }
        
        print("🔑 Starting unified CloudKit Sign in with Apple...")
        
        // CRITICAL FIX: Get the actual CloudKit userRecordID, not the Apple ID credential user ID
        let accountStatus: CKAccountStatus
        do {
            accountStatus = try await cloudKitContainer.accountStatus()
        } catch {
            print("❌ Failed to check CloudKit account status: \(error)")
            errorMessage = "Unable to access iCloud. Please check your iCloud settings."
            showError = true
            throw UnifiedAuthError.cloudKitNotAvailable
        }
        
        guard accountStatus == .available else {
            print("⚠️ CloudKit account not available: \(accountStatus)")
            switch accountStatus {
            case .noAccount:
                errorMessage = "Please sign in to iCloud in Settings to use this feature."
            case .restricted:
                errorMessage = "iCloud access is restricted on this device."
            case .temporarilyUnavailable:
                errorMessage = "iCloud is temporarily unavailable. Please try again later."
            default:
                errorMessage = "Unable to access iCloud. Please check your settings."
            }
            showError = true
            throw UnifiedAuthError.cloudKitNotAvailable
        }
        
        // Get the CloudKit user record ID (this is the stable ID we need)
        let userRecord = try await cloudKitContainer.userRecordID()
        let cloudKitUserID = userRecord.recordName
        
        print("✅ CloudKit userRecordID: \(cloudKitUserID)")
        
        let email = appleIDCredential.email
        let fullName = appleIDCredential.fullName
        let appleUserID = appleIDCredential.user  // The Apple ID user identifier
        
        // Use compound key to avoid conflicts with CloudKit system records
        let userRecordID = CKRecord.ID(recordName: "user_\(cloudKitUserID)")
        
        do {
            // Try to fetch existing user
            let existingRecord = try await cloudKitDatabase.record(for: userRecordID)
            
            // Check if record has correct type
            if existingRecord.recordType == CloudKitConfig.userRecordType {
                // Update last login - only if record type is correct
                existingRecord[CKField.User.lastLoginAt] = Date()
                try await cloudKitDatabase.save(existingRecord)
                
                // Update state
                self.currentUser = CloudKitUser(from: existingRecord)
                self.isAuthenticated = true
            } else {
                print("⚠️ User record has incorrect type '\(existingRecord.recordType)', expected '\(CloudKitConfig.userRecordType)'. Will delete and recreate.")
                // Try to delete the old record with wrong type
                do {
                    _ = try await cloudKitDatabase.deleteRecord(withID: existingRecord.recordID)
                    print("✅ Deleted old record with incorrect type")
                } catch {
                    print("⚠️ Could not delete old record: \(error.localizedDescription)")
                    // Continue anyway - we'll create a new record with a different ID
                }
                throw UnifiedAuthError.cloudKitNotAvailable // Will trigger creation of new record
            }
            
            // Store the CloudKit user ID (this is the persistent ID we need)
            UserDefaults.standard.set(cloudKitUserID, forKey: "currentUserRecordID")
            UserDefaults.standard.set(cloudKitUserID, forKey: "currentUserID") // For compatibility
            
            // Migrate anonymous data if available
            await migrateAnonymousData()
            
            print("✅ Existing CloudKit user loaded: \(cloudKitUserID)")
            
            // Check username requirement
            if self.currentUser?.username == nil || self.currentUser?.username?.isEmpty == true {
                self.showUsernameSetup = true
            } else {
                completeAuthentication()
            }
            
        } catch {
            print("📝 Creating new user record for CloudKit ID: \(cloudKitUserID)")
            print("📝 Using record ID: \(userRecordID)")
            
            // Create new user with compound key
            let newRecord = CKRecord(recordType: CloudKitConfig.userRecordType, recordID: userRecordID)
            
            // Note: cloudKitUserID is already encoded in the recordID as "user_<cloudKitUserID>"
            // No need to store it separately since that field doesn't exist in production
            
            // Set initial values - ONLY fields that exist in production!
            print("📝 Setting CloudKit User fields (production schema):")
            print("   authProvider: apple")
            print("   appleUserId: \(appleUserID)")
            print("   email: \(email ?? "none")")
            print("   displayName: \(fullName?.formatted() ?? "Anonymous Chef")")
            
            newRecord[CKField.User.authProvider] = "apple"
            newRecord[CKField.User.appleUserId] = appleUserID  // Store Apple Sign In ID
            newRecord[CKField.User.email] = email ?? ""
            newRecord[CKField.User.displayName] = fullName?.formatted() ?? "Anonymous Chef"
            newRecord[CKField.User.createdAt] = Date()
            newRecord[CKField.User.lastLoginAt] = Date()
            
            // Set default values for integer fields
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
            
            // Copy anonymous profile data if available
            if let anonymous = anonymousProfile {
                newRecord[CKField.User.recipesCreated] = Int64(anonymous.recipesCreatedCount)
                newRecord[CKField.User.totalPoints] = Int64(anonymous.engagementScore * 100) // Convert engagement to points
            }
            
            do {
                print("📤 Attempting to save new user record to CloudKit...")
                print("   Database: \(cloudKitDatabase == cloudKitContainer.publicCloudDatabase ? "Public" : "Private")")
                print("   Record Type: \(newRecord.recordType)")
                print("   Record ID: \(newRecord.recordID)")
                
                try await cloudKitDatabase.save(newRecord)
                print("✅ Successfully saved new user record")
            } catch let saveError as CKError {
                // Handle specific CloudKit errors
                print("❌ CloudKit save error code: \(saveError.code)")
                print("❌ CloudKit save error: \(saveError.localizedDescription)")
                
                if saveError.code == .invalidArguments {
                    print("❌ Invalid record save attempt: \(saveError.localizedDescription)")
                    errorMessage = "Unable to create user profile. Please try again."
                    showError = true
                    throw UnifiedAuthError.authenticationFailed
                } else {
                    throw saveError
                }
            }
            
            // Update state
            self.currentUser = CloudKitUser(from: newRecord)
            self.isAuthenticated = true
            
            // Store the CloudKit user ID (this is the persistent ID we need)
            UserDefaults.standard.set(cloudKitUserID, forKey: "currentUserRecordID")
            UserDefaults.standard.set(cloudKitUserID, forKey: "currentUserID") // For compatibility
            
            // Migrate anonymous data
            await migrateAnonymousData()
            
            print("✅ New CloudKit user profile created: \(cloudKitUserID)")
            
            // Show username setup for new users
            self.showUsernameSetup = true
        }
        
        print("🎉 Unified CloudKit authentication completed successfully")
    }
    
    // MARK: - TikTok Authentication
    
    func signInWithTikTok() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            self.tikTokUser = try await tikTokAuthManager.authenticate()
            
            // If user is also authenticated with CloudKit, link the accounts
            if isAuthenticated {
                await linkTikTokAccount()
            }
            
        } catch {
            throw UnifiedAuthError.tikTokAuthFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Username Management
    
    func setUsername(_ username: String) async throws {
        guard let currentUser = currentUser,
              let recordID = currentUser.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        // Check availability
        let isAvailable = try await checkUsernameAvailability(username)
        guard isAvailable else {
            throw UnifiedAuthError.usernameUnavailable
        }
        
        // Update record
        let record = try await cloudKitDatabase.record(for: CKRecord.ID(recordName: recordID))
        record[CKField.User.username] = username.lowercased()
        try await cloudKitDatabase.save(record)
        
        // Update local state
        self.currentUser?.username = username
        self.showUsernameSetup = false
        
        completeAuthentication()
    }
    
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let predicate = NSPredicate(format: "%K == %@", CKField.User.username, username.lowercased())
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        
        let results = try await cloudKitDatabase.records(matching: query)
        return results.matchResults.isEmpty
    }
    
    // MARK: - Progressive Authentication
    
    func trackAnonymousAction(_ action: AnonymousAction) {
        guard var profile = anonymousProfile else { return }
        
        // Don't track if already authenticated
        guard !isAuthenticated else { return }
        
        // Update profile based on action
        switch action {
        case .recipeCreated:
            profile.recipesCreatedCount += 1
        case .recipeViewed:
            profile.recipesViewedCount += 1
        case .videoGenerated:
            profile.videosGeneratedCount += 1
        case .videoShared:
            profile.videosSharedCount += 1
        case .appOpened:
            profile.appOpenCount += 1
        case .challengeViewed:
            profile.challengesViewed += 1
        case .socialExplored:
            profile.socialFeaturesExplored += 1
        }
        
        profile.updateLastActive()
        
        // Save updated profile
        Task {
            if profileManager.saveProfile(profile) {
                await MainActor.run {
                    self.anonymousProfile = profile
                }
            }
        }
        
        // Check if we should show progressive auth prompt
        checkProgressiveAuthConditions(for: action, profile: profile)
    }
    
    private func checkProgressiveAuthConditions(for action: AnonymousAction, profile: AnonymousUserProfile) {
        // Only show if not already authenticated and user hasn't opted out
        guard !isAuthenticated && profile.authenticationState == .anonymous else { return }
        
        // Progressive thresholds based on engagement
        let daysSinceFirstUse = Calendar.current.dateComponents([.day], from: profile.firstLaunchDate, to: Date()).day ?? 0
        
        let shouldShow = switch action {
        case .recipeCreated:
            // Show after 3 recipes or after 7 days with 1 recipe
            profile.recipesCreatedCount >= 3 || (daysSinceFirstUse >= 7 && profile.recipesCreatedCount >= 1)
        case .videoGenerated:
            // Show after 2 videos (viral potential)
            profile.videosGeneratedCount >= 2
        case .videoShared:
            // Show immediately on share (high intent)
            profile.videosSharedCount >= 1
        case .socialExplored:
            // Show after exploring social features twice
            profile.socialFeaturesExplored >= 2
        case .challengeViewed:
            // Show after viewing 2 challenges
            profile.challengesViewed >= 2
        case .appOpened:
            // Show after 5 app opens over 3+ days
            profile.appOpenCount >= 5 && daysSinceFirstUse >= 3
        case .recipeViewed:
            // Don't prompt for just viewing
            false
        }
        
        // Check dismissal cooldown (don't annoy users)
        if shouldShow && !profile.hasRecentDismissals(within: daysSinceFirstUse < 7 ? 7 : 3) {
            // Set context-aware prompt message
            setupProgressivePromptMessage(for: action, profile: profile)
            self.shouldShowProgressivePrompt = true
        }
    }
    
    private func setupProgressivePromptMessage(for action: AnonymousAction, profile: AnonymousUserProfile) {
        switch action {
        case .recipeCreated:
            errorMessage = "🎉 You've created \(profile.recipesCreatedCount) recipes! Sign in to save them forever and unlock challenges."
        case .videoShared:
            errorMessage = "🚀 Your recipe is going viral! Sign in to track views and get credit."
        case .socialExplored:
            errorMessage = "👥 Join the SnapChef community! Sign in to follow chefs and share recipes."
        case .challengeViewed:
            errorMessage = "🏆 Ready for a challenge? Sign in to compete and win rewards!"
        case .videoGenerated:
            errorMessage = "🎬 You're creating amazing content! Sign in to build your following."
        case .appOpened:
            errorMessage = "👋 Welcome back! Sign in to sync your \(profile.recipesCreatedCount) recipes across devices."
        default:
            errorMessage = "✨ Unlock all SnapChef features! Sign in to save recipes and join challenges."
        }
    }
    
    // MARK: - User Discovery Methods
    
    /// Get suggested users for discovery
    func getSuggestedUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        // Check CloudKit availability first
        do {
            let status = try await cloudKitContainer.accountStatus()
            if status != .available {
                print("⚠️ CloudKit not available. Status: \(status.rawValue)")
                if status == .noAccount {
                    throw UnifiedAuthError.cloudKitNotAvailable
                }
            }
        } catch {
            print("❌ Failed to check CloudKit status: \(error)")
            throw UnifiedAuthError.cloudKitNotAvailable
        }
        
        let predicate = NSPredicate(format: "%K == %d", CKField.User.isProfilePublic, 1)
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.User.followerCount, ascending: false)]
        
        do {
            let results = try await cloudKitDatabase.records(matching: query)
            let users = results.matchResults.compactMap { result in
                switch result.1 {
                case .success(let record):
                    return CloudKitUser(from: record)
                case .failure(let error):
                    print("  ⚠️ Failed to parse user record: \(error)")
                    return nil
                }
            }
            print("✅ CloudKit query succeeded. Found \(users.count) users")
            if users.isEmpty {
                print("  ℹ️ No users found matching criteria")
            }
            return Array(users.prefix(limit))
        } catch {
            print("❌ CloudKit query error: \(error)")
            if let ckError = error as? CKError {
                print("  CloudKit Error Code: \(ckError.code.rawValue)")
                if ckError.code == .networkUnavailable || ckError.code == .networkFailure {
                    throw UnifiedAuthError.networkError
                }
            }
            throw UnifiedAuthError.cloudKitError(error)
        }
    }
    
    /// Get trending users based on recent activity
    func getTrendingUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        let predicate = NSPredicate(format: "%K == %d", CKField.User.isProfilePublic, 1)
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.User.recipesShared, ascending: false)]
        
        do {
            let results = try await cloudKitDatabase.records(matching: query)
            let users = results.matchResults.compactMap { result in
                switch result.1 {
                case .success(let record):
                    return CloudKitUser(from: record)
                case .failure(let error):
                    print("  ⚠️ Failed to parse user record: \(error)")
                    return nil
                }
            }
            print("✅ CloudKit query succeeded. Found \(users.count) users")
            if users.isEmpty {
                print("  ℹ️ No users found matching criteria")
            }
            return Array(users.prefix(limit))
        } catch {
            print("❌ CloudKit query error: \(error)")
            if let ckError = error as? CKError {
                print("  CloudKit Error Code: \(ckError.code.rawValue)")
                if ckError.code == .networkUnavailable || ckError.code == .networkFailure {
                    throw UnifiedAuthError.networkError
                }
            }
            throw UnifiedAuthError.cloudKitError(error)
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
            let results = try await cloudKitDatabase.records(matching: query)
            let users = results.matchResults.compactMap { result in
                switch result.1 {
                case .success(let record):
                    return CloudKitUser(from: record)
                case .failure(let error):
                    print("  ⚠️ Failed to parse user record: \(error)")
                    return nil
                }
            }
            print("✅ CloudKit query succeeded. Found \(users.count) users")
            if users.isEmpty {
                print("  ℹ️ No users found matching criteria")
            }
            return Array(users.prefix(limit))
        } catch {
            print("❌ CloudKit query error: \(error)")
            if let ckError = error as? CKError {
                print("  CloudKit Error Code: \(ckError.code.rawValue)")
                if ckError.code == .networkUnavailable || ckError.code == .networkFailure {
                    throw UnifiedAuthError.networkError
                }
            }
            throw UnifiedAuthError.cloudKitError(error)
        }
    }
    
    /// Get new users (recently joined) for discovery
    func getNewUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        let predicate = NSPredicate(format: "%K == %d", CKField.User.isProfilePublic, 1)
        let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.User.createdAt, ascending: false)]
        
        do {
            let results = try await cloudKitDatabase.records(matching: query)
            let users = results.matchResults.compactMap { result in
                switch result.1 {
                case .success(let record):
                    return CloudKitUser(from: record)
                case .failure(let error):
                    print("  ⚠️ Failed to parse user record: \(error)")
                    return nil
                }
            }
            print("✅ CloudKit query succeeded. Found \(users.count) users")
            if users.isEmpty {
                print("  ℹ️ No users found matching criteria")
            }
            return Array(users.prefix(limit))
        } catch {
            print("❌ CloudKit query error: \(error)")
            if let ckError = error as? CKError {
                print("  CloudKit Error Code: \(ckError.code.rawValue)")
                if ckError.code == .networkUnavailable || ckError.code == .networkFailure {
                    throw UnifiedAuthError.networkError
                }
            }
            throw UnifiedAuthError.cloudKitError(error)
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
            let results = try await cloudKitDatabase.records(matching: queryObj)
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
            throw UnifiedAuthError.networkError
        }
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
            let results = try await cloudKitDatabase.records(matching: query)
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
            throw UnifiedAuthError.notAuthenticated
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
        
        _ = try await cloudKitDatabase.save(followRecord)
        
        print("✅ User followed: \(userID)")
        
        // Update local follower count
        self.currentUser?.followingCount += 1
    }
    
    /// Unfollow a user
    func unfollowUser(userID: String) async throws {
        guard let currentUser = currentUser,
              let currentUserID = currentUser.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %@ AND %K == %d",
            CKField.Follow.followerID, currentUserID,
            CKField.Follow.followingID, userID,
            CKField.Follow.isActive, 1
        )
        
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        do {
            let results = try await cloudKitDatabase.records(matching: query)
            
            for result in results.matchResults {
                switch result.1 {
                case .success(let record):
                    // Soft delete by setting isActive to 0
                    record[CKField.Follow.isActive] = Int64(0)
                    _ = try await cloudKitDatabase.save(record)
                case .failure(let error):
                    print("Error processing follow record: \(error)")
                }
            }
            
            print("✅ User unfollowed: \(userID)")
            
            // Update local follower count
            self.currentUser?.followingCount = max(0, (self.currentUser?.followingCount ?? 0) - 1)
        } catch {
            throw UnifiedAuthError.networkError
        }
    }
    
    // MARK: - Feature Access Control
    
    func isAuthRequiredFor(feature: AuthRequiredFeature) -> Bool {
        switch feature {
        case .challenges, .leaderboard, .socialSharing, .teams, .streaks, .premiumFeatures:
            return !isAuthenticated
        case .basicRecipes:
            return false
        }
    }
    
    func promptAuthForFeature(_ feature: AuthRequiredFeature, completion: (() -> Void)? = nil) {
        if isAuthRequiredFor(feature: feature) {
            authCompletionHandler = completion
            showAuthSheet = true
        } else {
            completion?()
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        // Clear CloudKit auth
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "currentUserRecordID")
        
        // Clear TikTok auth
        tikTokAuthManager.logout()
        tikTokUser = nil
        
        // Reset anonymous profile async
        Task { @MainActor in
            anonymousProfile = await profileManager.getOrCreateProfile()
        }
    }
    
    // MARK: - Private Helpers
    
    private func loadCloudKitUser(recordID: String, silent: Bool = false) async {
        do {
            // First verify CloudKit account is still available
            let accountStatus = try await cloudKitContainer.accountStatus()
            guard accountStatus == .available else {
                print("⚠️ CloudKit account not available, status: \(accountStatus)")
                // Only clear auth and show errors if not silent (user-initiated action)
                if !silent {
                    await clearStoredAuth()
                }
                return
            }
            
            // Use compound key for user records
            let userRecordID = CKRecord.ID(recordName: "user_\(recordID)")
            
            // Try to load the user record
            let record = try await cloudKitDatabase.record(for: userRecordID)
            await MainActor.run {
                self.currentUser = CloudKitUser(from: record)
                self.isAuthenticated = true
            }
            
            print("✅ CloudKit user loaded successfully: \(recordID)")
            
            // Update last active in background
            Task {
                do {
                    record[CKField.User.lastActiveAt] = Date()
                    _ = try await cloudKitDatabase.save(record)
                } catch {
                    print("⚠️ Failed to update last active time: \(error)")
                }
            }
        } catch {
            print("❌ Failed to load CloudKit user \(recordID): \(error)")
            // Only clear auth if not silent (user-initiated action)
            if !silent {
                await clearStoredAuth()
            }
        }
    }
    
    private func clearStoredAuth() async {
        await MainActor.run {
            // Clear stored user IDs
            UserDefaults.standard.removeObject(forKey: "currentUserRecordID")
            UserDefaults.standard.removeObject(forKey: "currentUserID")
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
    
    private func migrateAnonymousData() async {
        guard var profile = anonymousProfile else { return }
        
        // Update authentication state
        profile.authenticationState = .authenticated
        profile.addAuthPromptEvent(context: "migration", action: "completed")
        
        // Save updated profile
        Task {
            _ = profileManager.saveProfile(profile)
        }
        
        // Migrate anonymous recipes to authenticated user
        guard let userID = currentUser?.recordID else { return }
        
        print("🔄 Starting migration of anonymous recipes to user: \(userID)")
        
        // Note: Recipe migration would happen here
        // Currently recipes are stored in AppState and CloudKit
        // Future implementation would use LocalRecipeStore for offline-first storage
        
        // For now, just log the migration
        print("📦 Recipe migration would happen here for user: \(userID)")
        
        // Migrate photos from PhotoStorageManager if needed
        let photoCount = PhotoStorageManager.shared.getAnonymousPhotoCount()
        if photoCount > 0 {
            print("📸 Migrating \(photoCount) anonymous photos to user: \(userID)")
            PhotoStorageManager.shared.migratePhotosToUser(userID: userID)
            
            // Update user stats in CloudKit
            if currentUser != nil {
                // TODO: Update user stats after migration
                // This would update the user's recipe count in CloudKit
                print("📊 Would update user stats with migrated recipes")
            }
        } else {
            print("ℹ️ No local data to migrate")
        }
    }
    
    private func linkTikTokAccount() async {
        // This would update the CloudKit user record with TikTok integration info
        // For now, just log the linking
        // Log TikTok account linking
        os_log("TikTok account linked to CloudKit user", log: .default, type: .info)
    }
    
    private func completeAuthentication() {
        showAuthSheet = false
        shouldShowProgressivePrompt = false
        
        // Call completion handler if set
        if let handler = authCompletionHandler {
            handler()
            authCompletionHandler = nil
        }
    }
    
    // MARK: - Functions Ported from CloudKitAuthManager
    
    /// Update user statistics in CloudKit
    func updateUserStats(_ updates: UserStatUpdates) async throws {
        guard let currentUser = currentUser else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        let userRecordID = CKRecord.ID(recordName: "user_\(currentUser.recordID)")
        let record = try await cloudKitDatabase.record(for: userRecordID)
        
        // Apply updates - only for fields that exist in production
        if let totalPoints = updates.totalPoints {
            record[CKField.User.totalPoints] = Int64(totalPoints)
        }
        if let currentStreak = updates.currentStreak {
            record[CKField.User.currentStreak] = Int64(currentStreak)
        }
        if let longestStreak = updates.longestStreak {
            record[CKField.User.longestStreak] = Int64(longestStreak)
        }
        if let challengesCompleted = updates.challengesCompleted {
            record[CKField.User.challengesCompleted] = Int64(challengesCompleted)
        }
        if let recipesShared = updates.recipesShared {
            record[CKField.User.recipesShared] = Int64(recipesShared)
        }
        if let recipesCreated = updates.recipesCreated {
            record[CKField.User.recipesCreated] = Int64(recipesCreated)
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
        
        // Update last active time
        record[CKField.User.lastActiveAt] = Date()
        
        _ = try await cloudKitDatabase.save(record)
        
        // Update local user object
        await MainActor.run {
            if var updatedUser = self.currentUser {
                // Update local properties based on what's in UserStatUpdates
                // Note: CloudKitUser might need to be extended to include these properties
                self.currentUser = updatedUser
            }
        }
    }
    
    /// Refresh current user data from CloudKit
    func refreshCurrentUser() async {
        guard let currentUser = currentUser else { return }
        
        do {
            let userRecordID = CKRecord.ID(recordName: "user_\(currentUser.recordID)")
            let record = try await cloudKitDatabase.record(for: userRecordID)
            
            await MainActor.run {
                self.currentUser = CloudKitUser(from: record)
            }
        } catch {
            print("❌ Failed to refresh current user: \(error)")
        }
    }
    
    /// Update recipe counts for the current user
    func updateRecipeCounts() async {
        guard let currentUser = currentUser,
              let userID = currentUser.recordID else { return }
        
        do {
            // Count recipes created by this user
            let recipePredicate = NSPredicate(format: "%K == %@", CKField.Recipe.ownerID, userID)
            let recipeQuery = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: recipePredicate)
            
            let recipeResults = try await cloudKitDatabase.records(matching: recipeQuery)
            let recipeCount = recipeResults.matchResults.count
            
            // Update the user's recipe count
            try await updateUserStats(UserStatUpdates(recipesCreated: recipeCount, experiencePoints: nil))
        } catch {
            print("Error updating recipe counts: \(error)")
        }
    }
    
    /// Update social counts (followers/following)
    func updateSocialCounts() async {
        guard let currentUser = currentUser,
              let recordID = currentUser.recordID,
              !recordID.isEmpty else { 
            print("⚠️ updateSocialCounts: No valid user record ID")
            return 
        }
        
        do {
            // Count followers
            let followerPredicate = NSPredicate(format: "followingID == %@", recordID)
            let followerQuery = CKQuery(recordType: "Follow", predicate: followerPredicate)
            
            let (followerResults, _) = try await cloudKitDatabase.records(
                matching: followerQuery,
                desiredKeys: nil,
                resultsLimit: 1000
            )
            
            let followerCount = followerResults.count
            
            // Count following
            let followingPredicate = NSPredicate(format: "followerID == %@", currentUser.recordID ?? "")
            let followingQuery = CKQuery(recordType: "Follow", predicate: followingPredicate)
            
            let (followingResults, _) = try await cloudKitDatabase.records(
                matching: followingQuery,
                desiredKeys: nil,
                resultsLimit: 1000
            )
            
            let followingCount = followingResults.count
            
            // Update user record
            let updates = UserStatUpdates(
                followerCount: followerCount,
                followingCount: followingCount
            )
            
            try await updateUserStats(updates)
            
        } catch {
            print("❌ Failed to update social counts: \(error)")
        }
    }
    
    /// Get list of users followed by a specific user
    func getUsersFollowedBy(userID: String) async -> [CloudKitUser] {
        do {
            let predicate = NSPredicate(format: "followerID == %@", userID)
            let query = CKQuery(recordType: "Follow", predicate: predicate)
            
            let (results, _) = try await cloudKitDatabase.records(
                matching: query,
                desiredKeys: ["followingID"],
                resultsLimit: 100
            )
            
            var users: [CloudKitUser] = []
            
            for (_, result) in results {
                if case .success(let record) = result,
                   let followingID = record["followingID"] as? String {
                    // Fetch the user record
                    do {
                        let userRecordID = CKRecord.ID(recordName: "user_\(followingID)")
                        let userRecord = try await cloudKitDatabase.record(for: userRecordID)
                        users.append(CloudKitUser(from: userRecord))
                    } catch {
                        print("Failed to fetch user \(followingID): \(error)")
                    }
                }
            }
            
            return users
            
        } catch {
            print("❌ Failed to get users followed by \(userID): \(error)")
            return []
        }
    }
}

// MARK: - Error Types

enum UnifiedAuthError: LocalizedError {
    case invalidCredential
    case notAuthenticated
    case usernameUnavailable
    case tikTokAuthFailed(String)
    case networkError
    case cloudKitNotAvailable
    case cloudKitError(Error)
    case authenticationFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid authentication credentials"
        case .notAuthenticated:
            return "Please sign in to iCloud to sync your data"
        case .usernameUnavailable:
            return "This username is already taken"
        case .tikTokAuthFailed(let details):
            return "TikTok sign in failed: \(details)"
        case .networkError:
            return "Network error. Please try again."
        case .cloudKitNotAvailable:
            return "Please sign in to iCloud in Settings to use this feature"
        case .cloudKitError(let underlyingError):
            return "CloudKit error: \(underlyingError.localizedDescription)"
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - Supporting Types

enum AuthRequiredFeature {
    case basicRecipes
    case challenges
    case leaderboard
    case socialSharing
    case teams
    case streaks
    case premiumFeatures
    
    var title: String {
        switch self {
        case .basicRecipes: return "Basic Recipes"
        case .challenges: return "Challenges"
        case .leaderboard: return "Leaderboard"
        case .socialSharing: return "Social Sharing"
        case .teams: return "Teams"
        case .streaks: return "Streaks"
        case .premiumFeatures: return "Premium Features"
        }
    }
}

enum AnonymousAction: String, CaseIterable, Sendable {
    case recipeCreated = "recipe_created"
    case recipeViewed = "recipe_viewed"
    case videoGenerated = "video_generated"
    case videoShared = "video_shared"
    case appOpened = "app_opened"
    case challengeViewed = "challenge_viewed"
    case socialExplored = "social_explored"
}

// MARK: - CloudKitUser

public struct CloudKitUser: Identifiable {
    public let id = UUID()
    public let recordID: String?
    public var username: String?
    public var displayName: String
    public var email: String
    public var profileImageURL: String?
    public var authProvider: String
    public var totalPoints: Int
    public var currentStreak: Int
    public var longestStreak: Int
    public var challengesCompleted: Int
    public var recipesShared: Int
    public var recipesCreated: Int
    public var coinBalance: Int
    public var followerCount: Int
    public var followingCount: Int
    public var isVerified: Bool
    public var isProfilePublic: Bool
    public var showOnLeaderboard: Bool
    public var subscriptionTier: String
    public var createdAt: Date
    public var lastLoginAt: Date
    public var lastActiveAt: Date
    public var bio: String
    
    // Additional properties for compatibility
    public var profilePictureData: Data?
    public var totalLikes: Int
    public var totalShares: Int
    public var streakCount: Int
    public var joinDate: Date
    public var lastActiveDate: Date
    public var favoriteRecipes: [String] // Recipe IDs
    public var level: Int
    public var experiencePoints: Int
    
    public init(from record: CKRecord) {
        // Remove "user_" prefix if present to get the actual CloudKit user ID
        let fullRecordID = record.recordID.recordName
        if fullRecordID.hasPrefix("user_") {
            self.recordID = String(fullRecordID.dropFirst(5))  // Remove "user_" prefix
        } else {
            self.recordID = fullRecordID
        }
        self.username = record[CKField.User.username] as? String
        self.displayName = record[CKField.User.displayName] as? String ?? "Anonymous Chef"
        self.email = record[CKField.User.email] as? String ?? ""
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
        self.isVerified = (record[CKField.User.isVerified] as? Int64 ?? 0) == 1
        self.isProfilePublic = (record[CKField.User.isProfilePublic] as? Int64 ?? 1) == 1
        self.showOnLeaderboard = (record[CKField.User.showOnLeaderboard] as? Int64 ?? 1) == 1
        self.subscriptionTier = record[CKField.User.subscriptionTier] as? String ?? "free"
        self.createdAt = record[CKField.User.createdAt] as? Date ?? Date()
        self.lastLoginAt = record[CKField.User.lastLoginAt] as? Date ?? Date()
        self.lastActiveAt = record[CKField.User.lastActiveAt] as? Date ?? Date()
        self.bio = record["bio"] as? String ?? ""
        
        // Additional properties initialization
        self.profilePictureData = nil // Will be loaded separately if needed
        self.totalLikes = 0 // Not stored in CloudKit currently
        self.totalShares = 0 // Not stored in CloudKit currently
        self.streakCount = self.currentStreak // Use currentStreak
        self.joinDate = self.createdAt
        self.lastActiveDate = self.lastActiveAt
        self.favoriteRecipes = [] // Will be loaded separately if needed
        self.level = 1 // Calculate from experience or default
        self.experiencePoints = self.totalPoints // Use totalPoints as experience
    }
    
    public init(recordID: String?,
         userID: String,
         username: String?,
         displayName: String,
         email: String,
         profileImageURL: String?,
         authProvider: String,
         totalPoints: Int,
         currentStreak: Int,
         longestStreak: Int,
         challengesCompleted: Int,
         recipesShared: Int,
         recipesCreated: Int,
         coinBalance: Int,
         isProfilePublic: Bool,
         showOnLeaderboard: Bool,
         subscriptionTier: String,
         createdAt: Date,
         lastLoginAt: Date,
         lastActiveAt: Date,
         followerCount: Int,
         followingCount: Int,
         isVerified: Bool,
         bio: String) {
        self.recordID = recordID
        self.username = username
        self.displayName = displayName
        self.email = email
        self.profileImageURL = profileImageURL
        self.authProvider = authProvider
        self.totalPoints = totalPoints
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.challengesCompleted = challengesCompleted
        self.recipesShared = recipesShared
        self.recipesCreated = recipesCreated
        self.coinBalance = coinBalance
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.isVerified = isVerified
        self.isProfilePublic = isProfilePublic
        self.showOnLeaderboard = showOnLeaderboard
        self.subscriptionTier = subscriptionTier
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.lastActiveAt = lastActiveAt
        self.bio = bio
        
        // Additional properties initialization
        self.profilePictureData = nil
        self.totalLikes = 0
        self.totalShares = 0
        self.streakCount = currentStreak
        self.joinDate = createdAt
        self.lastActiveDate = lastActiveAt
        self.favoriteRecipes = []
        self.level = 1
        self.experiencePoints = totalPoints
    }
}

// MARK: - UserStatUpdates

public struct UserStatUpdates {
    public var totalPoints: Int?
    public var currentStreak: Int?
    public var longestStreak: Int?
    public var challengesCompleted: Int?
    public var recipesShared: Int?
    public var recipesCreated: Int?
    public var coinBalance: Int?
    public var followerCount: Int?
    public var followingCount: Int?
    public var experiencePoints: Int?  // Added for CloudKitSyncService compatibility
    
    public init(totalPoints: Int? = nil,
         currentStreak: Int? = nil,
         longestStreak: Int? = nil,
         challengesCompleted: Int? = nil,
         recipesShared: Int? = nil,
         recipesCreated: Int? = nil,
         coinBalance: Int? = nil,
         followerCount: Int? = nil,
         followingCount: Int? = nil,
         experiencePoints: Int? = nil) {
        self.totalPoints = totalPoints
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.challengesCompleted = challengesCompleted
        self.recipesShared = recipesShared
        self.recipesCreated = recipesCreated
        self.coinBalance = coinBalance
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.experiencePoints = experiencePoints
    }
}
