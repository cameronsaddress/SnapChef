//
//  LocalRecipeStore.swift
//  SnapChef
//
//  DEPRECATED: Use LocalRecipeManager instead
//  This file is kept for backward compatibility during migration
//  Will be removed in a future update
//

import Foundation
import SwiftUI
import CloudKit

// MARK: - Sync Status
enum SyncStatus: String {
    case local = "local"        // Only exists locally
    case pending = "pending"    // Waiting to sync to CloudKit
    case synced = "synced"      // Successfully synced with CloudKit
    case conflict = "conflict"  // Sync conflict needs resolution
}

// MARK: - Local Recipe Store
@MainActor
final class LocalRecipeStore: ObservableObject {
    static let shared = LocalRecipeStore()
    
    @Published var recipes: [LocalRecipe] = []
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    
    private let userDefaults = UserDefaults.standard
    private let recipesKey = "localRecipes"
    private let lastSyncKey = "lastRecipeSync"
    
    private init() {
        loadRecipes()
        lastSyncDate = userDefaults.object(forKey: lastSyncKey) as? Date
    }
    
    // MARK: - CRUD Operations
    
    func saveRecipe(_ recipe: Recipe, ownerID: String? = nil) -> LocalRecipe {
        let localRecipe = LocalRecipe(
            id: recipe.id,
            recipe: recipe,
            ownerID: ownerID,
            syncStatus: .local,
            cloudKitRecordID: nil,
            createdAt: Date(),
            modifiedAt: Date()
        )
        
        recipes.append(localRecipe)
        persistRecipes()
        
        // Queue for sync if user is authenticated
        if ownerID != nil {
            localRecipe.syncStatus = .pending
            persistRecipes()
        }
        
        return localRecipe
    }
    
    func updateRecipe(_ recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index].recipe = recipe
            recipes[index].modifiedAt = Date()
            
            // Mark for sync if already synced
            if recipes[index].syncStatus == .synced {
                recipes[index].syncStatus = .pending
            }
            
            persistRecipes()
        }
    }
    
    func deleteRecipe(id: UUID) {
        recipes.removeAll { $0.id == id }
        persistRecipes()
    }
    
    func getRecipe(id: UUID) -> LocalRecipe? {
        return recipes.first { $0.id == id }
    }
    
    // MARK: - Sync Operations
    
    func getRecipesForSync() -> [LocalRecipe] {
        return recipes.filter { $0.syncStatus == .pending }
    }
    
    func markRecipeSynced(id: UUID, cloudKitRecordID: String) {
        if let index = recipes.firstIndex(where: { $0.id == id }) {
            recipes[index].cloudKitRecordID = cloudKitRecordID
            recipes[index].syncStatus = .synced
            persistRecipes()
        }
    }
    
    func markRecipeConflict(id: UUID) {
        if let index = recipes.firstIndex(where: { $0.id == id }) {
            recipes[index].syncStatus = .conflict
            persistRecipes()
        }
    }
    
    // MARK: - Migration
    
    func migrateRecipesToUser(ownerID: String) {
        for index in recipes.indices {
            if recipes[index].ownerID == nil {
                recipes[index].ownerID = ownerID
                recipes[index].syncStatus = .pending
            }
        }
        persistRecipes()
    }
    
    // MARK: - Query Methods
    
    func getLocalRecipes() -> [LocalRecipe] {
        return recipes.filter { $0.syncStatus == .local }
    }
    
    func getPendingRecipes() -> [LocalRecipe] {
        return recipes.filter { $0.syncStatus == .pending }
    }
    
    func getSyncedRecipes() -> [LocalRecipe] {
        return recipes.filter { $0.syncStatus == .synced }
    }
    
    func getConflictedRecipes() -> [LocalRecipe] {
        return recipes.filter { $0.syncStatus == .conflict }
    }
    
    func getUserRecipes(ownerID: String) -> [LocalRecipe] {
        return recipes.filter { $0.ownerID == ownerID }
    }
    
    func getAnonymousRecipes() -> [LocalRecipe] {
        return recipes.filter { $0.ownerID == nil }
    }
    
    // MARK: - Persistence
    
    private func loadRecipes() {
        guard let data = userDefaults.data(forKey: recipesKey),
              let decoded = try? JSONDecoder().decode([LocalRecipe].self, from: data) else {
            recipes = []
            return
        }
        recipes = decoded
    }
    
    private func persistRecipes() {
        guard let encoded = try? JSONEncoder().encode(recipes) else { return }
        userDefaults.set(encoded, forKey: recipesKey)
    }
    
    func updateLastSyncDate() {
        lastSyncDate = Date()
        userDefaults.set(lastSyncDate, forKey: lastSyncKey)
    }
    
    // MARK: - Cleanup
    
    func cleanupOldRecipes(daysToKeep: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysToKeep, to: Date()) ?? Date()
        
        recipes = recipes.filter { recipe in
            // Keep if:
            // 1. Created after cutoff date
            // 2. Has pending changes
            // 3. Is favorited (when we add that feature)
            // 4. Has conflicts
            
            if recipe.createdAt > cutoffDate { return true }
            if recipe.syncStatus == .pending { return true }
            if recipe.syncStatus == .conflict { return true }
            
            return false
        }
        
        persistRecipes()
    }
    
    // MARK: - Statistics
    
    func getStorageStats() -> LocalStorageStats {
        return LocalStorageStats(
            totalRecipes: recipes.count,
            localRecipes: getLocalRecipes().count,
            pendingRecipes: getPendingRecipes().count,
            syncedRecipes: getSyncedRecipes().count,
            conflictedRecipes: getConflictedRecipes().count,
            anonymousRecipes: getAnonymousRecipes().count,
            lastSyncDate: lastSyncDate
        )
    }
}

// MARK: - Local Recipe Model
class LocalRecipe: Codable, Identifiable, ObservableObject {
    let id: UUID
    var recipe: Recipe
    var ownerID: String?
    @Published var syncStatus: SyncStatus
    var cloudKitRecordID: String?
    let createdAt: Date
    var modifiedAt: Date
    
    init(id: UUID = UUID(),
         recipe: Recipe,
         ownerID: String? = nil,
         syncStatus: SyncStatus = .local,
         cloudKitRecordID: String? = nil,
         createdAt: Date = Date(),
         modifiedAt: Date = Date()) {
        self.id = id
        self.recipe = recipe
        self.ownerID = ownerID
        self.syncStatus = syncStatus
        self.cloudKitRecordID = cloudKitRecordID
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, recipe, ownerID, syncStatus, cloudKitRecordID, createdAt, modifiedAt
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        recipe = try container.decode(Recipe.self, forKey: .recipe)
        ownerID = try container.decodeIfPresent(String.self, forKey: .ownerID)
        syncStatus = try SyncStatus(rawValue: container.decode(String.self, forKey: .syncStatus)) ?? .local
        cloudKitRecordID = try container.decodeIfPresent(String.self, forKey: .cloudKitRecordID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(recipe, forKey: .recipe)
        try container.encodeIfPresent(ownerID, forKey: .ownerID)
        try container.encode(syncStatus.rawValue, forKey: .syncStatus)
        try container.encodeIfPresent(cloudKitRecordID, forKey: .cloudKitRecordID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
    }
}

// MARK: - Storage Statistics
struct LocalStorageStats {
    let totalRecipes: Int
    let localRecipes: Int
    let pendingRecipes: Int
    let syncedRecipes: Int
    let conflictedRecipes: Int
    let anonymousRecipes: Int
    let lastSyncDate: Date?
    
    var needsSync: Bool {
        return pendingRecipes > 0 || conflictedRecipes > 0
    }
    
    var syncPercentage: Double {
        guard totalRecipes > 0 else { return 100.0 }
        return Double(syncedRecipes) / Double(totalRecipes) * 100.0
    }
}

// MARK: - Sync Queue Manager
@MainActor
final class SyncQueueManager: ObservableObject {
    static let shared = SyncQueueManager()
    
    @Published var isProcessing = false
    @Published var syncErrors: [SyncError] = []
    
    private let localStore = LocalRecipeStore.shared
    private var syncTask: Task<Void, Never>?
    
    private init() {}
    
    func startSync() {
        guard !isProcessing else { return }
        
        syncTask = Task {
            await processSyncQueue()
        }
    }
    
    func stopSync() {
        syncTask?.cancel()
        syncTask = nil
        isProcessing = false
    }
    
    private func processSyncQueue() async {
        isProcessing = true
        defer { isProcessing = false }
        
        let recipesToSync = localStore.getRecipesForSync()
        
        // Batch sync for efficiency
        let batchSize = 10
        let batches = recipesToSync.chunked(into: batchSize)
        
        for batch in batches {
            guard !Task.isCancelled else { break }
            
            // Process batch in parallel
            await withTaskGroup(of: SyncResult.self) { group in
                for localRecipe in batch {
                    group.addTask {
                        await self.syncSingleRecipe(localRecipe)
                    }
                }
                
                // Collect results
                for await result in group {
                    switch result {
                    case .success(let recipeID, let cloudKitID):
                        localStore.markRecipeSynced(id: recipeID, cloudKitRecordID: cloudKitID)
                        print("✅ Synced recipe: \(recipeID)")
                    case .conflict(let recipeID, let error):
                        localStore.markRecipeConflict(id: recipeID)
                        if let localRecipe = localStore.getRecipe(id: recipeID) {
                            await resolveConflict(localRecipe: localRecipe, error: error)
                        }
                    case .failure(let recipeID, let error):
                        syncErrors.append(SyncError(
                            recipeID: recipeID,
                            error: error,
                            timestamp: Date()
                        ))
                        print("⚠️ Sync failed for recipe \(recipeID), will retry: \(error)")
                    }
                }
            }
            
            // Small delay between batches to avoid rate limiting
            if !batches.isEmpty {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        localStore.updateLastSyncDate()
    }
    
    private func syncSingleRecipe(_ localRecipe: LocalRecipe) async -> SyncResult {
        do {
            let cloudKitRecordID = try await CloudKitService.shared.uploadRecipeForSharing(
                localRecipe.recipe,
                imageData: nil
            )
            return .success(recipeID: localRecipe.id, cloudKitID: cloudKitRecordID)
        } catch {
            if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
                return .conflict(recipeID: localRecipe.id, error: ckError)
            } else {
                return .failure(recipeID: localRecipe.id, error: error)
            }
        }
    }
    
    private enum SyncResult {
        case success(recipeID: UUID, cloudKitID: String)
        case conflict(recipeID: UUID, error: CKError)
        case failure(recipeID: UUID, error: Error)
    }
    
    // MARK: - Conflict Resolution
    
    private func resolveConflict(localRecipe: LocalRecipe, error: CKError) async {
        guard let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
            return
        }
        
        // Strategy: Last-write-wins based on modification date
        let serverModified = serverRecord.modificationDate ?? Date.distantPast
        let localModified = localRecipe.modifiedAt
        
        if localModified > serverModified {
            // Local version is newer - try to force update
            do {
                // Update the server record with local data
                serverRecord[CKField.Recipe.title] = localRecipe.recipe.name
                serverRecord[CKField.Recipe.description] = localRecipe.recipe.description
                // ... update other fields
                
                guard let container = CloudKitRuntimeSupport.makeContainer() else {
                    print("⚠️ CloudKit unavailable - skipping server-side conflict resolution upload")
                    return
                }
                let savedRecord = try await container.publicCloudDatabase.save(serverRecord)
                localStore.markRecipeSynced(id: localRecipe.id, cloudKitRecordID: savedRecord.recordID.recordName)
                print("✅ Conflict resolved: Local version won for \(localRecipe.recipe.name)")
            } catch {
                print("❌ Failed to resolve conflict: \(error)")
            }
        } else {
            // Server version is newer - update local with server data
            do {
                let (serverRecipe, _) = try await CloudKitService.shared.fetchSharedRecipe(by: serverRecord.recordID.recordName)
                localStore.updateRecipe(serverRecipe)
                localStore.markRecipeSynced(id: serverRecipe.id, cloudKitRecordID: serverRecord.recordID.recordName)
                print("✅ Conflict resolved: Server version won for \(serverRecipe.name)")
            } catch {
                print("❌ Failed to fetch server version: \(error)")
            }
        }
    }
}

// MARK: - Sync Error
struct SyncError: Identifiable {
    let id = UUID()
    let recipeID: UUID
    let error: Error
    let timestamp: Date
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
