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
        // Load user likes on initialization
        Task {
            await loadUserLikes()
        }
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
            
            // Refresh the actual count from CloudKit after successful operation
            await refreshLikeCount(for: recipeID)
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
        do {
            // First try to get it from the recipe record itself
            let recordID = CKRecord.ID(recordName: recipeID)
            let container = CKContainer(identifier: "iCloud.com.snapchefapp.app")
            let publicDB = container.publicCloudDatabase
            
            if let record = try? await publicDB.record(for: recordID) {
                let count = Int(record["likeCount"] as? Int64 ?? 0)
                await MainActor.run {
                    self.recipeLikeCounts[recipeID] = count
                    print("📊 Updated like count for \(recipeID): \(count)")
                }
            } else {
                // Fallback to counting records if recipe not found
                let count = await cloudKitManager.getLikeCount(for: recipeID)
                await MainActor.run {
                    self.recipeLikeCounts[recipeID] = count
                    print("📊 Counted likes for \(recipeID): \(count)")
                }
            }
        }
    }
    
    /// Batch refresh like counts for multiple recipes
    func refreshLikeCounts(for recipeIDs: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for recipeID in recipeIDs {
                group.addTask { [weak self] in
                    await self?.refreshLikeCount(for: recipeID)
                }
            }
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