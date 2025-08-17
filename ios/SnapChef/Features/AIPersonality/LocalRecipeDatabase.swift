import Foundation

struct LocalRecipeDatabase {
    static let shared = LocalRecipeDatabase()

    private init() {}

    // Helper function to create ingredients from strings
    private func createIngredients(from items: [String]) -> [Ingredient] {
        return items.map { item in
            Ingredient(id: UUID(), name: item, quantity: "", unit: nil, isAvailable: true)
        }
    }

    // Default nutrition values
    private let defaultNutrition = Nutrition(
        calories: 350,
        protein: 15,
        carbs: 45,
        fat: 12,
        fiber: 5,
        sugar: 8,
        sodium: 480
    )

    // MARK: - Italian Recipes
    var italianRecipes: [Recipe] {
        [
        Recipe(
            id: UUID(),
            name: "Classic Spaghetti Carbonara",
            description: "Creamy pasta with crispy pancetta and parmesan",
            ingredients: createIngredients(from: ["400g spaghetti", "200g pancetta", "4 egg yolks", "100g Parmigiano Reggiano", "Black pepper", "Salt"]),
            instructions: ["Cook spaghetti until al dente", "Crisp pancetta in a pan", "Mix egg yolks with cheese", "Toss hot pasta with pancetta", "Remove from heat and add egg mixture", "Season with pepper"],
            cookTime: 15,
            prepTime: 10,
            servings: 4,
            difficulty: .easy,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["italian", "pasta", "classic"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false)
        ),
        Recipe(
            id: UUID(),
            name: "Margherita Pizza",
            description: "Traditional Italian pizza with fresh mozzarella and basil",
            ingredients: createIngredients(from: ["Pizza dough", "200g mozzarella", "400g tomato sauce", "Fresh basil", "Olive oil", "Salt"]),
            instructions: ["Roll out pizza dough", "Spread tomato sauce", "Add torn mozzarella", "Bake at 250°C for 10 minutes", "Top with fresh basil", "Drizzle with olive oil"],
            cookTime: 15,
            prepTime: 20,
            servings: 2,
            difficulty: .easy,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["italian", "pizza", "vegetarian"],
            dietaryInfo: DietaryInfo(isVegetarian: true, isVegan: false, isGlutenFree: false, isDairyFree: false)
        )
        ]
    }

    // MARK: - Mexican Recipes
    var mexicanRecipes: [Recipe] {
        [
        Recipe(
            id: UUID(),
            name: "Chicken Tacos al Pastor",
            description: "Marinated chicken with pineapple and cilantro",
            ingredients: createIngredients(from: ["Chicken thighs", "Corn tortillas", "Pineapple", "Onion", "Cilantro", "Lime", "Chili powder"]),
            instructions: ["Marinate chicken in spices", "Grill with pineapple", "Warm tortillas", "Chop chicken", "Assemble tacos", "Top with onion and cilantro"],
            cookTime: 20,
            prepTime: 30,
            servings: 4,
            difficulty: .medium,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["mexican", "tacos", "spicy"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: true, isDairyFree: true)
        ),
        Recipe(
            id: UUID(),
            name: "Enchiladas Verdes",
            description: "Chicken enchiladas with green salsa",
            ingredients: createIngredients(from: ["Corn tortillas", "Shredded chicken", "Green salsa", "Sour cream", "Cheese", "Cilantro"]),
            instructions: ["Warm tortillas", "Fill with chicken", "Roll and place in dish", "Cover with salsa", "Top with cheese", "Bake until bubbly"],
            cookTime: 25,
            prepTime: 20,
            servings: 6,
            difficulty: .medium,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["mexican", "enchiladas", "spicy"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: true, isDairyFree: false)
        )
        ]
    }

    // MARK: - Chinese Recipes
    var chineseRecipes: [Recipe] {
        [
        Recipe(
            id: UUID(),
            name: "Kung Pao Chicken",
            description: "Spicy chicken with peanuts and peppers",
            ingredients: createIngredients(from: ["Chicken breast", "Peanuts", "Dried chilies", "Bell peppers", "Soy sauce", "Rice vinegar", "Cornstarch"]),
            instructions: ["Marinate chicken pieces", "Prepare sauce mixture", "Stir-fry chilies", "Add chicken", "Add vegetables", "Toss with sauce and peanuts"],
            cookTime: 15,
            prepTime: 20,
            servings: 4,
            difficulty: .medium,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["chinese", "spicy", "nuts"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: true)
        ),
        Recipe(
            id: UUID(),
            name: "Sweet and Sour Pork",
            description: "Crispy pork in tangy sauce",
            ingredients: createIngredients(from: ["Pork shoulder", "Pineapple", "Bell peppers", "Onion", "Vinegar", "Sugar", "Ketchup"]),
            instructions: ["Cut pork into chunks", "Batter and deep fry", "Make sweet sour sauce", "Stir-fry vegetables", "Combine everything", "Serve over rice"],
            cookTime: 25,
            prepTime: 30,
            servings: 4,
            difficulty: .hard,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["chinese", "sweet", "pork"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: true)
        )
        ]
    }

    // MARK: - Japanese Recipes
    var japaneseRecipes: [Recipe] {
        [
        Recipe(
            id: UUID(),
            name: "Chicken Teriyaki",
            description: "Glazed chicken with sweet soy sauce",
            ingredients: createIngredients(from: ["Chicken thighs", "Soy sauce", "Mirin", "Sugar", "Sake", "Ginger", "Green onions"]),
            instructions: ["Make teriyaki sauce", "Pan-fry chicken skin-side down", "Flip and cook through", "Glaze with sauce", "Reduce until thick", "Garnish with green onions"],
            cookTime: 20,
            prepTime: 10,
            servings: 4,
            difficulty: .easy,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["japanese", "teriyaki", "sweet"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: true)
        ),
        Recipe(
            id: UUID(),
            name: "Beef Gyudon",
            description: "Simmered beef over rice",
            ingredients: createIngredients(from: ["Thinly sliced beef", "Onions", "Dashi", "Soy sauce", "Mirin", "Sugar", "Rice"]),
            instructions: ["Cook onions in dashi", "Add seasonings", "Add beef slices", "Simmer briefly", "Serve over rice", "Top with pickled ginger"],
            cookTime: 15,
            prepTime: 10,
            servings: 2,
            difficulty: .easy,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["japanese", "beef", "rice"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: true, isDairyFree: true)
        )
        ]
    }

    // MARK: - Thai Recipes
    var thaiRecipes: [Recipe] {
        [
        Recipe(
            id: UUID(),
            name: "Pad Thai",
            description: "Stir-fried rice noodles with tamarind",
            ingredients: createIngredients(from: ["Rice noodles", "Shrimp", "Tofu", "Bean sprouts", "Peanuts", "Tamarind", "Fish sauce"]),
            instructions: ["Soak noodles", "Make pad thai sauce", "Stir-fry shrimp", "Add noodles and sauce", "Toss with vegetables", "Top with peanuts"],
            cookTime: 15,
            prepTime: 20,
            servings: 2,
            difficulty: .medium,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["thai", "noodles", "seafood"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: true, isDairyFree: true)
        ),
        Recipe(
            id: UUID(),
            name: "Green Curry",
            description: "Spicy coconut curry with vegetables",
            ingredients: createIngredients(from: ["Green curry paste", "Coconut milk", "Chicken", "Thai eggplant", "Basil", "Fish sauce"]),
            instructions: ["Fry curry paste", "Add coconut milk", "Simmer chicken", "Add vegetables", "Season to taste", "Garnish with basil"],
            cookTime: 20,
            prepTime: 15,
            servings: 4,
            difficulty: .medium,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["thai", "curry", "spicy"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: true, isDairyFree: true)
        )
        ]
    }

    // MARK: - Indian Recipes
    var indianRecipes: [Recipe] {
        [
        Recipe(
            id: UUID(),
            name: "Chicken Tikka Masala",
            description: "Creamy tomato curry with grilled chicken",
            ingredients: createIngredients(from: ["Chicken", "Yogurt", "Tomatoes", "Cream", "Garam masala", "Ginger", "Garlic"]),
            instructions: ["Marinate chicken", "Grill until charred", "Make curry sauce", "Simmer chicken in sauce", "Finish with cream", "Garnish with cilantro"],
            cookTime: 30,
            prepTime: 30,
            servings: 4,
            difficulty: .medium,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["indian", "curry", "creamy"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: true, isDairyFree: false)
        ),
        Recipe(
            id: UUID(),
            name: "Palak Paneer",
            description: "Spinach curry with cottage cheese",
            ingredients: createIngredients(from: ["Spinach", "Paneer", "Onions", "Tomatoes", "Cream", "Cumin", "Garlic"]),
            instructions: ["Blanch spinach", "Blend to puree", "Sauté aromatics", "Add spinach puree", "Fold in paneer", "Finish with cream"],
            cookTime: 25,
            prepTime: 20,
            servings: 4,
            difficulty: .medium,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["indian", "vegetarian", "spinach"],
            dietaryInfo: DietaryInfo(isVegetarian: true, isVegan: false, isGlutenFree: true, isDairyFree: false)
        )
        ]
    }

    // MARK: - French Recipes
    var frenchRecipes: [Recipe] {
        [
        Recipe(
            id: UUID(),
            name: "Coq au Vin",
            description: "Chicken braised in red wine",
            ingredients: createIngredients(from: ["Chicken", "Red wine", "Bacon", "Pearl onions", "Mushrooms", "Thyme", "Bay leaves"]),
            instructions: ["Brown chicken pieces", "Cook bacon and vegetables", "Deglaze with wine", "Braise chicken", "Reduce sauce", "Garnish with parsley"],
            cookTime: 90,
            prepTime: 30,
            servings: 6,
            difficulty: .hard,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["french", "braised", "wine"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: true, isDairyFree: true)
        ),
        Recipe(
            id: UUID(),
            name: "Quiche Lorraine",
            description: "Savory custard tart with bacon",
            ingredients: createIngredients(from: ["Pie crust", "Eggs", "Heavy cream", "Bacon", "Gruyere cheese", "Nutmeg"]),
            instructions: ["Blind bake crust", "Cook bacon", "Mix custard", "Add bacon and cheese", "Pour into crust", "Bake until set"],
            cookTime: 35,
            prepTime: 20,
            servings: 8,
            difficulty: .medium,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["french", "brunch", "eggs"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false)
        )
        ]
    }

    // MARK: - American Recipes
    var americanRecipes: [Recipe] {
        [
        Recipe(
            id: UUID(),
            name: "Classic Cheeseburger",
            description: "Juicy beef patty with melted cheese",
            ingredients: createIngredients(from: ["Ground beef", "Burger buns", "Cheddar cheese", "Lettuce", "Tomato", "Onion", "Pickles"]),
            instructions: ["Form beef patties", "Season with salt and pepper", "Grill to desired doneness", "Add cheese to melt", "Toast buns", "Assemble with toppings"],
            cookTime: 10,
            prepTime: 10,
            servings: 4,
            difficulty: .easy,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["american", "burger", "comfort-food"],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false)
        ),
        Recipe(
            id: UUID(),
            name: "Mac and Cheese",
            description: "Creamy baked pasta with cheese",
            ingredients: createIngredients(from: ["Elbow macaroni", "Cheddar", "Butter", "Flour", "Milk", "Breadcrumbs"]),
            instructions: ["Cook pasta", "Make cheese sauce", "Combine pasta and sauce", "Top with breadcrumbs", "Bake until golden", "Let rest before serving"],
            cookTime: 25,
            prepTime: 15,
            servings: 6,
            difficulty: .easy,
            nutrition: defaultNutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: ["american", "pasta", "comfort-food"],
            dietaryInfo: DietaryInfo(isVegetarian: true, isVegan: false, isGlutenFree: false, isDairyFree: false)
        )
        ]
    }

    func getRandomRecipe(for cuisine: String) -> Recipe? {
        let cleanCuisine = cuisine.replacingOccurrences(of: " 🍝", with: "")
            .replacingOccurrences(of: " 🌮", with: "")
            .replacingOccurrences(of: " 🥟", with: "")
            .replacingOccurrences(of: " 🍱", with: "")
            .replacingOccurrences(of: " 🍜", with: "")
            .replacingOccurrences(of: " 🍛", with: "")
            .replacingOccurrences(of: " 🥐", with: "")
            .replacingOccurrences(of: " 🍔", with: "")
            .lowercased()

        let recipes: [Recipe]

        switch cleanCuisine {
        case "italian":
            recipes = italianRecipes
        case "mexican":
            recipes = mexicanRecipes
        case "chinese":
            recipes = chineseRecipes
        case "japanese":
            recipes = japaneseRecipes
        case "thai":
            recipes = thaiRecipes
        case "indian":
            recipes = indianRecipes
        case "french":
            recipes = frenchRecipes
        case "american":
            recipes = americanRecipes
        default:
            // If cuisine not found, return a random recipe from all cuisines
            let allRecipes = italianRecipes + mexicanRecipes + chineseRecipes +
                           japaneseRecipes + thaiRecipes + indianRecipes +
                           frenchRecipes + americanRecipes
            recipes = allRecipes
        }

        return recipes.randomElement()
    }
}
