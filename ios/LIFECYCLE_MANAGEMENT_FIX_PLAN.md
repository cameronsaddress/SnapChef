# Lifecycle Management & Memory Optimization - Holistic Approach

## Executive Summary

After comprehensive analysis of the current implementation, this plan outlines a **holistic memory-based lifecycle management system** that replaces time-based deletion with intelligent memory limits, implements batched loading for instant display, and ensures all systems work in harmony.

### Current Implementation Analysis:

**✅ Strong Foundations Found:**
- Batched user fetching in `ActivityFeedManager.batchFetchUsers()` (lines 1210-1254)  
- TTL-based caching in `UserCacheManager` with 30-minute expiry
- Memory management with `maxCacheSize = 100` in ActivityFeedManager
- Parallel loading with `async let` in multiple managers
- Smart refresh intervals preventing too-frequent updates

**❌ Key Issues to Address:**
1. **Time-based cleanup** conflicts with user experience (`clearStaleDataIfNeeded`)
2. **Large initial loads** without progressive display (25+ items at once)
3. **No "newest-only" refresh pattern** - always refetches everything
4. **Inconsistent memory limits** across managers (50, 100, 200 items)
5. **Task lifecycle conflicts** between concurrent operations

---

## New Requirements Implementation Plan

### 1. Memory-Based Limits (Replace Time-Based)

**Current State:**
```swift
// ActivityFeedManager (line 1348-1357)
func clearStaleDataIfNeeded() {
    if let cacheTimestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date,
       now.timeIntervalSince(cacheTimestamp) > 600 {
        activities.removeAll() // ❌ Clears all data based on time
        userCache.removeAll()
    }
}
```

**New Approach:**
```swift
// Keep ONLY 100 newest items, regardless of age
func maintainMemoryLimits() {
    if activities.count > MEMORY_LIMIT {
        let keepCount = MEMORY_LIMIT
        activities = Array(activities.sorted { $0.timestamp > $1.timestamp }.prefix(keepCount))
        print("🧹 Trimmed to \(keepCount) newest activities")
    }
}
```

### 2. Batched Loading System

**Current State:**
```swift
// ActivityFeedManager fetches 25+ items initially (line 1002-1027)
// All loaded at once with no progressive display
```

**New Approach:**
```swift
// Load 5 items FIRST for instant display, then rest in background
func loadWithBatchedStrategy() async {
    // INSTANT: Load first 5 activities 
    let firstBatch = await fetchActivities(limit: 5)
    activities = firstBatch
    showingSkeletonViews = false // ✅ Instant display
    
    // BACKGROUND: Load remaining 15 activities
    Task.detached {
        let remainingBatch = await fetchActivities(offset: 5, limit: 15)
        await MainActor.run {
            activities.append(contentsOf: remainingBatch)
        }
    }
}
```

### 3. Smart Refresh (Newest-Only)

**Current State:**
```swift
// Always refetches everything from scratch
let targetedActivities = try await cloudKitSync.fetchActivityFeed(for: userID, limit: 25)
```

**New Approach:**
```swift
// Only fetch items NEWER than cached data
func refreshNewestOnly() async {
    guard let latestTimestamp = activities.first?.timestamp else {
        return await loadInitialBatch() // No cache, load normally
    }
    
    // Fetch only activities newer than our latest cached item
    let newActivities = try await cloudKitSync.fetchActivityFeed(
        newerThan: latestTimestamp,
        limit: 25
    )
    
    if !newActivities.isEmpty {
        activities.insert(contentsOf: newActivities, at: 0) // Add to front
        maintainMemoryLimits() // Trim oldest if needed
    }
}
```

### 4. Unified Memory Management

**Current Inconsistencies:**
- ActivityFeedManager: `maxActivities = 50`, `maxCacheSize = 100`  
- DiscoverUsersManager: `maxCacheSize = 200`, `pageSize = 20`
- UserCacheManager: Cache limit of `100` users

**New Unified Standards:**
```swift
// Shared memory configuration
enum MemoryLimits {
    static let maxFeedItems = 100     // All feeds
    static let maxCachedUsers = 100   // All user caches  
    static let maxCachedRecipes = 50  // All recipe caches
    static let batchSize = 5          // Initial display batch
    static let backgroundBatch = 15   // Background load batch
}
```

---

## Current System Analysis

### 1. ActivityFeedManager - Strengths & Issues

**File:** `ActivityFeedView.swift` (Lines 725-1800)

**✅ Current Strengths:**
- **Parallel Fetching**: Uses `async let` for concurrent operations (lines 1001-1005)
- **Batch User Loading**: `batchFetchUsers()` efficiently caches users (lines 1210-1254)
- **Memory Limits**: Already has `maxActivities = 50` and `maxCacheSize = 100` (lines 747-748)
- **TTL Caching**: User cache with 30-minute TTL (line 745)
- **Smart Refresh**: Prevents refreshes more than once per 30 seconds (lines 836-842)

**❌ Issues Found:**
- **Time-Based Clearing**: `clearStaleDataIfNeeded()` (line 1348) removes useful cached data
- **Large Initial Load**: Fetches 25 items at once with no progressive display  
- **Full Refresh**: Always refetches everything instead of newest-only updates
- **Task Lifecycle**: No proper cancellation in background operations

### 2. DiscoverUsersManager - Implementation Analysis

**File:** `DiscoverUsersManager.swift` (Lines 1-530)

**✅ Current Strengths:**  
- **Batch Operations**: `batchCheckFollowStatus()` for efficient follow state checks (lines 172-215)
- **Parallel Processing**: Uses `async let` for concurrent user/follow data (lines 126-131)
- **Smart Caching**: TTL-based cache with background refresh (lines 328-351)
- **Memory Management**: Has memory warning handling (lines 56-87)

**❌ Issues Found:**
- **Inconsistent Limits**: `maxCacheSize = 200` vs ActivityFeedManager's 100
- **No Batched Display**: Loads full page (20 items) at once
- **Time-Based Logic**: Cache expiry based on time rather than memory pressure

### 3. UserCacheManager - Excellent Foundation

**File:** `UserCacheManager.swift` (Lines 1-272)

**✅ Strong Implementation:**
- **Batch Fetching**: `batchFetchUsers()` with proper error handling (lines 75-158)
- **Memory Limits**: Automatically trims cache to 100 entries (lines 261-269)
- **TTL Validation**: 30-minute cache with smart invalidation (lines 199-210)
- **Safe CloudKit Operations**: Uses CloudKitActor for all database access

**❌ Minor Issues:**
- Cache size limit (100) should be consistent across all managers
- No newest-first ordering for cache trimming

---

## Holistic Solution: Memory-First Architecture

### Core Philosophy

Replace all time-based management with **memory-based limits** + **newest-first prioritization** + **batched loading** for optimal user experience and system harmony.

### 1. Unified Memory Manager

**Create:** `/SnapChef/Core/Services/UnifiedMemoryManager.swift`

```swift
import Foundation

/// Centralized memory management for all app caches and feeds
@MainActor
final class UnifiedMemoryManager: ObservableObject {
    static let shared = UnifiedMemoryManager()
    
    // UNIFIED LIMITS: Same across entire app
    enum Limits {
        static let maxFeedItems = 100        // All feeds (Activity, Social, etc.)
        static let maxCachedUsers = 100      // User cache across all managers  
        static let maxCachedRecipes = 50     // Recipe caches
        static let initialBatchSize = 5      // First load for instant display
        static let backgroundBatchSize = 15  // Background load after initial
        static let loadMoreBatchSize = 10    // Pagination batch size
    }
    
    /// Trim any array to keep only newest N items
    func keepNewestItems<T: Timestamped>(_ items: [T], limit: Int) -> [T] {
        return Array(items.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
    
    /// Check if memory pressure exists and should trigger cleanup
    func shouldTrimMemory() -> Bool {
        // Could integrate with iOS memory pressure notifications
        return false // For now, only trim based on count limits
    }
}

protocol Timestamped {
    var timestamp: Date { get }
}

extension ActivityItem: Timestamped {}
```

### 2. Batched Loading Strategy

**Modify:** `ActivityFeedManager.loadInitialActivities()` (line 762)

```swift
func loadInitialActivities() async {
    guard !isLoading else { return }
    
    // PHASE 1: Load first 5 items for INSTANT display
    isLoading = true
    showingSkeletonViews = activities.isEmpty
    
    let firstBatch = await fetchActivitiesFromCloudKit(limit: Limits.initialBatchSize)
    activities = UnifiedMemoryManager.shared.keepNewestItems(firstBatch, limit: Limits.maxFeedItems)
    
    // Update UI immediately with first batch
    showingSkeletonViews = false
    
    // PHASE 2: Load remaining items in background
    if firstBatch.count == Limits.initialBatchSize {
        Task.detached { [weak self] in
            let backgroundBatch = await self?.fetchActivitiesFromCloudKit(
                offset: Limits.initialBatchSize, 
                limit: Limits.backgroundBatchSize
            ) ?? []
            
            await MainActor.run {
                self?.activities.append(contentsOf: backgroundBatch)
                self?.activities = UnifiedMemoryManager.shared.keepNewestItems(
                    self?.activities ?? [], 
                    limit: Limits.maxFeedItems
                )
            }
        }
    }
    
    isLoading = false
    await saveCachedActivities()
}
```

### 3. Smart Refresh (Newest-Only Pattern)

**Modify:** `ActivityFeedManager.refresh()` (line 834)

```swift
func refresh() async {
    // SMART REFRESH: Only fetch items newer than our newest cached item
    guard let newestTimestamp = activities.first?.timestamp else {
        // No cached data, do full initial load
        return await loadInitialActivities()
    }
    
    // Prevent too-frequent refreshes (keep current smart logic)
    if let lastRefresh = lastRefreshTime,
       Date().timeIntervalSince(lastRefresh) < minimumRefreshInterval {
        print("⚡ Smart refresh: Skipping (too recent)")
        return
    }
    
    isRefreshing = true
    defer { 
        isRefreshing = false
        lastRefreshTime = Date()
    }
    
    // Fetch only activities NEWER than our newest cached item
    let newActivities = await fetchNewerActivities(since: newestTimestamp)
    
    if !newActivities.isEmpty {
        // Insert new activities at the FRONT
        activities.insert(contentsOf: newActivities, at: 0)
        
        // Maintain memory limits (trim oldest)
        activities = UnifiedMemoryManager.shared.keepNewestItems(activities, limit: Limits.maxFeedItems)
        
        print("✅ Smart refresh: Added \(newActivities.count) new activities")
        await saveCachedActivities()
    } else {
        print("⚡ Smart refresh: No new activities")
    }
}

private func fetchNewerActivities(since timestamp: Date) async -> [ActivityItem] {
    // Modify CloudKit query to use timestamp filter
    // This requires updating CloudKitSyncService.fetchActivityFeed()
    // to accept a `newerThan: Date?` parameter
    return await fetchActivitiesFromCloudKit(newerThan: timestamp, limit: 25)
}
```

### 4. Remove Time-Based Clearing

**Replace:** `clearStaleDataIfNeeded()` methods across all managers

```swift
// ❌ REMOVE: All time-based clearing functions
func clearStaleDataIfNeeded() { /* DELETE THIS FUNCTION */ }

// ✅ REPLACE WITH: Memory-based maintenance  
func maintainMemoryLimits() {
    activities = UnifiedMemoryManager.shared.keepNewestItems(activities, limit: Limits.maxFeedItems)
    
    // Trim user cache to limit
    if userCache.count > Limits.maxCachedUsers {
        let sortedCache = userCache.sorted { $0.value.timestamp > $1.value.timestamp }
        userCache = Dictionary(uniqueKeysWithValues: Array(sortedCache.prefix(Limits.maxCachedUsers)))
    }
    
    print("🧹 Memory maintenance: \(activities.count) activities, \(userCache.count) cached users")
}
```

### 5. Task Lifecycle Coordination

**Create:** `/SnapChef/Core/Services/TaskCoordinator.swift`

```swift
import Foundation

/// Coordinates task lifecycle across all managers to prevent conflicts
@MainActor
final class TaskCoordinator: ObservableObject {
    static let shared = TaskCoordinator()
    
    private var activeTasks: [String: Task<Void, Never>] = [:]
    
    /// Execute a task with automatic lifecycle management
    func executeTask(
        id: String,
        operation: @escaping () async throws -> Void
    ) {
        // Cancel existing task with same ID
        cancelTask(id)
        
        // Start new task
        let task = Task {
            do {
                try await operation()
            } catch {
                print("❌ Task \(id) failed: \(error)")
            }
            activeTasks.removeValue(forKey: id)
        }
        
        activeTasks[id] = task
    }
    
    func cancelTask(_ id: String) {
        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)
    }
    
    func cancelAllTasks() {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
    }
}
```

### 6. Harmony Across All Systems

**Update:** App lifecycle management in `SnapChefApp.swift`

```swift
// ❌ REMOVE: All calls to clearStaleDataIfNeeded()
// ✅ REPLACE WITH: Memory maintenance

.onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
    // Instead of clearing data, just maintain memory limits
    Task {
        await ActivityFeedManager.shared.maintainMemoryLimits()
        await DiscoverUsersManager.shared.maintainMemoryLimits()
        // Keep data for fast return to app
    }
}

.onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
    // Only clear on actual app termination
    TaskCoordinator.shared.cancelAllTasks()
}
```

---

## Implementation Priority & Timeline

### Phase 1: Foundation (Week 1)
1. **Create UnifiedMemoryManager** with consistent limits
2. **Create TaskCoordinator** for lifecycle management  
3. **Remove all `clearStaleDataIfNeeded()` calls** from app lifecycle

### Phase 2: Batched Loading (Week 1-2)
4. **Implement batched loading** in ActivityFeedManager (5 + 15 pattern)
5. **Add smart refresh** (newest-only) to ActivityFeedManager
6. **Update DiscoverUsersManager** to use batched display

### Phase 3: CloudKit Updates (Week 2)
7. **Modify CloudKitSyncService.fetchActivityFeed()** to accept `newerThan: Date?` parameter
8. **Add offset/limit parameters** for proper pagination
9. **Test newest-only refresh pattern** thoroughly

### Phase 4: System Harmony (Week 3)
10. **Apply memory limits consistently** across all managers
11. **Integrate TaskCoordinator** in all async operations  
12. **Performance testing** and memory validation

### Phase 5: Polish & Validation (Week 3-4)  
13. **Add memory pressure monitoring** 
14. **Implement scroll-based loading** for infinite feeds
15. **Final testing** and documentation

---

## Success Metrics

### Performance Targets
- **⚡ First Screen Display**: < 500ms (5-item initial batch)
- **🧠 Memory Usage**: Stable at < 100MB with consistent limits
- **🔄 Refresh Speed**: Only fetch new items (not full reload)
- **📱 App Launch**: Use cached data immediately (no skeleton views if cached)

### User Experience Goals
- **Instant Content**: Show cached content immediately on app open
- **Smooth Loading**: Progressive display (5 items → 20 items → more)
- **Smart Updates**: Only show new content on refresh, never lose current position
- **No Jank**: All loading happens in background without UI blocking

### Technical Objectives
- **Memory Consistency**: All managers use same 100-item limits
- **Task Harmony**: No conflicting background operations
- **Cache Efficiency**: Keep newest 100 items regardless of age
- **Battery Optimization**: Reduce unnecessary network requests

---

## Code Changes Summary

**Files Modified:**
1. `/SnapChef/Core/Services/UnifiedMemoryManager.swift` (NEW)
2. `/SnapChef/Core/Services/TaskCoordinator.swift` (NEW) 
3. `ActivityFeedView.swift` - Update loading & refresh logic
4. `DiscoverUsersManager.swift` - Apply consistent memory limits
5. `UserCacheManager.swift` - Use unified limits
6. `SnapChefApp.swift` - Remove time-based clearing
7. `CloudKitSyncService.swift` - Add newest-only query support

**Key Functions Changed:**
- `loadInitialActivities()` → Batched loading (5+15)
- `refresh()` → Newest-only smart refresh
- `clearStaleDataIfNeeded()` → `maintainMemoryLimits()` (memory-based)
- All async operations → Use TaskCoordinator

**Backward Compatibility:** ✅ All changes are additive or replace broken patterns
**Risk Level:** 🟡 Medium (requires thorough testing of refresh patterns)  
**Implementation Time:** 3-4 weeks with testing

This holistic approach transforms the current time-based, conflicting system into a harmonious memory-first architecture that prioritizes user experience while maintaining excellent performance and battery life.