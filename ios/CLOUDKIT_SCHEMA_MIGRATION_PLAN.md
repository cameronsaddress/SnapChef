# CloudKit Schema Migration Plan

## Date: August 24, 2025
## Status: READY FOR IMPLEMENTATION

---

## CRITICAL ISSUES IDENTIFIED

### 1. User Record Issues
Current `User` record has these fields but they have problems:
- `followerCount` (INT64) - EXISTS but marked as QUERYABLE SORTABLE only, needs WRITE permission
- `followingCount` (INT64) - EXISTS but NOT marked as QUERYABLE or SORTABLE, needs both
- `username` (STRING) - EXISTS and properly configured
- `displayName` (STRING) - EXISTS and properly configured
- `recipesCreated` (INT64) - EXISTS and QUERYABLE but needs SORTABLE
- `recipesShared` (INT64) - EXISTS and SORTABLE but NOT QUERYABLE

### 2. UserProfile Record (DEPRECATED)
- Has duplicate fields: `followersCount` vs `followerCount` (note the 's')
- Should NOT be used - User record is primary

### 3. Follow Record
- Correctly configured with proper fields and permissions
- `followerID` and `followingID` are STRING QUERYABLE as expected

---

## SCHEMA UPDATE PLAN

### Phase 1: Fix User Record Field Permissions

#### Current User Record Fields to Update:
```sql
-- CURRENT (line 669-670):
followerCount       INT64 QUERYABLE SORTABLE,
followingCount      INT64,

-- SHOULD BE:
followerCount       INT64 QUERYABLE SORTABLE,
followingCount      INT64 QUERYABLE SORTABLE,
```

#### Recipe Count Fields to Update:
```sql
-- CURRENT (line 678-679):
recipesCreated      INT64 QUERYABLE,
recipesShared       INT64 SORTABLE,

-- SHOULD BE:
recipesCreated      INT64 QUERYABLE SORTABLE,
recipesShared       INT64 QUERYABLE SORTABLE,
```

### Phase 2: Add New Fields for Better Functionality

#### New Fields to Add to User Record:
```sql
-- Add after line 685 (after username field):
recipeSaveCount     INT64 QUERYABLE SORTABLE,  -- Total saves of user's recipes
recipeLikeCount     INT64 QUERYABLE SORTABLE,  -- Total likes on user's recipes
recipeViewCount     INT64 QUERYABLE SORTABLE,  -- Total views on user's recipes
activityCount       INT64 QUERYABLE SORTABLE,  -- Total activities
lastActivityAt      TIMESTAMP QUERYABLE SORTABLE, -- Last activity timestamp
joinedChallenges    INT64 QUERYABLE SORTABLE,  -- Number of challenges joined
completedChallenges INT64 QUERYABLE SORTABLE,  -- Number of challenges completed
teamMemberships     INT64 QUERYABLE SORTABLE,  -- Number of teams joined
achievementCount    INT64 QUERYABLE SORTABLE,  -- Total achievements earned
```

### Phase 3: Add Indexes for Performance

#### Recommended Indexes:
1. `User.username` - For username lookups
2. `User.followerCount` - For leaderboard queries
3. `User.recipesCreated` - For recipe count sorting
4. `User.totalPoints` - For gamification leaderboards
5. `Follow.followerID` + `Follow.followingID` - Composite for relationship queries
6. `Activity.targetUserID` + `Activity.timestamp` - For activity feeds
7. `Recipe.ownerID` + `Recipe.createdAt` - For user recipe lists

---

## APP CODE UPDATES REQUIRED

### 1. UnifiedAuthManager.swift
- Update `updateSocialCounts()` to use writable fields
- Ensure all queries use QUERYABLE fields only
- Update user stat updates to include new fields

### 2. CloudKitUser Model
- Add new fields to the model
- Update initialization to handle new fields
- Ensure backward compatibility

### 3. UserProfileView & UserProfileViewModel
- Use `recipesCreated` consistently (not `recipesShared`)
- Display new stats when available

### 4. Activity & Feed System
- Update to use `lastActivityAt` field
- Track `activityCount` for users

---

## FIELD MAPPING REFERENCE

### User Record - Primary Fields to Use:
```swift
// Social Stats
CKField.User.followerCount      // Number of followers
CKField.User.followingCount     // Number following
CKField.User.username           // Unique username
CKField.User.displayName        // Display name

// Recipe Stats  
CKField.User.recipesCreated     // Recipes created by user
CKField.User.recipeSaveCount    // NEW: Total saves
CKField.User.recipeLikeCount    // NEW: Total likes
CKField.User.recipeViewCount    // NEW: Total views

// Gamification
CKField.User.totalPoints        // Total points earned
CKField.User.currentStreak      // Current streak days
CKField.User.longestStreak      // Longest streak achieved
CKField.User.coinBalance        // Chef coins balance

// Challenges
CKField.User.challengesCompleted // Completed challenges (exists)
CKField.User.joinedChallenges    // NEW: Joined challenges
CKField.User.achievementCount    // NEW: Total achievements

// Activity
CKField.User.lastActiveAt       // Last active timestamp (exists)
CKField.User.lastActivityAt     // NEW: Last activity timestamp
CKField.User.activityCount      // NEW: Total activities

// Profile
CKField.User.bio                // User bio
CKField.User.profilePictureAsset // Profile image
CKField.User.isVerified         // Verification status
```

### Follow Record - Relationship Fields:
```swift
CKField.Follow.followerID       // Who is following (normalized ID)
CKField.Follow.followingID      // Who is being followed (normalized ID)
CKField.Follow.followedAt       // When relationship created
CKField.Follow.isActive         // 1 = active, 0 = unfollowed
```

### Activity Record - Feed Fields:
```swift
CKField.Activity.actorID        // User who performed action
CKField.Activity.targetUserID   // User affected by action
CKField.Activity.type           // Type of activity
CKField.Activity.timestamp      // When it happened
CKField.Activity.recipeID       // Related recipe (if any)
CKField.Activity.challengeID    // Related challenge (if any)
```

---

## MIGRATION STEPS

### Step 1: Update CloudKit Schema File
1. Fix field permissions in User record
2. Add new fields with proper permissions
3. Ensure all fields have correct QUERYABLE/SORTABLE flags

### Step 2: Deploy to CloudKit
1. Deploy to Development environment first
2. Test all queries and operations
3. Deploy to Production environment

### Step 3: Update App Code
1. Update CKField constants with new fields
2. Update all queries to use correct fields
3. Add migration code to populate new fields

### Step 4: Test Everything
1. Test social features (follow/unfollow)
2. Test recipe creation and stats
3. Test activity feeds
4. Test leaderboards and sorting

---

## PERMISSIONS MATRIX

### User Record Permissions:
| Field | Read | Write | Query | Sort | Index |
|-------|------|-------|-------|------|-------|
| followerCount | ✅ _world | ✅ _creator | ✅ | ✅ | ✅ |
| followingCount | ✅ _world | ✅ _creator | ✅ | ✅ | ✅ |
| recipesCreated | ✅ _world | ✅ _creator | ✅ | ✅ | ✅ |
| username | ✅ _world | ✅ _creator | ✅ | ✅ | ✅ |
| displayName | ✅ _world | ✅ _creator | ✅ | ✅ | - |

### Follow Record Permissions:
| Field | Read | Write | Query | Sort | Index |
|-------|------|-------|-------|------|-------|
| followerID | ✅ _world | ✅ _creator | ✅ | - | ✅ |
| followingID | ✅ _world | ✅ _creator | ✅ | - | ✅ |
| isActive | ✅ _world | ✅ _creator | ✅ | - | - |

---

## SUCCESS CRITERIA

1. ✅ All User fields are properly QUERYABLE and SORTABLE
2. ✅ Social counts can be updated by record creator
3. ✅ New statistics fields added for better analytics
4. ✅ App uses consistent field names throughout
5. ✅ No more "field not writable" errors
6. ✅ Queries perform efficiently with proper indexes

---

## NOTES

- UserProfile record type is DEPRECATED - do not use
- Users record type (note the 's') is also deprecated
- User record is the primary authentication record
- All new features should use User record fields only
- Backward compatibility maintained for existing data