//
//  CloudKitSyncEngine.swift
//  SnapChef
//
//  Handles background CloudKit sync with intelligent retry and conflict resolution
//

import Foundation
import CloudKit
import UIKit

@MainActor
final class CloudKitSyncEngine: ObservableObject {
    static let shared = CloudKitSyncEngine()
    
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    @Published var lastSyncDate: Date?
    @Published var pendingOperationsCount: Int = 0
    
    private let syncQueue = DispatchQueue(label: "com.snapchef.sync", qos: .background)
    private var pendingOperations: [SyncOperation] = []
    private var failedOperations: [SyncOperation] = []
    private let maxRetries = 3
    private var syncTimer: Timer?
    
    struct SyncOperation: Codable {
        enum OperationType: String, Codable {
            case save
            case unsave
            case update
            case like
            case unlike
        }
        
        let id: String
        let recipeID: String
        let type: OperationType
        let timestamp: Date
        var retryCount: Int = 0
    }
    
    private init() {
        loadPendingOperations()
        startSyncTimer()
        
        // Update pending count
        pendingOperationsCount = pendingOperations.count
    }
    
    // MARK: - Queue Management
    
    func queueRecipeForSync(_ recipe: Recipe, image: UIImage? = nil) {
        let operation = SyncOperation(
            id: UUID().uuidString,
            recipeID: recipe.id.uuidString,
            type: .save,
            timestamp: Date()
        )
        
        pendingOperations.append(operation)
        pendingOperationsCount = pendingOperations.count
        savePendingOperations()
        
        // Store image for later upload
        if let image = image {
            saveImageForSync(recipeID: recipe.id.uuidString, image: image)
        }
        
        print("📤 CloudKitSyncEngine: Queued recipe for sync: \(recipe.name)")
        
        // Try to sync immediately if online
        Task {
            await processPendingSync()
        }
    }
    
    func queueRecipeForDeletion(_ recipeID: UUID) {
        let operation = SyncOperation(
            id: UUID().uuidString,
            recipeID: recipeID.uuidString,
            type: .unsave,
            timestamp: Date()
        )
        
        pendingOperations.append(operation)
        pendingOperationsCount = pendingOperations.count
        savePendingOperations()
        
        print("🗑 CloudKitSyncEngine: Queued recipe for deletion: \(recipeID)")
        
        Task {
            await processPendingSync()
        }
    }
    
    // MARK: - Sync Timer
    
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                await self.processPendingSync()
            }
        }
    }
    
    // MARK: - Sync Processing
    
    func processPendingSync() async {
        guard !isSyncing else { 
            print("⏳ CloudKitSyncEngine: Already syncing, skipping...")
            return 
        }
        
        guard UnifiedAuthManager.shared.isAuthenticated else { 
            print("🔒 CloudKitSyncEngine: User not authenticated, skipping sync")
            return 
        }
        
        guard !pendingOperations.isEmpty else { 
            print("✅ CloudKitSyncEngine: No pending operations")
            return 
        }
        
        print("🔄 CloudKitSyncEngine: Starting sync of \(pendingOperations.count) operations...")
        isSyncing = true
        syncProgress = 0.0
        
        var successfulOps: [String] = []
        var failedOps: [SyncOperation] = []
        let totalOperations = Double(pendingOperations.count)
        var processedCount = 0.0
        
        for operation in pendingOperations {
            do {
                switch operation.type {
                case .save:
                    try await syncRecipeToCloudKit(recipeID: operation.recipeID)
                    print("✅ Synced recipe: \(operation.recipeID)")
                    
                case .unsave:
                    try await deleteRecipeFromCloudKit(recipeID: operation.recipeID)
                    print("✅ Deleted recipe from CloudKit: \(operation.recipeID)")
                    
                case .update:
                    try await updateRecipeInCloudKit(recipeID: operation.recipeID)
                    print("✅ Updated recipe in CloudKit: \(operation.recipeID)")
                    
                case .like, .unlike:
                    // Handle like operations if needed
                    break
                }
                
                successfulOps.append(operation.id)
                
                // Update sync status in LocalRecipeManager
                LocalRecipeManager.shared.updateSyncStatus(for: operation.recipeID, status: .synced)
                
            } catch {
                print("❌ CloudKitSyncEngine: Sync failed for \(operation.recipeID): \(error.localizedDescription)")
                
                var failedOp = operation
                failedOp.retryCount += 1
                
                if failedOp.retryCount < maxRetries {
                    failedOps.append(failedOp)
                    LocalRecipeManager.shared.updateSyncStatus(for: operation.recipeID, status: .failed(error))
                } else {
                    print("❌ CloudKitSyncEngine: Max retries exceeded for \(operation.recipeID)")
                }
            }
            
            processedCount += 1
            syncProgress = processedCount / totalOperations
        }
        
        // Remove successful operations
        pendingOperations.removeAll { successfulOps.contains($0.id) }
        
        // Add failed operations back with retry count
        pendingOperations.append(contentsOf: failedOps)
        
        pendingOperationsCount = pendingOperations.count
        savePendingOperations()
        lastSyncDate = Date()
        isSyncing = false
        syncProgress = 1.0
        
        print("📊 CloudKitSyncEngine: Sync complete - Success: \(successfulOps.count), Failed: \(failedOps.count), Remaining: \(pendingOperations.count)")
    }
    
    // MARK: - CloudKit Operations
    
    private func syncRecipeToCloudKit(recipeID: String) async throws {
        // Get recipe from LocalRecipeManager
        guard let recipe = LocalRecipeManager.shared.allRecipes.first(where: { $0.id.uuidString == recipeID }) else {
            throw NSError(domain: "CloudKitSyncEngine", code: 404, userInfo: [NSLocalizedDescriptionKey: "Recipe not found in local database"])
        }
        
        // Update sync status to syncing
        LocalRecipeManager.shared.updateSyncStatus(for: recipeID, status: .syncing)
        
        // Get image if available
        let image = loadImageForSync(recipeID: recipeID)
        
        // Upload to CloudKit using existing manager
        _ = try await CloudKitRecipeManager.shared.uploadRecipe(
            recipe,
            fromLLM: false,
            beforePhoto: image
        )
        
        // Clean up stored image after successful upload
        deleteImageForSync(recipeID: recipeID)
    }
    
    private func deleteRecipeFromCloudKit(recipeID: String) async throws {
        // Delete from CloudKit using CloudKitActor
        let recordID = CKRecord.ID(recordName: recipeID)
        try await CloudKitSyncService.shared.cloudKitActor.deleteRecordByID(recordID)
    }
    
    private func updateRecipeInCloudKit(recipeID: String) async throws {
        // Similar to sync but updates existing record
        try await syncRecipeToCloudKit(recipeID: recipeID)
    }
    
    // MARK: - Image Storage for Sync
    
    private func saveImageForSync(recipeID: String, image: UIImage) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let syncImagesPath = documentsPath.appendingPathComponent("sync_images")
        
        try? FileManager.default.createDirectory(at: syncImagesPath, withIntermediateDirectories: true)
        
        let imagePath = syncImagesPath.appendingPathComponent("\(recipeID).jpg")
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: imagePath)
            print("💾 CloudKitSyncEngine: Saved image for sync: \(recipeID)")
        }
    }
    
    private func loadImageForSync(recipeID: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagePath = documentsPath.appendingPathComponent("sync_images/\(recipeID).jpg")
        
        if let data = try? Data(contentsOf: imagePath) {
            return UIImage(data: data)
        }
        
        // Try to get from PhotoStorageManager
        let photos = PhotoStorageManager.shared.getPhotos(for: UUID(uuidString: recipeID) ?? UUID())
        return photos?.fridgePhoto
    }
    
    private func deleteImageForSync(recipeID: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagePath = documentsPath.appendingPathComponent("sync_images/\(recipeID).jpg")
        
        try? FileManager.default.removeItem(at: imagePath)
    }
    
    // MARK: - Persistence
    
    private func savePendingOperations() {
        if let data = try? JSONEncoder().encode(pendingOperations) {
            UserDefaults.standard.set(data, forKey: "cloudkit_pending_sync_operations")
            print("💾 CloudKitSyncEngine: Saved \(pendingOperations.count) pending operations")
        }
    }
    
    private func loadPendingOperations() {
        if let data = UserDefaults.standard.data(forKey: "cloudkit_pending_sync_operations"),
           let operations = try? JSONDecoder().decode([SyncOperation].self, from: data) {
            pendingOperations = operations
            print("📥 CloudKitSyncEngine: Loaded \(operations.count) pending operations")
        }
    }
    
    // MARK: - Public Methods
    
    func clearAllPendingOperations() {
        pendingOperations.removeAll()
        pendingOperationsCount = 0
        savePendingOperations()
        print("🗑 CloudKitSyncEngine: Cleared all pending operations")
    }
    
    func getPendingSyncCount() -> Int {
        return pendingOperations.count
    }
    
    func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
}