import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var cameraModel = CameraModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var cloudKitDataManager: CloudKitDataManager
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTab: Int
    
    init(selectedTab: Binding<Int>? = nil) {
        self._selectedTab = selectedTab ?? .constant(0)
    }
    
    @State private var isProcessing = false
    @State private var showingResults = false
    @State private var generatedRecipes: [Recipe] = []
    @State private var detectedIngredients: [IngredientAPI] = []
    @State private var capturedImage: UIImage?
    @State private var resultsPreloaded = false
    @State private var showingPreview = false
    @State private var captureAnimation = false
    @State private var scanLineOffset: CGFloat = -200
    @State private var glowIntensity: Double = 0.3
    @State private var showingUpgrade = false
    @State private var showConfetti = false
    @State private var showWelcomeMessage = false
    
    // User preferences for API
    @State private var selectedFoodType: String?
    @State private var selectedDifficulty: String?
    @State private var currentDietaryRestrictions: [String] = []
    @State private var selectedHealthPreference: String?
    @State private var selectedMealType: String?
    @State private var selectedCookingTime: String?
    @State private var numberOfRecipes: Int = 5
    
    // Error handling
    @State private var currentError: SnapChefError?
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var showPremiumPrompt = false
    @State private var premiumPromptReason: PremiumUpgradePrompt.UpgradeReason = .dailyLimitReached
    
    var flashIcon: String {
        switch cameraModel.flashMode {
        case .off:
            return "bolt.slash.fill"
        case .on:
            return "bolt.fill"
        case .auto:
            return "bolt.badge.automatic.fill"
        @unknown default:
            return "bolt.slash.fill"
        }
    }
    
    var body: some View {
        ZStack {
            // Camera preview (bottom layer)
            if cameraModel.isCameraAuthorized && !isProcessing {
                CameraPreview(cameraModel: cameraModel)
                    .ignoresSafeArea()
                    .opacity(cameraModel.isSessionReady ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: cameraModel.isSessionReady)
            } else {
                // Fallback background when camera not available
                MagicalBackground()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.3))
            }
            
            // Scanning overlay
            if !isProcessing && !showingPreview {
                ScanningOverlay(scanLineOffset: $scanLineOffset)
                    .ignoresSafeArea()
            }
            
            // UI overlay
            if !showingPreview {
                VStack {
                    // Top bar
                    CameraTopBar(onClose: { 
                        // Try dismiss first (for modal presentation)
                        dismiss()
                        // Also set tab to 0 (for tab presentation)
                        selectedTab = 0
                    })
                    
                    Spacer()
                    
                    // Instructions
                    CameraControlsEnhanced(
                        cameraModel: cameraModel,
                        capturePhoto: capturePhoto,
                        isProcessing: isProcessing,
                        captureAnimation: $captureAnimation
                    )
                    
                    // Bottom controls with capture button and test button
                    VStack(spacing: 20) {
                        // Capture button
                        CaptureButtonEnhanced(
                            action: capturePhoto,
                            isDisabled: isProcessing || !cameraModel.isSessionReady,
                            triggerAnimation: $captureAnimation
                        )
                        
                        // TEMPORARY TEST BUTTON
                        Button(action: {
                            processTestImage()
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Test with Fridge Image")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.8))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(isProcessing)
                        .opacity(isProcessing ? 0.5 : 1)
                    }
                    .padding(.bottom, 50)
                }
            }
            
            // Processing overlay
            if isProcessing {
                MagicalProcessingOverlay(capturedImage: capturedImage)
            }
            
            // Captured image preview
            if showingPreview, let image = capturedImage {
                CapturedImageView(
                    image: image,
                    onRetake: {
                        showingPreview = false
                        capturedImage = nil
                    },
                    onConfirm: {
                        showingPreview = false
                        processImage(image)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 1.1)))
            }
            
            // Welcome message
            if showWelcomeMessage {
                VStack {
                    Spacer()
                    Text("Yay! This will be fun! 🎉")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "#667eea").opacity(0.9))
                                .shadow(radius: 20)
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    Spacer()
                }
            }
        }
        .onAppear {
            startScanAnimation()
            
            // Track screen view
            Task {
                await cloudKitDataManager.trackScreenView("Camera")
            }
            
            // Check if this is the first time
            let hasSeenCamera = UserDefaults.standard.bool(forKey: "hasSeenCameraView")
            if !hasSeenCamera {
                // First time - show confetti and message
                showConfetti = true
                showWelcomeMessage = true
                UserDefaults.standard.set(true, forKey: "hasSeenCameraView")
                
                // Hide message after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showWelcomeMessage = false
                    }
                }
            }
            
            // Request permission and setup camera with delay
            Task {
                // Small delay to ensure view is fully loaded
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                await MainActor.run {
                    cameraModel.requestCameraPermission()
                }
            }
        }
        .particleExplosion(trigger: $showConfetti)
        .onDisappear {
            cameraModel.stopSession()
        }
        .fullScreenCover(isPresented: $showingResults) {
            RecipeResultsView(
                recipes: generatedRecipes,
                ingredients: detectedIngredients,
                capturedImage: capturedImage
            )
            .onDisappear {
                // When recipe results are dismissed, also dismiss the camera
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $showingUpgrade, onDismiss: {
            // Restart camera when returning from upgrade screen
            if !isProcessing {
                cameraModel.requestCameraPermission()
            }
        }) {
            SubscriptionView()
                .environmentObject(deviceManager)
        }
        .errorAlert($currentError) {
            // Handle retry for network errors
            if case .networkError = currentError {
                // Retry last action
            }
        }
        .overlay(
            VStack {
                if showSuccess {
                    SuccessToast(message: successMessage) {
                        showSuccess = false
                    }
                    .padding(.top, 50)
                }
                Spacer()
            }
        )
        .overlay(
            // Premium upgrade prompt
            Group {
                if showPremiumPrompt {
                    PremiumUpgradePrompt(
                        isPresented: $showPremiumPrompt,
                        reason: premiumPromptReason
                    )
                }
            }
        )
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func startScanAnimation() {
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
            scanLineOffset = 200
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
    }
    
    private func capturePhoto() {
        // Trigger capture animation
        captureAnimation = true
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        cameraModel.capturePhoto { image in
            capturedImage = image
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingPreview = true
            }
            
            // Track daily snap streak
            Task {
                await StreakManager.shared.recordActivity(for: .dailySnap)
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        isProcessing = true
        capturedImage = image // Store the captured image
        
        // Stop camera session to save resources while processing
        cameraModel.stopSession()
        
        Task {
            // Check subscription status
            if !subscriptionManager.isPremium {
                let remainingRecipes = subscriptionManager.getRemainingDailyRecipes()
                if remainingRecipes <= 0 {
                    isProcessing = false
                    premiumPromptReason = .dailyLimitReached
                    showPremiumPrompt = true
                    cameraModel.requestCameraPermission()
                    return
                }
            }
            
            // No need to consume free uses - we track daily count in SubscriptionManager
            
            // Generate session ID
            let sessionId = UUID().uuidString
            
            // Track camera session start
            let sessionData = CameraSessionData(
                sessionID: sessionId,
                captureType: "fridge_snap",
                flashEnabled: cameraModel.flashMode == .on,
                ingredientsDetected: [],
                recipesGenerated: 0,
                aiModel: UserDefaults.standard.string(forKey: "SelectedLLMProvider") ?? "grok",
                processingTime: 0
            )
            let startTime = Date()
            
            // Get existing recipe names to avoid duplicates
            let existingRecipeNames = appState.allRecipes.map { $0.name }
            
            // Get food preferences from UserDefaults
            let foodPreferences = UserDefaults.standard.stringArray(forKey: "SelectedFoodPreferences") ?? []
            
            // If user has food preferences but no specific food type selected, use preferences
            let effectiveFoodType: String? = if !foodPreferences.isEmpty && selectedFoodType == nil {
                // Join preferences into a string for the foodType parameter
                foodPreferences.joined(separator: ", ")
            } else {
                selectedFoodType
            }
            
            // Get selected LLM provider from UserDefaults
            let llmProvider = UserDefaults.standard.string(forKey: "SelectedLLMProvider") ?? "grok"
            
            // Call the API
            SnapChefAPIManager.shared.sendImageForRecipeGeneration(
                image: image,
                sessionId: sessionId,
                dietaryRestrictions: currentDietaryRestrictions,
                foodType: effectiveFoodType,
                difficultyPreference: selectedDifficulty,
                healthPreference: selectedHealthPreference,
                mealType: selectedMealType,
                cookingTimePreference: selectedCookingTime,
                numberOfRecipes: numberOfRecipes,
                existingRecipeNames: existingRecipeNames,
                foodPreferences: foodPreferences,
                llmProvider: llmProvider
            ) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let apiResponse):
                        // Convert API recipes to app recipes
                        let recipes = apiResponse.data.recipes.map { apiRecipe in
                            SnapChefAPIManager.shared.convertAPIRecipeToAppRecipe(apiRecipe)
                        }
                        
                        // Update state
                        self.generatedRecipes = recipes
                        self.detectedIngredients = apiResponse.data.ingredients
                        
                        // Track camera session completion
                        let processingTime = Date().timeIntervalSince(startTime)
                        let completedSession = CameraSessionData(
                            sessionID: sessionId,
                            captureType: "fridge_snap",
                            flashEnabled: cameraModel.flashMode == .on,
                            ingredientsDetected: apiResponse.data.ingredients.map { $0.name },
                            recipesGenerated: recipes.count,
                            aiModel: llmProvider,
                            processingTime: processingTime
                        )
                        await cloudKitDataManager.trackCameraSession(completedSession)
                        
                        // Track recipe generation
                        for recipe in recipes {
                            let generationData = RecipeGenerationData(
                                sessionID: sessionId,
                                recipe: recipe,
                                ingredients: apiResponse.data.ingredients.map { $0.name },
                                preferencesJSON: String(describing: [
                                    "dietary": currentDietaryRestrictions,
                                    "foodType": effectiveFoodType ?? "",
                                    "difficulty": selectedDifficulty ?? "",
                                    "health": selectedHealthPreference ?? "",
                                    "mealType": selectedMealType ?? "",
                                    "cookingTime": selectedCookingTime ?? ""
                                ]),
                                generationTime: processingTime / Double(recipes.count),
                                quality: "high"
                            )
                            await cloudKitDataManager.trackRecipeGeneration(generationData)
                        }
                        
                        // Track feature usage
                        await cloudKitDataManager.trackFeatureUse("recipe_generation")
                        
                        // Save recipes to CloudKit
                        for recipe in recipes {
                            do {
                                let recipeID = try await cloudKitRecipeManager.uploadRecipe(recipe, fromLLM: true)
                                print("✅ Recipe saved to CloudKit with ID: \(recipeID)")
                                
                                // Also add to user's saved recipes list
                                try await cloudKitRecipeManager.addRecipeToUserProfile(recipeID, type: .saved)
                                print("✅ Recipe added to user's saved list")
                            } catch {
                                print("❌ Failed to save recipe to CloudKit: \(error)")
                            }
                        }
                        
                        // Increment snaps taken counter
                        self.appState.incrementSnapsTaken()
                        
                        // Increment daily recipe count if not premium
                        if !self.subscriptionManager.isPremium {
                            self.subscriptionManager.incrementDailyRecipeCount()
                        }
                        
                        // Track challenge progress for recipe creation
                        for recipe in recipes {
                            // Post notification for recipe creation
                            NotificationCenter.default.post(
                                name: Notification.Name("RecipeCreated"),
                                object: recipe
                            )
                            
                            // Award coins based on recipe quality
                            let quality = self.determineRecipeQuality(recipe)
                            ChefCoinsManager.shared.awardRecipeCreationCoins(recipeQuality: quality)
                            
                            // Track specific challenge actions
                            if recipe.nutrition.calories < 500 {
                                ChallengeProgressTracker.shared.trackAction(.calorieTarget, metadata: [
                                    "calories": recipe.nutrition.calories,
                                    "recipeId": recipe.id
                                ])
                            }
                            
                            if recipe.nutrition.protein >= 20 {
                                ChallengeProgressTracker.shared.trackAction(.proteinTarget, metadata: [
                                    "protein": recipe.nutrition.protein,
                                    "recipeId": recipe.id
                                ])
                            }
                            
                            // Track cuisine if available in tags
                            if let cuisineTag = recipe.tags.first(where: { tag in
                                ["italian", "mexican", "chinese", "japanese", "thai", "indian", "french", "american"].contains(tag.lowercased())
                            }) {
                                ChallengeProgressTracker.shared.trackAction(.cuisineExplored, metadata: [
                                    "cuisine": cuisineTag,
                                    "recipeId": recipe.id
                                ])
                            }
                            
                            // Check for speed challenges
                            if recipe.prepTime + recipe.cookTime <= 30 {
                                ChallengeProgressTracker.shared.trackAction(.timeCompleted, metadata: [
                                    "totalTime": recipe.prepTime + recipe.cookTime,
                                    "recipeId": recipe.id
                                ])
                            }
                            
                            // Track analytics for recipe creation
                            ChallengeAnalyticsService.shared.trackEvent(.milestoneReached, parameters: [
                                "milestone": "recipe_created",
                                "quality": quality.rawValue,
                                "calories": recipe.nutrition.calories,
                                "protein": recipe.nutrition.protein,
                                "totalTime": recipe.prepTime + recipe.cookTime,
                                "difficulty": recipe.difficulty,
                                "recipeId": recipe.id.uuidString
                            ])
                        }
                        
                        // Don't auto-save recipes - user will choose which ones to save
                        // Store the captured image for later use
                        self.capturedImage = image
                        
                        // Update UI on main thread
                        self.generatedRecipes = recipes
                        self.detectedIngredients = apiResponse.data.ingredients
                        self.resultsPreloaded = true
                        
                        // Dismiss processing overlay first
                        self.isProcessing = false
                        
                        // Small delay to ensure smooth transition
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.showingResults = true
                        }
                        
                    case .failure(let error):
                        self.isProcessing = false
                        
                        // Convert API errors to user-friendly errors
                        if case APIError.authenticationError = error {
                            self.currentError = .authenticationError("Authentication failed")
                        } else if case APIError.serverError(_, let message) = error {
                            self.currentError = .apiError("Server error: \(message)")
                        } else {
                            self.currentError = .unknown(error.localizedDescription)
                        }
                        
                        // Restart camera session on error
                        self.cameraModel.requestCameraPermission()
                    }
                }
            }
        }
    }
    
    private func processTestImage() {
        // Load the test fridge image from bundle
        guard let testImage = UIImage(named: "fridge.jpg") else {
            print("Failed to load test fridge image")
            return
        }
        
        // Increment snap counter for test button too
        appState.incrementSnapsTaken()
        
        // Process it the same way as a captured photo
        processImage(testImage)
    }
    
    private func determineRecipeQuality(_ recipe: Recipe) -> RecipeQuality {
        var score = 0
        
        // Check nutrition balance
        let nutrition = recipe.nutrition
        if nutrition.calories > 0 && nutrition.calories < 800 {
            score += 1
        }
        if nutrition.protein >= 15 {
            score += 1
        }
        if nutrition.carbs > 0 && nutrition.carbs < 60 {
            score += 1
        }
        
        // Check recipe completeness
        if recipe.ingredients.count >= 5 {
            score += 1
        }
        if recipe.instructions.count >= 3 {
            score += 1
        }
        if !recipe.tags.isEmpty {
            score += 1
        }
        
        // Determine quality based on score
        switch score {
        case 0...2:
            return .basic
        case 3...4:
            return .good
        case 5:
            return .excellent
        case 6...:
            return .perfect
        default:
            return .basic
        }
    }
}

// MARK: - Camera Top Bar
struct CameraTopBar: View {
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            // Close button
            Button(action: { onClose() }) {
                ZStack {
                    BlurredCircle()
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // AI Assistant
            AIAssistantIndicator()
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
}

struct BlurredCircle: View {
    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - AI Assistant Indicator
struct AIAssistantIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                        .scaleEffect(isAnimating ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            
            Text("AI Ready")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Scanning Overlay
struct ScanningOverlay: View {
    @Binding var scanLineOffset: CGFloat
    @State private var cornerAnimation = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Corner brackets
                ForEach(0..<4) { index in
                    CornerBracket(corner: index)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#4facfe"),
                                    Color(hex: "#00f2fe")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 60, height: 60)
                        .position(cornerPosition(for: index, in: geometry.size))
                        .scaleEffect(cornerAnimation ? 1.1 : 1)
                        .opacity(cornerAnimation ? 0.8 : 1)
                }
                
                // Scanning line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color(hex: "#4facfe").opacity(0.5),
                                Color(hex: "#00f2fe"),
                                Color(hex: "#4facfe").opacity(0.5),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .blur(radius: 1)
                    .offset(y: scanLineOffset)
                
                // Center focus
                Image(systemName: "viewfinder")
                    .font(.system(size: 200, weight: .ultraLight))
                    .foregroundColor(Color.white.opacity(0.1))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                cornerAnimation = true
            }
        }
    }
    
    private func cornerPosition(for index: Int, in size: CGSize) -> CGPoint {
        let padding: CGFloat = 60
        switch index {
        case 0: return CGPoint(x: padding, y: padding)
        case 1: return CGPoint(x: size.width - padding, y: padding)
        case 2: return CGPoint(x: padding, y: size.height - padding)
        case 3: return CGPoint(x: size.width - padding, y: size.height - padding)
        default: return .zero
        }
    }
}

struct CornerBracket: Shape {
    let corner: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = 20
        
        switch corner {
        case 0: // Top left
            path.move(to: CGPoint(x: 0, y: length))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: length, y: 0))
        case 1: // Top right
            path.move(to: CGPoint(x: rect.width - length, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: length))
        case 2: // Bottom left
            path.move(to: CGPoint(x: 0, y: rect.height - length))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: length, y: rect.height))
        case 3: // Bottom right
            path.move(to: CGPoint(x: rect.width - length, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - length))
        default:
            break
        }
        
        return path
    }
}

// MARK: - Enhanced Camera Controls
struct CameraControlsEnhanced: View {
    let cameraModel: CameraModel
    let capturePhoto: () -> Void
    let isProcessing: Bool
    @Binding var captureAnimation: Bool
    
    var body: some View {
        // Instructions only
        if !isProcessing {
            Text(cameraModel.isSessionReady ? "Point at your fridge or pantry" : "Initializing camera...")
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.bottom, 30) // Add spacing below instructions
        }
    }
}

struct CaptureButtonEnhanced: View {
    let action: () -> Void
    let isDisabled: Bool
    @Binding var triggerAnimation: Bool
    
    @State private var isPressed = false
    @State private var ringScale: CGFloat = 1
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring with animation
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#4facfe"),
                                Color(hex: "#00f2fe")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 90, height: 90)
                    .scaleEffect(ringScale)
                    .opacity(triggerAnimation ? 0 : 1)
                
                // Inner circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 75, height: 75)
                    .scaleEffect(isPressed ? 0.9 : 1)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, y: 3)
                
                // Center icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color(hex: "#667eea"))
            }
        }
        .disabled(isDisabled)
        .scaleEffect(isPressed ? 0.95 : 1)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onChange(of: triggerAnimation) { _ in
            if triggerAnimation {
                withAnimation(.easeOut(duration: 0.6)) {
                    ringScale = 1.5
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    triggerAnimation = false
                    ringScale = 1
                }
            }
        }
    }
}

// MagicalProcessingOverlay is now defined in PhysicsLoadingOverlay.swift

#Preview {
    CameraView()
        .environmentObject(AppState())
        .environmentObject(DeviceManager())
}