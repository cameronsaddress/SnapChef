import SwiftUI

struct EnhancedHomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showingCamera = false
    @State private var showingMysteryMeal = false
    @State private var particleTrigger = false
    @State private var mysteryMealAnimation = false
    @State private var showingUpgrade = false
    @StateObject private var fallingFoodManager = FallingFoodManager()
    @State private var buttonShake = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Full screen animated background
                MagicalBackground()
                    .ignoresSafeArea()
                
                // Falling food emojis (behind all elements except background)
                ForEach(fallingFoodManager.emojis) { emoji in
                    Text(emoji.emoji)
                        .font(.system(size: 30))
                        .opacity(0.5)  // 50% translucent
                        .position(x: emoji.position.x, y: emoji.position.y)
                }
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Animated Logo
                        HeroLogoView()
                        
                        // Main CTA Section with prominent spacing
                        VStack(spacing: 0) {
                            // Equal spacing above button
                            Spacer()
                                .frame(height: 50)
                            
                            MagneticButton(
                                title: "Snap Your Fridge",
                                icon: "camera.fill",
                                action: {
                                    showingCamera = true
                                    particleTrigger = true
                                }
                            )
                            .padding(.horizontal, 30)
                            .modifier(ShakeEffect(shakeNumber: buttonShake ? 2 : 0))
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            updateButtonFrames(geometry.frame(in: .global))
                                        }
                                }
                            )
                            
                            // Equal spacing below button
                            Spacer()
                                .frame(height: 50)
                            
                            if !deviceManager.hasUnlimitedAccess {
                                Button(action: { showingUpgrade = true }) {
                                    FreeUsesIndicatorEnhanced(remaining: deviceManager.freeUsesRemaining)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal, 30)
                                .padding(.top, 20)  // Add more space above
                                .padding(.bottom, 15)
                            }
                        }
                        
                        // Mystery Meal Button
                        MysteryMealButton(
                            isAnimating: $mysteryMealAnimation,
                            action: {
                                showingMysteryMeal = true
                                particleTrigger = true
                            }
                        )
                        .padding(.horizontal, 30)
                        
                        // Viral Section
                        ViralChallengeSection()
                        
                        // Recent Recipes
                        if !appState.recentRecipes.isEmpty {
                            EnhancedRecipesSection(recipes: appState.recentRecipes)
                        }
                    }
                    .padding(.bottom, 120)
                }
                .scrollContentBackground(.hidden)
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton(icon: "sparkles") {
                            // AI suggestions
                        }
                        .padding(30)
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)
            .particleExplosion(trigger: $particleTrigger)
        }
        .onAppear {
            // Simple fade in for mystery meal animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    mysteryMealAnimation = true
                }
            }
            
            // Start button shake after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                startButtonShake()
            }
            
            // Start falling food animation
            fallingFoodManager.startFallingFood()
        }
        .fullScreenCover(isPresented: $showingCamera) {
            EnhancedCameraView()
        }
        .fullScreenCover(isPresented: $showingMysteryMeal) {
            MysteryMealView()
        }
        .fullScreenCover(isPresented: $showingUpgrade) {
            SubscriptionView()
                .environmentObject(deviceManager)
        }
    }
    
    private func startButtonShake() {
        // Subtle shake effect
        withAnimation(.default) {
            buttonShake = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            buttonShake = false
            
            // Repeat every 8-12 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 8...12)) {
                startButtonShake()
            }
        }
    }
    
    private func updateButtonFrames(_ frame: CGRect) {
        fallingFoodManager.updateButtonFrames([frame])
    }
}

// MARK: - Hero Logo
struct HeroLogoView: View {
    @State private var textGlow: Double = 0
    @State private var emojiShimmer: Double = 0
    @State private var showGlow = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Main text in white with larger size
                Text("SnapChef")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.white.opacity(showGlow ? 0.8 : 0), radius: showGlow ? 20 : 0)
                    .shadow(color: Color(hex: "#667eea").opacity(showGlow ? 0.6 : 0), radius: showGlow ? 30 : 0)
                    .animation(.easeInOut(duration: 0.8), value: showGlow)
                
                // Sparkle emoji with shimmer effect
                ZStack {
                    // Background sparkles
                    ForEach(0..<3) { index in
                        Text("✨")
                            .font(.system(size: 48))
                            .offset(x: 140, y: -25)
                            .opacity(emojiShimmer)
                            .scaleEffect(1 + CGFloat(index) * 0.3)
                            .blur(radius: CGFloat(index) * 2)
                    }
                    
                    // Main sparkle
                    Text("✨")
                        .font(.system(size: 48))
                        .offset(x: 140, y: -25)
                }
            }
            
            Text("AI-powered recipes from what you already have")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 30)
        .onAppear {
            // One-time glow effect on load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    showGlow = true
                    emojiShimmer = 0.5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showGlow = false
                        emojiShimmer = 0.1
                    }
                }
            }
        }
    }
}

// MARK: - Free Uses Indicator Enhanced
struct FreeUsesIndicatorEnhanced: View {
    let remaining: Int
    @State private var pulseScale: CGFloat = 1
    @State private var showGlow = false
    
    var body: some View {
        GlassmorphicCard(content: {
            HStack(spacing: 12) {
                // Animated icon
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
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulseScale)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(remaining) free snaps remaining")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Upgrade for unlimited magic")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        })
        .shadow(color: Color(hex: "#43e97b").opacity(showGlow ? 0.6 : 0), radius: showGlow ? 20 : 0)
        .shadow(color: Color.white.opacity(showGlow ? 0.4 : 0), radius: showGlow ? 15 : 0)
        .animation(.easeInOut(duration: 0.8), value: showGlow)
        .onAppear {
            // Quick glow animation on appear
            withAnimation(.easeIn(duration: 0.3)) {
                showGlow = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showGlow = false
                }
            }
            // Subtle single pulse on appear
            withAnimation(.easeInOut(duration: 0.8)) {
                pulseScale = 1.05
            }
        }
    }
}


// MARK: - Viral Challenge Section
struct ViralChallengeSection: View {
    @State private var currentChallenge = 0
    let challenges = [
        ("🌮", "Taco Tuesday", "Transform leftovers into tacos"),
        ("🍕", "Pizza Party", "Create pizza with pantry items"),
        ("🥗", "Salad Spectacular", "Make amazing salads")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Today's Challenge")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            ZStack(alignment: .bottom) {
                TabView(selection: $currentChallenge) {
                    ForEach(0..<challenges.count, id: \.self) { index in
                        HomeChallengeCard(
                            emoji: challenges[index].0,
                            title: challenges[index].1,
                            description: challenges[index].2
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 220)
                
                // Custom page indicator below the card
                HStack(spacing: 8) {
                    ForEach(0..<challenges.count, id: \.self) { index in
                        Circle()
                            .fill(currentChallenge == index ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentChallenge == index ? 1.2 : 1)
                            .animation(.spring(response: 0.3), value: currentChallenge)
                    }
                }
                .padding(.bottom, -25)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct HomeChallengeCard: View {
    let emoji: String
    let title: String
    let description: String
    @State private var isPressed = false
    
    var body: some View {
        GlassmorphicCard(content: {
            VStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 50))
                
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                MagneticButton(title: "Join Challenge", icon: "arrow.right", action: {})
                    .scaleEffect(0.9)
            }
            .padding(30)
        }, glowColor: Color(hex: "#f093fb"))
        .padding(.horizontal, 10)
    }
}

// MARK: - Enhanced Recipes Section
struct EnhancedRecipesSection: View {
    let recipes: [Recipe]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Recent Magic")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {}) {
                    Text("See All")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#667eea"))
                }
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(recipes) { recipe in
                        EnhancedRecipeCard(recipe: recipe)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct EnhancedRecipeCard: View {
    let recipe: Recipe
    @State private var isPressed = false
    
    var body: some View {
        GlassmorphicCard(content: {
            VStack(alignment: .leading, spacing: 12) {
                // Recipe image placeholder with gradient
                RoundedRectangle(cornerRadius: 12)
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
                    .frame(height: 120)
                    .overlay(
                        Text(recipe.difficulty.emoji)
                            .font(.system(size: 40))
                    )
                
                Text(recipe.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack {
                    Label("\(recipe.cookTime)m", systemImage: "clock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Label("\(recipe.nutrition.calories)", systemImage: "flame")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(16)
            .frame(width: 220)
        })
        .scaleEffect(isPressed ? 0.95 : 1)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
}

// MARK: - Mystery Meal Button
struct MysteryMealButton: View {
    @Binding var isAnimating: Bool
    let action: () -> Void
    @State private var diceRotation = 0.0
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Animated dice icon
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#f093fb").opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .scaleEffect(isAnimating ? 1.2 : 1)
                    
                    Text("🎲")
                        .font(.system(size: 36))
                        .rotationEffect(.degrees(diceRotation))
                        .scaleEffect(isAnimating ? 1.1 : 1)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mystery Meal")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#f093fb"),
                                    Color(hex: "#f5576c")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Surprise me!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "#f093fb"))
                    .offset(x: isAnimating ? 5 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#f093fb").opacity(0.5),
                                        Color(hex: "#f5576c").opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .shadow(
                color: Color(hex: "#f093fb").opacity(0.3),
                radius: isAnimating ? 20 : 10,
                y: isAnimating ? 10 : 5
            )
            .scaleEffect(isPressed ? 0.95 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            // Single rotation on appear
            withAnimation(.easeInOut(duration: 1.2)) {
                diceRotation = 360
            }
        }
    }
}

// MARK: - Shake Effect
struct ShakeEffect: AnimatableModifier {
    var shakeNumber: CGFloat = 0
    
    var animatableData: CGFloat {
        get { shakeNumber }
        set { shakeNumber = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .offset(x: sin(shakeNumber * .pi * 2) * 5)
    }
}

// MARK: - Falling Food Manager
class FallingFoodManager: ObservableObject {
    @Published var emojis: [FallingFoodEmoji] = []
    private let foodEmojis = ["🍕", "🍔", "🌮", "🍜", "🍝", "🥗", "🍣", "🥘", "🍛", "🥙", "🍱", "🥪", "🌯", "🍖", "🍗", "🥓", "🧀", "🥚", "🍳", "🥞"]
    private var buttonFrames: [CGRect] = []
    
    struct FallingFoodEmoji: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        let emoji: String
        var hasBouncedOffButton = false
    }
    
    func updateButtonFrames(_ frames: [CGRect]) {
        buttonFrames = frames
    }
    
    func startFallingFood() {
        // Start physics update
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            self.updatePhysics()
        }
        
        // Start dropping food emojis with random delays
        scheduleNextEmoji()
    }
    
    private func scheduleNextEmoji() {
        // Random delay between 0.5-3 seconds, ensuring minimum 0.5s spacing
        let delay = Double.random(in: 0.5...3)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.dropEmoji()
            self.scheduleNextEmoji() // Schedule the next one
        }
    }
    
    private func dropEmoji() {
        let screenWidth = UIScreen.main.bounds.width
        
        // Always drop only 1 emoji
        let x = CGFloat.random(in: 50...screenWidth - 50)
        
        let emoji = FallingFoodEmoji(
            position: CGPoint(
                x: x,
                y: CGFloat.random(in: -50 ... -30) // Slight variation in start height
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -30...30), // Wider horizontal variation
                dy: CGFloat.random(in: 80...120) // More variation in fall speed
            ),
            emoji: foodEmojis.randomElement() ?? "🍕",
            hasBouncedOffButton: false
        )
        
        emojis.append(emoji)
    }
    
    private func updatePhysics() {
        let deltaTime = 0.016
        let gravity: Double = 400
        let screenHeight = UIScreen.main.bounds.height
        let bounceDamping: Double = 0.5
        
        for i in emojis.indices {
            // Apply gravity
            emojis[i].velocity.dy += gravity * deltaTime
            
            // Update position
            emojis[i].position.x += emojis[i].velocity.dx * deltaTime
            emojis[i].position.y += emojis[i].velocity.dy * deltaTime
            
            // Check collision with buttons (only if hasn't bounced yet)
            if !emojis[i].hasBouncedOffButton {
                for buttonFrame in buttonFrames {
                    if isCollidingWithButton(emoji: emojis[i], buttonFrame: buttonFrame) {
                        // Bounce off button
                        emojis[i].velocity.dy = -abs(emojis[i].velocity.dy) * bounceDamping
                        emojis[i].velocity.dx += CGFloat.random(in: -40...40)
                        
                        // Move emoji to top of button
                        emojis[i].position.y = buttonFrame.minY - 15
                        
                        // Mark as having bounced
                        emojis[i].hasBouncedOffButton = true
                        break
                    }
                }
            }
        }
        
        // Remove emojis that have fallen off screen
        emojis.removeAll { emoji in
            emoji.position.y > screenHeight + 50
        }
    }
    
    private func isCollidingWithButton(emoji: FallingFoodEmoji, buttonFrame: CGRect) -> Bool {
        // Check if emoji is within horizontal bounds of button
        let emojiLeft = emoji.position.x - 15
        let emojiRight = emoji.position.x + 15
        
        if emojiLeft < buttonFrame.maxX && emojiRight > buttonFrame.minX {
            // Check if emoji bottom is touching button top
            let emojiBottom = emoji.position.y + 15
            return emojiBottom >= buttonFrame.minY && emojiBottom <= buttonFrame.minY + 20 && emoji.velocity.dy > 0
        }
        return false
    }
}

#Preview {
    EnhancedHomeView()
        .environmentObject(AppState())
        .environmentObject(DeviceManager())
}