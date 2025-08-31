# Social Feed Background Preload Implementation Plan

## Overview
The social feed (ActivityFeedView) currently takes too long to load because it creates a new ActivityFeedManager instance and fetches data when the view appears. This plan implements background preloading using a singleton pattern to make the feed load instantly.

## Current Problems
1. **New Instance Every Time**: ActivityFeedView creates a new ActivityFeedManager on each view appearance
2. **No Data Sharing**: Preloaded data in SnapChefApp.swift isn't used by the actual view
3. **Sequential Loading**: Users wait for CloudKit queries when opening the social tab
4. **5-Second Delay**: Current preload starts too late to be useful

## Solution Architecture
- Convert ActivityFeedManager to a singleton with shared instance
- Preload data immediately after authentication (2 seconds after app launch)
- Reuse the singleton instance in ActivityFeedView
- Maintain all existing functionality and optimizations

## Implementation Phases

### Phase 1: Convert ActivityFeedManager to Singleton Pattern
**Goal**: Create a shared instance that can be used across the app

#### Step 1.1: Add Singleton Instance to ActivityFeedManager
**File**: `SnapChef/Features/Sharing/ActivityFeedView.swift`
**Line**: After line 714 (before class definition)

```swift
// MARK: - Activity Feed Manager
@MainActor
class ActivityFeedManager: ObservableObject {
    // SINGLETON: Shared instance for background preloading
    static let shared = ActivityFeedManager()
    
    @Published var activities: [ActivityItem] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var showingSkeletonViews = false
    
    // Rest of existing properties...
```

#### Step 1.2: Make Initializer Public (if needed)
**Line**: Around line 720, ensure init is accessible

```swift
    // Allow both singleton and instance creation for flexibility
    init() {
        // Existing initialization if any
    }
```

#### Step 1.3: Build Test
```bash
cd /Users/cameronanderson/SnapChef/snapchef/ios
xcodebuild -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Debug build 2>&1 | grep -E "(error:|warning:|FAILED|SUCCEEDED)"
```

### Phase 2: Update ActivityFeedView to Use Singleton
**Goal**: Use the shared preloaded instance instead of creating new one

#### Step 2.1: Modify ActivityFeedView StateObject
**File**: `SnapChef/Features/Sharing/ActivityFeedView.swift`
**Line**: Around line 147-151

**BEFORE**:
```swift
struct ActivityFeedView: View {
    @StateObject private var feedManager = {
        print("🔍 DEBUG: Creating ActivityFeedManager")
        return ActivityFeedManager()
    }()
```

**AFTER**:
```swift
struct ActivityFeedView: View {
    // Use shared singleton instance for preloaded data
    @StateObject private var feedManager = {
        print("🔍 DEBUG: Using shared ActivityFeedManager singleton")
        return ActivityFeedManager.shared
    }()
```

#### Step 2.2: Add Refresh Logic for Tab Switches
**Line**: Around line 301-306 in onAppear

**BEFORE**:
```swift
.onAppear {
    print("🔍 DEBUG: ActivityFeedView appeared - Start")
    DispatchQueue.main.async {
        print("🔍 DEBUG: ActivityFeedView - Async block started")
        // No state modifications here, just logging
        print("🔍 DEBUG: ActivityFeedView - Async block completed")
    }
    print("🔍 DEBUG: ActivityFeedView appeared - End")
}
```

**AFTER**:
```swift
.onAppear {
    print("🔍 DEBUG: ActivityFeedView appeared - Start")
    
    // Smart refresh: Only if data is stale or empty
    Task {
        // Check if we need to refresh (data older than 5 minutes or empty)
        let shouldRefresh = feedManager.activities.isEmpty || 
                          feedManager.needsRefresh()
        
        if shouldRefresh {
            print("📱 ActivityFeedView: Data stale or empty, refreshing...")
            await feedManager.refresh()
        } else {
            print("✅ ActivityFeedView: Using cached data (\(feedManager.activities.count) items)")
        }
    }
    
    print("🔍 DEBUG: ActivityFeedView appeared - End")
}
```

#### Step 2.3: Add Helper Method to Check Staleness
**File**: `SnapChef/Features/Sharing/ActivityFeedView.swift`
**Line**: After line 844 (in ActivityFeedManager, after refresh method)

```swift
    // Helper to check if data needs refresh
    func needsRefresh() -> Bool {
        // Check if cache is older than 5 minutes
        if let cacheTimestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date {
            let cacheAge = Date().timeIntervalSince(cacheTimestamp)
            return cacheAge > 300 // 5 minutes
        }
        return true // No cache timestamp means we need to refresh
    }
```

#### Step 2.4: Build Test
```bash
xcodebuild -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Debug build 2>&1 | grep -E "(error:|warning:|FAILED|SUCCEEDED)"
```

### Phase 3: Optimize Preload Timing in App Startup
**Goal**: Start preloading earlier and more efficiently

#### Step 3.1: Update SnapChefApp Preload Logic
**File**: `SnapChef/App/SnapChefApp.swift`
**Line**: Replace lines 92-99

**BEFORE**:
```swift
// Preload social feed after 5 seconds if authenticated
Task {
    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
    if UnifiedAuthManager.shared.isAuthenticated {
        print("🚀 Starting background social feed preload...")
        await ActivityFeedManager().preloadInBackground()
    }
}
```

**AFTER**:
```swift
// Preload social feed after 2 seconds if authenticated
// Using shared singleton to ensure data is available to views
Task { @MainActor in
    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    
    // Check authentication status
    if UnifiedAuthManager.shared.isAuthenticated {
        print("🚀 Starting background social feed preload...")
        print("   - User authenticated: ✓")
        print("   - Preloading into shared singleton instance")
        
        // Use the shared singleton instance
        await ActivityFeedManager.shared.preloadInBackground()
        
        print("✅ Social feed preload complete")
        print("   - Activities loaded: \(ActivityFeedManager.shared.activities.count)")
    } else {
        print("⏸️ Skipping social feed preload - user not authenticated")
    }
}
```

#### Step 3.2: Build Test
```bash
xcodebuild -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Debug build 2>&1 | grep -E "(error:|warning:|FAILED|SUCCEEDED)"
```

### Phase 4: Enhance Preload Method for Better Performance
**Goal**: Improve the preloadInBackground method to be more efficient

#### Step 4.1: Update preloadInBackground Method
**File**: `SnapChef/Features/Sharing/ActivityFeedView.swift`
**Line**: Replace lines 847-867 (preloadInBackground method)

**BEFORE**:
```swift
/// Preload feed data in background without blocking UI
func preloadInBackground() async {
    // Only preload if not already loading and no data exists
    guard !isLoading && activities.isEmpty else { 
        print("📱 Preload skipped - already loading or has data")
        return 
    }
    
    print("📱 Starting background preload of social feed...")
    
    // Don't show loading indicators for background fetch
    let originalShowingSkeleton = showingSkeletonViews
    showingSkeletonViews = false
    
    // Fetch without updating loading state
    await fetchActivitiesFromCloudKit()
    
    // Restore skeleton state
    showingSkeletonViews = originalShowingSkeleton
    
    print("✅ Background preload complete - \(activities.count) activities loaded")
}
```

**AFTER**:
```swift
/// Preload feed data in background without blocking UI
func preloadInBackground() async {
    // Check if we already have fresh data
    if !activities.isEmpty && !needsRefresh() {
        print("📱 Preload skipped - already have fresh data (\(activities.count) items)")
        return
    }
    
    // Only preload if not already loading
    guard !isLoading else { 
        print("📱 Preload skipped - already loading")
        return 
    }
    
    print("📱 Starting background preload of social feed...")
    print("   - Current activities: \(activities.count)")
    print("   - Cache status: \(needsRefresh() ? "stale" : "fresh")")
    
    // Don't show loading indicators for background fetch
    let originalShowingSkeleton = showingSkeletonViews
    let originalIsLoading = isLoading
    
    showingSkeletonViews = false
    // Don't set isLoading to prevent UI updates
    
    // Try to load from cache first
    await loadCachedActivities()
    
    // If cache is empty or stale, fetch from CloudKit
    if activities.isEmpty || needsRefresh() {
        print("📱 Cache miss or stale - fetching from CloudKit...")
        await fetchActivitiesFromCloudKit()
    } else {
        print("✅ Using cached data - \(activities.count) activities")
    }
    
    // Restore original states
    showingSkeletonViews = originalShowingSkeleton
    isLoading = originalIsLoading
    
    print("✅ Background preload complete")
    print("   - Activities loaded: \(activities.count)")
    print("   - Memory usage: \(userCache.count) cached users")
}
```

#### Step 4.2: Build Test
```bash
xcodebuild -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Debug build 2>&1 | grep -E "(error:|warning:|FAILED|SUCCEEDED)"
```

### Phase 5: Add Smart Memory Management
**Goal**: Ensure singleton doesn't consume too much memory

#### Step 5.1: Add Lifecycle Management
**File**: `SnapChef/Features/Sharing/ActivityFeedView.swift`
**Line**: After line 1296 (after cleanupMemory method)

```swift
    // MARK: - Singleton Lifecycle Management
    
    /// Clear old data when app goes to background
    func clearStaleDataIfNeeded() {
        let now = Date()
        
        // If data is older than 10 minutes, clear it to save memory
        if let cacheTimestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date,
           now.timeIntervalSince(cacheTimestamp) > 600 {
            print("🧹 Clearing stale activity data (>10 minutes old)")
            activities.removeAll()
            userCache.removeAll()
        }
    }
    
    /// Reset singleton for testing or logout
    func reset() {
        print("🔄 Resetting ActivityFeedManager singleton")
        activities.removeAll()
        userCache.removeAll()
        lastFetchedRecord = nil
        hasMore = true
        isLoading = false
        showingSkeletonViews = false
        lastRefreshTime = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
    }
```

#### Step 5.2: Add Background/Foreground Handling
**File**: `SnapChef/App/SnapChefApp.swift`
**Line**: After line 72 (add new notification observers)

```swift
.onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
    // Clean up stale data when going to background
    ActivityFeedManager.shared.clearStaleDataIfNeeded()
}
.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
    Task { @MainActor in
        // Preload fresh data when coming to foreground
        if UnifiedAuthManager.shared.isAuthenticated {
            await ActivityFeedManager.shared.preloadInBackground()
        }
    }
}
```

#### Step 5.3: Build Test
```bash
xcodebuild -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Debug build 2>&1 | grep -E "(error:|warning:|FAILED|SUCCEEDED)"
```

### Phase 6: Handle Authentication Changes
**Goal**: Reset and reload when user logs in/out

#### Step 6.1: Add Auth State Observer
**File**: `SnapChef/App/SnapChefApp.swift`
**Line**: In setupApp method, after line 193

```swift
// Monitor authentication changes for social feed
Task { @MainActor in
    // Observe auth state changes
    NotificationCenter.default.publisher(for: NSNotification.Name("UserDidAuthenticate"))
        .sink { _ in
            Task {
                print("🔄 User authenticated - preloading social feed...")
                await ActivityFeedManager.shared.reset()
                await ActivityFeedManager.shared.preloadInBackground()
            }
        }
        .store(in: &cancellables)
    
    NotificationCenter.default.publisher(for: NSNotification.Name("UserDidSignOut"))
        .sink { _ in
            print("🔄 User signed out - clearing social feed...")
            ActivityFeedManager.shared.reset()
        }
        .store(in: &cancellables)
}
```

Note: You'll need to add `@State private var cancellables = Set<AnyCancellable>()` at the top of SnapChefApp if not already present.

#### Step 6.2: Build Test
```bash
xcodebuild -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Debug build 2>&1 | grep -E "(error:|warning:|FAILED|SUCCEEDED)"
```

## Testing Plan

### Manual Testing Steps
1. **Cold Start Test**
   - Kill app completely
   - Launch app
   - Wait 3 seconds
   - Navigate to Social tab
   - **Expected**: Feed loads instantly with data

2. **Tab Switch Test**
   - Open Social tab (loads data)
   - Switch to another tab
   - Return to Social tab
   - **Expected**: Instant load, no refresh

3. **Pull to Refresh Test**
   - Open Social tab
   - Pull down to refresh
   - **Expected**: Smooth refresh with new data

4. **Background/Foreground Test**
   - Open Social tab
   - Send app to background
   - Wait 30 seconds
   - Return to app
   - **Expected**: Fresh data loads automatically

5. **Memory Test**
   - Open Social tab
   - Switch tabs multiple times
   - Check memory usage in Xcode
   - **Expected**: Stable memory, no leaks

### Performance Metrics to Track
- **Initial Load Time**: Should be <100ms with preloaded data
- **Memory Usage**: Should stay under 50MB for feed data
- **Cache Hit Rate**: Should be >80% for tab switches
- **Network Calls**: Reduced by 90% for repeat visits

## Rollback Plan
If issues occur, revert changes in this order:
1. Change ActivityFeedView back to creating new instance
2. Remove singleton pattern from ActivityFeedManager
3. Remove preload call from SnapChefApp

## Code Organization Summary

### Files Modified
1. **ActivityFeedView.swift**
   - Add singleton instance
   - Add needsRefresh() method
   - Update preloadInBackground()
   - Add lifecycle management methods

2. **SnapChefApp.swift**
   - Update preload timing (2 seconds)
   - Use singleton instance
   - Add background/foreground handlers
   - Add auth state observers

### No New Files Created
All changes are modifications to existing files only.

## Implementation Checklist

- [ ] Phase 1: Add singleton to ActivityFeedManager
- [ ] Phase 1: Build test passes
- [ ] Phase 2: Update ActivityFeedView to use singleton
- [ ] Phase 2: Add needsRefresh() method
- [ ] Phase 2: Build test passes
- [ ] Phase 3: Update preload timing in SnapChefApp
- [ ] Phase 3: Build test passes
- [ ] Phase 4: Enhance preloadInBackground method
- [ ] Phase 4: Build test passes
- [ ] Phase 5: Add memory management methods
- [ ] Phase 5: Add background/foreground handlers
- [ ] Phase 5: Build test passes
- [ ] Phase 6: Add auth state observers
- [ ] Phase 6: Build test passes
- [ ] Manual testing completed
- [ ] Performance metrics verified

## Expected Results
- **95% reduction** in social feed initial load time
- **Instant load** when switching tabs
- **Smart caching** prevents unnecessary network calls
- **Memory efficient** with automatic cleanup
- **Maintains all existing functionality**

## Notes
- All existing functionality is preserved
- No breaking changes to UI or UX
- Backward compatible with existing data
- Progressive enhancement approach