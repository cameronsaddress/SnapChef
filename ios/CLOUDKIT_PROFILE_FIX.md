# CloudKit Profile Stats Fix - Deployment Guide

## Problem Summary
When viewing Tom's profile from sisaccount (or any user viewing another user's profile), the following stats show as 0:
- Recipes created
- Achievements earned  
- Challenges completed
- Total points
- Current streak
- Total likes
- Cooking time

Only follower/following counts work correctly.

## Root Cause
CloudKit record permissions were set to `GRANT READ TO "_creator"` for UserChallenge and Achievement records, meaning only the creator could read their own records. This prevented cross-account profile viewing from working.

## Solution Applied

### 1. CloudKit Schema Changes
**File**: `SnapChef_CloudKit_Schema.ckdb`

#### UserChallenge Record Type (Line 160)
- **Changed FROM**: `GRANT READ TO "_creator"`
- **Changed TO**: `GRANT READ TO "_world"`

#### Achievement Record Type (Line 244)
- **Changed FROM**: `GRANT READ TO "_creator"`
- **Changed TO**: `GRANT READ TO "_world"`

#### Recipe Record Type
- Already had correct permission: `GRANT READ TO "_world"` ✅

### 2. Debug Logging Added
Enhanced debug logging has been added to identify any remaining issues:

#### UserProfileViewModel.swift
- Added comprehensive logging to all data loading methods
- Shows exact userIDs being queried
- Logs predicates, results, and errors
- Tracks data flow through entire profile loading process

#### CloudKitRecipeManager.swift
- Added new `fetchRecipesForUser` method with full logging
- Enhanced all existing methods with debug output
- Shows database targeting (private vs public)
- Logs owner information for verification

## Deployment Instructions

### Step 1: Deploy CloudKit Schema Changes

1. **Open CloudKit Dashboard**
   - Go to https://icloud.developer.apple.com/
   - Select your SnapChef container

2. **Import Updated Schema**
   - Navigate to Schema → Deploy Schema Changes
   - Click "Import Schema from File"
   - Select the updated `SnapChef_CloudKit_Schema.ckdb` file
   - Review the changes (should show permission updates for UserChallenge and Achievement)

3. **Deploy to Development First**
   - Select "Development" environment
   - Click "Deploy Changes"
   - Wait for deployment to complete (usually ~1-2 minutes)

4. **Test in Development**
   - Build and run the app using Development environment
   - Sign in with two test accounts
   - Create some test data (recipes, challenges, achievements) with one account
   - View that user's profile from the other account
   - Verify all stats display correctly

5. **Deploy to Production**
   - Once verified in Development, go back to CloudKit Dashboard
   - Navigate to Schema → Deploy to Production
   - Select the changes to promote
   - Click "Deploy to Production"
   - Confirm the deployment

### Step 2: Monitor Debug Logs

After deployment, monitor the console logs when viewing profiles:

```
🔍 DEBUG UserProfile: Loading profile for userID: _d4b8018a9065711f8e9731b7c8c6d31f
🔍 DEBUG UserProfile: Loading recipes for userID: _d4b8018a9065711f8e9731b7c8c6d31f
🔍 DEBUG UserProfile: Predicate: ownerID == "_d4b8018a9065711f8e9731b7c8c6d31f"
✅ DEBUG UserProfile: Found 5 recipes
🔍 DEBUG UserProfile: Loading achievements for user...
✅ DEBUG UserProfile: Unlocked achievement: firstRecipe
✅ DEBUG UserProfile: Unlocked achievement: socialButterfly
```

### Step 3: Verify Data Access

Check that the following work correctly:

1. **Recipe Display**
   - User's created recipes appear in their profile
   - Recipe count is accurate
   - Recipe tiles are clickable and show details

2. **Achievement Display**
   - Earned achievements show as unlocked
   - Achievement badges display correctly
   - Achievement count is accurate

3. **Challenge Stats**
   - Challenges completed count is correct
   - Points earned from challenges display
   - Current streak shows if applicable

4. **Social Stats**
   - Total likes calculated from all user's recipes
   - Follower/following counts (already working)

### Step 4: Handle Edge Cases

If issues persist after deployment:

1. **Check UserID Format**
   - Debug logs will show if userIDs have unexpected format
   - Look for mismatches between profile userID and recipe ownerID

2. **Verify Record Migration**
   - Existing records may need time to propagate permission changes
   - CloudKit may cache permissions for up to 15 minutes

3. **Clear CloudKit Cache** (if needed)
   - In app, sign out and sign back in
   - This forces CloudKit to refresh cached permissions

## Rollback Plan

If issues occur after deployment:

1. **Revert Schema Changes**
   - Change permissions back to `GRANT READ TO "_creator"`
   - Deploy reverted schema to affected environment

2. **Alternative Solution**
   - Implement server-side API to fetch user stats
   - Use CloudKit functions to aggregate data server-side
   - Return aggregated stats to client

## Success Criteria

✅ Tom's recipes show when viewing his profile from sisaccount
✅ Tom's achievements display correctly
✅ Tom's challenge stats are visible
✅ Total points and streaks calculate properly
✅ No privacy issues - users can only read, not modify others' data

## Security Notes

- WRITE permissions remain restricted to "_creator" only
- Users cannot modify other users' achievements or challenges
- Read-only access maintains data integrity
- No sensitive personal data exposed

## Contact for Issues

If you encounter issues during deployment:
1. Check debug logs for specific error messages
2. Verify CloudKit Dashboard shows successful deployment
3. Ensure app is using correct CloudKit environment (Dev/Prod)
4. Check CloudKit Dashboard logs for query errors

## Timeline

- Schema changes: Immediate effect after deployment
- Permission propagation: Up to 15 minutes for full effect
- Client-side caching: May require app restart to see changes