# CloudKit Schema Deployment Instructions

## Date: August 24, 2025
## Schema Version: 4.0

---

## WHAT'S BEEN UPDATED

### CloudKit Schema File (SnapChef_CloudKit_Schema.ckdb)
✅ Fixed field permissions for existing fields
✅ Added 9 new fields to User record type
✅ All fields now have proper QUERYABLE and SORTABLE flags

### App Code (CloudKitSchema.swift)
✅ Updated CKField.User struct with all new fields
✅ Added documentation for v4.0 changes
✅ Organized fields into logical groups

---

## HOW TO DEPLOY TO CLOUDKIT

### Step 1: Deploy to Development Environment

1. Open CloudKit Dashboard: https://icloud.developer.apple.com
2. Select your container: `iCloud.com.snapchefapp.app`
3. Choose **Development** environment
4. Navigate to **Schema** → **Record Types**

### Step 2: Update User Record Type

For the **User** record type, update these existing fields:

| Field | Change Required |
|-------|----------------|
| followingCount | Add QUERYABLE and SORTABLE |
| recipesCreated | Add SORTABLE |
| recipesShared | Add QUERYABLE |
| challengesCompleted | Add QUERYABLE and SORTABLE |

### Step 3: Add New Fields to User Record

Add these new fields to the User record type:

| Field Name | Type | Flags | Index |
|------------|------|-------|-------|
| recipeSaveCount | INT64 | QUERYABLE, SORTABLE | Yes |
| recipeLikeCount | INT64 | QUERYABLE, SORTABLE | Yes |
| recipeViewCount | INT64 | QUERYABLE, SORTABLE | Yes |
| activityCount | INT64 | QUERYABLE, SORTABLE | No |
| lastActivityAt | TIMESTAMP | QUERYABLE, SORTABLE | Yes |
| joinedChallenges | INT64 | QUERYABLE, SORTABLE | No |
| completedChallenges | INT64 | QUERYABLE, SORTABLE | No |
| teamMemberships | INT64 | QUERYABLE, SORTABLE | No |
| achievementCount | INT64 | QUERYABLE, SORTABLE | No |

### Step 4: Create Indexes

Add these indexes for performance:

1. **User.username** - Single field index
2. **User.followerCount** - Single field index (if not exists)
3. **User.recipesCreated** - Single field index
4. **User.lastActivityAt** - Single field index
5. **Follow** - Composite index on (followerID, followingID)

### Step 5: Save and Deploy to Development

1. Click **Save** to save schema changes
2. Test the app with Development environment
3. Verify all queries work correctly

### Step 6: Deploy to Production

Once tested in Development:

1. Switch to **Production** environment
2. Click **Deploy Schema Changes**
3. Select changes to deploy from Development
4. Click **Deploy to Production**
5. Wait for deployment to complete (may take a few minutes)

---

## POST-DEPLOYMENT VERIFICATION

### Test These Operations:

1. **Social Features**
   - Follow/unfollow a user
   - Check follower/following counts update
   - Verify counts are queryable and sortable

2. **Recipe Features**
   - Create a recipe
   - Check recipesCreated count increments
   - Like/save recipes and verify new count fields

3. **Activity Tracking**
   - Perform any activity
   - Check activityCount and lastActivityAt update

4. **Queries to Test**
   ```swift
   // Test sorting by new fields
   let query = CKQuery(recordType: "User", 
                       predicate: NSPredicate(value: true))
   query.sortDescriptors = [
       NSSortDescriptor(key: "followingCount", ascending: false),
       NSSortDescriptor(key: "recipesCreated", ascending: false)
   ]
   ```

---

## ROLLBACK PLAN

If issues occur after deployment:

1. **In CloudKit Dashboard**: Previous schema versions are maintained
2. **In App Code**: The app is backward compatible - new fields are optional
3. **Migration**: No data migration needed - new fields will be populated over time

---

## MONITORING

After deployment, monitor:

1. CloudKit Dashboard for any errors
2. App analytics for crash reports
3. User feedback for any issues

---

## NOTES

- All new fields are optional and won't break existing functionality
- The app will gracefully handle missing fields
- New fields will be populated as users interact with the app
- No immediate data migration is required

---

## SUCCESS CRITERIA

✅ All queries execute without errors
✅ Social counts update correctly
✅ New fields are writable by record creators
✅ Sorting works on all SORTABLE fields
✅ No performance degradation

---

## SUPPORT

If you encounter issues:
1. Check CloudKit Dashboard error logs
2. Verify field permissions match this document
3. Ensure indexes are created
4. Test with a clean app install