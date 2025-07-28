import SwiftUI

struct EnhancedHomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showingCamera = false
    @State private var logoScale: CGFloat = 0
    @State private var contentVisible = false
    @State private var particleTrigger = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 40) {
                        // Animated Logo
                        HeroLogoView()
                            .scaleEffect(logoScale)
                            .onAppear {
                                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                                    logoScale = 1
                                }
                                
                                withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                                    contentVisible = true
                                }
                            }
                        
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
                            .staggeredFade(index: 0, isShowing: contentVisible)
                            
                            if !deviceManager.hasUnlimitedAccess {
                                FreeUsesIndicatorEnhanced(remaining: deviceManager.freeUsesRemaining)
                                    .staggeredFade(index: 1, isShowing: contentVisible)
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Feature Cards
                        FeatureCardsGrid()
                            .padding(.horizontal, 20)
                            .staggeredFade(index: 2, isShowing: contentVisible)
                        
                        // Viral Section
                        ViralChallengeSection()
                            .staggeredFade(index: 3, isShowing: contentVisible)
                        
                        // Recent Recipes
                        if !appState.recentRecipes.isEmpty {
                            EnhancedRecipesSection(recipes: appState.recentRecipes)
                                .staggeredFade(index: 4, isShowing: contentVisible)
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
            .particleExplosion(trigger: $particleTrigger)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            EnhancedCameraView()
        }
    }
}

// MARK: - Hero Logo
struct HeroLogoView: View {
    @State private var shimmer: CGFloat = -1
    @State private var glow = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Glow effect
                Text("SnapChef")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "#667eea"))
                    .blur(radius: glow ? 30 : 10)
                    .scaleEffect(glow ? 1.2 : 1)
                
                // Main text with gradient
                Text("SnapChef")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "#667eea"),
                                Color(hex: "#764ba2"),
                                Color(hex: "#f093fb")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // Shimmer effect
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.8),
                                Color.clear
                            ],
                            startPoint: UnitPoint(x: shimmer - 0.3, y: 0),
                            endPoint: UnitPoint(x: shimmer + 0.3, y: 1)
                        )
                        .mask(
                            Text("SnapChef")
                                .font(.system(size: 56, weight: .black, design: .rounded))
                        )
                    )
                
                // Sparkle emoji
                Text("✨")
                    .font(.system(size: 42))
                    .offset(x: 110, y: -20)
                    .rotationEffect(.degrees(glow ? 360 : 0))
            }
            
            Text("AI-powered recipes from what you already have")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                shimmer = 2
            }
            
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

// MARK: - Free Uses Indicator Enhanced
struct FreeUsesIndicatorEnhanced: View {
    let remaining: Int
    @State private var pulseScale: CGFloat = 1
    
    var body: some View {
        GlassmorphicCard {
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
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }
}

// MARK: - Feature Cards Grid
struct FeatureCardsGrid: View {
    let features = [
        ("🤖", "AI Magic", "Smart recipe generation", Color(hex: "#667eea")),
        ("⚡", "Instant", "Results in seconds", Color(hex: "#f093fb")),
        ("🎯", "Personal", "Tailored to you", Color(hex: "#4facfe")),
        ("🌟", "Share", "Go viral instantly", Color(hex: "#43e97b"))
    ]
    
    @State private var selectedIndex: Int? = nil
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(0..<features.count, id: \.self) { index in
                FeatureCardEnhanced(
                    emoji: features[index].0,
                    title: features[index].1,
                    description: features[index].2,
                    color: features[index].3,
                    isSelected: selectedIndex == index
                )
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
        }, cornerRadius: 20, glowColor: color)
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
            
            TabView(selection: $currentChallenge) {
                ForEach(0..<challenges.count, id: \.self) { index in
                    ChallengeCard(
                        emoji: challenges[index].0,
                        title: challenges[index].1,
                        description: challenges[index].2
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .frame(height: 180)
        }
        .padding(.horizontal, 20)
    }
}

struct ChallengeCard: View {
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
        }, cornerRadius: 20, glowColor: Color(hex: "#f093fb"))
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
        GlassmorphicCard {
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
        }
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

#Preview {
    EnhancedHomeView()
        .environmentObject(AppState())
        .environmentObject(DeviceManager())
}