import Foundation
import SwiftUI

struct Recipe: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let ingredients: [Ingredient]
    let instructions: [String]
    let cookTime: Int
    let prepTime: Int
    let servings: Int
    let difficulty: Difficulty
    let nutrition: Nutrition
    let imageURL: String?
    let createdAt: Date
    let tags: [String]
    let dietaryInfo: DietaryInfo
    
    enum Difficulty: String, Codable, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        
        var color: String {
            switch self {
            case .easy: return "#4CAF50"
            case .medium: return "#FF9800"
            case .hard: return "#F44336"
            }
        }
        
        var emoji: String {
            switch self {
            case .easy: return "🧑‍🍳"
            case .medium: return "👨‍🍳"
            case .hard: return "👩‍🍳🔥"
            }
        }
        
        var swiftUIColor: Color {
            switch self {
            case .easy: return Color(hex: "#43e97b")
            case .medium: return Color(hex: "#ffa726")
            case .hard: return Color(hex: "#ef5350")
            }
        }
    }
}

struct Ingredient: Identifiable, Codable {
    let id: UUID
    let name: String
    let quantity: String
    let unit: String?
    let isAvailable: Bool
}

struct Nutrition: Codable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let fiber: Int?
    let sugar: Int?
    let sodium: Int?
}

struct RecipeGenerationRequest: Codable {
    let imageBase64: String
    let dietaryPreferences: [String]
    let mealType: String?
    let servings: Int
}

struct DietaryInfo: Codable {
    let isVegetarian: Bool
    let isVegan: Bool
    let isGlutenFree: Bool
    let isDairyFree: Bool
}

struct RecipeGenerationResponse: Codable {
    let success: Bool
    let recipes: [Recipe]?
    let error: String?
    let creditsRemaining: Int
}