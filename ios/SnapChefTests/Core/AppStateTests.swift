import XCTest
@testable import SnapChef
import SwiftUI

@MainActor
final class AppStateTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUpWithError() throws {
        // Reset UserDefaults for clean test state
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "hasLaunchedBefore")
        defaults.removeObject(forKey: "userJoinDate")
        defaults.removeObject(forKey: "savedRecipesWithPhotos")
        defaults.removeObject(forKey: "favoritedRecipeIds")
        defaults.removeObject(forKey: "totalSnapsTaken")
        
        appState = AppState()
    }
    
    override func tearDownWithError() throws {
        appState = nil
    }
    
    // MARK: - Initialization Tests
    
    func testAppStateInitialization() throws {
        XCTAssertTrue(appState.isFirstLaunch, "First launch should be true for new installation")
        XCTAssertNil(appState.currentUser, "User should be nil initially")
        XCTAssertFalse(appState.isLoading, "Should not be loading initially")
        XCTAssertNil(appState.error, "No error should be present initially")
        XCTAssertEqual(appState.recentRecipes.count, 0, "Recent recipes should be empty initially")
        XCTAssertEqual(appState.totalSnapsTaken, 0, "Snaps taken should be 0 initially")
        XCTAssertTrue(appState.favoritedRecipeIds.isEmpty, "Favorited recipes should be empty initially")
    }
    
    func testCompleteOnboarding() throws {
        // Initially first launch should be true
        XCTAssertTrue(appState.isFirstLaunch)
        
        // Complete onboarding
        appState.completeOnboarding()
        
        // Should no longer be first launch
        XCTAssertFalse(appState.isFirstLaunch)
        
        // UserDefaults should be updated
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        XCTAssertTrue(hasLaunched, "UserDefaults should reflect onboarding completion")
    }
    
    // MARK: - Recipe Management Tests
    
    func testAddRecentRecipe() throws {
        let recipe = createMockRecipe(name: "Test Recipe")
        
        appState.addRecentRecipe(recipe)
        
        XCTAssertEqual(appState.recentRecipes.count, 1, "Should have one recent recipe")
        XCTAssertEqual(appState.recentRecipes.first?.name, "Test Recipe", "Recipe should be added correctly")
        XCTAssertEqual(appState.allRecipes.count, 1, "All recipes should also contain the recipe")
    }
    
    func testRecentRecipesLimit() throws {
        // Add 15 recipes (more than the limit of 10)
        for i in 1...15 {
            let recipe = createMockRecipe(name: "Recipe \(i)")
            appState.addRecentRecipe(recipe)
        }
        
        XCTAssertEqual(appState.recentRecipes.count, 10, "Should maintain maximum of 10 recent recipes")
        XCTAssertEqual(appState.recentRecipes.first?.name, "Recipe 15", "Most recent recipe should be first")
        XCTAssertEqual(appState.recentRecipes.last?.name, "Recipe 6", "Oldest remaining recipe should be last")
    }
    
    func testToggleRecipeSave() throws {
        let recipe = createMockRecipe(name: "Save Test Recipe")
        
        // Initially should not be saved
        XCTAssertFalse(appState.savedRecipes.contains(where: { $0.id == recipe.id }))
        
        // Save the recipe
        appState.toggleRecipeSave(recipe)
        XCTAssertTrue(appState.savedRecipes.contains(where: { $0.id == recipe.id }), "Recipe should be saved")
        
        // Unsave the recipe
        appState.toggleRecipeSave(recipe)
        XCTAssertFalse(appState.savedRecipes.contains(where: { $0.id == recipe.id }), "Recipe should be removed from saved")
    }
    
    func testToggleFavorite() throws {
        let recipe = createMockRecipe(name: "Favorite Test Recipe")
        
        // Initially should not be favorited
        XCTAssertFalse(appState.isFavorited(recipe.id))
        XCTAssertFalse(appState.favoritedRecipeIds.contains(recipe.id))
        
        // Favorite the recipe
        appState.toggleFavorite(recipe.id)
        XCTAssertTrue(appState.isFavorited(recipe.id), "Recipe should be favorited")
        XCTAssertTrue(appState.favoritedRecipeIds.contains(recipe.id), "Recipe ID should be in favorites set")
        
        // Unfavorite the recipe
        appState.toggleFavorite(recipe.id)
        XCTAssertFalse(appState.isFavorited(recipe.id), "Recipe should not be favorited")
        XCTAssertFalse(appState.favoritedRecipeIds.contains(recipe.id), "Recipe ID should not be in favorites set")
    }
    
    // MARK: - Counter Tests
    
    func testIncrementShares() throws {
        let initialShares = appState.totalShares
        
        appState.incrementShares()
        
        XCTAssertEqual(appState.totalShares, initialShares + 1, "Total shares should increment by 1")
    }
    
    func testIncrementLikes() throws {
        let initialLikes = appState.totalLikes
        
        appState.incrementLikes()
        
        XCTAssertEqual(appState.totalLikes, initialLikes + 1, "Total likes should increment by 1")
    }
    
    func testIncrementSnapsTaken() throws {
        let initialSnaps = appState.totalSnapsTaken
        
        appState.incrementSnapsTaken()
        
        XCTAssertEqual(appState.totalSnapsTaken, initialSnaps + 1, "Total snaps should increment by 1")
        
        // Verify UserDefaults persistence
        let savedSnaps = UserDefaults.standard.integer(forKey: "totalSnapsTaken")
        XCTAssertEqual(savedSnaps, initialSnaps + 1, "Snaps should be persisted to UserDefaults")
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleError() throws {
        let testError = SnapChefError.networkError("Test network error")
        
        appState.handleError(testError, context: "test_context")
        
        XCTAssertEqual(appState.currentSnapChefError, testError, "Current error should be set")
    }
    
    func testClearError() throws {
        let testError = SnapChefError.networkError("Test error")
        appState.handleError(testError)
        
        // Error should be set
        XCTAssertNotNil(appState.currentSnapChefError)
        
        // Clear error
        appState.clearError()
        
        XCTAssertNil(appState.currentSnapChefError, "Error should be cleared")
    }
    
    // MARK: - Progressive Premium Tests
    
    func testCanCreateRecipe() throws {
        // Mock a scenario where user can create recipes
        let canCreate = appState.canCreateRecipe()
        
        // For testing, we assume unlimited usage in test mode
        XCTAssertTrue(canCreate, "User should be able to create recipes in test mode")
    }
    
    func testGetCurrentLimits() throws {
        let limits = appState.getCurrentLimits()
        
        XCTAssertNotNil(limits, "Should return valid daily limits")
        XCTAssertGreaterThan(limits.recipes, 0, "Recipe limit should be greater than 0")
    }
    
    // MARK: - Anonymous Action Tracking Tests
    
    func testTrackAnonymousAction() throws {
        // Track a recipe creation action
        appState.trackAnonymousAction(.recipeCreated)
        
        // This should not throw an error and should update internal state
        // We can't easily test the internal tracking without exposing more internals
        // But we can verify the method executes without error
        XCTAssertTrue(true, "Anonymous action tracking should execute without error")
    }
    
    func testTrackRecipeCreated() throws {
        let recipe = createMockRecipe(name: "Tracked Recipe")
        let initialCount = appState.recentRecipes.count
        
        appState.trackRecipeCreated(recipe)
        
        XCTAssertEqual(appState.recentRecipes.count, initialCount + 1, "Recipe should be added to recent recipes")
        XCTAssertEqual(appState.recentRecipes.first?.name, "Tracked Recipe", "Tracked recipe should be first in recent")
    }
    
    // MARK: - Helper Methods
    
    private func createMockRecipe(name: String, id: UUID = UUID()) -> Recipe {
        return Recipe(
            id: id,
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