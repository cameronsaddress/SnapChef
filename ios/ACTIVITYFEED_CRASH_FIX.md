# ActivityFeedView Crash Fix

## 🔴 CRITICAL ISSUE FOUND

The crash is happening in **ActivityFeedView** when it calls CloudKit operations that don't have double-resume protection.

### Crash Location
```
Thread 10: EXC_BREAKPOINT 
Queue: com.apple.cloudkit.operation.callback
```

### Root Causes Found

1. **CloudKitSyncService.fetchActivityFeed()** - Was still using direct CKQueryOperation without protection ✅ FIXED
2. **ActivityFeedView.fetchFollowedUserActivities()** - Uses `database.records(matching:)` directly ⚠️ NEEDS FIX
3. Multiple CloudKit operations running concurrently without proper isolation

## 🔧 FIXES APPLIED

### 1. Fixed fetchActivityFeed in CloudKitSyncService
Changed from direct CKQueryOperation to using CloudKitActor:
```swift
// OLD - CRASHES
return try await withCheckedThrowingContinuation { continuation in
    operation.queryResultBlock = { result in
        continuation.resume(...) // Could be called twice!
    }
}

// NEW - SAFE
let records = try await cloudKitActor.executeQuery(query, desiredKeys: nil, resultsLimit: limit)
```

### 2. Need to Fix fetchFollowedUserActivities
Current problematic code:
```swift
// Line 983 & 1017 - Direct database calls
let followRecords = try await database.records(matching: followingQuery)
let results = try await database.records(matching: activityQuery, resultsLimit: limit)
```

## 🚨 REMAINING FIXES NEEDED

### ActivityFeedView Line 983 & 1017
Replace direct database calls with CloudKitActor calls:

```swift
// Instead of:
let followRecords = try await database.records(matching: followingQuery)

// Use:
let followRecords = try await CloudKitSyncService.shared.cloudKitActor.executeQuery(followingQuery)
```

## 📊 CRASH PATTERN

1. SocialFeedView loads → triggers ActivityFeedView
2. ActivityFeedView.task starts → calls loadInitialActivities()
3. loadInitialActivities → fetchActivitiesFromCloudKit()
4. fetchActivitiesFromCloudKit calls two methods:
   - `cloudKitSync.fetchActivityFeed()` ✅ FIXED
   - `fetchFollowedUserActivities()` ⚠️ STILL BROKEN

## ✅ VERIFICATION CHECKLIST

- [x] CloudKitActor has double-resume protection
- [x] UnifiedAuthManager uses CloudKitActor
- [x] CloudKitSyncService.fetchActivityFeed uses CloudKitActor
- [ ] ActivityFeedView.fetchFollowedUserActivities needs CloudKitActor
- [ ] All direct `database.records(matching:)` calls removed

## 🎯 IMMEDIATE ACTION

The ActivityFeedView needs to be updated to use CloudKitActor for ALL CloudKit operations, not direct database calls.