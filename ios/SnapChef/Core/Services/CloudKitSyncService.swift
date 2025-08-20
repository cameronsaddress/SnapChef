import Foundation
import CloudKit
import Combine
import UIKit

@MainActor
final class CloudKitSyncService: ObservableObject {
    // Fix for Swift concurrency issue with @MainActor singletons
    static let shared: CloudKitSyncService = {
        let instance = CloudKitSyncService()
        return instance
    }()

    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase

    @Published var isSyncing = false
    @Published var syncError: Error?
    @Published var lastSyncDate: Date?

    private var cancellables = Set<AnyCancellable>()
    private var syncQueue = DispatchQueue(label: "com.snapchef.cloudkit.sync", qos: .background)

    private init() {
        container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
        publicDatabase = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase

        setupSubscriptions()
        checkiCloudStatus()
    }

    // MARK: - Recipe Upload Methods

    func uploadRecipe(_ recipe: Recipe, imageData: Data? = nil) async throws -> String {
        guard let userID = CloudKitAuthManager.shared.currentUser?.recordID,
              let userName = CloudKitAuthManager.shared.currentUser?.displayName else {
            throw CloudKitAuthError.notAuthenticated
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
        recipeRecord[CKField.Recipe.cuisine] = "" // Recipe doesn't have cuisine field

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
        // Note: In a real app, you'd create activities for all followers
        // For now, we'll just log it
        try await createActivity(
            type: "recipeShared",
            actorID: userID,
            actorName: userName,
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
        guard let userID = CloudKitAuthManager.shared.currentUser?.recordID,
              let userName = CloudKitAuthManager.shared.currentUser?.displayName else {
            throw CloudKitAuthError.notAuthenticated
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
                actorName: userName,
                targetUserID: recipeOwnerID,
                recipeID: recipeID,
                recipeName: recipeName
            )
        }
    }

    func unlikeRecipe(_ recipeID: String) async throws {
        guard let userID = CloudKitAuthManager.shared.currentUser?.recordID else {
            throw CloudKitAuthError.notAuthenticated
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

    func isRecipeLiked(_ recipeID: String) async throws -> Bool {
        guard let userID = CloudKitAuthManager.shared.currentUser?.recordID else {
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
            // If updating fails, try to sync from RecipeLike records
            await syncRecipeLikeCountFromRecords(recipeID)
        }
    }
    
    /// Syncs the like count for a recipe by counting RecipeLike records
    /// This method can be used for data consistency and recovery
    private func syncRecipeLikeCountFromRecords(_ recipeID: String) async {
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

    /// Public method to sync like count for a recipe (useful for data recovery)
    func syncRecipeLikeCount(_ recipeID: String) async {
        await syncRecipeLikeCountFromRecords(recipeID)
    }
    
    // MARK: - Activity Feed Methods

    func createActivity(type: String, actorID: String, actorName: String,
                       targetUserID: String? = nil, targetUserName: String? = nil,
                       recipeID: String? = nil, recipeName: String? = nil,
                       challengeID: String? = nil, challengeName: String? = nil) async throws {
        let activity = CKRecord(recordType: CloudKitConfig.activityRecordType)
        activity[CKField.Activity.id] = UUID().uuidString
        activity[CKField.Activity.type] = type
        activity[CKField.Activity.actorID] = actorID
        activity[CKField.Activity.actorName] = actorName
        activity[CKField.Activity.targetUserID] = targetUserID
        activity[CKField.Activity.targetUserName] = targetUserName
        activity[CKField.Activity.recipeID] = recipeID
        activity[CKField.Activity.recipeName] = recipeName
        activity[CKField.Activity.challengeID] = challengeID
        activity[CKField.Activity.challengeName] = challengeName
        activity[CKField.Activity.timestamp] = Date()
        activity[CKField.Activity.isRead] = Int64(0)

        try await publicDatabase.save(activity)
    }

    func fetchActivityFeed(for userID: String, limit: Int = 20) async throws -> [CKRecord] {
        // Fetch activities where user is the target or activities from users they follow
        let predicate = NSPredicate(format: "%K == %@", CKField.Activity.targetUserID, userID)
        let query = CKQuery(recordType: CloudKitConfig.activityRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.Activity.timestamp, ascending: false)]

        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = limit

        var activities: [CKRecord] = []

        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                activities.append(record)
            }
        }

        try await publicDatabase.add(operation)
        return activities
    }

    func markActivityAsRead(_ activityID: String) async throws {
        let recordID = CKRecord.ID(recordName: activityID)
        let record = try await publicDatabase.record(for: recordID)
        record[CKField.Activity.isRead] = Int64(1)
        try await publicDatabase.save(record)
    }

    // MARK: - Comment Methods

    func addComment(recipeID: String, content: String, parentCommentID: String? = nil) async throws {
        guard let userID = CloudKitAuthManager.shared.currentUser?.recordID,
              let userName = CloudKitAuthManager.shared.currentUser?.displayName else {
            print("❌ Cannot add comment: User not authenticated")
            throw CloudKitAuthError.notAuthenticated
        }

        print("📝 Creating comment for recipe: \(recipeID)")
        print("👤 User: \(userName) (ID: \(userID))")
        print("💬 Content: \(content)")

        let commentID = UUID().uuidString
        let comment = CKRecord(recordType: CloudKitConfig.recipeCommentRecordType, recordID: CKRecord.ID(recordName: commentID))
        
        // Debug field assignments
        print("🔧 Setting comment fields:")
        comment[CKField.RecipeComment.id] = commentID
        print("   - id: \(commentID)")
        comment[CKField.RecipeComment.userID] = userID
        print("   - userID: \(userID)")
        comment[CKField.RecipeComment.recipeID] = recipeID
        print("   - recipeID: \(recipeID)")
        comment[CKField.RecipeComment.content] = content
        print("   - content: \(content)")
        comment[CKField.RecipeComment.createdAt] = Date()
        print("   - createdAt: \(Date())")
        comment[CKField.RecipeComment.isDeleted] = Int64(0)
        print("   - isDeleted: 0")
        comment[CKField.RecipeComment.likeCount] = Int64(0)
        print("   - likeCount: 0")
        comment[CKField.RecipeComment.parentCommentID] = parentCommentID
        print("   - parentCommentID: \(parentCommentID ?? "nil")")

        print("💾 Saving comment to CloudKit...")
        let savedComment = try await publicDatabase.save(comment)
        print("✅ Comment saved to CloudKit with ID: \(commentID)")

        // Update recipe comment count
        await updateRecipeCommentCount(recipeID, increment: true)

        // Create activity for recipe owner
        if let recipeRecord = try? await publicDatabase.record(for: CKRecord.ID(recordName: recipeID)),
           let recipeOwnerID = recipeRecord[CKField.Recipe.ownerID] as? String,
           recipeOwnerID != userID {
            try await createActivity(
                type: "recipeComment",
                actorID: userID,
                actorName: userName,
                targetUserID: recipeOwnerID,
                recipeID: recipeID
            )
        }
    }

    func fetchComments(for recipeID: String, limit: Int = 50) async throws -> [CKRecord] {
        print("🔍 Fetching comments for recipe: \(recipeID)")
        
        let predicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                  CKField.RecipeComment.recipeID, recipeID,
                                  CKField.RecipeComment.isDeleted, 0)
        let query = CKQuery(recordType: CloudKitConfig.recipeCommentRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.RecipeComment.createdAt, ascending: false)]

        print("📊 Query predicate: \(predicate)")
        print("📊 Record type: \(CloudKitConfig.recipeCommentRecordType)")

        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = limit

            var comments: [CKRecord] = []

            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    comments.append(record)
                    print("✅ Found comment record: \(record.recordID.recordName)")
                case .failure(let error):
                    print("❌ Failed to process comment record: \(error)")
                }
            }

            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    print("✅ Comment query completed successfully. Found \(comments.count) comments")
                    continuation.resume(returning: comments)
                case .failure(let error):
                    print("❌ Comment query failed: \(error)")
                    continuation.resume(throwing: error)
                }
            }

            publicDatabase.add(operation)
        }
    }

    func deleteComment(_ commentID: String) async throws {
        let recordID = CKRecord.ID(recordName: commentID)
        let record = try await publicDatabase.record(for: recordID)

        // Soft delete
        record[CKField.RecipeComment.isDeleted] = Int64(1)
        let savedRecord = try await publicDatabase.save(record)
        print("✅ Comment soft deleted in CloudKit with ID: \(commentID)")

        // Update recipe comment count
        if let recipeID = record[CKField.RecipeComment.recipeID] as? String {
            await updateRecipeCommentCount(recipeID, increment: false)
        }
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

    // MARK: - Comment Like Methods
    
    func likeComment(_ commentID: String) async throws {
        guard let userID = CloudKitAuthManager.shared.currentUser?.recordID else {
            throw CloudKitAuthError.notAuthenticated
        }

        // Check if already liked
        let isLiked = try await isCommentLiked(commentID)
        if isLiked {
            return // Already liked
        }

        // Create like record (using a CommentLike record type - would need to be added to schema)
        // For now, just update the comment's like count directly
        await updateCommentLikeCount(commentID, increment: true)
    }

    func unlikeComment(_ commentID: String) async throws {
        guard let userID = CloudKitAuthManager.shared.currentUser?.recordID else {
            throw CloudKitAuthError.notAuthenticated
        }

        // Remove like and update count
        await updateCommentLikeCount(commentID, increment: false)
    }

    func isCommentLiked(_ commentID: String) async throws -> Bool {
        // TODO: Implement comment like tracking
        // This would require a CommentLike record type similar to RecipeLike
        return false
    }

    private func updateCommentLikeCount(_ commentID: String, increment: Bool) async {
        do {
            let recordID = CKRecord.ID(recordName: commentID)
            let record = try await publicDatabase.record(for: recordID)
            
            let currentCount = record[CKField.RecipeComment.likeCount] as? Int64 ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            record[CKField.RecipeComment.likeCount] = newCount
            
            try await publicDatabase.save(record)
            print("✅ Comment \(commentID) like count \(increment ? "incremented" : "decremented") to \(newCount)")
        } catch {
            print("❌ Failed to update comment like count for \(commentID): \(error)")
        }
    }

    // MARK: - iCloud Status
    private func checkiCloudStatus() {
        container.accountStatus { [weak self] status, _ in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    print("✅ iCloud available")
                    // Removed automatic sync - only sync when needed
                case .noAccount:
                    print("❌ No iCloud account")
                case .restricted:
                    print("⚠️ iCloud restricted")
                case .temporarilyUnavailable:
                    print("⏳ iCloud temporarily unavailable")
                case .couldNotDetermine:
                    print("❓ Could not determine iCloud status")
                @unknown default:
                    print("❓ Unknown iCloud status")
                }
            }
        }
    }

    // MARK: - Manual Setup (Only when needed)
    /// Call this manually when challenge/leaderboard data is needed
    func triggerChallengeSync() async {
        await syncChallenges()
        await syncUserProgress()
        await syncLeaderboard()
    }

    // MARK: - Subscriptions
    private func setupSubscriptions() {
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

        publicDatabase.save(challengeSubscription) { _, error in
            if let error = error {
                print("❌ Failed to create challenge subscription: \(error)")
            } else {
                print("✅ Challenge subscription created")
            }
        }
    }

    // MARK: - Sync Operations
    func syncChallenges() async {
        await MainActor.run { isSyncing = true }

        do {
            // Query challenges that should be active now
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
                lastSyncDate = Date()
                isSyncing = false
            }

            print("✅ Synced \(challenges.count) challenges (active and upcoming)")
        } catch {
            await MainActor.run {
                syncError = error
                isSyncing = false
            }
            print("❌ Failed to sync challenges: \(error)")
        }
    }

    func syncUserProgress() async {
        guard let userID = AuthenticationManager().currentUser?.id else { return }

        do {
            // Query user's challenge progress
            let predicate = NSPredicate(format: "%K == %@", CKField.UserChallenge.userID, userID)
            let query = CKQuery(recordType: CloudKitConfig.userChallengeRecordType, predicate: predicate)

            let results = try await privateDatabase.records(matching: query)

            var userChallenges: [UserChallenge] = []
            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    userChallenges.append(UserChallenge(from: record))
                }
            }

            // Update local storage
            await MainActor.run {
                GamificationManager.shared.syncUserChallenges(userChallenges)
            }

            print("✅ Synced \(userChallenges.count) user challenges")
        } catch {
            print("❌ Failed to sync user progress: \(error)")
        }
    }

    func syncLeaderboard() async {
        do {
            // Query top 100 global leaderboard
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: CloudKitConfig.leaderboardRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: CKField.Leaderboard.totalPoints, ascending: false)]

            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = 100

            var leaderboardEntries: [LeaderboardEntry] = []

            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    // Use LeaderboardEntry directly
                }
            }

            operation.queryResultBlock = { result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        print("✅ Synced \(leaderboardEntries.count) leaderboard entries")
                        // Update UI with leaderboard data
                    case .failure(let error):
                        print("❌ Failed to sync leaderboard: \(error)")
                    }
                }
            }

            publicDatabase.add(operation)
        }
    }

    // MARK: - Save Operations
    func saveUserChallenge(_ userChallenge: UserChallenge) async throws {
        // Moved to CloudKitManager
        try await CloudKitManager.shared.saveUserChallenge(userChallenge)
    }

    // Team functionality removed

    // MARK: - Challenge Proof Submission

    func submitChallengeProof(challengeID: String, proofImage: UIImage, notes: String? = nil) async throws {
        guard let userID = CloudKitAuthManager.shared.currentUser?.recordID else {
            throw CloudKitAuthError.notAuthenticated
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
            userChallengeRecord["proofImage"] = imageAsset

            // Also store URL for quick access
            userChallengeRecord[CKField.UserChallenge.proofImageURL] = tempURL.absoluteString
        }

        // Save to CloudKit
        _ = try await publicDatabase.save(userChallengeRecord)

        // Update challenge participant/completion counts
        await updateChallengeStats(challengeID: challengeID, completed: true)

        // Award points and coins
        if let challenge = GamificationManager.shared.getChallenge(by: challengeID) {
            await awardChallengeRewards(challenge: challenge, userID: userID)
        }

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

    private func awardChallengeRewards(challenge: Challenge, userID: String) async {
        // Update user points and coins
        var updates = UserStatUpdates()

        if let currentUser = CloudKitAuthManager.shared.currentUser {
            // Note: CloudKitAuthManager.currentUser uses experiencePoints instead of totalPoints
            // and doesn't have coinBalance property
            updates.experiencePoints = currentUser.experiencePoints + challenge.points
            // Coin balance functionality not available in current CloudKitAuthManager user model
            updates.challengesCompleted = currentUser.challengesCompleted + 1

            do {
                try await CloudKitAuthManager.shared.updateUserStats(updates)

                // Update leaderboard
                try await updateLeaderboardEntry(
                    for: userID,
                    points: challenge.points,
                    challengesCompleted: currentUser.challengesCompleted + 1
                )
            } catch {
                print("Failed to award challenge rewards: \(error)")
            }
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
    
    // MARK: - Social Recipe Feed Methods
    
    func fetchSocialRecipeFeed(lastDate: Date? = nil, limit: Int = 20) async throws -> [SocialRecipeCard] {
        guard let currentUser = CloudKitAuthManager.shared.currentUser,
              let currentUserID = currentUser.recordID else {
            throw CloudKitAuthError.notAuthenticated
        }
        
        // Step 1: Get list of users that the current user follows
        let followingUserIDs = try await getFollowingUserIDs(for: currentUserID)
        
        if followingUserIDs.isEmpty {
            print("ℹ️ User is not following anyone, returning empty feed")
            return []
        }
        
        // Step 2: Fetch recipes from those users
        var predicate: NSPredicate
        
        if followingUserIDs.count == 1 {
            // Single user predicate
            predicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                  CKField.Recipe.ownerID, followingUserIDs[0],
                                  CKField.Recipe.isPublic, 1)
        } else {
            // Multiple users predicate  
            predicate = NSPredicate(format: "%K IN %@ AND %K == %d",
                                  CKField.Recipe.ownerID, followingUserIDs,
                                  CKField.Recipe.isPublic, 1)
        }
        
        // Add date filter for pagination
        if let lastDate = lastDate {
            let datePredicate = NSPredicate(format: "%K < %@", CKField.Recipe.createdAt, lastDate as NSDate)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, datePredicate])
        }
        
        let query = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.Recipe.createdAt, ascending: false)]
        
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = limit
        
        var recipeRecords: [CKRecord] = []
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    recipeRecords.append(record)
                }
            }
            
            operation.queryResultBlock = { result in
                Task {
                    switch result {
                    case .success:
                        // Step 3: Get user details for each recipe's owner
                        let socialRecipes = await self.mapRecordsToSocialRecipeCards(recipeRecords)
                        continuation.resume(returning: socialRecipes)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            publicDatabase.add(operation)
        }
    }
    
    private func getFollowingUserIDs(for userID: String) async throws -> [String] {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                  CKField.Follow.followerID, userID,
                                  CKField.Follow.isActive, 1)
        
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        let results = try await publicDatabase.records(matching: query)
        
        var followingIDs: [String] = []
        for (_, result) in results.matchResults {
            if case .success(let record) = result {
                if let followingID = record[CKField.Follow.followingID] as? String {
                    followingIDs.append(followingID)
                }
            }
        }
        
        print("✅ Found \(followingIDs.count) users that current user follows")
        return followingIDs
    }
    
    private func mapRecordsToSocialRecipeCards(_ records: [CKRecord]) async -> [SocialRecipeCard] {
        var socialRecipes: [SocialRecipeCard] = []
        
        // Cache for user details to avoid duplicate queries
        var userCache: [String: CloudKitUser] = [:]
        
        for record in records {
            guard let ownerID = record[CKField.Recipe.ownerID] as? String else {
                continue
            }
            
            // Get user details (use cache if available)
            var creatorInfo: CloudKitUser
            if let cachedUser = userCache[ownerID] {
                creatorInfo = cachedUser
            } else {
                do {
                    let userRecord = try await publicDatabase.record(for: CKRecord.ID(recordName: ownerID))
                    creatorInfo = CloudKitUser(from: userRecord)
                    userCache[ownerID] = creatorInfo
                } catch {
                    print("❌ Failed to fetch user details for \(ownerID): \(error)")
                    // Create a minimal CloudKit record and parse it
                    let minimalRecord = CKRecord(recordType: CloudKitConfig.userRecordType, recordID: CKRecord.ID(recordName: ownerID))
                    minimalRecord[CKField.User.displayName] = "Unknown Chef"
                    minimalRecord[CKField.User.email] = ""
                    minimalRecord[CKField.User.authProvider] = "unknown"
                    minimalRecord[CKField.User.totalPoints] = Int64(0)
                    minimalRecord[CKField.User.currentStreak] = Int64(0)
                    minimalRecord[CKField.User.longestStreak] = Int64(0)
                    minimalRecord[CKField.User.challengesCompleted] = Int64(0)
                    minimalRecord[CKField.User.recipesShared] = Int64(0)
                    minimalRecord[CKField.User.recipesCreated] = Int64(0)
                    minimalRecord[CKField.User.coinBalance] = Int64(0)
                    minimalRecord[CKField.User.followerCount] = Int64(0)
                    minimalRecord[CKField.User.followingCount] = Int64(0)
                    minimalRecord[CKField.User.isVerified] = Int64(0)
                    minimalRecord[CKField.User.isProfilePublic] = Int64(1)
                    minimalRecord[CKField.User.showOnLeaderboard] = Int64(0)
                    minimalRecord[CKField.User.subscriptionTier] = "free"
                    minimalRecord[CKField.User.createdAt] = Date()
                    minimalRecord[CKField.User.lastLoginAt] = Date()
                    minimalRecord[CKField.User.lastActiveAt] = Date()
                    
                    creatorInfo = CloudKitUser(from: minimalRecord)
                }
            }
            
            // Create SocialRecipeCard
            var socialRecipe = SocialRecipeCard(from: record, creatorInfo: creatorInfo)
            
            // Check if current user liked this recipe
            do {
                let isLiked = try await isRecipeLiked(socialRecipe.id)
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
            } catch {
                print("❌ Failed to check like status for recipe \(socialRecipe.id): \(error)")
            }
            
            socialRecipes.append(socialRecipe)
        }
        
        print("✅ Mapped \(socialRecipes.count) records to SocialRecipeCard objects")
        return socialRecipes
    }
}

// MARK: - CloudKit Model Extensions

extension Challenge {
    init?(from record: CKRecord) {
        guard let id = record[CKField.Challenge.id] as? String,
              let title = record[CKField.Challenge.title] as? String,
              let description = record[CKField.Challenge.description] as? String,
              let typeRaw = record[CKField.Challenge.type] as? String,
              let category = record[CKField.Challenge.category] as? String,
              let difficultyInt = record[CKField.Challenge.difficulty] as? Int64,
              let difficulty = DifficultyLevel(rawValue: Int(difficultyInt)),
              let points = record[CKField.Challenge.points] as? Int64,
              let coins = record[CKField.Challenge.coins] as? Int64,
              let startDate = record[CKField.Challenge.startDate] as? Date,
              let endDate = record[CKField.Challenge.endDate] as? Date,
              let isActiveInt = record[CKField.Challenge.isActive] as? Int64,
              let isPremiumInt = record[CKField.Challenge.isPremium] as? Int64,
              let participantCount = record[CKField.Challenge.participantCount] as? Int64,
              let completionCount = record[CKField.Challenge.completionCount] as? Int64 else {
            print("❌ Failed to parse challenge from CloudKit record")
            return nil
        }

        // Parse type
        let type: ChallengeType
        switch typeRaw.lowercased() {
        case "daily":
            type = .daily
        case "weekly":
            type = .weekly
        case "special":
            type = .special
        case "community":
            type = .community
        default:
            type = .daily
        }

        // Parse requirements from pipe-separated string
        var requirements: [String] = []
        if let requirementsString = record[CKField.Challenge.requirements] as? String {
            requirements = requirementsString.split(separator: "|").map { String($0) }
        }

        self.init(
            id: id,
            title: title,
            description: description,
            type: type,
            category: category,
            difficulty: difficulty,
            points: Int(points),
            coins: Int(coins),
            startDate: startDate,
            endDate: endDate,
            requirements: requirements,
            currentProgress: 0,
            isCompleted: false,
            isActive: isActiveInt == 1,
            isJoined: false,
            participants: Int(participantCount),
            completions: Int(completionCount),
            imageURL: record[CKField.Challenge.imageURL] as? String,
            isPremium: isPremiumInt == 1
        )
    }
}
