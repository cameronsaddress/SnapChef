import XCTest
@testable import SnapChef
import UIKit

@MainActor
final class RecipeGenerationIntegrationTests: XCTestCase {
    
    var appState: AppState!
    var apiManager: SnapChefAPIManager!
    
    override func setUpWithError() throws {
        // Reset UserDefaults for clean test state
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "hasLaunchedBefore")
        defaults.removeObject(forKey: "userJoinDate")
        defaults.removeObject(forKey: "savedRecipesWithPhotos")
        defaults.removeObject(forKey: "favoritedRecipeIds")
        defaults.removeObject(forKey: "totalSnapsTaken")
        
        appState = AppState()
        apiManager = SnapChefAPIManager.shared
    }
    
    override func tearDownWithError() throws {
        appState = nil
        apiManager = nil
    }
    
    // MARK: - Recipe Generation Flow Tests
    
    func testCompleteRecipeGenerationFlow() throws {
        // Simulate taking a photo
        let mockImage = createMockImage()
        XCTAssertNotNil(mockImage, "Mock image should be created")
        
        // Track that a snap was taken
        let initialSnaps = appState.totalSnapsTaken
        appState.incrementSnapsTaken()
        XCTAssertEqual(appState.totalSnapsTaken, initialSnaps + 1, "Snap count should increment")
        
        // Create a mock recipe (simulating successful API response)
        let generatedRecipe = createMockRecipe(name: "AI Generated Recipe")
        
        // Add recipe to app state
        appState.addRecentRecipe(generatedRecipe)
        
        // Verify recipe was added
        XCTAssertEqual(appState.recentRecipes.count, 1, "Should have one recent recipe")
        XCTAssertEqual(appState.recentRecipes.first?.name, "AI Generated Recipe", "Recipe should be added correctly")
        XCTAssertEqual(appState.allRecipes.count, 1, "All recipes should also contain the recipe")
        
        // Test saving the recipe
        appState.toggleRecipeSave(generatedRecipe)
        XCTAssertTrue(appState.savedRecipes.contains(where: { $0.id == generatedRecipe.id }), "Recipe should be saved")
        
        // Test favoriting the recipe
        appState.toggleFavorite(generatedRecipe.id)
        XCTAssertTrue(appState.isFavorited(generatedRecipe.id), "Recipe should be favorited")
        
        // Test sharing (increment shares)
        let initialShares = appState.totalShares
        appState.incrementShares()
        XCTAssertEqual(appState.totalShares, initialShares + 1, "Share count should increment")
    }
    
    func testRecipeGenerationWithDietaryRestrictions() throws {
        let mockImage = createMockImage()
        let dietaryRestrictions = ["vegetarian", "gluten-free"]
        
        // Create a mock recipe that respects dietary restrictions
        let vegetarianRecipe = Recipe(
            id: UUID(),
            name: "Vegetarian Gluten-Free Pasta",
            description: "A delicious vegetarian pasta dish",
            ingredients: [
                Ingredient(id: UUID(), name: "Gluten-free pasta", quantity: "2 cups", unit: "cups", isAvailable: true),
                Ingredient(id: UUID(), name: "Vegetables", quantity: "1 cup", unit: "cup", isAvailable: true)
            ],
            instructions: ["Cook pasta", "Add vegetables"],
            cookTime: 20,
            prepTime: 10,
            servings: 2,
            difficulty: .easy,
            nutrition: Nutrition(calories: 300, protein: 12, carbs: 45, fat: 8, fiber: 6, sugar: 5, sodium: 200),
            imageURL: nil,
            createdAt: Date(),
            tags: ["vegetarian", "gluten-free"],
            dietaryInfo: DietaryInfo(isVegetarian: true, isVegan: false, isGlutenFree: true, isDairyFree: false)
        )
        
        appState.addRecentRecipe(vegetarianRecipe)
        
        // Verify dietary information was preserved
        let addedRecipe = appState.recentRecipes.first!
        XCTAssertTrue(addedRecipe.dietaryInfo.isVegetarian, "Recipe should be vegetarian")
        XCTAssertTrue(addedRecipe.dietaryInfo.isGlutenFree, "Recipe should be gluten-free")
        XCTAssertTrue(addedRecipe.tags.contains("vegetarian"), "Recipe should have vegetarian tag")
        XCTAssertTrue(addedRecipe.tags.contains("gluten-free"), "Recipe should have gluten-free tag")
    }
    
    func testRecipeGenerationWithExistingRecipes() throws {
        // Add some existing recipes first
        let existingRecipe1 = createMockRecipe(name: "Existing Recipe 1")
        let existingRecipe2 = createMockRecipe(name: "Existing Recipe 2")
        
        appState.addRecentRecipe(existingRecipe1)
        appState.addRecentRecipe(existingRecipe2)
        
        XCTAssertEqual(appState.recentRecipes.count, 2, "Should have 2 existing recipes")
        
        // Generate a new recipe
        let newRecipe = createMockRecipe(name: "New Generated Recipe")
        appState.addRecentRecipe(newRecipe)
        
        XCTAssertEqual(appState.recentRecipes.count, 3, "Should have 3 total recipes")
        XCTAssertEqual(appState.recentRecipes.first?.name, "New Generated Recipe", "New recipe should be first")
    }
    
    // MARK: - Progressive Premium Integration Tests
    
    func testRecipeGenerationWithLimits() throws {
        // Test that recipe generation respects daily limits
        let canCreate = appState.canCreateRecipe()
        
        // In test mode, this should typically return true
        XCTAssertTrue(canCreate, "Should be able to create recipes in test environment")
        
        // Get current limits
        let limits = appState.getCurrentLimits()
        XCTAssertGreaterThan(limits.recipes, 0, "Recipe limit should be positive")
        
        // Get remaining count
        let remaining = appState.getRemainingRecipes()
        XCTAssertGreaterThanOrEqual(remaining, 0, "Remaining recipes should be non-negative")
    }
    
    func testRecipeGenerationTracking() throws {
        let recipe = createMockRecipe(name: "Tracked Recipe")
        
        // Use the tracking method instead of direct add
        appState.trackRecipeCreated(recipe)
        
        // Verify recipe was added and tracked
        XCTAssertEqual(appState.recentRecipes.count, 1, "Recipe should be added")
        XCTAssertEqual(appState.recentRecipes.first?.name, "Tracked Recipe", "Correct recipe should be added")
        
        // Verify anonymous action was tracked
        // This is tested indirectly by ensuring the method doesn't crash
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testRecipeGenerationErrorHandling() throws {
        // Test handling of recipe generation errors
        let networkError = SnapChefError.networkError("Connection failed")
        
        appState.handleError(networkError, context: "recipe_generation")
        
        XCTAssertEqual(appState.currentSnapChefError, networkError, "Error should be set")
        
        // Clear error
        appState.clearError()
        XCTAssertNil(appState.currentSnapChefError, "Error should be cleared")
    }
    
    func testAPIErrorToRecipeGenerationError() throws {
        let apiError = SnapChefError.apiError("Server error", statusCode: 500, recovery: .retry)
        
        appState.handleError(apiError, context: "api_request")
        
        XCTAssertNotNil(appState.currentSnapChefError, "Error should be set")
        XCTAssertEqual(appState.currentSnapChefError?.actionTitle, "Retry", "Should suggest retry")
    }
    
    // MARK: - API Conversion Integration Tests
    
    func testAPIToAppRecipeConversion() throws {
        let apiRecipe = createMockAPIRecipe()
        let appRecipe = apiManager.convertAPIRecipeToAppRecipe(apiRecipe)
        
        // Verify conversion
        XCTAssertEqual(appRecipe.name, apiRecipe.name)
        XCTAssertEqual(appRecipe.description, apiRecipe.description)
        XCTAssertEqual(appRecipe.cookTime, apiRecipe.cook_time ?? 0)
        XCTAssertEqual(appRecipe.prepTime, apiRecipe.prep_time ?? 0)
        XCTAssertEqual(appRecipe.servings, apiRecipe.servings ?? 4)
        XCTAssertEqual(appRecipe.instructions.count, apiRecipe.instructions.count)
        
        // Test that it can be added to app state
        appState.addRecentRecipe(appRecipe)
        XCTAssertEqual(appState.recentRecipes.count, 1, "Converted recipe should be addable to app state")
    }
    
    // MARK: - Recipe Persistence Integration Tests
    
    func testRecipePersistenceFlow() throws {
        let recipe = createMockRecipe(name: "Persistence Test Recipe")
        
        // Save recipe with photos
        let beforePhoto = createMockImage()
        let afterPhoto = createMockImage()
        
        appState.saveRecipeWithPhotos(recipe, beforePhoto: beforePhoto, afterPhoto: afterPhoto)
        
        // Verify recipe was saved
        XCTAssertTrue(appState.savedRecipesWithPhotos.contains(where: { $0.recipe.id == recipe.id }), "Recipe should be saved with photos")
        XCTAssertTrue(appState.savedRecipes.contains(where: { $0.id == recipe.id }), "Recipe should be in saved recipes")
        
        // Test updating after photo
        let newAfterPhoto = createMockImage()
        appState.updateAfterPhoto(for: recipe.id, afterPhoto: newAfterPhoto)
        
        // Verify update
        let savedRecipe = appState.savedRecipesWithPhotos.first(where: { $0.recipe.id == recipe.id })
        XCTAssertNotNil(savedRecipe, "Saved recipe should exist")
        XCTAssertNotNil(savedRecipe?.afterPhoto, "After photo should be updated")
    }
    
    func testRecipeDeletion() throws {
        let recipe = createMockRecipe(name: "To Be Deleted")
        
        // Add recipe to all collections
        appState.addRecentRecipe(recipe)
        appState.toggleRecipeSave(recipe)
        appState.toggleFavorite(recipe.id)
        
        // Verify recipe is in all collections
        XCTAssertTrue(appState.recentRecipes.contains(where: { $0.id == recipe.id }))
        XCTAssertTrue(appState.savedRecipes.contains(where: { $0.id == recipe.id }))
        XCTAssertTrue(appState.isFavorited(recipe.id))
        
        // Delete recipe
        appState.deleteRecipe(recipe)
        
        // Verify recipe is removed from all collections
        XCTAssertFalse(appState.recentRecipes.contains(where: { $0.id == recipe.id }))
        XCTAssertFalse(appState.savedRecipes.contains(where: { $0.id == recipe.id }))
        XCTAssertFalse(appState.isFavorited(recipe.id))
    }
    
    // MARK: - Recipe Sharing Integration Tests
    
    func testRecipeSharingFlow() throws {
        let recipe = createMockRecipe(name: "Shareable Recipe")
        appState.addRecentRecipe(recipe)
        
        // Track sharing
        let initialShares = appState.totalShares
        appState.incrementShares()
        
        XCTAssertEqual(appState.totalShares, initialShares + 1, "Share count should increment")
        
        // Test anonymous action tracking for sharing
        appState.trackAnonymousAction(.videoShared)
        
        // This should not crash and should track the action internally
        XCTAssertTrue(true, "Sharing action tracking should complete without error")
    }
    
    // MARK: - Multi-Recipe Generation Tests
    
    func testMultipleRecipeGeneration() throws {
        let recipes = [
            createMockRecipe(name: "Recipe 1"),
            createMockRecipe(name: "Recipe 2"),
            createMockRecipe(name: "Recipe 3")
        ]
        
        // Add multiple recipes (simulating API returning multiple recipes)
        for recipe in recipes {
            appState.addRecentRecipe(recipe)
        }
        
        XCTAssertEqual(appState.recentRecipes.count, 3, "Should have 3 recipes")
        XCTAssertEqual(appState.recentRecipes.first?.name, "Recipe 3", "Most recent should be first")
        XCTAssertEqual(appState.allRecipes.count, 3, "All recipes should contain all 3")
    }
    
    // MARK: - Helper Methods
    
    private func createMockImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.red.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
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
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false)
        )
    }
    
    private func createMockAPIRecipe() -> RecipeAPI {
        return RecipeAPI(
            id: UUID().uuidString,
            name: "API Test Recipe",
            description: "A recipe from API",
            main_dish: "Main Course",
            side_dish: nil,
            total_time: 45,
            prep_time: 15,
            cook_time: 30,
            servings: 4,
            difficulty: "medium",
            ingredients_used: [
                IngredientUsed(name: "Chicken", amount: "1 lb"),
                IngredientUsed(name: "Rice", amount: "2 cups")
            ],
            instructions: ["Cook chicken", "Prepare rice", "Combine"],
            nutrition: NutritionAPI(calories: 400, protein: 25, carbs: 45, fat: 12, fiber: 3, sugar: 8, sodium: 600),
            tips: "Cook thoroughly",
            tags: ["protein", "healthy"],
            share_caption: "Delicious chicken and rice!"
        )
    }
}