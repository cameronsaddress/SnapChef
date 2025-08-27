import SwiftUI
import AVFoundation

struct DisplayChallenge {
    let emoji: String
    let challenge: Challenge
    let participants: String
    let color: Color
}

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var cloudKitDataManager: CloudKitDataManager
    @State private var showingCamera = false
    @State private var showingMysteryMeal = false
    @State private var particleTrigger = false
    @State private var mysteryMealAnimation = false
    @State private var showingUpgrade = false
    @StateObject private var fallingFoodManager = FallingFoodManager()
    @State private var buttonShake = false
    @State private var showingDetective = false
    @State private var showingCameraPermissionAlert = false

    var body: some View {
        ZStack {
            // Full screen animated background
                MagicalBackground()
                    .ignoresSafeArea()

                // Falling food emojis (behind all elements except background)
                if deviceManager.shouldShowParticles {
                    ForEach(fallingFoodManager.emojis.prefix(deviceManager.recommendedParticleCount)) { emoji in
                        Text(emoji.emoji)
                            .font(.system(size: 30))
                            .opacity(0.5)  // 50% translucent
                            .position(x: emoji.position.x, y: emoji.position.y)
                    }
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
                                    Task {
                                        let granted = await requestCameraPermission()
                                        if granted {
                                            showingCamera = true
                                            particleTrigger = true
                                        }
                                    }
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

                        // Recipe Detective Tile (moved up)
                        DetectiveFeatureTile()
                            .padding(.horizontal, 30)
                            .padding(.top, 20)

                        // Streak Summary
                        StreakSummaryCard()
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        // Viral Section (Today's Challenges) - moved up
                        ViralChallengeSection()
                            .padding(.top, 20)
                            .padding(.bottom, 20)


                        // Mystery Meal Button
                        MysteryMealButton(
                            isAnimating: $mysteryMealAnimation,
                            action: {
                                showingMysteryMeal = true
                                particleTrigger = true
                            }
                        )
                        .padding(.horizontal, 30)
                        .padding(.bottom, 40)

                        // Recent Recipes
                        if !appState.recentRecipes.isEmpty {
                            EnhancedRecipesSection(recipes: appState.recentRecipes)
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
            print("🔍 DEBUG: HomeView appeared - Start")
            
            // Defer state modifications to avoid "Modifying state during view update" warnings
            DispatchQueue.main.async {
                print("🔍 DEBUG: HomeView - Async block started")
                
                // Track screen view
                Task {
                    cloudKitDataManager.trackScreenView("Home")
                }
                
                // Simple fade in for mystery meal animation (only if animations enabled)
                if deviceManager.animationsEnabled {
                    print("🔍 DEBUG: HomeView - Setting mysteryMealAnimation")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: deviceManager.recommendedAnimationDuration * 2)) {
                        mysteryMealAnimation = true
                    }
                    }
                } else {
                    mysteryMealAnimation = true
                }
                
                // Start button shake after 3 seconds (only if continuous animations enabled)
                if deviceManager.shouldUseContinuousAnimations {
                    print("🔍 DEBUG: HomeView - Scheduling button shake")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        startButtonShake()
                    }
                }
                
                // Start falling food animation (only if particles enabled)
                if deviceManager.shouldShowParticles {
                    print("🔍 DEBUG: HomeView - Starting falling food animation")
                    fallingFoodManager.startFallingFood()
                }
                
                print("🔍 DEBUG: HomeView - Async block completed")
            }
            
            print("🔍 DEBUG: HomeView appeared - End")
            
            // Additional delayed check
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔍 DEBUG: HomeView - 0.5s after appear")
            }
        }
        .onDisappear {
            fallingFoodManager.cleanup()
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
        .fullScreenCover(isPresented: $showingDetective) {
            DetectiveView()
        }
        .alert("Camera Access Required", isPresented: $showingCameraPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("SnapChef needs camera access to capture photos of your ingredients. Please enable camera access in Settings.")
        }
    }
    
    // MARK: - Camera Permission Handling
    @MainActor
    private func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return true
            
        case .notDetermined:
            // Request permission
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted
            
        case .denied, .restricted:
            showingCameraPermissionAlert = true
            return false
            
        @unknown default:
            showingCameraPermissionAlert = true
            return false
        }
    }

    private func startButtonShake() {
        // Only shake if continuous animations are enabled
        guard deviceManager.shouldUseContinuousAnimations else { return }
        
        // Subtle shake effect
        withAnimation(.default) {
            buttonShake = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            buttonShake = false

            // Repeat every 8-12 seconds (only if still enabled)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 8...12)) {
                if deviceManager.shouldUseContinuousAnimations {
                    startButtonShake()
                }
            }
        }
    }

    private func updateButtonFrames(_ frame: CGRect) {
        fallingFoodManager.updateButtonFrames([frame])
    }
}


// MARK: - Viral Challenge Section
struct ViralChallengeSection: View {
    @State private var currentChallenge = 0
    @State private var showingChallengeView = false
    @State private var selectedChallenge: Challenge?
    @State private var autoTimer: Timer?
    @State private var sparkleAnimation = false
    @StateObject private var challengeDatabase = ChallengeDatabase.shared

    // Colors for challenges based on type/category
    let challengeColors = [
        Color(hex: "#f093fb"),
        Color(hex: "#667eea"),
        Color(hex: "#43e97b"),
        Color(hex: "#ffa726"),
        Color(hex: "#f5576c")
    ]

    var displayChallenges: [DisplayChallenge] {
        // Get ALL active challenges from ChallengeDatabase (should be 3-4 per day now)
        let activeChallenges = challengeDatabase.activeChallenges

        // If we have active challenges, use them
        if !activeChallenges.isEmpty {
            return activeChallenges.enumerated().map { index, challenge in
                // Get emoji for the challenge
                let emoji = challengeDatabase.getEmojiForChallenge(challenge)
                let participantCount = "\(challenge.participants) chefs"
                let color = challengeColors[index % challengeColors.count]

                return DisplayChallenge(emoji: emoji, challenge: challenge, participants: participantCount, color: color)
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
            // Determine difficulty based on points
            let difficulty: DifficultyLevel = {
                if data.4 <= 300 { return .easy } else if data.4 <= 450 { return .medium } else if data.4 <= 600 { return .hard } else { return .expert }
            }()

            // Set end time based on difficulty with some variation
            let baseHours: Double = {
                switch difficulty {
                case .easy: return 12
                case .medium: return 24
                case .hard: return 48
                case .expert: return 72
                case .master: return 168 // 1 week
                }
            }()

            // Add variation to prevent same countdown times
            let variation = Double.random(in: -2...2) // +/- 2 hours variation
            let hoursOffset = baseHours + variation + Double(index * 3) // Additional offset per challenge

            let challenge = Challenge(
                id: "home-\(data.1.replacingOccurrences(of: " ", with: "-").lowercased())",
                title: data.1,
                description: data.2,
                type: .daily,
                difficulty: difficulty,
                points: data.4,
                coins: data.4 / 10,
                endDate: Date().addingTimeInterval(TimeInterval(hoursOffset * 3_600)),
                requirements: ["Create a \(data.1.lowercased()) dish and share it"],
                currentProgress: 0,
                participants: Int.random(in: 100...500)
            )
            return DisplayChallenge(emoji: data.0, challenge: challenge, participants: data.3, color: data.5)
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(Array(displayChallenges.enumerated()), id: \.offset) { index, challengeData in
                        EnhancedChallengeCard(
                            emoji: challengeData.emoji,
                            title: challengeData.challenge.title,
                            description: challengeData.challenge.description,
                            participants: challengeData.participants,
                            points: "\(challengeData.challenge.points)",
                            color: challengeData.color,
                            actualChallenge: challengeData.challenge,
                            action: {
                                selectedChallenge = challengeData.challenge
                                showingChallengeView = true
                            }
                        )
                        .frame(width: UIScreen.main.bounds.width - 60)
                        .scaleEffect(currentChallenge == index ? 1 : 0.9)
                    }
                }
                .padding(.horizontal, 30)
            }
            .frame(height: 540)
        }
        .onAppear {
            // Update challenges when view appears
            challengeDatabase.updateActiveChallenges()
            
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    sparkleAnimation = true
                }
                startAutoScroll()
            }
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
            // Defer state updates to avoid "Modifying state during view update"
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentChallenge = (currentChallenge + 1) % max(displayChallenges.count, 1)
                }
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
    let actualChallenge: Challenge?
    let action: () -> Void

    @State private var isPressed = false
    @State private var particleAnimation = false
    @State private var timeRemaining = ""
    @StateObject private var gamificationManager = GamificationManager.shared
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Fallback challenge if none provided
    private var challenge: Challenge? {
        // Use the actual challenge if provided
        if let actualChallenge = actualChallenge {
            return actualChallenge
        }

        // Otherwise create a mock challenge with proper end date
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
                        Text(gamificationManager.isChallengeJoinedByTitle(title) ? "View Progress" : "View Challenge")
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
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = pressing
                        }
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
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    particleAnimation = true
                }
                updateTimeRemaining()
            }
        }
        .onReceive(timer) { _ in
            // Defer state updates to avoid "Modifying state during view update"
            DispatchQueue.main.async {
                updateTimeRemaining()
            }
        }
    }

    private func updateTimeRemaining() {
        // Use actualChallenge if available, otherwise use fallback
        let challengeToUse = actualChallenge ?? challenge
        guard let challenge = challengeToUse else {
            timeRemaining = "00:00:00"
            return
        }

        let now = Date()
        let endDate = challenge.endDate

        if now >= endDate {
            timeRemaining = "Ended"
            return
        }

        let timeInterval = endDate.timeIntervalSince(now)
        let totalHours = Int(timeInterval) / 3_600
        let minutes = (Int(timeInterval) % 3_600) / 60
        let seconds = Int(timeInterval) % 60

        // Always show in HH:MM:SS format, even for days
        // If more than 99 hours, show 99:59:59 as max
        let displayHours = min(totalHours, 99)
        timeRemaining = String(format: "%02d:%02d:%02d", displayHours, minutes, seconds)
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
    @EnvironmentObject var appState: AppState

    var body: some View {
        GlassmorphicCard(content: {
            VStack(alignment: .leading, spacing: 12) {
                // Recipe photos (before/after)
                RecipePhotoView(
                    recipe: recipe,
                    width: 188,  // 220 - 32 padding
                    height: 120,
                    showLabels: true
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
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }
        }, perform: {})
        .onAppear {
            // Single rotation on appear
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 1.2)) {
                    diceRotation = 360
                }
            }
        }
    }
}

// MARK: - Shake Effect
struct ShakeEffect: AnimatableModifier {
    var shakeNumber: CGFloat = 0

    nonisolated var animatableData: CGFloat {
        get { shakeNumber }
        set { shakeNumber = newValue }
    }

    func body(content: Content) -> some View {
        content
            .offset(x: sin(shakeNumber * .pi * 2) * 5)
    }
}

// MARK: - Falling Food Manager
@MainActor
final class FallingFoodManager: ObservableObject {
    @Published var emojis: [FallingFoodEmoji] = []
    private let foodEmojis = ["🍕", "🍔", "🌮", "🍜", "🍝", "🥗", "🍣", "🥘", "🍛", "🥙", "🍱", "🥪", "🌯", "🍖", "🍗", "🥓", "🧀", "🥚", "🍳", "🥞"]
    private var buttonFrames: [CGRect] = []
    private var displayLink: CADisplayLink?
    private var lastDropTime: TimeInterval = 0
    private var nextDropDelay: TimeInterval = 0
    private var maxParticles: Int = 15
    private var isRunning: Bool = false
    private var initialDelayComplete: Bool = false

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

    func startFallingFood(maxCount: Int = 15) {
        guard !isRunning else { return }
        
        isRunning = true
        maxParticles = maxCount
        initialDelayComplete = false
        
        // Delay the start of animations to avoid view update conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.initialDelayComplete = true
            
            // Use CADisplayLink for smooth animation that doesn't pause during scrolling
            self.displayLink = CADisplayLink(target: self, selector: #selector(self.updateAnimation))
            self.displayLink?.add(to: .current, forMode: .common) // .common mode ensures it runs during scrolling
            
            // Set initial drop delay
            self.nextDropDelay = Double.random(in: 1.0...4.0) // Longer delays for better performance
        }
    }

    @objc private func updateAnimation() {
        // Skip updates until initial delay is complete
        guard initialDelayComplete else { return }
        
        // Defer state updates to avoid "Modifying state during view update"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.updatePhysics()

            // Handle emoji dropping
            let currentTime = CACurrentMediaTime()
            if currentTime - self.lastDropTime >= self.nextDropDelay {
                self.dropEmoji()
                self.lastDropTime = currentTime
                self.nextDropDelay = Double.random(in: 0.5...3)
            }
        }
    }

    func cleanup() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        emojis.removeAll()
    }

    private func dropEmoji() {
        // Limit total number of emojis for performance
        guard emojis.count < maxParticles else { return }
        
        let screenWidth = UIScreen.main.bounds.width

        // Always drop only 1 emoji
        let xPosition = CGFloat.random(in: 50...screenWidth - 50)

        let emoji = FallingFoodEmoji(
            position: CGPoint(
                x: xPosition,
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

        for index in emojis.indices {
            // Apply gravity
            emojis[index].velocity.dy += gravity * deltaTime

            // Update position
            emojis[index].position.x += emojis[index].velocity.dx * deltaTime
            emojis[index].position.y += emojis[index].velocity.dy * deltaTime

            // Check collision with buttons (only if hasn't bounced yet)
            if !emojis[index].hasBouncedOffButton {
                for buttonFrame in buttonFrames {
                    if isCollidingWithButton(emoji: emojis[index], buttonFrame: buttonFrame) {
                        // Bounce off button
                        emojis[index].velocity.dy = -abs(emojis[index].velocity.dy) * bounceDamping
                        emojis[index].velocity.dx += CGFloat.random(in: -40...40)

                        // Move emoji to top of button
                        emojis[index].position.y = buttonFrame.minY - 15

                        // Mark as having bounced
                        emojis[index].hasBouncedOffButton = true
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

// MARK: - Recipe Detective Tile
struct RecipeDetectiveTile: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showingDetectiveView = false
    @State private var isAnimating = false
    @State private var mysteryGlow = false
    
    var body: some View {
        Button(action: {
            showingDetectiveView = true
        }) {
            HStack(spacing: 16) {
                // Detective magnifying glass with mystery animation
                ZStack {
                    // Dark mysterious glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#1a0033").opacity(mysteryGlow ? 0.8 : 0.4),
                                    Color(hex: "#330066").opacity(mysteryGlow ? 0.6 : 0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(mysteryGlow ? 1.2 : 1)
                    
                    // Magnifying glass icon with premium styling
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#2d1b69"),
                                        Color(hex: "#11052c")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                        
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(isAnimating ? 1.1 : 1)
                    }
                    
                    // Premium lock badge if needed
                    if !deviceManager.hasUnlimitedAccess {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(
                                        Circle()
                                            .fill(Color(hex: "#ffd700"))
                                    )
                                    .offset(x: 8, y: -8)
                            }
                            Spacer()
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recipe Detective")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#ffd700"),
                                    Color(hex: "#ffed4e")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Cook your favorites at home")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow with mystery styling
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.1 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#0f0625").opacity(0.9),
                                Color(hex: "#1a0033").opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#ffd700").opacity(0.6),
                                        Color(hex: "#2d1b69").opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial.opacity(0.3))
                    )
            )
            .shadow(
                color: Color(hex: "#ffd700").opacity(0.3),
                radius: mysteryGlow ? 20 : 10,
                y: mysteryGlow ? 8 : 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    mysteryGlow = true
                }
            }
        }
        .fullScreenCover(isPresented: $showingDetectiveView) {
            RecipeDetectiveView()
        }
    }
}

// MARK: - Detective Feature Tile
struct DetectiveFeatureTile: View {
    @State private var showingDetective = false
    @State private var isAnimating = false
    @StateObject private var userLifecycle = UserLifecycleManager.shared
    @StateObject private var cloudKitAuth = UnifiedAuthManager.shared
    @State private var showingCameraPermissionAlert = false
    
    // Track detective uses (10 for testing, should be 3 for production)
    @AppStorage("detectiveFeatureUses") private var detectiveUses: Int = 0
    private let freeUsesLimit = 10 // TODO: Change to 3 for production
    
    private var isPremiumLocked: Bool {
        detectiveUses >= freeUsesLimit && (!cloudKitAuth.isAuthenticated || userLifecycle.currentPhase == .standard)
    }
    
    var body: some View {
        Button(action: {
            Task {
                let granted = await requestCameraPermission()
                if granted {
                    showingDetective = true
                }
            }
        }) {
            HStack(spacing: 16) {
                // Animated detective icon
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#9b59b6").opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .scaleEffect(isAnimating ? 1.2 : 1)
                    
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#9b59b6"),
                                    Color(hex: "#8e44ad")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1.1 : 1)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recipe Detective")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#9b59b6"),
                                    Color(hex: "#8e44ad")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    Text("Reverse-engineer any dish")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                
                Spacer()
                
                // Show lock or arrow based on uses
                if isPremiumLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#9b59b6"))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color(hex: "#9b59b6").opacity(0.1))
                        )
                } else {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#9b59b6"))
                        .offset(x: isAnimating ? 5 : 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#9b59b6").opacity(0.5),
                                        Color(hex: "#8e44ad").opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .shadow(
                color: Color(hex: "#9b59b6").opacity(0.3),
                radius: isAnimating ? 20 : 10,
                y: isAnimating ? 10 : 5
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
        .fullScreenCover(isPresented: $showingDetective) {
            DetectiveView()
        }
        .alert("Camera Access Required", isPresented: $showingCameraPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("SnapChef needs camera access to capture photos of your ingredients. Please enable camera access in Settings.")
        }
    }
    
    // MARK: - Camera Permission Handling for Detective
    @MainActor
    private func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return true
            
        case .notDetermined:
            // Request permission
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted
            
        case .denied, .restricted:
            showingCameraPermissionAlert = true
            return false
            
        @unknown default:
            showingCameraPermissionAlert = true
            return false
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(DeviceManager())
}
