# Activity Feed Optimization Plan

## Current Performance Issues

The activity feed is experiencing significant performance degradation due to:
1. **Sequential CloudKit queries** - Each operation waits for the previous to complete
2. **Redundant user fetches** - Same user data fetched multiple times without caching
3. **Recipe validation overhead** - Each activity checks if recipe exists (N additional queries)
4. **Limited batch size** - Only fetching 10 followed users due to CloudKit constraints
5. **No caching layer** - User display names and avatars fetched repeatedly
6. **Inefficient data mapping** - Multiple passes over the same data

## Existing CloudKit Fields (DO NOT CHANGE)

### Activity Record Type
- `type` (STRING) - Activity type (recipeLiked, userFollowed, recipeShared, etc.)
- `actorID` (STRING) - User who performed the action
- `targetUserID` (STRING) - User who receives the notification (optional)
- `recipeID` (STRING) - Related recipe (optional)
- `recipeName` (STRING) - Recipe title (optional)
- `timestamp` (DATE/TIME) - When activity occurred
- `metadata` (STRING) - JSON encoded additional data

### User Record Type
- `recordID` - CloudKit record ID (format: "_abc123")
- `username` (STRING) - Display username
- `displayName` (STRING) - Full display name
- `bio` (STRING) - User biography
- `profilePictureAsset` (ASSET) - Profile photo
- `followerCount` (INT64) - Number of followers
- `followingCount` (INT64) - Number following
- `recipesCreated` (INT64) - Recipes created count

### Recipe Record Type
- `recordID` - Recipe unique ID
- `title` (STRING) - Recipe name
- `ownerID` (STRING) - Creator's user ID
- `imageAsset` (ASSET) - Recipe photo
- `likeCount` (INT64) - Number of likes
- `shareCount` (INT64) - Number of shares
- `viewCount` (INT64) - Number of views

## Implementation Plan

### Phase 1: User Cache Manager (Immediate Impact)
Create a centralized cache for user data to eliminate redundant fetches.

**Location**: `SnapChef/Core/Services/UserCacheManager.swift`

```swift
@MainActor
class UserCacheManager: ObservableObject {
    static let shared = UserCacheManager()
    
    private struct CachedUser {
        let username: String
        let displayName: String?
        let avatarData: Data?
        let fetchTime: Date
    }
    
    private var cache: [String: CachedUser] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    func getUserInfo(_ userID: String) async -> (username: String, displayName: String?, avatar: Data?) {
        // Return cached if fresh
        if let cached = cache[userID],
           Date().timeIntervalSince(cached.fetchTime) < cacheTimeout {
            return (cached.username, cached.displayName, cached.avatarData)
        }
        
        // Fetch from CloudKit using existing CloudKitActor
        let info = await fetchUserFromCloudKit(userID)
        
        // Cache the result
        cache[userID] = CachedUser(
            username: info.username,
            displayName: info.displayName,
            avatarData: info.avatar,
            fetchTime: Date()
        )
        
        return info
    }
    
    func batchFetchUsers(_ userIDs: [String]) async -> [String: (username: String, displayName: String?, avatar: Data?)] {
        // Fetch all uncached users in parallel
    }
    
    func clearCache() {
        cache.removeAll()
    }
}
```

### Phase 2: Parallel Query Execution
Replace sequential queries with parallel execution using TaskGroup.

**Updates to**: `SnapChef/Features/Social/ActivityFeedManager.swift`

```swift
func loadActivities() async {
    await withTaskGroup(of: [ActivityItem].self) { group in
        // Load all activity types in parallel
        group.addTask { await self.fetchUserActivities() }
        group.addTask { await self.fetchFollowedUserActivities() }
        group.addTask { await self.fetchRecipeLikes() }
        
        var allActivities: [ActivityItem] = []
        for await activities in group {
            allActivities.append(contentsOf: activities)
        }
        
        // Sort and deduplicate once
        self.activities = self.deduplicateAndSort(allActivities)
    }
}
```

### Phase 3: Batch User Fetching
Fetch all required user data in a single operation.

```swift
func enrichActivitiesWithUserData(_ activities: [ActivityItem]) async -> [ActivityItem] {
    // Collect all unique user IDs
    var userIDs = Set<String>()
    for activity in activities {
        userIDs.insert(activity.actorID)
        if let targetID = activity.targetUserID {
            userIDs.insert(targetID)
        }
    }
    
    // Batch fetch all users at once
    let userCache = UserCacheManager.shared
    let users = await userCache.batchFetchUsers(Array(userIDs))
    
    // Enrich activities with cached data
    return activities.map { activity in
        var enriched = activity
        if let userInfo = users[activity.actorID] {
            enriched.actorName = userInfo.username
            enriched.actorAvatar = userInfo.avatar
        }
        return enriched
    }
}
```

### Phase 4: Remove Recipe Validation
Skip individual recipe existence checks - handle missing recipes gracefully in UI.

**Current (Slow)**:
```swift
// Validates every recipe exists
if let recipeID = record["recipeID"] as? String {
    if await doesRecipeExist(recipeID) { // Extra query!
        activityItem.recipeID = recipeID
    }
}
```

**Optimized**:
```swift
// Just pass the ID, handle missing recipes in UI
activityItem.recipeID = record["recipeID"] as? String
activityItem.recipeName = record["recipeName"] as? String ?? "Recipe"
```

### Phase 5: Optimize Follow Query Chunking
Work around CloudKit's IN query limitation by parallel chunking.

```swift
func fetchFollowedUserActivities() async -> [ActivityItem] {
    let followedUserIDs = await getFollowedUserIDs()
    
    // CloudKit limits IN queries to 10 items, so chunk and parallelize
    let chunks = followedUserIDs.chunked(into: 10)
    
    return await withTaskGroup(of: [ActivityItem].self) { group in
        for chunk in chunks {
            group.addTask {
                await self.fetchActivitiesForUsers(chunk)
            }
        }
        
        var allActivities: [ActivityItem] = []
        for await activities in group {
            allActivities.append(contentsOf: activities)
        }
        return allActivities
    }
}
```

### Phase 6: Implement Smart Pagination
Load activities incrementally to improve perceived performance.

```swift
class ActivityFeedManager {
    private var lastCursor: CKQueryOperation.Cursor?
    private let pageSize = 20
    
    func loadInitialActivities() async {
        // Load first page quickly
        let activities = await fetchActivitiesPage(limit: pageSize)
        await MainActor.run {
            self.activities = activities
            self.isLoading = false
        }
    }
    
    func loadMoreActivities() async {
        guard let cursor = lastCursor, !isLoadingMore else { return }
        // Load next page
        let moreActivities = await fetchActivitiesPage(cursor: cursor, limit: pageSize)
        await MainActor.run {
            self.activities.append(contentsOf: moreActivities)
        }
    }
}
```

## Expected Performance Improvements

| Metric | Current | Expected | Improvement |
|--------|---------|----------|-------------|
| Initial Load Time | 3-5 seconds | 0.8-1.2 seconds | **75% faster** |
| CloudKit Queries | 50-100+ | 10-15 | **80% reduction** |
| User Data Fetches | N per activity | 1 batch | **95% reduction** |
| Memory Usage | Uncached | Efficient cache | **Stable** |
| Scroll Performance | Stutters | Smooth 60fps | **100% improvement** |

## Implementation Timeline

1. **Hour 1**: Implement UserCacheManager
2. **Hour 2**: Update ActivityFeedManager with parallel queries
3. **Hour 3**: Add batch user fetching and remove recipe validation
4. **Hour 4**: Test and measure performance improvements
5. **Hour 5**: Fine-tune and handle edge cases

## Testing Strategy

1. **Measure baseline** - Log current query counts and load times
2. **Unit test cache** - Verify cache hit rates and expiration
3. **Integration test** - Ensure all activity types still display correctly
4. **Performance test** - Measure improvement with 100+ activities
5. **Edge cases** - Test with no network, expired cache, new users

## Rollback Plan

If issues arise:
1. UserCacheManager can be disabled by setting cacheTimeout to 0
2. Parallel queries can revert to sequential with feature flag
3. All changes are backward compatible with existing CloudKit schema

## Success Criteria

- [ ] Activity feed loads in under 1.5 seconds
- [ ] No duplicate CloudKit queries for same user
- [ ] Smooth scrolling at 60fps
- [ ] All existing activity types display correctly
- [ ] No increase in crash rate or errors

## Notes

- All optimizations use EXISTING CloudKit fields only
- No schema changes required
- Backward compatible with existing data
- Cache is memory-only (no persistence needed)
- Respects CloudKit rate limits with intelligent batching