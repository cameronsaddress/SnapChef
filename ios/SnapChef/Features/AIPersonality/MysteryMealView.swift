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
                            
                            // Selected cuisine label
                            if !selectedCuisine.isEmpty {
                                Text("You got: \(selectedCuisine)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .transition(.opacity.combined(with: .scale))
                            }
                            
                            // Spin button - only show if not spinning and no recipe selected
                            if !isSpinning && selectedRecipe == nil {
                                SpinWheelButton(
                                    action: spinWheel,
                                    isSpinning: false
                                )
                                .padding(.horizontal, 40)
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
                } else {
                    // Generating view
                    MysteryGeneratingView()
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
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        // Random spin parameters
        let minRotations = Double.random(in: 3...5)
        let randomEndAngle = Double.random(in: 0...360)
        let totalRotation = (minRotations * 360) + randomEndAngle
        let spinDuration = Double.random(in: 2.5...4.0)
        
        // Spin animation with easing
        withAnimation(.easeOut(duration: spinDuration)) {
            wheelRotation += totalRotation
        }
        
        // Determine selected cuisine after spin
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            // Calculate which segment the wheel landed on
            let cuisines = ["Italian 🍝", "Mexican 🌮", "Chinese 🥟", "Japanese 🍱", 
                            "Thai 🍜", "Indian 🍛", "French 🥐", "American 🍔"]
            let segmentAngle = 360.0 / Double(cuisines.count)
            
            // The triangle points to the right (0 degrees)
            // We need to find which segment is at the right side after rotation
            let normalizedAngle = wheelRotation.truncatingRemainder(dividingBy: 360)
            let adjustedAngle = normalizedAngle < 0 ? normalizedAngle + 360 : normalizedAngle
            
            // Since the wheel rotates and triangle is fixed at right (0 degrees),
            // we need to find which segment is now at position 0
            let selectedIndex = Int(adjustedAngle / segmentAngle) % cuisines.count
            
            selectedCuisine = cuisines[selectedIndex]
            
            // Get a random recipe for the selected cuisine
            if let recipe = LocalRecipeDatabase.shared.getRandomRecipe(for: selectedCuisine) {
                withAnimation {
                    selectedRecipe = recipe
                    showConfetti = true
                    isSpinning = false
                }
                
                // Scroll to recipe card after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        scrollProxy?.scrollTo("recipeCard", anchor: .top)
                    }
                }
            } else {
                isSpinning = false
            }
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
                    createdAt: recipe.createdAt
                )
            }
        case .medium:
            // Fusion elements
            recipes = recipes.map { recipe in
                Recipe(
                    id: recipe.id,
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
                    createdAt: recipe.createdAt
                )
            }
        case .wild:
            // Unexpected combinations
            recipes = recipes.map { recipe in
                Recipe(
                    id: recipe.id,
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
                    createdAt: recipe.createdAt
                )
            }
        case .insane:
            // Complete chaos
            recipes = recipes.map { recipe in
                Recipe(
                    id: recipe.id,
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
                    createdAt: recipe.createdAt
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
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                sparkleAnimation = true
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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Rotating wheel
                ZStack {
                    // Wheel segments
                    ForEach(cuisines.indices, id: \.self) { index in
                        WheelSegment(
                            startAngle: Double(index) * 360 / Double(cuisines.count),
                            endAngle: Double(index + 1) * 360 / Double(cuisines.count),
                            text: cuisines[index],
                            color: segmentColor(for: index)
                        )
                    }
                    
                    // Center circle button
                    Button(action: onSpin) {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.8)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text("SPIN")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#667eea"))
                            )
                            .shadow(radius: 10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(width: geometry.size.width, height: geometry.size.width)
                .rotationEffect(.degrees(rotation))
                
                // Stationary pointer on the right - positioned to slightly overlap
                HStack {
                    Spacer()
                    Triangle()
                        .fill(Color(hex: "#ef5350"))
                        .frame(width: 40, height: 30)
                        .rotationEffect(.degrees(-90))
                        .shadow(radius: 5)
                        .offset(x: 25) // Positioned so the point barely overlaps the wheel
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
                // Segment shape
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
                .fill(color)
                .overlay(
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
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                
                // Text - positioned at the middle of the segment
                let midAngle = (startAngle + endAngle) / 2
                let angleInRadians = (midAngle - 90) * .pi / 180
                let xOffset = cos(angleInRadians) * geometry.size.width * 0.32
                let yOffset = sin(angleInRadians) * geometry.size.height * 0.32
                
                Text(text)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(recipe.description)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Save button
                Button(action: onSave) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color(hex: "#ff6b6b"))
                        )
                }
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
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
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
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                chefRotation = 360
            }
            
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                withAnimation {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
    }
}

#Preview {
    MysteryMealView()
}