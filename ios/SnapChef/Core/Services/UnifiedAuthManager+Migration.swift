//
//  UnifiedAuthManager+Migration.swift
//  SnapChef
//
//  Migration helpers for consolidating existing authentication systems
//

import Foundation

extension UnifiedAuthManager {
    // MARK: - Migration from Legacy Auth Systems
    
    /// Migrates from legacy CloudKitAuthManager if needed
    func migrateLegacyAuth() {
        // Check if we have a legacy CloudKit auth session
        if let legacyUserID = UserDefaults.standard.string(forKey: "currentUserID"),
           !legacyUserID.isEmpty {
            
            // Migrate to new key format
            UserDefaults.standard.set(legacyUserID, forKey: "currentUserRecordID")
            UserDefaults.standard.removeObject(forKey: "currentUserID")
            
            // Trigger auth status check with migrated data
            checkAuthStatus()
        }
    }
    
    /// Consolidates progressive auth data from multiple sources
    func consolidateProgressiveData() {
        // Get current anonymous profile
        guard var profile = anonymousProfile else { return }
        
        // Migrate any AppState data that might exist
        if let appStateRecipes = UserDefaults.standard.object(forKey: "anonymousRecipeCount") as? Int {
            profile.recipesCreatedCount = max(profile.recipesCreatedCount, appStateRecipes)
            UserDefaults.standard.removeObject(forKey: "anonymousRecipeCount")
        }
        
        if let appStateVideos = UserDefaults.standard.object(forKey: "anonymousVideoCount") as? Int {
            profile.videosGeneratedCount = max(profile.videosGeneratedCount, appStateVideos)
            UserDefaults.standard.removeObject(forKey: "anonymousVideoCount")
        }
        
        // Save consolidated profile
        Task {
            _ = profileManager.saveProfile(profile)
            await MainActor.run {
                self.anonymousProfile = profile
            }
        }
    }
    
    /// Clean up legacy auth artifacts
    func cleanupLegacyAuth() {
        // Remove old auth manager states that are no longer needed
        UserDefaults.standard.removeObject(forKey: "legacyAuthManager.isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "legacyAuthManager.currentUser")
        
        // Clean up temporary auth data
        UserDefaults.standard.removeObject(forKey: "temporaryUsername")
        
        print("✅ Legacy authentication artifacts cleaned up")
    }
}

// MARK: - Convenience Accessors for Easy Migration

extension UnifiedAuthManager {
    /// Drop-in replacement for CloudKitAuthManager.shared.isAuthenticated
    var legacyIsAuthenticated: Bool {
        return isAuthenticated
    }
    
    /// Drop-in replacement for CloudKitAuthManager.shared.currentUser
    var legacyCurrentUser: CloudKitUser? {
        return currentUser
    }
    
    /// Drop-in replacement for CloudKitAuthManager.shared.promptAuthForFeature
    func legacyPromptAuthForFeature(_ feature: AuthRequiredFeature, completion: (() -> Void)? = nil) {
        promptAuthForFeature(feature, completion: completion)
    }
    
    /// Drop-in replacement for CloudKitAuthManager.shared.signOut
    func legacySignOut() {
        signOut()
    }
}

// MARK: - Progressive Auth Compatibility

extension UnifiedAuthManager {
    /// Shows appropriate progressive prompt based on context
    func showProgressivePrompt(for context: SimpleProgressivePrompt.PromptContext) {
        // Check if user has opted out of progressive prompts
        guard !UserDefaults.standard.bool(forKey: "neverShowProgressiveAuth") else {
            return
        }
        
        // Check timing constraints
        let lastDismissalKey = "progressiveAuthDismissal_\(context.title.replacingOccurrences(of: " ", with: "_"))"
        if let lastDismissal = UserDefaults.standard.object(forKey: lastDismissalKey) as? Date,
           Date().timeIntervalSince(lastDismissal) < 24 * 60 * 60 { // 24 hours
            return
        }
        
        // Trigger the prompt
        shouldShowProgressivePrompt = true
    }
}
