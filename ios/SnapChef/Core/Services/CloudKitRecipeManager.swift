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
    func uploadRecipe(_ recipe: Recipe, fromLLM: Bool = false) async throws -> String {
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
        
        // Save to CloudKit
        let savedRecord = try await publicDB.save(record)
        
        // Cache locally
        cachedRecipes[recipeID] = recipe
        
        // Add to user's created recipes
        if fromLLM {
            try await addRecipeToUserProfile(recipeID, type: .created)
        }
        
        print("✅ Recipe uploaded to CloudKit: \(recipeID)")
        return savedRecord.recordID.recordName
    }
    
    // MARK: - Recipe Fetching
    
    /// Fetch a recipe by ID (checks cache first, then CloudKit)
    func fetchRecipe(by recipeID: String) async throws -> Recipe {
        // Check local cache first
        if let cached = cachedRecipes[recipeID] {
            print("📱 Recipe found in cache: \(recipeID)")
            return cached
        }
        
        // Fetch from CloudKit
        let recordID = CKRecord.ID(recordName: recipeID)
        let record = try await publicDB.record(for: recordID)
        
        // Parse recipe
        let recipe = try parseRecipeFromRecord(record)
        
        // Cache locally
        cachedRecipes[recipeID] = recipe
        
        // Increment view count
        await incrementViewCount(for: recipeID)
        
        print("☁️ Recipe fetched from CloudKit: \(recipeID)")
        return recipe
    }
    
    /// Batch fetch recipes by IDs
    func fetchRecipes(by recipeIDs: [String]) async throws -> [Recipe] {
        var recipes: [Recipe] = []
        
        for id in recipeIDs {
            do {
                let recipe = try await fetchRecipe(by: id)
                recipes.append(recipe)
            } catch {
                print("❌ Failed to fetch recipe \(id): \(error)")
            }
        }
        
        return recipes
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
        
        // Get current recipe IDs
        var savedIDs = (profileRecord["savedRecipeIDs"] as? [String]) ?? []
        var createdIDs = (profileRecord["createdRecipeIDs"] as? [String]) ?? []
        var favoritedIDs = (profileRecord["favoritedRecipeIDs"] as? [String]) ?? []
        
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
        
        // Update record
        profileRecord["savedRecipeIDs"] = savedIDs
        profileRecord["createdRecipeIDs"] = createdIDs
        profileRecord["favoritedRecipeIDs"] = favoritedIDs
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
        
        // Get current recipe IDs
        var savedIDs = (profileRecord["savedRecipeIDs"] as? [String]) ?? []
        var createdIDs = (profileRecord["createdRecipeIDs"] as? [String]) ?? []
        var favoritedIDs = (profileRecord["favoritedRecipeIDs"] as? [String]) ?? []
        
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
        
        // Update record
        profileRecord["savedRecipeIDs"] = savedIDs
        profileRecord["createdRecipeIDs"] = createdIDs
        profileRecord["favoritedRecipeIDs"] = favoritedIDs
        profileRecord["lastUpdated"] = Date()
        
        // Save to CloudKit
        _ = try await privateDB.save(profileRecord)
        
        print("✅ Removed recipe \(recipeID) from user's \(type) list")
    }
    
    /// Load user's recipe references
    func loadUserRecipeReferences() {
        Task {
            guard let userID = getCurrentUserID() else { return }
            
            do {
                let profileRecord = try await fetchOrCreateUserProfile(userID)
                
                let savedIDs = (profileRecord["savedRecipeIDs"] as? [String]) ?? []
                let createdIDs = (profileRecord["createdRecipeIDs"] as? [String]) ?? []
                let favoritedIDs = (profileRecord["favoritedRecipeIDs"] as? [String]) ?? []
                
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
    
    /// Get user's saved recipes
    func getUserSavedRecipes() async throws -> [Recipe] {
        return try await fetchRecipes(by: Array(userSavedRecipeIDs))
    }
    
    /// Get user's created recipes
    func getUserCreatedRecipes() async throws -> [Recipe] {
        return try await fetchRecipes(by: Array(userCreatedRecipeIDs))
    }
    
    /// Get user's favorited recipes
    func getUserFavoritedRecipes() async throws -> [Recipe] {
        return try await fetchRecipes(by: Array(userFavoritedRecipeIDs))
    }
    
    // MARK: - Recipe Sharing
    
    /// Generate a shareable link for a recipe
    func generateShareLink(for recipeID: String) -> URL {
        var components = URLComponents()
        components.scheme = "snapchef"
        components.host = "recipe"
        components.path = "/\(recipeID)"
        
        return components.url ?? URL(string: "snapchef://recipe/\(recipeID)")!
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
    
    /// Search for recipes by query
    func searchRecipes(query: String, limit: Int = 20) async throws -> [Recipe] {
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@ OR description CONTAINS[cd] %@", query, query)
        let ckQuery = CKQuery(recordType: "Recipe", predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
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
    
    // MARK: - Helper Methods
    
    private func getCurrentUserID() -> String? {
        return UserDefaults.standard.string(forKey: "currentUserID")
    }
    
    private func checkRecipeExists(_ name: String, _ description: String) async -> String? {
        let predicate = NSPredicate(format: "title == %@ AND description == %@", name, description)
        let query = CKQuery(recordType: "Recipe", predicate: predicate)
        
        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            if let record = try? matchResults.first?.1.get() {
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
            record["savedRecipeIDs"] = [String]()
            record["createdRecipeIDs"] = [String]()
            record["favoritedRecipeIDs"] = [String]()
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
            dietaryInfo: dietaryInfo
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