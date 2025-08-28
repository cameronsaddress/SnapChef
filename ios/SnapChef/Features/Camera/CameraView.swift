import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var cameraModel = CameraModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var usageTracker = UsageTracker.shared
    @StateObject private var userLifecycleManager = UserLifecycleManager.shared
    @StateObject private var paywallTriggerManager = PaywallTriggerManager.shared
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var cloudKitDataManager: CloudKitDataManager
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    @Binding var selectedTab: Int
    
    // Performance optimization: Lazy loading of heavy views
    @State private var shouldShowFullUI = false

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
    @State private var isClosing = false

    // Two-step capture flow state
    enum CaptureMode {
        case fridge
        case pantry
    }

    @State private var captureMode: CaptureMode = .fridge
    @State private var fridgePhoto: UIImage?
    @State private var showPantryStep = false

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

            // Scanning overlay (OptimizedScanningOverlay temporarily commented out)
            if !isProcessing && !showingPreview && shouldShowFullUI {
                // TODO: Implement OptimizedScanningOverlay
                ScanningOverlay(scanLineOffset: $scanLineOffset)
                    .ignoresSafeArea()
            }

            // Optimized UI overlay - load components progressively
            if !showingPreview && shouldShowFullUI {
                VStack {
                    // Top controls (CameraTopControls temporarily commented out)
                    // TODO: Implement CameraTopControls
                    CameraTopBar(onClose: {
                        // Start closing animation
                        withAnimation(.easeOut(duration: 0.2)) {
                            isClosing = true
                            shouldShowFullUI = false
                        }
                        
                        // Small delay for smooth animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            // Stop camera session only if it's running
                            if cameraModel.isSessionReady {
                                cameraModel.stopSession()
                            }
                            resetCaptureFlow()
                            
                            // Switch tabs after animation
                            selectedTab = 0
                            
                            // Reset closing state for next time
                            isClosing = false
                        }
                    })
                    
                    Spacer()
                    
                    // Bottom controls (CameraBottomControls temporarily commented out)
                    // TODO: Implement CameraBottomControls
                    VStack(spacing: 20) {
                        CaptureButtonEnhanced(
                            action: capturePhoto,
                            isDisabled: isProcessing,
                            triggerAnimation: $captureAnimation
                        )
                        .padding(.bottom, 50)
                    }
                }
            }

            // Overlays component (CameraOverlays temporarily commented out)
            // TODO: Implement CameraOverlays
            if isProcessing {
                MagicalBackground()
                    .ignoresSafeArea()
                    .overlay(
                        MagicalProcessingOverlay(capturedImage: capturedImage, onClose: {
                            // Stop processing and go back
                            isProcessing = false
                            capturedImage = nil
                            fridgePhoto = nil
                            captureMode = .fridge
                            showPantryStep = false
                            
                            // Navigate back to home tab immediately
                            selectedTab = 0
                        })
                    )
            }
            
            // Black overlay when closing to prevent frozen frame
            if isClosing {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // Preview overlay
            if showingPreview, let image = capturedImage {
                ZStack {
                    // Black background
                    Color.black.ignoresSafeArea()
                    
                    // Full screen photo with proper aspect ratio
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea()
                    
                    // Buttons overlaying directly on image
                    VStack {
                        Spacer()
                        
                        // Buttons positioned at bottom
                        HStack(spacing: 60) {
                            // Retake button
                            Button(action: {
                                showingPreview = false
                                capturedImage = nil
                            }) {
                                Text("Retake")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.5))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.5), radius: 8, y: 4)
                            }
                            
                            // Confirm button with green checkmark
                            VStack(spacing: 8) {
                                Button(action: {
                                    showingPreview = false
                                    if captureMode == .fridge {
                                        fridgePhoto = capturedImage
                                        captureMode = .pantry
                                        showPantryStep = true
                                    } else {
                                        if let fridgeImage = fridgePhoto {
                                            processBothImages(fridgeImage: fridgeImage, pantryImage: capturedImage!)
                                        }
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 70, height: 70)
                                            .shadow(color: Color.green.opacity(0.6), radius: 12, y: 6)
                                        
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                Text("Looks Good!")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                            }
                        }
                        .padding(.bottom, 60)
                    }
                }
            }
        }
        .onAppear {
            print("🔍 DEBUG: CameraView appeared - Start")
            // Reset closing state when view appears
            isClosing = false
            DispatchQueue.main.async {
                print("🔍 DEBUG: CameraView - Async block started")
                // Performance optimization: Progressive loading
                setupViewProgressively()
                print("🔍 DEBUG: CameraView - Async block completed")
            }
            print("🔍 DEBUG: CameraView appeared - End")
        }
        // Particle explosion only if effects are enabled
        .modifier(ConditionalParticleExplosion(
            trigger: $showConfetti,
            enabled: deviceManager.shouldShowParticles
        ))
        .onDisappear {
            // Clean up when view disappears
            // The camera session will be stopped by CameraModel's cleanup
            resetCaptureFlow()
        }
        .fullScreenCover(isPresented: $showingResults) {
            RecipeResultsView(
                recipes: generatedRecipes,
                ingredients: detectedIngredients,
                capturedImage: capturedImage,
                isPresented: $showingResults  // Pass binding to control dismissal
            )
            .onDisappear {
                // When recipe results are dismissed, go back to home tab
                selectedTab = 0 // Switch to home tab
                // Reset the capture flow for next time
                resetCaptureFlow()
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
        } onRetry: {
            // Handle retry action - re-process the last captured image
            if let image = capturedImage {
                processImage(image)
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
                    .onDisappear {
                        // Record dismissal if user dismisses without upgrading
                        if !subscriptionManager.isPremium {
                            paywallTriggerManager.recordPaywallDismissed()
                        } else {
                            // User converted!
                            paywallTriggerManager.recordPaywallConverted()
                        }
                    }
                }
            }
        )
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .overlay(
            // Pantry step overlay
            Group {
                if showPantryStep {
                    PantryStepOverlay(
                        fridgePhoto: fridgePhoto,
                        onSkip: {
                            // Process only fridge photo
                            showPantryStep = false
                            if let fridgeImage = fridgePhoto {
                                processImage(fridgeImage)
                            }
                            resetCaptureFlow()
                        },
                        onContinue: {
                            // Continue to pantry capture
                            showPantryStep = false
                        },
                        onBack: {
                            // Go back to fridge capture
                            showPantryStep = false
                            captureMode = .fridge
                            fridgePhoto = nil
                            showingPreview = true
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            }
        )
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
    
    // Test function for development - sends a test fridge image
    private func sendTestFridgeImage() {
        // List of available test images
        let testImages = ["fridge", "fridge1", "fridge2", "fridge3", "fridge4", "fridge5"]
        let randomImage = testImages.randomElement() ?? "fridge2"
        
        // Try multiple methods to load the test image
        var testImage: UIImage?
        
        // Method 1: Try with .jpg extension
        testImage = UIImage(named: "\(randomImage).jpg")
        
        // Method 2: Try without extension
        if testImage == nil {
            testImage = UIImage(named: randomImage)
        }
        
        // Method 3: Try loading from bundle directly
        if testImage == nil {
            if let imagePath = Bundle.main.path(forResource: randomImage, ofType: "jpg") {
                testImage = UIImage(contentsOfFile: imagePath)
                print("✅ Loaded test image from bundle path: \(imagePath)")
            }
        }
        
        // If still no image, show error
        guard let loadedImage = testImage else {
            print("❌ Test image '\(randomImage)' not found in bundle")
            print("📁 Trying to list available resources...")
            
            // Debug: Try to list what's actually available
            if let resourcePath = Bundle.main.resourcePath {
                do {
                    let items = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    let jpgFiles = items.filter { $0.hasSuffix(".jpg") }
                    print("📷 Available JPG files in bundle: \(jpgFiles)")
                } catch {
                    print("❌ Could not list bundle resources: \(error)")
                }
            }
            
            currentError = .imageProcessingError("Test image '\(randomImage)' not found. Please check Resources folder.")
            return
        }
        
        print("📸 Successfully loaded test image: \(randomImage).jpg")
        print("📐 Image size: \(loadedImage.size.width) x \(loadedImage.size.height)")
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Process the test image directly
        capturedImage = loadedImage
        processImage(loadedImage)
        
        // Track as test snap (not daily snap)
        Task {
            print("🧪 Test mode: Processing test fridge image '\(randomImage).jpg'")
            print("📤 Sending to Render server for recipe generation...")
        }
    }

    private func processImage(_ image: UIImage) {
        isProcessing = true
        capturedImage = image // Store the captured image

        // Stop camera session to save resources while processing
        cameraModel.stopSession()

        Task {
            // Check subscription status and usage limits
            if !subscriptionManager.isPremium {
                if usageTracker.hasReachedRecipeLimit() {
                    isProcessing = false

                    // Record paywall shown and trigger it
                    if paywallTriggerManager.shouldShowPaywall(for: .recipeLimitReached) {
                        paywallTriggerManager.recordPaywallShown(context: .recipeLimitReached)
                        premiumPromptReason = .dailyLimitReached
                        showPremiumPrompt = true
                    }

                    cameraModel.requestCameraPermission()
                    return
                }
            }

            // No need to consume free uses - we track daily count in SubscriptionManager

            // Generate session ID
            let sessionId = UUID().uuidString

            // Track camera session start
            let _ = CameraSessionData(
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
            // Include both local recipes and CloudKit recipes
            var existingRecipeNames = appState.allRecipes.map { $0.name }

            // Fetch CloudKit recipes to include them in duplicate prevention
            print("📱 Fetching CloudKit recipes for duplicate prevention...")
            do {
                let cloudKitSavedRecipes = try await cloudKitRecipeManager.getUserSavedRecipes()
                let cloudKitCreatedRecipes = try await cloudKitRecipeManager.getUserCreatedRecipes()

                // Add CloudKit recipe names to the list
                let cloudKitRecipeNames = (cloudKitSavedRecipes + cloudKitCreatedRecipes).map { $0.name }
                existingRecipeNames.append(contentsOf: cloudKitRecipeNames)

                // Remove duplicates
                existingRecipeNames = Array(Set(existingRecipeNames))

                print("✅ Total recipes for duplicate prevention: \(existingRecipeNames.count) (Local: \(appState.allRecipes.count), CloudKit: \(cloudKitRecipeNames.count))")
            } catch {
                print("⚠️ Failed to fetch CloudKit recipes for duplicate prevention: \(error)")
                // Continue with just local recipes
            }

            // Get food preferences from UserDefaults
            let foodPreferences = UserDefaults.standard.stringArray(forKey: "SelectedFoodPreferences") ?? []

            // If user has food preferences but no specific food type selected, use preferences
            let effectiveFoodType: String? = if !foodPreferences.isEmpty && selectedFoodType == nil {
                // Join preferences into a string for the foodType parameter
                foodPreferences.joined(separator: ", ")
            } else {
                selectedFoodType
            }

            // Get selected LLM provider from UserDefaults (default to Gemini)
            let llmProvider = UserDefaults.standard.string(forKey: "SelectedLLMProvider") ?? "gemini"

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

                        // 🔍 DEBUG: Log converted recipes in CameraView (single image)
                        print("🔍 DEBUG: CameraView - Converted \(recipes.count) recipes from API (single image)")
                        for (index, recipe) in recipes.enumerated() {
                            print("🔍 CAMERA RECIPE \(index + 1) FINAL STATE:")
                            print("🔍   - name: \(recipe.name)")
                            print("🔍   - cookingTechniques: \(recipe.cookingTechniques.isEmpty ? "EMPTY" : "\(recipe.cookingTechniques)")")
                            print("🔍   - secretIngredients: \(recipe.secretIngredients.isEmpty ? "EMPTY" : "\(recipe.secretIngredients)")")
                            print("🔍   - proTips: \(recipe.proTips.isEmpty ? "EMPTY" : "\(recipe.proTips)")")
                            print("🔍   - visualClues: \(recipe.visualClues.isEmpty ? "EMPTY" : "\(recipe.visualClues)")")
                            print("🔍   - shareCaption: \(recipe.shareCaption.isEmpty ? "EMPTY" : "\"\(recipe.shareCaption)\"")")
                        }

                        // Update state immediately for UI
                        self.generatedRecipes = recipes
                        self.detectedIngredients = apiResponse.data.ingredients
                        self.capturedImage = image
                        self.resultsPreloaded = true

                        // Store the fridge photo for all generated recipes
                        // IMPORTANT: Use 'image' parameter directly, not self.capturedImage which isn't set yet
                        print("📸 CameraView: Storing fridge photo in PhotoStorageManager for \(recipes.count) recipes")
                        PhotoStorageManager.shared.storeFridgePhoto(
                            image,  // Use the image parameter passed to processImage
                            for: recipes.map { $0.id }
                        )

                        // Dismiss processing overlay first
                        self.isProcessing = false

                        // Navigate to results immediately - user sees recipes right away!
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                            self.showingResults = true
                        }

                        // Capture values before entering detached task (these are @MainActor properties)
                        let flashEnabled = cameraModel.flashMode == .on
                        let dietaryRestrictions = currentDietaryRestrictions
                        let foodType = effectiveFoodType
                        let difficulty = selectedDifficulty
                        let health = selectedHealthPreference
                        let mealType = selectedMealType
                        let cookingTime = selectedCookingTime

                        // BACKGROUND SAVING: Queue CloudKit upload for background processing
                        Task.detached(priority: .background) {
                            do {
                                // Check if recipes already exist in CloudKit before uploading
                                print("📱 Background: Checking for duplicate recipes before CloudKit upload...")
                                var recipesToUpload: [Recipe] = []
                                
                                // Only proceed with CloudKit saving if user is authenticated
                                guard await UnifiedAuthManager.shared.isAuthenticated else {
                                    print("📱 Background: User not authenticated - skipping CloudKit saving")
                                    return
                                }
                                
                                // Check for duplicates before uploading
                                for recipe in recipes {
                                    let existingID = await cloudKitRecipeManager.checkRecipeExists(recipe.name, recipe.description)
                                    if existingID == nil {
                                        recipesToUpload.append(recipe)
                                        print("📱 Background: Recipe '\(recipe.name)' will be uploaded")
                                    } else {
                                        print("📱 Background: Recipe '\(recipe.name)' already exists in CloudKit, skipping upload")
                                    }
                                }
                                
                                if recipesToUpload.isEmpty {
                                    print("📱 Background: All recipes already exist in CloudKit, skipping upload")
                                    return
                                }
                                
                                // Track camera session completion
                                let processingTime = Date().timeIntervalSince(startTime)
                                let completedSession = CameraSessionData(
                                    sessionID: sessionId,
                                    captureType: "fridge_snap",
                                    flashEnabled: flashEnabled,
                                    ingredientsDetected: apiResponse.data.ingredients.map { $0.name },
                                    recipesGenerated: recipes.count,
                                    aiModel: llmProvider,
                                    processingTime: processingTime
                                )
                                await cloudKitDataManager.trackCameraSession(completedSession)

                                // Track usage with UsageTracker for daily limits
                                await MainActor.run {
                                    self.usageTracker.trackRecipeGenerated()
                                    self.userLifecycleManager.trackRecipeCreated()
                                }

                                // Track recipe generation
                                for recipe in recipes {
                                    let generationData = RecipeGenerationData(
                                        sessionID: sessionId,
                                        recipe: recipe,
                                        ingredients: apiResponse.data.ingredients.map { $0.name },
                                        preferencesJSON: String(describing: [
                                            "dietary": dietaryRestrictions,
                                            "foodType": foodType ?? "",
                                            "difficulty": difficulty ?? "",
                                            "health": health ?? "",
                                            "mealType": mealType ?? "",
                                            "cookingTime": cookingTime ?? ""
                                        ]),
                                        generationTime: processingTime / Double(recipes.count),
                                        quality: "high"
                                    )
                                    await cloudKitDataManager.trackRecipeGeneration(generationData)
                                }

                                // Track feature usage
                                await cloudKitDataManager.trackFeatureUse("recipe_generation")

                                // Check if paywall should be triggered after successful generation
                                if let suggestedContext = await MainActor.run { self.paywallTriggerManager.getSuggestedPaywallContext() } {
                                    if await MainActor.run { self.paywallTriggerManager.shouldShowPaywall(for: suggestedContext) } {
                                        await MainActor.run {
                                            self.premiumPromptReason = .dailyLimitReached
                                            self.showPremiumPrompt = true
                                        }
                                    }
                                }

                                // Save only new recipes to CloudKit with the captured fridge photo
                                print("📸 Background: Uploading \(recipesToUpload.count) new recipes to CloudKit...")
                                for (index, recipe) in recipesToUpload.enumerated() {
                                    do {
                                        print("📸 Background: Uploading recipe \(index + 1)/\(recipesToUpload.count): '\(recipe.name)'")
                                        let recipeID = try await cloudKitRecipeManager.uploadRecipe(recipe, fromLLM: true, beforePhoto: image)
                                        print("✅ Background: Recipe \(index + 1)/\(recipesToUpload.count) saved to CloudKit with ID: \(recipeID) and shared before photo")

                                        // Also add to user's saved recipes list
                                        try await cloudKitRecipeManager.addRecipeToUserProfile(recipeID, type: .saved)
                                        print("✅ Background: Recipe added to user's saved list")
                                    } catch {
                                        print("❌ Background: Failed to save recipe \(index + 1)/\(recipesToUpload.count) to CloudKit: \(error)")
                                    }
                                }
                                print("✅ Background: All \(recipesToUpload.count) new recipes have been saved with the fridge photo")

                                // Increment snaps taken counter
                                await MainActor.run {
                                    self.appState.incrementSnapsTaken()
                                }

                                // Increment daily recipe count if not premium
                                await MainActor.run {
                                    if !self.subscriptionManager.isPremium {
                                        self.subscriptionManager.incrementDailyRecipeCount()
                                    }
                                }

                                // Track challenge progress for recipe creation
                                for recipe in recipes {
                                    // Post notification for recipe creation
                                    await MainActor.run {
                                        NotificationCenter.default.post(
                                            name: Notification.Name("RecipeCreated"),
                                            object: recipe
                                        )
                                    }

                                    // Award coins based on recipe quality
                                    let quality = await MainActor.run { self.determineRecipeQuality(recipe) }
                                    await MainActor.run {
                                        ChefCoinsManager.shared.awardRecipeCreationCoins(recipeQuality: quality)
                                    }

                                    // Track specific challenge actions
                                    if recipe.nutrition.calories < 500 {
                                        await MainActor.run {
                                            ChallengeProgressTracker.shared.trackAction(.calorieTarget, metadata: [
                                                "calories": recipe.nutrition.calories,
                                                "recipeId": recipe.id
                                            ])
                                        }
                                    }

                                    if recipe.nutrition.protein >= 20 {
                                        await MainActor.run {
                                            ChallengeProgressTracker.shared.trackAction(.proteinTarget, metadata: [
                                                "protein": recipe.nutrition.protein,
                                                "recipeId": recipe.id
                                            ])
                                        }
                                    }

                                    // Track cuisine if available in tags
                                    if let cuisineTag = recipe.tags.first(where: { tag in
                                        ["italian", "mexican", "chinese", "japanese", "thai", "indian", "french", "american"].contains(tag.lowercased())
                                    }) {
                                        await MainActor.run {
                                            ChallengeProgressTracker.shared.trackAction(.cuisineExplored, metadata: [
                                                "cuisine": cuisineTag,
                                                "recipeId": recipe.id
                                            ])
                                        }
                                    }

                                    // Check for speed challenges
                                    if recipe.prepTime + recipe.cookTime <= 30 {
                                        await MainActor.run {
                                            ChallengeProgressTracker.shared.trackAction(.timeCompleted, metadata: [
                                                "totalTime": recipe.prepTime + recipe.cookTime,
                                                "recipeId": recipe.id
                                            ])
                                        }
                                    }

                                    // Track analytics for recipe creation
                                    await MainActor.run {
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
                                }
                            } catch {
                                print("❌ Background saving failed: \(error)")
                            }
                        }

                    case .failure(let error):
                        self.isProcessing = false

                        // Convert API errors to user-friendly SnapChef errors with appropriate recovery strategies
                        if case APIError.authenticationError = error {
                            // API auth error - this is about the backend API key, not user auth
                            self.currentError = .apiError("Server authentication failed. Please try again later.", recovery: .retry)
                        } else if case APIError.notFoodImage(let message) = error {
                            // Use imageProcessingError for non-food images with retry recovery
                            self.currentError = .imageProcessingError(message, recovery: .retry)
                        } else if case APIError.noIngredientsDetected(let message) = error {
                            // Use recipeGenerationError for ingredient detection issues with retry recovery
                            self.currentError = .recipeGenerationError(message, recovery: .retry)
                        } else if case APIError.serverError(_, let message) = error {
                            self.currentError = .apiError("Server error: \(message)", recovery: .retry)
                        } else if case APIError.unauthorized(let message) = error {
                            // This is about missing API key in the app, not user authentication
                            self.currentError = .apiError(message, recovery: .retry)
                        } else {
                            self.currentError = .unknown(error.localizedDescription, recovery: .retry)
                        }

                        // Restart camera session on error
                        self.cameraModel.requestCameraPermission()
                    }
                }
            }
        }
    }

    private func processBothImages(fridgeImage: UIImage, pantryImage: UIImage) {
        isProcessing = true
        capturedImage = fridgeImage // Store the fridge image as the primary image

        // Stop camera session to save resources while processing
        cameraModel.stopSession()

        Task {
            // Check subscription status and usage limits for dual images
            if !subscriptionManager.isPremium {
                if usageTracker.hasReachedRecipeLimit() {
                    isProcessing = false

                    // Record paywall shown and trigger it
                    if paywallTriggerManager.shouldShowPaywall(for: .recipeLimitReached) {
                        paywallTriggerManager.recordPaywallShown(context: .recipeLimitReached)
                        premiumPromptReason = .dailyLimitReached
                        showPremiumPrompt = true
                    }

                    cameraModel.requestCameraPermission()
                    return
                }
            }

            // Generate session ID
            let sessionId = UUID().uuidString

            // Track camera session start
            let _ = CameraSessionData(
                sessionID: sessionId,
                captureType: "fridge_and_pantry_snap",
                flashEnabled: cameraModel.flashMode == .on,
                ingredientsDetected: [],
                recipesGenerated: 0,
                aiModel: UserDefaults.standard.string(forKey: "SelectedLLMProvider") ?? "grok",
                processingTime: 0
            )
            let startTime = Date()

            // Get existing recipe names to avoid duplicates
            var existingRecipeNames = appState.allRecipes.map { $0.name }

            // Fetch CloudKit recipes to include them in duplicate prevention
            print("📱 Fetching CloudKit recipes for duplicate prevention...")
            do {
                let cloudKitSavedRecipes = try await cloudKitRecipeManager.getUserSavedRecipes()
                let cloudKitCreatedRecipes = try await cloudKitRecipeManager.getUserCreatedRecipes()

                // Add CloudKit recipe names to the list
                let cloudKitRecipeNames = (cloudKitSavedRecipes + cloudKitCreatedRecipes).map { $0.name }
                existingRecipeNames.append(contentsOf: cloudKitRecipeNames)

                // Remove duplicates
                existingRecipeNames = Array(Set(existingRecipeNames))

                print("✅ Total recipes for duplicate prevention: \(existingRecipeNames.count) (Local: \(appState.allRecipes.count), CloudKit: \(cloudKitRecipeNames.count))")
            } catch {
                print("⚠️ Failed to fetch CloudKit recipes for duplicate prevention: \(error)")
                // Continue with just local recipes
            }

            // Get food preferences from UserDefaults
            let foodPreferences = UserDefaults.standard.stringArray(forKey: "SelectedFoodPreferences") ?? []

            // If user has food preferences but no specific food type selected, use preferences
            let effectiveFoodType: String? = if !foodPreferences.isEmpty && selectedFoodType == nil {
                // Join preferences into a string for the foodType parameter
                foodPreferences.joined(separator: ", ")
            } else {
                selectedFoodType
            }

            // Get selected LLM provider from UserDefaults (default to Gemini)
            let llmProvider = UserDefaults.standard.string(forKey: "SelectedLLMProvider") ?? "gemini"

            // Call the new API function for both images
            SnapChefAPIManager.shared.sendBothImagesForRecipeGeneration(
                fridgeImage: fridgeImage,
                pantryImage: pantryImage,
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

                        // 🔍 DEBUG: Log converted recipes in CameraView (dual image)
                        print("🔍 DEBUG: CameraView - Converted \(recipes.count) recipes from API (dual image)")
                        for (index, recipe) in recipes.enumerated() {
                            print("🔍 CAMERA RECIPE \(index + 1) FINAL STATE:")
                            print("🔍   - name: \(recipe.name)")
                            print("🔍   - cookingTechniques: \(recipe.cookingTechniques.isEmpty ? "EMPTY" : "\(recipe.cookingTechniques)")")
                            print("🔍   - secretIngredients: \(recipe.secretIngredients.isEmpty ? "EMPTY" : "\(recipe.secretIngredients)")")
                            print("🔍   - proTips: \(recipe.proTips.isEmpty ? "EMPTY" : "\(recipe.proTips)")")
                            print("🔍   - visualClues: \(recipe.visualClues.isEmpty ? "EMPTY" : "\(recipe.visualClues)")")
                            print("🔍   - shareCaption: \(recipe.shareCaption.isEmpty ? "EMPTY" : "\"\(recipe.shareCaption)\"")")
                        }

                        // Update state immediately for UI
                        self.generatedRecipes = recipes
                        self.detectedIngredients = apiResponse.data.ingredients
                        self.capturedImage = fridgeImage
                        self.resultsPreloaded = true

                        // Store both photos for all generated recipes
                        print("📸 CameraView: Storing fridge and pantry photos in PhotoStorageManager for \(recipes.count) recipes")
                        PhotoStorageManager.shared.storeFridgePhoto(
                            fridgeImage,
                            for: recipes.map { $0.id }
                        )
                        PhotoStorageManager.shared.storePantryPhoto(
                            pantryImage,
                            for: recipes.map { $0.id }
                        )

                        // Dismiss processing overlay first
                        self.isProcessing = false

                        // Navigate to results immediately - user sees recipes right away!
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                            self.showingResults = true
                        }

                        // Capture values before entering detached task (these are @MainActor properties)
                        let flashEnabled = cameraModel.flashMode == .on
                        let dietaryRestrictions = currentDietaryRestrictions
                        let foodType = effectiveFoodType
                        let difficulty = selectedDifficulty
                        let health = selectedHealthPreference
                        let mealType = selectedMealType
                        let cookingTime = selectedCookingTime

                        // BACKGROUND SAVING: Queue CloudKit upload for background processing
                        Task.detached(priority: .background) {
                            do {
                                // Check if recipes already exist in CloudKit before uploading
                                print("📱 Background: Checking for duplicate recipes before CloudKit upload...")
                                var recipesToUpload: [Recipe] = []
                                
                                // Only proceed with CloudKit saving if user is authenticated
                                guard await UnifiedAuthManager.shared.isAuthenticated else {
                                    print("📱 Background: User not authenticated - skipping CloudKit saving")
                                    return
                                }
                                
                                // Check for duplicates before uploading
                                for recipe in recipes {
                                    let existingID = await cloudKitRecipeManager.checkRecipeExists(recipe.name, recipe.description)
                                    if existingID == nil {
                                        recipesToUpload.append(recipe)
                                        print("📱 Background: Recipe '\(recipe.name)' will be uploaded")
                                    } else {
                                        print("📱 Background: Recipe '\(recipe.name)' already exists in CloudKit, skipping upload")
                                    }
                                }
                                
                                if recipesToUpload.isEmpty {
                                    print("📱 Background: All recipes already exist in CloudKit, skipping upload")
                                    return
                                }
                                
                                // Track camera session completion
                                let processingTime = Date().timeIntervalSince(startTime)
                                let completedSession = CameraSessionData(
                                    sessionID: sessionId,
                                    captureType: "fridge_and_pantry_snap",
                                    flashEnabled: flashEnabled,
                                    ingredientsDetected: apiResponse.data.ingredients.map { $0.name },
                                    recipesGenerated: recipes.count,
                                    aiModel: llmProvider,
                                    processingTime: processingTime
                                )
                                await cloudKitDataManager.trackCameraSession(completedSession)

                                // Track usage with UsageTracker for dual images
                                await MainActor.run {
                                    self.usageTracker.trackRecipeGenerated()
                                    self.userLifecycleManager.trackRecipeCreated()
                                }

                                // Track recipe generation
                                for recipe in recipes {
                                    let generationData = RecipeGenerationData(
                                        sessionID: sessionId,
                                        recipe: recipe,
                                        ingredients: apiResponse.data.ingredients.map { $0.name },
                                        preferencesJSON: String(describing: [
                                            "dietary": dietaryRestrictions,
                                            "foodType": foodType ?? "",
                                            "difficulty": difficulty ?? "",
                                            "health": health ?? "",
                                            "mealType": mealType ?? "",
                                            "cookingTime": cookingTime ?? ""
                                        ]),
                                        generationTime: processingTime / Double(recipes.count),
                                        quality: "high"
                                    )
                                    await cloudKitDataManager.trackRecipeGeneration(generationData)
                                }

                                // Track feature usage
                                await cloudKitDataManager.trackFeatureUse("recipe_generation_with_pantry")

                                // Save only new recipes to CloudKit with the captured fridge photo
                                print("📸 Background: Uploading \(recipesToUpload.count) new recipes to CloudKit...")
                                for (index, recipe) in recipesToUpload.enumerated() {
                                    do {
                                        print("📸 Background: Uploading recipe \(index + 1)/\(recipesToUpload.count): '\(recipe.name)'")
                                        let recipeID = try await cloudKitRecipeManager.uploadRecipe(recipe, fromLLM: true, beforePhoto: fridgeImage)
                                        print("✅ Background: Recipe \(index + 1)/\(recipesToUpload.count) saved to CloudKit with ID: \(recipeID) and shared before photo")

                                        // Also add to user's saved recipes list
                                        try await cloudKitRecipeManager.addRecipeToUserProfile(recipeID, type: .saved)
                                        print("✅ Background: Recipe added to user's saved list")
                                    } catch {
                                        print("❌ Background: Failed to save recipe \(index + 1)/\(recipesToUpload.count) to CloudKit: \(error)")
                                    }
                                }
                                print("✅ Background: All \(recipesToUpload.count) new recipes have been saved with fridge and pantry photos")

                                // Increment snaps taken counter
                                await MainActor.run {
                                    self.appState.incrementSnapsTaken()
                                }

                                // Increment daily recipe count if not premium
                                await MainActor.run {
                                    if !self.subscriptionManager.isPremium {
                                        self.subscriptionManager.incrementDailyRecipeCount()
                                    }
                                }

                                // Track challenge progress for recipe creation
                                for recipe in recipes {
                                    // Post notification for recipe creation
                                    await MainActor.run {
                                        NotificationCenter.default.post(
                                            name: Notification.Name("RecipeCreated"),
                                            object: recipe
                                        )
                                    }

                                    // Award coins based on recipe quality
                                    let quality = await MainActor.run { self.determineRecipeQuality(recipe) }
                                    await MainActor.run {
                                        ChefCoinsManager.shared.awardRecipeCreationCoins(recipeQuality: quality)
                                    }

                                    // Track specific challenge actions
                                    if recipe.nutrition.calories < 500 {
                                        await MainActor.run {
                                            ChallengeProgressTracker.shared.trackAction(.calorieTarget, metadata: [
                                                "calories": recipe.nutrition.calories,
                                                "recipeId": recipe.id
                                            ])
                                        }
                                    }

                                    if recipe.nutrition.protein >= 20 {
                                        await MainActor.run {
                                            ChallengeProgressTracker.shared.trackAction(.proteinTarget, metadata: [
                                                "protein": recipe.nutrition.protein,
                                                "recipeId": recipe.id
                                            ])
                                        }
                                    }

                                    // Track cuisine if available in tags
                                    if let cuisineTag = recipe.tags.first(where: { tag in
                                        ["italian", "mexican", "chinese", "japanese", "thai", "indian", "french", "american"].contains(tag.lowercased())
                                    }) {
                                        await MainActor.run {
                                            ChallengeProgressTracker.shared.trackAction(.cuisineExplored, metadata: [
                                                "cuisine": cuisineTag,
                                                "recipeId": recipe.id
                                            ])
                                        }
                                    }

                                    // Check for speed challenges
                                    if recipe.prepTime + recipe.cookTime <= 30 {
                                        await MainActor.run {
                                            ChallengeProgressTracker.shared.trackAction(.timeCompleted, metadata: [
                                                "totalTime": recipe.prepTime + recipe.cookTime,
                                                "recipeId": recipe.id
                                            ])
                                        }
                                    }

                                    // Track analytics for recipe creation
                                    await MainActor.run {
                                        ChallengeAnalyticsService.shared.trackEvent(.milestoneReached, parameters: [
                                            "milestone": "recipe_created_with_pantry",
                                            "quality": quality.rawValue,
                                            "calories": recipe.nutrition.calories,
                                            "protein": recipe.nutrition.protein,
                                            "totalTime": recipe.prepTime + recipe.cookTime,
                                            "difficulty": recipe.difficulty,
                                            "recipeId": recipe.id.uuidString
                                        ])
                                    }
                                }
                            } catch {
                                print("❌ Background saving failed: \(error)")
                            }
                        }

                    case .failure(let error):
                        self.isProcessing = false

                        // Convert API errors to user-friendly SnapChef errors with appropriate recovery strategies
                        if case APIError.authenticationError = error {
                            // API auth error - this is about the backend API key, not user auth
                            self.currentError = .apiError("Server authentication failed. Please try again later.", recovery: .retry)
                        } else if case APIError.notFoodImage(let message) = error {
                            // Use imageProcessingError for non-food images with retry recovery
                            self.currentError = .imageProcessingError(message, recovery: .retry)
                        } else if case APIError.noIngredientsDetected(let message) = error {
                            // Use recipeGenerationError for ingredient detection issues with retry recovery
                            self.currentError = .recipeGenerationError(message, recovery: .retry)
                        } else if case APIError.serverError(_, let message) = error {
                            self.currentError = .apiError("Server error: \(message)", recovery: .retry)
                        } else if case APIError.unauthorized(let message) = error {
                            // This is about missing API key in the app, not user authentication
                            self.currentError = .apiError(message, recovery: .retry)
                        } else {
                            self.currentError = .unknown(error.localizedDescription, recovery: .retry)
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

    private func resetCaptureFlow() {
        captureMode = .fridge
        fridgePhoto = nil
        showPantryStep = false
        capturedImage = nil
        showingPreview = false
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

// MARK: - Pantry Step Overlay
struct PantryStepOverlay: View {
    let fridgePhoto: UIImage?
    let onSkip: () -> Void
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Fridge photo preview
                if let fridgeImage = fridgePhoto {
                    VStack(spacing: 16) {
                        Text("Great shot!")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Image(uiImage: fridgeImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 10)
                    }
                }

                // Main message
                VStack(spacing: 12) {
                    Text("Got a pantry too? 🥫")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Add your pantry for even better recipes!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)

                // Action buttons
                VStack(spacing: 16) {
                    // Continue button (primary)
                    Button(action: onContinue) {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Add Pantry Photo")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 4)
                        .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    }

                    // Skip button (secondary)
                    Button(action: onSkip) {
                        HStack(spacing: 8) {
                            Text("Skip - Use Fridge Only")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // Back button (tertiary)
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 14))
                            Text("Back")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            print("🔍 DEBUG: PantryStepOverlay appeared - Start")
            DispatchQueue.main.async {
                print("🔍 DEBUG: PantryStepOverlay - Async block started")
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
                print("🔍 DEBUG: PantryStepOverlay - Async block completed")
            }
            print("🔍 DEBUG: PantryStepOverlay appeared - End")
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
            print("🔍 DEBUG: ScanningOverlay appeared - Start")
            DispatchQueue.main.async {
                print("🔍 DEBUG: ScanningOverlay - Async block started")
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    cornerAnimation = true
                }
                print("🔍 DEBUG: ScanningOverlay - Async block completed")
            }
            print("🔍 DEBUG: ScanningOverlay appeared - End")
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

extension CameraView {
    // MARK: - Performance Optimization Methods
    
    private func setupViewProgressively() {
        // Start with basic camera setup
        Task {
            // Small delay to ensure view is fully loaded
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await MainActor.run {
                cameraModel.requestCameraPermission()
            }
            
            // Progressive UI loading based on device performance
            let loadDelay = deviceManager.isLowPowerModeEnabled ? 0.5 : 0.2
            try? await Task.sleep(nanoseconds: UInt64(loadDelay * 1_000_000_000))
            
            await MainActor.run {
                DispatchQueue.main.async {
                    print("🔍 DEBUG: setupViewProgressively - Async block started")
                    withAnimation(.easeIn(duration: 0.3)) {
                        shouldShowFullUI = true
                    }
                    print("🔍 DEBUG: setupViewProgressively - Async block completed")
                }
            }
        }
        
        // Start scan animation only if continuous animations are enabled
        if deviceManager.shouldUseContinuousAnimations {
            startScanAnimation()
        }

        // Track screen view
        Task {
            cloudKitDataManager.trackScreenView("Camera")
        }

        // Check if this is the first time
        let hasSeenCamera = UserDefaults.standard.bool(forKey: "hasSeenCameraView")
        if !hasSeenCamera && deviceManager.animationsEnabled {
            // First time - show confetti and message
            showConfetti = true
            showWelcomeMessage = true
            UserDefaults.standard.set(true, forKey: "hasSeenCameraView")

            // Hide message after 2 seconds
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                withAnimation(.easeOut(duration: 0.5)) {
                    showWelcomeMessage = false
                }
            }
        }
    }
}

// MARK: - Enhanced Camera Controls
struct CameraControlsEnhanced: View {
    let cameraModel: CameraModel
    let capturePhoto: () -> Void
    let isProcessing: Bool
    @Binding var captureAnimation: Bool
    let captureMode: CameraView.CaptureMode
    let fridgePhoto: UIImage?

    var body: some View {
        // Instructions based on capture mode
        if !isProcessing {
            VStack(spacing: 12) {
                // Progress indicator for pantry mode
                if captureMode == .pantry {
                    HStack(spacing: 8) {
                        Text("Step 2 of 2")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))

                        // Progress dots
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                        }
                    }
                }

                // Main instruction text
                Text(instructionText)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if captureMode == .pantry {
                                Capsule()
                                    .fill(.orange.opacity(0.8))
                            } else {
                                Capsule()
                                    .fill(.clear)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                        }
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    )

                // Fridge photo thumbnail for pantry mode
                if captureMode == .pantry, let fridgeImage = fridgePhoto {
                    HStack(spacing: 8) {
                        Image(uiImage: fridgeImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )

                        Text("Fridge photo captured ✓")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                }
            }
            .padding(.bottom, 30)
        }
    }

    private var instructionText: String {
        if !cameraModel.isSessionReady {
            return "Initializing camera..."
        }

        switch captureMode {
        case .fridge:
            return "Point at your fridge"
        case .pantry:
            return "Now point at your pantry 🥫"
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

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
                    triggerAnimation = false
                    ringScale = 1
                }
            }
        }
    }
}

// MagicalProcessingOverlay is now defined in PhysicsLoadingOverlay.swift

// MARK: - Performance Optimized Modifiers

struct ConditionalParticleExplosion: ViewModifier {
    @Binding var trigger: Bool
    let enabled: Bool
    
    func body(content: Content) -> some View {
        if enabled {
            content.particleExplosion(trigger: $trigger)
        } else {
            content
        }
    }
}

#Preview {
    CameraView()
        .environmentObject(AppState())
        .environmentObject(DeviceManager())
        .environmentObject(CloudKitDataManager.shared)
}
