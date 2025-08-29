import Foundation
import SwiftUI
import CloudKit

/// Centralized manager for recipe like states and counts
/// Provides single source of truth for all like-related data
@MainActor
class RecipeLikeManager: ObservableObject {
    static let shared = RecipeLikeManager()
    
    // MARK: - Published Properties
    
    /// Set of recipe IDs that the current user has liked
    @Published var likedRecipeIDs: Set<String> = []
    
    /// Cache of like counts for recipes
    @Published var recipeLikeCounts: [String: Int] = [:]
    
    // MARK: - Private Properties
    
    /// Track pending operations to prevent duplicates
    private var pendingOperations: Set<String> = []
    
    /// Reference to CloudKit manager
    private let cloudKitManager = CloudKitRecipeManager.shared
    
    /// Reference to auth manager
    private let authManager = UnifiedAuthManager.shared
    
    // MARK: - Initialization
    
    private init() {
        // Don't automatically load likes on init
        // Views should explicitly call loadUserLikes() when they appear
        // This prevents race conditions and ensures proper auth state
    }
    
    // MARK: - Public Methods
    
    /// Check if a recipe is liked by the current user
    func isRecipeLiked(_ recipeID: String) -> Bool {
        return likedRecipeIDs.contains(recipeID)
    }
    
    /// Get the cached like count for a recipe
    func getLikeCount(for recipeID: String) -> Int {
        return recipeLikeCounts[recipeID] ?? 0
    }
    
    /// Toggle like state for a recipe with optimistic updates
    func toggleLike(for recipeID: String) async {
        // Check authentication
        guard authManager.isAuthenticated else {
            await MainActor.run {
                authManager.promptAuthForFeature(.socialSharing)
            }
            return
        }
        
        // Prevent duplicate operations
        guard !pendingOperations.contains(recipeID) else { 
            print("⚠️ Like operation already pending for recipe: \(recipeID)")
            return 
        }
        
        pendingOperations.insert(recipeID)
        defer { pendingOperations.remove(recipeID) }
        
        // Determine current state
        let isCurrentlyLiked = likedRecipeIDs.contains(recipeID)
        
        // Optimistic update - update UI immediately
        if isCurrentlyLiked {
            likedRecipeIDs.remove(recipeID)
            recipeLikeCounts[recipeID] = max(0, (recipeLikeCounts[recipeID] ?? 0) - 1)
            print("👎 Optimistically unliked recipe: \(recipeID)")
        } else {
            likedRecipeIDs.insert(recipeID)
            recipeLikeCounts[recipeID] = (recipeLikeCounts[recipeID] ?? 0) + 1
            print("👍 Optimistically liked recipe: \(recipeID)")
        }
        
        // CloudKit update
        do {
            if isCurrentlyLiked {
                try await cloudKitManager.unlikeRecipe(recipeID: recipeID)
                print("✅ Successfully unliked recipe in CloudKit: \(recipeID)")
            } else {
                try await cloudKitManager.likeRecipe(recipeID: recipeID)
                print("✅ Successfully liked recipe in CloudKit: \(recipeID)")
            }
            
            // Don't immediately refresh from CloudKit - the optimistic update is accurate
            // and CloudKit may not have indexed the new record yet
            // The count will be refreshed when the view reappears or on pull-to-refresh
        } catch {
            print("❌ Failed to update like status: \(error)")
            
            // Revert optimistic update on failure
            await MainActor.run {
                if isCurrentlyLiked {
                    // Was liked, tried to unlike but failed - restore liked state
                    self.likedRecipeIDs.insert(recipeID)
                    self.recipeLikeCounts[recipeID] = (self.recipeLikeCounts[recipeID] ?? 0) + 1
                } else {
                    // Was unliked, tried to like but failed - restore unliked state
                    self.likedRecipeIDs.remove(recipeID)
                    self.recipeLikeCounts[recipeID] = max(0, (self.recipeLikeCounts[recipeID] ?? 0) - 1)
                }
            }
        }
    }
    
    /// Load all recipes liked by the current user
    func loadUserLikes() async {
        guard authManager.isAuthenticated else {
            print("⚠️ User not authenticated - skipping like load")
            return
        }
        
        print("📥 Loading user's liked recipes...")
        
        let likedRecipes = await cloudKitManager.fetchUserLikedRecipes()
        
        await MainActor.run {
            self.likedRecipeIDs = Set(likedRecipes)
            print("✅ Loaded \(likedRecipes.count) liked recipes")
        }
        
        // Also load counts for liked recipes
        for recipeID in likedRecipes {
            await refreshLikeCount(for: recipeID)
        }
    }
    
    /// Refresh the like count for a specific recipe from CloudKit
    func refreshLikeCount(for recipeID: String) async {
        // Get the actual count from CloudKit (now reads from Recipe record first)
        let count = await cloudKitManager.getLikeCount(for: recipeID)
        
        await MainActor.run {
            // Only update if the count is different from what we have
            if self.recipeLikeCounts[recipeID] != count {
                self.recipeLikeCounts[recipeID] = count
                print("📊 Updated like count for \(recipeID): \(count)")
            }
        }
    }
    
    /// Batch refresh like counts for multiple recipes efficiently
    func refreshLikeCounts(for recipeIDs: [String]) async {
        guard !recipeIDs.isEmpty else { return }
        
        print("📊 Batch refreshing like counts for \(recipeIDs.count) recipes")
        
        // Use the new batch fetch method
        let counts = await cloudKitManager.batchFetchLikeCounts(for: recipeIDs)
        
        await MainActor.run {
            // Update all counts at once
            for (recipeID, count) in counts {
                if self.recipeLikeCounts[recipeID] != count {
                    self.recipeLikeCounts[recipeID] = count
                }
            }
            print("✅ Batch updated \(counts.count) like counts")
        }
    }
    
    /// Clear all cached data (useful for logout)
    func clearCache() {
        likedRecipeIDs.removeAll()
        recipeLikeCounts.removeAll()
        pendingOperations.removeAll()
        print("🧹 Cleared like manager cache")
    }
    
    /// Handle user authentication changes
    func handleAuthenticationChange() {
        if authManager.isAuthenticated {
            Task {
                await loadUserLikes()
            }
        } else {
            clearCache()
        }
    }
}