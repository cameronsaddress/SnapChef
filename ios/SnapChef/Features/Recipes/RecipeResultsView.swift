import SwiftUI

struct RecipeResultsView: View {
    let recipes: [Recipe]
    let ingredients: [IngredientAPI]
    let capturedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    @State private var selectedRecipe: Recipe?
    @State private var showShareSheet = false
    @State private var showShareGenerator = false
    @State private var showSocialShare = false
    @State private var generatedShareImage: UIImage?
    @State private var confettiTrigger = false
    @State private var contentVisible = false
    @State private var activeSheet: ActiveSheet?
    
    enum ActiveSheet: Identifiable {
        case recipeDetail(Recipe)
        case shareGenerator(Recipe)
        case fridgeInventory
        
        var id: String {
            switch self {
            case .recipeDetail(let recipe): return "detail_\(recipe.id)"
            case .shareGenerator(let recipe): return "share_\(recipe.id)"
            case .fridgeInventory: return "fridge_inventory"
            }
        }
    }
    
    init(recipes: [Recipe], ingredients: [IngredientAPI] = [], capturedImage: UIImage? = nil) {
        self.recipes = recipes
        self.ingredients = ingredients
        self.capturedImage = capturedImage
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Success header
                        SuccessHeaderView()
                            .staggeredFade(index: 0, isShowing: contentVisible)
                        
                        // In Your Fridge card
                        if !ingredients.isEmpty {
                            FridgeInventoryCard(
                                ingredientCount: ingredients.count,
                                onTap: {
                                    activeSheet = .fridgeInventory
                                }
                            )
                            .staggeredFade(index: 1, isShowing: contentVisible)
                        }
                        
                        // Recipe cards
                        ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                            MagicalRecipeCard(
                                recipe: recipe,
                                onSelect: {
                                    activeSheet = .recipeDetail(recipe)
                                    confettiTrigger = true
                                },
                                onShare: {
                                    activeSheet = .shareGenerator(recipe)
                                }
                            )
                            .staggeredFade(index: index + (ingredients.isEmpty ? 1 : 2), isShowing: contentVisible)
                        }
                        
                        // Viral share prompt
                        ViralSharePrompt(action: {
                            if let firstRecipe = recipes.first {
                                activeSheet = .shareGenerator(firstRecipe)
                            }
                        })
                        .staggeredFade(index: recipes.count + (ingredients.isEmpty ? 1 : 2), isShowing: contentVisible)
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                
                // Confetti effect
                if confettiTrigger {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.2)))
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Your Recipes")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentVisible = true
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .recipeDetail(let recipe):
                RecipeDetailView(recipe: recipe)
            case .shareGenerator(let recipe):
                ShareGeneratorView(
                    recipe: recipe,
                    ingredientsPhoto: capturedImage
                )
            case .fridgeInventory:
                SimpleFridgeInventoryView(
                    ingredients: ingredients,
                    capturedImage: capturedImage
                )
            }
        }
        .sheet(isPresented: $showSocialShare) {
            if let recipe = selectedRecipe ?? recipes.first,
               let shareImage = generatedShareImage {
                // TODO: SocialShareView was moved to archive
                ShareSheet(items: [
                    shareImage,
                    "Just turned my fridge into \(recipe.name)! 🔥"
                ])
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let recipe = recipes.first {
                EnhancedShareSheet(recipe: recipe)
            }
        }
    }
}

// MARK: - Success Header
struct SuccessHeaderView: View {
    var body: some View {
        VStack(spacing: 20) {
            
            Text("Recipe Magic Complete!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#43e97b"),
                            Color(hex: "#38f9d7")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("We found \(3) delicious recipes")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.top, 40)
    }
}

// MARK: - Magical Recipe Card
struct MagicalRecipeCard: View {
    let recipe: Recipe
    let onSelect: () -> Void
    let onShare: () -> Void
    
    @State private var isHovered = false
    @State private var shimmerPhase: CGFloat = -1
    
    var body: some View {
        GlassmorphicCard(content: {
            VStack(alignment: .leading, spacing: 20) {
                // Header with image
                HStack(spacing: 20) {
                    // Recipe image placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#667eea"),
                                        Color(hex: "#764ba2")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Text(recipe.difficulty.emoji)
                            .font(.system(size: 40))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        HStack(spacing: 16) {
                            TimeIndicator(minutes: recipe.prepTime + recipe.cookTime)
                            CalorieIndicator(calories: recipe.nutrition.calories)
                        }
                        
                        DifficultyBadge(difficulty: recipe.difficulty)
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect()
                }
                
                // Description
                Text(recipe.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect()
                    }
                
                // Action buttons
                HStack(spacing: 12) {
                    ActionButton(
                        title: "Cook Now",
                        icon: "flame.fill",
                        color: Color(hex: "#f093fb"),
                        action: onSelect
                    )
                    
                    ActionButton(
                        title: "Share",
                        icon: "square.and.arrow.up",
                        color: Color(hex: "#4facfe"),
                        action: onShare
                    )
                }
            }
            .padding(24)
        }, glowColor: Color(hex: "#667eea"))
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Time Indicator
struct TimeIndicator: View {
    let minutes: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 14, weight: .semibold))
            Text("\(minutes)m")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(Color(hex: "#4facfe"))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "#4facfe").opacity(0.2))
        )
    }
}

// MARK: - Calorie Indicator
struct CalorieIndicator: View {
    let calories: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame")
                .font(.system(size: 14, weight: .semibold))
            Text("\(calories)")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(Color(hex: "#f093fb"))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "#f093fb").opacity(0.2))
        )
    }
}

// MARK: - Difficulty Badge
struct DifficultyBadge: View {
    let difficulty: Recipe.Difficulty
    
    var difficultyColor: Color {
        switch difficulty {
        case .easy: return Color(hex: "#43e97b")
        case .medium: return Color(hex: "#ffa726")
        case .hard: return Color(hex: "#ef5350")
        }
    }
    
    var body: some View {
        Text(difficulty.rawValue.capitalized)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(difficultyColor)
            )
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
            )
        }
    }
}

// MARK: - Viral Share Prompt
struct ViralSharePrompt: View {
    let action: () -> Void
    @State private var glowAnimation = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎉 Amazing recipes!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Share your culinary journey and inspire others")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            MagneticButton(
                title: "Share & Earn Credits",
                icon: "sparkles",
                action: action
            )
            .shadow(
                color: Color(hex: "#667eea").opacity(glowAnimation ? 0.8 : 0.4),
                radius: glowAnimation ? 30 : 20
            )
        }
        .padding(30)
        .background(
            GlassmorphicCard(content: {
                Color.clear
            }, glowColor: Color(hex: "#f093fb"))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
}

// MARK: - Share Floating Button
struct ShareFloatingButton: View {
    let action: () -> Void
    @State private var bounceAnimation = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Ripple effect
                Circle()
                    .stroke(Color(hex: "#f093fb").opacity(0.3), lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .scaleEffect(bounceAnimation ? 1.3 : 1)
                    .opacity(bounceAnimation ? 0 : 1)
                
                // Button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#f093fb"),
                                Color(hex: "#f5576c")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color(hex: "#f093fb").opacity(0.5), radius: 15, y: 5)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                withAnimation(.easeOut(duration: 1)) {
                    bounceAnimation = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    bounceAnimation = false
                }
            }
        }
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        Canvas { context, size in
            for piece in confettiPieces {
                context.fill(
                    RoundedRectangle(cornerRadius: 2)
                        .path(in: CGRect(
                            x: piece.position.x,
                            y: piece.position.y,
                            width: piece.size.width,
                            height: piece.size.height
                        )),
                    with: .color(piece.color)
                )
            }
        }
        .onAppear {
            createConfetti()
        }
    }
    
    private func createConfetti() {
        let colors: [Color] = [
            Color(hex: "#667eea"),
            Color(hex: "#764ba2"),
            Color(hex: "#f093fb"),
            Color(hex: "#4facfe"),
            Color(hex: "#43e97b"),
            Color(hex: "#ffa726")
        ]
        
        confettiPieces = (0..<100).map { _ in
            ConfettiPiece(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: -20
                ),
                velocity: CGVector(
                    dx: CGFloat.random(in: -100...100),
                    dy: CGFloat.random(in: 200...400)
                ),
                size: CGSize(
                    width: CGFloat.random(in: 5...10),
                    height: CGFloat.random(in: 10...20)
                ),
                color: colors.randomElement()!,
                rotation: CGFloat.random(in: 0...360)
            )
        }
        
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            updateConfetti()
            
            if confettiPieces.isEmpty {
                timer.invalidate()
            }
        }
    }
    
    private func updateConfetti() {
        confettiPieces = confettiPieces.compactMap { piece in
            var updated = piece
            updated.position.x += updated.velocity.dx * 0.016
            updated.position.y += updated.velocity.dy * 0.016
            updated.velocity.dy += 500 * 0.016 // Gravity
            updated.rotation += 5
            
            return updated.position.y < UIScreen.main.bounds.height + 50 ? updated : nil
        }
    }
}

struct ConfettiPiece {
    var position: CGPoint
    var velocity: CGVector
    var size: CGSize
    var color: Color
    var rotation: CGFloat
}

// MARK: - Fridge Inventory Card
struct FridgeInventoryCard: View {
    let ingredientCount: Int
    let onTap: () -> Void
    
    @State private var sparkleAnimation = false
    @State private var bounceAnimation = false
    
    var body: some View {
        GlassmorphicCard(content: {
            VStack(spacing: 20) {
                // Icon and title
                HStack(spacing: 20) {
                    // Fridge icon with animation
                    ZStack {
                        // Background gradient circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#38f9d7"),
                                        Color(hex: "#43e97b")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .scaleEffect(bounceAnimation ? 1.1 : 1)
                        
                        // Fridge icon
                        Image(systemName: "refrigerator.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                        
                        // Sparkles around
                        ForEach(0..<3) { index in
                            Image(systemName: "sparkle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#ffa726"))
                                .offset(x: 40, y: 0)
                                .rotationEffect(.degrees(sparkleAnimation ? 360 : 0))
                                .rotationEffect(.degrees(Double(index) * 120))
                                .scaleEffect(sparkleAnimation ? 1.2 : 0.8)
                                .opacity(sparkleAnimation ? 1 : 0.6)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("In Your Fridge")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("\(ingredientCount) ingredients detected")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 14))
                            Text("See what we found")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "#38f9d7"))
                    }
                    
                    Spacer()
                    
                    // Arrow indicator
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color(hex: "#38f9d7"))
                        .scaleEffect(bounceAnimation ? 1.2 : 1)
                }
                
                // Fun message
                Text("🎉 We analyzed your fridge like magic!")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }, glowColor: Color(hex: "#38f9d7"))
        .onTapGesture {
            onTap()
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                sparkleAnimation = true
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                bounceAnimation = true
            }
        }
    }
}

// MARK: - Simple Fridge Inventory View
struct SimpleFridgeInventoryView: View {
    let ingredients: [IngredientAPI]
    let capturedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "refrigerator.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#38f9d7"),
                                            Color(hex: "#43e97b")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Found \(ingredients.count) ingredients!")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 40)
                        
                        // Ingredients list
                        ForEach(ingredients, id: \.name) { ingredient in
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(ingredient.name)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("\(ingredient.quantity) \(ingredient.unit)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    HStack(spacing: 12) {
                                        Label(ingredient.category, systemImage: "tag.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "#38f9d7"))
                                        
                                        Label(ingredient.freshness, systemImage: "leaf.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(freshnessColor(for: ingredient.freshness))
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                }
            }
    }
    
    private func freshnessColor(for freshness: String) -> Color {
        switch freshness.lowercased() {
        case "fresh": return Color(hex: "#43e97b")
        case "good": return Color(hex: "#38f9d7")
        case "use soon": return Color(hex: "#ffa726")
        default: return Color.gray
        }
    }
}

#Preview {
    RecipeResultsView(recipes: MockDataProvider.shared.mockRecipeResponse().recipes ?? [])
}