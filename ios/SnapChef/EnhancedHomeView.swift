import SwiftUI

struct EnhancedHomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showingCamera = false
    @State private var showingMysteryMeal = false
    @State private var particleTrigger = false
    @State private var mysteryMealAnimation = false
    @State private var showingUpgrade = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Full screen animated background
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 40) {
                        // Animated Logo
                        HeroLogoView()
                        
                        // Main CTA
                        VStack(spacing: 20) {
                            MagneticButton(
                                title: "Snap Your Fridge",
                                icon: "camera.fill",
                                action: {
                                    showingCamera = true
                                    particleTrigger = true
                                }
                            )
                            
                            if !deviceManager.hasUnlimitedAccess {
                                Button(action: { showingUpgrade = true }) {
                                    FreeUsesIndicatorEnhanced(remaining: deviceManager.freeUsesRemaining)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Feature Cards
                        FeatureCardsGrid()
                            .padding(.horizontal, 20)
                        
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
}

// MARK: - Hero Logo
struct HeroLogoView: View {
    @State private var shimmerPhase: CGFloat = 0
    @State private var sparkleScale: CGFloat = 1
    @State private var sparkleOpacity: Double = 1
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Main text in white with larger size
                Text("SnapChef")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .overlay(
                        // Circular shimmer effect
                        GeometryReader { geometry in
                            Circle()
                                .fill(
                                    AngularGradient(
                                        gradient: Gradient(colors: [
                                            Color.clear,
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.8),
                                            Color.white.opacity(0.6),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startAngle: .degrees(shimmerPhase),
                                        endAngle: .degrees(shimmerPhase + 90)
                                    )
                                )
                                .scaleEffect(1.5)
                                .blur(radius: 8)
                                .mask(
                                    Text("SnapChef")
                                        .font(.system(size: 72, weight: .black, design: .rounded))
                                )
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        }
                    )
                
                // Sparkle emoji with sparkle animation
                Text("✨")
                    .font(.system(size: 48))
                    .offset(x: 140, y: -25)
                    .scaleEffect(sparkleScale)
                    .opacity(sparkleOpacity)
            }
            
            Text("AI-powered recipes from what you already have")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
        .onAppear {
            // Continuous circular shimmer
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                shimmerPhase = 360
            }
            
            // Sparkle pulse animation
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                sparkleScale = 1.4
                sparkleOpacity = 0.5
            }
        }
    }
}

// MARK: - Free Uses Indicator Enhanced
struct FreeUsesIndicatorEnhanced: View {
    let remaining: Int
    @State private var pulseScale: CGFloat = 1
    
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
        .onAppear {
            // Subtle single pulse on appear
            withAnimation(.easeInOut(duration: 0.8)) {
                pulseScale = 1.05
            }
        }
    }
}

// MARK: - Feature Cards Grid
struct FeatureCardsGrid: View {
    let features = [
        ("🤖", "AI Magic", "Smart recipe generation", Color(hex: "#667eea")),
        ("⚡", "Instant", "Results in seconds, meals in minutes", Color(hex: "#f093fb")),
        ("🎯", "Personal", "Tailored to you", Color(hex: "#4facfe")),
        ("🌟", "Share", "Go viral instantly", Color(hex: "#43e97b"))
    ]
    
    @State private var selectedIndex: Int? = nil
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            ForEach(0..<features.count, id: \.self) { index in
                FeatureCardEnhanced(
                    emoji: features[index].0,
                    title: features[index].1,
                    description: features[index].2,
                    color: features[index].3,
                    isSelected: selectedIndex == index
                )
                .aspectRatio(1, contentMode: .fit)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedIndex = selectedIndex == index ? nil : index
                    }
                    
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        }
    }
}

struct FeatureCardEnhanced: View {
    let emoji: String
    let title: String
    let description: String
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        GlassmorphicCard(content: {
            VStack(spacing: 12) {
                // Emoji with animation
                Text(emoji)
                    .font(.system(size: 40))
                    .scaleEffect(isSelected ? 1.2 : 1)
                    .rotationEffect(.degrees(isSelected ? 10 : 0))
                
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }, glowColor: color)
        .scaleEffect(isSelected ? 1.05 : 1)
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

#Preview {
    EnhancedHomeView()
        .environmentObject(AppState())
        .environmentObject(DeviceManager())
}