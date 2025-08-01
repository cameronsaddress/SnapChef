import SwiftUI

struct HomeView: View {
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
                        VStack(spacing: 16) {
                            SnapchefLogo()
                            
                            Text("AI-powered recipes\nfrom what you already have")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 30)
                        
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
                        }
                        
                        // Celebrity Kitchens Carousel
                        InfluencerCarousel()
                            .padding(.top, 10)
                        
                        // Food Preferences Card
                        FoodPreferencesCard()
                            .padding(.horizontal, 30)
                            .padding(.top, 20)
                        
                        // Mystery Meal Button
                        MysteryMealButton(
                            isAnimating: $mysteryMealAnimation,
                            action: {
                                showingMysteryMeal = true
                                particleTrigger = true
                            }
                        )
                        .padding(.horizontal, 30)
                        .padding(.top, 20)
                        
                        // Viral Section
                        ViralChallengeSection()
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        
                        // Recent Recipes
                        if !appState.recentRecipes.isEmpty {
                            EnhancedRecipesSection(recipes: appState.recentRecipes)
                        }
                        
                        // Free uses indicator at bottom
                        if !deviceManager.hasUnlimitedAccess {
                            Button(action: { showingUpgrade = true }) {
                                FreeUsesIndicatorEnhanced(remaining: deviceManager.freeUsesRemaining)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 30)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        }
                    }
                    .padding(.bottom, 100)
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
            CameraView()
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
    @State private var showingChallengeView = false
    @State private var selectedChallenge: Challenge?
    @State private var autoTimer: Timer?
    @State private var sparkleAnimation = false
    @StateObject private var gamificationManager = GamificationManager.shared
    
    // Colors for challenges based on type/category
    let challengeColors = [
        Color(hex: "#f093fb"),
        Color(hex: "#667eea"),
        Color(hex: "#43e97b"),
        Color(hex: "#ffa726"),
        Color(hex: "#f5576c")
    ]
    
    var displayChallenges: [(emoji: String, challenge: Challenge, participants: String, color: Color)] {
        // Get first 5 active challenges from GamificationManager
        let activeChallenges = Array(gamificationManager.activeChallenges.prefix(5))
        
        // If we have local challenges, use them
        if !activeChallenges.isEmpty {
            return activeChallenges.enumerated().map { index, challenge in
                // Look for emoji in ChallengeSeeder data
                let emoji = getEmojiForChallenge(challenge) ?? "🎯"
                let participantCount = "\(challenge.participants) chefs"
                let color = challengeColors[index % challengeColors.count]
                
                return (emoji, challenge, participantCount, color)
            }
        }
        
        // Fallback to mock data if no CloudKit challenges
        let mockData = [
            ("🌮", "Taco Tuesday", "Transform leftovers into tacos", "2.3K chefs", 500, Color(hex: "#f093fb")),
            ("🍕", "Pizza Party", "Create pizza with pantry items", "1.8K chefs", 450, Color(hex: "#667eea")),
            ("🥗", "Salad Spectacular", "Make amazing salads", "956 chefs", 300, Color(hex: "#43e97b")),
            ("🍜", "Ramen Remix", "Upgrade instant ramen to gourmet", "3.1K chefs", 600, Color(hex: "#ffa726")),
            ("🥘", "One-Pot Wonder", "Create magic in a single pot", "1.2K chefs", 400, Color(hex: "#f5576c"))
        ]
        
        return mockData.enumerated().map { index, data in
            let challenge = Challenge(
                id: "home-\(data.1.replacingOccurrences(of: " ", with: "-").lowercased())",
                title: data.1,
                description: data.2,
                type: .daily,
                points: data.4,
                coins: data.4 / 10,
                endDate: Date().addingTimeInterval(TimeInterval(3600 * (index + 1) * 8)),
                requirements: ["Create a \(data.1.lowercased()) dish and share it"],
                currentProgress: 0,
                participants: Int.random(in: 100...500)
            )
            return (data.0, challenge, data.3, data.5)
        }
    }
    
    private func getEmojiForChallenge(_ challenge: Challenge) -> String? {
        // Map of challenge titles to emojis from ChallengeSeeder
        let emojiMap: [String: String] = [
            // Winter
            "Holiday Cookie Decorating": "🎄",
            "Cozy Hot Chocolate Bar": "☕️",
            "Soup Season Champion": "🍲",
            "New Year's Lucky Dish": "🥧",
            "New Year New Salad": "🥗",
            "Ramen Glow-Up": "🍜",
            "Smoothie Bowl Art": "🧃",
            "Valentine's Treats": "❤️",
            "Comfort Food Remix": "🫔",
            "Pancake Art Master": "🥞",
            // Spring
            "Rainbow Veggie Challenge": "🌈",
            "Lucky Green Foods": "☘️",
            "Egg-cellent Creations": "🥚",
            "Edible Flowers": "🌷",
            "Perfect Picnic Spread": "🧺",
            "Taco Tuesday Takeover": "🌮",
            "Berry Delicious": "🍓",
            // Summer
            "Better Burger Battle": "🍔",
            "No-Churn Ice Cream": "🍦",
            "Red, White & Blue": "🎆",
            "Corn on the Cob Remix": "🌽",
            "Watermelon Wow": "🍉",
            "Mocktail Mixologist": "🥤",
            "Beach Snack Pack": "🏖️",
            // Fall
            "Apple Everything": "🍎",
            "Back to School Lunch": "📚",
            "Pumpkin Spice Everything": "🎃",
            "Spooky Food Art": "👻",
            "Mushroom Magic": "🍄",
            "Thanksgiving Sides Star": "🦃",
            "Pie Perfection": "🥧",
            "Leftover Makeover": "🍂",
            // Viral
            "Butter Board Bonanza": "🧈",
            "Tiny Kitchen Challenge": "🍳",
            "Cheese Pull Champion": "🧀",
            "Wrap Hack Magic": "🌯",
            "Pancake Cereal": "🥞",
            "Cloud Bread Dreams": "☁️",
            "One-Pot Pasta Magic": "🍝",
            "Mug Cake Master": "🎂",
            "Avocado Rose Art": "🥑",
            "Ocean Water Cake": "🌊",
            // Weekend
            "Breakfast for Dinner": "🥓",
            "Pizza Night Reinvented": "🍕",
            "Movie Night Snacks": "🍿",
            "Farmers Market Haul": "🧺",
            "Game Day Spread": "🎮",
            "Sunrise Breakfast": "🌅",
            "Edible Art Project": "🎨",
            "Indoor Camping Cuisine": "🏕️",
            "Carnival at Home": "🎪",
            "Around the World": "🌍"
        ]
        
        return emojiMap[challenge.title]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Challenge")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Join thousands of home chefs")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Live indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 8)
                                .scaleEffect(sparkleAnimation ? 2 : 1)
                                .opacity(sparkleAnimation ? 0 : 1)
                                .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: sparkleAnimation)
                        )
                    
                    Text("LIVE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.2))
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // Carousel
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    TabView(selection: $currentChallenge) {
                        ForEach(Array(displayChallenges.enumerated()), id: \.offset) { index, challengeData in
                            EnhancedChallengeCard(
                                emoji: challengeData.emoji,
                                title: challengeData.challenge.title,
                                description: challengeData.challenge.description,
                                participants: challengeData.participants,
                                points: "\(challengeData.challenge.points)",
                                color: challengeData.color,
                                action: {
                                    selectedChallenge = challengeData.challenge
                                    showingChallengeView = true
                                }
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 540)
                    
                    // Page indicators
                    HStack(spacing: 6) {
                        ForEach(0..<displayChallenges.count, id: \.self) { index in
                            Capsule()
                                .fill(currentChallenge == index ? Color.white : Color.white.opacity(0.3))
                                .frame(width: currentChallenge == index ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentChallenge)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .frame(height: 540)
        }
        .onAppear {
            sparkleAnimation = true
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
        .sheet(item: $selectedChallenge) { challenge in
            ChallengeDetailView(challenge: challenge)
        }
    }
    
    private func startAutoScroll() {
        autoTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentChallenge = (currentChallenge + 1) % max(displayChallenges.count, 1)
            }
        }
    }
    
    private func stopAutoScroll() {
        autoTimer?.invalidate()
        autoTimer = nil
    }
}

struct EnhancedChallengeCard: View {
    let emoji: String
    let title: String
    let description: String
    let participants: String
    let points: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var particleAnimation = false
    @StateObject private var gamificationManager = GamificationManager.shared
    @State private var timeRemaining = ""
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Get the actual challenge to access its endDate
    private var challenge: Challenge? {
        // First check if we have a challenge from CloudKit
        if let activeChallenge = gamificationManager.activeChallenges.first(where: { $0.title == title }) {
            return activeChallenge
        }
        
        // Check completed challenges
        if let completedChallenge = gamificationManager.completedChallenges.first(where: { $0.title == title }) {
            return completedChallenge
        }
        
        // Create a mock challenge with proper end date if not found
        return Challenge(
            title: title,
            description: description,
            type: .daily,
            points: Int(points.replacingOccurrences(of: " pts", with: "")) ?? 100,
            coins: (Int(points.replacingOccurrences(of: " pts", with: "")) ?? 100) / 10,
            endDate: Date().addingTimeInterval(24 * 60 * 60), // 24 hours from now
            requirements: ["Complete the challenge"]
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            VStack(spacing: 20) {
                // Trophy and points
                ZStack {
                    // Animated glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [color.opacity(0.5), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(particleAnimation ? 1.2 : 1)
                        .opacity(particleAnimation ? 0.5 : 0.8)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: particleAnimation)
                    
                    VStack(spacing: 8) {
                        Text(emoji)
                            .font(.system(size: 60))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#ffa726"))
                            Text(points + " pts")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                    }
                }
                
                // Challenge info
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    // Participants
                    HStack(spacing: 8) {
                        // Profile stack
                        ZStack {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text(["JD", "AS", "MK"][index])
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: CGFloat(index * 20))
                            }
                        }
                        .frame(width: 80, height: 30, alignment: .leading)
                        
                        Text(participants + " joining")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Timer countdown
                VStack(spacing: 8) {
                    Text("Ends in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(timeRemaining)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.2))
                )
                
                // CTA Button
                Button(action: action) {
                    HStack {
                        Text(gamificationManager.isChallengeJoinedByTitle(title) ? "View Progress" : "Join Challenge")
                            .font(.system(size: 18, weight: .semibold))
                        Image(systemName: gamificationManager.isChallengeJoinedByTitle(title) ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                            .font(.system(size: 18))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: gamificationManager.isChallengeJoinedByTitle(title) ? 
                                           [Color.green, Color.green.opacity(0.8)] : 
                                           [color, color.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: gamificationManager.isChallengeJoinedByTitle(title) ? 
                            Color.green.opacity(0.5) : color.opacity(0.5), radius: 15, y: 5)
                }
                .scaleEffect(isPressed ? 0.95 : 1)
                .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = pressing
                    }
                }, perform: {})
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 60)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
        .onAppear {
            particleAnimation = true
            updateTimeRemaining()
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        guard let challenge = challenge else {
            timeRemaining = "00:00:00"
            return
        }
        
        let now = Date()
        let endDate = challenge.endDate
        
        if now >= endDate {
            timeRemaining = "Ended"
            return
        }
        
        let difference = Calendar.current.dateComponents([.hour, .minute, .second], from: now, to: endDate)
        
        let hours = difference.hour ?? 0
        let minutes = difference.minute ?? 0
        let seconds = difference.second ?? 0
        
        if hours > 24 {
            let days = hours / 24
            timeRemaining = "\(days)d \(hours % 24)h"
        } else {
            timeRemaining = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}

struct TimeUnit: View {
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
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
                    .frame(height: 48, alignment: .topLeading)
                
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
            .frame(width: 220, height: 220)
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
    private var displayLink: CADisplayLink?
    private var lastDropTime: TimeInterval = 0
    private var nextDropDelay: TimeInterval = 0
    
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
        // Use CADisplayLink for smooth animation that doesn't pause during scrolling
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.add(to: .current, forMode: .common) // .common mode ensures it runs during scrolling
        
        // Set initial drop delay
        nextDropDelay = Double.random(in: 0.5...3)
    }
    
    @objc private func updateAnimation() {
        updatePhysics()
        
        // Handle emoji dropping
        let currentTime = CACurrentMediaTime()
        if currentTime - lastDropTime >= nextDropDelay {
            dropEmoji()
            lastDropTime = currentTime
            nextDropDelay = Double.random(in: 0.5...3)
        }
    }
    
    deinit {
        displayLink?.invalidate()
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
    HomeView()
        .environmentObject(AppState())
        .environmentObject(DeviceManager())
}