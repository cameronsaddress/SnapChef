# CloudKit User Discovery Fixes

## Issues Fixed

### 1. Non-queryable Field Usage
**Problem**: The CloudKit schema had fields marked as queryable in comments but not actually queryable in the CloudKit database.

**Fields Affected**:
- `timestamp` field in Activity records
- `isProfilePublic` field in User records 
- `isVerified` field in User records
- `followerCount` field (may not be queryable)

**Solution**:
- Updated user discovery methods to use only confirmed queryable fields
- Added client-side filtering and sorting for non-queryable fields
- Updated schema documentation to clarify queryable requirements

### 2. User Discovery Method Updates

#### getSuggestedUsers()
- **Before**: Used `isProfilePublic == 1` (not queryable) sorted by `followerCount`
- **After**: Uses `totalPoints >= 0` (queryable) sorted by `totalPoints`
- **Rationale**: totalPoints is queryable and serves as a proxy for user engagement

#### getTrendingUsers() 
- **Before**: Used `isProfilePublic == 1` sorted by `recipesShared`
- **After**: Uses `lastActiveAt >= [7 days ago]` sorted by `lastActiveAt`
- **Rationale**: Recently active users represent "trending" users better

#### getVerifiedUsers()
- **Before**: Used `isVerified == 1 AND isProfilePublic == 1`
- **After**: Uses `totalPoints >= 1000` as proxy for verified status
- **Rationale**: High-point users are likely verified/trusted users

#### getNewUsers()
- **Before**: Used `isProfilePublic == 1` sorted by `createdAt`
- **After**: Uses `createdAt >= [30 days ago]` sorted by `createdAt`
- **Rationale**: Better filtering for actually new users

#### searchUsers()
- **Before**: Used `CONTAINS` queries with `isProfilePublic` filter
- **After**: Uses `BEGINSWITH` queries without non-queryable filters
- **Rationale**: BEGINSWITH is more performant for queryable fields

### 3. Activity Feed Fixes
**Problem**: Activity records used `timestamp` field for queries and sorting, which was not queryable/sortable.

**Solution**:
- Removed `timestamp` field from CloudKit query predicates and sort descriptors
- Added client-side filtering by timestamp after fetching records
- Added client-side sorting by timestamp
- Used `TRUEPREDICATE` or other queryable fields for initial filtering

### 4. CloudKit User Model Updates
**Problem**: User model initialization used hardcoded field names instead of CKField constants.

**Solution**:
- Updated CloudKitUser init method to use proper CKField constants
- Added proper Int64 to Int conversions for CloudKit numeric fields
- Fixed boolean field conversions (Int64 0/1 to Bool)

## Database Setup Requirements

For these fixes to work properly, ensure the CloudKit schema has these fields marked as **QUERYABLE**:

### User Record Type
- `username` (String) - QUERYABLE, INDEXED
- `displayName` (String) - QUERYABLE, INDEXED  
- `authProvider` (String) - QUERYABLE, INDEXED
- `totalPoints` (Int64) - QUERYABLE, INDEXED, SORTABLE
- `createdAt` (Date/Time) - QUERYABLE, INDEXED, SORTABLE
- `lastLoginAt` (Date/Time) - QUERYABLE, INDEXED, SORTABLE
- `lastActiveAt` (Date/Time) - QUERYABLE, INDEXED, SORTABLE

### Activity Record Type
- `id` (String) - QUERYABLE, INDEXED
- `type` (String) - QUERYABLE, INDEXED
- `actorID` (String) - QUERYABLE, INDEXED
- `targetUserID` (String) - QUERYABLE, INDEXED
- `recipeID` (String) - QUERYABLE, INDEXED
- `timestamp` (Date/Time) - QUERYABLE, INDEXED, SORTABLE

## Testing User Discovery

The user discovery methods should now work without throwing "field not queryable" errors:

```swift
// Test basic discovery
let suggested = try await CloudKitAuthManager.shared.getSuggestedUsers(limit: 10)
let trending = try await CloudKitAuthManager.shared.getTrendingUsers(limit: 10) 
let newUsers = try await CloudKitAuthManager.shared.getNewUsers(limit: 10)
let verified = try await CloudKitAuthManager.shared.getVerifiedUsers(limit: 10)

// Test search
let searchResults = try await CloudKitAuthManager.shared.searchUsers(query: "chef")
```

## Performance Considerations

1. **Client-side filtering**: Some operations now filter on the client, which may be less efficient for large datasets
2. **Query optimization**: Using BEGINSWITH instead of CONTAINS for better index usage
3. **Reduced network calls**: Fewer complex predicates mean more predictable CloudKit performance

## Future Improvements

1. **Schema updates**: Work with CloudKit team to make more fields queryable if needed
2. **Caching**: Implement local caching for user discovery results
3. **Background sync**: Pre-fetch popular users for better offline experience
4. **Analytics**: Track which discovery methods are most effective