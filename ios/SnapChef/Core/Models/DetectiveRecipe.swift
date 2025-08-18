import Foundation
import SwiftUI

// MARK: - DetectiveRecipe Model
/// A specialized recipe model that extends the base Recipe model for reverse-engineered recipes
public struct DetectiveRecipe: Identifiable, Codable, Sendable {
    public let id: UUID

    // Base recipe properties
    let name: String
    let description: String
    let ingredients: [Ingredient]
    let instructions: [String]
    let cookTime: Int
    let prepTime: Int
    let servings: Int
    let difficulty: Recipe.Difficulty
    let nutrition: Nutrition
    let imageURL: String?
    let createdAt: Date
    let tags: [String]
    let dietaryInfo: DietaryInfo

    // Detective-specific properties
    let isDetectiveRecipe: Bool = true
    let confidenceScore: Double // 0-100 scale
    let originalDishName: String
    let restaurantStyle: String?
    let analyzedAt: Date

    /// Initialize DetectiveRecipe from base Recipe with detective-specific data
    init(
        baseRecipe: Recipe,
        confidenceScore: Double,
        originalDishName: String,
        restaurantStyle: String? = nil
    ) {
        self.id = baseRecipe.id
        self.name = baseRecipe.name
        self.description = baseRecipe.description
        self.ingredients = baseRecipe.ingredients
        self.instructions = baseRecipe.instructions
        self.cookTime = baseRecipe.cookTime
        self.prepTime = baseRecipe.prepTime
        self.servings = baseRecipe.servings
        self.difficulty = baseRecipe.difficulty
        self.nutrition = baseRecipe.nutrition
        self.imageURL = baseRecipe.imageURL
        self.createdAt = baseRecipe.createdAt
        self.tags = baseRecipe.tags
        self.dietaryInfo = baseRecipe.dietaryInfo

        // Detective-specific properties
        self.confidenceScore = max(0, min(100, confidenceScore)) // Clamp to 0-100
        self.originalDishName = originalDishName
        self.restaurantStyle = restaurantStyle
        self.analyzedAt = Date()
    }

    /// Direct initializer for complete control
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        ingredients: [Ingredient],
        instructions: [String],
        cookTime: Int,
        prepTime: Int,
        servings: Int,
        difficulty: Recipe.Difficulty,
        nutrition: Nutrition,
        imageURL: String? = nil,
        createdAt: Date = Date(),
        tags: [String],
        dietaryInfo: DietaryInfo,
        confidenceScore: Double,
        originalDishName: String,
        restaurantStyle: String? = nil,
        analyzedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.ingredients = ingredients
        self.instructions = instructions
        self.cookTime = cookTime
        self.prepTime = prepTime
        self.servings = servings
        self.difficulty = difficulty
        self.nutrition = nutrition
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.tags = tags
        self.dietaryInfo = dietaryInfo
        self.confidenceScore = max(0, min(100, confidenceScore))
        self.originalDishName = originalDishName
        self.restaurantStyle = restaurantStyle
        self.analyzedAt = analyzedAt
    }
}

// MARK: - Extensions
extension DetectiveRecipe {
    /// Convert DetectiveRecipe to base Recipe model for compatibility
    func toBaseRecipe() -> Recipe {
        return Recipe(
            id: self.id,
            name: self.name,
            description: self.description,
            ingredients: self.ingredients,
            instructions: self.instructions,
            cookTime: self.cookTime,
            prepTime: self.prepTime,
            servings: self.servings,
            difficulty: self.difficulty,
            nutrition: self.nutrition,
            imageURL: self.imageURL,
            createdAt: self.createdAt,
            tags: self.tags,
            dietaryInfo: self.dietaryInfo
        )
    }

    /// Confidence level for UI display
    var confidenceLevel: ConfidenceLevel {
        switch confidenceScore {
        case 0..<40:
            return .low
        case 40..<70:
            return .medium
        case 70..<85:
            return .high
        case 85...100:
            return .veryHigh
        default:
            return .low
        }
    }

    /// Confidence description for user display
    var confidenceDescription: String {
        switch confidenceLevel {
        case .veryHigh:
            return "Very confident match"
        case .high:
            return "Confident match"
        case .medium:
            return "Good match"
        case .low:
            return "Possible match"
        }
    }

    /// Color for confidence indicator
    var confidenceColor: Color {
        switch confidenceLevel {
        case .veryHigh:
            return Color(hex: "#4CAF50") // Green
        case .high:
            return Color(hex: "#8BC34A") // Light green
        case .medium:
            return Color(hex: "#FF9800") // Orange
        case .low:
            return Color(hex: "#F44336") // Red
        }
    }

    /// Emoji for confidence level
    var confidenceEmoji: String {
        switch confidenceLevel {
        case .veryHigh:
            return "🎯"
        case .high:
            return "✅"
        case .medium:
            return "🤔"
        case .low:
            return "❓"
        }
    }
}

// MARK: - Supporting Types
enum ConfidenceLevel: String, Codable, CaseIterable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case veryHigh = "Very High"
}

// MARK: - API Response Model
struct DetectiveRecipeResponse: Codable, Sendable {
    let success: Bool
    let detectiveRecipe: DetectiveRecipeAPI?
    let message: String
    let creditsRemaining: Int?

    enum CodingKeys: String, CodingKey {
        case success
        case detectiveRecipe = "detective_recipe"
        case message
        case creditsRemaining = "credits_remaining"
    }
}

struct DetectiveRecipeAPI: Codable, Sendable {
    // Base recipe data (matches RecipeAPI structure)
    let id: String
    let name: String
    let description: String
    let main_dish: String?
    let side_dish: String?
    let total_time: Int?
    let prep_time: Int?
    let cook_time: Int?
    let servings: Int?
    let difficulty: String
    let ingredients_used: [IngredientUsed]?
    let instructions: [String]
    let nutrition: NutritionAPI?
    let tips: String?
    let tags: [String]?
    let share_caption: String?

    // Detective-specific API fields
    let confidence_score: Double
    let original_dish_name: String
    let restaurant_style: String?
    let analysis_details: AnalysisDetails?

    struct AnalysisDetails: Codable, Sendable {
        let visual_features: [String]?
        let flavor_profile: [String]?
        let cooking_techniques: [String]?
        let ingredient_substitutions: [String: String]?
    }
}

// MARK: - Error Types
enum DetectiveRecipeError: Error, LocalizedError {
    case imageNotRecognized(String)
    case lowConfidence(String)
    case analysisTimeout(String)
    case premiumRequired(String)

    var errorDescription: String? {
        switch self {
        case .imageNotRecognized(let message):
            return message
        case .lowConfidence(let message):
            return message
        case .analysisTimeout(let message):
            return message
        case .premiumRequired(let message):
            return message
        }
    }
}