import SwiftUI
import UIKit
import Foundation

// MARK: - Detective View
struct DetectiveView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraModel = CameraModel()
    @StateObject private var cloudKitAuth = UnifiedAuthManager.shared
    @StateObject private var userLifecycle = UserLifecycleManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var detectiveRecipe: DetectiveRecipe?
    @State private var errorMessage: String?
    @State private var showingPremiumPrompt = false
    @State private var analysisProgress: Double = 0.0
    @State private var showingSharePopup = false
    @State private var savedRecipeIds: Set<UUID> = []
    @State private var showingAfterPhotoCapture = false
    @State private var selectedRecipeForPhoto: DetectiveRecipe?
    @State private var afterPhoto: UIImage?
    
    // Track detective uses for premium limit
    @AppStorage("detectiveFeatureUses") private var detectiveUses: Int = 0
    
    // MARK: - Computed Properties for Type Inference
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }
    
    private var recentRecipes: [DetectiveRecipe] {
        // Return empty array for now since detectiveRecipes is commented out in AppState
        []
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        detectiveHeader
                        
                        // Main Content
                        if let recipe = detectiveRecipe {
                            detectiveResultCard(recipe: recipe)
                        } else if isAnalyzing {
                            analysisProgressView
                        } else if let error = errorMessage {
                            errorDisplayCard(error: error)
                        } else {
                            detectivePromptCard
                        }
                        
                        // Recent Detective Analyses (if any)
                        if !recentRecipes.isEmpty {
                            recentAnalysesSection
                        }
                        
                        Spacer(minLength: 120) // Account for tab bar
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("Recipe Detective")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.7))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.2))
                            )
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraDetectiveView(
                    capturedImage: $capturedImage,
                    isAnalyzing: $isAnalyzing
                )
            }
            .sheet(isPresented: $showingPremiumPrompt) {
                PremiumUpgradePrompt(
                    isPresented: $showingPremiumPrompt,
                    reason: .premiumFeature("Recipe Detective")
                )
            }
            .sheet(isPresented: $showingSharePopup) {
                if let recipe = detectiveRecipe {
                    BrandedSharePopup(
                        content: ShareContent(
                            type: .recipe(recipe.toBaseRecipe()),
                            beforeImage: getBeforePhotoForDetectiveRecipe(),
                            afterImage: getAfterPhotoForDetectiveRecipe()
                        )
                    )
                }
            }
            .fullScreenCover(isPresented: $showingAfterPhotoCapture) {
                if let recipe = selectedRecipeForPhoto {
                    AfterPhotoCaptureView(
                        afterPhoto: $afterPhoto,
                        recipeID: recipe.id.uuidString
                    )
                    .onDisappear {
                        if let photo = afterPhoto {
                            // Save the after photo to PhotoStorageManager (single source of truth)
                            PhotoStorageManager.shared.storeMealPhoto(photo, for: recipe.id)
                            
                            // Also update appState for backwards compatibility
                            let baseRecipe = recipe.toBaseRecipe()
                            appState.updateAfterPhoto(for: baseRecipe.id, afterPhoto: photo)
                            
                            print("📸 Detective: After photo saved for recipe \(recipe.name)")
                        }
                    }
                }
            }
            .onChange(of: capturedImage) { newImage in
                if let newImage = newImage {
                    Task {
                        await analyzeImage(newImage)
                    }
                }
            }
            .onAppear {
                print("🔍 DEBUG: DetectiveView appeared - Start")
                DispatchQueue.main.async {
                    print("🔍 DEBUG: DetectiveView - Async block started")
                    // Initialize saved recipe IDs from appState
                    savedRecipeIds = Set(appState.savedRecipes.map { $0.id })
                    print("🔍 DetectiveView: Loaded \(savedRecipeIds.count) saved recipes")
                    print("🔍 DEBUG: DetectiveView - Async block completed")
                }
                print("🔍 DEBUG: DetectiveView appeared - End")
            }
        }
    }
    
    // MARK: - Header
    private var detectiveHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#9b59b6"), Color(hex: "#8e44ad")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recipe Detective")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Reverse-engineer any dish from a photo")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Show premium badge for non-premium users
                if !SubscriptionManager.shared.isPremium {
                    premiumBadge
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Premium Badge
    private var premiumBadge: some View {
        VStack(spacing: 2) {
            Image(systemName: "crown.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#9b59b6"))
            Text("Premium")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "#9b59b6"))
        }
    }
    
    // MARK: - Detective Usage Counter
    private func detectiveUsageCounter(remaining: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
            Text("\(remaining) left")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(remaining > 5 ? Color.green.opacity(0.8) : remaining > 2 ? Color.orange.opacity(0.8) : Color.red.opacity(0.8))
        )
    }
    
    // MARK: - Detective Prompt Card
    private var detectivePromptCard: some View {
        VStack(spacing: 20) {
            // Illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#9b59b6").opacity(0.3), Color(hex: "#8e44ad").opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                VStack(spacing: 8) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "#9b59b6"))
                    
                    Image(systemName: "arrow.down")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#3498db"))
                }
            }
            
            VStack(spacing: 12) {
                Text("Snap & Solve")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Take a photo of any restaurant dish and I'll reverse-engineer the recipe for you!")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button(action: {
                if canUseDetectiveFeature() {
                    showingCamera = true
                } else {
                    // Show premium prompt when detective limit is reached
                    showingPremiumPrompt = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text(canUseDetectiveFeature() ? "Analyze Dish" : "Unlock Detective")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#9b59b6"), Color(hex: "#8e44ad")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Analysis Progress View
    private var analysisProgressView: some View {
        VStack(spacing: 20) {
            // Animated magnifying glass
            ZStack {
                Circle()
                    .fill(Color(hex: "#9b59b6").opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(1 + sin(analysisProgress * .pi * 4) * 0.1)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(Color(hex: "#9b59b6"))
                    .rotationEffect(.degrees(analysisProgress * 360))
            }
            
            VStack(spacing: 8) {
                Text("Analyzing dish...")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Our AI chef is studying the ingredients and techniques")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            // Progress bar
            ProgressView(value: analysisProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#9b59b6")))
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .frame(height: 8)
                .background(Color.white.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            print("🔍 DEBUG: DetectiveAnalysisProgress appeared - Start")
            DispatchQueue.main.async {
                print("🔍 DEBUG: DetectiveAnalysisProgress - Async block started")
                startProgressAnimation()
                print("🔍 DEBUG: DetectiveAnalysisProgress - Async block completed")
            }
            print("🔍 DEBUG: DetectiveAnalysisProgress appeared - End")
        }
    }
    
    // MARK: - Error Display Card
    private func errorDisplayCard(error: String) -> some View {
        VStack(spacing: 20) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 12) {
                Text("Analysis Failed")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(error)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            
            // Action button
            Button(action: {
                // Clear error and go back to prompt
                errorMessage = nil
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left")
                    Text("Back")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Detective Result Card
    private func detectiveResultCard(recipe: DetectiveRecipe) -> some View {
        VStack(spacing: 20) {
            // Before/After Photo Container
            detectivePhotoContainer(recipe: recipe)
                .frame(height: 150)
                .padding(.horizontal, -24) // Extend to card edges
                .padding(.top, -24)
            
            // Confidence indicator
            HStack {
                Text(recipe.confidenceEmoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confidence: \(Int(recipe.confidenceScore))%")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(recipe.confidenceDescription)
                        .font(.caption)
                        .foregroundColor(recipe.confidenceColor)
                }
                
                Spacer()
                
                Text("\(Int(recipe.confidenceScore))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(recipe.confidenceColor)
            }
            
            // Recipe info
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Identified Dish")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(recipe.originalDishName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    if let style = recipe.restaurantStyle {
                        Text(style)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#9b59b6").opacity(0.3))
                            )
                    }
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.3))
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recreation Recipe")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(recipe.name)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    NavigationLink(destination: DetectiveRecipeDetailView(recipe: recipe)) {
                        HStack(spacing: 6) {
                            Text("View Recipe")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#9b59b6"))
                        )
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    // Save recipe to recipe book
                    saveDetectiveRecipe(recipe)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isSaved(recipe) ? "heart.fill" : "heart")
                        Text(isSaved(recipe) ? "Saved" : "Save")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSaved(recipe) ? Color(hex: "#4CAF50").opacity(0.3) : Color.white.opacity(0.2))
                    .cornerRadius(12)
                }
                
                Button(action: {
                    print("🔍 Share button tapped")
                    showingSharePopup = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(recipe.confidenceColor.opacity(0.5), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Recent Analyses Section
    private var recentAnalysesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Analyses")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(recentRecipes, id: \.id) { recipe in
                    NavigationLink(destination: DetectiveRecipeDetailView(recipe: recipe)) {
                        detectiveHistoryCard(recipe: recipe)
                    }
                }
            }
        }
    }
    
    // MARK: - Detective History Card
    private func detectiveHistoryCard(recipe: DetectiveRecipe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(recipe.confidenceEmoji)
                    .font(.title3)
                
                Spacer()
                
                Text("\(Int(recipe.confidenceScore))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(recipe.confidenceColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.originalDishName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(recipe.name)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            Text("Analyzed \(timeAgoString(from: recipe.analyzedAt))")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Functions
    private func startProgressAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
            analysisProgress = 1.0
        }
    }
    
    private func canUseDetectiveFeature() -> Bool {
        // Use the actual UsageTracker to check detective limits
        return UsageTracker.shared.canUseDetective()
    }
    
    private func analyzeImage(_ image: UIImage) async {
        isAnalyzing = true
        errorMessage = nil
        
        do {
            // Create a session ID for this analysis
            let sessionID = UUID().uuidString
            print("🔍 Starting detective analysis with session ID: \(sessionID)")
            
            // Call the actual API through SnapChefAPIManager
            let response = try await SnapChefAPIManager.shared.analyzeRestaurantMeal(
                image: image,
                sessionID: sessionID,
                llmProvider: .gemini // Using Gemini for detective analysis (default provider)
            )
            
            if response.success, let apiRecipe = response.detectiveRecipe {
                // Convert API recipe to our DetectiveRecipe model
                detectiveRecipe = SnapChefAPIManager.shared.convertAPIDetectiveRecipeToDetectiveRecipe(apiRecipe)
                
                // Log success but don't auto-save (user should explicitly save)
                if let recipe = detectiveRecipe, recipe.confidenceScore > 0 {
                    print("✅ Detective analysis successful: \(recipe.name)")
                    print("✅ Confidence: \(recipe.confidenceScore)%")
                    
                    // Increment detective uses counter in UsageTracker
                    UsageTracker.shared.incrementDetectiveUse()
                    print("📊 Detective analysis completed successfully")
                }
            } else {
                // Handle the case where no dish was detected
                errorMessage = response.message.isEmpty ? "Failed to analyze the meal photo" : response.message
                print("❌ Detective analysis failed: \(errorMessage ?? "Unknown error")")
            }
        } catch {
            errorMessage = "Failed to analyze image: \(error.localizedDescription)"
            print("❌ Detective analysis error: \(error)")
        }
        
        isAnalyzing = false
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
    
    // MARK: - Helper Functions for Actions
    
    private func saveDetectiveRecipe(_ recipe: DetectiveRecipe) {
        let baseRecipe = recipe.toBaseRecipe()
        
        print("🔍 Save button tapped for recipe: \(recipe.name)")
        print("🔍 Recipe ID: \(recipe.id)")
        print("🔍 Currently saved IDs: \(savedRecipeIds)")
        
        // Toggle save state
        if savedRecipeIds.contains(recipe.id) {
            // Already saved - remove it
            savedRecipeIds.remove(recipe.id)
            
            // Remove from saved recipes
            if let index = appState.savedRecipes.firstIndex(where: { $0.id == baseRecipe.id }) {
                appState.savedRecipes.remove(at: index)
                print("✅ Recipe removed from saved recipes")
            }
            
            // Remove from recent recipes
            if let index = appState.recentRecipes.firstIndex(where: { $0.id == baseRecipe.id }) {
                appState.recentRecipes.remove(at: index)
                print("✅ Recipe removed from recent recipes")
            }
            
            // Remove from savedRecipesWithPhotos
            appState.savedRecipesWithPhotos.removeAll { $0.recipe.id == baseRecipe.id }
            
            // Remove photos from PhotoStorageManager
            PhotoStorageManager.shared.removePhotos(for: [recipe.id])
            print("📸 Photos removed from storage")
            
            // Remove from CloudKit if authenticated
            if cloudKitAuth.isAuthenticated {
                Task {
                    try? await CloudKitRecipeManager.shared.removeRecipeFromUserProfile(
                        baseRecipe.id.uuidString,
                        type: .saved
                    )
                    print("☁️ Recipe removed from CloudKit")
                }
            }
            
            // Haptic feedback for unsave
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } else {
            // Not saved - add it
            savedRecipeIds.insert(recipe.id)
            
            // Add to saved recipes
            if !appState.savedRecipes.contains(where: { $0.id == baseRecipe.id }) {
                appState.savedRecipes.append(baseRecipe)
                print("✅ Recipe added to saved recipes")
            }
            
            // Add to recent recipes so it appears in the recipe book
            if !appState.recentRecipes.contains(where: { $0.id == baseRecipe.id }) {
                appState.addRecentRecipe(baseRecipe)
                print("✅ Recipe added to recent recipes")
            }
            
            // Save with photos - use captured image as before photo
            let beforePhoto = capturedImage
            appState.saveRecipeWithPhotos(baseRecipe, beforePhoto: beforePhoto, afterPhoto: nil)
            
            // Store photos in PhotoStorageManager for future access
            PhotoStorageManager.shared.storePhotos(
                fridgePhoto: beforePhoto,
                mealPhoto: nil,
                for: recipe.id
            )
            print("📸 Photos stored: before=\(beforePhoto != nil), after=nil")
            
            // Save to CloudKit if authenticated (will sync later if not)
            if cloudKitAuth.isAuthenticated {
                Task {
                    _ = try? await CloudKitRecipeManager.shared.uploadRecipe(
                        baseRecipe,
                        fromLLM: true,
                        beforePhoto: beforePhoto
                    )
                    print("☁️ Recipe uploaded to CloudKit with photos")
                }
            }
            
            // Haptic feedback for save
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        
        print("🔍 Updated saved IDs: \(savedRecipeIds)")
    }
    
    private func isSaved(_ recipe: DetectiveRecipe) -> Bool {
        let saved = savedRecipeIds.contains(recipe.id)
        return saved
    }
    
    private func getBeforePhotoForDetectiveRecipe() -> UIImage? {
        // First try to use the captured image from the current session
        if let capturedImage = capturedImage {
            return capturedImage
        }
        
        // Then check PhotoStorageManager
        if let recipe = detectiveRecipe {
            let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
            return photos?.fridgePhoto
        }
        
        return nil
    }
    
    private func getAfterPhotoForDetectiveRecipe() -> UIImage? {
        // Check PhotoStorageManager for after photo
        if let recipe = detectiveRecipe {
            let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
            return photos?.mealPhoto ?? afterPhoto
        }
        
        return afterPhoto
    }
    
    // MARK: - Detective Photo Container
    private func detectivePhotoContainer(recipe: DetectiveRecipe) -> some View {
        ZStack {
            // Background gradient
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
            
            HStack(spacing: 0) {
                // Before Photo (Left Side)
                ZStack {
                    if let beforePhoto = getBeforePhotoForRecipe(recipe) {
                        GeometryReader { geometry in
                            Image(uiImage: beforePhoto)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        }
                    } else {
                        VStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.5))
                            Text("Original")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    VStack {
                        Spacer()
                        if getBeforePhotoForRecipe(recipe) != nil {
                            Text("BEFORE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.6))
                                )
                                .padding(.bottom, 4)
                        }
                    }
                )
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1)
                
                // After Photo (Right Side) - Clickable
                Button(action: {
                    selectedRecipeForPhoto = recipe
                    showingAfterPhotoCapture = true
                }) {
                    ZStack {
                        if let afterPhoto = getAfterPhotoForRecipe(recipe) {
                            GeometryReader { geometry in
                                Image(uiImage: afterPhoto)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            }
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Take Photo")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    .scaleEffect(1.02)
                                    .opacity(0.5)
                                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: true)
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    VStack {
                        Spacer()
                        Text("AFTER")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                            )
                            .padding(.bottom, 4)
                    }
                )
                .buttonStyle(PlainButtonStyle())
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func getBeforePhotoForRecipe(_ recipe: DetectiveRecipe) -> UIImage? {
        // First try the captured image from current session
        if let capturedImage = capturedImage, recipe.id == detectiveRecipe?.id {
            return capturedImage
        }
        
        // Then check PhotoStorageManager
        let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
        return photos?.fridgePhoto
    }
    
    private func getAfterPhotoForRecipe(_ recipe: DetectiveRecipe) -> UIImage? {
        // Check if we have a temporary after photo for this recipe
        if recipe.id == selectedRecipeForPhoto?.id {
            if let afterPhoto = afterPhoto {
                return afterPhoto
            }
        }
        
        // Check PhotoStorageManager
        let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
        return photos?.mealPhoto
    }
    
}

// MARK: - Detective Recipe Detail View
struct DetectiveRecipeDetailView: View {
    let recipe: DetectiveRecipe
    @EnvironmentObject var appState: AppState
    @State private var showingSharePopup = false
    @State private var shareContent: ShareContent?
    @State private var capturedImage: UIImage?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero Section with Confidence
                detectiveHeroSection
                
                // Quick Stats
                quickStatsSection
                
                // Description
                descriptionSection
                
                // Ingredients Section
                ingredientsSection
                
                // Instructions Section
                instructionsSection
                
                // Pro Tips Section
                if !recipe.proTips.isEmpty {
                    proTipsSection
                }
                
                // Secret Ingredients Section
                if !recipe.secretIngredients.isEmpty {
                    secretIngredientsSection
                }
                
                // Cooking Techniques Section
                if !recipe.cookingTechniques.isEmpty {
                    cookingTechniquesSection
                }
                
                // Flavor Profile Section
                if let flavorProfile = recipe.flavorProfile {
                    flavorProfileSection(flavorProfile)
                }
                
                // Visual Clues Section
                if !recipe.visualClues.isEmpty {
                    visualCluesSection
                }
                
                // Nutrition Section
                nutritionSection
                
                // Action Buttons
                actionButtonsSection
                
                // Bottom padding for tab bar
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal)
        }
        .background(MagicalBackground())
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingSharePopup) {
            if let shareContent = shareContent {
                BrandedSharePopup(content: shareContent)
            }
        }
    }
    
    // MARK: - View Components
    
    private var detectiveHeroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Confidence Badge
            HStack {
                Text(recipe.confidenceEmoji)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confidence: \(Int(recipe.confidenceScore))%")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(recipe.confidenceDescription)
                        .font(.caption)
                        .foregroundColor(recipe.confidenceColor)
                }
                
                Spacer()
                
                // Confidence meter
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 100, height: 8)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(recipe.confidenceColor)
                        .frame(width: CGFloat(recipe.confidenceScore), height: 8)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(recipe.confidenceColor.opacity(0.5), lineWidth: 1)
                    )
            )
            
            // Original Dish Info
            VStack(alignment: .leading, spacing: 8) {
                Label("Original Dish", systemImage: "fork.knife")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(recipe.originalDishName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let style = recipe.restaurantStyle {
                    Text(style)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#9b59b6").opacity(0.3))
                        )
                }
            }
        }
    }
    
    private var quickStatsSection: some View {
        HStack(spacing: 16) {
            DetectiveStatCard(icon: "clock", title: "Time", value: "\(recipe.prepTime + recipe.cookTime) min")
            DetectiveStatCard(icon: "person.2", title: "Servings", value: "\(recipe.servings)")
            DetectiveStatCard(icon: "chart.bar", title: "Difficulty", value: recipe.difficulty.rawValue.capitalized)
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(recipe.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(recipe.ingredients, id: \.id) { ingredient in
                HStack {
                    Circle()
                        .fill(Color(hex: "#9b59b6").opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    Text(ingredient.name)
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if !ingredient.quantity.isEmpty {
                        Text(ingredient.quantity)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color(hex: "#9b59b6").opacity(0.5))
                        )
                    
                    Text(instruction)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var proTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Pro Tips")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            ForEach(recipe.proTips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(Color.yellow.opacity(0.8))
                    Text(tip)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var secretIngredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.open.fill")
                    .foregroundColor(Color(hex: "#9b59b6"))
                Text("Secret Ingredients")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            ForEach(recipe.secretIngredients, id: \.self) { secret in
                HStack {
                    Image(systemName: "sparkle")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#9b59b6").opacity(0.8))
                    Text(secret)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#9b59b6").opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#9b59b6").opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var cookingTechniquesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Cooking Techniques")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            ForEach(recipe.cookingTechniques, id: \.self) { technique in
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.orange.opacity(0.8))
                    Text(technique)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func flavorProfileSection(_ profile: DetectiveFlavorProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(Color(hex: "#3498db"))
                Text("Flavor Profile")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                FlavorBar(label: "Sweet", value: profile.sweet, color: .pink)
                FlavorBar(label: "Salty", value: profile.salty, color: .blue)
                FlavorBar(label: "Sour", value: profile.sour, color: .green)
                FlavorBar(label: "Bitter", value: profile.bitter, color: .brown)
                FlavorBar(label: "Umami", value: profile.umami, color: .orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#3498db").opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#3498db").opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var visualCluesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(Color(hex: "#2ecc71"))
                Text("Visual Clues")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            ForEach(recipe.visualClues, id: \.self) { clue in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#2ecc71").opacity(0.8))
                    Text(clue)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#2ecc71").opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#2ecc71").opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                NutritionCard(label: "Calories", value: "\(recipe.nutrition.calories)", unit: "cal")
                NutritionCard(label: "Protein", value: "\(recipe.nutrition.protein)", unit: "g")
                NutritionCard(label: "Carbs", value: "\(recipe.nutrition.carbs)", unit: "g")
                NutritionCard(label: "Fat", value: "\(recipe.nutrition.fat)", unit: "g")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                saveRecipe()
            }) {
                HStack {
                    Image(systemName: isSaved() ? "heart.fill" : "heart")
                    Text(isSaved() ? "Saved" : "Save")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: isSaved() ? [Color(hex: "#4CAF50"), Color(hex: "#45a049")] : [Color(hex: "#9b59b6"), Color(hex: "#8e44ad")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            
            Button(action: {
                prepareShareContent()
                showingSharePopup = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#3498db"), Color(hex: "#2980b9")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Helper Functions
    
    private func saveRecipe() {
        let baseRecipe = recipe.toBaseRecipe()
        
        // Toggle save state
        if let index = appState.savedRecipes.firstIndex(where: { $0.id == baseRecipe.id }) {
            // Already saved - remove it
            appState.savedRecipes.remove(at: index)
            
            // Remove from CloudKit if authenticated
            if UnifiedAuthManager.shared.isAuthenticated {
                Task {
                    try? await CloudKitRecipeManager.shared.removeRecipeFromUserProfile(
                        baseRecipe.id.uuidString,
                        type: .saved
                    )
                }
            }
            
            // Haptic feedback for unsave
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } else {
            // Not saved - add it
            appState.savedRecipes.append(baseRecipe)
            
            // Save to CloudKit if authenticated (will sync later if not)
            if UnifiedAuthManager.shared.isAuthenticated {
                Task {
                    _ = try? await CloudKitRecipeManager.shared.uploadRecipe(baseRecipe)
                }
            }
            
            // Haptic feedback for save
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    private func isSaved() -> Bool {
        return appState.savedRecipes.contains(where: { $0.id == recipe.id })
    }
    
    private func prepareShareContent() {
        // Get photos from PhotoStorageManager
        // Get photos from PhotoStorageManager
        let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
        let beforePhoto = capturedImage ?? photos?.fridgePhoto
        let afterPhoto = photos?.mealPhoto
        
        // Create share content
        shareContent = ShareContent(
            type: .recipe(recipe.toBaseRecipe()),
            beforeImage: beforePhoto,
            afterImage: afterPhoto
        )
    }
}

// MARK: - Supporting Views

struct DetectiveStatCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#9b59b6"))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct FlavorBar: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 60, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value) / 10, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(value)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 20, alignment: .trailing)
        }
    }
}

struct NutritionCard: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            
            HStack(spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Camera Detective View
struct CameraDetectiveView: View {
    @Binding var capturedImage: UIImage?
    @Binding var isAnalyzing: Bool
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var cameraModel = CameraModel()
    
    var body: some View {
        ZStack {
            // Camera preview background
            if cameraModel.isCameraAuthorized {
                CameraPreview(cameraModel: cameraModel)
                    .ignoresSafeArea()
                    .opacity(cameraModel.isSessionReady ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: cameraModel.isSessionReady)
            } else {
                // Fallback background when camera not available
                LinearGradient(
                    colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.3))
            }
            
            // Camera controls overlay
            VStack {
                // Top bar with close button
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    // Detective indicator
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Detective Mode")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#9b59b6").opacity(0.6), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
                
                // Instructions
                if cameraModel.isSessionReady {
                    Text("Point your camera at the restaurant dish")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.bottom, 30)
                }
                
                // Bottom controls
                VStack(spacing: 16) {
                    // Main capture button
                    DetectiveCameraCaptureButton {
                        capturePhoto()
                    }
                }
                .padding(.bottom, 50)
            }
            
            // Scanning overlay for visual feedback
            if cameraModel.isSessionReady {
                DetectiveScanningOverlay()
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            print("🔍 DEBUG: CameraDetectiveView appeared - Start")
            DispatchQueue.main.async {
                print("🔍 DEBUG: CameraDetectiveView - Async block started")
                cameraModel.requestCameraPermission()
                print("🔍 DEBUG: CameraDetectiveView - Async block completed")
            }
            print("🔍 DEBUG: CameraDetectiveView appeared - End")
        }
        .onDisappear {
            cameraModel.stopSession()
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private func capturePhoto() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        cameraModel.capturePhoto { image in
            capturedImage = image
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Detective Camera Capture Button
struct DetectiveCameraCaptureButton: View {
    let action: () -> Void
    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring with detective purple gradient
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#9b59b6"),
                                Color(hex: "#8e44ad")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 90, height: 90)
                    .scaleEffect(pulseScale)
                
                // Inner circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 75, height: 75)
                    .scaleEffect(isPressed ? 0.9 : 1)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, y: 3)
                
                // Center magnifying glass icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(Color(hex: "#9b59b6"))
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            print("🔍 DEBUG: DetectiveCameraCaptureButton appeared - Start")
            DispatchQueue.main.async {
                print("🔍 DEBUG: DetectiveCameraCaptureButton - Async block started")
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                }
                print("🔍 DEBUG: DetectiveCameraCaptureButton - Async block completed")
            }
            print("🔍 DEBUG: DetectiveCameraCaptureButton appeared - End")
        }
    }
}

// MARK: - Detective Scanning Overlay
struct DetectiveScanningOverlay: View {
    @State private var scanLineOffset: CGFloat = -200
    @State private var cornerAnimation = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Corner brackets with detective purple
                ForEach(0..<4) { index in
                    DetectiveCornerBracket(corner: index)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#9b59b6"),
                                    Color(hex: "#8e44ad")
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
                                Color(hex: "#9b59b6").opacity(0.5),
                                Color(hex: "#8e44ad"),
                                Color(hex: "#9b59b6").opacity(0.5),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .blur(radius: 1)
                    .offset(y: scanLineOffset)
                
                // Center focus with food icon
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(Color.white.opacity(0.3))
                    
                    Text("Analyzing dish...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.6))
                }
            }
        }
        .onAppear {
            print("🔍 DEBUG: DetectiveScanningOverlay appeared - Start")
            DispatchQueue.main.async {
                print("🔍 DEBUG: DetectiveScanningOverlay - Async block started")
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
                    scanLineOffset = 200
                }
                
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    cornerAnimation = true
                }
                print("🔍 DEBUG: DetectiveScanningOverlay - Async block completed")
            }
            print("🔍 DEBUG: DetectiveScanningOverlay appeared - End")
        }
    }
    
    private func cornerPosition(for index: Int, in size: CGSize) -> CGPoint {
        let padding: CGFloat = 80
        switch index {
        case 0: return CGPoint(x: padding, y: padding)
        case 1: return CGPoint(x: size.width - padding, y: padding)
        case 2: return CGPoint(x: padding, y: size.height - padding)
        case 3: return CGPoint(x: size.width - padding, y: size.height - padding)
        default: return .zero
        }
    }
}

// MARK: - Detective Corner Bracket
struct DetectiveCornerBracket: Shape {
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

#Preview {
    DetectiveView()
        .environmentObject(AppState())
}