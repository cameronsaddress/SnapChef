# CloudKitAuthManager to UnifiedAuthManager Migration Plan

## Overview
Consolidate all authentication functionality from CloudKitAuthManager into UnifiedAuthManager, ensuring all features work with the production CloudKit schema.

## Current Production Schema Analysis

### User Record Fields (CONFIRMED IN PRODUCTION)
```
authProvider        STRING QUERYABLE
bio                 STRING
challengesCompleted INT64
coinBalance         INT64
createdAt           TIMESTAMP SORTABLE
currentStreak       INT64
displayName         STRING QUERYABLE SEARCHABLE
email               STRING
followerCount       INT64 QUERYABLE
followingCount      INT64
isProfilePublic     INT64
isVerified          INT64
lastActiveAt        TIMESTAMP SORTABLE
lastLoginAt         TIMESTAMP SORTABLE
longestStreak       INT64
profileImageURL     STRING
recipesCreated      INT64 QUERYABLE
recipesShared       INT64
showOnLeaderboard   INT64
subscriptionTier    STRING
totalPoints         INT64 QUERYABLE SORTABLE
userID              STRING QUERYABLE
username            STRING QUERYABLE SORTABLE
```

## Functionality Comparison

### ✅ Already in UnifiedAuthManager
- Sign in with Apple
- Sign in with TikTok
- Username setup and availability checking
- Anonymous user tracking
- Progressive authentication
- Basic user search (getSuggestedUsers, getTrendingUsers, getVerifiedUsers, getNewUsers, searchUsers)
- Follow/unfollow functionality
- Auth requirement checking
- Sign out

### ❌ Missing from UnifiedAuthManager (in CloudKitAuthManager)
1. **updateUserStats()** - Updates user statistics like points, streaks, challenges
2. **refreshCurrentUser()** - Refreshes current user data from CloudKit
3. **updateSocialCounts()** - Updates follower/following counts
4. **getUsersFollowedBy()** - Gets list of users followed by a specific user

### 🔴 CRITICAL: Missing Production Schema Fields

Based on app functionality, these fields are NEEDED but MISSING from production:

1. **appleUserID** or **appleUserId** - Need to store Apple Sign in identifier
   - Currently trying to store but field doesn't exist
   - CRITICAL for re-authentication

2. **tiktokUserID** or **tiktokUserId** - Need to store TikTok identifier
   - App has TikTok auth but no field to store the ID
   - CRITICAL for TikTok integration

3. **profilePictureAsset** - For storing actual profile photos
   - Currently only have profileImageURL (string)
   - Need ASSET field for CloudKit photo storage

## Migration Tasks

### Phase 1: Add Missing Functions to UnifiedAuthManager
1. Port `updateUserStats()` from CloudKitAuthManager
2. Port `refreshCurrentUser()` from CloudKitAuthManager  
3. Port `updateSocialCounts()` from CloudKitAuthManager
4. Port `getUsersFollowedBy()` from CloudKitAuthManager

### Phase 2: Update All References
Files that import/use CloudKitAuthManager:
- ContentView.swift
- ProfileView.swift
- FeedView.swift
- ChallengeHubView.swift
- UsernameSetupView.swift
- CloudKitAuthView.swift
- UserProfileViewModel.swift
- And many more...

### Phase 3: Field Mapping
Map all field references to production schema:
- `fullName` → `displayName`
- `updatedAt` → `lastLoginAt` or `lastActiveAt`
- Remove references to non-existent fields

### Phase 4: Remove CloudKitAuthManager
1. Delete CloudKitAuthManager.swift
2. Remove from Xcode project
3. Clean build

## Required Production Schema Updates

### CRITICAL - Add these fields to production:
```sql
-- In User record type, ADD:
appleUserId         STRING QUERYABLE  -- Store Apple Sign In identifier
tiktokUserId        STRING QUERYABLE  -- Store TikTok identifier
profilePictureAsset ASSET             -- Store actual profile photo
```

### NICE TO HAVE - Consider adding:
```sql
-- For better user management:
googleUserId        STRING QUERYABLE  -- If adding Google sign in
facebookUserId      STRING QUERYABLE  -- If adding Facebook sign in
lastSeenAt          TIMESTAMP         -- Track user activity
preferences         STRING            -- Store user preferences JSON
```

## File-by-File Update List

### Files using CloudKitAuthManager.shared:
1. **ContentView.swift** - Update to UnifiedAuthManager.shared
2. **ProfileView.swift** - Update to UnifiedAuthManager.shared
3. **FeedView.swift** - Update to UnifiedAuthManager.shared
4. **ChallengeHubView.swift** - Update to UnifiedAuthManager.shared
5. **UsernameSetupView.swift** - Update to UnifiedAuthManager.shared
6. **CloudKitAuthView.swift** - Update to UnifiedAuthManager.shared
7. **UserProfileViewModel.swift** - Update to UnifiedAuthManager.shared
8. **RecipeResultsView.swift** - Update to UnifiedAuthManager.shared
9. **ShareGeneratorView.swift** - Update to UnifiedAuthManager.shared
10. **TeamChallengeView.swift** - Update to UnifiedAuthManager.shared
11. **CreateTeamView.swift** - Update to UnifiedAuthManager.shared
12. **AchievementGalleryView.swift** - Update to UnifiedAuthManager.shared
13. **LeaderboardView.swift** - Update to UnifiedAuthManager.shared
14. **ChallengeCardView.swift** - Update to UnifiedAuthManager.shared
15. **ChallengeProofSubmissionView.swift** - Update to UnifiedAuthManager.shared

## Implementation Order

1. **FIRST**: Get confirmation on adding missing fields to production
2. **THEN**: Port missing functions to UnifiedAuthManager
3. **NEXT**: Update all file references
4. **FINALLY**: Remove CloudKitAuthManager

## Testing Checklist
- [ ] Apple Sign In works
- [ ] TikTok Sign In works
- [ ] Username setup works
- [ ] Profile photo upload works
- [ ] Follow/unfollow works
- [ ] User search works
- [ ] Stats update correctly
- [ ] Sign out works
- [ ] Re-authentication works

## Notes
- CloudKitAuthManager is mostly disabled already (see line 32-91)
- UnifiedAuthManager is already the primary auth manager
- Main issue is missing production fields for storing auth provider IDs