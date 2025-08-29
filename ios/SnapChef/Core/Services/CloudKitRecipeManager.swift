import Foundation
import CloudKit
import SwiftUI

/// Centralized CloudKit Recipe Manager
/// Ensures single instance per recipe and reference-based access
@MainActor
class CloudKitRecipeManager: ObservableObject {
    static let shared = CloudKitRecipeManager()

    private let container = CKContainer(identifier: "iCloud.com.snapchefapp.app")
    private let publicDB: CKDatabase
    private let privateDB: CKDatabase

    // Cache for recipes
    @Published var cachedRecipes: [String: Recipe] = [:]
    @Published var userSavedRecipeIDs: Set<String> = []
    @Published var userCreatedRecipeIDs: Set<String> = []
    @Published var userFavoritedRecipeIDs: Set<String> = []
    
    // OPTIMIZATION: Photo fetch caching and deduplication
    private var photoFetchCache: [String: (before: UIImage?, after: UIImage?)] = [:]
    private var activeFetches: Set<String> = []
    private var fetchCompletionHandlers: [String: [(Result<(before: UIImage?, after: UIImage?), Error>) -> Void]] = [:]

    private init() {
        self.publicDB = container.publicCloudDatabase
        self.privateDB = container.privateCloudDatabase
        loadUserRecipeReferences()
    }

    // MARK: - Debug Methods
    
    /// Debug method to list all recipes and their owners
    @MainActor
    public func debugListAllRecipes() async {
        print("🔍 DEBUG: Listing ALL recipes in CloudKit...")
        print("==========================================")
        
        let query = CKQuery(recordType: "Recipe", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 100)
            
            print("Found \(matchResults.count) recipes in CloudKit:")
            print("")
            
            for (id, result) in matchResults {
                if case .success(let record) = result {
                    let title = record["title"] as? String ?? "Unknown"
                    let ownerID = record["ownerID"] as? String ?? "No Owner"
                    let recipeID = record["id"] as? String ?? id.recordName
                    let isPublic = record["isPublic"] as? Int64 ?? 0
                    
                    print("🍴 Recipe: \(title)")
                    print("   ID: \(recipeID)")
                    print("   Owner ID: \(ownerID)")
                    print("   Is Public: \(isPublic == 1 ? "Yes" : "No")")
                    print("")
                }
            }
            
            // Also show current user for comparison
            if let currentUserID = getCurrentUserID() {
                print("==========================================")
                print("👤 Current User ID: \(currentUserID)")
                print("==========================================")
            }
            
        } catch {
            print("❌ Error listing recipes: \(error)")
        }
    }
    
    // MARK: - Recipe Upload (Single Instance)

    /// Upload a recipe to CloudKit (creates single master record)
    func uploadRecipe(_ recipe: Recipe, fromLLM: Bool = false, beforePhoto: UIImage? = nil) async throws -> String {
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        // Only upload to CloudKit if user is authenticated
        guard UnifiedAuthManager.shared.isAuthenticated else {
            print("📱 User not authenticated - skipping CloudKit upload")
            // Return a local ID for the recipe
            return recipe.id.uuidString
        }
        
        // Check if recipe already exists
        if let existingID = await checkRecipeExists(recipe.name, recipe.description) {
            print("✅ Recipe already exists with ID: \(existingID)")
            return existingID
        }

        // Create unique recipe ID
        let recipeID = recipe.id.uuidString
        let record = CKRecord(recordType: "Recipe", recordID: CKRecord.ID(recordName: recipeID))

        // Get the current user's ID - this is critical for ownership
        guard let currentUserID = getCurrentUserID() else {
            print("❌ Cannot upload recipe without authenticated user")
            throw SnapChefError.authenticationError("User must be authenticated to upload recipes")
        }
        
        print("🔑 Setting recipe owner to user: \(currentUserID)")
        
        // Set recipe fields
        record["id"] = recipeID
        record["ownerID"] = currentUserID  // This associates the recipe with the user
        record["ownerName"] = UnifiedAuthManager.shared.currentUser?.displayName ?? "Anonymous Chef"
        record["title"] = recipe.name
        record["description"] = recipe.description
        record["createdAt"] = Date()
        record["isPublic"] = 1
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
        
        // Detective recipe fields
        record["isDetectiveRecipe"] = recipe.isDetectiveRecipe == true ? 1 : 0
        record["cookingTechniques"] = recipe.cookingTechniques
        record["flavorProfile"] = recipe.flavorProfile != nil ? try encodeToJSON(recipe.flavorProfile!) : nil
        record["secretIngredients"] = recipe.secretIngredients
        record["proTips"] = recipe.proTips
        record["visualClues"] = recipe.visualClues
        record["shareCaption"] = recipe.shareCaption

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

        // Save to CloudKit with enhanced error handling and retry logic
        logger.logSaveStart(recordType: "Recipe", database: "publicDB")
        do {
            let savedRecord = try await saveRecordWithRetry(record: record, database: publicDB, maxRetries: 3)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: "Recipe", recordID: savedRecord.recordID.recordName, database: "publicDB", duration: duration)
            print("✅ Recipe saved to CloudKit with ID: \(savedRecord.recordID.recordName)")
        } catch let error as CKError {
            // Handle specific CloudKit errors
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: "Recipe", database: "publicDB", error: error, duration: duration)
            let snapChefError = CloudKitErrorHandler.snapChefError(from: error)
            ErrorAnalytics.logError(snapChefError, context: "recipe_upload_\(recipeID)")
            
            // If record already exists, just update the reference
            if error.code == .serverRecordChanged || error.code == .unknownItem {
                print("⚠️ Recipe already exists in CloudKit: \(recipeID)")
                // Try to fetch the existing record
                do {
                    _ = try await publicDB.record(for: record.recordID)
                    print("✅ Using existing recipe: \(recipeID)")
                } catch {
                    // If we can't fetch it, throw the converted error
                    throw snapChefError
                }
            } else {
                throw snapChefError
            }
        } catch {
            // Handle non-CloudKit errors
            let snapChefError = SnapChefError.cloudKitError(
                CKError(CKError.internalError),
                recovery: .retry
            )
            ErrorAnalytics.logError(snapChefError, context: "recipe_upload_unexpected_\(recipeID)")
            throw snapChefError
        }

        // Cache locally
        cachedRecipes[recipeID] = recipe

        // Add to user's created recipes
        if fromLLM {
            try await addRecipeToUserProfile(recipeID, type: .created)
        }

        // Trigger manual sync after saving a recipe
        Task {
            await CloudKitDataManager.shared.triggerManualSync()
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

    /// Get all recipe IDs from CloudKit (lightweight query) - FILTERED BY CURRENT USER
    private func fetchAllRecipeIDs() async throws -> Set<String> {
        print("🔍 Fetching recipe IDs for current user from CloudKit...")
        
        // CRITICAL PRIVACY FIX: Only fetch current user's recipes
        guard let currentUserID = getCurrentUserID() else {
            print("⚠️ No authenticated user - returning empty recipe set")
            return Set<String>()
        }
        
        let predicate = NSPredicate(format: "ownerID == %@", currentUserID)
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

                // Try public database for recipes
                publicDB.add(operation)
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

                publicDB.add(publicOperation)
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

        print("✅ Total recipe IDs found for user \(currentUserID): \(allRecipeIDs.count)")
        return allRecipeIDs
    }

    /// Fetch a single recipe from CloudKit (internal method)
    private func fetchRecipeFromCloudKit(_ recipeID: String) async throws -> Recipe {
        let recordID = CKRecord.ID(recordName: recipeID)

        do {
            // Try public database for recipes
            let record = try await publicDB.record(for: recordID)
            let recipe = try parseRecipeFromRecord(record)
            cachedRecipes[recipeID] = recipe
            
            // Store owner information in cache
            let ownerID = record["ownerID"] as? String ?? ""
            let ownerName = record["ownerName"] as? String ?? ""
            CloudKitRecipeCache.shared.addRecipeToCache(recipe, ownerID: ownerID, ownerName: ownerName)
            
            print("☁️ Recipe fetched from public CloudKit: \(recipeID)")
            return recipe
        } catch {
            // Fallback: Try private database for user's own recipes
            let record = try await privateDB.record(for: recordID)
            let recipe = try parseRecipeFromRecord(record)
            cachedRecipes[recipeID] = recipe
            
            // Store owner information in cache
            let ownerID = record["ownerID"] as? String ?? ""
            let ownerName = record["ownerName"] as? String ?? ""
            CloudKitRecipeCache.shared.addRecipeToCache(recipe, ownerID: ownerID, ownerName: ownerName)
            
            print("☁️ Recipe fetched from private CloudKit: \(recipeID)")
            return recipe
        }
    }

    // MARK: - Recipe Fetching

    /// Fetch a recipe by ID (checks cache first, then CloudKit)
    func fetchRecipe(by recipeID: String) async throws -> Recipe {
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        // Check local cache first
        if let cached = cachedRecipes[recipeID] {
            return cached
        }
        // Fetch from CloudKit with enhanced error handling
        let recordID = CKRecord.ID(recordName: recipeID)

        do {
            // Try public database first (recipes are stored in public for social features)
            logger.logFetchStart(recordType: "Recipe", query: "byID: \(recipeID)", database: "publicDB")
            let record = try await fetchRecordWithRetry(recordID: recordID, database: publicDB, maxRetries: 2)
            let recipe = try parseRecipeFromRecord(record)
            cachedRecipes[recipeID] = recipe
            
            // Store owner information in cache
            let ownerID = record["ownerID"] as? String ?? ""
            let ownerName = record["ownerName"] as? String ?? ""
            CloudKitRecipeCache.shared.addRecipeToCache(recipe, ownerID: ownerID, ownerName: ownerName)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logFetchSuccess(recordType: "Recipe", recordCount: 1, database: "publicDB", duration: duration)
            print("☁️ Recipe fetched from public CloudKit: \(recipeID)")
            return recipe
        } catch let publicError as CKError {
            // If not in public, try private database for user's own recipes
            let publicDuration = Date().timeIntervalSince(startTime)
            logger.logFetchFailure(recordType: "Recipe", database: "publicDB", error: publicError, duration: publicDuration)
            do {
                let record = try await fetchRecordWithRetry(recordID: recordID, database: privateDB, maxRetries: 2)
                let recipe = try parseRecipeFromRecord(record)
                cachedRecipes[recipeID] = recipe
                
                // Store owner information in cache
                let ownerID = record["ownerID"] as? String ?? ""
                let ownerName = record["ownerName"] as? String ?? ""
                CloudKitRecipeCache.shared.addRecipeToCache(recipe, ownerID: ownerID, ownerName: ownerName)
                
                // Note: View count increment disabled due to CloudKit permission restrictions
                // Only recipe owner can modify recipe records (GRANT WRITE TO "_creator")
                // TODO: Implement separate RecipeView record type for tracking views
                // Task {
                //     await incrementViewCount(for: recipeID)
                // }
                
                let duration = Date().timeIntervalSince(startTime)
                logger.logFetchSuccess(recordType: "Recipe", recordCount: 1, database: "privateDB", duration: duration)
                print("☁️ Recipe fetched from private CloudKit after public error: \(recipeID)")
                return recipe
            } catch let publicError as CKError {
                // Both databases failed - convert and throw appropriate error
                print("❌ DEBUG CloudKitRecipeManager: Both databases failed with CKError for recipeID: \(recipeID)")
                print("❌ DEBUG CloudKitRecipeManager: Public DB CKError: \(publicError)")
                let snapChefError = CloudKitErrorHandler.snapChefError(from: publicError)
                ErrorAnalytics.logError(snapChefError, context: "recipe_fetch_failed_\(recipeID)")
                throw snapChefError
            } catch {
                // Non-CloudKit error from public database
                print("❌ DEBUG CloudKitRecipeManager: Public DB failed with non-CloudKit error for recipeID: \(recipeID)")
                print("❌ DEBUG CloudKitRecipeManager: Public DB non-CloudKit error: \(error)")
                let snapChefError = SnapChefError.unknown("Failed to fetch recipe: \(error.localizedDescription)")
                ErrorAnalytics.logError(snapChefError, context: "recipe_fetch_unexpected_\(recipeID)")
                throw snapChefError
            }
        } catch {
            // Non-CloudKit error from private database - still try public
            print("🔍 DEBUG CloudKitRecipeManager: Private DB failed with non-CloudKit error, trying public database for recipeID: \(recipeID)")
            print("🔍 DEBUG CloudKitRecipeManager: Private DB non-CloudKit error: \(error)")
            do {
                let record = try await fetchRecordWithRetry(recordID: recordID, database: publicDB, maxRetries: 2)
                let recipe = try parseRecipeFromRecord(record)
                cachedRecipes[recipeID] = recipe
                
                // Store owner information in cache
                let ownerID = record["ownerID"] as? String ?? ""
                let ownerName = record["ownerName"] as? String ?? ""
                print("🔍 DEBUG CloudKitRecipeManager: Recipe fetched from public DB after non-CloudKit private error - ownerID: '\(ownerID)', ownerName: '\(ownerName)'")
                CloudKitRecipeCache.shared.addRecipeToCache(recipe, ownerID: ownerID, ownerName: ownerName)
                
                // Note: View count increment disabled due to CloudKit permission restrictions
                // Only recipe owner can modify recipe records (GRANT WRITE TO "_creator")
                // TODO: Implement separate RecipeView record type for tracking views
                // Task {
                //     await incrementViewCount(for: recipeID)
                // }
                
                print("☁️ Recipe fetched from public CloudKit after private error: \(recipeID)")
                return recipe
            } catch {
                // Both attempts failed with non-CloudKit errors
                print("❌ DEBUG CloudKitRecipeManager: Final fallback failed for recipeID: \(recipeID)")
                print("❌ DEBUG CloudKitRecipeManager: Final error: \(error)")
                let snapChefError = SnapChefError.unknown("Failed to fetch recipe from both databases: \(error.localizedDescription)")
                ErrorAnalytics.logError(snapChefError, context: "recipe_fetch_total_failure_\(recipeID)")
                throw snapChefError
            }
        }
    }

    /// Batch fetch recipes by IDs (optimized with concurrent downloads)
    func fetchRecipes(by recipeIDs: [String]) async throws -> [Recipe] {
        print("🔍 DEBUG CloudKitRecipeManager: Starting batch fetch for recipe IDs: \(recipeIDs.prefix(5))")
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
        print("🔍 DEBUG CloudKitRecipeManager: Batch fetch complete - cached: \(cachedRecipes.count), downloaded: \(downloadedRecipes.count), total: \(allRecipes.count)")
        print("✅ Batch fetch complete: \(allRecipes.count) recipes")
        return allRecipes
    }

    // MARK: - User Profile Recipe Management

    enum RecipeListType {
        case saved, created, favorited
    }

    /// Fetch recipes for a specific user (for viewing other users' profiles)
    func fetchRecipesForUser(_ userID: String, limit: Int = 50) async throws -> [Recipe] {
        let logger = CloudKitDebugLogger.shared
        let _ = Date()
        
        // Handle different userID formats
        var queryUserID = userID
        if userID.hasPrefix("user_") {
            // Remove the "user_" prefix to get the raw CloudKit ID
            queryUserID = String(userID.dropFirst(5))
            print("🔍 Fetching recipes for user profile")
            print("   Original ID: \(userID)")
            print("   Cleaned ID: \(queryUserID)")
        } else {
            print("🔍 Fetching recipes for user")
            print("   User ID: \(userID)")
        }
        
        print("   Query: ownerID == '\(queryUserID)'")
        
        // Create predicate to find recipes by ownerID
        let predicate = NSPredicate(format: "ownerID == %@", queryUserID)
        print("🔍 DEBUG CloudKitRecipeManager: Predicate: \(predicate)")
        
        let query = CKQuery(recordType: "Recipe", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        var allRecipes: [Recipe] = []
        var totalRecordsFound = 0
        var cursor: CKQueryOperation.Cursor?
        
        do {
            repeat {
                let operation: CKQueryOperation
                if let cursor = cursor {
                    operation = CKQueryOperation(cursor: cursor)
                    print("🔍 DEBUG CloudKitRecipeManager: Continuing query with cursor")
                } else {
                    operation = CKQueryOperation(query: query)
                    print("🔍 DEBUG CloudKitRecipeManager: Starting initial query")
                }
                
                operation.resultsLimit = min(limit - allRecipes.count, 50) // Batch size
                
                let (records, nextCursor) = try await withCheckedThrowingContinuation { continuation in
                    var fetchedRecords: [CKRecord] = []
                    
                    operation.recordMatchedBlock = { recordID, result in
                        switch result {
                        case .success(let record):
                            fetchedRecords.append(record)
                            let recordOwnerID = record["ownerID"] as? String ?? "Unknown"
                            print("🔍 DEBUG CloudKitRecipeManager: Found recipe \(recordID.recordName) with ownerID: '\(recordOwnerID)'")
                        case .failure(let error):
                            print("❌ DEBUG CloudKitRecipeManager: Failed to fetch record \(recordID): \(error)")
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
                    
                    // Try public database for recipes
                    logger.logQueryStart(query: query, database: "publicDB")
                    publicDB.add(operation)
                }
                
                totalRecordsFound += records.count
                print("🔍 DEBUG CloudKitRecipeManager: Batch returned \(records.count) records (total so far: \(totalRecordsFound))")
                
                // Parse recipes from records
                for record in records {
                    do {
                        let recipe = try parseRecipeFromRecord(record)
                        allRecipes.append(recipe)
                        
                        // Cache the recipe
                        cachedRecipes[recipe.id.uuidString] = recipe
                        
                        // Store owner information in cache
                        let ownerID = record["ownerID"] as? String ?? ""
                        let ownerName = record["ownerName"] as? String ?? ""
                        CloudKitRecipeCache.shared.addRecipeToCache(recipe, ownerID: ownerID, ownerName: ownerName)
                        
                        print("🔍 DEBUG CloudKitRecipeManager: Parsed recipe '\(recipe.name)' (ID: \(recipe.id.uuidString))")
                    } catch {
                        print("❌ DEBUG CloudKitRecipeManager: Failed to parse recipe from record \(record.recordID): \(error)")
                    }
                }
                
                cursor = nextCursor
            } while cursor != nil && allRecipes.count < limit
        } catch {
            print("❌ DEBUG CloudKitRecipeManager: Query failed in private database, trying public database: \(error)")
            
            // Try public database as fallback
            do {
                let operation = CKQueryOperation(query: query)
                operation.resultsLimit = limit
                
                let (records, _): ([CKRecord], CKQueryOperation.Cursor?) = try await withCheckedThrowingContinuation { continuation in
                    var fetchedRecords: [CKRecord] = []
                    
                    operation.recordMatchedBlock = { recordID, result in
                        switch result {
                        case .success(let record):
                            fetchedRecords.append(record)
                            let recordOwnerID = record["ownerID"] as? String ?? "Unknown"
                            print("🔍 DEBUG CloudKitRecipeManager: Found public recipe \(recordID.recordName) with ownerID: '\(recordOwnerID)'")
                        case .failure(let error):
                            print("❌ DEBUG CloudKitRecipeManager: Failed to fetch public record \(recordID): \(error)")
                        }
                    }
                    
                    operation.queryResultBlock = { result in
                        switch result {
                        case .success:
                            continuation.resume(returning: (fetchedRecords, nil))
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    
                    publicDB.add(operation)
                }
                
                print("🔍 DEBUG CloudKitRecipeManager: Public database returned \(records.count) records")
                
                // Parse recipes from public records
                for record in records {
                    do {
                        let recipe = try parseRecipeFromRecord(record)
                        allRecipes.append(recipe)
                        
                        // Cache the recipe
                        cachedRecipes[recipe.id.uuidString] = recipe
                        
                        // Store owner information in cache
                        let ownerID = record["ownerID"] as? String ?? ""
                        let ownerName = record["ownerName"] as? String ?? ""
                        CloudKitRecipeCache.shared.addRecipeToCache(recipe, ownerID: ownerID, ownerName: ownerName)
                        
                        print("🔍 DEBUG CloudKitRecipeManager: Parsed public recipe '\(recipe.name)' (ID: \(recipe.id.uuidString))")
                    } catch {
                        print("❌ DEBUG CloudKitRecipeManager: Failed to parse public recipe from record \(record.recordID): \(error)")
                    }
                }
                
            } catch {
                print("❌ DEBUG CloudKitRecipeManager: Both private and public database queries failed: \(error)")
                throw error
            }
        }
        
        print("🔍 DEBUG CloudKitRecipeManager: fetchRecipesForUser completed")
        print("🔍 DEBUG CloudKitRecipeManager: Total recipes found for userID '\(userID)': \(allRecipes.count)")
        print("🔍 DEBUG CloudKitRecipeManager: Recipe titles: \(allRecipes.prefix(3).map { $0.name })")
        
        return allRecipes
    }

    /// Add recipe reference to user profile
    func addRecipeToUserProfile(_ recipeID: String, type: RecipeListType) async throws {
        guard let userID = getCurrentUserID() else { return }

        // For now, just track the recipe ID locally since CloudKit User record doesn't have list fields
        // The recipe itself is already saved to CloudKit in the Recipe table
        switch type {
        case .saved:
            userSavedRecipeIDs.insert(recipeID)
            print("✅ Recipe \(recipeID) marked as saved locally")
        case .created:
            userCreatedRecipeIDs.insert(recipeID)
            print("✅ Recipe \(recipeID) marked as created locally")
        case .favorited:
            userFavoritedRecipeIDs.insert(recipeID)
            print("✅ Recipe \(recipeID) marked as favorited locally")
        }
        
        // Update save count on recipe
        if type == .saved {
            await incrementSaveCount(for: recipeID)
        }
        
        // TODO: In the future, create a SavedRecipe record type in CloudKit
        // to properly track which recipes each user has saved
        // For now, the recipe is saved to CloudKit Recipe table and tracked locally
        
        print("✅ Recipe \(recipeID) successfully tracked as \(type)")
    }

    /// Remove recipe reference from user profile
    func removeRecipeFromUserProfile(_ recipeID: String, type: RecipeListType) async throws {
        guard let userID = getCurrentUserID() else { return }

        // For now, just remove the recipe ID locally since CloudKit User record doesn't have list fields
        switch type {
        case .saved:
            userSavedRecipeIDs.remove(recipeID)
            print("✅ Recipe \(recipeID) removed from saved locally")
        case .created:
            userCreatedRecipeIDs.remove(recipeID)
            print("✅ Recipe \(recipeID) removed from created locally")
        case .favorited:
            userFavoritedRecipeIDs.remove(recipeID)
            print("✅ Recipe \(recipeID) removed from favorited locally")
        }
        
        // TODO: In the future, delete the SavedRecipe record from CloudKit
        // For now, just track locally
        
        print("✅ Recipe \(recipeID) successfully removed from \(type) list")
    }

    /// Load user's recipe references
    func loadUserRecipeReferences() {
        Task {
            // Only load CloudKit data if authenticated
            guard UnifiedAuthManager.shared.isAuthenticated else {
                return
            }
            
            guard let userID = getCurrentUserID() else { 
                return 
            }

            do {
                let profileRecord = try await fetchOrCreateUserProfile(userID)

                // Get IDs and filter out placeholder values
                let rawSavedIDs = profileRecord["savedRecipeIDs"] as? [String] ?? []
                let rawCreatedIDs = profileRecord["createdRecipeIDs"] as? [String] ?? []
                let rawFavoritedIDs = profileRecord["favoritedRecipeIDs"] as? [String] ?? []
                
                let savedIDs = rawSavedIDs.filter { $0 != "_placeholder_" }
                let createdIDs = rawCreatedIDs.filter { $0 != "_placeholder_" }
                let favoritedIDs = rawFavoritedIDs.filter { $0 != "_placeholder_" }

                await MainActor.run {
                    self.userSavedRecipeIDs = Set(savedIDs)
                    self.userCreatedRecipeIDs = Set(createdIDs)
                    self.userFavoritedRecipeIDs = Set(favoritedIDs)
                }

            } catch {
                print("❌ Failed to load user recipe references: \(error)")
            }
        }
    }

    /// Get user's saved recipes (optimized)
    func getUserSavedRecipes() async throws -> [Recipe] {
        // Check if user is authenticated with Apple/Google/Facebook
        guard UnifiedAuthManager.shared.isAuthenticated else {
            return []
        }
        
        guard let currentUserID = getCurrentUserID() else {
            return []
        }

        // Skip loading from CloudKit since those fields don't exist
        // TODO: In the future, query SavedRecipe records to get the user's saved recipes
        print("📱 Using locally tracked saved recipes: \(userSavedRecipeIDs.count) saved")

        // If we have any saved recipe IDs tracked locally, fetch those recipes
        if !userSavedRecipeIDs.isEmpty {
            let recipes = try await fetchRecipes(by: Array(userSavedRecipeIDs))
            return recipes
        } else {
            return []
        }
    }

    /// Get user's created recipes (optimized)
    func getUserCreatedRecipes() async throws -> [Recipe] {
        // Check if user is authenticated with Apple/Google/Facebook
        guard UnifiedAuthManager.shared.isAuthenticated else {
            print("📱 User not authenticated - returning empty created recipes")
            return []
        }
        
        guard let currentUserID = getCurrentUserID() else {
            return []
        }
        
        print("🍳 Getting user's CREATED recipes...")
        print("   Current User ID: \(currentUserID)")
        print("   Querying CloudKit for recipes where ownerID == '\(currentUserID)'")

        // Query CloudKit directly for recipes owned by this user
        // This is more reliable than relying on the createdRecipeIDs field which isn't being populated
        let predicate = NSPredicate(format: "ownerID == %@", currentUserID)
        let query = CKQuery(recordType: "Recipe", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        var allRecipes: [Recipe] = []
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let operation: CKQueryOperation
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }
            
            operation.resultsLimit = 50 // Fetch in batches
            
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
                
                publicDB.add(operation)
            }
            
            // Parse recipes from records
            for record in records {
                do {
                    let recipe = try parseRecipeFromRecord(record)
                    allRecipes.append(recipe)
                    
                    // Cache the recipe
                    if let recipeID = record["id"] as? String {
                        cachedRecipes[recipeID] = recipe
                        // Also update our local tracking
                        userCreatedRecipeIDs.insert(recipeID)
                    }
                } catch {
                    print("⚠️ Failed to parse recipe: \(error)")
                }
            }
            
            cursor = nextCursor
            print("📊 Fetched batch of \(records.count) recipes (total: \(allRecipes.count))")
        } while cursor != nil
        
        print("🍳 Retrieved \(allRecipes.count) created recipes for user \(currentUserID)")
        return allRecipes
    }

    /// Get user's favorited recipes (optimized)
    func getUserFavoritedRecipes() async throws -> [Recipe] {
        guard let currentUserID = getCurrentUserID() else {
            return []
        }
        
        print("🔍 DEBUG CloudKitRecipeManager: Getting favorited recipes for userID: \(currentUserID)")
        print("❤️ Getting user's favorited recipes...")

        // Ensure references are loaded first
        if userSavedRecipeIDs.isEmpty && userCreatedRecipeIDs.isEmpty && userFavoritedRecipeIDs.isEmpty {
            // Try to load references if they haven't been loaded yet
            guard let userID = getCurrentUserID() else { return [] }

            do {
                let profileRecord = try await fetchOrCreateUserProfile(userID)

                // Get IDs and filter out placeholder values
                let savedIDs = ((profileRecord["savedRecipeIDs"] as? [String]) ?? []).filter { $0 != "_placeholder_" }
                let createdIDs = ((profileRecord["createdRecipeIDs"] as? [String]) ?? []).filter { $0 != "_placeholder_" }
                let favoritedIDs = ((profileRecord["favoritedRecipeIDs"] as? [String]) ?? []).filter { $0 != "_placeholder_" }

                await MainActor.run {
                    self.userSavedRecipeIDs = Set(savedIDs)
                    self.userCreatedRecipeIDs = Set(createdIDs)
                    self.userFavoritedRecipeIDs = Set(favoritedIDs)
                }

                print("✅ Loaded recipe references: \(savedIDs.count) saved, \(createdIDs.count) created, \(favoritedIDs.count) favorited")
            } catch {
                print("❌ Failed to load recipe references: \(error)")
            }
        }

        print("🔍 DEBUG CloudKitRecipeManager: Fetching \(userFavoritedRecipeIDs.count) favorited recipe IDs: \(Array(userFavoritedRecipeIDs).prefix(5))")
        let recipes = try await fetchRecipes(by: Array(userFavoritedRecipeIDs))
        print("🔍 DEBUG CloudKitRecipeManager: Successfully retrieved \(recipes.count) favorited recipes")
        print("❤️ Retrieved \(recipes.count) favorited recipes")
        return recipes
    }

    // MARK: - Recipe Sharing

    /// Generate a shareable link for a recipe
    func generateShareLink(for recipeID: String) -> URL {
        var components = URLComponents()
        components.scheme = "snapchef"
        components.host = "recipe"
        components.path = "/\(recipeID)"

        if let url = components.url {
            return url
        } else if let fallbackURL = URL(string: "snapchef://recipe/\(recipeID)") {
            return fallbackURL
        } else {
            // Final fallback to a generic URL
            return URL(string: "snapchef://error")!
        }
    }

    /// Handle incoming recipe share link
    func handleRecipeShareLink(_ url: URL) async throws -> Recipe {
        guard url.scheme == "snapchef",
              url.host == "recipe" else {
            throw RecipeError.invalidShareLink
        }

        let recipeID = url.pathComponents.last ?? ""
        return try await fetchRecipe(by: recipeID)
    }

    // MARK: - Recipe Search

    /// Search for recipes by query - FILTERED BY CURRENT USER AND PUBLIC RECIPES
    func searchRecipes(query: String, limit: Int = 20) async throws -> [Recipe] {
        let _ = CloudKitDebugLogger.shared
        let _ = Date()
        print("🔍 DEBUG CloudKitRecipeManager: Starting searchRecipes with query: '\(query)', limit: \(limit)")
        // CRITICAL PRIVACY FIX: Only search user's own recipes and explicitly public recipes
        guard let currentUserID = getCurrentUserID() else {
            print("🔍 DEBUG CloudKitRecipeManager: No authenticated user - searching only public recipes")
            print("⚠️ No authenticated user - searching only public recipes")
            let predicate = NSPredicate(format: "(title CONTAINS[cd] %@ OR description CONTAINS[cd] %@) AND isPublic == 1", query, query)
            print("🔍 DEBUG CloudKitRecipeManager: Public-only search predicate: \(predicate)")
            let ckQuery = CKQuery(recordType: "Recipe", predicate: predicate)
            ckQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try await performSearchQuery(ckQuery, limit: limit)
        }
        
        print("🔍 DEBUG CloudKitRecipeManager: Searching for user '\(currentUserID)' and public recipes")
        let predicate = NSPredicate(format: "(title CONTAINS[cd] %@ OR description CONTAINS[cd] %@) AND (ownerID == %@ OR isPublic == 1)", query, query, currentUserID)
        print("🔍 DEBUG CloudKitRecipeManager: Search predicate: \(predicate)")
        let ckQuery = CKQuery(recordType: "Recipe", predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        return try await performSearchQuery(ckQuery, limit: limit)
    }
    
    /// Helper method to perform search queries with consistent handling
    private func performSearchQuery(_ ckQuery: CKQuery, limit: Int) async throws -> [Recipe] {
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        print("🔍 DEBUG CloudKitRecipeManager: Executing search query with limit: \(limit)")
        logger.logQueryStart(query: ckQuery, database: "publicDB")
        let (matchResults, _) = try await publicDB.records(matching: ckQuery, resultsLimit: limit)
        let duration = Date().timeIntervalSince(startTime)
        logger.logQuerySuccess(query: ckQuery, resultCount: matchResults.count, database: "publicDB", duration: duration)
        print("🔍 DEBUG CloudKitRecipeManager: Search query returned \(matchResults.count) results")

        var recipes: [Recipe] = []
        for (recordID, result) in matchResults {
            if let record = try? result.get() {
                if let recipe = try? parseRecipeFromRecord(record) {
                    recipes.append(recipe)
                    // Cache the recipe
                    cachedRecipes[recipe.id.uuidString] = recipe
                    
                    // Store owner information in cache
                    let ownerID = record["ownerID"] as? String ?? ""
                    let ownerName = record["ownerName"] as? String ?? ""
                    print("🔍 DEBUG CloudKitRecipeManager: Search result recipe '\(recipe.name)' - ownerID: '\(ownerID)', ownerName: '\(ownerName)'")
                    CloudKitRecipeCache.shared.addRecipeToCache(recipe, ownerID: ownerID, ownerName: ownerName)
                } else {
                    print("⚠️ DEBUG CloudKitRecipeManager: Failed to parse recipe from search result: \(recordID)")
                }
            } else {
                print("⚠️ DEBUG CloudKitRecipeManager: Failed to get record from search result: \(recordID)")
            }
        }

        print("🔍 DEBUG CloudKitRecipeManager: Search completed, parsed \(recipes.count) recipes")
        return recipes
    }
    
    /// Fetch public recipes that are explicitly shared (separate from user's own recipes)
    func fetchPublicRecipes(limit: Int = 20) async throws -> [Recipe] {
        print("🔍 DEBUG CloudKitRecipeManager: Starting fetchPublicRecipes with limit: \(limit)")
        print("🌐 Fetching public recipes...")
        
        let predicate = NSPredicate(format: "isPublic == 1")
        print("🔍 DEBUG CloudKitRecipeManager: Public recipes predicate: \(predicate)")
        let ckQuery = CKQuery(recordType: "Recipe", predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        let recipes = try await performSearchQuery(ckQuery, limit: limit)
        print("🔍 DEBUG CloudKitRecipeManager: fetchPublicRecipes completed with \(recipes.count) recipes")
        print("🌐 Found \(recipes.count) public recipes")
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
        // Only return user ID if authenticated
        guard UnifiedAuthManager.shared.isAuthenticated else {
            print("⚠️ CloudKitRecipeManager: User not authenticated")
            return nil
        }
        
        // Get the CloudKit user record ID - this should be the single source of truth
        if let userID = UserDefaults.standard.string(forKey: "currentUserRecordID") {
            // Return the raw CloudKit ID without any prefix
            // This ensures consistency between saving and querying
            print("📱 CloudKitRecipeManager: Using CloudKit userID: \(userID)")
            print("📱 This ID will be used for ownerID field in Recipe records")
            return userID
        }
        
        // Fallback to legacy key if needed
        if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
            print("📱 CloudKitRecipeManager: Using legacy userID: \(userID)")
            return userID
        }
        
        print("❌ CloudKitRecipeManager: No user ID found despite being authenticated")
        return nil
    }

    /// Check if a recipe exists by its ID
    func checkRecipeExists(_ recipeID: String) async -> Bool {
        let recordID = CKRecord.ID(recordName: recipeID)
        
        do {
            // Try to fetch from public database first
            _ = try await publicDB.record(for: recordID)
            return true
        } catch {
            // If not in public, try private database
            do {
                _ = try await privateDB.record(for: recordID)
                return true
            } catch {
                // Recipe doesn't exist in either database
                return false
            }
        }
    }
    
    func checkRecipeExists(_ name: String, _ description: String) async -> String? {
        // CRITICAL PRIVACY FIX: Only check current user's recipes for duplicates
        guard let currentUserID = getCurrentUserID() else {
            print("⚠️ No authenticated user - skipping duplicate check")
            return nil
        }
        
        // Only use title for query since description is not queryable, but filter by ownerID
        let predicate = NSPredicate(format: "title == %@ AND ownerID == %@", name, currentUserID)
        let query = CKQuery(recordType: "Recipe", predicate: predicate)

        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            if let record = try? matchResults.first?.1.get() {
                print("✅ Found existing recipe by same user: \(name)")
                return record["id"] as? String
            }
        } catch {
            print("Error checking recipe existence: \(error)")
        }

        return nil
    }

    private func fetchOrCreateUserProfile(_ userID: String) async throws -> CKRecord {
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        print("🔍 DEBUG CloudKitRecipeManager: fetchOrCreateUserProfile starting for userID: \(userID)")
        let recordID = CKRecord.ID(recordName: "profile_\(userID)")
        print("🔍 DEBUG CloudKitRecipeManager: Looking for UserProfile record: \(recordID.recordName)")

        do {
            // Try to fetch existing profile
            print("🔍 DEBUG CloudKitRecipeManager: Attempting to fetch existing UserProfile record")
            logger.logFetchStart(recordType: CloudKitConfig.userRecordType, query: "profile_\(userID)", database: "privateDB")
            let existingRecord = try await privateDB.record(for: recordID)
            let duration = Date().timeIntervalSince(startTime)
            logger.logFetchSuccess(recordType: CloudKitConfig.userRecordType, recordCount: 1, database: "privateDB", duration: duration)
            print("🔍 DEBUG CloudKitRecipeManager: Found existing UserProfile record: \(existingRecord.recordID.recordName)")
            return existingRecord
        } catch {
            // Create new profile
            let fetchDuration = Date().timeIntervalSince(startTime)
            logger.logFetchFailure(recordType: CloudKitConfig.userRecordType, database: "privateDB", error: error, duration: fetchDuration)
            print("🔍 DEBUG CloudKitRecipeManager: UserProfile record not found, creating new one")
            print("🔍 DEBUG CloudKitRecipeManager: Fetch error: \(error)")
            let record = CKRecord(recordType: CloudKitConfig.userRecordType, recordID: recordID)
            record["userID"] = userID
            // Don't set empty arrays - CloudKit doesn't like them
            // These fields will be created when we first add a recipe
            record["createdAt"] = Date()
            record["lastActiveAt"] = Date()

            print("🔍 DEBUG CloudKitRecipeManager: Saving new UserProfile record")
            logger.logSaveStart(recordType: CloudKitConfig.userRecordType, database: "privateDB")
            let saveStartTime = Date()
            let savedRecord = try await privateDB.save(record)
            let saveDuration = Date().timeIntervalSince(saveStartTime)
            logger.logSaveSuccess(recordType: CloudKitConfig.userRecordType, recordID: savedRecord.recordID.recordName, database: "privateDB", duration: saveDuration)
            print("🔍 DEBUG CloudKitRecipeManager: Created new UserProfile record: \(savedRecord.recordID.recordName)")
            return savedRecord
        }
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
        
        // Parse Detective recipe fields
        let isDetectiveRecipe = (record["isDetectiveRecipe"] as? Int64 ?? 0) == 1
        let cookingTechniques = record["cookingTechniques"] as? [String] ?? []
        let flavorProfile: FlavorProfile? = {
            if let flavorProfileString = record["flavorProfile"] as? String {
                return try? decodeFromJSON(flavorProfileString)
            }
            return nil
        }()
        let secretIngredients = record["secretIngredients"] as? [String] ?? []
        let proTips = record["proTips"] as? [String] ?? []
        let visualClues = record["visualClues"] as? [String] ?? []
        let shareCaption = record["shareCaption"] as? String ?? ""

        // Get owner ID from record
        let ownerID = record["ownerID"] as? String
        
        let recipe = Recipe(
            id: UUID(uuidString: id) ?? UUID(),
            ownerID: ownerID,
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
            isDetectiveRecipe: isDetectiveRecipe,
            cookingTechniques: cookingTechniques,
            flavorProfile: flavorProfile,
            secretIngredients: secretIngredients,
            proTips: proTips,
            visualClues: visualClues,
            shareCaption: shareCaption
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
            let record = try await publicDB.record(for: recordID)
            let currentCount = record["viewCount"] as? Int64 ?? 0
            record["viewCount"] = currentCount + 1
            _ = try await publicDB.save(record)
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
            let record = try await privateDB.record(for: recordID)
            let currentCount = record["saveCount"] as? Int64 ?? 0
            record["saveCount"] = currentCount + 1
            _ = try await privateDB.save(record)
            print("✅ Save count incremented in private database for recipe: \(recipeID)")
            return
        } catch {
            print("⚠️ Recipe not found in private database, trying public: \(error)")
        }
        
        // Try public database if not in private
        do {
            let record = try await publicDB.record(for: recordID)
            let currentCount = record["saveCount"] as? Int64 ?? 0
            record["saveCount"] = currentCount + 1
            _ = try await publicDB.save(record)
            print("✅ Save count incremented in public database for recipe: \(recipeID)")
        } catch {
            // This is expected for user's own recipes that are only in private database
            print("ℹ️ Could not increment save count for recipe \(recipeID) - likely a private recipe. This is normal.")
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

        // Clean up will happen automatically when asset is saved
        return asset
    }

    /// Update the after photo for a recipe
    func updateAfterPhoto(for recipeID: String, afterPhoto: UIImage) async throws {
        let recordID = CKRecord.ID(recordName: recipeID)

        print("📸 CloudKit: Starting AFTER photo upload for recipe ID: \(recipeID)")

        do {
            // Try private database first (user's own recipes)
            let record = try await privateDB.record(for: recordID)
            let recipeTitle = record["title"] as? String ?? "Unknown Recipe"

            print("📸 CloudKit: Uploading AFTER photo for recipe '\(recipeTitle)' with ID: \(recipeID)")

            // Upload after photo
            let afterPhotoAsset = try await uploadImageAsset(afterPhoto, named: "after_\(recipeID)")
            record["afterPhotoAsset"] = afterPhotoAsset

            // Save updated record
            _ = try await privateDB.save(record)
            print("✅ CloudKit: AFTER photo uploaded successfully for recipe '\(recipeTitle)' (ID: \(recipeID)) - Private DB")
        } catch {
            // If not in private, try public database
            let record = try await publicDB.record(for: recordID)
            let recipeTitle = record["title"] as? String ?? "Unknown Recipe"

            print("📸 CloudKit: Uploading AFTER photo for recipe '\(recipeTitle)' with ID: \(recipeID)")

            // Upload after photo
            let afterPhotoAsset = try await uploadImageAsset(afterPhoto, named: "after_\(recipeID)")
            record["afterPhotoAsset"] = afterPhotoAsset

            // Save updated record
            _ = try await publicDB.save(record)
            print("✅ CloudKit: AFTER photo uploaded successfully for recipe '\(recipeTitle)' (ID: \(recipeID)) - Public DB")
        }
    }

    /// Fetch photos for a recipe with caching and deduplication
    func fetchRecipePhotos(for recipeID: String) async throws -> (before: UIImage?, after: UIImage?) {
        // Only fetch photos if authenticated
        guard UnifiedAuthManager.shared.isAuthenticated else {
            print("📱 User not authenticated - skipping CloudKit photo fetch")
            return (nil, nil)
        }
        
        // OPTIMIZATION: Return cached photos if available
        if let cachedPhotos = photoFetchCache[recipeID] {
            print("📸 CloudKit: Returning cached photos for recipe \(recipeID)")
            return cachedPhotos
        }
        
        // OPTIMIZATION: If already fetching, wait for completion instead of duplicating
        if activeFetches.contains(recipeID) {
            print("📸 CloudKit: Recipe \(recipeID) already being fetched, waiting for completion...")
            return try await withCheckedThrowingContinuation { continuation in
                if fetchCompletionHandlers[recipeID] == nil {
                    fetchCompletionHandlers[recipeID] = []
                }
                fetchCompletionHandlers[recipeID]?.append { result in
                    continuation.resume(with: result)
                }
            }
        }
        
        // Mark as fetching
        activeFetches.insert(recipeID)
        
        let recordID = CKRecord.ID(recordName: recipeID)
        print("🔍 CloudKit: Fetching photos for recipe ID: \(recipeID)")

        do {
            let photos: (before: UIImage?, after: UIImage?)
            
            do {
                // Try private database first
                let record = try await privateDB.record(for: recordID)
                let recipeTitle = record["title"] as? String ?? "Unknown Recipe"
                print("🔍 CloudKit: Found recipe '\(recipeTitle)' in Private DB, fetching photos...")
                photos = await fetchPhotosFromRecord(record, recipeTitle: recipeTitle, recipeID: recipeID)
            } catch {
                // Try public database
                let record = try await publicDB.record(for: recordID)
                let recipeTitle = record["title"] as? String ?? "Unknown Recipe"
                print("🔍 CloudKit: Found recipe '\(recipeTitle)' in Public DB, fetching photos...")
                photos = await fetchPhotosFromRecord(record, recipeTitle: recipeTitle, recipeID: recipeID)
            }
            
            // Cache the result
            photoFetchCache[recipeID] = photos
            
            // Complete fetch and notify waiting handlers
            completeFetch(for: recipeID, with: .success(photos))
            
            return photos
        } catch {
            // Complete fetch with error and notify waiting handlers
            completeFetch(for: recipeID, with: .failure(error))
            throw error
        }
    }
    
    /// Complete fetch and notify all waiting handlers
    private func completeFetch(for recipeID: String, with result: Result<(before: UIImage?, after: UIImage?), Error>) {
        activeFetches.remove(recipeID)
        
        if let handlers = fetchCompletionHandlers[recipeID] {
            for handler in handlers {
                handler(result)
            }
            fetchCompletionHandlers[recipeID] = nil
        }
    }
    
    /// Clear photo cache for a specific recipe (useful when photos are updated)
    func clearPhotoCache(for recipeID: String) {
        photoFetchCache.removeValue(forKey: recipeID)
        print("📸 CloudKit: Cleared photo cache for recipe \(recipeID)")
    }
    
    /// Clear all photo cache (useful for memory management)
    func clearAllPhotoCache() {
        let count = photoFetchCache.count
        photoFetchCache.removeAll()
        print("📸 CloudKit: Cleared all photo cache (\(count) entries)")
    }

    /// Helper to fetch photos from a CKRecord
    /// Retry helper for CloudKit record saves with exponential backoff
    private func saveRecordWithRetry(record: CKRecord, database: CKDatabase, maxRetries: Int) async throws -> CKRecord {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let savedRecord = try await database.save(record)
                if attempt > 0 {
                    print("✅ CloudKit save succeeded on attempt \(attempt + 1)")
                }
                return savedRecord
            } catch let error as CKError {
                lastError = error
                
                // Don't retry on certain errors
                switch error.code {
                case .notAuthenticated, .permissionFailure, .quotaExceeded:
                    throw error
                case .zoneBusy, .serviceUnavailable, .requestRateLimited:
                    // These are retryable
                    if attempt < maxRetries - 1 {
                        let delay = calculateCloudKitBackoffDelay(attempt: attempt, baseDelay: 1.0)
                        print("⏳ CloudKit save failed (attempt \(attempt + 1)), retrying in \(delay)s: \(error.localizedDescription)")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    throw error
                default:
                    // For other errors, retry with shorter delays
                    if attempt < maxRetries - 1 {
                        let delay = calculateCloudKitBackoffDelay(attempt: attempt, baseDelay: 0.5)
                        print("⏳ CloudKit save error (attempt \(attempt + 1)), retrying in \(delay)s: \(error.localizedDescription)")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    throw error
                }
            } catch {
                lastError = error
                // Non-CloudKit errors generally shouldn't be retried
                throw error
            }
        }
        
        throw lastError ?? SnapChefError.unknown("CloudKit save failed after all retries")
    }
    
    /// Retry helper for CloudKit record fetches with exponential backoff
    private func fetchRecordWithRetry(recordID: CKRecord.ID, database: CKDatabase, maxRetries: Int) async throws -> CKRecord {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let record = try await database.record(for: recordID)
                if attempt > 0 {
                    print("✅ CloudKit fetch succeeded on attempt \(attempt + 1)")
                }
                return record
            } catch let error as CKError {
                lastError = error
                
                // Don't retry on certain errors
                switch error.code {
                case .unknownItem, .notAuthenticated, .permissionFailure:
                    throw error
                case .zoneBusy, .serviceUnavailable, .requestRateLimited, .networkFailure:
                    // These are retryable
                    if attempt < maxRetries - 1 {
                        let delay = calculateCloudKitBackoffDelay(attempt: attempt, baseDelay: 0.5)
                        print("⏳ CloudKit fetch failed (attempt \(attempt + 1)), retrying in \(delay)s: \(error.localizedDescription)")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    throw error
                default:
                    throw error
                }
            } catch {
                lastError = error
                throw error
            }
        }
        
        throw lastError ?? SnapChefError.unknown("CloudKit fetch failed after all retries")
    }
    
    /// Calculate exponential backoff delay for CloudKit operations
    private func calculateCloudKitBackoffDelay(attempt: Int, baseDelay: TimeInterval) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0.1...0.2) * exponentialDelay
        let maxDelay: TimeInterval = 10.0 // Cap at 10 seconds for CloudKit
        return min(exponentialDelay + jitter, maxDelay)
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
    
    // MARK: - Recipe Likes
    
    /// Like a recipe
    func likeRecipe(recipeID: String) async throws {
        guard let userID = getCurrentUserID() else {
            throw RecipeError.uploadFailed
        }
        
        // First check if already liked
        if await hasUserLikedRecipe(recipeID: recipeID) {
            print("⚠️ Recipe already liked: \(recipeID)")
            return // Already liked, don't try to create duplicate
        }
        
        // Create a Like record - ensure ID doesn't start with underscore
        let cleanUserID = userID.hasPrefix("_") ? String(userID.dropFirst()) : userID
        let likeID = "like_\(cleanUserID)_\(recipeID)"
        print("🔍 Creating RecipeLike with ID: \(likeID)")
        print("🔍 userID field value: \(userID)")
        print("🔍 recipeID field value: \(recipeID)")
        
        let likeRecord = CKRecord(recordType: "RecipeLike", recordID: CKRecord.ID(recordName: likeID))
        likeRecord["userID"] = userID
        likeRecord["recipeID"] = recipeID
        likeRecord["likedAt"] = Date()
        
        // Save to CloudKit using CloudKitActor for safety
        _ = try await CloudKitSyncService.shared.cloudKitActor.saveRecord(likeRecord)
        
        // Update the recipe's like count
        await updateRecipeLikeCount(recipeID: recipeID, increment: true)
        
        // Create activity for recipe owner (if it's not their own recipe)
        do {
            // Fetch the recipe to get owner info and recipe name using CloudKitActor
            let recipeRecord = try await CloudKitSyncService.shared.cloudKitActor.fetchRecord(with: CKRecord.ID(recordName: recipeID))
            let recipeOwnerID = recipeRecord["ownerID"] as? String
            let recipeName = recipeRecord["title"] as? String ?? recipeRecord["name"] as? String
            
            // Only create activity if it's not the user's own recipe
            if let recipeOwnerID = recipeOwnerID, recipeOwnerID != userID {
                // Use CloudKitSyncService to create the activity
                try await CloudKitSyncService.shared.createActivity(
                    type: "recipeLiked",
                    actorID: userID,
                    targetUserID: recipeOwnerID,
                    recipeID: recipeID,
                    recipeName: recipeName
                )
                print("📢 Created like activity for recipe owner: \(recipeOwnerID)")
            }
        } catch {
            // Don't fail the like operation if activity creation fails
            print("⚠️ Failed to create like activity: \(error)")
        }
        
        print("✅ Liked recipe: \(recipeID)")
    }
    
    /// Unlike a recipe
    func unlikeRecipe(recipeID: String) async throws {
        guard let userID = getCurrentUserID() else {
            throw RecipeError.uploadFailed
        }
        
        // First check if actually liked
        guard await hasUserLikedRecipe(recipeID: recipeID) else {
            print("⚠️ Recipe not liked, cannot unlike: \(recipeID)")
            return // Not liked, nothing to unlike
        }
        
        // Delete the Like record - ensure ID doesn't start with underscore
        let cleanUserID = userID.hasPrefix("_") ? String(userID.dropFirst()) : userID
        let likeID = "like_\(cleanUserID)_\(recipeID)"
        let recordID = CKRecord.ID(recordName: likeID)
        
        do {
            // Use CloudKitActor for safe deletion
            try await CloudKitSyncService.shared.cloudKitActor.deleteRecord(with: recordID)
            
            // Update the recipe's like count
            await updateRecipeLikeCount(recipeID: recipeID, increment: false)
            
            print("✅ Unliked recipe: \(recipeID)")
        } catch {
            print("⚠️ Failed to unlike recipe: \(error)")
            throw error
        }
    }
    
    /// Check if user has liked a recipe
    func hasUserLikedRecipe(recipeID: String) async -> Bool {
        guard let userID = getCurrentUserID() else {
            return false
        }
        
        // Ensure ID doesn't start with underscore
        let cleanUserID = userID.hasPrefix("_") ? String(userID.dropFirst()) : userID
        let likeID = "like_\(cleanUserID)_\(recipeID)"
        let recordID = CKRecord.ID(recordName: likeID)
        
        do {
            // Use CloudKitActor for safe fetching
            _ = try await CloudKitSyncService.shared.cloudKitActor.fetchRecord(with: recordID)
            return true
        } catch {
            return false
        }
    }
    
    /// Get like count for a recipe
    func getLikeCount(for recipeID: String) async -> Int {
        // First try to get the cached count from the Recipe record itself
        let recordID = CKRecord.ID(recordName: recipeID)
        do {
            if let record = try? await CloudKitSyncService.shared.cloudKitActor.fetchRecord(with: recordID) {
                if let likeCount = record["likeCount"] as? Int64 {
                    return Int(likeCount)
                }
            }
        } catch {
            print("Could not fetch recipe record for like count: \(error)")
        }
        
        // Fallback: Count the actual RecipeLike records
        let predicate = NSPredicate(format: "recipeID == %@", recipeID)
        let query = CKQuery(recordType: "RecipeLike", predicate: predicate)
        print("🔍 Querying RecipeLike records with predicate: recipeID == \(recipeID)")
        
        do {
            let results = try await CloudKitSyncService.shared.cloudKitActor.executeQueryWithResults(query)
            let count = results.matchResults.count
            print("🔍 Found \(count) RecipeLike records for recipe: \(recipeID)")
            
            // Update the Recipe record with the actual count for future use
            if count > 0 {
                Task {
                    await updateRecipeLikeCount(recipeID: recipeID, absoluteCount: count)
                }
            }
            
            return count
        } catch {
            print("Failed to get like count: \(error)")
            return 0
        }
    }
    
    /// Fetch all recipes liked by the current user
    func fetchUserLikedRecipes() async -> [String] {
        guard let userID = getCurrentUserID() else {
            print("⚠️ No user ID available for fetching likes")
            return []
        }
        
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "RecipeLike", predicate: predicate)
        
        do {
            let results = try await CloudKitSyncService.shared.cloudKitActor.executeQueryWithResults(query)
            let recipeIDs = results.matchResults.compactMap { (_, result) -> String? in
                guard case .success(let record) = result else { return nil }
                return record["recipeID"] as? String
            }
            print("✅ Fetched \(recipeIDs.count) liked recipes for user")
            return recipeIDs
        } catch {
            print("❌ Failed to fetch user likes: \(error)")
            return []
        }
    }
    
    /// Update recipe's like count by increment/decrement
    private func updateRecipeLikeCount(recipeID: String, increment: Bool) async {
        let recordID = CKRecord.ID(recordName: recipeID)
        
        do {
            // Try to fetch from public database using CloudKitActor
            if let record = try? await CloudKitSyncService.shared.cloudKitActor.fetchRecord(with: recordID) {
                let currentCount = record["likeCount"] as? Int64 ?? 0
                record["likeCount"] = increment ? currentCount + 1 : max(0, currentCount - 1)
                _ = try await CloudKitSyncService.shared.cloudKitActor.saveRecord(record)
                print("✅ Updated like count for recipe: \(recipeID) to \(record["likeCount"] ?? 0)")
            }
        } catch {
            print("⚠️ Could not update like count for recipe: \(error)")
        }
    }
    
    /// Update recipe's like count to an absolute value
    private func updateRecipeLikeCount(recipeID: String, absoluteCount: Int) async {
        let recordID = CKRecord.ID(recordName: recipeID)
        
        do {
            // Try to fetch from public database using CloudKitActor
            if let record = try? await CloudKitSyncService.shared.cloudKitActor.fetchRecord(with: recordID) {
                record["likeCount"] = Int64(absoluteCount)
                _ = try await CloudKitSyncService.shared.cloudKitActor.saveRecord(record)
                print("✅ Set like count for recipe: \(recipeID) to \(absoluteCount)")
            }
        } catch {
            print("⚠️ Could not set like count for recipe: \(error)")
        }
    }
}

// MARK: - Sync Data Structures

/// Statistics about sync status
struct SyncStats {
    let totalCloudKitRecipes: Int
    let totalLocalRecipes: Int
    let missingRecipes: Int
    let recipesWithPhotos: Int
    let recipesNeedingPhotos: Int

    var isUpToDate: Bool {
        return missingRecipes == 0
    }

    var completionPercentage: Double {
        guard totalCloudKitRecipes > 0 else { return 100.0 }
        return (Double(totalLocalRecipes) / Double(totalCloudKitRecipes)) * 100.0
    }
}

/// Result of a sync operation
struct SyncResult {
    let newRecipesSynced: Int
    let photosDownloaded: Int
    let duration: TimeInterval
    let success: Bool
    let error: Error?

    init(newRecipesSynced: Int, photosDownloaded: Int, duration: TimeInterval, success: Bool, error: Error? = nil) {
        self.newRecipesSynced = newRecipesSynced
        self.photosDownloaded = photosDownloaded
        self.duration = duration
        self.success = success
        self.error = error
    }
}

// MARK: - Error Types

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
