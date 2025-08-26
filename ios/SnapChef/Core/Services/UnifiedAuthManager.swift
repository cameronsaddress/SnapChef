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
    
    // Serial queue to prevent concurrent updates
    private var isUpdatingSocialData = false
    private var isSavingUserRecord = false
    private let updateQueue = DispatchQueue(label: "com.snapchef.socialupdate", qos: .userInitiated)
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
            
            // Generate username - this is the ONLY name we use
            let generatedUsername = generateUsername(from: email, fullName: fullName)
            
            newRecord[CKField.User.username] = generatedUsername
            newRecord[CKField.User.displayName] = generatedUsername  // Same as username
            
            print("📝 Generated username: \(generatedUsername)")
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
            print("❌ setUsername failed: No current user or recordID")
            throw UnifiedAuthError.notAuthenticated
        }
        
        // Check availability - but allow setting our own current username
        if username.lowercased() != currentUser.username?.lowercased() {
            let isAvailable = try await checkUsernameAvailability(username)
            guard isAvailable else {
                print("❌ Username '\(username)' is not available")
                throw UnifiedAuthError.usernameUnavailable
            }
        }
        
        do {
            // Try BOTH possible record IDs - with and without prefix
            let recordIDsToTry = [
                "user_\(recordID)",  // Standard format
                recordID             // Just the raw ID
            ]
            
            var recordFound: CKRecord? = nil
            var usedRecordID: String? = nil
            
            for tryID in recordIDsToTry {
                do {
                    print("🔍 DEBUG: Trying to fetch record with ID: \(tryID)")
                    let record = try await cloudKitDatabase.record(for: CKRecord.ID(recordName: tryID))
                    recordFound = record
                    usedRecordID = tryID
                    print("✅ Found record with ID: \(tryID)")
                    break
                } catch {
                    print("   Record not found with ID: \(tryID)")
                    continue
                }
            }
            
            guard let record = recordFound, let finalRecordID = usedRecordID else {
                print("❌ Could not find user record with any ID format")
                throw UnifiedAuthError.userRecordNotFound
            }
            
            // Debug what's currently in CloudKit before update
            print("🔍 DEBUG setUsername - BEFORE update (record ID: \(finalRecordID)):")
            print("   username field: '\(record[CKField.User.username] as? String ?? "nil")'")
            print("   displayName field: '\(record[CKField.User.displayName] as? String ?? "nil")'")
            
            record[CKField.User.username] = username.lowercased()
            // ALWAYS update displayName to match username - we only use username!
            record[CKField.User.displayName] = username
            print("   Setting BOTH username and displayName to '\(username)'")
            
            let savedRecord = try await cloudKitDatabase.save(record)
            
            // Debug what was actually saved
            print("✅ Successfully saved username '\(username)' to CloudKit record")
            print("🔍 DEBUG setUsername - AFTER save:")
            print("   username field: '\(savedRecord[CKField.User.username] as? String ?? "nil")'")
            print("   displayName field: '\(savedRecord[CKField.User.displayName] as? String ?? "nil")'")
            
            // Update local state - both username and displayName
            self.currentUser?.username = username.lowercased()
            self.currentUser?.displayName = username  // Always keep them in sync
            self.showUsernameSetup = false
            
            completeAuthentication()
        } catch let error as CKError {
            print("❌ CloudKit error setting username: \(error)")
            print("   Error code: \(error.code)")
            print("   Error description: \(error.localizedDescription)")
            
            if error.code == .unknownItem {
                print("❌ User record doesn't exist. May need to create it first.")
                throw UnifiedAuthError.userRecordNotFound
            }
            throw error
        } catch {
            print("❌ Unexpected error setting username: \(error)")
            throw error
        }
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
    
    // MARK: - ID Normalization
    
    /// Normalizes user IDs by removing "user_" prefix if present
    /// This ensures consistent ID format throughout the app
    private func normalizeUserID(_ id: String) -> String {
        // Remove "user_" prefix to get raw CloudKit ID
        if id.hasPrefix("user_") {
            return String(id.dropFirst(5))
        }
        return id
    }
    
    // MARK: - Username Generation
    
    /// Generates a unique username from email or name
    private func generateUsername(from email: String?, fullName: PersonNameComponents?) -> String {
        // Try to use email prefix
        if let email = email, let username = email.split(separator: "@").first {
            let base = String(username).lowercased()
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: "-", with: "")
            if base.count >= 3 {
                return base
            }
        }
        
        // Try to use first name
        if let firstName = fullName?.givenName?.lowercased() {
            let cleanName = firstName
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
            if cleanName.count >= 3 {
                return cleanName + String(Int.random(in: 100...999))
            }
        }
        
        // Fallback to random username
        return "chef" + String(Int.random(in: 10000...99999))
    }
    
    /// Fix CloudKit user record that has missing username
    func fixUserUsername(userID: String, username: String) async throws {
        print("🔧 Fixing username for user \(userID) to '\(username)'")
        
        // Try both record ID formats
        let recordIDsToTry = [
            userID,                    // Raw ID like "_d4b8018a9065711f8e9731b7c8c6d31f"
            "user_\(userID)"          // With prefix
        ]
        
        var recordFound: CKRecord? = nil
        
        for tryID in recordIDsToTry {
            do {
                let record = try await cloudKitDatabase.record(for: CKRecord.ID(recordName: tryID))
                recordFound = record
                print("✅ Found record with ID: \(tryID)")
                break
            } catch {
                continue
            }
        }
        
        guard let record = recordFound else {
            print("❌ Could not find user record for ID: \(userID)")
            throw UnifiedAuthError.userRecordNotFound
        }
        
        // Update the username field
        record[CKField.User.username] = username.lowercased()
        record[CKField.User.displayName] = username
        
        let savedRecord = try await cloudKitDatabase.save(record)
        print("✅ Fixed username for user \(userID): username='\(savedRecord[CKField.User.username] as? String ?? "nil")'")
    }
    
    // MARK: - Profile Photo Management
    
    /// Update profile photo in CloudKit
    func updateProfilePhoto(_ asset: CKAsset, for userID: String) async {
        do {
            let database = cloudKitDatabase
            
            // Fetch user record
            let recordID = CKRecord.ID(recordName: "user_\(userID)")
            let record = try await database.record(for: recordID)
            
            // Update profile photo asset
            record["profilePictureAsset"] = asset
            
            // Save record
            _ = try await database.save(record)
            
            print("✅ UnifiedAuthManager: Updated profile photo in CloudKit for user \(userID)")
            
            // Refresh current user if this is the current user
            if userID == currentUser?.recordID {
                await refreshCurrentUser()
            }
        } catch {
            print("⚠️ UnifiedAuthManager: Failed to update profile photo in CloudKit: \(error)")
        }
    }
    
    /// Fetch profile photo from CloudKit
    func fetchProfilePhoto(for userID: String) async -> UIImage? {
        do {
            let database = cloudKitDatabase
            
            // Fetch user record
            let recordID = CKRecord.ID(recordName: "user_\(userID)")
            let record = try await database.record(for: recordID)
            
            // Get profile photo asset
            guard let asset = record["profilePictureAsset"] as? CKAsset,
                  let fileURL = asset.fileURL,
                  let imageData = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: imageData) else {
                return nil
            }
            
            print("✅ UnifiedAuthManager: Fetched profile photo from CloudKit for user \(userID)")
            return image
        } catch {
            print("⚠️ UnifiedAuthManager: Failed to fetch profile photo from CloudKit: \(error)")
            return nil
        }
    }
    
    /// Delete profile photo from CloudKit
    func deleteProfilePhoto(for userID: String) async {
        do {
            let database = cloudKitDatabase
            
            // Fetch user record
            let recordID = CKRecord.ID(recordName: "user_\(userID)")
            let record = try await database.record(for: recordID)
            
            // Remove profile photo asset
            record["profilePictureAsset"] = nil
            
            // Save record
            _ = try await database.save(record)
            
            print("✅ UnifiedAuthManager: Deleted profile photo from CloudKit for user \(userID)")
            
            // Refresh current user if this is the current user
            if userID == currentUser?.recordID {
                await refreshCurrentUser()
            }
        } catch {
            print("⚠️ UnifiedAuthManager: Failed to delete profile photo from CloudKit: \(error)")
        }
    }
    
    // MARK: - Social Features
    
    /// Check if the current user is following another user
    func isFollowing(userID: String) async -> Bool {
        guard let currentUser = currentUser,
              let currentUserID = currentUser.recordID else {
            return false
        }
        
        // Use normalized IDs for CloudKit queries
        let normalizedFollowerID = normalizeUserID(currentUserID)
        let normalizedFollowingID = normalizeUserID(userID)
        
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %@ AND %K == %d",
            CKField.Follow.followerID, normalizedFollowerID,
            CKField.Follow.followingID, normalizedFollowingID,
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
            print("⚠️ Already following user: \(userID)")
            return // Already following
        }
        
        // Create follow record with normalized IDs (without "user_" prefix)
        let followRecord = CKRecord(recordType: CloudKitConfig.followRecordType)
        // Normalize IDs to ensure consistency
        let normalizedFollowerID = normalizeUserID(currentUserID)
        let normalizedFollowingID = normalizeUserID(userID)
        
        followRecord[CKField.Follow.followerID] = normalizedFollowerID
        followRecord[CKField.Follow.followingID] = normalizedFollowingID
        followRecord[CKField.Follow.followedAt] = Date()
        followRecord[CKField.Follow.isActive] = Int64(1)
        
        _ = try await cloudKitDatabase.save(followRecord)
        
        print("✅ User followed: \(userID)")
        
        // Update local follower count immediately
        self.currentUser?.followingCount += 1
        
        // Update CloudKit User record with new following count
        let newFollowingCount = self.currentUser?.followingCount ?? 1
        try await updateUserStats(UserStatUpdates(followingCount: newFollowingCount))
        
        // Also update the followed user's follower count
        await updateFollowedUserFollowerCount(userID: userID, increment: true)
    }
    
    /// Unfollow a user
    func unfollowUser(userID: String) async throws {
        guard let currentUser = currentUser,
              let currentUserID = currentUser.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        // Use normalized IDs for CloudKit queries
        let normalizedFollowerID = normalizeUserID(currentUserID)
        let normalizedFollowingID = normalizeUserID(userID)
        
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %@ AND %K == %d",
            CKField.Follow.followerID, normalizedFollowerID,
            CKField.Follow.followingID, normalizedFollowingID,
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
            
            // Update local follower count immediately
            self.currentUser?.followingCount = max(0, (self.currentUser?.followingCount ?? 0) - 1)
            
            // Update CloudKit User record with new following count
            let newFollowingCount = self.currentUser?.followingCount ?? 0
            try await updateUserStats(UserStatUpdates(followingCount: newFollowingCount))
            
            // Also update the unfollowed user's follower count
            await updateFollowedUserFollowerCount(userID: userID, increment: false)
        } catch {
            throw UnifiedAuthError.networkError
        }
    }
    
    /// Helper method to update the followed/unfollowed user's follower count
    private func updateFollowedUserFollowerCount(userID: String, increment: Bool) async {
        do {
            // Normalize the user ID and add "user_" prefix for CloudKit record
            let normalizedID = normalizeUserID(userID)
            let userRecordID = CKRecord.ID(recordName: "user_\(normalizedID)")
            let userRecord = try await cloudKitDatabase.record(for: userRecordID)
            
            // Get current follower count
            let currentCount = Int(userRecord[CKField.User.followerCount] as? Int64 ?? 0)
            
            // Update the count
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            userRecord[CKField.User.followerCount] = Int64(newCount)
            
            // Save the updated record
            _ = try await cloudKitDatabase.save(userRecord)
            
            print("✅ Updated user \(userID) follower count to \(newCount)")
        } catch {
            print("❌ Failed to update followed user's follower count: \(error)")
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
        guard let currentUser = currentUser,
              let recordID = currentUser.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        // Prevent concurrent saves
        guard !isSavingUserRecord else {
            print("⚠️ User record save already in progress, skipping")
            return
        }
        
        isSavingUserRecord = true
        defer { isSavingUserRecord = false }
        
        print("🔍 DEBUG updateUserStats: Starting ")
        print("   Current queue: \(OperationQueue.current?.name ?? "unknown")")
        print("   Is main thread: \(Thread.isMainThread)")
        
        let userRecordID = CKRecord.ID(recordName: "user_\(recordID)")
        print("   Fetching record with ID: \(userRecordID.recordName)")
        
        let record = try await cloudKitDatabase.record(for: userRecordID)
        
        print("🔍 DEBUG updateUserStats: Fetched record from CloudKit ")
        print("   Record type: \(record.recordType)")
        print("   Record ID: \(record.recordID.recordName)")
        
        // Apply updates - only for fields that exist in production
        if let totalPoints = updates.totalPoints {
            record[CKField.User.totalPoints] = Int64(totalPoints)
        }
        if let currentStreak = updates.currentStreak {
            print("📝 Setting currentStreak field to: \(currentStreak)")
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
        
        print("💾 Saving updated user record to CloudKit... ")
        print("   Updates applied - Followers: \(updates.followerCount ?? -1), Following: \(updates.followingCount ?? -1)")
        print("   Record values - Followers: \(record[CKField.User.followerCount] as? Int64 ?? -1), Following: \(record[CKField.User.followingCount] as? Int64 ?? -1)")
        print("   Current queue before save: \(OperationQueue.current?.name ?? "unknown")")
        print("   Is main thread before save: \(Thread.isMainThread)")
        
        do {
            // Save the record - ensure we're not on a dispatch assertion queue
            print("   About to call cloudKitDatabase.save()...")
            
            // Wrap the save in a Task to ensure proper queue handling
            let savedRecord = try await Task.detached(priority: .userInitiated) {
                try await self.cloudKitDatabase.save(record)
            }.value
            
            print("   cloudKitDatabase.save() returned successfully")
            print("✅ User record saved successfully ")
            print("   Saved record ID: \(savedRecord.recordID.recordName)")
            print("   Saved follower count: \(savedRecord[CKField.User.followerCount] as? Int64 ?? -1)")
            print("   Saved following count: \(savedRecord[CKField.User.followingCount] as? Int64 ?? -1)")
            
            // Update local counts immediately to reflect the changes
            await MainActor.run {
                if let followerCount = updates.followerCount {
                    self.currentUser?.followerCount = followerCount
                }
                if let followingCount = updates.followingCount {
                    self.currentUser?.followingCount = followingCount
                }
                if let recipesCreated = updates.recipesCreated {
                    self.currentUser?.recipesCreated = recipesCreated
                }
            }
        } catch let error as CKError {
            print("❌ CloudKit error saving user record: \(error)")
            print("   Error code: \(error.code)")
            print("   Error description: \(error.localizedDescription)")
            print("   Current queue on error: \(OperationQueue.current?.name ?? "unknown")")
            print("   Is main thread on error: \(Thread.isMainThread)")
            
            // If it's a conflict error, retry with the server record
            if error.code == .serverRecordChanged {
                print("⚠️ Server record changed, retrying with latest version...")
                if let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                    // Apply updates to the server record
                    if let followerCount = updates.followerCount {
                        serverRecord[CKField.User.followerCount] = Int64(followerCount)
                    }
                    if let followingCount = updates.followingCount {
                        serverRecord[CKField.User.followingCount] = Int64(followingCount)
                    }
                    serverRecord[CKField.User.lastActiveAt] = Date()
                    
                    // Try saving again with the server record (also detached)
                    _ = try await Task.detached(priority: .userInitiated) {
                        try await self.cloudKitDatabase.save(serverRecord)
                    }.value
                    print("✅ Retry successful - user record saved")
                    return
                }
            }
            throw error
        } catch {
            print("❌ Unexpected error saving user record: \(error)")
            throw error
        }
        
        print("🔍 DEBUG updateUserStats: Completed ")
    }
    
    /// Refresh current user data from CloudKit
    func refreshCurrentUser() async {
        guard let currentUser = currentUser else { return }
        
        print("🔍 DEBUG refreshCurrentUser: Starting ")
        
        do {
            guard let recordID = currentUser.recordID else { return }
            let userRecordID = CKRecord.ID(recordName: "user_\(recordID)")
            let record = try await cloudKitDatabase.record(for: userRecordID)
            
            // Debug what's actually in CloudKit
            print("🔍 DEBUG refreshCurrentUser - CloudKit record contents :")
            print("   username field: '\(record[CKField.User.username] as? String ?? "nil")'")
            print("   displayName field: '\(record[CKField.User.displayName] as? String ?? "nil")'")
            print("   currentStreak field: '\(record[CKField.User.currentStreak] as? Int64 ?? -1)'")
            print("   longestStreak field: '\(record[CKField.User.longestStreak] as? Int64 ?? -1)'")
            print("   totalPoints field: '\(record[CKField.User.totalPoints] as? Int64 ?? -1)'")
            print("   recipesCreated field: '\(record[CKField.User.recipesCreated] as? Int64 ?? -1)'")
            print("   followerCount field: '\(record[CKField.User.followerCount] as? Int64 ?? -1)'")
            print("   followingCount field: '\(record[CKField.User.followingCount] as? Int64 ?? -1)'")
            
            let newUser = CloudKitUser(from: record)
            print("🔍 DEBUG refreshCurrentUser: About to update currentUser on MainActor ")
            
            await MainActor.run {
                print("🔍 DEBUG refreshCurrentUser: Updating currentUser on MainActor ")
                self.currentUser = newUser
                print("🔍 DEBUG refreshCurrentUser: currentUser updated successfully ")
            }
            
            print("🔍 DEBUG refreshCurrentUser: Completed successfully ")
        } catch {
            print("❌ Failed to refresh current user: \(error) ")
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
    
    /// Refresh current user data from CloudKit
    func refreshCurrentUserData() async throws {
        guard let currentUser = currentUser,
              let recordID = currentUser.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        do {
            // Fetch the latest user record from CloudKit
            let userRecordID = CKRecord.ID(recordName: "user_\(recordID)")
            let userRecord = try await cloudKitDatabase.record(for: userRecordID)
            
            // Update the current user with fresh data on MainActor
            let refreshedUser = CloudKitUser(from: userRecord)
            await MainActor.run {
                self.currentUser = refreshedUser
            }
            
            print("✅ Refreshed current user data - Followers: \(refreshedUser.followerCount), Following: \(refreshedUser.followingCount)")
        } catch {
            print("❌ Failed to refresh user data: \(error)")
            throw error
        }
    }
    
    /// Synchronized method to refresh all social data without race conditions
    func refreshAllSocialData() async {
        // Prevent concurrent updates
        guard !isUpdatingSocialData else {
            print("⚠️ Social data update already in progress, skipping")
            return
        }
        
        isUpdatingSocialData = true
        defer { isUpdatingSocialData = false }
        
        print("🔍 DEBUG refreshAllSocialData: Starting synchronized update ")
        
        do {
            // First refresh the user record to get latest data
            try await refreshCurrentUserData()
            
            // Then update counts (without calling refresh again)
            await updateSocialCountsWithoutRefresh()
            
            // Finally update recipe counts
            await updateRecipeCounts()
            
            print("✅ DEBUG refreshAllSocialData: Completed successfully")
        } catch {
            print("❌ Failed to refresh social data: \(error)")
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
        
        print("🔍 DEBUG updateSocialCounts: Starting for user recordID: \(recordID) ")
        
        do {
            // Count followers - people who follow this user
            // followingID is the user being followed
            // Use normalized ID for consistency
            let normalizedID = normalizeUserID(recordID)
            print("🔍 DEBUG updateSocialCounts: Using normalized ID: \(normalizedID)")
            
            // Query for followers with normalized ID
            let followerPredicate = NSPredicate(format: "followingID == %@ AND isActive == 1", normalizedID)
            let followerQuery = CKQuery(recordType: "Follow", predicate: followerPredicate)
            
            let followerResults = try await cloudKitDatabase.records(matching: followerQuery)
            print("🔍 DEBUG updateSocialCounts: Follower query returned \(followerResults.matchResults.count) results")
            
            let activeFollowers = followerResults.matchResults.compactMap { (_, result) -> String? in
                if case .success(let record) = result {
                    let isActive = record["isActive"] as? Int64
                    let followerID = record["followerID"] as? String
                    print("🔍 DEBUG updateSocialCounts: Follow record - followerID: \(followerID ?? "nil"), isActive: \(isActive ?? -1)")
                    if isActive == 1 {
                        return followerID
                    }
                }
                return nil
            }
            let followerCount = activeFollowers.count
            print("🔍 DEBUG updateSocialCounts: Final follower count: \(followerCount)")
            
            // Count following - people this user follows
            // followerID is the user doing the following
            // Use normalized ID for consistency
            let followingPredicate = NSPredicate(format: "followerID == %@ AND isActive == 1", normalizedID)
            let followingQuery = CKQuery(recordType: "Follow", predicate: followingPredicate)
            
            let followingResults = try await cloudKitDatabase.records(matching: followingQuery)
            print("🔍 DEBUG updateSocialCounts: Following query returned \(followingResults.matchResults.count) results")
            
            let activeFollowing = followingResults.matchResults.compactMap { (_, result) -> String? in
                if case .success(let record) = result {
                    let isActive = record["isActive"] as? Int64
                    let followingID = record["followingID"] as? String
                    print("🔍 DEBUG updateSocialCounts: Follow record - followingID: \(followingID ?? "nil"), isActive: \(isActive ?? -1)")
                    if isActive == 1 {
                        return followingID
                    }
                }
                return nil
            }
            let followingCount = activeFollowing.count
            print("🔍 DEBUG updateSocialCounts: Final following count: \(followingCount)")
            
            print("📊 Updated social counts - Followers: \(followerCount), Following: \(followingCount) ")
            
            // Update user record with the counts
            let updates = UserStatUpdates(
                followerCount: followerCount,
                followingCount: followingCount
            )
            
            print("🔍 DEBUG: About to call updateUserStats ")
            try await updateUserStats(updates)
            print("🔍 DEBUG: updateUserStats completed successfully ")
            
            // Refresh the entire user object from CloudKit to get all updates
            print("🔍 DEBUG: About to call refreshCurrentUser ")
            await refreshCurrentUser()
            print("🔍 DEBUG: refreshCurrentUser completed successfully ")
            
        } catch {
            print("❌ Failed to update social counts: \(error)")
        }
    }
    
    /// Internal method to update social counts without refreshing user (prevents circular calls)
    private func updateSocialCountsWithoutRefresh() async {
        guard let currentUser = currentUser,
              let recordID = currentUser.recordID,
              !recordID.isEmpty else { 
            print("⚠️ updateSocialCountsWithoutRefresh: No valid user record ID")
            return 
        }
        
        print("🔍 DEBUG updateSocialCountsWithoutRefresh: Starting ")
        
        do {
            // Use normalized ID for consistency
            let normalizedID = normalizeUserID(recordID)
            
            // Query for followers
            let followerPredicate = NSPredicate(format: "followingID == %@ AND isActive == 1", normalizedID)
            let followerQuery = CKQuery(recordType: "Follow", predicate: followerPredicate)
            let followerResults = try await cloudKitDatabase.records(matching: followerQuery)
            
            let followerCount = followerResults.matchResults.compactMap { (_, result) -> String? in
                if case .success(let record) = result, record["isActive"] as? Int64 == 1 {
                    return record["followerID"] as? String
                }
                return nil
            }.count
            
            // Query for following
            let followingPredicate = NSPredicate(format: "followerID == %@ AND isActive == 1", normalizedID)
            let followingQuery = CKQuery(recordType: "Follow", predicate: followingPredicate)
            let followingResults = try await cloudKitDatabase.records(matching: followingQuery)
            
            let followingCount = followingResults.matchResults.compactMap { (_, result) -> String? in
                if case .success(let record) = result, record["isActive"] as? Int64 == 1 {
                    return record["followingID"] as? String
                }
                return nil
            }.count
            
            print("📊 updateSocialCountsWithoutRefresh: Followers: \(followerCount), Following: \(followingCount)")
            
            // Update user record with counts (without refreshing)
            let updates = UserStatUpdates(
                followerCount: followerCount,
                followingCount: followingCount
            )
            
            do {
                try await updateUserStats(updates)
            } catch {
                // Log error but don't throw - this is a background update
                print("⚠️ Failed to update user stats in CloudKit: \(error)")
                print("   Will use cached counts for now")
                
                // Still update local state even if CloudKit save fails
                await MainActor.run {
                    self.currentUser?.followerCount = followerCount
                    self.currentUser?.followingCount = followingCount
                }
            }
            
            // Don't call refreshCurrentUser here - it's already called in refreshAllSocialData
        } catch {
            print("❌ Failed to query social counts: \(error)")
            // Don't crash the app - just use cached counts
        }
    }
    
    /// Get list of users followed by a specific user
    func getUsersFollowedBy(userID: String) async -> [CloudKitUser] {
        do {
            // Ensure userID has "user_" prefix for CloudKit query
            let fullUserID = userID.hasPrefix("user_") ? userID : "user_\(userID)"
            let predicate = NSPredicate(format: "followerID == %@", fullUserID)
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
                        // followingID already has "user_" prefix from Follow record, use it directly
                        let userRecordID = CKRecord.ID(recordName: followingID)
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
    case userRecordNotFound
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
        case .userRecordNotFound:
            return "User profile not found. Please try signing in again."
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
        
        // CRITICAL FIX: Extract username and displayName properly
        let rawUsername = record[CKField.User.username] as? String
        let rawDisplayName = record[CKField.User.displayName] as? String
        
        print("🔍 DEBUG CloudKitUser init: Processing user record \(fullRecordID)")
        print("    └─ Raw username field: '\(rawUsername ?? "nil")'")
        print("    └─ Raw displayName field: '\(rawDisplayName ?? "nil")'")
        
        // ONLY use username field - ignore displayName completely
        if let username = rawUsername, !username.isEmpty {
            // This is the user's actual chosen username - use it!
            self.username = username.lowercased()
            self.displayName = username  // Display name always matches username
            print("    └─ ✅ Using CloudKit username field: '\(username)'")
        } else {
            // No username in CloudKit - this is a problem that needs fixing
            // Generate a temporary one but log it as an error
            let idSuffix = String(recordID?.suffix(4) ?? "0000")
            self.username = "user\(idSuffix)".lowercased()
            self.displayName = "User\(idSuffix)"
            print("    └─ ❌ ERROR: No username in CloudKit! Generated fallback: '\(self.username ?? "nil")'")
            print("    └─ This user needs to set their username in ProfileView")
        }
        
        print("    └─ Final username: '\(self.username ?? "nil")'")
        print("    └─ Final displayName: '\(self.displayName)'")
        self.email = record[CKField.User.email] as? String ?? ""
        self.profileImageURL = record[CKField.User.profileImageURL] as? String
        self.authProvider = record[CKField.User.authProvider] as? String ?? "unknown"
        self.totalPoints = Int(record[CKField.User.totalPoints] as? Int64 ?? 0)
        let streakValue = record[CKField.User.currentStreak] as? Int64 ?? 0
        print("    └─ currentStreak from CloudKit: '\(streakValue)'")
        self.currentStreak = Int(streakValue)
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
