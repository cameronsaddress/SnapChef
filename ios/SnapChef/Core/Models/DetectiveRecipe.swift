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
    let isDetectiveRecipe: Bool
    let confidenceScore: Double // 0-100 scale
    let originalDishName: String
    let restaurantStyle: String?
    let analyzedAt: Date
    let cookingTechniques: [String]
    let flavorProfile: DetectiveFlavorProfile?
    let secretIngredients: [String]
    let proTips: [String]
    let visualClues: [String]
    let shareCaption: String?

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
        self.isDetectiveRecipe = true
        self.confidenceScore = max(0, min(100, confidenceScore)) // Clamp to 0-100
        self.originalDishName = originalDishName
        self.restaurantStyle = restaurantStyle
        self.analyzedAt = Date()
        self.cookingTechniques = []
        self.flavorProfile = nil
        self.secretIngredients = []
        self.proTips = []
        self.visualClues = []
        self.shareCaption = nil
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
        analyzedAt: Date = Date(),
        cookingTechniques: [String] = [],
        flavorProfile: DetectiveFlavorProfile? = nil,
        secretIngredients: [String] = [],
        proTips: [String] = [],
        visualClues: [String] = [],
        shareCaption: String? = nil
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
        self.isDetectiveRecipe = true
        self.confidenceScore = max(0, min(100, confidenceScore))
        self.originalDishName = originalDishName
        self.restaurantStyle = restaurantStyle
        self.analyzedAt = analyzedAt
        self.cookingTechniques = cookingTechniques
        self.flavorProfile = flavorProfile
        self.secretIngredients = secretIngredients
        self.proTips = proTips
        self.visualClues = visualClues
        self.shareCaption = shareCaption
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
            dietaryInfo: self.dietaryInfo,
            isDetectiveRecipe: true
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

// MARK: - Detective Flavor Profile
struct DetectiveFlavorProfile: Codable, Sendable {
    let sweet: Int      // 1-10 scale
    let salty: Int      // 1-10 scale
    let sour: Int       // 1-10 scale
    let bitter: Int     // 1-10 scale
    let umami: Int      // 1-10 scale
}

// MARK: - API Response Model
struct DetectiveRecipeResponse: Codable, Sendable {
    let success: Bool
    let detectiveRecipe: DetectiveRecipeAPI?
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case detectiveRecipe = "detective_recipe"
        case message
    }
}

// MARK: - Detective Recipe API Model (matches server exactly)
struct DetectiveRecipeAPI: Codable, Sendable {
    let id: String
    let originalDishName: String
    let restaurantStyle: String
    let confidenceScore: Int
    let name: String
    let description: String
    let ingredients: [DetectiveIngredientAPI]
    let instructions: [String]
    let prepTime: Int
    let cookTime: Int
    let servings: Int
    let difficulty: String
    let nutrition: DetectiveNutritionAPI
    let cookingTechniques: [String]
    let flavorProfile: DetectiveFlavorProfileAPI
    let secretIngredients: [String]
    let proTips: [String]
    let visualClues: [String]
    let tags: [String]
    let shareCaption: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case originalDishName = "original_dish_name"
        case restaurantStyle = "restaurant_style"
        case confidenceScore = "confidence_score"
        case name
        case description
        case ingredients
        case instructions
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case servings
        case difficulty
        case nutrition
        case cookingTechniques = "cooking_techniques"
        case flavorProfile = "flavor_profile"
        case secretIngredients = "secret_ingredients"
        case proTips = "pro_tips"
        case visualClues = "visual_clues"
        case tags
        case shareCaption = "share_caption"
    }
}

// MARK: - Supporting API Models
struct DetectiveIngredientAPI: Codable, Sendable {
    let name: String
    let amount: String
    let preparation: String
}

struct DetectiveNutritionAPI: Codable, Sendable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

struct DetectiveFlavorProfileAPI: Codable, Sendable {
    let sweet: Int
    let salty: Int
    let sour: Int
    let bitter: Int
    let umami: Int
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