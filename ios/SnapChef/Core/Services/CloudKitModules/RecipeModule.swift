import Foundation
import CloudKit
import SwiftUI

/// Statistics about recipe sync status between the local cache and CloudKit.
struct SyncStats {
    let totalCloudKitRecipes: Int
    let totalLocalRecipes: Int
    let missingRecipes: Int
    let recipesWithPhotos: Int
    let recipesNeedingPhotos: Int

    var isUpToDate: Bool {
        missingRecipes == 0
    }

    var completionPercentage: Double {
        guard totalCloudKitRecipes > 0 else { return 100.0 }
        return (Double(totalLocalRecipes) / Double(totalCloudKitRecipes)) * 100.0
    }
}

/// Result of a recipe sync operation.
struct SyncResult {
    let newRecipesSynced: Int
    let photosDownloaded: Int
    let duration: TimeInterval
    let success: Bool
}

enum RecipeError: LocalizedError {
    case invalidRecord
    case invalidJSON
    case invalidShareLink
    case notFound
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .invalidRecord:
            return "Invalid recipe record format"
        case .invalidJSON:
            return "Failed to parse JSON data"
        case .invalidShareLink:
            return "Invalid recipe share link"
        case .notFound:
            return "Recipe not found"
        case .uploadFailed:
            return "Failed to upload recipe"
        }
    }
}

/// Recipe module for CloudKit operations
/// Handles recipe upload, fetch, sync, and user recipe management
@MainActor
final class RecipeModule: ObservableObject {
    
    // MARK: - Properties
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private weak var parent: CloudKitService?
    
    // Cache for recipes
    @Published var cachedRecipes: [String: Recipe] = [:]
    @Published var userSavedRecipeIDs: Set<String> = []
    @Published var userCreatedRecipeIDs: Set<String> = []
    @Published var userFavoritedRecipeIDs: Set<String> = []

    private enum CacheKeys {
        static let saved = "user_saved_recipe_ids"
        static let created = "user_created_recipe_ids"
        static let favorited = "user_favorited_recipe_ids"
    }
    
    // MARK: - Initialization
    init(container: CKContainer, publicDB: CKDatabase, privateDB: CKDatabase, parent: CloudKitService) {
        self.container = container
        self.publicDatabase = publicDB
        self.privateDatabase = privateDB
        self.parent = parent
        loadUserRecipeReferences()
    }

    private func loadCachedRecipeReferences() {
        let defaults = UserDefaults.standard
        if let savedIDs = defaults.array(forKey: CacheKeys.saved) as? [String] {
            userSavedRecipeIDs = Set(savedIDs)
        }
        if let createdIDs = defaults.array(forKey: CacheKeys.created) as? [String] {
            userCreatedRecipeIDs = Set(createdIDs)
        }
        if let favoritedIDs = defaults.array(forKey: CacheKeys.favorited) as? [String] {
            userFavoritedRecipeIDs = Set(favoritedIDs)
        }
    }

    private func persistRecipeReferences() {
        let defaults = UserDefaults.standard
        defaults.set(Array(userSavedRecipeIDs), forKey: CacheKeys.saved)
        defaults.set(Array(userCreatedRecipeIDs), forKey: CacheKeys.created)
        defaults.set(Array(userFavoritedRecipeIDs), forKey: CacheKeys.favorited)
    }
    
    // MARK: - Recipe Upload (Single Instance)
    
    /// Upload a recipe to CloudKit (creates single master record)
    func uploadRecipe(_ recipe: Recipe, fromLLM: Bool = false, beforePhoto: UIImage? = nil) async throws -> String {
        // Check if recipe already exists
        if let existingID = await checkRecipeExists(recipe.name, recipe.description) {
            print("✅ Recipe already exists with ID: \(existingID)")
            return existingID
        }
        
        // Create unique recipe ID
        let recipeID = recipe.id.uuidString
        let record = CKRecord(recordType: "Recipe", recordID: CKRecord.ID(recordName: recipeID))
        
        // Set recipe fields
        record["id"] = recipeID
        record["ownerID"] = getCurrentUserID() ?? "anonymous"
        record["ownerName"] = parent?.currentUser?.displayName ?? "Anonymous Chef"
        record["title"] = recipe.name
        record["description"] = recipe.description
        record["createdAt"] = Date()
        // Recipes saved to the user's private database are not globally public by default.
        record["isPublic"] = Int64(0)
        record["fromLLM"] = fromLLM ? 1 : 0
        
        // Encode complex data as JSON
        record["ingredients"] = try encodeToJSON(recipe.ingredients)
        record["instructions"] = try encodeToJSON(recipe.instructions)
        record["nutrition"] = try encodeToJSON(recipe.nutrition)
        record["tags"] = recipe.tags
        
        // Set metadata
        record["cookingTime"] = Int64(recipe.cookTime)
        record["prepTime"] = Int64(recipe.prepTime)
        record["servings"] = Int64(recipe.servings)
        record["difficulty"] = recipe.difficulty.rawValue
        record["cuisine"] = ""  // Recipe doesn't have cuisine field
        record["mealType"] = "" // Recipe doesn't have mealType field
        
        // Initial counts
        record["likeCount"] = Int64(0)
        record["commentCount"] = Int64(0)
        record["viewCount"] = Int64(0)
        record["shareCount"] = Int64(0)
        record["saveCount"] = Int64(0)
        record["rating"] = 0.0
        record["ratingCount"] = Int64(0)
        
        // Upload before photo if provided (this is the fridge photo shared by all recipes from the same generation)
        if let beforePhoto = beforePhoto {
            print("📸 CloudKit: Uploading BEFORE (fridge) photo for recipe '\(recipe.name)' with ID: \(recipeID)")
            let beforePhotoAsset = try await uploadImageAsset(beforePhoto, named: "before_\(recipeID)")
            record["beforePhotoAsset"] = beforePhotoAsset
            print("✅ CloudKit: BEFORE (fridge) photo uploaded successfully for recipe '\(recipe.name)' (ID: \(recipeID))")
            print("    ℹ️ This fridge photo is shared across all recipes from the same generation")
        } else {
            print("⚠️ CloudKit: No BEFORE (fridge) photo provided for recipe '\(recipe.name)' (ID: \(recipeID))")
        }
        
        // Save to CloudKit - use private database for user's own recipes
        do {
            let savedRecord = try await privateDatabase.save(record)
            print("✅ Recipe saved to CloudKit with ID: \(savedRecord.recordID.recordName)")
        } catch let error as CKError {
            // If record already exists, just update the reference
            if error.code == .serverRecordChanged || error.code == .unknownItem {
                print("⚠️ Recipe already exists in CloudKit: \(recipeID)")
                // Try to fetch the existing record
                do {
                    _ = try await privateDatabase.record(for: record.recordID)
                    print("✅ Using existing recipe: \(recipeID)")
                } catch {
                    // If we can't fetch it, throw the original error
                    throw error
                }
            } else {
                throw error
            }
        }
        
        // Cache locally
        cachedRecipes[recipeID] = recipe
        
        // Add to user's created recipes
        if fromLLM {
            try await addRecipeToUserProfile(recipeID, type: .created)
        }
        
        // Trigger manual sync after saving a recipe
        Task {
            await parent?.triggerManualSync()
        }
        
        print("✅ Recipe processed in CloudKit: \(recipeID)")
        return recipeID
    }
    
    // MARK: - Efficient Background Sync
    
    /// Fetch only missing recipes based on provided local recipe IDs (optimized)
    func fetchMissingRecipes(localRecipeIDs: Set<String>) async throws -> [Recipe] {
        print("🔍 Starting optimized recipe sync with \(localRecipeIDs.count) local recipes...")
        
        // Get all recipe IDs from CloudKit (lightweight query)
        let cloudKitRecipeIDs = try await fetchAllRecipeIDs()
        print("☁️ Found \(cloudKitRecipeIDs.count) recipes in CloudKit")
        print("📱 Local recipes provided: \(localRecipeIDs.count)")
        
        // Find missing recipe IDs (exist in CloudKit but not locally)
        let missingRecipeIDs = cloudKitRecipeIDs.subtracting(localRecipeIDs)
        print("📋 Missing recipes to sync: \(missingRecipeIDs.count)")
        
        if missingRecipeIDs.isEmpty {
            print("✅ All recipes are already synced - no download needed")
            return []
        }
        
        // Log what we're syncing for transparency
        print("🔄 Syncing missing recipe IDs: \(Array(missingRecipeIDs).prefix(5))\(missingRecipeIDs.count > 5 ? "..." : "")")
        
        // Batch download missing recipes
        var syncedRecipes: [Recipe] = []
        let batchSize = 10 // Download in batches to avoid memory issues
        
        for batch in Array(missingRecipeIDs).chunked(into: batchSize) {
            print("📥 Downloading batch of \(batch.count) recipes...")
            
            let batchRecipes = await withTaskGroup(of: Recipe?.self) { group in
                for recipeID in batch {
                    group.addTask {
                        do {
                            let recipe = try await self.fetchRecipeFromCloudKit(recipeID)
                            print("✅ Downloaded recipe: \(recipe.name) (\(recipeID))")
                            return recipe
                        } catch {
                            print("❌ Failed to fetch recipe \(recipeID): \(error)")
                            return nil
                        }
                    }
                }
                
                var recipes: [Recipe] = []
                for await recipe in group {
                    if let recipe = recipe {
                        recipes.append(recipe)
                    }
                }
                return recipes
            }
            
            syncedRecipes.append(contentsOf: batchRecipes)
            print("✅ Synced batch: \(batchRecipes.count) recipes")
        }
        
        print("🎉 Optimized sync complete: Downloaded \(syncedRecipes.count) new recipes")
        return syncedRecipes
    }
    
    /// Legacy method for backwards compatibility - uses cached recipes as local set
    func fetchMissingRecipes() async throws -> [Recipe] {
        print("🔍 Starting efficient recipe sync - checking for missing recipes...")
        
        // Get locally cached recipe IDs
        let localRecipeIDs = Set(cachedRecipes.keys)
        
        // Use the optimized method
        return try await fetchMissingRecipes(localRecipeIDs: localRecipeIDs)
    }
    
    /// Background sync that doesn't block UI - optimized to use local recipe IDs
    @MainActor
    func performBackgroundSync(localRecipeIDs: Set<String>? = nil) {
        Task.detached(priority: .background) {
            do {
                let startTime = Date()
                print("🚀 Starting optimized background sync...")
                
                // Use provided local IDs or fall back to cached recipes
                let localIDs: Set<String>
                if let providedIDs = localRecipeIDs {
                    localIDs = providedIDs
                } else {
                    localIDs = await MainActor.run { Set(self.cachedRecipes.keys) }
                }
                
                let newRecipes = try await self.fetchMissingRecipes(localRecipeIDs: localIDs)
                await self.syncMissingPhotos(for: newRecipes)
                
                let duration = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    print("🎉 Optimized background sync completed in \(String(format: "%.2f", duration))s")
                    print("   - New recipes synced: \(newRecipes.count)")
                    print("   - Total cached recipes: \(self.cachedRecipes.count)")
                }
            } catch {
                await MainActor.run {
                    print("❌ Background sync failed: \(error)")
                }
            }
        }
    }
    
    /// Optimized photo sync - checks PhotoStorageManager first to avoid unnecessary downloads
    private func syncMissingPhotos(for recipes: [Recipe]) async {
        print("📸 Starting optimized photo sync for \(recipes.count) recipes...")
        
        // Get recipe IDs that already have photos to avoid unnecessary downloads
        let recipeIDsWithPhotos = await MainActor.run {
            PhotoStorageManager.shared.getRecipeIDsWithPhotos()
        }
        
        let recipesToSync = recipes.filter { recipe in
            !recipeIDsWithPhotos.contains(recipe.id)
        }
        
        print("📸 PhotoStorageManager check: \(recipeIDsWithPhotos.count) recipes already have photos")
        print("📸 Filtered to \(recipesToSync.count) recipes needing photo sync")
        
        if recipesToSync.isEmpty {
            print("✅ All recipes already have photos in PhotoStorageManager - no download needed")
            return
        }
        
        // Log what we're syncing for transparency
        let recipeNames = recipesToSync.prefix(3).map { $0.name }
        print("🔄 Syncing photos for: \(recipeNames.joined(separator: ", "))\(recipesToSync.count > 3 ? "..." : "")")
        
        // Process in smaller batches to avoid overwhelming memory
        let photoBatches = recipesToSync.chunked(into: 3) // Even smaller batches for photos
        
        for (batchIndex, batch) in photoBatches.enumerated() {
            print("📸 Processing photo batch \(batchIndex + 1)/\(photoBatches.count) (\(batch.count) recipes)")
            
            await withTaskGroup(of: Void.self) { group in
                for recipe in batch {
                    group.addTask {
                        let recipeID = recipe.id
                        
                        // Double-check PhotoStorageManager to avoid race conditions
                        let hasPhotos = await MainActor.run {
                            PhotoStorageManager.shared.hasAnyPhotos(for: recipeID)
                        }
                        
                        if hasPhotos {
                            print("📸 Recipe \(recipe.name) photos found in PhotoStorageManager - skipping download")
                            return
                        }
                        
                        // Fetch photos from CloudKit
                        do {
                            print("📥 Downloading photos for recipe: \(recipe.name)")
                            let (beforePhoto, afterPhoto) = try await self.fetchRecipePhotos(for: recipeID.uuidString)
                            
                            // Store photos in PhotoStorageManager
                            await MainActor.run {
                                PhotoStorageManager.shared.storePhotos(
                                    fridgePhoto: beforePhoto,
                                    mealPhoto: afterPhoto,
                                    for: recipeID
                                )
                            }
                            
                            let photoStatus = "before: \(beforePhoto != nil ? "✓" : "✗"), after: \(afterPhoto != nil ? "✓" : "✗")"
                            print("✅ Synced photos for \(recipe.name): \(photoStatus)")
                        } catch {
                            print("❌ Failed to sync photos for \(recipe.name): \(error)")
                        }
                    }
                }
            }
            
            print("✅ Completed photo batch \(batchIndex + 1)/\(photoBatches.count)")
        }
        
        print("📸 Optimized photo sync completed: processed \(recipesToSync.count) recipes")
    }
    
    /// Get all recipe IDs from CloudKit (lightweight query)
    private func fetchAllRecipeIDs() async throws -> Set<String> {
        print("🔍 Fetching all recipe IDs from CloudKit...")
        
        let predicate = NSPredicate(value: true) // Get all recipes
        let query = CKQuery(recordType: "Recipe", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        var allRecipeIDs: Set<String> = []
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let operation: CKQueryOperation
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }
            
            // Set desired keys to only fetch ID (minimal data transfer)
            operation.desiredKeys = ["id"]
            operation.resultsLimit = 100 // Process in chunks
            
            let (records, nextCursor) = try await withCheckedThrowingContinuation { continuation in
                var fetchedRecords: [CKRecord] = []
                
                operation.recordMatchedBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        fetchedRecords.append(record)
                    case .failure(let error):
                        print("❌ Failed to fetch record \(recordID): \(error)")
                    }
                }
                
                operation.queryResultBlock = { result in
                    switch result {
                    case .success(let cursor):
                        continuation.resume(returning: (fetchedRecords, cursor))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                // Try both databases
                privateDatabase.add(operation)
            }
            
            // Extract recipe IDs
            for record in records {
                if let recipeID = record["id"] as? String {
                    allRecipeIDs.insert(recipeID)
                }
            }
            
            cursor = nextCursor
            print("📊 Fetched \(records.count) recipe IDs (total: \(allRecipeIDs.count))")
        } while cursor != nil
        
        // Also check public database
        do {
            let publicOperation = CKQueryOperation(query: query)
            publicOperation.desiredKeys = ["id"]
            publicOperation.resultsLimit = 100
            
            let (publicRecords, _): ([CKRecord], CKQueryOperation.Cursor?) = try await withCheckedThrowingContinuation { continuation in
                var fetchedRecords: [CKRecord] = []
                
                publicOperation.recordMatchedBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        fetchedRecords.append(record)
                    case .failure(let error):
                        print("❌ Failed to fetch public record \(recordID): \(error)")
                    }
                }
                
                publicOperation.queryResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume(returning: (fetchedRecords, nil))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                publicDatabase.add(publicOperation)
            }
            
            // Add public recipe IDs
            for record in publicRecords {
                if let recipeID = record["id"] as? String {
                    allRecipeIDs.insert(recipeID)
                }
            }
            
            print("📊 Added \(publicRecords.count) public recipe IDs")
        } catch {
            print("⚠️ Failed to fetch public recipes: \(error)")
        }
        
        print("✅ Total recipe IDs found: \(allRecipeIDs.count)")
        return allRecipeIDs
    }
    
    /// Fetch a single recipe from CloudKit (internal method)
    private func fetchRecipeFromCloudKit(_ recipeID: String) async throws -> Recipe {
        let recordID = CKRecord.ID(recordName: recipeID)
        
        do {
            // Try private database first
            let record = try await privateDatabase.record(for: recordID)
            let recipe = try parseRecipeFromRecord(record)
            cachedRecipes[recipeID] = recipe
            print("☁️ Recipe fetched from private CloudKit: \(recipeID)")
            return recipe
        } catch {
            // Try public database
            let record = try await publicDatabase.record(for: recordID)
            let recipe = try parseRecipeFromRecord(record)
            cachedRecipes[recipeID] = recipe
            print("☁️ Recipe fetched from public CloudKit: \(recipeID)")
            return recipe
        }
    }
    
    // MARK: - Recipe Fetching
    
    /// Fetch a recipe by ID (checks cache first, then CloudKit)
    func fetchRecipe(by recipeID: String) async throws -> Recipe {
        // Check local cache first
        if let cached = cachedRecipes[recipeID] {
            print("📱 Recipe found in cache: \(recipeID)")
            return cached
        }
        
        // Fetch from CloudKit - try private database first, then public
        let recordID = CKRecord.ID(recordName: recipeID)
        
        do {
            // Try private database first (user's own recipes)
            let record = try await privateDatabase.record(for: recordID)
            let recipe = try parseRecipeFromRecord(record)
            cachedRecipes[recipeID] = recipe
            print("☁️ Recipe fetched from private CloudKit: \(recipeID)")
            return recipe
        } catch {
            // If not in private, try public database
            let record = try await publicDatabase.record(for: recordID)
            
            // Parse recipe
            let recipe = try parseRecipeFromRecord(record)
            
            // Cache locally
            cachedRecipes[recipeID] = recipe
            
            // Increment view count
            await incrementViewCount(for: recipeID)
            
            print("☁️ Recipe fetched from public CloudKit: \(recipeID)")
            return recipe
        }
    }
    
    /// Check if a recipe record exists in CloudKit by ID.
    func recipeExists(with recipeID: String) async -> Bool {
        let recordID = CKRecord.ID(recordName: recipeID)
        
        if (try? await privateDatabase.record(for: recordID)) != nil {
            return true
        }
        
        if (try? await publicDatabase.record(for: recordID)) != nil {
            return true
        }
        
        return false
    }
    
    /// Returns an existing recipe ID when the same recipe content already exists.
    func existingRecipeID(name: String, description: String) async -> String? {
        return await checkRecipeExists(name, description)
    }
    
    /// Batch fetch recipes by IDs (optimized with concurrent downloads)
    func fetchRecipes(by recipeIDs: [String]) async throws -> [Recipe] {
        print("📥 Batch fetching \(recipeIDs.count) recipes...")
        
        // Separate cached and missing recipes
        var cachedRecipes: [Recipe] = []
        var missingIDs: [String] = []
        
        for id in recipeIDs {
            if let cached = self.cachedRecipes[id] {
                cachedRecipes.append(cached)
                print("📱 Recipe \(id) found in cache")
            } else {
                missingIDs.append(id)
            }
        }
        
        print("📊 Cache hit: \(cachedRecipes.count), Cache miss: \(missingIDs.count)")
        
        // Concurrent download of missing recipes
        let downloadedRecipes = await withTaskGroup(of: Recipe?.self) { group in
            for id in missingIDs {
                group.addTask {
                    do {
                        return try await self.fetchRecipeFromCloudKit(id)
                    } catch {
                        print("❌ Failed to fetch recipe \(id): \(error)")
                        return nil
                    }
                }
            }
            
            var recipes: [Recipe] = []
            for await recipe in group {
                if let recipe = recipe {
                    recipes.append(recipe)
                }
            }
            return recipes
        }
        
        let allRecipes = cachedRecipes + downloadedRecipes
        print("✅ Batch fetch complete: \(allRecipes.count) recipes")
        return allRecipes
    }
    
    // MARK: - User Profile Recipe Management
    
    /// Add recipe reference to user profile
    func addRecipeToUserProfile(_ recipeID: String, type: RecipeListType) async throws {
        guard let userID = getCurrentUserID() else { return }

        if type == .saved {
            let wasInserted = try await upsertSavedRecipeReference(userID: userID, recipeID: recipeID)
            userSavedRecipeIDs.insert(recipeID)
            persistRecipeReferences()

            if wasInserted {
                await incrementSaveCount(for: recipeID)
                print("✅ Added recipe \(recipeID) to SavedRecipe references")
            } else {
                print("ℹ️ SavedRecipe reference already exists for recipe \(recipeID)")
            }
            return
        }

        // Created / favorited lists are persisted locally (UserDefaults) and derived from CloudKit queries when needed.
        // This avoids schema drift from ad-hoc profile list fields.
        switch type {
        case .created:
            userCreatedRecipeIDs.insert(recipeID)
        case .favorited:
            userFavoritedRecipeIDs.insert(recipeID)
        case .saved:
            break
        }
        persistRecipeReferences()
    }
    
    /// Remove recipe reference from user profile
    func removeRecipeFromUserProfile(_ recipeID: String, type: RecipeListType) async throws {
        guard let userID = getCurrentUserID() else { return }

        if type == .saved {
            let wasRemoved = try await removeSavedRecipeReference(userID: userID, recipeID: recipeID)
            userSavedRecipeIDs.remove(recipeID)
            persistRecipeReferences()

            if wasRemoved {
                await decrementSaveCount(for: recipeID)
                print("✅ Removed recipe \(recipeID) from SavedRecipe references")
            } else {
                print("ℹ️ SavedRecipe reference did not exist for recipe \(recipeID)")
            }
            return
        }

        // Created / favorited lists are persisted locally.
        switch type {
        case .saved:
            break
        case .created:
            userCreatedRecipeIDs.remove(recipeID)
        case .favorited:
            userFavoritedRecipeIDs.remove(recipeID)
        }
        persistRecipeReferences()
    }
    
    /// Load user's recipe references
    func loadUserRecipeReferences() {
        // Load locally cached references for instant availability.
        loadCachedRecipeReferences()

        Task {
            guard UnifiedAuthManager.shared.isAuthenticated else { return }
            guard let userID = getCurrentUserID() else { return }

            do {
                let savedFromReferences = try await fetchSavedRecipeIDsFromReferences(userID: userID)
                let mergedSaved = userSavedRecipeIDs.union(savedFromReferences)
                await MainActor.run {
                    self.userSavedRecipeIDs = mergedSaved
                    self.persistRecipeReferences()
                }
            } catch {
                print("⚠️ Failed to refresh SavedRecipe references: \(error)")
            }
        }
    }
    
    /// Get user's saved recipes (optimized)
    func getUserSavedRecipes() async throws -> [Recipe] {
        print("📖 Getting user's saved recipes...")
        guard let userID = getCurrentUserID() else {
            return []
        }
        
        var savedIDs = userSavedRecipeIDs
        
        do {
            let savedFromReferences = try await fetchSavedRecipeIDsFromReferences(userID: userID)
            savedIDs.formUnion(savedFromReferences)
            print("✅ Loaded \(savedFromReferences.count) saved recipe references from CloudKit")
        } catch {
            print("⚠️ Failed to load SavedRecipe references: \(error)")
        }

        // Note: legacy "savedRecipeIDs" profile fields were removed to prevent schema drift.
        // Saved recipes are now sourced from SavedRecipe reference records.

        userSavedRecipeIDs = savedIDs
        
        guard !savedIDs.isEmpty else {
            return []
        }
        
        let recipes = try await fetchRecipes(by: Array(savedIDs))
        print("📖 Retrieved \(recipes.count) saved recipes")
        return recipes
    }
    
    /// Get user's created recipes (optimized)
    func getUserCreatedRecipes() async throws -> [Recipe] {
        guard UnifiedAuthManager.shared.isAuthenticated else { return [] }
        guard let userID = getCurrentUserID() else { return [] }

        let predicate = NSPredicate(format: "%K == %@", CKField.Recipe.ownerID, userID)
        let query = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.Recipe.createdAt, ascending: false)]

        var recipes: [Recipe] = []
        var createdIDs = Set<String>()

        // Prefer private recipes, but fall back to public if needed.
        do {
            let results = try await privateDatabase.records(matching: query, resultsLimit: 50)
            for (_, result) in results.matchResults {
                if case .success(let record) = result,
                   let recipe = try? parseRecipeFromRecord(record) {
                    recipes.append(recipe)
                    createdIDs.insert(recipe.id.uuidString)
                    cachedRecipes[recipe.id.uuidString] = recipe
                }
            }
        } catch {
            // Ignore private-db failures; we still attempt public.
        }

        do {
            let results = try await publicDatabase.records(matching: query, resultsLimit: 50)
            for (_, result) in results.matchResults {
                if case .success(let record) = result,
                   let recipe = try? parseRecipeFromRecord(record) {
                    recipes.append(recipe)
                    createdIDs.insert(recipe.id.uuidString)
                    cachedRecipes[recipe.id.uuidString] = recipe
                }
            }
        } catch {
            // If both fail, bubble up the public error (more likely the shared source).
            if recipes.isEmpty { throw error }
        }

        // Deduplicate by id and keep newest ordering.
        var unique: [UUID: Recipe] = [:]
        for recipe in recipes {
            unique[recipe.id] = recipe
        }
        let sorted = unique.values.sorted { $0.createdAt > $1.createdAt }

        userCreatedRecipeIDs = createdIDs
        persistRecipeReferences()

        return sorted
    }
    
    /// Get user's favorited recipes (optimized)
    func getUserFavoritedRecipes() async throws -> [Recipe] {
        // Favorited recipe IDs are stored locally for UX speed; CloudKit schema does not guarantee a dedicated favorites list.
        // If needed, this can be upgraded to a CloudKit record type similar to SavedRecipe.
        guard !userFavoritedRecipeIDs.isEmpty else { return [] }
        return try await fetchRecipes(by: Array(userFavoritedRecipeIDs))
    }
    
    // MARK: - Recipe Sharing
    
    /// Generate a shareable link for a recipe
    func generateShareLink(for recipeID: String) -> URL {
        // Prefer universal links for viral sharing (works even without app install).
        var components = URLComponents()
        components.scheme = "https"
        components.host = "snapchef.app"
        components.path = "/recipe/\(recipeID)"

        if let url = components.url {
            return url
        }

        return URL(string: "https://snapchef.app")!
    }
    
    /// Handle incoming recipe share link
    func handleRecipeShareLink(_ url: URL) async throws -> Recipe {
        let scheme = (url.scheme ?? "").lowercased()
        let host = (url.host ?? "").lowercased()
        let pathParts = url.pathComponents.filter { $0 != "/" }

        if scheme == "snapchef", host == "recipe", let recipeID = pathParts.last, !recipeID.isEmpty {
            return try await fetchRecipe(by: recipeID)
        }

        if scheme == "https",
           (host == "snapchef.app" || host == "www.snapchef.app"),
           pathParts.count >= 2,
           pathParts[0].lowercased() == "recipe" {
            let recipeID = pathParts[1]
            guard !recipeID.isEmpty else { throw RecipeError.invalidShareLink }
            return try await fetchRecipe(by: recipeID)
        }

        throw RecipeError.invalidShareLink
    }
    
    // MARK: - Recipe Search
    
    /// Search for recipes by query
    func searchRecipes(query: String, limit: Int = 20) async throws -> [Recipe] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@ OR description CONTAINS[cd] %@", query, query)
        let ckQuery = CKQuery(recordType: "Recipe", predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        let (matchResults, _) = try await publicDatabase.records(matching: ckQuery, resultsLimit: limit)
        
        var recipes: [Recipe] = []
        for (_, result) in matchResults {
            if let record = try? result.get() {
                if let recipe = try? parseRecipeFromRecord(record) {
                    recipes.append(recipe)
                    // Cache the recipe
                    cachedRecipes[recipe.id.uuidString] = recipe
                }
            }
        }
        
        return recipes
    }
    
    // MARK: - Public Sync Methods
    
    /// Check if local cache is up to date with CloudKit
    func isCacheUpToDate() async throws -> Bool {
        print("🔍 Checking if cache is up to date...")
        
        let cloudKitRecipeIDs = try await fetchAllRecipeIDs()
        let localRecipeIDs = Set(cachedRecipes.keys)
        
        let isUpToDate = cloudKitRecipeIDs.isSubset(of: localRecipeIDs)
        print("📊 Cache status: \(isUpToDate ? "✅ Up to date" : "⚠️ Needs sync")")
        print("   CloudKit: \(cloudKitRecipeIDs.count) recipes")
        print("   Local: \(localRecipeIDs.count) recipes")
        
        return isUpToDate
    }
    
    /// Get sync statistics
    func getSyncStats() async throws -> SyncStats {
        print("📊 Calculating sync statistics...")
        
        let cloudKitRecipeIDs = try await fetchAllRecipeIDs()
        let localRecipeIDs = Set(cachedRecipes.keys)
        let missingRecipeIDs = cloudKitRecipeIDs.subtracting(localRecipeIDs)
        
        let photosWithRecipes = await MainActor.run {
            PhotoStorageManager.shared.getRecipeIDsWithPhotos()
        }
        
        let localRecipeUUIDs = Set(localRecipeIDs.compactMap { UUID(uuidString: $0) })
        let recipesNeedingPhotos = localRecipeUUIDs.subtracting(photosWithRecipes)
        
        let stats = SyncStats(
            totalCloudKitRecipes: cloudKitRecipeIDs.count,
            totalLocalRecipes: localRecipeIDs.count,
            missingRecipes: missingRecipeIDs.count,
            recipesWithPhotos: photosWithRecipes.count,
            recipesNeedingPhotos: recipesNeedingPhotos.count
        )
        
        print("📊 Sync Stats:")
        print("   Total CloudKit recipes: \(stats.totalCloudKitRecipes)")
        print("   Total local recipes: \(stats.totalLocalRecipes)")
        print("   Missing recipes: \(stats.missingRecipes)")
        print("   Recipes with photos: \(stats.recipesWithPhotos)")
        print("   Recipes needing photos: \(stats.recipesNeedingPhotos)")
        
        return stats
    }
    
    /// Perform intelligent sync (only fetch what's needed)
    func performIntelligentSync() async throws -> SyncResult {
        print("🧠 Starting intelligent sync...")
        
        let startTime = Date()
        
        // Get missing recipes
        let newRecipes = try await fetchMissingRecipes()
        
        // Sync photos for recipes that need them
        await syncMissingPhotos(for: Array(cachedRecipes.values))
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        let result = SyncResult(
            newRecipesSynced: newRecipes.count,
            photosDownloaded: 0, // We could track this more precisely if needed
            duration: duration,
            success: true
        )
        
        print("🧠 Intelligent sync completed in \(String(format: "%.2f", duration))s")
        print("   New recipes: \(result.newRecipesSynced)")
        
        return result
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserID() -> String? {
        // Try both keys for compatibility
        if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
            return userID
        }
        return UserDefaults.standard.string(forKey: "currentUserRecordID")
    }

    private func savedRecipeRecordID(userID: String, recipeID: String) -> CKRecord.ID {
        let sanitizedUserID = userID.replacingOccurrences(of: "/", with: "_")
        let sanitizedRecipeID = recipeID.replacingOccurrences(of: "/", with: "_")
        return CKRecord.ID(recordName: "saved_\(sanitizedUserID)_\(sanitizedRecipeID)")
    }

    private func upsertSavedRecipeReference(userID: String, recipeID: String) async throws -> Bool {
        let recordID = savedRecipeRecordID(userID: userID, recipeID: recipeID)

        do {
            _ = try await privateDatabase.record(for: recordID)
            return false
        } catch let ckError as CKError where ckError.code == .unknownItem {
            let record = CKRecord(recordType: CloudKitConfig.savedRecipeRecordType, recordID: recordID)
            record[CKField.SavedRecipe.userID] = userID
            record[CKField.SavedRecipe.recipeID] = recipeID
            record[CKField.SavedRecipe.savedAt] = Date()
            _ = try await privateDatabase.save(record)
            return true
        }
    }

    private func removeSavedRecipeReference(userID: String, recipeID: String) async throws -> Bool {
        let recordID = savedRecipeRecordID(userID: userID, recipeID: recipeID)

        do {
            _ = try await privateDatabase.deleteRecord(withID: recordID)
            return true
        } catch let ckError as CKError where ckError.code == .unknownItem {
            let predicate = NSPredicate(
                format: "%K == %@ AND %K == %@",
                CKField.SavedRecipe.userID, userID,
                CKField.SavedRecipe.recipeID, recipeID
            )
            let query = CKQuery(recordType: CloudKitConfig.savedRecipeRecordType, predicate: predicate)
            let (matchResults, _) = try await privateDatabase.records(matching: query, resultsLimit: 20)

            var deletedAny = false
            for (matchRecordID, result) in matchResults {
                guard case .success = result else { continue }
                do {
                    _ = try await privateDatabase.deleteRecord(withID: matchRecordID)
                    deletedAny = true
                } catch {
                    print("⚠️ Failed deleting legacy SavedRecipe record \(matchRecordID.recordName): \(error)")
                }
            }
            return deletedAny
        }
    }

    private func fetchSavedRecipeIDsFromReferences(userID: String) async throws -> Set<String> {
        let predicate = NSPredicate(format: "%K == %@", CKField.SavedRecipe.userID, userID)
        let query = CKQuery(recordType: CloudKitConfig.savedRecipeRecordType, predicate: predicate)

        let (matchResults, _) = try await privateDatabase.records(
            matching: query,
            desiredKeys: [CKField.SavedRecipe.recipeID],
            resultsLimit: 500
        )

        var savedIDs = Set<String>()
        for (_, result) in matchResults {
            guard case .success(let record) = result,
                  let recipeID = record[CKField.SavedRecipe.recipeID] as? String,
                  !recipeID.isEmpty else { continue }
            savedIDs.insert(recipeID)
        }
        return savedIDs
    }
    
    private func checkRecipeExists(_ name: String, _ description: String) async -> String? {
        // Only use title for query since description is not queryable
        let predicate = NSPredicate(format: "title == %@", name)
        let query = CKQuery(recordType: "Recipe", predicate: predicate)
        
        do {
            let (matchResults, _) = try await publicDatabase.records(matching: query, resultsLimit: 1)
            if let record = try? matchResults.first?.1.get() {
                return record["id"] as? String
            }
        } catch {
            print("Error checking recipe existence: \(error)")
        }
        
        return nil
    }
    
    private func parseRecipeFromRecord(_ record: CKRecord) throws -> Recipe {
        guard let id = record["id"] as? String,
              let title = record["title"] as? String,
              let description = record["description"] as? String else {
            throw RecipeError.invalidRecord
        }
        
        // Decode JSON fields
        let ingredients: [Ingredient] = (try? decodeFromJSON(record["ingredients"] as? String)) ?? []
        let instructions: [String] = (try? decodeFromJSON(record["instructions"] as? String)) ?? []
        let nutrition: Nutrition? = try? decodeFromJSON(record["nutrition"] as? String)
        
        // Create dietary info
        let dietaryInfo = DietaryInfo(
            isVegetarian: false,
            isVegan: false,
            isGlutenFree: false,
            isDairyFree: false
        )
        
        let recipe = Recipe(
            id: UUID(uuidString: id) ?? UUID(),
            ownerID: record["ownerID"] as? String,
            name: title,
            description: description,
            ingredients: ingredients,
            instructions: instructions,
            cookTime: Int(record["cookingTime"] as? Int64 ?? 0),
            prepTime: Int(record["prepTime"] as? Int64 ?? 0),
            servings: Int(record["servings"] as? Int64 ?? 4),
            difficulty: Recipe.Difficulty(rawValue: record["difficulty"] as? String ?? "Medium") ?? .medium,
            nutrition: nutrition ?? Nutrition(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: nil, sugar: nil, sodium: nil),
            imageURL: nil,
            createdAt: record["createdAt"] as? Date ?? Date(),
            tags: record["tags"] as? [String] ?? [],
            dietaryInfo: dietaryInfo,
            isDetectiveRecipe: false,
            cookingTechniques: [],
            flavorProfile: nil,
            secretIngredients: [],
            proTips: [],
            visualClues: [],
            shareCaption: ""
        )
        
        return recipe
    }
    
    private func encodeToJSON<T: Encodable>(_ object: T) throws -> String {
        let data = try JSONEncoder().encode(object)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func decodeFromJSON<T: Decodable>(_ string: String?) throws -> T {
        guard let string = string,
              let data = string.data(using: .utf8) else {
            throw RecipeError.invalidJSON
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Analytics
    
    private func incrementViewCount(for recipeID: String) async {
        let recordID = CKRecord.ID(recordName: recipeID)
        
        // Only try public database for view counts (views are for public recipes)
        do {
            let record = try await publicDatabase.record(for: recordID)
            let currentCount = record["viewCount"] as? Int64 ?? 0
            record["viewCount"] = currentCount + 1
            _ = try await publicDatabase.save(record)
            print("✅ View count incremented for public recipe: \(recipeID)")
        } catch {
            // This is expected for private recipes - they don't need view tracking
            print("ℹ️ Could not increment view count for recipe \(recipeID) - likely a private recipe. This is normal.")
        }
    }
    
    private func incrementSaveCount(for recipeID: String) async {
        let recordID = CKRecord.ID(recordName: recipeID)
        
        // Try private database first (user's own recipes)
        do {
            let record = try await privateDatabase.record(for: recordID)
            let currentCount = record["saveCount"] as? Int64 ?? 0
            record["saveCount"] = currentCount + 1
            _ = try await privateDatabase.save(record)
            print("✅ Save count incremented in private database for recipe: \(recipeID)")
            return
        } catch {
            print("⚠️ Recipe not found in private database, trying public: \(error)")
        }
        
        // Try public database if not in private
        do {
            let record = try await publicDatabase.record(for: recordID)
            let currentCount = record["saveCount"] as? Int64 ?? 0
            record["saveCount"] = currentCount + 1
            _ = try await publicDatabase.save(record)
            print("✅ Save count incremented in public database for recipe: \(recipeID)")
        } catch {
            // This is expected for user's own recipes that are only in private database
            print("ℹ️ Could not increment save count for recipe \(recipeID) - likely a private recipe. This is normal.")
        }
    }

    private func decrementSaveCount(for recipeID: String) async {
        let recordID = CKRecord.ID(recordName: recipeID)

        do {
            let record = try await privateDatabase.record(for: recordID)
            let currentCount = record["saveCount"] as? Int64 ?? 0
            record["saveCount"] = max(0, currentCount - 1)
            _ = try await privateDatabase.save(record)
            print("✅ Save count decremented in private database for recipe: \(recipeID)")
            return
        } catch {
            print("⚠️ Recipe not found in private database for decrement, trying public: \(error)")
        }

        do {
            let record = try await publicDatabase.record(for: recordID)
            let currentCount = record["saveCount"] as? Int64 ?? 0
            record["saveCount"] = max(0, currentCount - 1)
            _ = try await publicDatabase.save(record)
            print("✅ Save count decremented in public database for recipe: \(recipeID)")
        } catch {
            print("ℹ️ Could not decrement save count for recipe \(recipeID) - likely local-only record.")
        }
    }
    
    // MARK: - Photo Management
    
    /// Upload an image as a CKAsset
    private func uploadImageAsset(_ image: UIImage, named filename: String) async throws -> CKAsset {
        let isBeforePhoto = filename.starts(with: "before_")
        let photoType = isBeforePhoto ? "FRIDGE" : "MEAL"
        
        print("🔧 CloudKit: Preparing \(photoType) image asset '\(filename)' for upload")
        
        // Compress image to reduce size (JPEG at 80% quality)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ CloudKit: Failed to compress \(photoType) image '\(filename)'")
            throw RecipeError.uploadFailed
        }
        
        let imageSizeInMB = Double(imageData.count) / (1_024.0 * 1_024.0)
        print("📏 CloudKit: \(photoType) image '\(filename)' compressed to \(String(format: "%.2f", imageSizeInMB)) MB")
        
        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).jpg")
        
        try imageData.write(to: fileURL)
        print("💾 CloudKit: Temporary file created for \(photoType) photo at: \(fileURL.lastPathComponent)")
        
        // Create CKAsset
        let asset = CKAsset(fileURL: fileURL)
        print("📦 CloudKit: CKAsset created for \(photoType) photo '\(filename)', ready for upload")
        
        return asset
    }
    
    /// Update the after photo for a recipe
    func updateAfterPhoto(for recipeID: String, afterPhoto: UIImage) async throws {
        let recordID = CKRecord.ID(recordName: recipeID)
        
        print("📸 CloudKit: Starting AFTER photo upload for recipe ID: \(recipeID)")
        
        do {
            // Try private database first (user's own recipes)
            let record = try await privateDatabase.record(for: recordID)
            let recipeTitle = record["title"] as? String ?? "Unknown Recipe"
            
            print("📸 CloudKit: Uploading AFTER photo for recipe '\(recipeTitle)' with ID: \(recipeID)")
            
            // Upload after photo
            let afterPhotoAsset = try await uploadImageAsset(afterPhoto, named: "after_\(recipeID)")
            record["afterPhotoAsset"] = afterPhotoAsset
            
            // Save updated record
            _ = try await privateDatabase.save(record)
            print("✅ CloudKit: AFTER photo uploaded successfully for recipe '\(recipeTitle)' (ID: \(recipeID)) - Private DB")
        } catch {
            // If not in private, try public database
            let record = try await publicDatabase.record(for: recordID)
            let recipeTitle = record["title"] as? String ?? "Unknown Recipe"
            
            print("📸 CloudKit: Uploading AFTER photo for recipe '\(recipeTitle)' with ID: \(recipeID)")
            
            // Upload after photo
            let afterPhotoAsset = try await uploadImageAsset(afterPhoto, named: "after_\(recipeID)")
            record["afterPhotoAsset"] = afterPhotoAsset
            
            // Save updated record
            _ = try await publicDatabase.save(record)
            print("✅ CloudKit: AFTER photo uploaded successfully for recipe '\(recipeTitle)' (ID: \(recipeID)) - Public DB")
        }
    }
    
    /// Fetch photos for a recipe
    func fetchRecipePhotos(for recipeID: String) async throws -> (before: UIImage?, after: UIImage?) {
        let recordID = CKRecord.ID(recordName: recipeID)
        
        print("🔍 CloudKit: Fetching photos for recipe ID: \(recipeID)")
        
        do {
            // Try private database first
            let record = try await privateDatabase.record(for: recordID)
            let recipeTitle = record["title"] as? String ?? "Unknown Recipe"
            print("🔍 CloudKit: Found recipe '\(recipeTitle)' in Private DB, fetching photos...")
            let photos = await fetchPhotosFromRecord(record, recipeTitle: recipeTitle, recipeID: recipeID)
            return photos
        } catch {
            // Try public database
            let record = try await publicDatabase.record(for: recordID)
            let recipeTitle = record["title"] as? String ?? "Unknown Recipe"
            print("🔍 CloudKit: Found recipe '\(recipeTitle)' in Public DB, fetching photos...")
            let photos = await fetchPhotosFromRecord(record, recipeTitle: recipeTitle, recipeID: recipeID)
            return photos
        }
    }
    
    /// Helper to fetch photos from a CKRecord
    private func fetchPhotosFromRecord(_ record: CKRecord, recipeTitle: String = "Unknown", recipeID: String = "Unknown") async -> (before: UIImage?, after: UIImage?) {
        var beforePhoto: UIImage?
        var afterPhoto: UIImage?
        
        // Fetch before photo
        if let beforeAsset = record["beforePhotoAsset"] as? CKAsset,
           let fileURL = beforeAsset.fileURL {
            print("📥 CloudKit: Downloading BEFORE photo for recipe '\(recipeTitle)' (ID: \(recipeID))")
            if let imageData = try? Data(contentsOf: fileURL) {
                beforePhoto = UIImage(data: imageData)
                print("✅ CloudKit: BEFORE photo retrieved successfully for recipe '\(recipeTitle)' (ID: \(recipeID))")
            } else {
                print("❌ CloudKit: Failed to load BEFORE photo data for recipe '\(recipeTitle)' (ID: \(recipeID))")
            }
        } else {
            print("⚠️ CloudKit: No BEFORE photo found for recipe '\(recipeTitle)' (ID: \(recipeID))")
        }
        
        // Fetch after photo
        if let afterAsset = record["afterPhotoAsset"] as? CKAsset,
           let fileURL = afterAsset.fileURL {
            print("📥 CloudKit: Downloading AFTER photo for recipe '\(recipeTitle)' (ID: \(recipeID))")
            if let imageData = try? Data(contentsOf: fileURL) {
                afterPhoto = UIImage(data: imageData)
                print("✅ CloudKit: AFTER photo retrieved successfully for recipe '\(recipeTitle)' (ID: \(recipeID))")
            } else {
                print("❌ CloudKit: Failed to load AFTER photo data for recipe '\(recipeTitle)' (ID: \(recipeID))")
            }
        } else {
            print("⚠️ CloudKit: No AFTER photo found for recipe '\(recipeTitle)' (ID: \(recipeID))")
        }
        
        print("📊 CloudKit: Photo fetch complete for recipe '\(recipeTitle)' - Before: \(beforePhoto != nil ? "✓" : "✗"), After: \(afterPhoto != nil ? "✓" : "✗")")
        
        return (beforePhoto, afterPhoto)
    }
}

// MARK: - Recipe List Types
enum RecipeListType {
    case saved, created, favorited
}
