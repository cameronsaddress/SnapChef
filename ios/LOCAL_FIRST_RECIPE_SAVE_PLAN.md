# 📱 LOCAL-FIRST Recipe Save/Unsave Implementation Plan

## Overview
Transform recipe save/unsave to be LOCAL-FIRST with instant UI updates and background CloudKit sync.

**Core Principle:** Local storage provides instant feedback, CloudKit syncs in background for backup/sharing.

---

## 📋 Task List

### Phase 1: Local Storage Infrastructure

#### ✅ Task 1.1: Create LocalRecipeStorage Manager
**File:** `SnapChef/Core/Storage/LocalRecipeStorage.swift` (NEW)
**Integration:** Will replace direct CloudKit calls in RecipeResultsView

```swift
import Foundation
import SwiftUI

class LocalRecipeStorage: ObservableObject {
    static let shared = LocalRecipeStorage()
    
    // UserDefaults keys
    private let savedRecipeIdsKey = "saved_recipe_ids_v2"
    private let createdRecipeIdsKey = "created_recipe_ids_v2"
    
    // Published for UI updates
    @Published var savedRecipeIds: Set<String> = []
    @Published var createdRecipeIds: Set<String> = []
    
    // File storage
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var recipesDirectory: URL { 
        documentsDirectory.appendingPathComponent("recipes")
    }
    
    init() {
        loadFromUserDefaults()
        createRecipesDirectoryIfNeeded()
    }
    
    private func loadFromUserDefaults() {
        if let savedIds = UserDefaults.standard.array(forKey: savedRecipeIdsKey) as? [String] {
            savedRecipeIds = Set(savedIds)
        }
        if let createdIds = UserDefaults.standard.array(forKey: createdRecipeIdsKey) as? [String] {
            createdRecipeIds = Set(createdIds)
        }
    }
    
    private func createRecipesDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: recipesDirectory, withIntermediateDirectories: true)
    }
    
    // INSTANT save operation
    func saveRecipe(_ recipe: Recipe, capturedImage: UIImage? = nil) {
        // 1. Update local state
        savedRecipeIds.insert(recipe.id.uuidString)
        persistToUserDefaults()
        
        // 2. Save to file system
        saveRecipeToFile(recipe)
        
        // 3. Store photo if provided
        if let image = capturedImage {
            PhotoStorageManager.shared.storePhotos(
                fridgePhoto: image,
                mealPhoto: nil,
                for: recipe.id
            )
        }
        
        // 4. Queue for background sync
        RecipeSyncQueue.shared.queueSave(recipe, beforePhoto: capturedImage)
    }
    
    // INSTANT unsave operation
    func unsaveRecipe(_ recipeId: UUID) {
        // 1. Update local state
        savedRecipeIds.remove(recipeId.uuidString)
        persistToUserDefaults()
        
        // 2. Remove photos
        PhotoStorageManager.shared.removePhotos(for: [recipeId])
        
        // 3. Queue for background sync
        RecipeSyncQueue.shared.queueUnsave(recipeId)
    }
    
    func isRecipeSaved(_ recipeId: UUID) -> Bool {
        return savedRecipeIds.contains(recipeId.uuidString)
    }
    
    private func persistToUserDefaults() {
        UserDefaults.standard.set(Array(savedRecipeIds), forKey: savedRecipeIdsKey)
        UserDefaults.standard.set(Array(createdRecipeIds), forKey: createdRecipeIdsKey)
    }
    
    private func saveRecipeToFile(_ recipe: Recipe) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(recipe) {
            let fileURL = recipesDirectory.appendingPathComponent("\(recipe.id.uuidString).json")
            try? data.write(to: fileURL)
        }
    }
}
```

---

#### ✅ Task 1.2: Create Recipe Sync Queue
**File:** `SnapChef/Core/Services/RecipeSyncQueue.swift` (NEW)
**Integration:** Uses existing CloudKitRecipeManager and CloudKitSyncService

```swift
import Foundation
import Combine

class RecipeSyncQueue: ObservableObject {
    static let shared = RecipeSyncQueue()
    
    private var pendingOperations: [SyncOperation] = []
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 5.0
    private var cancellables = Set<AnyCancellable>()
    
    enum SyncOperation: Codable {
        case save(recipeId: String, beforePhotoPath: String?)
        case unsave(recipeId: String)
        case update(recipeId: String)
    }
    
    init() {
        // Listen for network changes
        NotificationCenter.default.publisher(for: .networkStatusChanged)
            .sink { _ in
                self.processPendingIfConnected()
            }
            .store(in: &cancellables)
    }
    
    func queueSave(_ recipe: Recipe, beforePhoto: UIImage?) {
        // Save photo locally first if provided
        var photoPath: String? = nil
        if let photo = beforePhoto {
            photoPath = savePhotoLocally(photo, recipeId: recipe.id)
        }
        
        pendingOperations.append(.save(recipeId: recipe.id.uuidString, beforePhotoPath: photoPath))
        startSyncTimer()
    }
    
    func queueUnsave(_ recipeId: UUID) {
        pendingOperations.append(.unsave(recipeId: recipeId.uuidString))
        startSyncTimer()
    }
    
    private func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: false) { _ in
            Task { await self.processBatch() }
        }
    }
    
    @MainActor
    private func processBatch() async {
        guard !pendingOperations.isEmpty else { return }
        
        let batch = pendingOperations
        pendingOperations.removeAll()
        
        for operation in batch {
            await processOperation(operation)
        }
    }
    
    private func processOperation(_ operation: SyncOperation) async {
        switch operation {
        case .save(let recipeId, let photoPath):
            await syncSaveToCloudKit(recipeId: recipeId, photoPath: photoPath)
        case .unsave(let recipeId):
            await syncUnsaveToCloudKit(recipeId: recipeId)
        case .update(let recipeId):
            await syncUpdateToCloudKit(recipeId: recipeId)
        }
    }
    
    private func syncSaveToCloudKit(recipeId: String, photoPath: String?) async {
        do {
            // Load photo if path exists
            var beforePhoto: UIImage? = nil
            if let path = photoPath {
                beforePhoto = loadPhotoFromPath(path)
            }
            
            // Check if recipe exists in CloudKit
            let exists = await CloudKitRecipeManager.shared.checkRecipeExists(recipeId)
            
            if !exists {
                // Need to load recipe from local storage
                if let recipe = loadRecipeFromFile(recipeId) {
                    _ = try await CloudKitRecipeManager.shared.uploadRecipe(
                        recipe,
                        fromLLM: false,
                        beforePhoto: beforePhoto
                    )
                }
            }
            
            // Mark as saved for user
            try await CloudKitRecipeManager.shared.addRecipeToUserProfile(recipeId, type: .saved)
            
        } catch {
            // Add to persistent queue for retry
            PersistentSyncQueue.shared.addFailedOperation(operation)
        }
    }
    
    private func syncUnsaveToCloudKit(recipeId: String) async {
        do {
            try await CloudKitRecipeManager.shared.removeRecipeFromUserProfile(recipeId, type: .saved)
        } catch {
            PersistentSyncQueue.shared.addFailedOperation(.unsave(recipeId: recipeId))
        }
    }
}
```

---

### Phase 2: Update UI Layer

#### ✅ Task 2.1: Refactor RecipeResultsView Save Logic
**File:** `SnapChef/Features/Recipes/RecipeResultsView.swift`
**Changes:** Replace complex save logic with simple local-first approach

```swift
// REPLACE the existing saveRecipe function with:
private func saveRecipe(_ recipe: Recipe) {
    // Check authentication first
    guard authManager.isAuthenticated else {
        pendingAction = .save(recipe)
        showAuthPrompt = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        return
    }
    
    // INSTANT local update
    let localStorage = LocalRecipeStorage.shared
    let currentlySaved = localStorage.isRecipeSaved(recipe.id)
    
    // Toggle state
    if currentlySaved {
        // UNSAVE
        print("🔍 DEBUG: Unsaving recipe '\(recipe.name)' locally")
        
        // 1. Update UI state immediately
        savedRecipeIds.remove(recipe.id)
        
        // 2. Update local storage (instant)
        localStorage.unsaveRecipe(recipe.id)
        
        // 3. Update AppState for other views
        appState.savedRecipes.removeAll { $0.id == recipe.id }
        appState.recentRecipes.removeAll { $0.id == recipe.id }
        
    } else {
        // SAVE
        print("🔍 DEBUG: Saving recipe '\(recipe.name)' locally")
        
        // 1. Update UI state immediately
        savedRecipeIds.insert(recipe.id)
        
        // 2. Update local storage (instant)
        localStorage.saveRecipe(recipe, capturedImage: capturedImage)
        
        // 3. Update AppState for other views
        if !appState.savedRecipes.contains(where: { $0.id == recipe.id }) {
            appState.savedRecipes.append(recipe)
            appState.addRecentRecipe(recipe)
        }
    }
    
    // 4. Haptic feedback
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    
    // CloudKit sync happens automatically via RecipeSyncQueue
}

// REPLACE the onAppear initialization with:
.onAppear {
    let localStorage = LocalRecipeStorage.shared
    
    // Initialize from local storage (instant)
    for recipe in recipes {
        if localStorage.isRecipeSaved(recipe.id) {
            savedRecipeIds.insert(recipe.id)
        }
    }
    
    print("🔍 DEBUG: Initialized \(savedRecipeIds.count) saved recipes from local storage")
    startAnimations()
}
```

---

#### ✅ Task 2.2: Update DetectiveRecipeCard
**File:** `SnapChef/Features/Recipes/RecipeResultsView.swift`
**Changes:** Ensure button shows correct saved state from local storage

```swift
// In DetectiveRecipeCard, ensure the save button reflects local state:
Button(action: onSave) {
    HStack(spacing: 8) {
        Image(systemName: isAuthenticated ? 
              (isSaved ? "heart.fill" : "heart") : 
              "lock.fill")
        Text(isAuthenticated ? 
             (isSaved ? "Saved" : "Save") : 
             "Sign In to Save")
    }
    // ... rest of button styling
}
// No changes needed here - parent view passes correct isSaved state
```

---

### Phase 3: Background Sync Integration

#### ✅ Task 3.1: Create Persistent Sync Queue
**File:** `SnapChef/Core/Services/PersistentSyncQueue.swift` (NEW)
**Purpose:** Store failed sync operations for retry on next app launch

```swift
import Foundation

class PersistentSyncQueue {
    static let shared = PersistentSyncQueue()
    private let failedOperationsKey = "failed_sync_operations_v1"
    
    func addFailedOperation(_ operation: RecipeSyncQueue.SyncOperation) {
        var operations = getFailedOperations()
        operations.append(operation)
        
        // Encode and save
        if let data = try? JSONEncoder().encode(operations) {
            UserDefaults.standard.set(data, forKey: failedOperationsKey)
        }
    }
    
    func getFailedOperations() -> [RecipeSyncQueue.SyncOperation] {
        guard let data = UserDefaults.standard.data(forKey: failedOperationsKey),
              let operations = try? JSONDecoder().decode([RecipeSyncQueue.SyncOperation].self, from: data) else {
            return []
        }
        return operations
    }
    
    func retryAllFailedOperations() {
        let operations = getFailedOperations()
        for operation in operations {
            RecipeSyncQueue.shared.requeue(operation)
        }
        clearFailedOperations()
    }
    
    func clearFailedOperations() {
        UserDefaults.standard.removeObject(forKey: failedOperationsKey)
    }
}
```

---

#### ✅ Task 3.2: Add Network Monitoring
**File:** `SnapChef/Core/Services/NetworkMonitor.swift` (Already exists)
**Changes:** Ensure it triggers sync queue on reconnection

```swift
// Add to NetworkMonitor if not already present:
extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

// In NetworkMonitor's pathUpdateHandler:
if path.status == .satisfied && !wasConnected {
    // Connection restored
    NotificationCenter.default.post(name: .networkStatusChanged, object: nil)
    
    // Retry failed syncs
    PersistentSyncQueue.shared.retryAllFailedOperations()
}
```

---

### Phase 4: AppState Integration

#### ✅ Task 4.1: Update AppState Methods
**File:** `SnapChef/Core/ViewModels/AppState.swift`
**Changes:** Add methods that work with LocalRecipeStorage

```swift
// Add these methods to AppState:
func syncWithLocalStorage() {
    let localStorage = LocalRecipeStorage.shared
    
    // Update savedRecipes from local storage
    savedRecipes = savedRecipes.filter { recipe in
        localStorage.isRecipeSaved(recipe.id)
    }
}

func addToSaved(_ recipe: Recipe) {
    if !savedRecipes.contains(where: { $0.id == recipe.id }) {
        savedRecipes.append(recipe)
        LocalRecipeStorage.shared.saveRecipe(recipe)
    }
}

func removeFromSaved(_ recipe: Recipe) {
    savedRecipes.removeAll { $0.id == recipe.id }
    recentRecipes.removeAll { $0.id == recipe.id }
    LocalRecipeStorage.shared.unsaveRecipe(recipe.id)
}
```

---

### Phase 5: Migration & Cleanup

#### ✅ Task 5.1: Migrate Existing Saved Recipes
**File:** `SnapChef/SnapChefApp.swift`
**Changes:** Add one-time migration on app launch

```swift
// In SnapChefApp's init or onAppear:
private func migrateToLocalFirstStorage() {
    let migrationKey = "local_first_migration_completed_v1"
    guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
    
    // Migrate existing saved recipes to local storage
    let localStorage = LocalRecipeStorage.shared
    for recipe in appState.savedRecipes {
        localStorage.savedRecipeIds.insert(recipe.id.uuidString)
    }
    localStorage.persistToUserDefaults()
    
    UserDefaults.standard.set(true, forKey: migrationKey)
    print("✅ Migrated \(appState.savedRecipes.count) recipes to local-first storage")
}
```

---

#### ✅ Task 5.2: Remove Direct CloudKit Calls from UI
**Files to Update:**
- `RecipeResultsView.swift` - Remove all CloudKit calls ✓
- `DetectiveView.swift` - Update save logic
- `RecipeDetailView.swift` - Update save button

```swift
// Example for other views - use same pattern:
private func toggleSave() {
    let localStorage = LocalRecipeStorage.shared
    if localStorage.isRecipeSaved(recipe.id) {
        localStorage.unsaveRecipe(recipe.id)
    } else {
        localStorage.saveRecipe(recipe)
    }
    // Update local UI state
}
```

---

## 🧪 Testing Plan

### Test Cases:
1. ✅ Save recipe - Should update UI instantly
2. ✅ Unsave recipe - Should update UI instantly
3. ✅ Toggle rapidly - Should handle without delays
4. ✅ Airplane mode - Should work offline
5. ✅ Kill app mid-sync - Should retry on next launch
6. ✅ Sign out/in - Should preserve local saves

---

## 🚀 Deployment Steps

1. **Build and test LocalRecipeStorage** in isolation
2. **Update RecipeResultsView** with new save logic
3. **Test offline mode** thoroughly
4. **Add background sync** without breaking existing functionality
5. **Run migration** for existing users
6. **Monitor CloudKit** for sync success rate

---

## 📊 Success Metrics

- Save/unsave response time: < 50ms (currently 1-3 seconds)
- Offline functionality: 100% working
- Sync success rate: > 95% within 30 seconds
- User complaints about save button: 0

---

## 🔧 Rollback Plan

If issues arise, revert to direct CloudKit calls by:
1. Comment out LocalRecipeStorage usage
2. Restore original saveRecipe function
3. Clear UserDefaults keys for local storage

---

## Integration Points with Existing Code

### Existing Modules We'll Use:
- **PhotoStorageManager** - Already handles local photo storage
- **CloudKitRecipeManager** - For background sync only
- **AppState** - Update to use LocalRecipeStorage
- **UnifiedAuthManager** - Keep auth checks as-is
- **CloudKitSyncService** - Use for batch operations

### Files That Need Updates:
1. `RecipeResultsView.swift` - Main UI changes
2. `AppState.swift` - Add local storage methods
3. `SnapChefApp.swift` - Add migration
4. `CameraView.swift` - Ensure no auto-save (already done)

### New Files to Create:
1. `LocalRecipeStorage.swift`
2. `RecipeSyncQueue.swift`  
3. `PersistentSyncQueue.swift`

---

## Time Estimate
- Phase 1 (Local Storage): 30 minutes
- Phase 2 (UI Updates): 20 minutes
- Phase 3 (Sync Queue): 30 minutes
- Phase 4 (Integration): 15 minutes
- Phase 5 (Migration): 15 minutes
- Testing: 30 minutes
**Total: ~2.5 hours**