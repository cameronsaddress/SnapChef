# CloudKit Recipe Sync Optimization Plan

## Executive Summary
This document outlines the step-by-step fixes to optimize CloudKit recipe syncing, ensuring recipes are downloaded only once and always served from local storage thereafter.

## Current Issues Identified

1. **Double Fetching**: `CloudKitRecipeCache.fetchNewRecipesOnly()` calls both `getUserSavedRecipes()` and `getUserCreatedRecipes()`, potentially fetching the same recipes twice
2. **No Local Persistence**: Created recipes are fetched from CloudKit on every app launch
3. **Inefficient Cache Timing**: 5-minute refresh interval is too aggressive
4. **Missing Change Detection**: No mechanism to detect if CloudKit actually has new data

## Implementation Phases

---

## PHASE 1: Fix Double Fetching Issue
**Priority: HIGH** | **Risk: LOW** | **Performance Gain: 50% reduction in CloudKit calls**

### Problem
File: `SnapChef/Core/Services/CloudKitRecipeCache.swift` (Line 176-194)
```swift
private func fetchNewRecipesOnly() async throws -> [Recipe] {
    // PROBLEM: Fetching both saved AND created recipes
    let savedRecipes = try await cloudKitManager.getUserSavedRecipes()
    let createdRecipes = try await cloudKitManager.getUserCreatedRecipes()
    let allCloudKitRecipes = savedRecipes + createdRecipes  // Potential duplicates!
}
```

### Solution
```swift
private func fetchNewRecipesOnly() async throws -> [Recipe] {
    print("📱 CloudKitCache: Fetching only new recipes from CloudKit...")
    
    // FIXED: Only fetch created recipes (which are ALL user's recipes by ownerID)
    // Saved recipes are tracked locally via LocalRecipeStorage
    let createdRecipes = try await cloudKitManager.getUserCreatedRecipes()
    
    // Filter out recipes we already have locally
    let newRecipes = createdRecipes.filter { recipe in
        !localRecipeIDs.contains(recipe.id)
    }
    
    print("📱 CloudKitCache: Found \(newRecipes.count) new recipes out of \(createdRecipes.count) total")
    
    return newRecipes
}
```

---

## PHASE 2: Persist Created Recipe IDs Locally
**Priority: HIGH** | **Risk: LOW** | **Performance Gain: Eliminate CloudKit calls on app launch**

### Problem
File: `SnapChef/Core/Services/CloudKitRecipeManager.swift` (Line 1017-1071)
- `getUserCreatedRecipes()` queries CloudKit every time
- No local cache persistence between app launches

### Solution - Part A: Add Local Cache to CloudKitRecipeManager
File: `SnapChef/Core/Services/CloudKitRecipeManager.swift`

Add these properties after line 19:
```swift
// Local cache persistence
private let localRecipeCacheKey = "cloudkit_local_recipe_cache_v1"
private let localRecipeCacheTimestampKey = "cloudkit_local_recipe_cache_timestamp"
private let cacheExpirationInterval: TimeInterval = 1800 // 30 minutes
private var localRecipeCache: [Recipe] = []
private var cacheTimestamp: Date?
```

Add initialization in `init()` after line 29:
```swift
private init() {
    self.publicDB = container.publicCloudDatabase
    self.privateDB = container.privateCloudDatabase
    loadLocalRecipeCache() // Add this line
    loadUserRecipeReferences()
}
```

Add these methods after `loadUserRecipeReferences()`:
```swift
// MARK: - Local Cache Management

private func loadLocalRecipeCache() {
    // Load cached recipes from UserDefaults
    if let data = UserDefaults.standard.data(forKey: localRecipeCacheKey),
       let recipes = try? JSONDecoder().decode([Recipe].self, from: data) {
        localRecipeCache = recipes
        print("📱 Loaded \(recipes.count) recipes from local cache")
    }
    
    // Load cache timestamp
    cacheTimestamp = UserDefaults.standard.object(forKey: localRecipeCacheTimestampKey) as? Date
    
    if let timestamp = cacheTimestamp {
        let age = Date().timeIntervalSince(timestamp)
        print("📱 Local recipe cache is \(Int(age))s old")
    }
}

private func saveLocalRecipeCache(_ recipes: [Recipe]) {
    localRecipeCache = recipes
    cacheTimestamp = Date()
    
    // Save to UserDefaults
    if let data = try? JSONEncoder().encode(recipes) {
        UserDefaults.standard.set(data, forKey: localRecipeCacheKey)
        UserDefaults.standard.set(cacheTimestamp, forKey: localRecipeCacheTimestampKey)
        print("💾 Saved \(recipes.count) recipes to local cache")
    }
}

private func isCacheValid() -> Bool {
    guard let timestamp = cacheTimestamp else { return false }
    let age = Date().timeIntervalSince(timestamp)
    return age < cacheExpirationInterval
}
```

### Solution - Part B: Update getUserCreatedRecipes
Replace the entire `getUserCreatedRecipes()` function (Line 1017-1071):
```swift
/// Get user's created recipes (optimized with local cache)
func getUserCreatedRecipes() async throws -> [Recipe] {
    // Check if user is authenticated
    guard UnifiedAuthManager.shared.isAuthenticated else {
        print("📱 User not authenticated - returning empty created recipes")
        return []
    }
    
    guard let currentUserID = getCurrentUserID() else {
        return []
    }
    
    // OPTIMIZATION: Return local cache immediately if valid
    if isCacheValid() && !localRecipeCache.isEmpty {
        print("📱 Using local recipe cache: \(localRecipeCache.count) recipes (cache valid)")
        
        // Start background refresh if cache is getting old (>15 minutes)
        if let timestamp = cacheTimestamp, 
           Date().timeIntervalSince(timestamp) > 900 {
            Task.detached { [weak self] in
                print("🔄 Starting background cache refresh...")
                if let recipes = try? await self?.fetchCreatedRecipesFromCloudKit() {
                    await MainActor.run {
                        self?.saveLocalRecipeCache(recipes)
                    }
                }
            }
        }
        
        return localRecipeCache
    }
    
    // Cache is invalid or empty, fetch from CloudKit
    print("🔄 Local cache invalid or empty, fetching from CloudKit...")
    let recipes = try await fetchCreatedRecipesFromCloudKit()
    
    // Save to local cache
    saveLocalRecipeCache(recipes)
    
    return recipes
}

private func fetchCreatedRecipesFromCloudKit() async throws -> [Recipe] {
    guard let currentUserID = getCurrentUserID() else {
        return []
    }
    
    print("🍳 Fetching created recipes from CloudKit for user: \(currentUserID)")
    
    // Query CloudKit for recipes owned by this user
    let predicate = NSPredicate(format: "ownerID == %@", currentUserID)
    let query = CKQuery(recordType: "Recipe", predicate: predicate)
    query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
    
    var allRecipes: [Recipe] = []
    var cursor: CKQueryOperation.Cursor?
    
    repeat {
        let operation: CKQueryOperation
        if let cursor = cursor {
            operation = CKQueryOperation(cursor: cursor)
        } else {
            operation = CKQueryOperation(query: query)
        }
        
        operation.resultsLimit = 50
        
        let (records, nextCursor) = try await withCheckedThrowingContinuation { continuation in
            var fetchedRecords: [CKRecord] = []
            
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    fetchedRecords.append(record)
                case .failure(let error):
                    print("❌ Failed to fetch record \(recordID): \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    continuation.resume(returning: (fetchedRecords, cursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            publicDB.add(operation)
        }
        
        // Parse recipes from records
        for record in records {
            do {
                let recipe = try parseRecipeFromRecord(record)
                allRecipes.append(recipe)
                
                // Cache the recipe
                if let recipeID = record["id"] as? String {
                    cachedRecipes[recipeID] = recipe
                    userCreatedRecipeIDs.insert(recipeID)
                }
            } catch {
                print("⚠️ Failed to parse recipe: \(error)")
            }
        }
        
        cursor = nextCursor
        print("📊 Fetched batch of \(records.count) recipes (total: \(allRecipes.count))")
    } while cursor != nil
    
    print("🍳 Retrieved \(allRecipes.count) created recipes from CloudKit")
    return allRecipes
}
```

---

## PHASE 3: Increase Cache Duration
**Priority: MEDIUM** | **Risk: LOW** | **Performance Gain: 80% reduction in CloudKit calls**

### Problem
File: `SnapChef/Core/Services/CloudKitRecipeCache.swift` (Line 39)
```swift
private let recipeFetchInterval: TimeInterval = 300 // 5 minutes - Too aggressive!
```

### Solution
```swift
// Change to 30 minutes - recipes don't change that often
private let recipeFetchInterval: TimeInterval = 1800 // 30 minutes

// Also update the intelligent refresh logic
private func shouldFetchFromCloudKit() -> Bool {
    // If we've never fetched, we should fetch
    guard let lastFetch = lastFetchDate else {
        print("📱 CloudKitCache: No previous fetch date, will fetch from CloudKit")
        return true
    }
    
    // Check if cache is empty (always fetch if empty)
    if cachedRecipes.isEmpty {
        print("📱 CloudKitCache: Cache is empty, will fetch from CloudKit")
        return true
    }
    
    // Check if enough time has passed since last fetch
    let timeSinceLastFetch = Date().timeIntervalSince(lastFetch)
    let shouldFetch = timeSinceLastFetch > recipeFetchInterval
    
    if shouldFetch {
        print("📱 CloudKitCache: \(Int(timeSinceLastFetch/60)) minutes since last fetch, will refresh")
    } else {
        print("📱 CloudKitCache: Only \(Int(timeSinceLastFetch/60)) minutes since last fetch, using cache")
    }
    
    return shouldFetch
}
```

---

## PHASE 4: Optimize Recipe Save Flow
**Priority: MEDIUM** | **Risk: LOW** | **Performance Gain: Instant save confirmation**

### Problem
File: `SnapChef/Core/Services/CloudKitRecipeManager.swift` (Line 879-906)
- `addRecipeToUserProfile` only tracks locally, doesn't update CloudKit

### Solution
Update `addRecipeToUserProfile()`:
```swift
/// Add recipe reference to user profile
func addRecipeToUserProfile(_ recipeID: String, type: RecipeListType) async throws {
    guard let userID = getCurrentUserID() else { return }
    
    // Track locally for instant UI update
    switch type {
    case .saved:
        userSavedRecipeIDs.insert(recipeID)
        print("✅ Recipe \(recipeID) marked as saved locally")
    case .created:
        userCreatedRecipeIDs.insert(recipeID)
        // Also update local cache when a new recipe is created
        if let recipe = cachedRecipes[recipeID] {
            localRecipeCache.append(recipe)
            saveLocalRecipeCache(localRecipeCache)
        }
        print("✅ Recipe \(recipeID) marked as created locally")
    case .favorited:
        userFavoritedRecipeIDs.insert(recipeID)
        print("✅ Recipe \(recipeID) marked as favorited locally")
    }
    
    // Persist to UserDefaults for next app launch
    persistRecipeReferences()
    
    // Update save count on recipe
    if type == .saved {
        await incrementSaveCount(for: recipeID)
    }
    
    print("✅ Recipe \(recipeID) successfully tracked as \(type)")
}

private func persistRecipeReferences() {
    UserDefaults.standard.set(Array(userSavedRecipeIDs), forKey: "user_saved_recipe_ids")
    UserDefaults.standard.set(Array(userCreatedRecipeIDs), forKey: "user_created_recipe_ids")
    UserDefaults.standard.set(Array(userFavoritedRecipeIDs), forKey: "user_favorited_recipe_ids")
}
```

---

## PHASE 5: Add Manual Refresh Option
**Priority: LOW** | **Risk: LOW** | **Performance Gain: User control**

### Solution
Add to `CloudKitRecipeCache.swift`:
```swift
/// Force refresh recipes from CloudKit (user-initiated)
func forceRefreshFromCloudKit() async {
    print("🔄 User-initiated force refresh from CloudKit")
    
    // Clear cache timestamp to force refresh
    lastFetchDate = nil
    
    // Fetch fresh data
    _ = await getRecipes(forceRefresh: true)
}
```

Add pull-to-refresh in `RecipesView.swift` (after line 104):
```swift
.refreshable {
    await cloudKitRecipeCache.forceRefreshFromCloudKit()
}
```

---

## Testing Plan

### After Each Phase:
1. Build test: `xcodebuild -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Debug build 2>&1`
2. Verify no compilation errors
3. Test scenarios:
   - App launch with existing cache
   - App launch with no cache
   - Create new recipe
   - Pull to refresh
   - Background sync

### Expected Results:
- **Phase 1**: 50% reduction in CloudKit API calls
- **Phase 2**: Instant recipe display on app launch
- **Phase 3**: 80% fewer background refreshes
- **Phase 4**: Instant save feedback
- **Phase 5**: User control over sync

## Rollback Plan
If any phase causes issues:
1. `git stash` to save changes
2. `git checkout main` to revert
3. Debug and fix offline
4. Reapply with `git stash pop`

## Success Metrics
- [ ] Recipes load instantly on app launch
- [ ] CloudKit is queried maximum once per 30 minutes
- [ ] No duplicate recipe fetches
- [ ] Recipe saves are instant with background sync
- [ ] Users can manually refresh when needed