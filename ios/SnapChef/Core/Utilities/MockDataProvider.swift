import Foundation

class MockDataProvider {
    static let shared = MockDataProvider()
    
    private init() {}
    
    var useMockData: Bool {
        #if DEBUG
        return true // Set to false to use real API
        #else
        return false
        #endif
    }
    
    func mockRecipeResponse() -> RecipeGenerationResponse {
        let recipes = [
            Recipe(
                name: "Garden Fresh Salad",
                description: "A colorful and nutritious salad with fresh vegetables",
                ingredients: [
                    Ingredient(name: "Mixed greens", quantity: "4", unit: "cups", isAvailable: true),
                    Ingredient(name: "Cherry tomatoes", quantity: "1", unit: "cup", isAvailable: true),
                    Ingredient(name: "Cucumber", quantity: "1", unit: "medium", isAvailable: true),
                    Ingredient(name: "Red onion", quantity: "1/4", unit: "cup", isAvailable: true),
                    Ingredient(name: "Feta cheese", quantity: "1/2", unit: "cup", isAvailable: false),
                    Ingredient(name: "Olive oil", quantity: "3", unit: "tbsp", isAvailable: true),
                    Ingredient(name: "Lemon juice", quantity: "2", unit: "tbsp", isAvailable: false)
                ],
                instructions: [
                    "Wash and dry the mixed greens thoroughly",
                    "Cut cherry tomatoes in half",
                    "Dice the cucumber into small cubes",
                    "Thinly slice the red onion",
                    "Combine all vegetables in a large bowl",
                    "Crumble feta cheese over the salad",
                    "Whisk together olive oil and lemon juice",
                    "Drizzle dressing over salad and toss gently"
                ],
                cookTime: 0,
                prepTime: 15,
                servings: 4,
                difficulty: .easy,
                nutrition: Nutrition(
                    calories: 180,
                    protein: 6,
                    carbs: 12,
                    fat: 14,
                    fiber: 4,
                    sugar: 6,
                    sodium: 320
                ),
                imageURL: nil,
                createdAt: Date()
            ),
            Recipe(
                name: "Quick Chicken Stir-Fry",
                description: "A fast and flavorful Asian-inspired dish perfect for busy weeknights",
                ingredients: [
                    Ingredient(name: "Chicken breast", quantity: "1", unit: "lb", isAvailable: true),
                    Ingredient(name: "Broccoli florets", quantity: "2", unit: "cups", isAvailable: true),
                    Ingredient(name: "Bell pepper", quantity: "1", unit: "large", isAvailable: true),
                    Ingredient(name: "Soy sauce", quantity: "3", unit: "tbsp", isAvailable: false),
                    Ingredient(name: "Garlic", quantity: "3", unit: "cloves", isAvailable: true),
                    Ingredient(name: "Ginger", quantity: "1", unit: "tbsp", isAvailable: false),
                    Ingredient(name: "Vegetable oil", quantity: "2", unit: "tbsp", isAvailable: true)
                ],
                instructions: [
                    "Cut chicken into bite-sized pieces",
                    "Heat oil in a large wok or skillet over high heat",
                    "Add chicken and cook until golden brown, about 5 minutes",
                    "Remove chicken and set aside",
                    "Add broccoli and bell pepper to the pan",
                    "Stir-fry vegetables for 3-4 minutes until crisp-tender",
                    "Add garlic and ginger, cook for 30 seconds",
                    "Return chicken to pan with soy sauce",
                    "Toss everything together and serve hot"
                ],
                cookTime: 15,
                prepTime: 10,
                servings: 4,
                difficulty: .medium,
                nutrition: Nutrition(
                    calories: 320,
                    protein: 28,
                    carbs: 15,
                    fat: 12,
                    fiber: 3,
                    sugar: 5,
                    sodium: 580
                ),
                imageURL: nil,
                createdAt: Date()
            ),
            Recipe(
                name: "Hearty Vegetable Soup",
                description: "A warming and comforting soup packed with seasonal vegetables",
                ingredients: [
                    Ingredient(name: "Onion", quantity: "1", unit: "large", isAvailable: true),
                    Ingredient(name: "Carrots", quantity: "3", unit: "medium", isAvailable: true),
                    Ingredient(name: "Celery", quantity: "3", unit: "stalks", isAvailable: true),
                    Ingredient(name: "Potatoes", quantity: "2", unit: "large", isAvailable: true),
                    Ingredient(name: "Vegetable broth", quantity: "6", unit: "cups", isAvailable: false),
                    Ingredient(name: "Canned tomatoes", quantity: "1", unit: "can", isAvailable: true),
                    Ingredient(name: "Green beans", quantity: "1", unit: "cup", isAvailable: true),
                    Ingredient(name: "Italian seasoning", quantity: "2", unit: "tsp", isAvailable: true)
                ],
                instructions: [
                    "Dice onion, carrots, celery, and potatoes into uniform pieces",
                    "Heat oil in a large pot over medium heat",
                    "Sauté onion until translucent, about 5 minutes",
                    "Add carrots and celery, cook for 5 more minutes",
                    "Pour in vegetable broth and canned tomatoes",
                    "Bring to a boil, then reduce heat and simmer",
                    "Add potatoes and cook for 15 minutes",
                    "Add green beans and Italian seasoning",
                    "Simmer for another 10 minutes until vegetables are tender",
                    "Season with salt and pepper to taste"
                ],
                cookTime: 40,
                prepTime: 15,
                servings: 6,
                difficulty: .easy,
                nutrition: Nutrition(
                    calories: 145,
                    protein: 4,
                    carbs: 28,
                    fat: 3,
                    fiber: 6,
                    sugar: 8,
                    sodium: 420
                ),
                imageURL: nil,
                createdAt: Date()
            )
        ]
        
        return RecipeGenerationResponse(
            success: true,
            recipes: recipes,
            error: nil,
            creditsRemaining: 2
        )
    }
    
    func mockDeviceStatus() -> DeviceStatus {
        return DeviceStatus(
            deviceId: "mock-device-id",
            freeUsesRemaining: 2,
            isBlocked: false,
            hasSubscription: false
        )
    }
    
    func mockUser() -> User {
        return User(
            id: "mock-user-id",
            email: "test@snapchef.app",
            name: "Test User",
            profileImageURL: nil,
            subscription: Subscription(
                tier: .free,
                status: .active,
                expiresAt: nil,
                autoRenew: false
            ),
            credits: 10,
            deviceId: "mock-device-id",
            createdAt: Date(),
            lastLoginAt: Date()
        )
    }
}