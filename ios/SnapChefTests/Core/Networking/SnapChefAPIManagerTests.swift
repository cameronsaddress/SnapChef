import XCTest
@testable import SnapChef
import UIKit

@MainActor
final class SnapChefAPIManagerTests: XCTestCase {
    
    var apiManager: SnapChefAPIManager!
    var mockImage: UIImage!
    
    override func setUpWithError() throws {
        apiManager = SnapChefAPIManager.shared
        
        // Create a simple test image
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.red.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        mockImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        XCTAssertNotNil(mockImage, "Mock image should be created successfully")
    }
    
    override func tearDownWithError() throws {
        apiManager = nil
        mockImage = nil
    }
    
    // MARK: - API Manager Initialization Tests
    
    func testAPIManagerSingleton() throws {
        let manager1 = SnapChefAPIManager.shared
        let manager2 = SnapChefAPIManager.shared
        
        XCTAssertTrue(manager1 === manager2, "API Manager should be a singleton")
    }
    
    // MARK: - Image Resizing Tests
    
    func testImageResizing() throws {
        // Create a large image
        let largeSize = CGSize(width: 4000, height: 3000)
        UIGraphicsBeginImageContext(largeSize)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.blue.cgColor)
        context?.fill(CGRect(origin: .zero, size: largeSize))
        let largeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        XCTAssertNotNil(largeImage, "Large image should be created")
        
        // Test resizing
        let maxDimension: CGFloat = 2048
        let resizedImage = largeImage!.resized(withMaxDimension: maxDimension)
        
        XCTAssertLessThanOrEqual(resizedImage.size.width, maxDimension, "Resized width should not exceed max dimension")
        XCTAssertLessThanOrEqual(resizedImage.size.height, maxDimension, "Resized height should not exceed max dimension")
        
        // Test that aspect ratio is maintained
        let originalAspectRatio = largeImage!.size.width / largeImage!.size.height
        let resizedAspectRatio = resizedImage.size.width / resizedImage.size.height
        
        XCTAssertEqual(originalAspectRatio, resizedAspectRatio, accuracy: 0.01, "Aspect ratio should be maintained")
    }
    
    func testImageResizingSmallImage() throws {
        // Create a small image that shouldn't need resizing
        let smallSize = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(smallSize)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.green.cgColor)
        context?.fill(CGRect(origin: .zero, size: smallSize))
        let smallImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        XCTAssertNotNil(smallImage, "Small image should be created")
        
        let maxDimension: CGFloat = 2048
        let resizedImage = smallImage!.resized(withMaxDimension: maxDimension)
        
        // Should return the same image since it's already smaller than max dimension
        XCTAssertEqual(resizedImage.size.width, smallImage!.size.width, "Small image width should remain unchanged")
        XCTAssertEqual(resizedImage.size.height, smallImage!.size.height, "Small image height should remain unchanged")
    }
    
    // MARK: - API Response Model Tests
    
    func testRecipeAPIModel() throws {
        let recipeAPI = RecipeAPI(
            id: "test-id",
            name: "Test Recipe",
            description: "A test recipe description",
            main_dish: "Main Course",
            side_dish: nil,
            total_time: 45,
            prep_time: 15,
            cook_time: 30,
            servings: 4,
            difficulty: "easy",
            ingredients_used: [
                IngredientUsed(name: "Tomatoes", amount: "2 cups")
            ],
            instructions: ["Step 1", "Step 2"],
            nutrition: NutritionAPI(calories: 250, protein: 15, carbs: 30, fat: 8, fiber: 5, sugar: 10, sodium: 400),
            tips: "Test tip",
            tags: ["healthy", "quick"],
            share_caption: "Check out this recipe!"
        )
        
        XCTAssertEqual(recipeAPI.id, "test-id")
        XCTAssertEqual(recipeAPI.name, "Test Recipe")
        XCTAssertEqual(recipeAPI.difficulty, "easy")
        XCTAssertEqual(recipeAPI.servings, 4)
        XCTAssertEqual(recipeAPI.instructions.count, 2)
        XCTAssertNotNil(recipeAPI.nutrition)
        XCTAssertEqual(recipeAPI.nutrition?.calories, 250)
    }
    
    func testIngredientAPIModel() throws {
        let ingredient = IngredientAPI(
            name: "Carrots",
            quantity: "3",
            unit: "large",
            category: "vegetable",
            freshness: "fresh",
            location: "refrigerator"
        )
        
        XCTAssertEqual(ingredient.name, "Carrots")
        XCTAssertEqual(ingredient.quantity, "3")
        XCTAssertEqual(ingredient.unit, "large")
        XCTAssertEqual(ingredient.category, "vegetable")
        XCTAssertEqual(ingredient.freshness, "fresh")
        XCTAssertEqual(ingredient.location, "refrigerator")
    }
    
    // MARK: - Recipe Conversion Tests
    
    func testConvertAPIRecipeToAppRecipe() throws {
        let apiRecipe = RecipeAPI(
            id: "test-conversion-id",
            name: "Conversion Test Recipe",
            description: "Testing recipe conversion",
            main_dish: "Test Main",
            side_dish: nil,
            total_time: 60,
            prep_time: 20,
            cook_time: 40,
            servings: 6,
            difficulty: "medium",
            ingredients_used: [
                IngredientUsed(name: "Chicken", amount: "1 lb"),
                IngredientUsed(name: "Rice", amount: "2 cups")
            ],
            instructions: ["Prepare chicken", "Cook rice", "Combine"],
            nutrition: NutritionAPI(calories: 400, protein: 25, carbs: 45, fat: 12, fiber: 3, sugar: 8, sodium: 600),
            tips: "Cook thoroughly",
            tags: ["protein", "gluten-free"],
            share_caption: "Delicious chicken and rice!"
        )
        
        let appRecipe = apiManager.convertAPIRecipeToAppRecipe(apiRecipe)
        
        XCTAssertEqual(appRecipe.name, "Conversion Test Recipe")
        XCTAssertEqual(appRecipe.description, "Testing recipe conversion")
        XCTAssertEqual(appRecipe.cookTime, 40)
        XCTAssertEqual(appRecipe.prepTime, 20)
        XCTAssertEqual(appRecipe.servings, 6)
        XCTAssertEqual(appRecipe.difficulty, .medium)
        XCTAssertEqual(appRecipe.ingredients.count, 2)
        XCTAssertEqual(appRecipe.instructions.count, 3)
        XCTAssertEqual(appRecipe.nutrition.calories, 400)
        XCTAssertEqual(appRecipe.tags.count, 2)
        XCTAssertTrue(appRecipe.tags.contains("protein"))
        XCTAssertTrue(appRecipe.tags.contains("gluten-free"))
        XCTAssertTrue(appRecipe.dietaryInfo.isGlutenFree)
    }
    
    func testConvertAPIRecipeWithDietaryInfo() throws {
        let apiRecipe = RecipeAPI(
            id: "dietary-test-id",
            name: "Dietary Test Recipe",
            description: "Testing dietary info extraction",
            main_dish: nil,
            side_dish: nil,
            total_time: nil,
            prep_time: nil,
            cook_time: nil,
            servings: nil,
            difficulty: "hard",
            ingredients_used: nil,
            instructions: ["Test instruction"],
            nutrition: nil,
            tips: nil,
            tags: ["vegetarian", "dairy-free", "vegan"],
            share_caption: nil
        )
        
        let appRecipe = apiManager.convertAPIRecipeToAppRecipe(apiRecipe)
        
        XCTAssertTrue(appRecipe.dietaryInfo.isVegetarian, "Should detect vegetarian tag")
        XCTAssertTrue(appRecipe.dietaryInfo.isVegan, "Should detect vegan tag")
        XCTAssertTrue(appRecipe.dietaryInfo.isDairyFree, "Should detect dairy-free tag")
        XCTAssertFalse(appRecipe.dietaryInfo.isGlutenFree, "Should not detect gluten-free when not present")
        XCTAssertEqual(appRecipe.difficulty, .hard, "Should convert hard difficulty correctly")
    }
    
    func testConvertAPIRecipeWithMissingData() throws {
        let apiRecipe = RecipeAPI(
            id: "minimal-test-id",
            name: "Minimal Recipe",
            description: "Testing with minimal data",
            main_dish: nil,
            side_dish: nil,
            total_time: nil,
            prep_time: nil,
            cook_time: nil,
            servings: nil,
            difficulty: "unknown", // Test default difficulty
            ingredients_used: nil,
            instructions: ["Single instruction"],
            nutrition: nil,
            tips: nil,
            tags: nil,
            share_caption: nil
        )
        
        let appRecipe = apiManager.convertAPIRecipeToAppRecipe(apiRecipe)
        
        // Test default values
        XCTAssertEqual(appRecipe.cookTime, 0, "Cook time should default to 0")
        XCTAssertEqual(appRecipe.prepTime, 0, "Prep time should default to 0")
        XCTAssertEqual(appRecipe.servings, 4, "Servings should default to 4")
        XCTAssertEqual(appRecipe.difficulty, .medium, "Unknown difficulty should default to medium")
        XCTAssertEqual(appRecipe.ingredients.count, 0, "Should handle nil ingredients_used")
        XCTAssertEqual(appRecipe.nutrition.calories, 0, "Nutrition should default to zero values when nil")
        XCTAssertEqual(appRecipe.tags.count, 0, "Should handle nil tags")
    }
    
    // MARK: - API Error Tests
    
    func testAPIErrorDescriptions() throws {
        let invalidURLError = APIError.invalidURL
        XCTAssertEqual(invalidURLError.errorDescription, "The server URL is invalid.")
        
        let invalidRequestError = APIError.invalidRequestData
        XCTAssertEqual(invalidRequestError.errorDescription, "Failed to encode request data.")
        
        let noDataError = APIError.noData
        XCTAssertEqual(noDataError.errorDescription, "No data received from the server.")
        
        let serverError = APIError.serverError(statusCode: 500, message: "Internal server error")
        XCTAssertEqual(serverError.errorDescription, "Server error 500: Internal server error")
        
        let decodingError = APIError.decodingError("JSON parsing failed")
        XCTAssertEqual(decodingError.errorDescription, "Failed to decode server response: JSON parsing failed")
        
        let authError = APIError.authenticationError
        XCTAssertEqual(authError.errorDescription, "Authentication failed. Please check your app's API key.")
        
        let unauthorizedError = APIError.unauthorized("API key missing")
        XCTAssertEqual(unauthorizedError.errorDescription, "API key missing")
    }
    
    // MARK: - Data Extension Tests
    
    func testDataAppendString() throws {
        var data = Data()
        let testString = "Hello, World!"
        
        data.append(testString)
        
        let stringFromData = String(data: data, encoding: .utf8)
        XCTAssertEqual(stringFromData, testString, "Data should correctly append UTF-8 string")
    }
    
    func testDataAppendEmptyString() throws {
        var data = Data()
        let emptyString = ""
        
        data.append(emptyString)
        
        XCTAssertEqual(data.count, 0, "Appending empty string should not add any bytes")
    }
    
    func testDataAppendUnicodeString() throws {
        var data = Data()
        let unicodeString = "Hello 👋 World 🌍"
        
        data.append(unicodeString)
        
        let stringFromData = String(data: data, encoding: .utf8)
        XCTAssertEqual(stringFromData, unicodeString, "Data should correctly handle Unicode strings")
    }
    
    // MARK: - Performance Tests
    
    func testImageResizingPerformance() throws {
        // Create a large image for performance testing
        let largeSize = CGSize(width: 4000, height: 4000)
        UIGraphicsBeginImageContext(largeSize)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.blue.cgColor)
        context?.fill(CGRect(origin: .zero, size: largeSize))
        let largeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        XCTAssertNotNil(largeImage, "Large image should be created for performance test")
        
        self.measure {
            let _ = largeImage!.resized(withMaxDimension: 2048)
        }
    }
    
    func testRecipeConversionPerformance() throws {
        let apiRecipe = RecipeAPI(
            id: "performance-test-id",
            name: "Performance Test Recipe",
            description: "Testing conversion performance",
            main_dish: "Main",
            side_dish: "Side",
            total_time: 45,
            prep_time: 15,
            cook_time: 30,
            servings: 4,
            difficulty: "medium",
            ingredients_used: Array(1...50).map { IngredientUsed(name: "Ingredient \($0)", amount: "1 cup") },
            instructions: Array(1...20).map { "Step \($0): Do something" },
            nutrition: NutritionAPI(calories: 300, protein: 20, carbs: 35, fat: 10, fiber: 5, sugar: 8, sodium: 500),
            tips: "Performance test tip",
            tags: ["tag1", "tag2", "tag3", "tag4", "tag5"],
            share_caption: "Performance test caption"
        )
        
        self.measure {
            let _ = apiManager.convertAPIRecipeToAppRecipe(apiRecipe)
        }
    }
}