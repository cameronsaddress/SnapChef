//
//  LocalRecipeManager.swift
//  SnapChef
//
//  Single source of truth for all recipe data
//  Handles local-first storage with CloudKit sync capabilities
//

import Foundation
import SwiftUI
import SQLite3

@MainActor
final class LocalRecipeManager: ObservableObject {
    static let shared = LocalRecipeManager()
    
    // MARK: - Published Properties for UI
    @Published var allRecipes: [Recipe] = []
    @Published var isLoading = false
    @Published var lastError: Error?
    
    // MARK: - Private Properties
    nonisolated(unsafe) private var db: OpaquePointer?
    private let dbPath: String
    private let dbQueue = DispatchQueue(label: "com.snapchef.recipedb", attributes: .concurrent)
    private let memoryCache = NSCache<NSString, NSData>()
    
    // Track save states efficiently
    private var savedRecipeIDs: Set<String> = []
    private var likedRecipeIDs: Set<String> = []
    
    // Sync tracking
    private var syncStatuses: [String: SyncStatus] = [:]
    private var lastSyncDate: Date?
    
    enum SyncStatus {
        case local
        case pending
        case syncing
        case synced
        case failed(Error)
    }
    
    private init() {
        // Setup SQLite database
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.dbPath = documentsPath.appendingPathComponent("recipes.sqlite").path
        
        setupDatabase()
        loadAllRecipes()
        
        // Setup memory cache limits
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ LocalRecipeManager: Failed to open database")
            return
        }
        
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS recipes (
                id TEXT PRIMARY KEY,
                data BLOB NOT NULL,
                owner_id TEXT,
                is_saved INTEGER DEFAULT 0,
                is_liked INTEGER DEFAULT 0,
                sync_status TEXT DEFAULT 'local',
                cloudkit_record_id TEXT,
                created_at REAL NOT NULL,
                modified_at REAL NOT NULL,
                last_sync_at REAL
            );
            
            CREATE INDEX IF NOT EXISTS idx_recipes_owner ON recipes(owner_id);
            CREATE INDEX IF NOT EXISTS idx_recipes_saved ON recipes(is_saved);
            CREATE INDEX IF NOT EXISTS idx_recipes_sync ON recipes(sync_status);
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ LocalRecipeManager: Failed to create recipes table")
        } else {
            print("✅ LocalRecipeManager: Database initialized successfully")
        }
    }
    
    // MARK: - Core CRUD Operations
    
    func saveRecipe(_ recipe: Recipe, capturedImage: UIImage? = nil) {
        // Capture the current user ID on main thread
        let currentUserID = UnifiedAuthManager.shared.currentUser?.recordID
        
        // 1. Save to database immediately for instant UI update
        dbQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            do {
                let recipeData = try JSONEncoder().encode(recipe)
                
                let sql = """
                    INSERT OR REPLACE INTO recipes 
                    (id, data, owner_id, is_saved, created_at, modified_at, sync_status)
                    VALUES (?, ?, ?, 1, ?, ?, 'pending')
                """
                
                var statement: OpaquePointer?
                if sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, recipe.id.uuidString, -1, nil)
                    sqlite3_bind_blob(statement, 2, [UInt8](recipeData), Int32(recipeData.count), nil)
                    sqlite3_bind_text(statement, 3, currentUserID, -1, nil)
                    sqlite3_bind_double(statement, 4, recipe.createdAt.timeIntervalSince1970)
                    sqlite3_bind_double(statement, 5, Date().timeIntervalSince1970)
                    
                    if sqlite3_step(statement) == SQLITE_DONE {
                        print("✅ LocalRecipeManager: Recipe saved to database: \(recipe.name)")
                    } else {
                        print("❌ LocalRecipeManager: Failed to save recipe: \(String(cString: sqlite3_errmsg(self.db)))")
                    }
                }
                sqlite3_finalize(statement)
                
                // 2. Update in-memory state
                Task { @MainActor in
                    if !self.allRecipes.contains(where: { $0.id == recipe.id }) {
                        self.allRecipes.insert(recipe, at: 0)
                    }
                    self.savedRecipeIDs.insert(recipe.id.uuidString)
                    
                    // 3. Store photo if provided
                    if let image = capturedImage {
                        PhotoStorageManager.shared.storePhotos(
                            fridgePhoto: image,
                            mealPhoto: nil,
                            for: recipe.id
                        )
                    }
                    
                    // 4. Queue for CloudKit sync (will be implemented in Phase 2)
                    // CloudKitSyncEngine.shared.queueRecipeForSync(recipe, image: capturedImage)
                }
                
            } catch {
                print("❌ LocalRecipeManager: Failed to save recipe: \(error)")
            }
        }
    }
    
    func unsaveRecipe(_ recipeID: UUID) {
        dbQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Mark as unsaved rather than delete - preserves recipe but removes from saved list
            let sql = "UPDATE recipes SET is_saved = 0, modified_at = ? WHERE id = ?"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
                sqlite3_bind_text(statement, 2, recipeID.uuidString, -1, nil)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    print("✅ LocalRecipeManager: Recipe unsaved: \(recipeID)")
                }
            }
            sqlite3_finalize(statement)
            
            Task { @MainActor in
                self.savedRecipeIDs.remove(recipeID.uuidString)
                
                // Remove photos
                PhotoStorageManager.shared.removePhotos(for: [recipeID])
                
                // Queue for CloudKit deletion (will be implemented in Phase 2)
                // CloudKitSyncEngine.shared.queueRecipeForDeletion(recipeID)
            }
        }
    }
    
    func isRecipeSaved(_ recipeID: UUID) -> Bool {
        return savedRecipeIDs.contains(recipeID.uuidString)
    }
    
    func toggleRecipeLike(_ recipeID: UUID) {
        let isCurrentlyLiked = likedRecipeIDs.contains(recipeID.uuidString)
        
        dbQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let sql = "UPDATE recipes SET is_liked = ?, modified_at = ? WHERE id = ?"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int(statement, 1, isCurrentlyLiked ? 0 : 1)
                sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
                sqlite3_bind_text(statement, 3, recipeID.uuidString, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
            
            Task { @MainActor in
                if isCurrentlyLiked {
                    self.likedRecipeIDs.remove(recipeID.uuidString)
                } else {
                    self.likedRecipeIDs.insert(recipeID.uuidString)
                }
            }
        }
    }
    
    // MARK: - Loading and Querying
    
    func loadAllRecipes() {
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            
            var recipes: [Recipe] = []
            var savedIDs: Set<String> = []
            var likedIDs: Set<String> = []
            
            let sql = "SELECT data, is_saved, is_liked, id FROM recipes ORDER BY created_at DESC"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let dataBlob = sqlite3_column_blob(statement, 0) {
                        let dataSize = sqlite3_column_bytes(statement, 0)
                        let data = Data(bytes: dataBlob, count: Int(dataSize))
                        
                        if let recipe = try? JSONDecoder().decode(Recipe.self, from: data) {
                            recipes.append(recipe)
                            
                            // Update save/like states
                            if sqlite3_column_int(statement, 1) == 1 {
                                savedIDs.insert(recipe.id.uuidString)
                            }
                            if sqlite3_column_int(statement, 2) == 1 {
                                likedIDs.insert(recipe.id.uuidString)
                            }
                        }
                    }
                }
            }
            sqlite3_finalize(statement)
            
            Task { @MainActor in
                self.allRecipes = recipes
                self.savedRecipeIDs = savedIDs
                self.likedRecipeIDs = likedIDs
                print("📱 LocalRecipeManager: Loaded \(recipes.count) recipes (\(savedIDs.count) saved, \(likedIDs.count) liked)")
            }
        }
    }
    
    func getSavedRecipes() -> [Recipe] {
        return allRecipes.filter { isRecipeSaved($0.id) }
    }
    
    func getRecentRecipes(limit: Int = 10) -> [Recipe] {
        return Array(allRecipes.prefix(limit))
    }
    
    // MARK: - CloudKit Integration
    
    func mergeCloudKitRecipes(_ cloudRecipes: [Recipe]) {
        dbQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            var addedCount = 0
            
            for recipe in cloudRecipes {
                // Check if recipe exists locally
                let checkSQL = "SELECT COUNT(*) FROM recipes WHERE id = ?"
                var checkStatement: OpaquePointer?
                var exists = false
                
                if sqlite3_prepare_v2(self.db, checkSQL, -1, &checkStatement, nil) == SQLITE_OK {
                    sqlite3_bind_text(checkStatement, 1, recipe.id.uuidString, -1, nil)
                    
                    if sqlite3_step(checkStatement) == SQLITE_ROW {
                        exists = sqlite3_column_int(checkStatement, 0) > 0
                    }
                }
                sqlite3_finalize(checkStatement)
                
                // Only insert if doesn't exist locally
                if !exists {
                    do {
                        let recipeData = try JSONEncoder().encode(recipe)
                        
                        let sql = """
                            INSERT INTO recipes 
                            (id, data, owner_id, created_at, modified_at, sync_status)
                            VALUES (?, ?, ?, ?, ?, 'synced')
                        """
                        
                        var statement: OpaquePointer?
                        if sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK {
                            sqlite3_bind_text(statement, 1, recipe.id.uuidString, -1, nil)
                            sqlite3_bind_blob(statement, 2, [UInt8](recipeData), Int32(recipeData.count), nil)
                            sqlite3_bind_text(statement, 3, recipe.ownerID, -1, nil)
                            sqlite3_bind_double(statement, 4, recipe.createdAt.timeIntervalSince1970)
                            sqlite3_bind_double(statement, 5, Date().timeIntervalSince1970)
                            
                            if sqlite3_step(statement) == SQLITE_DONE {
                                addedCount += 1
                            }
                        }
                        sqlite3_finalize(statement)
                        
                    } catch {
                        print("❌ LocalRecipeManager: Failed to merge CloudKit recipe: \(error)")
                    }
                }
            }
            
            if addedCount > 0 {
                print("✅ LocalRecipeManager: Merged \(addedCount) new recipes from CloudKit")
                // Reload recipes to include new ones
                Task { @MainActor in
                    self.loadAllRecipes()
                }
            }
        }
    }
    
    func updateSyncStatus(for recipeID: String, status: SyncStatus) {
        syncStatuses[recipeID] = status
        
        // Update database
        dbQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let statusString: String
            switch status {
            case .local: statusString = "local"
            case .pending: statusString = "pending"
            case .syncing: statusString = "syncing"
            case .synced: statusString = "synced"
            case .failed: statusString = "failed"
            }
            
            let sql = "UPDATE recipes SET sync_status = ?, last_sync_at = ? WHERE id = ?"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, statusString, -1, nil)
                if case .synced = status {
                    sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(statement, 2)
                }
                sqlite3_bind_text(statement, 3, recipeID, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }
    
    // MARK: - Cleanup
    
    func clearAllRecipes() {
        dbQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let sql = "DELETE FROM recipes"
            sqlite3_exec(self.db, sql, nil, nil, nil)
            
            Task { @MainActor in
                self.allRecipes.removeAll()
                self.savedRecipeIDs.removeAll()
                self.likedRecipeIDs.removeAll()
                self.memoryCache.removeAllObjects()
                print("🗑️ LocalRecipeManager: All recipes cleared from database")
            }
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
}