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

    private init() {
        self.publicDB = container.publicCloudDatabase
        self.privateDB = container.privateCloudDatabase
        loadUserRecipeReferences()
    }

    // MARK: - Recipe Upload (Single Instance)

    /// Upload a recipe to CloudKit (creates single master record)
    func uploadRecipe(_ recipe: Recipe, fromLLM: Bool = false, beforePhoto: UIImage? = nil) async throws -> String {
        // Only upload to CloudKit if user is authenticated
        guard CloudKitAuthManager.shared.isAuthenticated else {
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

        // Set recipe fields
        record["id"] = recipeID
        record["ownerID"] = getCurrentUserID() ?? "anonymous"
        record["ownerName"] = CloudKitAuthManager.shared.currentUser?.displayName ?? "Anonymous Chef"
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
        do {
            let savedRecord = try await saveRecordWithRetry(record: record, database: privateDB, maxRetries: 3)
            print("✅ Recipe saved to CloudKit with ID: \(savedRecord.recordID.recordName)")
        } catch let error as CKError {
            // Handle specific CloudKit errors
            let snapChefError = CloudKitErrorHandler.snapChefError(from: error)
            ErrorAnalytics.logError(snapChefError, context: "recipe_upload_\(recipeID)")
            
            // If record already exists, just update the reference
            if error.code == .serverRecordChanged || error.code == .unknownItem {
                print("⚠️ Recipe already exists in CloudKit: \(recipeID)")
                // Try to fetch the existing record
                do {
                    _ = try await privateDB.record(for: record.recordID)
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

                // Try both databases
                privateDB.add(operation)
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
            // Try private database first
            let record = try await privateDB.record(for: recordID)
            let recipe = try parseRecipeFromRecord(record)
            cachedRecipes[recipeID] = recipe
            print("☁️ Recipe fetched from private CloudKit: \(recipeID)")
            return recipe
        } catch {
            // Try public database
            let record = try await publicDB.record(for: recordID)
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

        // Fetch from CloudKit with enhanced error handling
        let recordID = CKRecord.ID(recordName: recipeID)

        do {
            // Try private database first (user's own recipes)
            let record = try await fetchRecordWithRetry(recordID: recordID, database: privateDB, maxRetries: 2)
            let recipe = try parseRecipeFromRecord(record)
            cachedRecipes[recipeID] = recipe
            print("☁️ Recipe fetched from private CloudKit: \(recipeID)")
            return recipe
        } catch _ as CKError {
            // If not in private, try public database
            do {
                let record = try await fetchRecordWithRetry(recordID: recordID, database: publicDB, maxRetries: 2)
                let recipe = try parseRecipeFromRecord(record)
                cachedRecipes[recipeID] = recipe
                
                // Increment view count for public recipes
                Task {
                    await incrementViewCount(for: recipeID)
                }
                
                print("☁️ Recipe fetched from public CloudKit: \(recipeID)")
                return recipe
            } catch let publicError as CKError {
                // Both databases failed - convert and throw appropriate error
                let snapChefError = CloudKitErrorHandler.snapChefError(from: publicError)
                ErrorAnalytics.logError(snapChefError, context: "recipe_fetch_failed_\(recipeID)")
                throw snapChefError
            } catch {
                // Non-CloudKit error from public database
                let snapChefError = SnapChefError.unknown("Failed to fetch recipe: \(error.localizedDescription)")
                ErrorAnalytics.logError(snapChefError, context: "recipe_fetch_unexpected_\(recipeID)")
                throw snapChefError
            }
        } catch {
            // Non-CloudKit error from private database - still try public
            do {
                let record = try await fetchRecordWithRetry(recordID: recordID, database: publicDB, maxRetries: 2)
                let recipe = try parseRecipeFromRecord(record)
                cachedRecipes[recipeID] = recipe
                
                // Increment view count for public recipes
                Task {
                    await incrementViewCount(for: recipeID)
                }
                
                print("☁️ Recipe fetched from public CloudKit after private error: \(recipeID)")
                return recipe
            } catch {
                // Both attempts failed with non-CloudKit errors
                let snapChefError = SnapChefError.unknown("Failed to fetch recipe from both databases: \(error.localizedDescription)")
                ErrorAnalytics.logError(snapChefError, context: "recipe_fetch_total_failure_\(recipeID)")
                throw snapChefError
            }
        }
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

    enum RecipeListType {
        case saved, created, favorited
    }

    /// Add recipe reference to user profile
    func addRecipeToUserProfile(_ recipeID: String, type: RecipeListType) async throws {
        guard let userID = getCurrentUserID() else { return }

        // Fetch user profile or create new one
        let profileRecord = try await fetchOrCreateUserProfile(userID)

        // Get current recipe IDs (handle nil fields for new profiles and filter placeholders)
        var savedIDs = ((profileRecord["savedRecipeIDs"] as? [String]) ?? []).filter { $0 != "_placeholder_" }
        var createdIDs = ((profileRecord["createdRecipeIDs"] as? [String]) ?? []).filter { $0 != "_placeholder_" }
        var favoritedIDs = ((profileRecord["favoritedRecipeIDs"] as? [String]) ?? []).filter { $0 != "_placeholder_" }

        // Add recipe ID to appropriate list
        switch type {
        case .saved:
            if !savedIDs.contains(recipeID) {
                savedIDs.append(recipeID)
                userSavedRecipeIDs.insert(recipeID)
            }
        case .created:
            if !createdIDs.contains(recipeID) {
                createdIDs.append(recipeID)
                userCreatedRecipeIDs.insert(recipeID)
            }
        case .favorited:
            if !favoritedIDs.contains(recipeID) {
                favoritedIDs.append(recipeID)
                userFavoritedRecipeIDs.insert(recipeID)
            }
        }

        // Update record - CloudKit requires non-empty arrays for list fields
        // Use a placeholder value if array is empty
        profileRecord["savedRecipeIDs"] = savedIDs.isEmpty ? ["_placeholder_"] : savedIDs
        profileRecord["createdRecipeIDs"] = createdIDs.isEmpty ? ["_placeholder_"] : createdIDs
        profileRecord["favoritedRecipeIDs"] = favoritedIDs.isEmpty ? ["_placeholder_"] : favoritedIDs
        profileRecord["lastUpdated"] = Date()

        // Save to CloudKit
        _ = try await privateDB.save(profileRecord)

        // Update save count on recipe
        if type == .saved {
            await incrementSaveCount(for: recipeID)
        }

        print("✅ Added recipe \(recipeID) to user's \(type) list")
    }

    /// Remove recipe reference from user profile
    func removeRecipeFromUserProfile(_ recipeID: String, type: RecipeListType) async throws {
        guard let userID = getCurrentUserID() else { return }

        let profileRecord = try await fetchOrCreateUserProfile(userID)

        // Get current recipe IDs (handle nil fields for new profiles and filter placeholders)
        var savedIDs = ((profileRecord["savedRecipeIDs"] as? [String]) ?? []).filter { $0 != "_placeholder_" }
        var createdIDs = ((profileRecord["createdRecipeIDs"] as? [String]) ?? []).filter { $0 != "_placeholder_" }
        var favoritedIDs = ((profileRecord["favoritedRecipeIDs"] as? [String]) ?? []).filter { $0 != "_placeholder_" }

        // Remove recipe ID from appropriate list
        switch type {
        case .saved:
            savedIDs.removeAll { $0 == recipeID }
            userSavedRecipeIDs.remove(recipeID)
        case .created:
            createdIDs.removeAll { $0 == recipeID }
            userCreatedRecipeIDs.remove(recipeID)
        case .favorited:
            favoritedIDs.removeAll { $0 == recipeID }
            userFavoritedRecipeIDs.remove(recipeID)
        }

        // Update record - CloudKit requires non-empty arrays for list fields
        // Use a placeholder value if array is empty
        profileRecord["savedRecipeIDs"] = savedIDs.isEmpty ? ["_placeholder_"] : savedIDs
        profileRecord["createdRecipeIDs"] = createdIDs.isEmpty ? ["_placeholder_"] : createdIDs
        profileRecord["favoritedRecipeIDs"] = favoritedIDs.isEmpty ? ["_placeholder_"] : favoritedIDs
        profileRecord["lastUpdated"] = Date()

        // Save to CloudKit
        _ = try await privateDB.save(profileRecord)

        print("✅ Removed recipe \(recipeID) from user's \(type) list")
    }

    /// Load user's recipe references
    func loadUserRecipeReferences() {
        Task {
            // Only load CloudKit data if authenticated
            guard CloudKitAuthManager.shared.isAuthenticated else {
                print("📱 User not authenticated - skipping CloudKit recipe references")
                return
            }
            
            guard let userID = getCurrentUserID() else { return }

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

                print("✅ Loaded user recipe references: \(savedIDs.count) saved, \(createdIDs.count) created, \(favoritedIDs.count) favorited")
            } catch {
                print("❌ Failed to load user recipe references: \(error)")
            }
        }
    }

    /// Get user's saved recipes (optimized)
    func getUserSavedRecipes() async throws -> [Recipe] {
        // Check if user is authenticated with Apple/Google/Facebook
        guard CloudKitAuthManager.shared.isAuthenticated else {
            print("📱 User not authenticated - returning empty saved recipes")
            return []
        }
        
        print("📖 Getting user's saved recipes...")

        // Ensure references are loaded first
        if userSavedRecipeIDs.isEmpty && userCreatedRecipeIDs.isEmpty && userFavoritedRecipeIDs.isEmpty {
            // Try to load references if they haven't been loaded yet
            guard let userID = getCurrentUserID() else {
                print("⚠️ No user ID found for loading saved recipes")
                return []
            }

            print("📱 Loading recipe references for user: \(userID)")

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
        } else {
            print("📱 Using cached references: \(userSavedRecipeIDs.count) saved")
        }

        let recipes = try await fetchRecipes(by: Array(userSavedRecipeIDs))
        print("📖 Retrieved \(recipes.count) saved recipes")
        return recipes
    }

    /// Get user's created recipes (optimized)
    func getUserCreatedRecipes() async throws -> [Recipe] {
        // Check if user is authenticated with Apple/Google/Facebook
        guard CloudKitAuthManager.shared.isAuthenticated else {
            print("📱 User not authenticated - returning empty created recipes")
            return []
        }
        
        print("🍳 Getting user's created recipes...")

        // Ensure references are loaded first
        if userSavedRecipeIDs.isEmpty && userCreatedRecipeIDs.isEmpty && userFavoritedRecipeIDs.isEmpty {
            // Try to load references if they haven't been loaded yet
            guard let userID = getCurrentUserID() else {
                print("⚠️ No user ID found for loading created recipes")
                return []
            }

            print("📱 Loading recipe references for user: \(userID)")

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
        } else {
            print("📱 Using cached references: \(userCreatedRecipeIDs.count) created")
        }

        let recipes = try await fetchRecipes(by: Array(userCreatedRecipeIDs))
        print("🍳 Retrieved \(recipes.count) created recipes")
        return recipes
    }

    /// Get user's favorited recipes (optimized)
    func getUserFavoritedRecipes() async throws -> [Recipe] {
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

        let recipes = try await fetchRecipes(by: Array(userFavoritedRecipeIDs))
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
        // CRITICAL PRIVACY FIX: Only search user's own recipes and explicitly public recipes
        guard let currentUserID = getCurrentUserID() else {
            print("⚠️ No authenticated user - searching only public recipes")
            let predicate = NSPredicate(format: "(title CONTAINS[cd] %@ OR description CONTAINS[cd] %@) AND isPublic == 1", query, query)
            let ckQuery = CKQuery(recordType: "Recipe", predicate: predicate)
            ckQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try await performSearchQuery(ckQuery, limit: limit)
        }
        
        let predicate = NSPredicate(format: "(title CONTAINS[cd] %@ OR description CONTAINS[cd] %@) AND (ownerID == %@ OR isPublic == 1)", query, query, currentUserID)
        let ckQuery = CKQuery(recordType: "Recipe", predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        return try await performSearchQuery(ckQuery, limit: limit)
    }
    
    /// Helper method to perform search queries with consistent handling
    private func performSearchQuery(_ ckQuery: CKQuery, limit: Int) async throws -> [Recipe] {
        let (matchResults, _) = try await publicDB.records(matching: ckQuery, resultsLimit: limit)

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
    
    /// Fetch public recipes that are explicitly shared (separate from user's own recipes)
    func fetchPublicRecipes(limit: Int = 20) async throws -> [Recipe] {
        print("🌐 Fetching public recipes...")
        
        let predicate = NSPredicate(format: "isPublic == 1")
        let ckQuery = CKQuery(recordType: "Recipe", predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        let recipes = try await performSearchQuery(ckQuery, limit: limit)
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
        guard CloudKitAuthManager.shared.isAuthenticated else {
            return nil
        }
        
        // Try both keys for compatibility
        if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
            return userID
        }
        // Also check the key used by CloudKitAuthManager
        return UserDefaults.standard.string(forKey: "currentUserRecordID")
    }

    private func checkRecipeExists(_ name: String, _ description: String) async -> String? {
        // CRITICAL PRIVACY FIX: Only check current user's recipes for duplicates
        guard let currentUserID = getCurrentUserID() else {
            print("⚠️ No authenticated user - skipping duplicate check")
            return nil
        }
        
        // Only use title for query since description is not queryable, but filter by ownerID
        let predicate = NSPredicate(format: "title == %@ AND ownerID == %@", name, currentUserID)
        let query = CKQuery(recordType: "Recipe", predicate: predicate)

        do {
            let (matchResults, _) = try await privateDB.records(matching: query, resultsLimit: 1)
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
        let recordID = CKRecord.ID(recordName: "profile_\(userID)")

        do {
            // Try to fetch existing profile
            return try await privateDB.record(for: recordID)
        } catch {
            // Create new profile
            let record = CKRecord(recordType: "UserProfile", recordID: recordID)
            record["userID"] = userID
            // Don't set empty arrays - CloudKit doesn't like them
            // These fields will be created when we first add a recipe
            record["createdAt"] = Date()
            record["lastUpdated"] = Date()

            return try await privateDB.save(record)
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

        let recipe = Recipe(
            id: UUID(uuidString: id) ?? UUID(),
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
            isDetectiveRecipe: false
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
        do {
            let recordID = CKRecord.ID(recordName: recipeID)
            let record = try await publicDB.record(for: recordID)
            let currentCount = record["viewCount"] as? Int64 ?? 0
            record["viewCount"] = currentCount + 1
            _ = try await publicDB.save(record)
        } catch {
            print("Failed to increment view count: \(error)")
        }
    }

    private func incrementSaveCount(for recipeID: String) async {
        do {
            let recordID = CKRecord.ID(recordName: recipeID)
            let record = try await publicDB.record(for: recordID)
            let currentCount = record["saveCount"] as? Int64 ?? 0
            record["saveCount"] = currentCount + 1
            _ = try await publicDB.save(record)
        } catch {
            print("Failed to increment save count: \(error)")
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

    /// Fetch photos for a recipe
    func fetchRecipePhotos(for recipeID: String) async throws -> (before: UIImage?, after: UIImage?) {
        // Only fetch photos if authenticated
        guard CloudKitAuthManager.shared.isAuthenticated else {
            print("📱 User not authenticated - skipping CloudKit photo fetch")
            return (nil, nil)
        }
        
        let recordID = CKRecord.ID(recordName: recipeID)

        print("🔍 CloudKit: Fetching photos for recipe ID: \(recipeID)")

        do {
            // Try private database first
            let record = try await privateDB.record(for: recordID)
            let recipeTitle = record["title"] as? String ?? "Unknown Recipe"
            print("🔍 CloudKit: Found recipe '\(recipeTitle)' in Private DB, fetching photos...")
            let photos = await fetchPhotosFromRecord(record, recipeTitle: recipeTitle, recipeID: recipeID)
            return photos
        } catch {
            // Try public database
            let record = try await publicDB.record(for: recordID)
            let recipeTitle = record["title"] as? String ?? "Unknown Recipe"
            print("🔍 CloudKit: Found recipe '\(recipeTitle)' in Public DB, fetching photos...")
            let photos = await fetchPhotosFromRecord(record, recipeTitle: recipeTitle, recipeID: recipeID)
            return photos
        }
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
