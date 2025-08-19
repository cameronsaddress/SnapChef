import XCTest
@testable import SnapChef
import UIKit

@MainActor
final class PerformanceTests: XCTestCase {
    
    var appState: AppState!
    var apiManager: SnapChefAPIManager!
    
    override func setUpWithError() throws {
        appState = AppState()
        apiManager = SnapChefAPIManager.shared
    }
    
    override func tearDownWithError() throws {
        appState = nil
        apiManager = nil
    }
    
    // MARK: - App State Performance Tests
    
    func testAppStateInitializationPerformance() throws {
        self.measure {
            let _ = AppState()
        }
    }
    
    func testRecipeAdditionPerformance() throws {
        let recipes = (1...100).map { createMockRecipe(name: "Recipe \($0)") }
        
        self.measure {
            for recipe in recipes {
                appState.addRecentRecipe(recipe)
            }
        }
    }
    
    func testFavoriteTogglePerformance() throws {
        // Add many recipes first
        let recipes = (1...1000).map { createMockRecipe(name: "Recipe \($0)") }
        for recipe in recipes {
            appState.addRecentRecipe(recipe)
        }
        
        self.measure {
            for recipe in recipes.prefix(100) {
                appState.toggleFavorite(recipe.id)
            }
        }
    }
    
    func testRecipeDeletionPerformance() throws {
        // Add many recipes first
        let recipes = (1...500).map { createMockRecipe(name: "Recipe \($0)") }
        for recipe in recipes {
            appState.addRecentRecipe(recipe)
            appState.toggleRecipeSave(recipe)
            appState.toggleFavorite(recipe.id)
        }
        
        self.measure {
            for recipe in recipes.prefix(50) {
                appState.deleteRecipe(recipe)
            }
        }
    }
    
    // MARK: - Image Processing Performance Tests
    
    func testSmallImageResizePerformance() throws {
        let smallImage = createTestImage(size: CGSize(width: 500, height: 500))
        
        self.measure {
            let _ = smallImage.resized(withMaxDimension: 300)
        }
    }
    
    func testMediumImageResizePerformance() throws {
        let mediumImage = createTestImage(size: CGSize(width: 2000, height: 1500))
        
        self.measure {
            let _ = mediumImage.resized(withMaxDimension: 1024)
        }
    }
    
    func testLargeImageResizePerformance() throws {
        let largeImage = createTestImage(size: CGSize(width: 4000, height: 3000))
        
        self.measure {
            let _ = largeImage.resized(withMaxDimension: 2048)
        }
    }
    
    func testImageCompressionPerformance() throws {
        let testImage = createTestImage(size: CGSize(width: 2000, height: 2000))
        
        self.measure {
            let _ = testImage.jpegData(compressionQuality: 0.8)
        }
    }
    
    // MARK: - Recipe Conversion Performance Tests
    
    func testSingleRecipeConversionPerformance() throws {
        let apiRecipe = createComplexAPIRecipe()
        
        self.measure {
            let _ = apiManager.convertAPIRecipeToAppRecipe(apiRecipe)
        }
    }
    
    func testBatchRecipeConversionPerformance() throws {
        let apiRecipes = (1...50).map { _ in createComplexAPIRecipe() }
        
        self.measure {
            for apiRecipe in apiRecipes {
                let _ = apiManager.convertAPIRecipeToAppRecipe(apiRecipe)
            }
        }
    }
    
    func testComplexRecipeConversionPerformance() throws {
        let complexAPIRecipe = createVeryComplexAPIRecipe()
        
        self.measure {
            let _ = apiManager.convertAPIRecipeToAppRecipe(complexAPIRecipe)
        }
    }
    
    // MARK: - Error Handling Performance Tests
    
    func testErrorHandlingPerformance() throws {
        let errors = (1...100).map { SnapChefError.networkError("Error \($0)") }
        
        self.measure {
            for error in errors {
                appState.handleError(error, context: "performance_test")
            }
        }
    }
    
    func testErrorAnalyticsPerformance() throws {
        let testError = SnapChefError.networkError("Performance test error")
        
        self.measure {
            for i in 1...50 {
                ErrorAnalytics.logError(testError, context: "performance_test_\(i)", userId: "test_user")
            }
        }
    }
    
    func testGlobalErrorHandlerPerformance() throws {
        let globalHandler = GlobalErrorHandler.shared
        let errors = (1...200).map { SnapChefError.apiError("Error \($0)") }
        
        self.measure {
            for error in errors {
                globalHandler.handleError(error, context: "performance_test")
            }
        }
        
        // Clean up after test
        globalHandler.clearHistory()
    }
    
    // MARK: - Data Persistence Performance Tests
    
    func testRecipePersistencePerformance() throws {
        let recipes = (1...50).map { createMockRecipe(name: "Persist Recipe \($0)") }
        let testImage = createTestImage(size: CGSize(width: 100, height: 100))
        
        self.measure {
            for recipe in recipes {
                appState.saveRecipeWithPhotos(recipe, beforePhoto: testImage, afterPhoto: testImage)
            }
        }
    }
    
    func testFavoritesPersistencePerformance() throws {
        let recipeIds = (1...500).map { _ in UUID() }
        
        self.measure {
            for id in recipeIds {
                appState.toggleFavorite(id)
            }
        }
    }
    
    // MARK: - Search and Filter Performance Tests
    
    func testRecipeSearchPerformance() throws {
        // Add many recipes with varied names
        let recipeNames = [
            "Chicken Pasta", "Beef Stew", "Vegetarian Curry", "Fish Tacos",
            "Quinoa Salad", "Mushroom Risotto", "Grilled Salmon", "Turkey Sandwich",
            "Pork Chops", "Shrimp Scampi", "Vegetable Soup", "Chicken Curry",
            "Beef Tacos", "Fish Soup", "Quinoa Bowl", "Mushroom Pasta"
        ]
        
        let recipes = (1...100).flatMap { i in
            recipeNames.map { name in createMockRecipe(name: "\(name) \(i)") }
        }
        
        for recipe in recipes {
            appState.addRecentRecipe(recipe)
        }
        
        let searchTerms = ["Chicken", "Vegetarian", "Pasta", "Fish", "Quinoa"]
        
        self.measure {
            for searchTerm in searchTerms {
                let _ = appState.allRecipes.filter { recipe in
                    recipe.name.localizedCaseInsensitiveContains(searchTerm) ||
                    recipe.description.localizedCaseInsensitiveContains(searchTerm) ||
                    recipe.tags.contains { $0.localizedCaseInsensitiveContains(searchTerm) }
                }
            }
        }
    }
    
    func testDietaryFilterPerformance() throws {
        // Create recipes with varied dietary info
        let recipes = (1...1000).map { i in
            createMockRecipeWithDietaryInfo(
                name: "Recipe \(i)",
                isVegetarian: i % 3 == 0,
                isVegan: i % 5 == 0,
                isGlutenFree: i % 4 == 0,
                isDairyFree: i % 6 == 0
            )
        }
        
        for recipe in recipes {
            appState.addRecentRecipe(recipe)
        }
        
        self.measure {
            // Filter vegetarian recipes
            let _ = appState.allRecipes.filter { $0.dietaryInfo.isVegetarian }
            
            // Filter vegan recipes
            let _ = appState.allRecipes.filter { $0.dietaryInfo.isVegan }
            
            // Filter gluten-free recipes
            let _ = appState.allRecipes.filter { $0.dietaryInfo.isGlutenFree }
            
            // Filter dairy-free recipes
            let _ = appState.allRecipes.filter { $0.dietaryInfo.isDairyFree }
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsageWithManyRecipes() throws {
        // This test helps identify memory leaks
        let initialMemory = getMemoryUsage()
        
        // Create and add many recipes
        for i in 1...2000 {
            let recipe = createMockRecipe(name: "Memory Test Recipe \(i)")
            appState.addRecentRecipe(recipe)
            appState.toggleRecipeSave(recipe)
            appState.toggleFavorite(recipe.id)
        }
        
        let peakMemory = getMemoryUsage()
        
        // Clear all recipes
        appState.clearAllRecipes()
        
        let finalMemory = getMemoryUsage()
        
        // Verify memory usage is reasonable
        let memoryIncrease = peakMemory - initialMemory
        let memoryAfterCleanup = finalMemory - initialMemory
        
        XCTAssertLessThan(memoryIncrease, 100_000_000, "Memory increase should be less than 100MB") // 100MB limit
        XCTAssertLessThan(memoryAfterCleanup, memoryIncrease / 2, "Memory should be significantly reduced after cleanup")
    }
    
    func testImageMemoryUsage() throws {
        let initialMemory = getMemoryUsage()
        var images: [UIImage] = []
        
        // Create many images
        for _ in 1...100 {
            let image = createTestImage(size: CGSize(width: 500, height: 500))
            images.append(image)
        }
        
        let peakMemory = getMemoryUsage()
        
        // Clear images
        images.removeAll()
        
        let finalMemory = getMemoryUsage()
        
        let memoryIncrease = peakMemory - initialMemory
        let memoryAfterCleanup = finalMemory - initialMemory
        
        XCTAssertLessThan(memoryIncrease, 50_000_000, "Image memory increase should be less than 50MB") // 50MB limit
        XCTAssertLessThan(memoryAfterCleanup, memoryIncrease / 2, "Memory should be reduced after clearing images")
    }
    
    // MARK: - Concurrency Performance Tests
    
    func testConcurrentRecipeAddition() throws {
        let expectation = self.expectation(description: "Concurrent recipe addition")
        expectation.expectedFulfillmentCount = 10
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Add recipes concurrently
        for i in 1...10 {
            Task {
                let recipe = createMockRecipe(name: "Concurrent Recipe \(i)")
                await MainActor.run {
                    appState.addRecentRecipe(recipe)
                }
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0) { _ in
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            XCTAssertLessThan(duration, 1.0, "Concurrent recipe addition should complete within 1 second")
            XCTAssertEqual(self.appState.recentRecipes.count, 10, "All recipes should be added")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.blue.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    private func createMockRecipe(name: String) -> Recipe {
        return Recipe(
            id: UUID(),
            name: name,
            description: "A test recipe for performance testing",
            ingredients: [
                Ingredient(id: UUID(), name: "Ingredient 1", quantity: "1 cup", unit: "cup", isAvailable: true),
                Ingredient(id: UUID(), name: "Ingredient 2", quantity: "2 tbsp", unit: "tbsp", isAvailable: true)
            ],
            instructions: ["Step 1: Prepare ingredients", "Step 2: Cook", "Step 3: Serve"],
            cookTime: 30,
            prepTime: 15,
            servings: 4,
            difficulty: .easy,
            nutrition: Nutrition(calories: 250, protein: 12, carbs: 30, fat: 8, fiber: 5, sugar: 6, sodium: 400),
            imageURL: nil,
            createdAt: Date(),
            tags: ["test", "performance"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false),
            cookingTechniques: [],
            flavorProfile: nil,
            secretIngredients: [],
            proTips: [],
            visualClues: [],
            shareCaption: ""
        )
    }
    
    private func createMockRecipeWithDietaryInfo(name: String, isVegetarian: Bool, isVegan: Bool, isGlutenFree: Bool, isDairyFree: Bool) -> Recipe {
        return Recipe(
            id: UUID(),
            name: name,
            description: "A test recipe with dietary info",
            ingredients: [
                Ingredient(id: UUID(), name: "Test Ingredient", quantity: "1 cup", unit: "cup", isAvailable: true)
            ],
            instructions: ["Test instruction"],
            cookTime: 20,
            prepTime: 10,
            servings: 2,
            difficulty: .easy,
            nutrition: Nutrition(calories: 200, protein: 10, carbs: 25, fat: 6, fiber: 4, sugar: 5, sodium: 300),
            imageURL: nil,
            createdAt: Date(),
            tags: ["test"],
            dietaryInfo: DietaryInfo(
                isVegetarian: isVegetarian,
                isVegan: isVegan,
                isGlutenFree: isGlutenFree,
                isDairyFree: isDairyFree
            ),
            cookingTechniques: [],
            flavorProfile: nil,
            secretIngredients: [],
            proTips: [],
            visualClues: [],
            shareCaption: ""
        )
    }
    
    private func createComplexAPIRecipe() -> RecipeAPI {
        return RecipeAPI(
            id: UUID().uuidString,
            name: "Complex API Recipe",
            description: "A complex recipe with many ingredients and steps",
            main_dish: "Main Course",
            side_dish: "Side Dish",
            total_time: 60,
            prep_time: 20,
            cook_time: 40,
            servings: 6,
            difficulty: "medium",
            ingredients_used: (1...20).map { IngredientUsed(name: "Ingredient \($0)", amount: "\($0) cups") },
            instructions: (1...15).map { "Step \($0): Do something complex" },
            nutrition: NutritionAPI(calories: 450, protein: 25, carbs: 50, fat: 15, fiber: 8, sugar: 12, sodium: 700),
            tips: "This is a complex recipe with detailed tips and instructions",
            tags: ["complex", "performance", "test", "main-course", "family-friendly"],
            share_caption: "Check out this amazing complex recipe!"
        )
    }
    
    private func createVeryComplexAPIRecipe() -> RecipeAPI {
        return RecipeAPI(
            id: UUID().uuidString,
            name: "Very Complex API Recipe with Very Long Name That Tests String Processing Performance",
            description: "An extremely complex recipe with numerous ingredients, detailed steps, and comprehensive nutritional information designed to test the performance limits of our recipe conversion system",
            main_dish: "Elaborate Main Course",
            side_dish: "Complex Side Dish",
            total_time: 180,
            prep_time: 60,
            cook_time: 120,
            servings: 12,
            difficulty: "hard",
            ingredients_used: (1...100).map { IngredientUsed(name: "Complex Ingredient \($0)", amount: "\($0) units") },
            instructions: (1...50).map { "Detailed Step \($0): Perform a very complex cooking operation that requires careful attention to detail and precise timing" },
            nutrition: NutritionAPI(calories: 800, protein: 45, carbs: 90, fat: 25, fiber: 15, sugar: 20, sodium: 1200),
            tips: "This extremely complex recipe requires advanced cooking skills and has many detailed tips and tricks for success",
            tags: (1...20).map { "tag-\($0)" },
            share_caption: "This is the most complex recipe you'll ever see with an extremely long caption that tests text processing performance!"
        )
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}