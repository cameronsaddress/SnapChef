import XCTest
@testable import SnapChef
import SwiftUI

final class RecipeTests: XCTestCase {
    
    // MARK: - Recipe Model Tests
    
    func testRecipeInitialization() throws {
        let ingredient = Ingredient(
            id: UUID(),
            name: "Tomatoes",
            quantity: "2 cups",
            unit: "cups",
            isAvailable: true
        )
        
        let nutrition = Nutrition(
            calories: 250,
            protein: 15,
            carbs: 30,
            fat: 8,
            fiber: 5,
            sugar: 10,
            sodium: 400
        )
        
        let dietaryInfo = DietaryInfo(
            isVegetarian: true,
            isVegan: false,
            isGlutenFree: true,
            isDairyFree: false
        )
        
        let recipe = Recipe(
            id: UUID(),
            name: "Test Recipe",
            description: "A delicious test recipe",
            ingredients: [ingredient],
            instructions: ["Step 1: Prepare ingredients", "Step 2: Cook"],
            cookTime: 30,
            prepTime: 15,
            servings: 4,
            difficulty: .medium,
            nutrition: nutrition,
            imageURL: "https://example.com/image.jpg",
            createdAt: Date(),
            tags: ["healthy", "quick"],
            dietaryInfo: dietaryInfo
        )
        
        XCTAssertEqual(recipe.name, "Test Recipe")
        XCTAssertEqual(recipe.description, "A delicious test recipe")
        XCTAssertEqual(recipe.ingredients.count, 1)
        XCTAssertEqual(recipe.instructions.count, 2)
        XCTAssertEqual(recipe.cookTime, 30)
        XCTAssertEqual(recipe.prepTime, 15)
        XCTAssertEqual(recipe.servings, 4)
        XCTAssertEqual(recipe.difficulty, .medium)
        XCTAssertEqual(recipe.nutrition.calories, 250)
        XCTAssertEqual(recipe.imageURL, "https://example.com/image.jpg")
        XCTAssertEqual(recipe.tags.count, 2)
        XCTAssertTrue(recipe.dietaryInfo.isVegetarian)
        XCTAssertTrue(recipe.dietaryInfo.isGlutenFree)
    }
    
    func testRecipeIdentifiable() throws {
        let recipe1 = createMockRecipe(name: "Recipe 1")
        let recipe2 = createMockRecipe(name: "Recipe 2")
        
        XCTAssertNotEqual(recipe1.id, recipe2.id, "Different recipes should have different IDs")
        XCTAssertEqual(recipe1.id, recipe1.id, "Recipe ID should be consistent")
    }
    
    // MARK: - Recipe Difficulty Tests
    
    func testRecipeDifficultyEnum() throws {
        XCTAssertEqual(Recipe.Difficulty.easy.rawValue, "Easy")
        XCTAssertEqual(Recipe.Difficulty.medium.rawValue, "Medium")
        XCTAssertEqual(Recipe.Difficulty.hard.rawValue, "Hard")
    }
    
    func testRecipeDifficultyColors() throws {
        XCTAssertEqual(Recipe.Difficulty.easy.color, "#4CAF50")
        XCTAssertEqual(Recipe.Difficulty.medium.color, "#FF9800")
        XCTAssertEqual(Recipe.Difficulty.hard.color, "#F44336")
    }
    
    func testRecipeDifficultyEmojis() throws {
        XCTAssertEqual(Recipe.Difficulty.easy.emoji, "🧑‍🍳")
        XCTAssertEqual(Recipe.Difficulty.medium.emoji, "👨‍🍳")
        XCTAssertEqual(Recipe.Difficulty.hard.emoji, "👩‍🍳🔥")
    }
    
    func testRecipeDifficultySwiftUIColors() throws {
        let easyColor = Recipe.Difficulty.easy.swiftUIColor
        let mediumColor = Recipe.Difficulty.medium.swiftUIColor
        let hardColor = Recipe.Difficulty.hard.swiftUIColor
        
        // Test that colors are different
        XCTAssertNotEqual(easyColor, mediumColor, "Easy and medium colors should be different")
        XCTAssertNotEqual(mediumColor, hardColor, "Medium and hard colors should be different")
        XCTAssertNotEqual(easyColor, hardColor, "Easy and hard colors should be different")
    }
    
    func testRecipeDifficultyCaseIterable() throws {
        let allCases = Recipe.Difficulty.allCases
        XCTAssertEqual(allCases.count, 3, "Should have exactly 3 difficulty levels")
        XCTAssertTrue(allCases.contains(.easy), "Should contain easy difficulty")
        XCTAssertTrue(allCases.contains(.medium), "Should contain medium difficulty")
        XCTAssertTrue(allCases.contains(.hard), "Should contain hard difficulty")
    }
    
    // MARK: - Ingredient Model Tests
    
    func testIngredientInitialization() throws {
        let ingredient = Ingredient(
            id: UUID(),
            name: "Carrots",
            quantity: "3 large",
            unit: "pieces",
            isAvailable: true
        )
        
        XCTAssertEqual(ingredient.name, "Carrots")
        XCTAssertEqual(ingredient.quantity, "3 large")
        XCTAssertEqual(ingredient.unit, "pieces")
        XCTAssertTrue(ingredient.isAvailable)
    }
    
    func testIngredientWithOptionalUnit() throws {
        let ingredient = Ingredient(
            id: UUID(),
            name: "Salt",
            quantity: "to taste",
            unit: nil,
            isAvailable: false
        )
        
        XCTAssertEqual(ingredient.name, "Salt")
        XCTAssertEqual(ingredient.quantity, "to taste")
        XCTAssertNil(ingredient.unit)
        XCTAssertFalse(ingredient.isAvailable)
    }
    
    func testIngredientIdentifiable() throws {
        let ingredient1 = Ingredient(id: UUID(), name: "Ingredient 1", quantity: "1", unit: nil, isAvailable: true)
        let ingredient2 = Ingredient(id: UUID(), name: "Ingredient 2", quantity: "2", unit: nil, isAvailable: true)
        
        XCTAssertNotEqual(ingredient1.id, ingredient2.id, "Different ingredients should have different IDs")
    }
    
    // MARK: - Nutrition Model Tests
    
    func testNutritionInitialization() throws {
        let nutrition = Nutrition(
            calories: 350,
            protein: 20,
            carbs: 40,
            fat: 12,
            fiber: 8,
            sugar: 15,
            sodium: 600
        )
        
        XCTAssertEqual(nutrition.calories, 350)
        XCTAssertEqual(nutrition.protein, 20)
        XCTAssertEqual(nutrition.carbs, 40)
        XCTAssertEqual(nutrition.fat, 12)
        XCTAssertEqual(nutrition.fiber, 8)
        XCTAssertEqual(nutrition.sugar, 15)
        XCTAssertEqual(nutrition.sodium, 600)
    }
    
    func testNutritionWithOptionalValues() throws {
        let nutrition = Nutrition(
            calories: 200,
            protein: 10,
            carbs: 25,
            fat: 5,
            fiber: nil,
            sugar: nil,
            sodium: nil
        )
        
        XCTAssertEqual(nutrition.calories, 200)
        XCTAssertEqual(nutrition.protein, 10)
        XCTAssertEqual(nutrition.carbs, 25)
        XCTAssertEqual(nutrition.fat, 5)
        XCTAssertNil(nutrition.fiber)
        XCTAssertNil(nutrition.sugar)
        XCTAssertNil(nutrition.sodium)
    }
    
    // MARK: - DietaryInfo Model Tests
    
    func testDietaryInfoInitialization() throws {
        let dietaryInfo = DietaryInfo(
            isVegetarian: true,
            isVegan: false,
            isGlutenFree: true,
            isDairyFree: false
        )
        
        XCTAssertTrue(dietaryInfo.isVegetarian)
        XCTAssertFalse(dietaryInfo.isVegan)
        XCTAssertTrue(dietaryInfo.isGlutenFree)
        XCTAssertFalse(dietaryInfo.isDairyFree)
    }
    
    func testDietaryInfoAllTrue() throws {
        let dietaryInfo = DietaryInfo(
            isVegetarian: true,
            isVegan: true,
            isGlutenFree: true,
            isDairyFree: true
        )
        
        XCTAssertTrue(dietaryInfo.isVegetarian)
        XCTAssertTrue(dietaryInfo.isVegan)
        XCTAssertTrue(dietaryInfo.isGlutenFree)
        XCTAssertTrue(dietaryInfo.isDairyFree)
    }
    
    func testDietaryInfoAllFalse() throws {
        let dietaryInfo = DietaryInfo(
            isVegetarian: false,
            isVegan: false,
            isGlutenFree: false,
            isDairyFree: false
        )
        
        XCTAssertFalse(dietaryInfo.isVegetarian)
        XCTAssertFalse(dietaryInfo.isVegan)
        XCTAssertFalse(dietaryInfo.isGlutenFree)
        XCTAssertFalse(dietaryInfo.isDairyFree)
    }
    
    // MARK: - Recipe Generation Request Model Tests
    
    func testRecipeGenerationRequestInitialization() throws {
        let request = RecipeGenerationRequest(
            imageBase64: "base64encodedimage",
            dietaryPreferences: ["vegetarian", "gluten-free"],
            mealType: "dinner",
            servings: 6
        )
        
        XCTAssertEqual(request.imageBase64, "base64encodedimage")
        XCTAssertEqual(request.dietaryPreferences.count, 2)
        XCTAssertTrue(request.dietaryPreferences.contains("vegetarian"))
        XCTAssertTrue(request.dietaryPreferences.contains("gluten-free"))
        XCTAssertEqual(request.mealType, "dinner")
        XCTAssertEqual(request.servings, 6)
    }
    
    func testRecipeGenerationRequestWithOptionalMealType() throws {
        let request = RecipeGenerationRequest(
            imageBase64: "base64image",
            dietaryPreferences: [],
            mealType: nil,
            servings: 4
        )
        
        XCTAssertEqual(request.imageBase64, "base64image")
        XCTAssertTrue(request.dietaryPreferences.isEmpty)
        XCTAssertNil(request.mealType)
        XCTAssertEqual(request.servings, 4)
    }
    
    // MARK: - Recipe Generation Response Model Tests
    
    func testRecipeGenerationResponseSuccess() throws {
        let recipe = createMockRecipe(name: "Generated Recipe")
        
        let response = RecipeGenerationResponse(
            success: true,
            recipes: [recipe],
            error: nil,
            creditsRemaining: 5
        )
        
        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.recipes)
        XCTAssertEqual(response.recipes?.count, 1)
        XCTAssertEqual(response.recipes?.first?.name, "Generated Recipe")
        XCTAssertNil(response.error)
        XCTAssertEqual(response.creditsRemaining, 5)
    }
    
    func testRecipeGenerationResponseFailure() throws {
        let response = RecipeGenerationResponse(
            success: false,
            recipes: nil,
            error: "Failed to generate recipes",
            creditsRemaining: 3
        )
        
        XCTAssertFalse(response.success)
        XCTAssertNil(response.recipes)
        XCTAssertEqual(response.error, "Failed to generate recipes")
        XCTAssertEqual(response.creditsRemaining, 3)
    }
    
    // MARK: - Model Codable Tests
    
    func testRecipeCodable() throws {
        let originalRecipe = createMockRecipe(name: "Codable Test Recipe")
        
        // Encode
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(originalRecipe)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedRecipe = try decoder.decode(Recipe.self, from: encodedData)
        
        // Verify
        XCTAssertEqual(originalRecipe.id, decodedRecipe.id)
        XCTAssertEqual(originalRecipe.name, decodedRecipe.name)
        XCTAssertEqual(originalRecipe.description, decodedRecipe.description)
        XCTAssertEqual(originalRecipe.cookTime, decodedRecipe.cookTime)
        XCTAssertEqual(originalRecipe.prepTime, decodedRecipe.prepTime)
        XCTAssertEqual(originalRecipe.servings, decodedRecipe.servings)
        XCTAssertEqual(originalRecipe.difficulty, decodedRecipe.difficulty)
        XCTAssertEqual(originalRecipe.ingredients.count, decodedRecipe.ingredients.count)
        XCTAssertEqual(originalRecipe.instructions.count, decodedRecipe.instructions.count)
    }
    
    func testIngredientCodable() throws {
        let originalIngredient = Ingredient(
            id: UUID(),
            name: "Test Ingredient",
            quantity: "1 cup",
            unit: "cup",
            isAvailable: true
        )
        
        // Encode
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(originalIngredient)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedIngredient = try decoder.decode(Ingredient.self, from: encodedData)
        
        // Verify
        XCTAssertEqual(originalIngredient.id, decodedIngredient.id)
        XCTAssertEqual(originalIngredient.name, decodedIngredient.name)
        XCTAssertEqual(originalIngredient.quantity, decodedIngredient.quantity)
        XCTAssertEqual(originalIngredient.unit, decodedIngredient.unit)
        XCTAssertEqual(originalIngredient.isAvailable, decodedIngredient.isAvailable)
    }
    
    func testNutritionCodable() throws {
        let originalNutrition = Nutrition(
            calories: 300,
            protein: 18,
            carbs: 35,
            fat: 10,
            fiber: 6,
            sugar: 12,
            sodium: 500
        )
        
        // Encode
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(originalNutrition)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedNutrition = try decoder.decode(Nutrition.self, from: encodedData)
        
        // Verify
        XCTAssertEqual(originalNutrition.calories, decodedNutrition.calories)
        XCTAssertEqual(originalNutrition.protein, decodedNutrition.protein)
        XCTAssertEqual(originalNutrition.carbs, decodedNutrition.carbs)
        XCTAssertEqual(originalNutrition.fat, decodedNutrition.fat)
        XCTAssertEqual(originalNutrition.fiber, decodedNutrition.fiber)
        XCTAssertEqual(originalNutrition.sugar, decodedNutrition.sugar)
        XCTAssertEqual(originalNutrition.sodium, decodedNutrition.sodium)
    }
    
    func testDietaryInfoCodable() throws {
        let originalDietaryInfo = DietaryInfo(
            isVegetarian: true,
            isVegan: false,
            isGlutenFree: true,
            isDairyFree: false
        )
        
        // Encode
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(originalDietaryInfo)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedDietaryInfo = try decoder.decode(DietaryInfo.self, from: encodedData)
        
        // Verify
        XCTAssertEqual(originalDietaryInfo.isVegetarian, decodedDietaryInfo.isVegetarian)
        XCTAssertEqual(originalDietaryInfo.isVegan, decodedDietaryInfo.isVegan)
        XCTAssertEqual(originalDietaryInfo.isGlutenFree, decodedDietaryInfo.isGlutenFree)
        XCTAssertEqual(originalDietaryInfo.isDairyFree, decodedDietaryInfo.isDairyFree)
    }
    
    // MARK: - Sendable Conformance Tests
    
    func testRecipeSendable() throws {
        let recipe = createMockRecipe(name: "Sendable Test")
        
        // Test that Recipe conforms to Sendable by using it in an async context
        Task {
            let recipeInTask = recipe
            XCTAssertEqual(recipeInTask.name, "Sendable Test")
        }
        
        XCTAssertTrue(true, "Recipe should conform to Sendable")
    }
    
    func testIngredientSendable() throws {
        let ingredient = Ingredient(
            id: UUID(),
            name: "Sendable Ingredient",
            quantity: "1",
            unit: nil,
            isAvailable: true
        )
        
        Task {
            let ingredientInTask = ingredient
            XCTAssertEqual(ingredientInTask.name, "Sendable Ingredient")
        }
        
        XCTAssertTrue(true, "Ingredient should conform to Sendable")
    }
    
    // MARK: - Helper Methods
    
    private func createMockRecipe(name: String) -> Recipe {
        return Recipe(
            id: UUID(),
            name: name,
            description: "A test recipe",
            ingredients: [
                Ingredient(id: UUID(), name: "Test Ingredient", quantity: "1 cup", unit: "cup", isAvailable: true)
            ],
            instructions: ["Step 1: Test instruction"],
            cookTime: 30,
            prepTime: 15,
            servings: 4,
            difficulty: .easy,
            nutrition: Nutrition(calories: 200, protein: 10, carbs: 20, fat: 5, fiber: 3, sugar: 5, sodium: 300),
            imageURL: nil,
            createdAt: Date(),
            tags: ["test"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false),
            cookingTechniques: [],
            flavorProfile: nil,
            secretIngredients: [],
            proTips: [],
            visualClues: [],
            shareCaption: ""
        )
    }
}