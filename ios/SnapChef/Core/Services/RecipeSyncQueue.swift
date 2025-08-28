import Foundation
import UIKit
import Combine

/// Background sync queue for recipe operations
/// Batches operations and syncs with CloudKit in background
actor RecipeSyncQueue {
    static let shared = RecipeSyncQueue()
    
    private var pendingOperations: [SyncOperation] = []
    private var syncTask: Task<Void, Never>?
    private let syncInterval: TimeInterval = 5.0
    
    enum SyncOperation: Codable, Equatable {
        case save(recipeId: String, hasPhoto: Bool)
        case unsave(recipeId: String)
        case update(recipeId: String)
        
        var recipeId: String {
            switch self {
            case .save(let id, _), .unsave(let id), .update(let id):
                return id
            }
        }
    }
    
    private init() {
        // Start monitoring for app becoming active
        Task {
            await setupNotificationObservers()
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for app becoming active to retry failed syncs
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await PersistentSyncQueue.shared.retryAllFailedOperations()
            }
        }
    }
    
    // MARK: - Public Methods
    
    func queueSave(_ recipe: Recipe, beforePhoto: UIImage?) async {
        let hasPhoto = beforePhoto != nil
        
        // Store photo locally if provided
        if let photo = beforePhoto {
            await savePhotoForSync(photo, recipeId: recipe.id.uuidString)
        }
        
        // Store recipe locally for sync
        await storeRecipeForSync(recipe)
        
        // Add to queue
        let operation = SyncOperation.save(recipeId: recipe.id.uuidString, hasPhoto: hasPhoto)
        await addOperation(operation)
        
        print("📤 Queued save for recipe: \(recipe.name)")
    }
    
    func queueUnsave(_ recipeId: UUID) async {
        let operation = SyncOperation.unsave(recipeId: recipeId.uuidString)
        await addOperation(operation)
        
        print("📤 Queued unsave for recipe: \(recipeId)")
    }
    
    func queueUpdate(_ recipe: Recipe) async {
        await storeRecipeForSync(recipe)
        let operation = SyncOperation.update(recipeId: recipe.id.uuidString)
        await addOperation(operation)
    }
    
    // For PersistentSyncQueue to retry operations
    func requeue(_ operation: SyncOperation) async {
        await addOperation(operation)
    }
    
    // MARK: - Private Methods
    
    private func addOperation(_ operation: SyncOperation) {
        // Remove any existing operations for the same recipe
        pendingOperations.removeAll { $0.recipeId == operation.recipeId }
        
        // Add the new operation
        pendingOperations.append(operation)
        
        // Start or restart the sync timer
        startSyncTimer()
    }
    
    private func startSyncTimer() {
        // Cancel existing task
        syncTask?.cancel()
        
        // Start new task
        syncTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(syncInterval * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            await processBatch()
        }
    }
    
    private func processBatch() async {
        guard !pendingOperations.isEmpty else { return }
        
        print("🔄 Processing sync batch: \(pendingOperations.count) operations")
        
        let batch = pendingOperations
        pendingOperations.removeAll()
        
        for operation in batch {
            await processOperation(operation)
        }
    }
    
    private func processOperation(_ operation: SyncOperation) async {
        switch operation {
        case .save(let recipeId, let hasPhoto):
            await syncSaveToCloudKit(recipeId: recipeId, hasPhoto: hasPhoto)
            
        case .unsave(let recipeId):
            await syncUnsaveToCloudKit(recipeId: recipeId)
            
        case .update(let recipeId):
            await syncUpdateToCloudKit(recipeId: recipeId)
        }
    }
    
    // MARK: - CloudKit Sync
    
    private func syncSaveToCloudKit(recipeId: String, hasPhoto: Bool) async {
        do {
            // Check if recipe exists in CloudKit
            let exists = await CloudKitRecipeManager.shared.checkRecipeExists(recipeId)
            
            if !exists {
                // Load recipe from local storage
                guard let recipe = await loadRecipeFromSync(recipeId) else {
                    print("❌ Recipe not found in local storage: \(recipeId)")
                    return
                }
                
                // Load photo if it was saved
                let photo = hasPhoto ? await loadPhotoFromSync(recipeId) : nil
                
                // Upload to CloudKit
                _ = try await CloudKitRecipeManager.shared.uploadRecipe(
                    recipe,
                    fromLLM: false,
                    beforePhoto: photo
                )
                
                print("☁️ Recipe uploaded to CloudKit: \(recipe.name)")
            }
            
            // Mark as saved for this user
            try await CloudKitRecipeManager.shared.addRecipeToUserProfile(recipeId, type: .saved)
            print("✅ Recipe marked as saved in CloudKit: \(recipeId)")
            
        } catch {
            print("❌ CloudKit sync failed for save: \(error)")
            // Add to persistent queue for retry
            await PersistentSyncQueue.shared.addFailedOperation(.save(recipeId: recipeId, hasPhoto: hasPhoto))
        }
    }
    
    private func syncUnsaveToCloudKit(recipeId: String) async {
        do {
            try await CloudKitRecipeManager.shared.removeRecipeFromUserProfile(recipeId, type: .saved)
            print("✅ Recipe removed from saved in CloudKit: \(recipeId)")
        } catch {
            print("❌ CloudKit sync failed for unsave: \(error)")
            await PersistentSyncQueue.shared.addFailedOperation(.unsave(recipeId: recipeId))
        }
    }
    
    private func syncUpdateToCloudKit(recipeId: String) async {
        // For future implementation when recipes can be edited
        print("📝 Update sync not yet implemented for: \(recipeId)")
    }
    
    // MARK: - Local Storage for Sync
    
    private func storeRecipeForSync(_ recipe: Recipe) async {
        // Store in documents directory for sync
        let syncDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("sync_queue")
        
        try? FileManager.default.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        
        let fileURL = syncDirectory.appendingPathComponent("\(recipe.id.uuidString).json")
        
        if let data = try? JSONEncoder().encode(recipe) {
            try? data.write(to: fileURL)
        }
    }
    
    private func loadRecipeFromSync(_ recipeId: String) async -> Recipe? {
        // First try LocalRecipeStorage
        if let recipe = await MainActor.run(body: { 
            LocalRecipeStorage.shared.loadRecipeFromFile(recipeId) 
        }) {
            return recipe
        }
        
        // Then try sync queue directory
        let syncDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("sync_queue")
        let fileURL = syncDirectory.appendingPathComponent("\(recipeId).json")
        
        guard let data = try? Data(contentsOf: fileURL),
              let recipe = try? JSONDecoder().decode(Recipe.self, from: data) else {
            return nil
        }
        
        return recipe
    }
    
    private func savePhotoForSync(_ photo: UIImage, recipeId: String) async {
        let syncDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("sync_queue")
            .appendingPathComponent("photos")
        
        try? FileManager.default.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        
        let fileURL = syncDirectory.appendingPathComponent("\(recipeId).jpg")
        
        if let data = photo.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }
    }
    
    private func loadPhotoFromSync(_ recipeId: String) async -> UIImage? {
        let syncDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("sync_queue")
            .appendingPathComponent("photos")
        let fileURL = syncDirectory.appendingPathComponent("\(recipeId).jpg")
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
}