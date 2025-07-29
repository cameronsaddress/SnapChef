import SwiftUI

struct EnhancedRecipeResultsView: View {
    let recipes: [Recipe]
    let capturedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    @State private var selectedRecipe: Recipe?
    @State private var showShareSheet = false
    @State private var showShareGenerator = false
    @State private var showSocialShare = false
    @State private var generatedShareImage: UIImage?
    @State private var confettiTrigger = false
    @State private var contentVisible = false
    
    init(recipes: [Recipe], capturedImage: UIImage? = nil) {
        self.recipes = recipes
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
                        
                        // Recipe cards
                        ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                            MagicalRecipeCard(
                                recipe: recipe,
                                onSelect: {
                                    selectedRecipe = recipe
                                    confettiTrigger = true
                                },
                                onShare: {
                                    selectedRecipe = recipe
                                    showShareGenerator = true
                                }
                            )
                            .staggeredFade(index: index + 1, isShowing: contentVisible)
                        }
                        
                        // Viral share prompt
                        ViralSharePrompt(action: {
                            showShareGenerator = true
                        })
                        .staggeredFade(index: recipes.count + 1, isShowing: contentVisible)
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                
                // Floating share button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ShareFloatingButton {
                            showShareGenerator = true
                        }
                        .padding(30)
                    }
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
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .sheet(isPresented: $showShareGenerator) {
            if let recipe = selectedRecipe ?? recipes.first {
                ShareGeneratorView(
                    recipe: recipe,
                    ingredientsPhoto: capturedImage
                )
            }
        }
        .sheet(isPresented: $showSocialShare) {
            if let recipe = selectedRecipe ?? recipes.first,
               let shareImage = generatedShareImage {
                SocialShareView(
                    image: shareImage,
                    text: "Just turned my fridge into \(recipe.name)! 🔥",
                    recipe: recipe
                )
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
    @State private var sparkleRotation: Double = 0
    @State private var pulseScale: CGFloat = 1
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#43e97b").opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)
                
                // Success icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#43e97b"),
                                    Color(hex: "#38f9d7")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Sparkles
                ForEach(0..<4) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "#43e97b"))
                        .offset(x: 60, y: 0)
                        .rotationEffect(.degrees(sparkleRotation + Double(index) * 90))
                }
            }
            
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
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
        }
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
        Button(action: onSelect) {
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
                    
                    // Description
                    Text(recipe.description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                    
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
        }
        .buttonStyle(PlainButtonStyle())
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

#Preview {
    EnhancedRecipeResultsView(recipes: MockDataProvider.shared.mockRecipeResponse().recipes ?? [])
}