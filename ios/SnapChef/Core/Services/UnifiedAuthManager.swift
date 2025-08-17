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
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Progressive Auth State
    @Published var anonymousProfile: AnonymousUserProfile?
    @Published var shouldShowProgressivePrompt = false
    
    // MARK: - Dependencies
    
    private let cloudKitContainer = CKContainer(identifier: CloudKitConfig.containerIdentifier)
    private let cloudKitDatabase = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase
    private let profileManager = KeychainProfileManager.shared
    private let tikTokAuthManager = TikTokAuthManager.shared
    
    // MARK: - Auth completion callback
    var authCompletionHandler: (() -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        // Load anonymous profile
        self.anonymousProfile = profileManager.getOrCreateProfile()
        
        // Check existing auth status
        checkAuthStatus()
    }
    
    // MARK: - Auth Status Management
    
    func checkAuthStatus() {
        // Check CloudKit auth
        if let storedUserID = UserDefaults.standard.string(forKey: "currentUserRecordID") {
            Task {
                await loadCloudKitUser(recordID: storedUserID)
            }
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
        defer { isLoading = false }
        
        let userID = appleIDCredential.user
        let email = appleIDCredential.email
        let fullName = appleIDCredential.fullName
        
        let recordID = CKRecord.ID(recordName: userID)
        
        do {
            // Try to fetch existing user
            let existingRecord = try await cloudKitDatabase.record(for: recordID)
            
            // Update last login
            existingRecord[CKField.User.lastLoginAt] = Date()
            try await cloudKitDatabase.save(existingRecord)
            
            // Update state
            self.currentUser = CloudKitUser(from: existingRecord)
            self.isAuthenticated = true
            
            // Store user ID
            UserDefaults.standard.set(userID, forKey: "currentUserRecordID")
            
            // Migrate anonymous data if available
            await migrateAnonymousData()
            
            // Check username requirement
            if self.currentUser?.username == nil || self.currentUser?.username?.isEmpty == true {
                self.showUsernameSetup = true
            } else {
                completeAuthentication()
            }
            
        } catch {
            // Create new user
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
            
            // Copy anonymous profile data if available
            if let anonymous = anonymousProfile {
                newRecord[CKField.User.recipesCreated] = Int64(anonymous.recipesCreatedCount)
                newRecord[CKField.User.totalPoints] = Int64(anonymous.engagementScore * 100) // Convert engagement to points
            }
            
            try await cloudKitDatabase.save(newRecord)
            
            // Update state
            self.currentUser = CloudKitUser(from: newRecord)
            self.isAuthenticated = true
            
            // Store user ID
            UserDefaults.standard.set(userID, forKey: "currentUserRecordID")
            
            // Migrate anonymous data
            await migrateAnonymousData()
            
            // Show username setup for new users
            self.showUsernameSetup = true
        }
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
    
    private func checkUsernameAvailability(_ username: String) async throws -> Bool {
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
        if profileManager.saveProfile(profile) {
            self.anonymousProfile = profile
        }
        
        // Check if we should show progressive auth prompt
        checkProgressiveAuthConditions(for: action, profile: profile)
    }
    
    private func checkProgressiveAuthConditions(for action: AnonymousAction, profile: AnonymousUserProfile) {
        // Only show if not already authenticated and user hasn't opted out
        guard !isAuthenticated && profile.authenticationState == .anonymous else { return }
        
        let shouldShow = switch action {
        case .recipeCreated:
            profile.recipesCreatedCount == 1 // First recipe success
        case .videoGenerated:
            profile.videosGeneratedCount >= 1 && profile.socialFeaturesExplored >= 1 // Viral content
        case .socialExplored:
            profile.socialFeaturesExplored >= 2 // Social interest
        case .challengeViewed:
            profile.challengesViewed >= 3 // Challenge interest
        default:
            false
        }
        
        if shouldShow && !profile.hasRecentDismissals(within: 3) {
            self.shouldShowProgressivePrompt = true
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
        
        // Reset anonymous profile
        anonymousProfile = profileManager.getOrCreateProfile()
    }
    
    // MARK: - Private Helpers
    
    private func loadCloudKitUser(recordID: String) async {
        do {
            let record = try await cloudKitDatabase.record(for: CKRecord.ID(recordName: recordID))
            self.currentUser = CloudKitUser(from: record)
            self.isAuthenticated = true
            
            // Update last active
            record[CKField.User.lastActiveAt] = Date()
            try await cloudKitDatabase.save(record)
        } catch {
            // User not found or error
            UserDefaults.standard.removeObject(forKey: "currentUserRecordID")
            self.isAuthenticated = false
        }
    }
    
    private func migrateAnonymousData() async {
        guard var profile = anonymousProfile else { return }
        
        // Update authentication state
        profile.authenticationState = .authenticated
        profile.addAuthPromptEvent(context: "migration", action: "completed")
        
        // Save updated profile (or delete if no longer needed)
        _ = profileManager.saveProfile(profile)
        
        // Note: In production, you might want to upload anonymous usage data to CloudKit here
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
}

// MARK: - Error Types

enum UnifiedAuthError: LocalizedError {
    case invalidCredential
    case notAuthenticated
    case usernameUnavailable
    case tikTokAuthFailed(String)
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid authentication credentials"
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .usernameUnavailable:
            return "This username is already taken"
        case .tikTokAuthFailed(let details):
            return "TikTok sign in failed: \(details)"
        case .networkError:
            return "Network error. Please try again."
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
