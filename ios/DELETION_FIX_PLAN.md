# Account Deletion Fix Plan

## Issues Found

### 1. CloudKit Query Failures (5 Errors)
- **User Record**: Predicate using `"user_\(userID)"` when it should use `userID` directly
- **Recipe Records**: Field `creatorUserRecordID` doesn't exist, should be `ownerID`
- **Follow Records**: Underscore in ID causing predicate parse errors
- **TeamMessage**: Field `senderID` not marked queryable in CloudKit schema
- **TeamInvite**: Same underscore ID parsing issue

### 2. Local Storage Issues
- **Recipes Still Visible**: LocalRecipeStorage not being cleared
- **Likes Still Showing**: RecipeLikeManager cache not cleared
- **SQLite Errors**: Database files deleted while still in use

### 3. Verification Failures
- Verification failing due to same predicate issues
- Not checking all relevant record types

## Fix Implementation

### Phase 1: Fix CloudKit Predicates

```swift
// AccountDeletionService.swift - Fix predicates

// OLD - WRONG:
("User", NSPredicate(format: "recordID.recordName == %@", "user_\(userID)"))

// NEW - CORRECT:
("User", NSPredicate(format: "recordID.recordName == %@", userID))

// OLD - WRONG:
("Recipe", NSPredicate(format: "creatorUserRecordID == %@", userID))

// NEW - CORRECT:
("Recipe", NSPredicate(format: "ownerID == %@", userID))

// OLD - PROBLEMATIC:
("Follow", NSPredicate(format: "followerID == %@ OR followingID == %@", userID, userID))

// NEW - HANDLE BOTH FORMATS:
let followPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
    NSPredicate(format: "followerID == %@", userID),
    NSPredicate(format: "followingID == %@", userID),
    NSPredicate(format: "followerID == %@", "user_\(userID)"),
    NSPredicate(format: "followingID == %@", "user_\(userID)")
])
```

### Phase 2: Add Missing Local Storage Cleanup

```swift
// Add to clearAllCacheManagers():

// Clear recipe-related storage
if let localRecipeStorage = try? LocalRecipeStorage.shared {
    localRecipeStorage.clearAllRecipes()
}

// Clear CloudKit recipe cache
CloudKitRecipeCache.shared.clearCache()

// Clear user cache
UserCacheManager.shared.clearCache()

// Clear recipe likes
RecipeLikeManager.shared.clearAllLikes()

// Clear saved recipe IDs from UserDefaults
UserDefaults.standard.removeObject(forKey: "savedRecipeIDs")
UserDefaults.standard.removeObject(forKey: "createdRecipeIDs")
UserDefaults.standard.removeObject(forKey: "likedRecipeIDs")
```

### Phase 3: Fix SQLite Database Issues

```swift
// Close databases before deletion:
private func closeActiveDatabases() {
    // Close any SDWebImage or other image cache databases
    SDImageCache.shared?.diskCache.removeAllData()
    
    // Give SQLite time to close
    Thread.sleep(forTimeInterval: 0.1)
}
```

### Phase 4: CloudKit Schema Updates

**Required CloudKit Dashboard Changes:**
1. Go to CloudKit Dashboard
2. Select SnapChef container
3. Edit TeamMessage record type
4. Mark `senderID` field as QUERYABLE
5. Save and deploy to production

### Phase 5: Enhanced Verification

```swift
private func verifyDeletion(userID: String) async -> Bool {
    // Check multiple record types to ensure complete deletion
    let recordTypesToVerify = [
        ("User", NSPredicate(format: "recordID.recordName == %@", userID)),
        ("Recipe", NSPredicate(format: "ownerID == %@", userID)),
        ("RecipeLike", NSPredicate(format: "userID == %@", userID)),
        ("Activity", NSPredicate(format: "actorID == %@", userID))
    ]
    
    for (recordType, predicate) in recordTypesToVerify {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        let records = try? await cloudKitActor.performQuery(query, in: database)
        
        if let records = records, !records.isEmpty {
            print("⚠️ Verification failed: \(records.count) \(recordType) records still exist")
            return false
        }
    }
    
    return true
}
```

## Implementation Order

1. **Fix CloudKit predicates** (5 minutes)
2. **Add local storage cleanup** (10 minutes)
3. **Fix SQLite issues** (5 minutes)
4. **Update CloudKit schema** (manual dashboard update)
5. **Test with fresh account** (15 minutes)

## Testing Plan

### Create Test Account
1. Sign up with new Apple ID
2. Create 5+ recipes
3. Like several recipes
4. Add comments
5. Follow other users

### Test Deletion
1. Run deletion with fixes
2. Verify progress shows all record types
3. Check deletion report for errors
4. Verify no recipes remain
5. Verify no likes remain
6. Check CloudKit dashboard for orphaned records

## Expected Results After Fix

- **0 errors** in deletion report
- **All recipes gone** from recipe book
- **All likes cleared**
- **Clean sign out** with no remaining data
- **Successful verification** showing 0 remaining records

## Fallback Options

If specific record types continue to fail:
1. **Null/Zero Strategy**: Set counts to 0 instead of deleting
2. **Soft Delete**: Mark records as deleted without removal
3. **Manual Cleanup**: Provide CloudKit dashboard instructions for manual deletion