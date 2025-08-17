import Foundation
import CloudKit

// Extended recipe model that includes CloudKit metadata
struct CloudKitRecipe {
    let recipe: Recipe
    let ownerID: String
    let ownerName: String
    let cloudKitRecordID: String?
    let likeCount: Int
    let commentCount: Int
    let viewCount: Int
    let shareCount: Int
    let createdAt: Date

    init(recipe: Recipe, ownerID: String = "", ownerName: String = "", cloudKitRecordID: String? = nil,
         likeCount: Int = 0, commentCount: Int = 0, viewCount: Int = 0, shareCount: Int = 0,
         createdAt: Date = Date()) {
        self.recipe = recipe
        self.ownerID = ownerID
        self.ownerName = ownerName
        self.cloudKitRecordID = cloudKitRecordID
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.viewCount = viewCount
        self.shareCount = shareCount
        self.createdAt = createdAt
    }

    init(from record: CKRecord) throws {
        // Extract recipe data
        let id = UUID(uuidString: record[CKField.Recipe.id] as? String ?? "") ?? UUID()
        let name = record[CKField.Recipe.title] as? String ?? "Untitled"
        let description = record[CKField.Recipe.description] as? String ?? ""
        let cookingTime = Int(record[CKField.Recipe.cookingTime] as? Int64 ?? 30)
        let difficulty = Recipe.Difficulty(rawValue: record[CKField.Recipe.difficulty] as? String ?? "Easy") ?? .easy

        // Parse ingredients from JSON
        var ingredients: [Ingredient] = []
        if let ingredientsJSON = record[CKField.Recipe.ingredients] as? String,
           let data = ingredientsJSON.data(using: .utf8),
           let ingredientArray = try? JSONDecoder().decode([[String: String]].self, from: data) {
            ingredients = ingredientArray.map { dict in
                Ingredient(
                    id: UUID(),
                    name: dict["name"] ?? "",
                    quantity: dict["quantity"] ?? "",
                    unit: dict["unit"],
                    isAvailable: true
                )
            }
        }

        // Parse instructions from JSON
        var instructions: [String] = []
        if let instructionsJSON = record[CKField.Recipe.instructions] as? String,
           let data = instructionsJSON.data(using: .utf8),
           let instructionArray = try? JSONDecoder().decode([String].self, from: data) {
            instructions = instructionArray
        }

        // Create Recipe object
        self.recipe = Recipe(
            id: id,
            name: name,
            description: description,
            ingredients: ingredients,
            instructions: instructions,
            cookTime: cookingTime / 2, // Assume half is cook time
            prepTime: cookingTime / 2, // Assume half is prep time
            servings: 4, // Default servings
            difficulty: difficulty,
            nutrition: Nutrition(calories: 400, protein: 20, carbs: 50, fat: 15, fiber: 5, sugar: 10, sodium: 800),
            imageURL: record[CKField.Recipe.imageURL] as? String,
            createdAt: record[CKField.Recipe.createdAt] as? Date ?? Date(),
            tags: [],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false)
        )

        // Extract CloudKit metadata
        self.ownerID = record[CKField.Recipe.ownerID] as? String ?? ""
        self.ownerName = "" // Will need to be fetched separately
        self.cloudKitRecordID = record.recordID.recordName
        self.likeCount = Int(record[CKField.Recipe.likeCount] as? Int64 ?? 0)
        self.commentCount = Int(record[CKField.Recipe.commentCount] as? Int64 ?? 0)
        self.viewCount = Int(record[CKField.Recipe.viewCount] as? Int64 ?? 0)
        self.shareCount = Int(record[CKField.Recipe.shareCount] as? Int64 ?? 0)
        self.createdAt = record[CKField.Recipe.createdAt] as? Date ?? Date()
    }
}
