# Recipe Like System Improvements

## Current Issues
1. Each RecipeCard maintains its own isolated like state
2. No central source of truth for liked recipes
3. Inefficient CloudKit queries for like counts
4. Race conditions with rapid tapping
5. Mixed systems (local favorites vs CloudKit likes)

## Proposed Solution

### 1. Create a Centralized Like Manager
```swift
@MainActor
class RecipeLikeManager: ObservableObject {
    static let shared = RecipeLikeManager()
    
    // Central cache of like states
    @Published var likedRecipeIDs: Set<String> = []
    @Published var recipeLikeCounts: [String: Int] = [:]
    
    // Track pending operations to prevent duplicates
    private var pendingOperations: Set<String> = []
    
    init() {
        loadUserLikes()
    }
    
    func isRecipeLiked(_ recipeID: String) -> Bool {
        return likedRecipeIDs.contains(recipeID)
    }
    
    func getLikeCount(for recipeID: String) -> Int {
        return recipeLikeCounts[recipeID] ?? 0
    }
    
    func toggleLike(for recipeID: String) async {
        // Prevent duplicate operations
        guard !pendingOperations.contains(recipeID) else { return }
        pendingOperations.insert(recipeID)
        defer { pendingOperations.remove(recipeID) }
        
        // Optimistic update
        let isCurrentlyLiked = likedRecipeIDs.contains(recipeID)
        
        if isCurrentlyLiked {
            likedRecipeIDs.remove(recipeID)
            recipeLikeCounts[recipeID] = max(0, (recipeLikeCounts[recipeID] ?? 0) - 1)
        } else {
            likedRecipeIDs.insert(recipeID)
            recipeLikeCounts[recipeID] = (recipeLikeCounts[recipeID] ?? 0) + 1
        }
        
        // CloudKit update
        do {
            if isCurrentlyLiked {
                try await CloudKitRecipeManager.shared.unlikeRecipe(recipeID: recipeID)
            } else {
                try await CloudKitRecipeManager.shared.likeRecipe(recipeID: recipeID)
            }
        } catch {
            // Revert on failure
            if isCurrentlyLiked {
                likedRecipeIDs.insert(recipeID)
                recipeLikeCounts[recipeID] = (recipeLikeCounts[recipeID] ?? 0) + 1
            } else {
                likedRecipeIDs.remove(recipeID)
                recipeLikeCounts[recipeID] = max(0, (recipeLikeCounts[recipeID] ?? 0) - 1)
            }
        }
    }
    
    func loadUserLikes() {
        Task {
            // Load user's liked recipes on startup
            let likes = await CloudKitRecipeManager.shared.fetchUserLikedRecipes()
            await MainActor.run {
                self.likedRecipeIDs = Set(likes)
            }
        }
    }
    
    func refreshLikeCount(for recipeID: String) async {
        // Fetch from Recipe record's likeCount field instead of counting records
        if let recipe = try? await CloudKitRecipeManager.shared.fetchRecipe(by: recipeID) {
            await MainActor.run {
                self.recipeLikeCounts[recipeID] = recipe.likeCount
            }
        }
    }
}
```

### 2. Update RecipeCard to Use Central Manager
```swift
struct RecipeCard: View {
    let recipe: Recipe
    @StateObject private var likeManager = RecipeLikeManager.shared
    @State private var isAnimating = false
    
    private var isLiked: Bool {
        likeManager.isRecipeLiked(recipe.id.uuidString)
    }
    
    private var likeCount: Int {
        likeManager.getLikeCount(for: recipe.id.uuidString)
    }
    
    private func toggleLike() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Animate
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        // Update via manager
        Task {
            await likeManager.toggleLike(for: recipe.id.uuidString)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation {
                isAnimating = false
            }
        }
    }
}
```

### 3. Optimize CloudKit Implementation
```swift
// In CloudKitRecipeManager
func fetchUserLikedRecipes() async -> [String] {
    guard let userID = getCurrentUserID() else { return [] }
    
    let predicate = NSPredicate(format: "userID == %@", userID)
    let query = CKQuery(recordType: "RecipeLike", predicate: predicate)
    
    do {
        let (matchResults, _) = try await publicDB.records(matching: query)
        return matchResults.compactMap { try? $0.1.get()["recipeID"] as? String }
    } catch {
        print("Failed to fetch user likes: \(error)")
        return []
    }
}

// Update recipe record to maintain accurate like count
func updateRecipeLikeCount(recipeID: String, increment: Bool) async {
    let recordID = CKRecord.ID(recordName: recipeID)
    
    do {
        let record = try await publicDB.record(for: recordID)
        let currentCount = record["likeCount"] as? Int64 ?? 0
        record["likeCount"] = increment ? currentCount + 1 : max(0, currentCount - 1)
        _ = try await publicDB.save(record)
        
        // Update local cache
        await RecipeLikeManager.shared.refreshLikeCount(for: recipeID)
    } catch {
        print("Failed to update like count: \(error)")
    }
}
```

### 4. Benefits of This Approach
- **Single Source of Truth**: All like states managed centrally
- **Consistent UI**: All recipe cards showing same recipe will update together
- **Optimistic Updates**: Immediate UI feedback with rollback on failure
- **Efficient Queries**: Load all user likes once, then cache
- **Prevents Race Conditions**: Tracks pending operations
- **Better Performance**: Uses recipe's likeCount field instead of counting records

### 5. Implementation Steps
1. Create RecipeLikeManager class
2. Update RecipeCard to use the manager
3. Update CloudKitRecipeManager methods for efficiency
4. Add batch loading on app startup
5. Test with multiple recipe cards visible simultaneously

### 6. Additional Enhancements
- Add local persistence with UserDefaults/Core Data for offline support
- Implement exponential backoff for failed CloudKit operations
- Add analytics tracking for like/unlike actions
- Consider WebSocket/push notifications for real-time like count updates