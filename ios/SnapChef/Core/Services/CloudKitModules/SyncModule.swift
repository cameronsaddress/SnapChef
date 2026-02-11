import Foundation
import CloudKit
import SwiftUI
import UIKit

/// Sync module for CloudKit operations
/// Handles recipe sharing, social features, and sync operations
@MainActor
final class SyncModule: ObservableObject {
    
    // MARK: - Properties
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private weak var parent: CloudKitService?
    
    // MARK: - Initialization
    init(container: CKContainer, publicDB: CKDatabase, privateDB: CKDatabase, parent: CloudKitService) {
        self.container = container
        self.publicDatabase = publicDB
        self.privateDatabase = privateDB
        self.parent = parent
    }
    
    // MARK: - Recipe Upload Methods
    func uploadRecipe(_ recipe: Recipe, imageData: Data? = nil) async throws -> String {
        guard let userID = parent?.currentUser?.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        let recipeRecord = CKRecord(recordType: CloudKitConfig.recipeRecordType, recordID: CKRecord.ID(recordName: recipe.id.uuidString))
        
        // Set recipe fields
        recipeRecord[CKField.Recipe.id] = recipe.id.uuidString
        recipeRecord[CKField.Recipe.ownerID] = userID
        recipeRecord[CKField.Recipe.title] = recipe.name
        recipeRecord[CKField.Recipe.description] = recipe.description
        recipeRecord[CKField.Recipe.createdAt] = Date()
        recipeRecord[CKField.Recipe.likeCount] = Int64(0)
        recipeRecord[CKField.Recipe.commentCount] = Int64(0)
        recipeRecord[CKField.Recipe.viewCount] = Int64(0)
        recipeRecord[CKField.Recipe.shareCount] = Int64(0)
        recipeRecord[CKField.Recipe.isPublic] = Int64(1)
        recipeRecord[CKField.Recipe.cookingTime] = Int64(recipe.prepTime + recipe.cookTime)
        recipeRecord[CKField.Recipe.difficulty] = recipe.difficulty.rawValue
        recipeRecord[CKField.Recipe.cuisine] = ""
        
        // Convert ingredients and instructions to JSON
        let ingredientsData = try JSONEncoder().encode(recipe.ingredients.map { ing in
            ["name": ing.name, "quantity": ing.quantity, "unit": ing.unit ?? ""]
        })
        recipeRecord[CKField.Recipe.ingredients] = String(data: ingredientsData, encoding: .utf8) ?? "[]"
        
        let instructionsData = try JSONEncoder().encode(recipe.instructions)
        recipeRecord[CKField.Recipe.instructions] = String(data: instructionsData, encoding: .utf8) ?? "[]"
        
        // Handle image upload if provided
        if let imageData = imageData {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(recipe.id.uuidString).jpg")
            try imageData.write(to: tempURL)
            let imageAsset = CKAsset(fileURL: tempURL)
            recipeRecord["imageAsset"] = imageAsset
        }
        
        // Save to CloudKit
        let savedRecord = try await publicDatabase.save(recipeRecord)
        
        // Update share count
        await incrementShareCount(for: recipe.id.uuidString)
        
        // Create activity for followers
        try await createActivity(
            type: "recipeShared",
            actorID: userID,
            recipeID: recipe.id.uuidString,
            recipeName: recipe.name
        )
        
        return savedRecord.recordID.recordName
    }
    
    func fetchRecipe(by recordID: String) async throws -> (Recipe, CKRecord) {
        let recipeRecordID = CKRecord.ID(recordName: recordID)
        let record = try await publicDatabase.record(for: recipeRecordID)
        
        // Parse recipe from CloudKit record
        let recipe = try parseRecipeFromRecord(record)
        
        // Increment view count
        await incrementViewCount(for: recordID)
        
        return (recipe, record)
    }
    
    private func parseRecipeFromRecord(_ record: CKRecord) throws -> Recipe {
        guard let id = record[CKField.Recipe.id] as? String,
              let title = record[CKField.Recipe.title] as? String,
              let description = record[CKField.Recipe.description] as? String,
              let cookingTime = record[CKField.Recipe.cookingTime] as? Int64,
              let difficulty = record[CKField.Recipe.difficulty] as? String,
              let ingredientsJSON = record[CKField.Recipe.ingredients] as? String,
              let instructionsJSON = record[CKField.Recipe.instructions] as? String else {
            throw NSError(domain: "CloudKitSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid recipe data"])
        }
        
        // Parse ingredients
        let ingredientsData = ingredientsJSON.data(using: .utf8) ?? Data()
        let ingredientDicts = try JSONDecoder().decode([[String: String]].self, from: ingredientsData)
        let ingredients = ingredientDicts.map { dict in
            Ingredient(
                id: UUID(),
                name: dict["name"] ?? "",
                quantity: dict["quantity"] ?? "",
                unit: dict["unit"],
                isAvailable: true
            )
        }
        
        // Parse instructions
        let instructionsData = instructionsJSON.data(using: .utf8) ?? Data()
        let instructions = try JSONDecoder().decode([String].self, from: instructionsData)
        
        // Create recipe
        return Recipe(
            id: UUID(uuidString: id) ?? UUID(),
            ownerID: record[CKField.Recipe.ownerID] as? String,
            name: title,
            description: description,
            ingredients: ingredients,
            instructions: instructions,
            cookTime: Int(cookingTime) / 2,
            prepTime: Int(cookingTime) / 2,
            servings: 4,
            difficulty: Recipe.Difficulty(rawValue: difficulty) ?? .medium,
            nutrition: Nutrition(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: nil, sugar: nil, sodium: nil),
            imageURL: nil,
            createdAt: record[CKField.Recipe.createdAt] as? Date ?? Date(),
            tags: [],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false),
            isDetectiveRecipe: false,
            cookingTechniques: [],
            flavorProfile: nil,
            secretIngredients: [],
            proTips: [],
            visualClues: [],
            shareCaption: ""
        )
    }
    
    private func incrementShareCount(for recipeID: String) async {
        do {
            let record = try await publicDatabase.record(for: CKRecord.ID(recordName: recipeID))
            let currentCount = record[CKField.Recipe.shareCount] as? Int64 ?? 0
            record[CKField.Recipe.shareCount] = currentCount + 1
            try await publicDatabase.save(record)
        } catch {
            print("Failed to increment share count: \(error)")
        }
    }
    
    private func incrementViewCount(for recipeID: String) async {
        do {
            let record = try await publicDatabase.record(for: CKRecord.ID(recordName: recipeID))
            let currentCount = record[CKField.Recipe.viewCount] as? Int64 ?? 0
            record[CKField.Recipe.viewCount] = currentCount + 1
            try await publicDatabase.save(record)
        } catch {
            print("Failed to increment view count: \(error)")
        }
    }
    
    // MARK: - Recipe Like Methods
    func likeRecipe(_ recipeID: String, recipeOwnerID: String) async throws {
        guard let userID = parent?.currentUser?.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        // Check if already liked
        let isLiked = try await isRecipeLiked(recipeID)
        if isLiked {
            return // Already liked
        }
        
        // Create like record
        let like = CKRecord(recordType: CloudKitConfig.recipeLikeRecordType)
        like[CKField.RecipeLike.userID] = userID
        like[CKField.RecipeLike.recipeID] = recipeID
        like[CKField.RecipeLike.recipeOwnerID] = recipeOwnerID
        like[CKField.RecipeLike.likedAt] = Date()
        
        try await publicDatabase.save(like)
        
        // Update recipe like count
        await updateRecipeLikeCount(recipeID, increment: true)
        
        // Create activity for recipe owner
        if userID != recipeOwnerID {
            // Get recipe name for the activity
            var recipeName: String?
            do {
                let recipeRecord = try await publicDatabase.record(for: CKRecord.ID(recordName: recipeID))
                recipeName = recipeRecord[CKField.Recipe.title] as? String
            } catch {
                print("⚠️ Could not fetch recipe name for activity: \(error)")
            }
            
            try await createActivity(
                type: "recipeLiked",
                actorID: userID,
                targetUserID: recipeOwnerID,
                recipeID: recipeID,
                recipeName: recipeName
            )
        }
    }
    
    func likeRecipe(_ recipeID: String) async throws {
        // Resolve owner directly from recipe record so callers don't need to provide it.
        let recipeRecord = try await publicDatabase.record(for: CKRecord.ID(recordName: recipeID))
        let recipeOwnerID = recipeRecord[CKField.Recipe.ownerID] as? String ?? ""
        try await likeRecipe(recipeID, recipeOwnerID: recipeOwnerID)
    }
    
    func unlikeRecipe(_ recipeID: String) async throws {
        guard let userID = parent?.currentUser?.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        // Find the like record
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                  CKField.RecipeLike.userID, userID,
                                  CKField.RecipeLike.recipeID, recipeID)
        let query = CKQuery(recordType: CloudKitConfig.recipeLikeRecordType, predicate: predicate)
        
        let results = try await publicDatabase.records(matching: query)
        
        // Delete the like record
        for (recordID, result) in results.matchResults {
            if case .success = result {
                try await publicDatabase.deleteRecord(withID: recordID)
            }
        }
        
        // Update recipe like count
        await updateRecipeLikeCount(recipeID, increment: false)
    }
    
    func fetchUserLikedRecipeIDs() async throws -> [String] {
        guard let userID = parent?.currentUser?.recordID else {
            return []
        }
        
        let predicate = NSPredicate(format: "%K == %@", CKField.RecipeLike.userID, userID)
        let query = CKQuery(recordType: CloudKitConfig.recipeLikeRecordType, predicate: predicate)
        
        let results = try await publicDatabase.records(matching: query)
        var likedRecipeIDs: [String] = []
        
        for (_, result) in results.matchResults {
            if case .success(let record) = result,
               let recipeID = record[CKField.RecipeLike.recipeID] as? String {
                likedRecipeIDs.append(recipeID)
            }
        }
        
        return likedRecipeIDs
    }
    
    func isRecipeLiked(_ recipeID: String) async throws -> Bool {
        guard let userID = parent?.currentUser?.recordID else {
            return false
        }
        
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                  CKField.RecipeLike.userID, userID,
                                  CKField.RecipeLike.recipeID, recipeID)
        let query = CKQuery(recordType: CloudKitConfig.recipeLikeRecordType, predicate: predicate)
        
        let results = try await publicDatabase.records(matching: query)
        return !results.matchResults.isEmpty
    }
    
    func getRecipeLikeCount(_ recipeID: String) async throws -> Int {
        // Get like count directly from Recipe record for efficiency
        do {
            let recordID = CKRecord.ID(recordName: recipeID)
            let record = try await publicDatabase.record(for: recordID)
            return Int(record[CKField.Recipe.likeCount] as? Int64 ?? 0)
        } catch {
            // Fallback to counting RecipeLike records if Recipe record not found
            let predicate = NSPredicate(format: "%K == %@", CKField.RecipeLike.recipeID, recipeID)
            let query = CKQuery(recordType: CloudKitConfig.recipeLikeRecordType, predicate: predicate)
            let results = try await publicDatabase.records(matching: query)
            return results.matchResults.count
        }
    }
    
    private func updateRecipeLikeCount(_ recipeID: String, increment: Bool) async {
        do {
            // Fetch the recipe record from CloudKit
            let recordID = CKRecord.ID(recordName: recipeID)
            let record = try await publicDatabase.record(for: recordID)
            
            // Update the like count
            let currentCount = record[CKField.Recipe.likeCount] as? Int64 ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            record[CKField.Recipe.likeCount] = newCount
            
            // Save the updated record back to CloudKit
            try await publicDatabase.save(record)
            
            print("✅ Recipe \(recipeID) like count \(increment ? "incremented" : "decremented") to \(newCount)")
        } catch {
            print("❌ Failed to update recipe like count for \(recipeID): \(error)")
        }
    }
    
    /// Syncs the like count for a recipe by counting RecipeLike records
    /// This method can be used for data consistency and recovery
    func syncRecipeLikeCount(_ recipeID: String) async {
        do {
            // Count actual RecipeLike records
            let predicate = NSPredicate(format: "%K == %@", CKField.RecipeLike.recipeID, recipeID)
            let query = CKQuery(recordType: CloudKitConfig.recipeLikeRecordType, predicate: predicate)
            let results = try await publicDatabase.records(matching: query)
            let actualLikeCount = Int64(results.matchResults.count)
            
            // Update Recipe record with actual count
            let recordID = CKRecord.ID(recordName: recipeID)
            let record = try await publicDatabase.record(for: recordID)
            record[CKField.Recipe.likeCount] = actualLikeCount
            try await publicDatabase.save(record)
            
            print("♾️ Synced recipe \(recipeID) like count to \(actualLikeCount) from RecipeLike records")
        } catch {
            print("❌ Failed to sync recipe like count from records for \(recipeID): \(error)")
        }
    }
    
    // MARK: - Activity Feed Methods
    func createActivity(type: String, actorID: String,
                       targetUserID: String? = nil,
                       recipeID: String? = nil, recipeName: String? = nil,
                       challengeID: String? = nil, challengeName: String? = nil) async throws {
        let activity = CKRecord(recordType: CloudKitConfig.activityRecordType)
        activity[CKField.Activity.id] = UUID().uuidString
        activity[CKField.Activity.type] = type
        activity[CKField.Activity.actorID] = actorID
        activity[CKField.Activity.targetUserID] = targetUserID
        // Note: actorName and targetUserName are now fetched dynamically when displaying activities
        activity[CKField.Activity.recipeID] = recipeID
        activity[CKField.Activity.recipeName] = recipeName
        activity[CKField.Activity.challengeID] = challengeID
        activity[CKField.Activity.challengeName] = challengeName
        activity[CKField.Activity.timestamp] = Date()
        activity[CKField.Activity.isRead] = Int64(0)
        
        try await publicDatabase.save(activity)
    }
    
    func fetchActivityFeed(for userID: String, limit: Int = 20) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "%K == %@", CKField.Activity.targetUserID, userID)
        let query = CKQuery(recordType: CloudKitConfig.activityRecordType, predicate: predicate)
        // Remove timestamp sort descriptor since it may not be sortable in CloudKit
        // query.sortDescriptors = [NSSortDescriptor(key: CKField.Activity.timestamp, ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = limit
        
        var activities: [CKRecord] = []
        
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                activities.append(record)
            }
        }
        
        try await withCheckedThrowingContinuation { continuation in
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            publicDatabase.add(operation)
        }
        
        // Sort by timestamp in code since it may not be sortable in CloudKit
        // Use sorted to create a new array instead of mutating in-place
        let sortedActivities = activities.sorted { record1, record2 in
            let date1 = record1[CKField.Activity.timestamp] as? Date ?? Date.distantPast
            let date2 = record2[CKField.Activity.timestamp] as? Date ?? Date.distantPast
            return date1 > date2 // Descending order (newest first)
        }
        
        return sortedActivities
    }
    
    func markActivityAsRead(_ activityID: String) async throws {
        let recordID = CKRecord.ID(recordName: activityID)
        let record = try await publicDatabase.record(for: recordID)
        record[CKField.Activity.isRead] = Int64(1)
        try await publicDatabase.save(record)
    }
    
    // MARK: - Comment Methods
    func addComment(recipeID: String, content: String, parentCommentID: String? = nil) async throws {
        guard let userID = parent?.currentUser?.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        let comment = CKRecord(recordType: CloudKitConfig.recipeCommentRecordType)
        comment[CKField.RecipeComment.id] = UUID().uuidString
        comment[CKField.RecipeComment.userID] = userID
        comment[CKField.RecipeComment.recipeID] = recipeID
        comment[CKField.RecipeComment.content] = content
        comment[CKField.RecipeComment.createdAt] = Date()
        comment[CKField.RecipeComment.isDeleted] = Int64(0)
        comment[CKField.RecipeComment.likeCount] = Int64(0)
        comment[CKField.RecipeComment.parentCommentID] = parentCommentID
        
        try await publicDatabase.save(comment)
        
        // Update recipe comment count
        await updateRecipeCommentCount(recipeID, increment: true)
        
        // Create activity for recipe owner
        if let recipeRecord = try? await publicDatabase.record(for: CKRecord.ID(recordName: recipeID)),
           let recipeOwnerID = recipeRecord[CKField.Recipe.ownerID] as? String,
           recipeOwnerID != userID {
            try await createActivity(
                type: "recipeComment",
                actorID: userID,
                targetUserID: recipeOwnerID,
                recipeID: recipeID
            )
        }
    }
    
    func fetchComments(for recipeID: String, limit: Int = 50) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                  CKField.RecipeComment.recipeID, recipeID,
                                  CKField.RecipeComment.isDeleted, 0)
        let query = CKQuery(recordType: CloudKitConfig.recipeCommentRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.RecipeComment.createdAt, ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = limit
        
        var comments: [CKRecord] = []
        
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                comments.append(record)
            }
        }
        
        try await withCheckedThrowingContinuation { continuation in
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            publicDatabase.add(operation)
        }
        return comments
    }
    
    func deleteComment(_ commentID: String) async throws {
        let recordID = CKRecord.ID(recordName: commentID)
        let record = try await publicDatabase.record(for: recordID)
        
        // Soft delete
        record[CKField.RecipeComment.isDeleted] = Int64(1)
        try await publicDatabase.save(record)
        
        // Update recipe comment count
        if let recipeID = record[CKField.RecipeComment.recipeID] as? String {
            await updateRecipeCommentCount(recipeID, increment: false)
        }
    }

    // MARK: - Comment Like Methods
    func likeComment(_ commentID: String) async throws {
        guard let userID = parent?.currentUser?.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }

        var likedCommentIDs = locallyLikedCommentIDs(for: userID)
        guard !likedCommentIDs.contains(commentID) else { return }

        try await updateCommentLikeCount(commentID, increment: true)
        likedCommentIDs.insert(commentID)
        setLocallyLikedCommentIDs(likedCommentIDs, for: userID)
    }

    func unlikeComment(_ commentID: String) async throws {
        guard let userID = parent?.currentUser?.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }

        var likedCommentIDs = locallyLikedCommentIDs(for: userID)
        guard likedCommentIDs.contains(commentID) else { return }

        try await updateCommentLikeCount(commentID, increment: false)
        likedCommentIDs.remove(commentID)
        setLocallyLikedCommentIDs(likedCommentIDs, for: userID)
    }

    func isCommentLiked(_ commentID: String) async throws -> Bool {
        guard let userID = parent?.currentUser?.recordID else { return false }
        return locallyLikedCommentIDs(for: userID).contains(commentID)
    }
    
    private func updateRecipeCommentCount(_ recipeID: String, increment: Bool) async {
        do {
            let record = try await publicDatabase.record(for: CKRecord.ID(recordName: recipeID))
            let currentCount = record[CKField.Recipe.commentCount] as? Int64 ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            record[CKField.Recipe.commentCount] = newCount
            try await publicDatabase.save(record)
        } catch {
            print("Failed to update comment count for recipe \(recipeID): \(error)")
        }
    }

    private func updateCommentLikeCount(_ commentID: String, increment: Bool) async throws {
        let recordID = CKRecord.ID(recordName: commentID)
        let record = try await publicDatabase.record(for: recordID)

        let currentCount = record[CKField.RecipeComment.likeCount] as? Int64 ?? 0
        let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
        record[CKField.RecipeComment.likeCount] = newCount

        try await publicDatabase.save(record)
    }

    private func likedCommentsStorageKey(for userID: String) -> String {
        "likedCommentIDs.\(userID)"
    }

    private func locallyLikedCommentIDs(for userID: String) -> Set<String> {
        let key = likedCommentsStorageKey(for: userID)
        let ids = UserDefaults.standard.array(forKey: key) as? [String] ?? []
        return Set(ids)
    }

    private func setLocallyLikedCommentIDs(_ ids: Set<String>, for userID: String) {
        let key = likedCommentsStorageKey(for: userID)
        UserDefaults.standard.set(Array(ids), forKey: key)
    }

    // MARK: - Social Recipe Feed Methods
    func fetchSocialRecipeFeed(lastDate: Date? = nil, limit: Int = 20) async throws -> [SocialRecipeCard] {
        guard let currentUserID = parent?.currentUser?.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }

        let followingUserIDs = try await getFollowingUserIDs(for: currentUserID)
        if followingUserIDs.isEmpty {
            return []
        }

        var basePredicate: NSPredicate
        if followingUserIDs.count == 1 {
            basePredicate = NSPredicate(
                format: "%K == %@ AND %K == %d",
                CKField.Recipe.ownerID, followingUserIDs[0],
                CKField.Recipe.isPublic, 1
            )
        } else {
            basePredicate = NSPredicate(
                format: "%K IN %@ AND %K == %d",
                CKField.Recipe.ownerID, followingUserIDs,
                CKField.Recipe.isPublic, 1
            )
        }

        if let lastDate = lastDate {
            let datePredicate = NSPredicate(
                format: "%K < %@",
                CKField.Recipe.createdAt,
                lastDate as NSDate
            )
            basePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, datePredicate])
        }

        let query = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: basePredicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.Recipe.createdAt, ascending: false)]

        let results = try await publicDatabase.records(matching: query)

        var recipeRecords: [CKRecord] = []
        for (_, result) in results.matchResults {
            if case .success(let record) = result {
                recipeRecords.append(record)
            }
        }

        recipeRecords.sort {
            let date0 = $0[CKField.Recipe.createdAt] as? Date ?? .distantPast
            let date1 = $1[CKField.Recipe.createdAt] as? Date ?? .distantPast
            return date0 > date1
        }

        if recipeRecords.count > limit {
            recipeRecords = Array(recipeRecords.prefix(limit))
        }

        return await mapRecordsToSocialRecipeCards(recipeRecords)
    }

    private func getFollowingUserIDs(for userID: String) async throws -> [String] {
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %d",
            CKField.Follow.followerID, userID,
            CKField.Follow.isActive, 1
        )

        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        let results = try await publicDatabase.records(matching: query)

        var followingIDs: [String] = []
        for (_, result) in results.matchResults {
            if case .success(let record) = result,
               let followingID = record[CKField.Follow.followingID] as? String {
                followingIDs.append(followingID)
            }
        }

        return followingIDs
    }

    private func mapRecordsToSocialRecipeCards(_ records: [CKRecord]) async -> [SocialRecipeCard] {
        var socialRecipes: [SocialRecipeCard] = []
        var userCache: [String: CloudKitUser] = [:]

        for record in records {
            guard let ownerID = record[CKField.Recipe.ownerID] as? String else {
                continue
            }

            let creatorInfo: CloudKitUser
            if let cachedUser = userCache[ownerID] {
                creatorInfo = cachedUser
            } else {
                do {
                    let userRecord = try await publicDatabase.record(for: CKRecord.ID(recordName: ownerID))
                    let parsedUser = CloudKitUser(from: userRecord)
                    creatorInfo = parsedUser
                    userCache[ownerID] = parsedUser
                } catch {
                    let fallbackUser = CloudKitUser(from: makeFallbackUserRecord(for: ownerID))
                    creatorInfo = fallbackUser
                    userCache[ownerID] = fallbackUser
                }
            }

            var socialRecipe = SocialRecipeCard(from: record, creatorInfo: creatorInfo)
            let isLiked = (try? await isRecipeLiked(socialRecipe.id)) ?? false
            socialRecipe = SocialRecipeCard(
                id: socialRecipe.id,
                title: socialRecipe.title,
                description: socialRecipe.description,
                imageURL: socialRecipe.imageURL,
                createdAt: socialRecipe.createdAt,
                likeCount: socialRecipe.likeCount,
                commentCount: socialRecipe.commentCount,
                viewCount: socialRecipe.viewCount,
                difficulty: socialRecipe.difficulty,
                cookingTime: socialRecipe.cookingTime,
                isLiked: isLiked,
                creatorID: socialRecipe.creatorID,
                creatorName: socialRecipe.creatorName,
                creatorImageURL: socialRecipe.creatorImageURL,
                creatorIsVerified: socialRecipe.creatorIsVerified
            )

            socialRecipes.append(socialRecipe)
        }

        return socialRecipes
    }

    private func makeFallbackUserRecord(for ownerID: String) -> CKRecord {
        let fallbackRecord = CKRecord(
            recordType: CloudKitConfig.userRecordType,
            recordID: CKRecord.ID(recordName: ownerID)
        )
        fallbackRecord[CKField.User.displayName] = "Unknown Chef"
        fallbackRecord[CKField.User.email] = ""
        fallbackRecord[CKField.User.authProvider] = "unknown"
        fallbackRecord[CKField.User.totalPoints] = Int64(0)
        fallbackRecord[CKField.User.currentStreak] = Int64(0)
        fallbackRecord[CKField.User.longestStreak] = Int64(0)
        fallbackRecord[CKField.User.challengesCompleted] = Int64(0)
        fallbackRecord[CKField.User.recipesShared] = Int64(0)
        fallbackRecord[CKField.User.recipesCreated] = Int64(0)
        fallbackRecord[CKField.User.coinBalance] = Int64(0)
        fallbackRecord[CKField.User.followerCount] = Int64(0)
        fallbackRecord[CKField.User.followingCount] = Int64(0)
        fallbackRecord[CKField.User.isVerified] = Int64(0)
        fallbackRecord[CKField.User.isProfilePublic] = Int64(1)
        fallbackRecord[CKField.User.showOnLeaderboard] = Int64(0)
        fallbackRecord[CKField.User.subscriptionTier] = "free"
        fallbackRecord[CKField.User.createdAt] = Date()
        fallbackRecord[CKField.User.lastLoginAt] = Date()
        fallbackRecord[CKField.User.lastActiveAt] = Date()
        return fallbackRecord
    }
    
    // MARK: - Challenge Sync Methods
    func triggerChallengeSync() async {
        await syncChallenges()
        await syncUserProgress()
        await syncLeaderboard()
    }
    
    func syncChallenges() async {
        parent?.isSyncing = true
        
        do {
            let now = Date()
            let predicate = NSPredicate(format: "startDate <= %@ AND endDate >= %@", now as NSDate, now as NSDate)
            let query = CKQuery(recordType: CloudKitConfig.challengeRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: CKField.Challenge.startDate, ascending: true)]
            
            let results = try await publicDatabase.records(matching: query)
            
            var challenges: [Challenge] = []
            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    if let challenge = Challenge(from: record) {
                        challenges.append(challenge)
                    }
                }
            }
            
            // Also fetch upcoming challenges (next 7 days)
            let nextWeek = now.addingTimeInterval(7 * 24 * 60 * 60)
            let upcomingPredicate = NSPredicate(format: "startDate > %@ AND startDate <= %@", now as NSDate, nextWeek as NSDate)
            let upcomingQuery = CKQuery(recordType: CloudKitConfig.challengeRecordType, predicate: upcomingPredicate)
            upcomingQuery.sortDescriptors = [NSSortDescriptor(key: CKField.Challenge.startDate, ascending: true)]
            
            let upcomingResults = try await publicDatabase.records(matching: upcomingQuery)
            
            for (_, result) in upcomingResults.matchResults {
                if case .success(let record) = result {
                    if let challenge = Challenge(from: record) {
                        challenges.append(challenge)
                    }
                }
            }
            
            // Update local storage
            await MainActor.run {
                GamificationManager.shared.updateChallenges(challenges)
            }
            parent?.lastSyncDate = Date()
            parent?.isSyncing = false
            
            print("✅ Synced \(challenges.count) challenges (active and upcoming)")
        } catch {
            parent?.syncError = error
            parent?.isSyncing = false
            print("❌ Failed to sync challenges: \(error)")
        }
    }
    
    func syncUserProgress() async {
        guard let userID = UnifiedAuthManager.shared.currentUser?.recordID else { return }

        do {
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: CloudKitConfig.userChallengeRecordType, predicate: predicate)

            let results = try await privateDatabase.records(matching: query)

            var userChallenges: [UserChallenge] = []
            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    if let recordUserID = record[CKField.UserChallenge.userID] as? String,
                       recordUserID == userID {
                        userChallenges.append(UserChallenge(from: record))
                    }
                }
            }

            await MainActor.run {
                GamificationManager.shared.syncUserChallenges(userChallenges)
            }

            print("✅ Synced \(userChallenges.count) user challenges")
        } catch {
            print("❌ Failed to sync user progress: \(error)")
        }
    }
    
    private func syncLeaderboard() async {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: CloudKitConfig.leaderboardRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.Leaderboard.totalPoints, ascending: false)]

        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 100

        operation.queryResultBlock = { result in
            Task { @MainActor in
                switch result {
                case .success:
                    print("✅ Synced leaderboard entries")
                case .failure(let error):
                    print("❌ Failed to sync leaderboard: \(error)")
                }
            }
        }

        publicDatabase.add(operation)
    }
    
    // MARK: - Challenge Proof Submission
    func submitChallengeProof(challengeID: String, proofImage: UIImage, notes: String? = nil) async throws {
        guard let userID = parent?.currentUser?.recordID else {
            throw UnifiedAuthError.notAuthenticated
        }
        
        // Find or create UserChallenge record
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                  CKField.UserChallenge.userID, userID,
                                  "challengeID", challengeID)
        let query = CKQuery(recordType: CloudKitConfig.userChallengeRecordType, predicate: predicate)
        
        let results = try await publicDatabase.records(matching: query)
        
        var userChallengeRecord: CKRecord
        
        if let (_, result) = results.matchResults.first,
           case .success(let record) = result {
            userChallengeRecord = record
        } else {
            // Create new UserChallenge record
            userChallengeRecord = CKRecord(recordType: CloudKitConfig.userChallengeRecordType)
            userChallengeRecord[CKField.UserChallenge.userID] = userID
            userChallengeRecord["challengeID"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: challengeID), action: .none)
            userChallengeRecord[CKField.UserChallenge.startedAt] = Date()
        }
        
        // Update progress
        userChallengeRecord[CKField.UserChallenge.status] = "completed"
        userChallengeRecord[CKField.UserChallenge.progress] = 1.0
        userChallengeRecord[CKField.UserChallenge.completedAt] = Date()
        
        // Add notes if provided
        if let notes = notes {
            userChallengeRecord[CKField.UserChallenge.notes] = notes
        }
        
        // Upload proof image
        if let imageData = proofImage.jpegData(compressionQuality: 0.8) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            try imageData.write(to: tempURL)
            let imageAsset = CKAsset(fileURL: tempURL)
            userChallengeRecord[CKField.UserChallenge.proofImage] = imageAsset
            
            // Also store URL for quick access
            userChallengeRecord[CKField.UserChallenge.proofImageURL] = tempURL.absoluteString
        }
        
        // Save to CloudKit
        _ = try await publicDatabase.save(userChallengeRecord)
        
        // Update challenge participant/completion counts
        await updateChallengeStats(challengeID: challengeID, completed: true)
        
        print("✅ Challenge proof submitted successfully")
    }
    
    private func updateChallengeStats(challengeID: String, completed: Bool) async {
        do {
            let recordID = CKRecord.ID(recordName: challengeID)
            let record = try await publicDatabase.record(for: recordID)
            
            if completed {
                let currentCount = record[CKField.Challenge.completionCount] as? Int64 ?? 0
                record[CKField.Challenge.completionCount] = currentCount + 1
            } else {
                let currentCount = record[CKField.Challenge.participantCount] as? Int64 ?? 0
                record[CKField.Challenge.participantCount] = currentCount + 1
            }
            
            _ = try await publicDatabase.save(record)
        } catch {
            print("Failed to update challenge stats: \(error)")
        }
    }
    
    func updateLeaderboardEntry(for userID: String, points: Int, challengesCompleted: Int) async throws {
        let recordID = CKRecord.ID(recordName: userID)
        
        do {
            // Try to fetch existing record
            let record = try await publicDatabase.record(for: recordID)
            record[CKField.Leaderboard.totalPoints] = (record[CKField.Leaderboard.totalPoints] as? Int ?? 0) + points
            record[CKField.Leaderboard.challengesCompleted] = challengesCompleted
            record[CKField.Leaderboard.lastUpdated] = Date()
            
            _ = try await publicDatabase.save(record)
        } catch {
            // Create new record if doesn't exist
            let newRecord = CKRecord(recordType: CloudKitConfig.leaderboardRecordType, recordID: recordID)
            newRecord[CKField.Leaderboard.userID] = userID
            newRecord[CKField.Leaderboard.totalPoints] = points
            newRecord[CKField.Leaderboard.challengesCompleted] = challengesCompleted
            newRecord[CKField.Leaderboard.lastUpdated] = Date()
            
            _ = try await publicDatabase.save(newRecord)
        }
        
        print("✅ Updated leaderboard entry")
    }
    
    // MARK: - Subscriptions
    func setupSubscriptions() {
        container.accountStatus { [weak self] status, statusError in
            guard let self else { return }

            if let statusError {
                print("⚠️ Skipping challenge subscription setup (account status error): \(statusError.localizedDescription)")
                return
            }

            guard status == .available else {
                print("⏭️ Skipping challenge subscription setup - CloudKit account unavailable (\(status.rawValue))")
                return
            }

            // Subscribe to challenge updates
            let challengePredicate = NSPredicate(value: true)
            let challengeSubscription = CKQuerySubscription(
                recordType: CloudKitConfig.challengeRecordType,
                predicate: challengePredicate,
                subscriptionID: CloudKitConfig.challengeUpdatesSubscription,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate]
            )

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            challengeSubscription.notificationInfo = notificationInfo

            self.publicDatabase.save(challengeSubscription) { _, error in
                if let ckError = error as? CKError, ckError.code == .notAuthenticated {
                    print("⏭️ Challenge subscription deferred - user not authenticated with iCloud yet")
                    return
                }

                if let error {
                    print("❌ Failed to create challenge subscription: \(error)")
                } else {
                    print("✅ Challenge subscription created")
                }
            }
        }
    }
}
