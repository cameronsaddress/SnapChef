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
        
        // Calculate the angle needed to land on this cuisine
        // The wheel starts with Italian at the top (90 degrees)
        // The pointer is on the right (0 degrees in SwiftUI coordinate system)
        // Each segment is 45 degrees (360/8)
        let segmentAngle = 360.0 / Double(cuisines.count)
        
        // Calculate target angle: we want the selected segment to align with the pointer (right side)
        // Segments start at 0° (right) and go clockwise
        // First segment (Italian, index 0): 0° to 45°
        // Second segment (Mexican, index 1): 45° to 90°
        // The pointer is at 0° (right side), so to align segment with pointer:
        let segmentStartAngle = Double(targetCuisineIndex) * segmentAngle
        let segmentMidAngle = segmentStartAngle + (segmentAngle / 2.0)
        
        // We need to rotate the wheel so the segment's middle aligns with 0° (pointer position)
        // If segment is at angle X, we rotate by -X to bring it to 0°
        let targetAngle = -segmentMidAngle
        
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
            // Calculate which cuisine is actually at the pointer position
            // Normalize the final rotation angle to 0-360 range
            var normalizedAngle = finalRotation.truncatingRemainder(dividingBy: 360)
            while normalizedAngle < 0 {
                normalizedAngle += 360
            }
            
            // The wheel has rotated by normalizedAngle degrees
            // The pointer is at 0° (right side)
            // We need to find which segment is now at 0°
            // Since the wheel rotated clockwise by normalizedAngle,
            // the segment that was at normalizedAngle is now at 0°
            let segmentAtPointer = normalizedAngle / segmentAngle
            let actualCuisineIndex = Int(segmentAtPointer.rounded()) % cuisines.count
            
            selectedCuisine = cuisines[actualCuisineIndex]
            
            // Generate a recipe for the actual selected cuisine
            generateRecipeForCuisine(cuisines[actualCuisineIndex])
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
            let recipeName = ["Classic Spaghetti Carbonara", "Margherita Pizza", "Osso Buco", "Risotto Milanese"].randomElement()!
            let ingredients: [Ingredient]
            
            switch recipeName {
            case "Classic Spaghetti Carbonara":
                ingredients = [
                    Ingredient(id: UUID(), name: "Spaghetti pasta", quantity: "400g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Pancetta or guanciale", quantity: "200g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Eggs", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Pecorino Romano cheese", quantity: "100g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Black pepper", quantity: "2 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Salt", quantity: "to taste", unit: nil, isAvailable: true)
                ]
            case "Margherita Pizza":
                ingredients = [
                    Ingredient(id: UUID(), name: "Pizza dough", quantity: "500g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "San Marzano tomatoes", quantity: "400g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Fresh mozzarella", quantity: "250g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Fresh basil", quantity: "1 bunch", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Extra virgin olive oil", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Salt", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "2 cloves", unit: nil, isAvailable: true)
                ]
            case "Osso Buco":
                ingredients = [
                    Ingredient(id: UUID(), name: "Veal shanks", quantity: "4 pieces", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "All-purpose flour", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Carrots", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Celery", quantity: "2 stalks", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Onion", quantity: "1 large", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "White wine", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Beef broth", quantity: "2 cups", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Crushed tomatoes", quantity: "400g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bay leaves", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Fresh thyme", quantity: "2 sprigs", unit: nil, isAvailable: true)
                ]
            default: // Risotto Milanese
                ingredients = [
                    Ingredient(id: UUID(), name: "Arborio rice", quantity: "320g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Saffron", quantity: "1 pinch", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Beef bone marrow", quantity: "50g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Onion", quantity: "1 small", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "White wine", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Beef broth", quantity: "1.5 liters", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Parmesan cheese", quantity: "100g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Butter", quantity: "80g", unit: nil, isAvailable: true)
                ]
            }
            
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: recipeName,
                description: "Authentic Italian dish with traditional flavors",
                ingredients: ingredients,
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
            let recipeName = ["Tacos al Pastor", "Enchiladas Verdes", "Pozole", "Mole Poblano"].randomElement()!
            let ingredients: [Ingredient]
            
            switch recipeName {
            case "Tacos al Pastor":
                ingredients = [
                    Ingredient(id: UUID(), name: "Pork shoulder", quantity: "1 kg", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Corn tortillas", quantity: "12", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Pineapple", quantity: "1/2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Dried guajillo chilies", quantity: "3", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Achiote paste", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Orange juice", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "White vinegar", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Onion", quantity: "1", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cilantro", quantity: "1 bunch", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Lime", quantity: "4", unit: nil, isAvailable: true)
                ]
            case "Enchiladas Verdes":
                ingredients = [
                    Ingredient(id: UUID(), name: "Corn tortillas", quantity: "12", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Chicken breast", quantity: "500g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tomatillos", quantity: "500g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Serrano chilies", quantity: "3", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "3 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "White onion", quantity: "1", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cilantro", quantity: "1/2 bunch", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Mexican crema", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Queso fresco", quantity: "200g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Chicken broth", quantity: "1 cup", unit: nil, isAvailable: true)
                ]
            case "Pozole":
                ingredients = [
                    Ingredient(id: UUID(), name: "Pork shoulder", quantity: "1 kg", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Hominy", quantity: "2 cans", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Dried guajillo chilies", quantity: "6", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Dried ancho chilies", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "6 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Onion", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bay leaves", quantity: "3", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Oregano", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cabbage", quantity: "1/4 head", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Radishes", quantity: "1 bunch", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Lime", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tostadas", quantity: "8", unit: nil, isAvailable: true)
                ]
            default: // Mole Poblano
                ingredients = [
                    Ingredient(id: UUID(), name: "Chicken", quantity: "1 whole", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Dried mulato chilies", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Dried ancho chilies", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Dried pasilla chilies", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Dark chocolate", quantity: "50g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Raisins", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sesame seeds", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Pumpkin seeds", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cinnamon stick", quantity: "1", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Black pepper", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cloves", quantity: "3", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tomatoes", quantity: "3", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Plantain", quantity: "1/2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bread slice", quantity: "1", unit: nil, isAvailable: true)
                ]
            }
            
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: recipeName,
                description: "Vibrant Mexican cuisine with bold spices",
                ingredients: ingredients,
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
            let recipeName = ["Kung Pao Chicken", "Mapo Tofu", "Beijing Duck", "Dim Sum Platter"].randomElement()!
            let ingredients: [Ingredient]
            
            switch recipeName {
            case "Kung Pao Chicken":
                ingredients = [
                    Ingredient(id: UUID(), name: "Chicken breast", quantity: "500g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Peanuts", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Dried red chilies", quantity: "10", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sichuan peppercorns", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Soy sauce", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Rice vinegar", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sugar", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cornstarch", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "3 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ginger", quantity: "1 inch", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Green onions", quantity: "3", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sesame oil", quantity: "1 tsp", unit: nil, isAvailable: true)
                ]
            case "Mapo Tofu":
                ingredients = [
                    Ingredient(id: UUID(), name: "Silken tofu", quantity: "400g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ground pork", quantity: "200g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Doubanjiang (chili bean paste)", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sichuan peppercorns", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Soy sauce", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Chicken stock", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cornstarch", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "4 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ginger", quantity: "1 inch", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Green onions", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sesame oil", quantity: "1 tsp", unit: nil, isAvailable: true)
                ]
            case "Beijing Duck":
                ingredients = [
                    Ingredient(id: UUID(), name: "Whole duck", quantity: "1 (2kg)", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Honey", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Rice wine", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Soy sauce", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Five-spice powder", quantity: "2 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ginger", quantity: "2 inches", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Star anise", quantity: "3", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Mandarin pancakes", quantity: "20", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cucumber", quantity: "1", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Green onions", quantity: "6", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Hoisin sauce", quantity: "1/2 cup", unit: nil, isAvailable: true)
                ]
            default: // Dim Sum Platter
                ingredients = [
                    Ingredient(id: UUID(), name: "Shrimp", quantity: "300g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ground pork", quantity: "300g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Wonton wrappers", quantity: "30", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Dumpling wrappers", quantity: "30", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Water chestnuts", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bamboo shoots", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Shiitake mushrooms", quantity: "6", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Soy sauce", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sesame oil", quantity: "2 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ginger", quantity: "1 inch", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Green onions", quantity: "3", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cornstarch", quantity: "2 tbsp", unit: nil, isAvailable: true)
                ]
            }
            
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: recipeName,
                description: "Traditional Chinese dish with complex flavors",
                ingredients: ingredients,
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
            let recipeName = ["Salmon Teriyaki", "Ramen Bowl", "Sushi Platter", "Tempura Vegetables"].randomElement()!
            let ingredients: [Ingredient]
            
            switch recipeName {
            case "Salmon Teriyaki":
                ingredients = [
                    Ingredient(id: UUID(), name: "Salmon fillets", quantity: "4 pieces", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Soy sauce", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Mirin", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sake", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sugar", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ginger", quantity: "1 inch", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "2 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sesame seeds", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Green onions", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Vegetable oil", quantity: "1 tbsp", unit: nil, isAvailable: true)
                ]
            case "Ramen Bowl":
                ingredients = [
                    Ingredient(id: UUID(), name: "Ramen noodles", quantity: "400g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Pork belly", quantity: "500g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Chicken broth", quantity: "2 liters", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Soy sauce", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Miso paste", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Eggs", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Nori sheets", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Green onions", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bamboo shoots", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Corn", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "4 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ginger", quantity: "2 inches", unit: nil, isAvailable: true)
                ]
            case "Sushi Platter":
                ingredients = [
                    Ingredient(id: UUID(), name: "Sushi rice", quantity: "3 cups", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Rice vinegar", quantity: "1/3 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sugar", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Salt", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Nori sheets", quantity: "10", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Salmon (sushi grade)", quantity: "200g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tuna (sushi grade)", quantity: "200g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cucumber", quantity: "1", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Avocado", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Wasabi", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Pickled ginger", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Soy sauce", quantity: "1/2 cup", unit: nil, isAvailable: true)
                ]
            default: // Tempura Vegetables
                ingredients = [
                    Ingredient(id: UUID(), name: "All-purpose flour", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cornstarch", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ice water", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Egg", quantity: "1", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sweet potato", quantity: "1 large", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Eggplant", quantity: "1", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bell peppers", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Broccoli", quantity: "1 head", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Mushrooms", quantity: "200g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Vegetable oil", quantity: "4 cups", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Soy sauce", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Mirin", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Grated daikon", quantity: "1/2 cup", unit: nil, isAvailable: true)
                ]
            }
            
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: recipeName,
                description: "Delicate Japanese cuisine with umami flavors",
                ingredients: ingredients,
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
            let recipeName = ["Pad Thai", "Green Curry", "Tom Yum Soup", "Mango Sticky Rice"].randomElement()!
            let ingredients: [Ingredient]
            
            switch recipeName {
            case "Pad Thai":
                ingredients = [
                    Ingredient(id: UUID(), name: "Rice noodles", quantity: "250g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Shrimp", quantity: "200g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tofu", quantity: "200g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Eggs", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bean sprouts", quantity: "2 cups", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Fish sauce", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tamarind paste", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Palm sugar", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Lime", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Peanuts", quantity: "1/3 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Green onions", quantity: "3", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "3 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Thai chili", quantity: "2", unit: nil, isAvailable: true)
                ]
            case "Green Curry":
                ingredients = [
                    Ingredient(id: UUID(), name: "Chicken thighs", quantity: "500g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Green curry paste", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Coconut milk", quantity: "400ml", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Thai eggplant", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bamboo shoots", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Thai basil", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Fish sauce", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Palm sugar", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Kaffir lime leaves", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Thai chilies", quantity: "3", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Chicken stock", quantity: "1/2 cup", unit: nil, isAvailable: true)
                ]
            case "Tom Yum Soup":
                ingredients = [
                    Ingredient(id: UUID(), name: "Shrimp", quantity: "300g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Lemongrass", quantity: "3 stalks", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Galangal", quantity: "2 inches", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Kaffir lime leaves", quantity: "6", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Thai chilies", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Mushrooms", quantity: "200g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tomatoes", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Fish sauce", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Lime juice", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Chili paste", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cilantro", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Chicken stock", quantity: "4 cups", unit: nil, isAvailable: true)
                ]
            default: // Mango Sticky Rice
                ingredients = [
                    Ingredient(id: UUID(), name: "Glutinous rice", quantity: "2 cups", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ripe mangoes", quantity: "3", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Coconut milk", quantity: "400ml", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sugar", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Salt", quantity: "1/2 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cornstarch", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sesame seeds", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Pandan leaves", quantity: "2", unit: nil, isAvailable: true)
                ]
            }
            
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: recipeName,
                description: "Aromatic Thai dish with perfect balance of flavors",
                ingredients: ingredients,
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
            let recipeName = ["Butter Chicken", "Palak Paneer", "Biryani", "Tikka Masala"].randomElement()!
            let ingredients: [Ingredient]
            
            switch recipeName {
            case "Butter Chicken":
                ingredients = [
                    Ingredient(id: UUID(), name: "Chicken breast", quantity: "750g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Yogurt", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Heavy cream", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tomato puree", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Butter", quantity: "4 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garam masala", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Turmeric", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Chili powder", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ginger garlic paste", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Kasuri methi", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Onion", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cashews", quantity: "1/4 cup", unit: nil, isAvailable: true)
                ]
            case "Palak Paneer":
                ingredients = [
                    Ingredient(id: UUID(), name: "Paneer", quantity: "400g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Spinach", quantity: "500g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Onion", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tomatoes", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Heavy cream", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ginger", quantity: "1 inch", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "4 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Green chilies", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garam masala", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cumin seeds", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Butter", quantity: "2 tbsp", unit: nil, isAvailable: true)
                ]
            case "Biryani":
                ingredients = [
                    Ingredient(id: UUID(), name: "Basmati rice", quantity: "2 cups", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Chicken or mutton", quantity: "500g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Yogurt", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Onions", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Saffron", quantity: "1/4 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Milk", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ghee", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Biryani masala", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ginger garlic paste", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Mint leaves", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cilantro", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bay leaves", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cinnamon stick", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cardamom", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cloves", quantity: "4", unit: nil, isAvailable: true)
                ]
            default: // Tikka Masala
                ingredients = [
                    Ingredient(id: UUID(), name: "Chicken breast", quantity: "600g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Yogurt", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Heavy cream", quantity: "3/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tomato sauce", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garam masala", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Paprika", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Turmeric", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cumin", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ginger", quantity: "2 inches", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "6 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Onion", quantity: "1 large", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Butter", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cilantro", quantity: "1/4 cup", unit: nil, isAvailable: true)
                ]
            }
            
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: recipeName,
                description: "Rich Indian cuisine with aromatic spices",
                ingredients: ingredients,
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
            let recipeName = ["Coq au Vin", "Ratatouille", "Croque Monsieur", "Bouillabaisse"].randomElement()!
            let ingredients: [Ingredient]
            
            switch recipeName {
            case "Coq au Vin":
                ingredients = [
                    Ingredient(id: UUID(), name: "Chicken pieces", quantity: "1.5 kg", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Red wine", quantity: "750ml", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bacon", quantity: "150g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Pearl onions", quantity: "12", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Mushrooms", quantity: "250g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Carrots", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "4 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tomato paste", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Chicken stock", quantity: "2 cups", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Brandy", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Butter", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Flour", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bay leaves", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Fresh thyme", quantity: "4 sprigs", unit: nil, isAvailable: true)
                ]
            case "Ratatouille":
                ingredients = [
                    Ingredient(id: UUID(), name: "Eggplant", quantity: "1 large", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Zucchini", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bell peppers", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tomatoes", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Onion", quantity: "1", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "3 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tomato paste", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Olive oil", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Fresh basil", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Fresh thyme", quantity: "2 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bay leaf", quantity: "1", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Salt and pepper", quantity: "to taste", unit: nil, isAvailable: true)
                ]
            case "Croque Monsieur":
                ingredients = [
                    Ingredient(id: UUID(), name: "White bread", quantity: "8 slices", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Ham", quantity: "8 slices", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Gruyère cheese", quantity: "200g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Butter", quantity: "4 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Flour", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Milk", quantity: "1.5 cups", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Dijon mustard", quantity: "2 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Nutmeg", quantity: "1/4 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Salt and pepper", quantity: "to taste", unit: nil, isAvailable: true)
                ]
            default: // Bouillabaisse
                ingredients = [
                    Ingredient(id: UUID(), name: "Mixed fish", quantity: "1.5 kg", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Shellfish", quantity: "500g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Fennel bulb", quantity: "1", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Leeks", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tomatoes", quantity: "4", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Onion", quantity: "1", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "4 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Saffron", quantity: "1/4 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Orange zest", quantity: "1 strip", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Fish stock", quantity: "2 liters", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "White wine", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Olive oil", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bay leaves", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Fresh thyme", quantity: "2 sprigs", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Parsley", quantity: "1/4 cup", unit: nil, isAvailable: true)
                ]
            }
            
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: recipeName,
                description: "Elegant French cuisine with refined techniques",
                ingredients: ingredients,
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
            let recipeName = ["BBQ Ribs", "Mac and Cheese", "Buffalo Wings", "Chili Con Carne"].randomElement()!
            let ingredients: [Ingredient]
            
            switch recipeName {
            case "BBQ Ribs":
                ingredients = [
                    Ingredient(id: UUID(), name: "Pork ribs", quantity: "2 racks", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "BBQ sauce", quantity: "2 cups", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Brown sugar", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Paprika", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic powder", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Onion powder", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Chili powder", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cumin", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Black pepper", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Salt", quantity: "2 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Apple cider vinegar", quantity: "1/4 cup", unit: nil, isAvailable: true)
                ]
            case "Mac and Cheese":
                ingredients = [
                    Ingredient(id: UUID(), name: "Elbow macaroni", quantity: "1 lb", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Sharp cheddar", quantity: "300g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Gruyère cheese", quantity: "200g", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Butter", quantity: "6 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Flour", quantity: "1/4 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Milk", quantity: "3 cups", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Heavy cream", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Mustard powder", quantity: "1 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cayenne pepper", quantity: "1/4 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Breadcrumbs", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Salt and pepper", quantity: "to taste", unit: nil, isAvailable: true)
                ]
            case "Buffalo Wings":
                ingredients = [
                    Ingredient(id: UUID(), name: "Chicken wings", quantity: "2 lbs", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Hot sauce", quantity: "1/2 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Butter", quantity: "1/3 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "White vinegar", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Worcestershire sauce", quantity: "1/2 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cayenne pepper", quantity: "1/2 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic powder", quantity: "1/2 tsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Vegetable oil", quantity: "for frying", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Celery sticks", quantity: "for serving", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Blue cheese dressing", quantity: "for serving", unit: nil, isAvailable: true)
                ]
            default: // Chili Con Carne
                ingredients = [
                    Ingredient(id: UUID(), name: "Ground beef", quantity: "1 kg", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Kidney beans", quantity: "2 cans", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Crushed tomatoes", quantity: "2 cans", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Onions", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Bell peppers", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Garlic", quantity: "4 cloves", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Jalapeños", quantity: "2", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Chili powder", quantity: "3 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Cumin", quantity: "2 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Paprika", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Oregano", quantity: "1 tbsp", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Beer", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Beef broth", quantity: "1 cup", unit: nil, isAvailable: true),
                    Ingredient(id: UUID(), name: "Tomato paste", quantity: "2 tbsp", unit: nil, isAvailable: true)
                ]
            }
            
            return Recipe(
                id: UUID(),
                ownerID: nil,
                name: recipeName,
                description: "Hearty American comfort food",
                ingredients: ingredients,
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
                // Triangle removed - selection happens after spin completes
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

// Triangle shape removed - no longer needed

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
