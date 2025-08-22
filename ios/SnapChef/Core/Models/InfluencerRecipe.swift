import SwiftUI
import Foundation

// Wrapper for Recipe with additional display properties
struct InfluencerShowcaseRecipe: Sendable {
    let recipe: Recipe
    let cuisine: String
    let tags: [String]
    let rating: Double
}

struct InfluencerRecipe: Identifiable, Sendable {
    let id = UUID()
    let influencerName: String
    let influencerHandle: String
    let profileImageName: String
    let quote: String
    let beforeImageName: String
    let afterImageName: String
    let recipe: InfluencerShowcaseRecipe
    let fridgeContents: [String]
    let followerCount: String
    let dateShared: Date
    let likes: Int
    let shares: Int
}

// Mock data for celebrity mom influencers
extension InfluencerRecipe {
    static let mockInfluencers: [InfluencerRecipe] = [
        // Sarah Johnson
        InfluencerRecipe(
            influencerName: "Sarah Johnson",
            influencerHandle: "@sarahcooks",
            profileImageName: "kylie_profile",
            quote: "My daughter loves when I make this! It's our go-to after-school snack 💕",
            beforeImageName: "fridge1.jpg",
            afterImageName: "meal1.jpg",
            recipe: InfluencerShowcaseRecipe(
                recipe: Recipe(
                    id: UUID(),
                    ownerID: nil,  // Mock data
                    name: "Gluten-Free Rainbow Veggie Wraps",
                    description: "Colorful, healthy wraps that Stormi actually asks for! Packed with hidden veggies and her favorite hummus.",
                    ingredients: [
                        Ingredient(id: UUID(), name: "Gluten-free tortillas", quantity: "4", unit: "wraps", isAvailable: true),
                        Ingredient(id: UUID(), name: "Rainbow bell peppers", quantity: "3", unit: "peppers", isAvailable: true),
                        Ingredient(id: UUID(), name: "Organic hummus", quantity: "1", unit: "cup", isAvailable: true),
                        Ingredient(id: UUID(), name: "Baby spinach", quantity: "2", unit: "cups", isAvailable: true),
                        Ingredient(id: UUID(), name: "Avocado", quantity: "2", unit: "whole", isAvailable: true),
                        Ingredient(id: UUID(), name: "Shredded carrots", quantity: "1", unit: "cup", isAvailable: true),
                        Ingredient(id: UUID(), name: "Cucumber", quantity: "1", unit: "medium", isAvailable: true),
                        Ingredient(id: UUID(), name: "Feta cheese", quantity: "1/2", unit: "cup", isAvailable: true)
                    ],
                    instructions: [
                        "Warm the gluten-free tortillas slightly to make them pliable",
                        "Spread a generous layer of hummus on each tortilla",
                        "Layer baby spinach leaves across the center",
                        "Add thinly sliced bell peppers in rainbow colors",
                        "Mash avocado and spread over the veggies",
                        "Add shredded carrots and cucumber strips",
                        "Sprinkle with crumbled feta cheese",
                        "Roll tightly and cut in half diagonally",
                        "Secure with cute toothpicks for kids!"
                    ],
                    cookTime: 0,
                    prepTime: 15,
                    servings: 4,
                    difficulty: .easy,
                    nutrition: Nutrition(
                        calories: 285,
                        protein: 12,
                        carbs: 32,
                        fat: 18,
                        fiber: 8,
                        sugar: 6,
                        sodium: 420
                    ),
                    imageURL: nil,
                    createdAt: Date(),
                    tags: ["gluten-free", "vegetarian", "kid-friendly", "no-cook"],
                    dietaryInfo: DietaryInfo(
                        isVegetarian: true,
                        isVegan: false,
                        isGlutenFree: true,
                        isDairyFree: false
                    ),
                    isDetectiveRecipe: false,
                    cookingTechniques: ["wrapping"],
                    flavorProfile: FlavorProfile(sweet: 4, salty: 3, sour: 2, bitter: 1, umami: 3),
                    secretIngredients: ["Special hummus blend"],
                    proTips: ["Roll tightly to prevent ingredients from falling out"],
                    visualClues: ["Colorful vegetable layers", "Neat wrap presentation"],
                    shareCaption: "Rainbow veggie wraps that even kids love! 🌈🥗 #HealthyKids #GlutenFree"
                ),
                cuisine: "Healthy",
                tags: ["gluten-free", "vegetarian", "kid-friendly", "no-cook"],
                rating: 4.9
            ),
            fridgeContents: [
                "Oat milk", "Gluten-free bread", "Organic eggs", "Avocados",
                "Bell peppers", "Spinach", "Kale", "Berries", "Greek yogurt",
                "Hummus", "Almond butter", "Coconut water", "Feta cheese",
                "Cucumber", "Carrots", "Tomatoes", "Fresh herbs"
            ],
            followerCount: "398M",
            dateShared: Date().addingTimeInterval(-86_400 * 3),
            likes: 4_892_000,
            shares: 287_000
        ),

        // Emma Chen
        InfluencerRecipe(
            influencerName: "Emma Chen",
            influencerHandle: "@emmaeats",
            profileImageName: "chrissy_profile",
            quote: "My kids destroyed this in 5 minutes flat! Mom win 🙌",
            beforeImageName: "fridge2.jpg",
            afterImageName: "meal2.jpg",
            recipe: InfluencerShowcaseRecipe(
                recipe: Recipe(
                    id: UUID(),
                    ownerID: nil,  // Mock data
                    name: "Thai-Inspired Chicken Lettuce Cups",
                    description: "A family favorite that's ready in 20 minutes! Sweet, savory, and the kids love assembling their own cups.",
                    ingredients: [
                        Ingredient(id: UUID(), name: "Ground chicken", quantity: "1", unit: "lb", isAvailable: true),
                        Ingredient(id: UUID(), name: "Butter lettuce", quantity: "1", unit: "head", isAvailable: true),
                        Ingredient(id: UUID(), name: "Soy sauce", quantity: "3", unit: "tbsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Honey", quantity: "2", unit: "tbsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Ginger", quantity: "1", unit: "tbsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Garlic", quantity: "3", unit: "cloves", isAvailable: true),
                        Ingredient(id: UUID(), name: "Water chestnuts", quantity: "1", unit: "can", isAvailable: true),
                        Ingredient(id: UUID(), name: "Green onions", quantity: "4", unit: "stalks", isAvailable: true),
                        Ingredient(id: UUID(), name: "Sesame oil", quantity: "1", unit: "tsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Lime", quantity: "2", unit: "whole", isAvailable: true)
                    ],
                    instructions: [
                        "Heat sesame oil in a large skillet over medium-high heat",
                        "Add ground chicken and cook until browned",
                        "Add minced garlic and ginger, cook for 1 minute",
                        "Stir in soy sauce and honey",
                        "Add diced water chestnuts for crunch",
                        "Cook until sauce thickens, about 2-3 minutes",
                        "Remove from heat and add sliced green onions",
                        "Separate butter lettuce leaves",
                        "Spoon chicken mixture into lettuce cups",
                        "Squeeze fresh lime juice over each cup",
                        "Let kids customize with toppings!"
                    ],
                    cookTime: 10,
                    prepTime: 10,
                    servings: 4,
                    difficulty: .easy,
                    nutrition: Nutrition(
                        calories: 245,
                        protein: 28,
                        carbs: 15,
                        fat: 8,
                        fiber: 3,
                        sugar: 8,
                        sodium: 680
                    ),
                    imageURL: nil,
                    createdAt: Date(),
                    tags: ["vegan", "high-protein", "easy", "quick"],
                    dietaryInfo: DietaryInfo(
                        isVegetarian: true,
                        isVegan: true,
                        isGlutenFree: false,
                        isDairyFree: true
                    ),
                    isDetectiveRecipe: false,
                    cookingTechniques: ["stir-frying", "chopping"],
                    flavorProfile: FlavorProfile(sweet: 3, salty: 6, sour: 4, bitter: 2, umami: 8),
                    secretIngredients: ["Thai fish sauce", "Fresh lime juice"],
                    proTips: ["Cook chicken until just done to keep it tender"],
                    visualClues: ["Fresh lettuce cups", "Colorful filling"],
                    shareCaption: "Thai-inspired lettuce wraps! So fresh and flavorful 🥬🌶️ #ThaiFood #HealthyEating"
                ),
                cuisine: "Thai",
                tags: ["asian", "lettuce-wraps", "quick", "kid-friendly"],
                rating: 4.8
            ),
            fridgeContents: [
                "Ground chicken", "Soy sauce", "Sriracha", "Fish sauce",
                "Limes", "Ginger root", "Garlic", "Butter lettuce",
                "Thai basil", "Cilantro", "Green onions", "Bell peppers",
                "Coconut milk", "Rice", "Eggs", "Champagne", "Kids yogurt"
            ],
            followerCount: "13.2M",
            dateShared: Date().addingTimeInterval(-86_400 * 5),
            likes: 892_000,
            shares: 45_000
        ),

        // Jessica Martinez
        InfluencerRecipe(
            influencerName: "Jessica Martinez",
            influencerHandle: "@jessicacooks",
            profileImageName: "blake_profile",
            quote: "My husband said this is better than takeout. I'll take it! 🎬✨",
            beforeImageName: "fridge3.jpg",
            afterImageName: "meal3.jpg",
            recipe: InfluencerShowcaseRecipe(
                recipe: Recipe(
                    id: UUID(),
                    ownerID: nil,  // Mock data
                    name: "Harvest Goddess Bowl",
                    description: "A beautiful, nourishing bowl that looks as good as it tastes. My girls love picking their own toppings!",
                    ingredients: [
                        Ingredient(id: UUID(), name: "Quinoa", quantity: "1", unit: "cup", isAvailable: true),
                        Ingredient(id: UUID(), name: "Sweet potato", quantity: "2", unit: "medium", isAvailable: true),
                        Ingredient(id: UUID(), name: "Kale", quantity: "1", unit: "bunch", isAvailable: true),
                        Ingredient(id: UUID(), name: "Chickpeas", quantity: "1", unit: "can", isAvailable: true),
                        Ingredient(id: UUID(), name: "Tahini", quantity: "3", unit: "tbsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Maple syrup", quantity: "1", unit: "tbsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Pomegranate seeds", quantity: "1/2", unit: "cup", isAvailable: true),
                        Ingredient(id: UUID(), name: "Pumpkin seeds", quantity: "1/4", unit: "cup", isAvailable: true),
                        Ingredient(id: UUID(), name: "Goat cheese", quantity: "4", unit: "oz", isAvailable: true)
                    ],
                    instructions: [
                        "Cook quinoa according to package directions",
                        "Cube sweet potatoes and roast at 425°F for 25 minutes",
                        "Massage kale with olive oil and a pinch of salt",
                        "Drain and rinse chickpeas, pat dry",
                        "Roast chickpeas with cumin and paprika for 20 minutes",
                        "Make dressing: whisk tahini, maple syrup, lemon juice, and water",
                        "Build bowls: start with quinoa base",
                        "Add roasted sweet potatoes and crispy chickpeas",
                        "Top with massaged kale",
                        "Drizzle with tahini dressing",
                        "Garnish with pomegranate seeds, pumpkin seeds, and goat cheese"
                    ],
                    cookTime: 30,
                    prepTime: 15,
                    servings: 4,
                    difficulty: .medium,
                    nutrition: Nutrition(
                        calories: 485,
                        protein: 18,
                        carbs: 64,
                        fat: 19,
                        fiber: 12,
                        sugar: 14,
                        sodium: 320
                    ),
                    imageURL: nil,
                    createdAt: Date(),
                    tags: ["italian", "comfort-food", "quick", "easy"],
                    dietaryInfo: DietaryInfo(
                        isVegetarian: false,
                        isVegan: false,
                        isGlutenFree: false,
                        isDairyFree: false
                    ),
                    isDetectiveRecipe: false,
                    cookingTechniques: ["boiling", "mixing"],
                    flavorProfile: FlavorProfile(sweet: 5, salty: 4, sour: 3, bitter: 1, umami: 6),
                    secretIngredients: ["Fresh basil", "Good parmesan"],
                    proTips: ["Cook pasta al dente for best texture"],
                    visualClues: ["Creamy sauce coating", "Fresh herb garnish"],
                    shareCaption: "Simple pasta perfection! 🍝✨ #PastaLove #ComfortFood"
                ),
                cuisine: "Healthy",
                tags: ["gluten-free", "vegetarian", "bowls", "harvest"],
                rating: 4.9
            ),
            fridgeContents: [
                "Kale", "Spinach", "Sweet potatoes", "Quinoa", "Wild rice",
                "Tahini", "Maple syrup", "Goat cheese", "Pomegranate",
                "Chickpeas", "Black beans", "Avocados", "Lemons",
                "Fresh herbs", "Whole grain bread", "Almond milk", "Berries"
            ],
            followerCount: "43.8M",
            dateShared: Date().addingTimeInterval(-86_400 * 2),
            likes: 2_100_000,
            shares: 98_000
        ),

        // Rachel Thompson
        InfluencerRecipe(
            influencerName: "Rachel Thompson",
            influencerHandle: "@rachelthompson",
            profileImageName: "reese_profile",
            quote: "Y'all, this smoothie bowl will change your morning! 🍑",
            beforeImageName: "fridge4.jpg",
            afterImageName: "meal4.jpg",
            recipe: InfluencerShowcaseRecipe(
                recipe: Recipe(
                    id: UUID(),
                    ownerID: nil,  // Mock data
                    name: "Southern Peach Pie Smoothie Bowl",
                    description: "A healthy breakfast that tastes like dessert! Tennessee peaches make all the difference.",
                    ingredients: [
                        Ingredient(id: UUID(), name: "Frozen peaches", quantity: "1.5", unit: "cups", isAvailable: true),
                        Ingredient(id: UUID(), name: "Greek yogurt", quantity: "1/2", unit: "cup", isAvailable: true),
                        Ingredient(id: UUID(), name: "Almond milk", quantity: "1/4", unit: "cup", isAvailable: true),
                        Ingredient(id: UUID(), name: "Honey", quantity: "2", unit: "tbsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Vanilla extract", quantity: "1", unit: "tsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Granola", quantity: "1/3", unit: "cup", isAvailable: true),
                        Ingredient(id: UUID(), name: "Fresh peach", quantity: "1", unit: "sliced", isAvailable: true),
                        Ingredient(id: UUID(), name: "Pecans", quantity: "2", unit: "tbsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Cinnamon", quantity: "1/4", unit: "tsp", isAvailable: true)
                    ],
                    instructions: [
                        "Blend frozen peaches, Greek yogurt, and almond milk until thick",
                        "Add honey and vanilla, blend briefly",
                        "Pour into a bowl",
                        "Top with sliced fresh peaches in a pretty pattern",
                        "Sprinkle with granola for crunch",
                        "Add chopped pecans for that Southern touch",
                        "Dust with cinnamon",
                        "Optional: drizzle with extra honey",
                        "Enjoy immediately while cold!"
                    ],
                    cookTime: 0,
                    prepTime: 10,
                    servings: 2,
                    difficulty: .easy,
                    nutrition: Nutrition(
                        calories: 320,
                        protein: 12,
                        carbs: 52,
                        fat: 9,
                        fiber: 5,
                        sugar: 32,
                        sodium: 85
                    ),
                    imageURL: nil,
                    createdAt: Date(),
                    tags: ["paleo", "gluten-free", "grain-free", "healthy"],
                    dietaryInfo: DietaryInfo(
                        isVegetarian: false,
                        isVegan: false,
                        isGlutenFree: true,
                        isDairyFree: true
                    ),
                    isDetectiveRecipe: false,
                    cookingTechniques: ["blending", "layering"],
                    flavorProfile: FlavorProfile(sweet: 8, salty: 1, sour: 2, bitter: 1, umami: 2),
                    secretIngredients: ["Coconut flakes", "Honey drizzle"],
                    proTips: ["Freeze fruit for thicker texture"],
                    visualClues: ["Beautiful fruit layers", "Colorful toppings"],
                    shareCaption: "Southern peach smoothie bowl! 🍑🌞 #SmoothieBowl #HealthyBreakfast"
                ),
                cuisine: "Southern",
                tags: ["breakfast", "smoothie-bowl", "peach", "healthy"],
                rating: 4.7
            ),
            fridgeContents: [
                "Greek yogurt", "Almond milk", "Fresh peaches", "Berries",
                "Honey", "Maple syrup", "Granola", "Pecans", "Walnuts",
                "Green juice", "Kombucha", "Eggs", "Turkey bacon",
                "Whole grain bread", "Avocado", "Sweet tea", "Butter"
            ],
            followerCount: "27.9M",
            dateShared: Date().addingTimeInterval(-86_400 * 4),
            likes: 1_500_000,
            shares: 72_000
        ),

        // Lisa Anderson
        InfluencerRecipe(
            influencerName: "Lisa Anderson",
            influencerHandle: "@lisahealthy",
            profileImageName: "kourtney_profile",
            quote: "My kids beg for these! Proof that healthy can be delicious 🌱",
            beforeImageName: "fridge5.jpg",
            afterImageName: "meal5.jpg",
            recipe: InfluencerShowcaseRecipe(
                recipe: Recipe(
                    id: UUID(),
                    ownerID: nil,  // Mock data
                    name: "Superfood Energy Balls",
                    description: "No-bake, vegan, and loaded with nutrients. Perfect for lunch boxes or post-workout!",
                    ingredients: [
                        Ingredient(id: UUID(), name: "Medjool dates", quantity: "1", unit: "cup", isAvailable: true),
                        Ingredient(id: UUID(), name: "Raw almonds", quantity: "1/2", unit: "cup", isAvailable: true),
                        Ingredient(id: UUID(), name: "Chia seeds", quantity: "2", unit: "tbsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Hemp hearts", quantity: "2", unit: "tbsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Cacao powder", quantity: "3", unit: "tbsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Almond butter", quantity: "2", unit: "tbsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Vanilla extract", quantity: "1", unit: "tsp", isAvailable: true),
                        Ingredient(id: UUID(), name: "Coconut flakes", quantity: "1/3", unit: "cup", isAvailable: true),
                        Ingredient(id: UUID(), name: "Matcha powder", quantity: "1", unit: "tsp", isAvailable: true)
                    ],
                    instructions: [
                        "Pit the dates if needed",
                        "In a food processor, blend almonds until coarsely ground",
                        "Add dates and process until sticky",
                        "Add chia seeds, hemp hearts, and cacao powder",
                        "Add almond butter and vanilla",
                        "Pulse until mixture holds together",
                        "Roll into 1-inch balls",
                        "Roll half in coconut flakes",
                        "Dust the other half with matcha powder",
                        "Refrigerate for 30 minutes to firm up",
                        "Store in airtight container for up to a week"
                    ],
                    cookTime: 0,
                    prepTime: 15,
                    servings: 20,
                    difficulty: .easy,
                    nutrition: Nutrition(
                        calories: 85,
                        protein: 3,
                        carbs: 12,
                        fat: 4,
                        fiber: 2,
                        sugar: 9,
                        sodium: 15
                    ),
                    imageURL: nil,
                    createdAt: Date(),
                    tags: ["healthy", "mediterranean", "light", "fresh"],
                    dietaryInfo: DietaryInfo(
                        isVegetarian: true,
                        isVegan: false,
                        isGlutenFree: false,
                        isDairyFree: false
                    ),
                    isDetectiveRecipe: false,
                    cookingTechniques: ["mixing", "rolling"],
                    flavorProfile: FlavorProfile(sweet: 7, salty: 2, sour: 1, bitter: 3, umami: 2),
                    secretIngredients: ["Vanilla extract", "Sea salt"],
                    proTips: ["Chill mixture before rolling for easier handling"],
                    visualClues: ["Perfect sphere shapes", "Dusted with cocoa"],
                    shareCaption: "Energy bites for busy days! 💪🍫 #EnergyBites #HealthySnacks"
                ),
                cuisine: "Vegan",
                tags: ["no-bake", "vegan", "energy-balls", "snack"],
                rating: 4.8
            ),
            fridgeContents: [
                "Almond milk", "Coconut water", "Green juice", "Kombucha",
                "Chia seeds", "Hemp hearts", "Dates", "Almonds", "Cashews",
                "Almond butter", "Coconut oil", "Matcha", "Cacao powder",
                "Fresh berries", "Avocados", "Kale", "Cucumber", "Celery"
            ],
            followerCount: "224M",
            dateShared: Date().addingTimeInterval(-86_400 * 1),
            likes: 3_200_000,
            shares: 156_000
        )
    ]
}
