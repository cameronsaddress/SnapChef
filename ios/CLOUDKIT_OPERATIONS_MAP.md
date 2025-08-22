# CloudKit Operations Map

## Overview
This document maps all CloudKit read/write/create/delete operations in the SnapChef codebase.

## Files with CloudKit Operations

### 1. **CloudKitRecipeManager.swift**
- `saveRecipe()` - Saves recipe to publicDB
- `fetchRecipes()` - Fetches user's recipes from publicDB
- `deleteRecipe()` - Deletes recipe from publicDB
- `fetchRecipe(byID:)` - Fetches single recipe
- `updateRecipe()` - Updates existing recipe

### 2. **CloudKitChallengeManager.swift**
- `createChallenge()` - Creates challenge in publicDB (line 53)
- `joinChallenge()` - Creates participation record in privateDB (line 120)
- `updateChallengeProgress()` - Updates progress in publicDB (line 178)
- `completeChallenge()` - Updates completion status (line 228)
- `fetchActiveChallenges()` - Queries active challenges
- `fetchUserChallenges()` - Queries user's challenges
- `logChallengeActivity()` - Logs activity in publicDB (line 290)
- `shareChallenge()` - Creates share record (line 321)
- `submitChallengeEntry()` - Submits entry (line 405)

### 3. **CloudKitSyncService.swift**
- `uploadRecipe()` - Uploads recipe to publicDB (line 76)
- `toggleFavorite()` - Creates/deletes favorite record (lines 166, 177)
- `likeRecipe()` - Creates like record (line 203)
- `updateUserStats()` - Updates user statistics (lines 294, 318)
- `logActivity()` - Creates activity record (line 350)
- `followUser()` - Creates follow relationship (line 388)
- `addComment()` - Adds comment to recipe (line 437)
- `fetchComments()` - Queries comments (line 471)
- `incrementRecipeViews()` - Updates view count (line 507)
- `saveChallenge()` - Saves challenge (line 522)
- `updateChallenge()` - Updates challenge (line 570)
- `setupSubscriptions()` - Creates push subscriptions (line 623)
- `fetchActiveChallenges()` - Queries challenges (line 726)
- `joinChallenge()` - Creates participation (line 822)
- `updateChallengeProgress()` - Updates progress (line 851)
- `logChallengeActivity()` - Logs activity (line 900)
- `shareChallenge()` - Creates share (line 918)
- `submitChallengeEntry()` - Submits entry (line 927)
- `fetchFollowers()` - Queries followers (line 973)

### 4. **CloudKitModules/AuthModule.swift**
- `createOrUpdateUserFromAppleID()` - Creates/updates user (lines 68, 121)
- `createOrUpdateUserFromTikTok()` - Creates/updates user (lines 172, 227)
- `updateUserProfile()` - Updates profile (line 289)
- `updateUsername()` - Updates username (line 343)
- `followUser()` - Creates follow record (line 417)
- `unfollowUser()` - Deletes follow record (line 453)
- `incrementRecipesCreated()` - Updates stats (line 557)
- `incrementRecipesShared()` - Updates stats (line 574)
- `fetchFollowers()` - Queries followers (line 617)
- `fetchFollowing()` - Queries following (line 653)
- `fetchUser()` - Fetches user by ID (line 689)
- `updateProfilePicture()` - Updates avatar (line 766)

### 5. **CloudKitModules/UserModule.swift**
- `createUser()` - Creates user record in publicDB
- `updateUser()` - Updates user record
- `fetchUser()` - Fetches user by ID
- `deleteUser()` - Deletes user record
- `searchUsers()` - Queries users by username

### 6. **CloudKitModules/SyncModule.swift**
- `syncRecipes()` - Syncs recipes between local and cloud
- `syncChallenges()` - Syncs challenges
- `syncUserData()` - Syncs user profile
- `resolveConflicts()` - Handles sync conflicts

### 7. **CloudKitUserManager.swift**
- `createProfile()` - Creates user profile (line 68)
- `updateProfile()` - Updates profile (line 132)
- `updateUsername()` - Updates username (line 144)
- `updateAvatar()` - Updates avatar (line 159)
- `updateBio()` - Updates bio (line 171)
- `incrementStat()` - Updates statistics (lines 318, 330)

### 8. **CloudKitDataManager.swift**
- `savePreferences()` - Saves preferences to privateDB (line 138)
- `fetchPreferences()` - Fetches preferences
- `saveDraft()` - Saves draft recipe (line 163)
- `fetchDrafts()` - Fetches draft recipes
- `saveNote()` - Saves recipe note (line 207)
- `fetchNotes()` - Fetches notes
- `saveRating()` - Saves recipe rating (line 249)
- `fetchRatings()` - Fetches ratings
- `saveCookingHistory()` - Saves history (line 273)
- `fetchCookingHistory()` - Fetches history
- `saveShoppingList()` - Saves shopping list (line 298)
- `setupSubscription()` - Creates subscription (line 320)
- `batchSave()` - Batch saves records (line 402)

### 9. **CloudKitStreakManager.swift**
- `updateStreak()` - Updates streak in privateDB (line 43)
- `resetStreak()` - Resets streak (line 63)
- `shareStreak()` - Shares streak to publicDB (line 82)

### 10. **CloudKitManager.swift**
- `setupRecordZones()` - Creates custom zones (line 79)
- `setupSubscriptions()` - Creates subscriptions (line 102)
- `syncChallenges()` - Syncs challenges (line 147)
- `createChallenge()` - Creates challenge (line 256)
- `joinChallenge()` - Creates participation (line 278)
- `updateChallengeProgress()` - Updates progress (line 317)
- `completeChallenge()` - Marks complete (line 333)
- `logChallengeActivity()` - Logs activity (line 348)
- `shareChallenge()` - Creates share (line 395)

### 11. **UnifiedAuthManager.swift**
- CloudKit operations through AuthModule
- User record management
- Profile updates
- Follow/unfollow operations

### 12. **LocalRecipeStore.swift**
- `syncToCloudKit()` - Syncs local recipes to cloud (line 398)

## Operation Categories

### CREATE Operations (Records being created)
- User profiles
- Recipes
- Challenges
- Challenge participations
- Activities
- Comments
- Likes
- Favorites
- Follow relationships
- Subscriptions
- Shopping lists
- Ratings
- Notes
- Drafts

### READ Operations (Queries/Fetches)
- User profiles by ID
- User search by username
- Recipes by user
- Recipe by ID
- Active challenges
- User challenges
- Comments on recipes
- Followers/Following lists
- Activity feed
- Preferences
- Drafts
- Notes
- Ratings
- Shopping lists

### UPDATE Operations (Modifications)
- User profile fields
- Recipe details
- Challenge progress
- User statistics
- View counts
- Streak data
- Preferences

### DELETE Operations
- Recipes
- Favorites
- Follow relationships
- Drafts
- Notes

## Databases Used

### Public Database (publicDB)
- User profiles
- Recipes
- Challenges
- Activities
- Comments
- Likes
- Follow relationships
- Shared content

### Private Database (privateDB)
- User preferences
- Draft recipes
- Personal notes
- Shopping lists
- Challenge participation
- Streak data
- Personal ratings

## Critical Operations Requiring Debug Logging

1. **User Authentication/Creation** - Must never fail silently
2. **Recipe Save/Upload** - Core functionality
3. **Challenge Operations** - Gamification features
4. **Social Operations** - Follow/unfollow, likes, comments
5. **Sync Operations** - Data consistency
6. **Subscription Setup** - Push notifications

## Implementation Plan

1. Add CloudKitDebugLogger calls to each operation
2. Wrap operations with timing measurements
3. Log all errors with context
4. Add assertion failures for critical errors in DEBUG
5. Track operation statistics
6. Provide debug console for viewing recent errors