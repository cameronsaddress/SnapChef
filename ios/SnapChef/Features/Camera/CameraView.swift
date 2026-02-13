import SwiftUI
import AVFoundation
import AuthenticationServices
import Foundation

private let cameraDebugLoggingEnabled = false

private func cameraDebugLog(_ message: @autoclosure () -> String) {
#if DEBUG
    guard cameraDebugLoggingEnabled else { return }
    print(message())
#endif
}

struct CameraView: View {
    @StateObject private var cameraModel = CameraModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var usageTracker = UsageTracker.shared
    @StateObject private var userLifecycleManager = UserLifecycleManager.shared
    @StateObject private var paywallTriggerManager = PaywallTriggerManager.shared
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var cloudKitDataManager: CloudKitDataManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var cloudKitRecipeManager = CloudKitService.shared
    @Binding var selectedTab: Int
    var isPresented: Binding<Bool>?  // Optional binding to dismiss the camera
    
    // Performance optimization: Lazy loading of heavy views
    @State private var shouldShowFullUI = false

    init(selectedTab: Binding<Int>? = nil, isPresented: Binding<Bool>? = nil) {
        self._selectedTab = selectedTab ?? .constant(0)
        self.isPresented = isPresented
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
    @State private var showingUpgrade = false
    @State private var showConfetti = false
    @State private var showWelcomeMessage = false
    @State private var isClosing = false
    @State private var showResultsTransition = false
    @State private var resultsTransitionPulse = false
    @State private var captureFlashOpacity: Double = 0
    @State private var processingMilestone: CameraProcessingMilestone = .idle
    @State private var transitionStage: ResultsTransitionStage = .staging
    @State private var transitionHeroScale: CGFloat = 0.78
    @State private var transitionHeroOffset: CGFloat = 28
    @State private var transitionHeroOpacity: Double = 0
    @State private var transitionProgress: Double = 0.1
    @State private var transitionAura = false
    @State private var showEntryCinematic = false

    // Two-step capture flow state
    enum CaptureMode {
        case fridge
        case pantry
    }

    private enum ResultsTransitionStage {
        case staging
        case hero
        case locking
        case opening

        var title: String {
            switch self {
            case .staging:
                return "Preparing Reveal"
            case .hero:
                return "Crafting Your Hero Shot"
            case .locking:
                return "Locking Final Recipes"
            case .opening:
                return "Opening Results"
            }
        }
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

    // Backward-compatibility shim for tests and legacy call sites.
    // Internal test capture is permanently disabled in production flows.
    static func shouldEnableInternalTestCapture(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isDebugBuild: Bool = _isDebugAssertConfiguration()
    ) -> Bool {
        let _ = arguments
        let _ = environment
        let _ = isDebugBuild
        return false
    }

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

            // Adaptive scan overlay tuned for device performance.
            if !isProcessing && !showingPreview && shouldShowFullUI {
                StudioOptimizedScanningOverlay(scanLineOffset: $scanLineOffset)
                    .ignoresSafeArea()
            }

            // Optimized UI overlay - load components progressively
            if !showingPreview && shouldShowFullUI {
                VStack {
                    StudioCameraTopBar(
                        captureMode: captureMode,
                        isSessionReady: cameraModel.isSessionReady,
                        flashIcon: flashIcon,
                        onClose: closeCamera,
                        onFlipCamera: { cameraModel.flipCamera() },
                        onToggleFlash: { cameraModel.toggleFlash() }
                    )
                    
                    Spacer()
                    
                    StudioCameraBottomDock(
                        captureMode: captureMode,
                        isSessionReady: cameraModel.isSessionReady,
                        isProcessing: isProcessing,
                        fridgePhoto: fridgePhoto,
                        triggerAnimation: $captureAnimation,
                        onCapture: capturePhoto
                    )
                }
            }

            if isProcessing {
                MagicalBackground()
                    .ignoresSafeArea()
                    .overlay(
                        MagicalProcessingOverlay(capturedImage: capturedImage, processingMilestone: processingMilestone, onClose: {
                            cameraDebugLog("🔍 DEBUG: MagicalProcessingOverlay onClose called")
                            // Stop processing and go back
                            isProcessing = false
                            processingMilestone = .idle
                            capturedImage = nil
                            fridgePhoto = nil
                            captureMode = .fridge
                            showPantryStep = false
                            routeOutOfCamera()
                        })
                    )
                    .onAppear {
                        cameraDebugLog("🔍 DEBUG: Showing MagicalProcessingOverlay - isProcessing: true")
                    }
            }
            
            // Black overlay when closing to prevent frozen frame
            if isClosing {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // Preview overlay
            if showingPreview, let image = capturedImage {
                CapturedImageView(
                    image: image,
                    onRetake: retakeCapturedPhoto,
                    onConfirm: confirmCapturedPhoto
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            cameraDebugLog("🔍 DEBUG: CameraView appeared - Start")
            // Reset closing state when view appears
            isClosing = false
            if deviceManager.animationsEnabled && !reduceMotion {
                withAnimation(MotionTuning.crispCurve(0.16)) {
                    showEntryCinematic = true
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(0.55))
                    withAnimation(MotionTuning.softExit(0.2)) {
                        showEntryCinematic = false
                    }
                }
            } else {
                showEntryCinematic = false
            }
            DispatchQueue.main.async {
                cameraDebugLog("🔍 DEBUG: CameraView - Async block started")
                // Performance optimization: Progressive loading
                setupViewProgressively()
                cameraDebugLog("🔍 DEBUG: CameraView - Async block completed")
            }
            cameraDebugLog("🔍 DEBUG: CameraView appeared - End")
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
                routeOutOfCamera()
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
        .overlay(resultsTransitionOverlay)
        .overlay(captureFlashOverlay)
        .overlay(entryCinematicOverlay)
        .overlay(
            Group {
                if showWelcomeMessage {
                    StudioCameraWelcomeOverlay()
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
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
                            captureMode = .pantry
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

    @ViewBuilder
    private var resultsTransitionOverlay: some View {
        if showResultsTransition {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.72),
                        Color(hex: "#0f142d").opacity(0.62)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    if let capturedImage {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 256, height: 168)
                                .scaleEffect(transitionAura ? 1.025 : 0.985)

                            Image(uiImage: capturedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 246, height: 158)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                                )
                        }
                        .shadow(color: Color(hex: "#38f9d7").opacity(0.28), radius: 24, y: 12)
                        .opacity(transitionHeroOpacity)
                        .scaleEffect(transitionHeroScale)
                        .offset(y: transitionHeroOffset)
                    }

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#38f9d7"), Color(hex: "#43e97b")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .shadow(color: Color(hex: "#38f9d7").opacity(0.45), radius: 16, y: 8)
                            .scaleEffect(resultsTransitionPulse ? 1.04 : 0.96)

                        Image(systemName: "sparkles")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text(transitionStage.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Building your studio-quality reveal...")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))

                    ProgressView(value: transitionProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(Color(hex: "#38f9d7"))
                        .frame(width: 210)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.22), value: showResultsTransition)
        }
    }

    private func startScanAnimation() {
        withAnimation(
            .linear(duration: MotionTuning.cameraSeconds(GrowthRemoteConfig.shared.cameraScanCycleBaseDuration))
                .repeatForever(autoreverses: true)
        ) {
            scanLineOffset = 200
        }
    }

    private func routeOutOfCamera() {
        if let cameraPresented = isPresented {
            cameraPresented.wrappedValue = false
        } else {
            selectedTab = 0
        }
    }

    private func closeCamera() {
        withAnimation(.easeOut(duration: 0.2)) {
            isClosing = true
            shouldShowFullUI = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if cameraModel.isSessionReady {
                cameraModel.stopSession()
            }
            resetCaptureFlow()
            routeOutOfCamera()
            isClosing = false
        }
    }

    private func retakeCapturedPhoto() {
        showingPreview = false
        capturedImage = nil
    }

    private func confirmCapturedPhoto() {
        guard let latestCapture = capturedImage else { return }
        showingPreview = false

        if captureMode == .fridge {
            fridgePhoto = latestCapture
            showPantryStep = true
            return
        }

        if let fridgeImage = fridgePhoto {
            processBothImages(fridgeImage: fridgeImage, pantryImage: latestCapture)
            return
        }

        // Fallback path if pantry step was resumed without a fridge photo.
        processImage(latestCapture)
    }

    @MainActor
    private func presentRecipeResults() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        transitionStage = .staging
        transitionHeroScale = 0.78
        transitionHeroOffset = 28
        transitionHeroOpacity = 0
        transitionProgress = 0.1
        transitionAura = false
        resultsTransitionPulse = false

        withAnimation(.spring(response: MotionTuning.seconds(0.34), dampingFraction: 0.84)) {
            showResultsTransition = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(0.09))
            transitionStage = .hero
            withAnimation(.spring(response: MotionTuning.seconds(0.42), dampingFraction: 0.82)) {
                transitionHeroScale = 1.0
                transitionHeroOffset = 0
                transitionHeroOpacity = 1
                transitionProgress = 0.52
            }

            try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(0.14))
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            transitionStage = .locking
            withAnimation(.easeInOut(duration: MotionTuning.seconds(0.35))) {
                transitionProgress = 0.83
                resultsTransitionPulse = true
                transitionAura = true
            }
            withAnimation(.easeInOut(duration: MotionTuning.seconds(1.05)).repeatForever(autoreverses: true)) {
                transitionAura = true
            }

            try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(0.17))
            transitionStage = .opening
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeOut(duration: MotionTuning.seconds(0.18))) {
                transitionProgress = 1.0
            }

            try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(0.11))
            updateProcessingMilestone(.completed)
            NotificationCenter.default.post(
                name: .snapchefRecipeGenerated,
                object: nil,
                userInfo: ["count": generatedRecipes.count]
            )
            showingResults = true
            try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(0.13))
            isProcessing = false
            withAnimation(.easeInOut(duration: MotionTuning.seconds(0.22))) {
                showResultsTransition = false
                resultsTransitionPulse = false
                transitionAura = false
            }
        }
    }

    @ViewBuilder
    private var captureFlashOverlay: some View {
        if captureFlashOpacity > 0.001 {
            Color.white
                .opacity(captureFlashOpacity)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var entryCinematicOverlay: some View {
        if showEntryCinematic {
            ZStack {
                RadialGradient(
                    colors: [
                        Color(hex: "#38f9d7").opacity(0.44),
                        Color(hex: "#4facfe").opacity(0.24),
                        .clear
                    ],
                    center: .center,
                    startRadius: 8,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .blendMode(.screen)

                VStack(spacing: 10) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white.opacity(0.95))
                    Text("Snap Mode")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.35))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.24), lineWidth: 1)
                        )
                )
                .shadow(color: Color(hex: "#38f9d7").opacity(0.38), radius: 18, y: 8)
            }
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 1.02)))
        }
    }

    private func capturePhoto() {
        do {
            try SnapChefAPIManager.shared.ensureCredentialsConfigured()
        } catch {
            currentError = mapAPIErrorToSnapChefError(error)
            return
        }

        // Trigger capture animation
        captureAnimation = true

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        withAnimation(.easeOut(duration: 0.08)) {
            captureFlashOpacity = 0.28
        }
        withAnimation(.easeIn(duration: 0.14).delay(0.08)) {
            captureFlashOpacity = 0
        }

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
        cameraDebugLog("🔍 DEBUG: processImage called for single image")
        cameraDebugLog("🔍 DEBUG: Setting isProcessing = true for single image")
        isProcessing = true
        GrowthLoopManager.shared.resetRecipeWaitMeasurement()
        updateProcessingMilestone(.preparingRequest)
        capturedImage = image // Store the captured image
        cameraDebugLog("🔍 DEBUG: isProcessing is now: \(isProcessing)")

        // Stop camera session to save resources while processing
        cameraDebugLog("🔍 DEBUG: Stopping camera session for single image processing")
        cameraModel.stopSession()

        Task {
            cameraDebugLog("🔍 DEBUG: processImage Task started")
            // Check subscription status and usage limits
            if !subscriptionManager.isPremium {
                if usageTracker.hasReachedRecipeLimit() {
                    isProcessing = false
                    updateProcessingMilestone(.idle)

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

            do {
                try SnapChefAPIManager.shared.ensureCredentialsConfigured()
            } catch {
                self.updateProcessingMilestone(.failed)
                self.isProcessing = false
                self.currentError = self.mapAPIErrorToSnapChefError(error)
                self.cameraModel.requestCameraPermission()
                return
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
                aiModel: UserDefaults.standard.string(forKey: "SelectedLLMProvider") ?? "gemini",
                processingTime: 0
            )
            let startTime = Date()

            // Get existing recipe names to avoid duplicates
            // Use LOCAL-FIRST approach with LocalRecipeManager for instant access
            var existingRecipeNames = Set<String>()
            
            // 1. Get recipes from LocalRecipeManager (instant, reliable)
            let localSavedRecipes = LocalRecipeManager.shared.getSavedRecipes()
            
            // Load recipe names from local storage
            for recipe in localSavedRecipes {
                existingRecipeNames.insert(recipe.name)
                // Also add variations of the name to prevent similar recipes
                existingRecipeNames.insert(recipe.name.lowercased())
                existingRecipeNames.insert(recipe.name.replacingOccurrences(of: " and ", with: " & "))
                existingRecipeNames.insert(recipe.name.replacingOccurrences(of: " & ", with: " and "))
            }
            print("📱 Found \(localSavedRecipes.count) saved recipes in LocalRecipeManager")
            
            // 2. Also include recipes from AppState (for backwards compatibility)
            for recipe in appState.allRecipes {
                existingRecipeNames.insert(recipe.name)
                existingRecipeNames.insert(recipe.name.lowercased())
            }
            print("📱 Found \(appState.allRecipes.count) recipes in AppState")
            
            // 3. Include recently generated recipes from this session
            for recipe in appState.recentRecipes {
                existingRecipeNames.insert(recipe.name)
                existingRecipeNames.insert(recipe.name.lowercased())
            }
            
            // Convert to array for API (removing duplicates automatically via Set)
            let existingRecipeNamesArray = Array(existingRecipeNames)
            print("✅ Total unique recipe names for duplicate prevention: \(existingRecipeNamesArray.count)")
            
            // Log first few names for debugging
            if !existingRecipeNamesArray.isEmpty {
                let preview = existingRecipeNamesArray.prefix(5).joined(separator: ", ")
                print("📋 Sample existing recipes: \(preview)...")
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
            updateProcessingMilestone(.uploadingPhotos)
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
                existingRecipeNames: existingRecipeNamesArray,
                foodPreferences: foodPreferences,
                llmProvider: llmProvider,
                lifecycle: { milestone in
                    Task { @MainActor in
                        self.updateProcessingMilestone(from: milestone)
                    }
                }
            ) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let apiResponse):
                        self.updateProcessingMilestone(.finalizingResults)
                        // Convert API recipes to app recipes
                        let recipes = apiResponse.data.recipes.map { apiRecipe in
                            SnapChefAPIManager.shared.convertAPIRecipeToAppRecipe(apiRecipe)
                        }

                        // 🔍 DEBUG: Log converted recipes in CameraView (single image)
                        cameraDebugLog("🔍 DEBUG: CameraView - Converted \(recipes.count) recipes from API (single image)")
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

                        // Navigate to results - keep processing overlay visible until results show
                        // This prevents the camera from restarting
                        presentRecipeResults()

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
                                    let existingID = await cloudKitRecipeManager.existingRecipeID(name: recipe.name, description: recipe.description)
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
                                if let suggestedContext = await MainActor.run(body: { self.paywallTriggerManager.getSuggestedPaywallContext() }) {
                                    if await MainActor.run(body: { self.paywallTriggerManager.shouldShowPaywall(for: suggestedContext) }) {
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

                                        // Track as created (not saved - user must explicitly save)
                                        try await cloudKitRecipeManager.addRecipeToUserProfile(recipeID, type: .created)
                                        print("✅ Background: Recipe tracked as created by user")
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
                        }

                    case .failure(let error):
                        cameraDebugLog("🔍 DEBUG: API FAILURE: \(error)")
                        cameraDebugLog("🔍 DEBUG: Setting isProcessing = false due to error")
                        self.updateProcessingMilestone(.failed)
                        self.isProcessing = false

                        self.currentError = self.mapAPIErrorToSnapChefError(error)

                        // Restart camera session on error
                        self.cameraModel.requestCameraPermission()
                    }
                }
            }
        }
    }

    private func processBothImages(fridgeImage: UIImage, pantryImage: UIImage) {
        cameraDebugLog("🔍 DEBUG: processBothImages called")
        cameraDebugLog("🔍 DEBUG: Setting isProcessing = true")
        isProcessing = true
        GrowthLoopManager.shared.resetRecipeWaitMeasurement()
        updateProcessingMilestone(.preparingRequest)
        capturedImage = fridgeImage // Store the fridge image as the primary image
        cameraDebugLog("🔍 DEBUG: isProcessing is now: \(isProcessing)")
        cameraDebugLog("🔍 DEBUG: capturedImage set: \(capturedImage != nil)")

        // Stop camera session to save resources while processing
        cameraDebugLog("🔍 DEBUG: Stopping camera session for processing")
        cameraModel.stopSession()

        Task {
            cameraDebugLog("🔍 DEBUG: processBothImages Task started")
            // Check subscription status and usage limits for dual images
            cameraDebugLog("🔍 DEBUG: Checking subscription - isPremium: \(subscriptionManager.isPremium)")
            if !subscriptionManager.isPremium {
                let hasReachedLimit = usageTracker.hasReachedRecipeLimit()
                cameraDebugLog("🔍 DEBUG: Has reached recipe limit: \(hasReachedLimit)")
                if hasReachedLimit {
                    cameraDebugLog("🔍 DEBUG: Recipe limit reached, stopping processing")
                    isProcessing = false
                    updateProcessingMilestone(.idle)

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
            cameraDebugLog("🔍 DEBUG: Subscription check passed, continuing with API call")

            do {
                try SnapChefAPIManager.shared.ensureCredentialsConfigured()
            } catch {
                self.updateProcessingMilestone(.failed)
                self.isProcessing = false
                self.currentError = self.mapAPIErrorToSnapChefError(error)
                self.cameraModel.requestCameraPermission()
                return
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
                aiModel: UserDefaults.standard.string(forKey: "SelectedLLMProvider") ?? "gemini",
                processingTime: 0
            )
            let startTime = Date()

            // Get existing recipe names to avoid duplicates
            var existingRecipeNames = Set<String>()
            
            // Use LocalRecipeManager for faster access to saved recipes
            let localSavedRecipes = LocalRecipeManager.shared.getSavedRecipes()
            
            for recipe in localSavedRecipes {
                existingRecipeNames.insert(recipe.name)
                existingRecipeNames.insert(recipe.name.lowercased())
                
                // Add variations with "and" vs "&"
                let nameWithAnd = recipe.name.replacingOccurrences(of: "&", with: "and")
                let nameWithAmpersand = recipe.name.replacingOccurrences(of: "and", with: "&")
                existingRecipeNames.insert(nameWithAnd.lowercased())
                existingRecipeNames.insert(nameWithAmpersand.lowercased())
            }
            
            // Also add recipes from current app state
            for recipe in appState.allRecipes {
                existingRecipeNames.insert(recipe.name)
                existingRecipeNames.insert(recipe.name.lowercased())
            }
            
            // Convert to array for API
            let existingRecipeNamesArray = Array(existingRecipeNames)
            
            print("✅ Total recipe names for duplicate prevention: \(existingRecipeNamesArray.count)")

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
            updateProcessingMilestone(.uploadingPhotos)
            cameraDebugLog("🔍 DEBUG: About to call API with both images")
            cameraDebugLog("🔍 DEBUG: Fridge image size: \(fridgeImage.size)")
            cameraDebugLog("🔍 DEBUG: Pantry image size: \(pantryImage.size)")
            cameraDebugLog("🔍 DEBUG: Number of recipes: \(numberOfRecipes)")
            cameraDebugLog("🔍 DEBUG: LLM Provider: \(llmProvider)")
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
                existingRecipeNames: existingRecipeNamesArray,
                foodPreferences: foodPreferences,
                llmProvider: llmProvider,
                lifecycle: { milestone in
                    Task { @MainActor in
                        self.updateProcessingMilestone(from: milestone)
                    }
                }
            ) { result in
                cameraDebugLog("🔍 DEBUG: API callback received for dual images")
                Task { @MainActor in
                    cameraDebugLog("🔍 DEBUG: In MainActor task for dual images")
                    switch result {
                    case .success(let apiResponse):
                        self.updateProcessingMilestone(.finalizingResults)
                        cameraDebugLog("🔍 DEBUG: API SUCCESS - Got \(apiResponse.data.recipes.count) recipes from dual images")
                        // Convert API recipes to app recipes
                        let recipes = apiResponse.data.recipes.map { apiRecipe in
                            SnapChefAPIManager.shared.convertAPIRecipeToAppRecipe(apiRecipe)
                        }

                        // 🔍 DEBUG: Log converted recipes in CameraView (dual image)
                        cameraDebugLog("🔍 DEBUG: CameraView - Converted \(recipes.count) recipes from API (dual image)")
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

                        // Navigate to results - keep processing overlay visible until results show
                        // This prevents the camera from restarting
                        presentRecipeResults()

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
                                    let existingID = await cloudKitRecipeManager.existingRecipeID(name: recipe.name, description: recipe.description)
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

                                        // Track as created (not saved - user must explicitly save)
                                        try await cloudKitRecipeManager.addRecipeToUserProfile(recipeID, type: .created)
                                        print("✅ Background: Recipe tracked as created by user")
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
                        }

                    case .failure(let error):
                        cameraDebugLog("🔍 DEBUG: API FAILURE: \(error)")
                        cameraDebugLog("🔍 DEBUG: Setting isProcessing = false due to error")
                        self.updateProcessingMilestone(.failed)
                        self.isProcessing = false

                        self.currentError = self.mapAPIErrorToSnapChefError(error)

                        // Restart camera session on error
                        self.cameraModel.requestCameraPermission()
                    }
                }
            }
        }
    }

    private func mapAPIErrorToSnapChefError(_ error: Error) -> SnapChefError {
        if let existing = error as? SnapChefError {
            return existing
        }

        guard let apiError = error as? APIError else {
            return .unknown(error.localizedDescription, recovery: .retry)
        }

        switch apiError {
        case .authenticationError:
            return .apiError(
                "Server authentication failed. Please verify the app API key configuration.",
                statusCode: 401,
                recovery: .retry
            )
        case .unauthorized(let message):
            return .apiError(
                normalizedServerMessage(message),
                statusCode: 401,
                recovery: .retry
            )
        case .notFoodImage(let message):
            return .imageProcessingError(message, recovery: .retry)
        case .noIngredientsDetected(let message):
            return .recipeGenerationError(message, recovery: .retry)
        case .serverError(let statusCode, let message):
            if statusCode == -1 || message.localizedCaseInsensitiveContains("timed out") {
                return .timeoutError("Request timed out. Please try again.")
            }
            let normalizedMessage = normalizedServerMessage(message)
            if statusCode == 503 {
                let retryDelay = retryAfterSeconds(fromMessage: normalizedMessage) ?? 20
                let fallbackMessage = normalizedMessage.isEmpty
                    ? "Our AI service is waking up. Please retry in a moment."
                    : normalizedMessage
                return .apiError(
                    fallbackMessage,
                    statusCode: statusCode,
                    recovery: .retryAfter(retryDelay)
                )
            }
            if statusCode == 429 {
                let retryDelay = retryAfterSeconds(fromMessage: normalizedMessage) ?? 15
                return .rateLimitError(
                    normalizedMessage.isEmpty ? "Too many requests. Please wait a moment and try again." : normalizedMessage,
                    retryAfter: retryDelay
                )
            }
            return .apiError(
                normalizedMessage,
                statusCode: statusCode,
                recovery: .retry
            )
        case .decodingError:
            return .apiError(
                "Unexpected server response. Please try again in a moment.",
                statusCode: 502,
                recovery: .retry
            )
        case .invalidURL:
            return .apiError("Service URL is invalid. Please contact support.", statusCode: 500, recovery: .contactSupport)
        case .invalidRequestData:
            return .validationError("Photo data could not be prepared. Try retaking the photo.", fields: ["image"])
        case .noData:
            return .apiError("No response received from the server. Please retry.", statusCode: 502, recovery: .retry)
        }
    }

    private func normalizedServerMessage(_ rawMessage: String) -> String {
        let trimmed = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Service temporarily unavailable. Please try again shortly."
        }

        var candidate = trimmed
        if candidate.lowercased().hasPrefix("server error:") {
            candidate = candidate.dropFirst("server error:".count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let data = candidate.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = json["detail"] as? String, !detail.isEmpty {
                return detail
            }
            if let message = json["message"] as? String, !message.isEmpty {
                return message
            }
            if let error = json["error"] as? String, !error.isEmpty {
                return error
            }
        }

        return candidate
    }

    private func retryAfterSeconds(fromMessage message: String) -> TimeInterval? {
        let pattern = #"(\d+)\s*(second|seconds|sec|s|minute|minutes|min|m)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(message.startIndex..<message.endIndex, in: message)
        guard let match = regex.firstMatch(in: message, options: [], range: range),
              match.numberOfRanges >= 3,
              let valueRange = Range(match.range(at: 1), in: message),
              let unitRange = Range(match.range(at: 2), in: message),
              let value = Double(message[valueRange]) else {
            return nil
        }

        let unit = message[unitRange].lowercased()
        if unit.hasPrefix("m") {
            return value * 60
        }
        return value
    }

    private func resetCaptureFlow() {
        captureMode = .fridge
        fridgePhoto = nil
        showPantryStep = false
        capturedImage = nil
        showingPreview = false
        GrowthLoopManager.shared.resetRecipeWaitMeasurement()
        processingMilestone = .idle
    }

    private func updateProcessingMilestone(_ phase: CameraProcessingPhase) {
        processingMilestone = CameraProcessingMilestone(phase: phase)
        switch phase {
        case .waitingForRecipes:
            GrowthLoopManager.shared.markRecipeWaitStarted()
        case .decodingResponse, .completed, .failed:
            GrowthLoopManager.shared.markRecipeWaitFinished()
        case .idle:
            GrowthLoopManager.shared.resetRecipeWaitMeasurement()
        default:
            break
        }
    }

    private func updateProcessingMilestone(from milestone: SnapChefAPIManager.RecipeGenerationMilestone) {
        switch milestone {
        case .requestPrepared:
            updateProcessingMilestone(.preparingRequest)
        case .requestSent:
            updateProcessingMilestone(.waitingForRecipes)
        case .responseReceived:
            updateProcessingMilestone(.decodingResponse)
        case .responseDecoded:
            updateProcessingMilestone(.finalizingResults)
        case .completed:
            updateProcessingMilestone(.finalizingResults)
        case .failed:
            updateProcessingMilestone(.failed)
        }
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
    @State private var showAuthPrompt = false
    @StateObject private var authManager = UnifiedAuthManager.shared

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

                    Text(authManager.isAuthenticated 
                        ? "Add your pantry for even better recipes!"
                        : "Sign in to combine fridge + pantry photos!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)

                // Action buttons
                VStack(spacing: 16) {
                    // Continue button (primary) - check authentication
                    Button(action: {
                        if authManager.isAuthenticated {
                            onContinue()
                        } else {
                            showAuthPrompt = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: authManager.isAuthenticated ? "camera.fill" : "lock.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text(authManager.isAuthenticated ? "Add Pantry Photo" : "Sign In to Add Pantry")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: authManager.isAuthenticated 
                                    ? [Color.orange, Color.orange.opacity(0.8)]
                                    : [Color.purple, Color.purple.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: authManager.isAuthenticated ? Color.orange.opacity(0.3) : Color.purple.opacity(0.3), radius: 8, y: 4)
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
            cameraDebugLog("🔍 DEBUG: PantryStepOverlay appeared - Start")
            DispatchQueue.main.async {
                cameraDebugLog("🔍 DEBUG: PantryStepOverlay - Async block started")
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
                cameraDebugLog("🔍 DEBUG: PantryStepOverlay - Async block completed")
            }
            cameraDebugLog("🔍 DEBUG: PantryStepOverlay appeared - End")
        }
        .sheet(isPresented: $showAuthPrompt) {
            ProgressiveAuthPrompt(overrideContext: .featureUnlock)
                .onDisappear {
                    if authManager.isAuthenticated {
                        onContinue()
                    }
                }
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
            cameraDebugLog("🔍 DEBUG: ScanningOverlay appeared - Start")
            DispatchQueue.main.async {
                cameraDebugLog("🔍 DEBUG: ScanningOverlay - Async block started")
                withAnimation(
                    .easeInOut(duration: MotionTuning.cameraSeconds(GrowthRemoteConfig.shared.cameraScanCycleBaseDuration))
                        .repeatForever(autoreverses: true)
                ) {
                    cornerAnimation = true
                }
                cameraDebugLog("🔍 DEBUG: ScanningOverlay - Async block completed")
            }
            cameraDebugLog("🔍 DEBUG: ScanningOverlay appeared - End")
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
            await SnapChefAPIManager.shared.warmupBackendIfNeeded()

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
                    cameraDebugLog("🔍 DEBUG: setupViewProgressively - Async block started")
                    withAnimation(.easeIn(duration: 0.3)) {
                        shouldShowFullUI = true
                    }
                    cameraDebugLog("🔍 DEBUG: setupViewProgressively - Async block completed")
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var ringScale: CGFloat = 1
    @State private var readyPulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if !isDisabled {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#38f9d7").opacity(readyPulse ? 0.42 : 0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 6,
                                endRadius: 74
                            )
                        )
                        .frame(width: 130, height: 130)
                        .scaleEffect(readyPulse ? 1.08 : 0.9)
                }

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
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(MotionTuning.crispCurve(1.4).repeatForever(autoreverses: true)) {
                readyPulse = true
            }
        }
        .onChange(of: isDisabled) { disabled in
            if disabled || reduceMotion {
                readyPulse = false
            } else {
                withAnimation(MotionTuning.crispCurve(1.4).repeatForever(autoreverses: true)) {
                    readyPulse = true
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
        .environmentObject(CloudKitDataManager.shared)
}
