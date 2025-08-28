import SwiftUI

struct MysteryMealView: View {
    @StateObject private var personalityManager = AIPersonalityManager.shared
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.dismiss) var dismiss
    @State private var isGenerating = false
    @State private var generatedRecipes: [Recipe] = []
    @State private var showingResults = false
    @State private var wheelRotation = 0.0
    @State private var selectedIngredients: [String] = []
    @State private var surpriseLevel: SurpriseRecipeSettings.WildnessLevel = .medium
    @State private var showConfetti = false
    @State private var selectedCuisine: String = ""
    @State private var selectedRecipe: Recipe?
    @State private var showingSaveAlert = false
    @State private var isSpinning = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var finalRotation = 0.0
    @State private var hasSpun = false

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                if !isGenerating {
                    ScrollViewReader { proxy in
                        ScrollView {
                        VStack(spacing: 30) {
                            // Header
                            MysteryMealHeaderView()
                                .padding(.top, 40)

                            // Fortune wheel
                            FortuneWheelView(rotation: $wheelRotation, onSpin: spinWheel)
                                .frame(height: 300)
                                .padding(.horizontal, 20)

                            // Selected cuisine label with enhanced design
                            if !selectedCuisine.isEmpty && !isGenerating {
                                VStack(spacing: 8) {
                                    Text("🎯 WINNER!")
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundColor(Color(hex: "#ffd700"))
                                        .tracking(2)
                                    
                                    Text(selectedCuisine)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color.white,
                                                    Color.white.opacity(0.9)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 10)
                                }
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            Color(hex: "#ffd700").opacity(0.6),
                                                            Color(hex: "#ffa500").opacity(0.4)
                                                        ],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    ),
                                                    lineWidth: 2
                                                )
                                        )
                                )
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }

                            // Spin button - show if not currently spinning
                            if !isSpinning {
                                SpinWheelButton(
                                    action: {
                                        // Clear previous recipe when spinning again
                                        selectedRecipe = nil
                                        selectedCuisine = ""
                                        spinWheel()
                                    },
                                    isSpinning: false
                                )
                                .padding(.horizontal, 40)
                                .opacity(selectedRecipe != nil ? 0.8 : 1.0)
                            }

                            // Recipe card
                            if let recipe = selectedRecipe {
                                VStack(spacing: 20) {
                                    MysteryRecipeCard(
                                        recipe: recipe,
                                        onSave: saveRecipe
                                    )
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                }
                                .padding(.horizontal, 20)
                                .id("recipeCard")
                            }

                            Spacer(minLength: 40)
                        }
                        .onAppear {
                            scrollProxy = proxy
                        }
                        }
                    }
                } else if isGenerating {
                    // Enhanced generating view
                    VStack(spacing: 30) {
                        Spacer()
                        
                        // Animated chef icon
                        ZStack {
                            ForEach(0..<3) { index in
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#667eea").opacity(0.6 - Double(index) * 0.2),
                                                Color(hex: "#f093fb").opacity(0.4 - Double(index) * 0.1)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 3
                                    )
                                    .frame(
                                        width: CGFloat(80 + index * 30),
                                        height: CGFloat(80 + index * 30)
                                    )
                                    .rotationEffect(.degrees(Double(index * 120)))
                                    .rotationEffect(.degrees(wheelRotation * 0.2))
                            }
                            
                            Text("👨‍🍳")
                                .font(.system(size: 60))
                        }
                        
                        VStack(spacing: 12) {
                            Text("Creating Your \(selectedCuisine.components(separatedBy: " ").first ?? "Mystery") Recipe")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Adding authentic flavors...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Loading dots
                        HStack(spacing: 12) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 12, height: 12)
                                    .scaleEffect(showConfetti ? 1.2 : 0.8)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                        value: showConfetti
                                    )
                            }
                        }
                        .onAppear {
                            showConfetti = true
                        }
                        
                        Spacer()
                    }
                }

                // Close button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.7))
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                        .padding(20)
                    }
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            print("🔍 DEBUG: [MysteryMealView] appeared - Start")
            // No state modifications directly in onAppear
            print("🔍 DEBUG: [MysteryMealView] appeared - End")
        }
        .fullScreenCover(isPresented: $showingResults) {
            RecipeResultsView(
                recipes: generatedRecipes,
                capturedImage: nil
            )
        }
        .particleExplosion(trigger: $showConfetti)
        .alert("Save Recipe", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if deviceManager.hasUnlimitedAccess {
                Text("Recipe saved to your collection!")
            } else if deviceManager.freeSavesRemaining > 0 {
                Text("Recipe saved! You have \(deviceManager.freeSavesRemaining - 1) free saves remaining.")
            } else {
                Text("You've used all your free saves. Upgrade to save unlimited recipes!")
            }
        }
    }

    private func saveRecipe() {
        guard let recipe = selectedRecipe else { return }

        // Check if user can save
        if !deviceManager.hasUnlimitedAccess && deviceManager.freeSavesRemaining <= 0 {
            showingSaveAlert = true
            return
        }

        // Consume a free save if not subscribed
        if !deviceManager.hasUnlimitedAccess {
            Task {
                await deviceManager.consumeFreeSave()
            }
        }

        // Save the recipe
        appState.addRecentRecipe(recipe)
        appState.saveRecipeWithPhotos(recipe, beforePhoto: nil, afterPhoto: nil)

        showingSaveAlert = true
    }

    private func spinWheel() {
        // Reset state
        selectedRecipe = nil
        selectedCuisine = ""
        isSpinning = true
        hasSpun = true

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // Define cuisines - must match the wheel segments
        let cuisines = ["Italian 🍝", "Mexican 🌮", "Chinese 🥟", "Japanese 🍱",
                        "Thai 🍜", "Indian 🍛", "French 🥐", "American 🍔"]
        
        // Randomly select which cuisine to land on
        let targetCuisineIndex = Int.random(in: 0..<cuisines.count)
        let targetCuisine = cuisines[targetCuisineIndex]
        
        // Calculate the angle needed to land on this cuisine
        // The wheel starts with Italian at the top (90 degrees)
        // The pointer is on the right (0 degrees)
        // Each segment is 45 degrees (360/8)
        let segmentAngle = 360.0 / Double(cuisines.count)
        
        // Calculate target angle: we want the selected segment to align with the pointer (right side)
        // Since Italian starts at top (90°) and goes clockwise:
        // Italian: 90° to 45°, Mexican: 45° to 0°, Chinese: 0° to -45° (315°), etc.
        let targetSegmentStartAngle = 90.0 - (Double(targetCuisineIndex) * segmentAngle)
        
        // We want the middle of the segment to align with the pointer
        let targetAngle = targetSegmentStartAngle - (segmentAngle / 2.0)
        
        // Add multiple rotations for visual effect
        let minRotations = Double.random(in: 5...7)
        let totalRotation = (minRotations * 360) - targetAngle
        
        // Ensure we're rotating forward
        finalRotation = wheelRotation + totalRotation
        
        let spinDuration = Double.random(in: 3.0...4.0)

        // Spin animation with realistic deceleration
        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: spinDuration)) {
            wheelRotation = finalRotation
        }

        // Set the selected cuisine after spin completes
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            selectedCuisine = targetCuisine
            
            // Generate a recipe for the selected cuisine
            generateRecipeForCuisine(targetCuisine)
        }
    }
    
    private func generateRecipeForCuisine(_ cuisine: String) {
        // Haptic feedback for landing
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        Task {
            // Show generating state briefly
            isGenerating = true
            
            // Simulate API call with appropriate cuisine
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            await MainActor.run {
                // Create a recipe based on the selected cuisine
                let cuisineType = cuisine.components(separatedBy: " ").first ?? "Mystery"
                let recipe = createRecipeForCuisine(cuisineType)
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    selectedRecipe = recipe
                    showConfetti = true
                    isSpinning = false
                    isGenerating = false
                }
                
                // Scroll to recipe card
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        scrollProxy?.scrollTo("recipeCard", anchor: .top)
                    }
                }
            }
        }
    }
    
    private func createRecipeForCuisine(_ cuisineType: String) -> Recipe {
        // Create appropriate recipes based on cuisine type
        switch cuisineType {
        case "Italian":
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: ["Classic Spaghetti Carbonara", "Margherita Pizza", "Osso Buco", "Risotto Milanese"].randomElement()!,
                description: "Authentic Italian dish with traditional flavors",
                ingredients: [Ingredient(id: UUID(), name: "Pasta", quantity: "400g", unit: nil, isAvailable: true)],
                instructions: ["Prepare ingredients", "Cook with love", "Serve hot"],
                cookTime: 25, prepTime: 15, servings: 4,
                difficulty: .medium,
                nutrition: Nutrition(calories: 450, protein: 20, carbs: 55, fat: 15, fiber: 3, sugar: 5, sodium: 680),
                imageURL: nil, createdAt: Date(),
                tags: ["italian", "pasta", "classic"],
                dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false),
                isDetectiveRecipe: false,
                cookingTechniques: [],
                flavorProfile: nil,
                secretIngredients: [],
                proTips: [],
                visualClues: [],
                shareCaption: ""
            )
        case "Mexican":
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: ["Tacos al Pastor", "Enchiladas Verdes", "Pozole", "Mole Poblano"].randomElement()!,
                description: "Vibrant Mexican cuisine with bold spices",
                ingredients: [Ingredient(id: UUID(), name: "Tortillas", quantity: "8", unit: nil, isAvailable: true)],
                instructions: ["Prepare ingredients", "Cook with passion", "Garnish and serve"],
                cookTime: 30, prepTime: 20, servings: 4,
                difficulty: .medium,
                nutrition: Nutrition(calories: 380, protein: 25, carbs: 40, fat: 12, fiber: 8, sugar: 4, sodium: 720),
                imageURL: nil, createdAt: Date(),
                tags: ["mexican", "spicy", "authentic"],
                dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: true, isDairyFree: false),
                isDetectiveRecipe: false,
                cookingTechniques: [],
                flavorProfile: nil,
                secretIngredients: [],
                proTips: [],
                visualClues: [],
                shareCaption: ""
            )
        case "Chinese":
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: ["Kung Pao Chicken", "Mapo Tofu", "Beijing Duck", "Dim Sum Platter"].randomElement()!,
                description: "Traditional Chinese dish with complex flavors",
                ingredients: [Ingredient(id: UUID(), name: "Soy Sauce", quantity: "3 tbsp", unit: nil, isAvailable: true)],
                instructions: ["Prep ingredients", "Stir-fry on high heat", "Season and serve"],
                cookTime: 20, prepTime: 25, servings: 4,
                difficulty: .hard,
                nutrition: Nutrition(calories: 420, protein: 28, carbs: 35, fat: 18, fiber: 4, sugar: 8, sodium: 890),
                imageURL: nil, createdAt: Date(),
                tags: ["chinese", "wok", "savory"],
                dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: true),
                isDetectiveRecipe: false,
                cookingTechniques: [],
                flavorProfile: nil,
                secretIngredients: [],
                proTips: [],
                visualClues: [],
                shareCaption: ""
            )
        case "Japanese":
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: ["Salmon Teriyaki", "Ramen Bowl", "Sushi Platter", "Tempura Vegetables"].randomElement()!,
                description: "Delicate Japanese cuisine with umami flavors",
                ingredients: [Ingredient(id: UUID(), name: "Mirin", quantity: "2 tbsp", unit: nil, isAvailable: true)],
                instructions: ["Prepare with precision", "Cook gently", "Present beautifully"],
                cookTime: 25, prepTime: 30, servings: 2,
                difficulty: .hard,
                nutrition: Nutrition(calories: 350, protein: 30, carbs: 40, fat: 8, fiber: 2, sugar: 10, sodium: 780),
                imageURL: nil, createdAt: Date(),
                tags: ["japanese", "umami", "fresh"],
                dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: true),
                isDetectiveRecipe: false,
                cookingTechniques: [],
                flavorProfile: nil,
                secretIngredients: [],
                proTips: [],
                visualClues: [],
                shareCaption: ""
            )
        case "Thai":
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: ["Pad Thai", "Green Curry", "Tom Yum Soup", "Mango Sticky Rice"].randomElement()!,
                description: "Aromatic Thai dish with perfect balance of flavors",
                ingredients: [Ingredient(id: UUID(), name: "Fish Sauce", quantity: "2 tbsp", unit: nil, isAvailable: true)],
                instructions: ["Prepare aromatics", "Cook with high heat", "Balance flavors"],
                cookTime: 20, prepTime: 20, servings: 3,
                difficulty: .medium,
                nutrition: Nutrition(calories: 400, protein: 22, carbs: 45, fat: 14, fiber: 5, sugar: 12, sodium: 650),
                imageURL: nil, createdAt: Date(),
                tags: ["thai", "spicy", "aromatic"],
                dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: true, isDairyFree: true),
                isDetectiveRecipe: false,
                cookingTechniques: [],
                flavorProfile: nil,
                secretIngredients: [],
                proTips: [],
                visualClues: [],
                shareCaption: ""
            )
        case "Indian":
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: ["Butter Chicken", "Palak Paneer", "Biryani", "Tikka Masala"].randomElement()!,
                description: "Rich Indian cuisine with aromatic spices",
                ingredients: [Ingredient(id: UUID(), name: "Garam Masala", quantity: "1 tbsp", unit: nil, isAvailable: true)],
                instructions: ["Toast spices", "Simmer slowly", "Garnish with cilantro"],
                cookTime: 40, prepTime: 25, servings: 4,
                difficulty: .medium,
                nutrition: Nutrition(calories: 480, protein: 24, carbs: 50, fat: 20, fiber: 6, sugar: 8, sodium: 720),
                imageURL: nil, createdAt: Date(),
                tags: ["indian", "curry", "spiced"],
                dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: true, isDairyFree: false),
                isDetectiveRecipe: false,
                cookingTechniques: [],
                flavorProfile: nil,
                secretIngredients: [],
                proTips: [],
                visualClues: [],
                shareCaption: ""
            )
        case "French":
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: ["Coq au Vin", "Ratatouille", "Croque Monsieur", "Bouillabaisse"].randomElement()!,
                description: "Elegant French cuisine with refined techniques",
                ingredients: [Ingredient(id: UUID(), name: "Butter", quantity: "4 tbsp", unit: nil, isAvailable: true)],
                instructions: ["Prepare mise en place", "Cook with technique", "Plate elegantly"],
                cookTime: 45, prepTime: 30, servings: 4,
                difficulty: .hard,
                nutrition: Nutrition(calories: 520, protein: 28, carbs: 35, fat: 28, fiber: 3, sugar: 6, sodium: 680),
                imageURL: nil, createdAt: Date(),
                tags: ["french", "classic", "elegant"],
                dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false),
                isDetectiveRecipe: false,
                cookingTechniques: [],
                flavorProfile: nil,
                secretIngredients: [],
                proTips: [],
                visualClues: [],
                shareCaption: ""
            )
        case "American":
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: ["BBQ Ribs", "Mac and Cheese", "Buffalo Wings", "Chili Con Carne"].randomElement()!,
                description: "Hearty American comfort food",
                ingredients: [Ingredient(id: UUID(), name: "BBQ Sauce", quantity: "1 cup", unit: nil, isAvailable: true)],
                instructions: ["Season generously", "Cook low and slow", "Serve with sides"],
                cookTime: 60, prepTime: 20, servings: 6,
                difficulty: .easy,
                nutrition: Nutrition(calories: 580, protein: 32, carbs: 45, fat: 28, fiber: 4, sugar: 15, sodium: 980),
                imageURL: nil, createdAt: Date(),
                tags: ["american", "bbq", "comfort"],
                dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false),
                isDetectiveRecipe: false,
                cookingTechniques: [],
                flavorProfile: nil,
                secretIngredients: [],
                proTips: [],
                visualClues: [],
                shareCaption: ""
            )
        default:
            return MockDataProvider.shared.mockRecipeResponse().recipes?.first ?? Recipe(
                id: UUID(),
                ownerID: nil,
                name: "Mystery Surprise",
                description: "A delightful culinary adventure",
                ingredients: [],
                instructions: [],
                cookTime: 30, prepTime: 20, servings: 4,
                difficulty: .medium,
                nutrition: Nutrition(calories: 400, protein: 20, carbs: 45, fat: 15, fiber: 5, sugar: 8, sodium: 700),
                imageURL: nil, createdAt: Date(),
                tags: ["mystery"],
                dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false),
                isDetectiveRecipe: false,
                cookingTechniques: [],
                flavorProfile: nil,
                secretIngredients: [],
                proTips: [],
                visualClues: [],
                shareCaption: ""
            )
        }
    }

    private func generateMysteryMeal() {
        isGenerating = true
        showConfetti = true

        Task {
            // Simulate API call
            try await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds

            // Generate mystery recipes based on surprise level
            let mockRecipes = generateSurpriseRecipes()

            await MainActor.run {
                generatedRecipes = mockRecipes

                // Save recipes to app state
                for recipe in mockRecipes {
                    appState.addRecentRecipe(recipe)
                    appState.saveRecipeWithPhotos(recipe, beforePhoto: nil, afterPhoto: nil)
                }

                showingResults = true
                isGenerating = false
            }
        }
    }

    private func generateSurpriseRecipes() -> [Recipe] {
        // This would call the API with special surprise parameters
        var recipes = MockDataProvider.shared.mockRecipeResponse().recipes ?? []

        // Add surprise elements based on level
        switch surpriseLevel {
        case .mild:
            // Small twists
            recipes = recipes.map { recipe in
                Recipe(
                    id: recipe.id,
                    ownerID: recipe.ownerID,
                    name: recipe.name + " with a Twist",
                    description: recipe.description,
                    ingredients: recipe.ingredients,
                    instructions: recipe.instructions,
                    cookTime: recipe.cookTime,
                    prepTime: recipe.prepTime,
                    servings: recipe.servings,
                    difficulty: recipe.difficulty,
                    nutrition: recipe.nutrition,
                    imageURL: recipe.imageURL,
                    createdAt: recipe.createdAt,
                    tags: recipe.tags,
                    dietaryInfo: recipe.dietaryInfo,
                    isDetectiveRecipe: false,
                    cookingTechniques: recipe.cookingTechniques,
                    flavorProfile: recipe.flavorProfile,
                    secretIngredients: recipe.secretIngredients,
                    proTips: recipe.proTips,
                    visualClues: recipe.visualClues,
                    shareCaption: recipe.shareCaption
                )
            }
        case .medium:
            // Fusion elements
            recipes = recipes.map { recipe in
                Recipe(
                    id: recipe.id,
                    ownerID: recipe.ownerID,
                    name: "Fusion " + recipe.name,
                    description: recipe.description,
                    ingredients: recipe.ingredients,
                    instructions: recipe.instructions,
                    cookTime: recipe.cookTime,
                    prepTime: recipe.prepTime,
                    servings: recipe.servings,
                    difficulty: recipe.difficulty,
                    nutrition: recipe.nutrition,
                    imageURL: recipe.imageURL,
                    createdAt: recipe.createdAt,
                    tags: recipe.tags,
                    dietaryInfo: recipe.dietaryInfo,
                    isDetectiveRecipe: false,
                    cookingTechniques: recipe.cookingTechniques,
                    flavorProfile: recipe.flavorProfile,
                    secretIngredients: recipe.secretIngredients,
                    proTips: recipe.proTips,
                    visualClues: recipe.visualClues,
                    shareCaption: recipe.shareCaption
                )
            }
        case .wild:
            // Unexpected combinations
            recipes = recipes.map { recipe in
                Recipe(
                    id: recipe.id,
                    ownerID: recipe.ownerID,
                    name: "Wild " + recipe.name + " Adventure",
                    description: recipe.description,
                    ingredients: recipe.ingredients,
                    instructions: recipe.instructions,
                    cookTime: recipe.cookTime,
                    prepTime: recipe.prepTime,
                    servings: recipe.servings,
                    difficulty: recipe.difficulty,
                    nutrition: recipe.nutrition,
                    imageURL: recipe.imageURL,
                    createdAt: recipe.createdAt,
                    tags: recipe.tags,
                    dietaryInfo: recipe.dietaryInfo,
                    isDetectiveRecipe: false,
                    cookingTechniques: recipe.cookingTechniques,
                    flavorProfile: recipe.flavorProfile,
                    secretIngredients: recipe.secretIngredients,
                    proTips: recipe.proTips,
                    visualClues: recipe.visualClues,
                    shareCaption: recipe.shareCaption
                )
            }
        case .insane:
            // Complete chaos
            recipes = recipes.map { recipe in
                Recipe(
                    id: recipe.id,
                    ownerID: recipe.ownerID,
                    name: "Insane " + recipe.name + " Experiment",
                    description: recipe.description,
                    ingredients: recipe.ingredients,
                    instructions: recipe.instructions,
                    cookTime: recipe.cookTime,
                    prepTime: recipe.prepTime,
                    servings: recipe.servings,
                    difficulty: recipe.difficulty,
                    nutrition: recipe.nutrition,
                    imageURL: recipe.imageURL,
                    createdAt: recipe.createdAt,
                    tags: recipe.tags,
                    dietaryInfo: recipe.dietaryInfo,
                    isDetectiveRecipe: false,
                    cookingTechniques: recipe.cookingTechniques,
                    flavorProfile: recipe.flavorProfile,
                    secretIngredients: recipe.secretIngredients,
                    proTips: recipe.proTips,
                    visualClues: recipe.visualClues,
                    shareCaption: recipe.shareCaption
                )
            }
        }

        return recipes
    }
}

// MARK: - Mystery Meal Header
struct MysteryMealHeaderView: View {
    @State private var sparkleAnimation = false

    var body: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                // Sparkles
                ForEach(0..<6) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "#f093fb"))
                        .offset(
                            x: cos(Double(index) * .pi / 3) * 50,
                            y: sin(Double(index) * .pi / 3) * 50
                        )
                        .rotationEffect(.degrees(sparkleAnimation ? 360 : 0))
                        .opacity(sparkleAnimation ? 0.8 : 0.3)
                }

                Text("🎰")
                    .font(.system(size: 80))
            }

            Text("Mystery Meal Roulette")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("Let fate decide your next culinary adventure!")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    sparkleAnimation = true
                }
            }
        }
    }
}

// MARK: - Fortune Wheel
struct FortuneWheelView: View {
    @Binding var rotation: Double
    let onSpin: () -> Void
    let cuisines = ["Italian 🍝", "Mexican 🌮", "Chinese 🥟", "Japanese 🍱",
                    "Thai 🍜", "Indian 🍛", "French 🥐", "American 🍔"]
    @State private var isHovering = false
    @State private var glowAnimation = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#667eea").opacity(0.3),
                                Color(hex: "#764ba2").opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: geometry.size.width * 0.4,
                            endRadius: geometry.size.width * 0.7
                        )
                    )
                    .blur(radius: 20)
                    .scaleEffect(glowAnimation ? 1.1 : 0.9)
                
                // Rotating wheel with outer ring
                ZStack {
                    // Outer decorative ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2"),
                                    Color(hex: "#f093fb")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 10)
                    
                    // Inner shadow ring
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.black.opacity(0.0),
                                    Color.black.opacity(0.1)
                                ],
                                center: .center,
                                startRadius: geometry.size.width * 0.35,
                                endRadius: geometry.size.width * 0.5
                            )
                        )
                    
                    // Wheel segments
                    ForEach(cuisines.indices, id: \.self) { index in
                        WheelSegment(
                            startAngle: Double(index) * 360 / Double(cuisines.count),
                            endAngle: Double(index + 1) * 360 / Double(cuisines.count),
                            text: cuisines[index],
                            color: segmentColor(for: index)
                        )
                    }

                    // Center hub with enhanced design
                    ZStack {
                        // Outer ring of center button
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color(hex: "#f5f5f5")
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 90, height: 90)
                            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                        
                        // Inner button
                        Button(action: onSpin) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: isHovering ? [
                                                Color(hex: "#f093fb"),
                                                Color(hex: "#f5576c")
                                            ] : [
                                                Color(hex: "#667eea"),
                                                Color(hex: "#764ba2")
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                VStack(spacing: 2) {
                                    Image(systemName: "dice")
                                        .font(.system(size: 24, weight: .bold))
                                    Text("SPIN")
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(isHovering ? 1.1 : 1.0)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.3)) {
                                isHovering = hovering
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width * 0.95, height: geometry.size.width * 0.95)
                .rotationEffect(.degrees(rotation))

                // Premium pointer design
                HStack {
                    Spacer()
                    
                    ZStack {
                        // Pointer glow
                        Triangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#ff6b6b").opacity(0.6),
                                        Color(hex: "#ff6b6b").opacity(0.2)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 50, height: 40)
                            .blur(radius: 8)
                            .rotationEffect(.degrees(-90))
                        
                        // Main pointer
                        Triangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#ff6b6b"),
                                        Color(hex: "#ef5350")
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 45, height: 35)
                            .rotationEffect(.degrees(-90))
                            .overlay(
                                Triangle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 45, height: 35)
                                    .rotationEffect(.degrees(-90))
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 5, y: 2)
                    }
                    .offset(x: 15) // Positioned to point at wheel edge
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            }
        }
    }

    private func segmentColor(for index: Int) -> Color {
        let colors = [
            Color(hex: "#667eea"),
            Color(hex: "#764ba2"),
            Color(hex: "#f093fb"),
            Color(hex: "#f5576c"),
            Color(hex: "#4facfe"),
            Color(hex: "#00f2fe"),
            Color(hex: "#43e97b"),
            Color(hex: "#38f9d7")
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Wheel Segment
struct WheelSegment: View {
    let startAngle: Double
    let endAngle: Double
    let text: String
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main segment with gradient
                Path { path in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let radius = min(geometry.size.width, geometry.size.height) / 2

                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(startAngle - 90),
                        endAngle: .degrees(endAngle - 90),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            color,
                            color.opacity(0.8)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
                
                // Inner highlight
                Path { path in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let radius = min(geometry.size.width, geometry.size.height) / 2

                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius * 0.95,
                        startAngle: .degrees(startAngle - 90),
                        endAngle: .degrees(endAngle - 90),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: geometry.size.width * 0.4
                    )
                )
                
                // Segment border
                Path { path in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let radius = min(geometry.size.width, geometry.size.height) / 2

                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(startAngle - 90),
                        endAngle: .degrees(endAngle - 90),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )

                // Enhanced text positioning
                let midAngle = (startAngle + endAngle) / 2
                let angleInRadians = (midAngle - 90) * .pi / 180
                let textRadius = geometry.size.width * 0.32
                let xOffset = cos(angleInRadians) * textRadius
                let yOffset = sin(angleInRadians) * textRadius

                VStack(spacing: 2) {
                    // Extract emoji and text
                    let components = text.components(separatedBy: " ")
                    if components.count > 1 {
                        Text(components[1]) // Emoji
                            .font(.system(size: 24))
                        Text(components[0]) // Cuisine name
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Text(text)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 1, y: 1)
                .rotationEffect(.degrees(midAngle))  // Rotate text to align with segment
                .position(
                    x: geometry.size.width / 2 + xOffset,
                    y: geometry.size.height / 2 + yOffset
                )
            }
        }
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Mystery Recipe Card
struct MysteryRecipeCard: View {
    let recipe: Recipe
    let onSave: () -> Void
    @State private var showingDetail = false
    @State private var appearAnimation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Cuisine badge
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                Text("MYSTERY MEAL SPECIAL")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
            }
            .foregroundColor(Color(hex: "#ffd700"))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(hex: "#ffd700").opacity(0.2))
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "#ffd700").opacity(0.5), lineWidth: 1)
                    )
            )
            
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.95)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .lineLimit(2)

                    Text(recipe.description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }

                Spacer()

                // Save button with animation
                Button(action: onSave) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#ff6b6b"),
                                        Color(hex: "#ef5350")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color(hex: "#ff6b6b").opacity(0.4), radius: 8, y: 4)
                }
                .scaleEffect(appearAnimation ? 1.0 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3), value: appearAnimation)
            }

            // Recipe info
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("\(recipe.prepTime) min")
                }
                HStack(spacing: 4) {
                    Image(systemName: "flame")
                    Text("\(recipe.cookTime) min")
                }
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar")
                    Text(recipe.difficulty.rawValue.capitalized)
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.8))

            // Ingredients preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Ingredients")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Text(recipe.ingredients.prefix(3).map { $0.name }.joined(separator: ", ") + (recipe.ingredients.count > 3 ? "..." : ""))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }

            // View full recipe button
            Button(action: { showingDetail = true }) {
                HStack {
                    Text("View Full Recipe")
                        .font(.system(size: 16, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
        .sheet(isPresented: $showingDetail) {
            RecipeDetailView(recipe: recipe)
        }
        .onAppear {
            withAnimation {
                appearAnimation = true
            }
        }
    }
}

// MARK: - Ingredient Hints Card
struct IngredientHintsCard: View {
    @Binding var selectedIngredients: [String]
    @State private var ingredientText = ""

    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#ffa726"))

                    Text("Ingredient Hints (Optional)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Text("Add ingredients you'd like to include")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                // Ingredient input
                HStack {
                    TextField("e.g., chicken, tomatoes...", text: $ingredientText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .onSubmit {
                            addIngredient()
                        }

                    Button(action: addIngredient) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#43e97b"))
                    }
                    .disabled(ingredientText.isEmpty)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )

                // Selected ingredients
                if !selectedIngredients.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedIngredients, id: \.self) { ingredient in
                                IngredientChip(
                                    ingredient: ingredient,
                                    onRemove: {
                                        selectedIngredients.removeAll { $0 == ingredient }
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func addIngredient() {
        guard !ingredientText.isEmpty else { return }
        selectedIngredients.append(ingredientText)
        ingredientText = ""
    }
}

// MARK: - Ingredient Chip
struct IngredientChip: View {
    let ingredient: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(ingredient)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(hex: "#667eea").opacity(0.3))
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "#667eea"), lineWidth: 1)
                )
        )
    }
}

// MARK: - Surprise Level Selector
struct SurpriseLevelSelector: View {
    @Binding var selectedLevel: SurpriseRecipeSettings.WildnessLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Your Adventure Level")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                ForEach(SurpriseRecipeSettings.WildnessLevel.allCases, id: \.self) { level in
                    SurpriseLevelButton(
                        level: level,
                        isSelected: selectedLevel == level,
                        action: { selectedLevel = level }
                    )
                }
            }
        }
    }
}

// MARK: - Surprise Level Button
struct SurpriseLevelButton: View {
    let level: SurpriseRecipeSettings.WildnessLevel
    let isSelected: Bool
    let action: () -> Void

    var emoji: String {
        switch level {
        case .mild: return "😊"
        case .medium: return "😎"
        case .wild: return "🤪"
        case .insane: return "🤯"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 30))

                Text(level.rawValue.split(separator: " ").first ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? level.color
                            : Color.white.opacity(0.2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.clear : Color.white.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Spin Wheel Button
struct SpinWheelButton: View {
    let action: () -> Void
    let isSpinning: Bool
    @State private var pulseAnimation = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "dice")
                    .font(.system(size: 24, weight: .semibold))

                Text(isSpinning ? "Spinning..." : "Spin the Wheel!")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "#f093fb"),
                        Color(hex: "#f5576c")
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(
                color: Color(hex: "#f093fb").opacity(0.5),
                radius: pulseAnimation ? 30 : 20,
                y: 10
            )
            .scaleEffect(pulseAnimation ? 1.05 : 1)
            .disabled(isSpinning)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
    }
}

// MARK: - Mystery Generating View
struct MysteryGeneratingView: View {
    @State private var chefRotation = 0.0
    @State private var messageIndex = 0

    let messages = [
        "Consulting the culinary cosmos...",
        "Mixing unexpected flavors...",
        "Adding a dash of chaos...",
        "Channeling your inner chef...",
        "Creating something magical..."
    ]

    var body: some View {
        VStack(spacing: 40) {
            // Animated chef hat
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#f093fb").opacity(0.6 - Double(index) * 0.2),
                                    Color(hex: "#f5576c").opacity(0.4 - Double(index) * 0.1),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 3
                        )
                        .frame(
                            width: CGFloat(100 + index * 40),
                            height: CGFloat(100 + index * 40)
                        )
                        .rotationEffect(.degrees(chefRotation + Double(index * 60)))
                }

                Text("👨‍🍳")
                    .font(.system(size: 60))
                    .rotationEffect(.degrees(-chefRotation / 2))
            }

            // Messages
            Text(messages[messageIndex])
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
                .id(messageIndex)
        }
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    chefRotation = 360
                }
                
                Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                    Task { @MainActor in
                        withAnimation {
                            messageIndex = (messageIndex + 1) % messages.count
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    MysteryMealView()
}
