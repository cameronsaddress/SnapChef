import SwiftUI

struct RecipeResultsView: View {
    let recipes: [Recipe]
    let ingredients: [IngredientAPI]
    let capturedImage: UIImage?
    var isPresented: Binding<Bool>?  // Optional binding for direct control
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var authManager = UnifiedAuthManager.shared
    @State private var activeSheet: ActiveSheet?
    // Use LocalRecipeManager instead of LocalRecipeStorage
    @StateObject private var localManager = LocalRecipeManager.shared
    
    // Computed property that directly reflects LocalRecipeManager state
    private var savedRecipeIds: Set<UUID> {
        Set(recipes.compactMap { recipe in
            localManager.isRecipeSaved(recipe.id) ? recipe.id : nil
        })
    }
    // Authentication states
    @State private var showAuthPrompt = false
    @State private var pendingAction: PendingAction?
    
    enum PendingAction {
        case save(Recipe)
        case like(Recipe)
        
        var actionName: String {
            switch self {
            case .save: return "save"
            case .like: return "like"
            }
        }
        
        var recipeName: String {
            switch self {
            case .save(let recipe), .like(let recipe):
                return recipe.name
            }
        }
    }
    
    // New states for branded share
    @State private var showBrandedShare = false
    @State private var shareContent: ShareContent?
    
    // Detective-style animation states
    @State private var recipesDiscoveredAnimation = false
    @State private var sparkleAnimation = false
    @State private var cardEntranceAnimations = Array(repeating: false, count: 5)
    @State private var topSectionVisible = false
    @State private var showViralPrompt = false
    @State private var didTrackViralPrompt = false
    @State private var viralPromptTask: Task<Void, Never>?
    @State private var preparingShare = false
    @State private var sharePrepPulse = false
    @State private var showShareMomentum = false
    @State private var shareMomentumPulse = false
    @State private var shareMomentumMessage = "Share one recipe this month to unlock bonus coins."
    @State private var shareMomentumCount = 0
    @State private var entryHeroVisible = false
    @State private var entryHeroOpacity: Double = 0
    @State private var entryHeroScale: CGFloat = 1.08
    @State private var entryHeroOffset: CGFloat = 20
    @State private var heroCardAccent = false
    
    enum ActiveSheet: Identifiable {
        case recipeDetail(Recipe)
        case fridgeInventory
        
        var id: String {
            switch self {
            case .recipeDetail(let recipe): return "detail_\(recipe.id)"
            case .fridgeInventory: return "fridge_inventory"
            }
        }
    }
    
    init(recipes: [Recipe], ingredients: [IngredientAPI] = [], capturedImage: UIImage? = nil, isPresented: Binding<Bool>? = nil) {
        self.recipes = recipes
        self.ingredients = ingredients
        self.capturedImage = capturedImage
        self.isPresented = isPresented
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            // Dark detective background - exact same as DetectiveResultsView
            LinearGradient(
                colors: [
                    Color(hex: "#0b1024"),
                    Color(hex: "#1a0a33"),
                    Color(hex: "#12061f")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#38f9d7").opacity(0.22), .clear],
                        center: .center,
                        startRadius: 12,
                        endRadius: 220
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 10)
                .offset(x: -120, y: -260)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#f093fb").opacity(0.2), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 260
                    )
                )
                .frame(width: 360, height: 360)
                .blur(radius: 14)
                .offset(x: 140, y: 240)
            
            ScrollView {
                LazyVStack(spacing: 30) {
                    // Add top padding to avoid navigation bar overlap
                    Color.clear.frame(height: 1)

                    ResultsHeroCard(recipeCount: recipes.count, sourceImage: capturedImage, accent: heroCardAccent)
                        .padding(.horizontal, 20)
                        .opacity(topSectionVisible ? 1 : 0)
                        .offset(y: topSectionVisible ? 0 : 12)
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: topSectionVisible)

                    if !ingredients.isEmpty {
                        FridgeInventoryCard(ingredientCount: ingredients.count) {
                            activeSheet = .fridgeInventory
                        }
                        .padding(.horizontal, 20)
                        .opacity(topSectionVisible ? 1 : 0)
                        .offset(y: topSectionVisible ? 0 : 12)
                        .animation(.spring(response: 0.5, dampingFraction: 0.84).delay(0.06), value: topSectionVisible)
                    }

                    if showViralPrompt, let leadRecipe = recipes.first {
                        ViralSharePrompt {
                            handleViralPromptTap(recipe: leadRecipe)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    if showShareMomentum, let leadRecipe = recipes.first {
                        ShareMomentumCard(
                            monthlyShareCount: shareMomentumCount,
                            message: shareMomentumMessage,
                            pulse: shareMomentumPulse
                        ) {
                            handleViralPromptTap(recipe: leadRecipe)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Recipe Cards with Detective styling
                    ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                        DetectiveRecipeCard(
                            recipe: recipe,
                            isSaved: savedRecipeIds.contains(recipe.id),
                            capturedImage: capturedImage,
                            isAuthenticated: authManager.isAuthenticated,
                            onSelect: {
                                activeSheet = .recipeDetail(recipe)
                            },
                            onShare: {
                                presentBrandedShare(for: recipe, source: "recipe_card")
                            },
                            onSave: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    saveRecipe(recipe)
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                        .allowsHitTesting(true) // Force hit testing to be enabled
                        .opacity(cardEntranceAnimations[safe: index] == true ? 1 : 0)
                        .scaleEffect(cardEntranceAnimations[safe: index] == true ? 1 : 0.9)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                                .delay(0.1 + Double(index) * 0.1),
                            value: cardEntranceAnimations[safe: index]
                        )
                    }
                    
                    Spacer(minLength: 50)
                }
            }

            if entryHeroVisible, let capturedImage {
                VStack {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 260, height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.34), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: "#38f9d7").opacity(0.24), radius: 24, y: 10)
                        .opacity(entryHeroOpacity)
                        .scaleEffect(entryHeroScale)
                        .offset(y: entryHeroOffset)
                    Spacer()
                }
                .padding(.top, 96)
                .allowsHitTesting(false)
            }
            
            if preparingShare {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#667eea"), Color(hex: "#9b59b6")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                                .scaleEffect(sharePrepPulse ? 1.04 : 0.95)

                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text("Preparing Share Card")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Optimizing your result for social")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .transition(.opacity.combined(with: .scale))
            }
            // Removed .onTapGesture { } that was intercepting button taps
        }
    }
    
    var body: some View {
        NavigationStack {
            mainContent
            .navigationTitle("Your Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: dismissResults) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#9b59b6"), Color(hex: "#8e44ad")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !savedRecipeIds.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                            Text("\(savedRecipeIds.count)")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "#4CAF50"))
                    }
                }
            }
            .onAppear {
                startAnimations()
                scheduleViralPromptPresentation()
                refreshShareMomentumFromStorage()
                withAnimation(.easeInOut(duration: MotionTuning.seconds(1.8)).repeatForever(autoreverses: true)) {
                    shareMomentumPulse = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ViralShareCompleted"))) { notification in
                let platform = notification.userInfo?["platform"] as? String ?? "Share"
                let monthlyCount = notification.userInfo?["monthlyShareCount"] as? Int ?? shareMomentumCount
                let bonusCoins = notification.userInfo?["bonusCoins"] as? Int ?? 0

                shareMomentumCount = monthlyCount
                if bonusCoins > 0 {
                    shareMomentumMessage = "Nice. \(platform) share sent. +\(bonusCoins) bonus coins earned."
                } else {
                    shareMomentumMessage = "\(platform) share tracked. Keep momentum going."
                }

                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    showShareMomentum = true
                }
            }
            .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .recipeDetail(let recipe):
                // Use the same detail view as Detective
                RecipeDetailView(recipe: recipe)
            case .fridgeInventory:
                SimpleFridgeInventoryView(
                    ingredients: ingredients,
                    capturedImage: capturedImage
                )
            }
        }
        // Add branded share popup sheet
        .sheet(isPresented: $showBrandedShare) {
            if let content = shareContent {
                BrandedSharePopup(content: content)
            }
        }
        // Authentication prompt sheet
        .sheet(isPresented: $showAuthPrompt) {
            ProgressiveAuthPrompt(overrideContext: .featureUnlock)
                .onDisappear {
                    completePendingActionAfterAuthentication()
                }
        }
        .onDisappear {
            viralPromptTask?.cancel()
            viralPromptTask = nil
        }
        } // End NavigationStack
    }
    
    private func saveRecipe(_ recipe: Recipe) {
        // Check authentication first
        guard authManager.isAuthenticated else {
            pendingAction = .save(recipe)
            showAuthPrompt = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        
        // LOCAL-FIRST: Instant update, no waiting for network
        let currentlySaved = localManager.isRecipeSaved(recipe.id)
        
        // 1. Haptic feedback (instant)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // 2. Update local storage with animation
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            if currentlySaved {
                // UNSAVE
                localManager.unsaveRecipe(recipe.id)
            
                // Update AppState for other views
                appState.savedRecipes.removeAll { $0.id == recipe.id }
                appState.recentRecipes.removeAll { $0.id == recipe.id }
                appState.savedRecipesWithPhotos.removeAll { $0.recipe.id == recipe.id }
                
            } else {
                // SAVE
                localManager.saveRecipe(recipe, capturedImage: capturedImage)
                
                // Update AppState for other views
                if !appState.savedRecipes.contains(where: { $0.id == recipe.id }) {
                    appState.savedRecipes.append(recipe)
                    appState.addRecentRecipe(recipe)
                }
                
                // Store photos in AppState's saved recipes with photos
                if let photo = capturedImage {
                    let savedRecipe = SavedRecipe(recipe: recipe, beforePhoto: photo, afterPhoto: nil)
                    if !appState.savedRecipesWithPhotos.contains(where: { $0.recipe.id == recipe.id }) {
                        appState.savedRecipesWithPhotos.append(savedRecipe)
                    }
                }
            }
        }
        
        // 4. Background activities (fire and forget)
        Task {
            // Track streak activity if saving (not unsaving)
            // NOTE: We don't create a social feed activity for saving - that's private
            // Only sharing creates social activities
            if !currentlySaved {
                await StreakManager.shared.recordActivity(for: .recipeCreation)
                
                if recipe.nutrition.calories < 500 {
                    await StreakManager.shared.recordActivity(for: .healthyEating)
                }
            }
        }
        
        // CloudKit sync happens automatically in background via RecipeSyncQueue
    }

    private func completePendingActionAfterAuthentication() {
        defer { pendingAction = nil }
        guard authManager.isAuthenticated, let pending = pendingAction else { return }

        switch pending {
        case .save(let recipe):
            DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(0.4)) {
                saveRecipe(recipe)
            }
        case .like(let recipe):
            print("Like action for: \(recipe.name)")
        }
    }
    
    private func startAnimations() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if capturedImage != nil {
            entryHeroVisible = true
            entryHeroOpacity = 0
            entryHeroScale = 1.08
            entryHeroOffset = 20
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                entryHeroOpacity = 0.95
                entryHeroScale = 1.0
                entryHeroOffset = 0
            }
        }

        withAnimation(.spring(response: MotionTuning.seconds(0.45), dampingFraction: 0.82)) {
            topSectionVisible = true
            heroCardAccent = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(0.18)) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(0.42)) {
            withAnimation(.easeOut(duration: MotionTuning.seconds(0.24))) {
                entryHeroOpacity = 0
                entryHeroScale = 0.92
                entryHeroOffset = -42
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(0.24)) {
                entryHeroVisible = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(0.5)) {
            recipesDiscoveredAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(1.8)) {
            sparkleAnimation = true
        }
        
        // Stagger card entrance animations - start immediately
        for i in 0..<min(recipes.count, 5) {
            DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(0.1 + Double(i) * 0.1)) {
                if i < cardEntranceAnimations.count {
                    cardEntranceAnimations[i] = true
                }
            }
        }
    }

    private func scheduleViralPromptPresentation() {
        guard !didTrackViralPrompt, !recipes.isEmpty else { return }

        viralPromptTask?.cancel()
        viralPromptTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(1.35))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: MotionTuning.seconds(0.45), dampingFraction: 0.85)) {
                showViralPrompt = true
            }
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            didTrackViralPrompt = true
            GrowthLoopManager.shared.trackViralPromptShown(recipeCount: recipes.count)
        }
    }

    private func handleViralPromptTap(recipe: Recipe) {
        GrowthLoopManager.shared.trackViralCTATapped(recipeID: recipe.id)
        presentBrandedShare(for: recipe, source: "viral_prompt")
    }

    private func presentBrandedShare(for recipe: Recipe, source: String) {
        guard !preparingShare else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
        let beforeImage = photos?.fridgePhoto ?? photos?.pantryPhoto ?? capturedImage
        let afterImage = photos?.mealPhoto

        shareContent = ShareContent(
            type: .recipe(recipe),
            beforeImage: beforeImage,
            afterImage: afterImage
        )
        
        withAnimation(.easeOut(duration: MotionTuning.seconds(0.18))) {
            preparingShare = true
            sharePrepPulse = true
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(0.18))
            showBrandedShare = true
            try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(0.12))
            withAnimation(.easeIn(duration: MotionTuning.seconds(0.18))) {
                preparingShare = false
                sharePrepPulse = false
            }
        }

        AnalyticsManager.shared.logEvent(
            "viral_share_started",
            parameters: [
                "source": source,
                "recipe_id": recipe.id.uuidString
            ]
        )
    }
    
    private func refreshShareMomentumFromStorage() {
        let defaults = UserDefaults.standard
        let currentBucket = currentMonthBucket()
        let storedBucket = defaults.string(forKey: "growth_share_reward_month_bucket")
        if storedBucket == currentBucket {
            shareMomentumCount = defaults.integer(forKey: "growth_share_reward_count")
        } else {
            shareMomentumCount = 0
        }
        showShareMomentum = true
        if shareMomentumCount == 0 {
            shareMomentumMessage = "Share one recipe this month to unlock bonus coins."
        } else {
            shareMomentumMessage = "You have \(shareMomentumCount) share\(shareMomentumCount == 1 ? "" : "s") this month. Push one more for extra reach."
        }
    }
    
    private func currentMonthBucket() -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: Date())
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }

    private func dismissResults() {
        if let binding = isPresented {
            binding.wrappedValue = false
        } else {
            dismiss()
        }
    }
}

// MARK: - Array Safe Access Extension
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Detective Recipe Card
struct DetectiveRecipeCard: View {
    let recipe: Recipe
    let isSaved: Bool
    let capturedImage: UIImage?
    let isAuthenticated: Bool  // Pass auth status from parent
    let onSelect: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        mainCardView
    }
    
    @ViewBuilder
    private var mainCardView: some View {
        VStack(spacing: 0) {
            // Photo container at top (full width, 150px height, no padding)
            detectivePhotoContainer(recipe: recipe)
                .frame(height: 150)
                .clipped()
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 16
                ))
            
            // Content below photo
            VStack(spacing: 20) {
                    // Confidence indicator (95% match for recipes)
                    confidenceSection
                
                // Recipe info
                recipeInfoSection
                
                // Action buttons at bottom
                actionButtonsSection
            }
            .padding(20)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 0
                )
                .fill(Color.white.opacity(0.1))
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 16,
                        topTrailingRadius: 0
                    )
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#ffd700").opacity(0.4),
                                Color(hex: "#2d1b69").opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 16,
                        topTrailingRadius: 0
                    )
                    .fill(.ultraThinMaterial.opacity(0.2))
                )
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#ffd700").opacity(0.4),
                                    Color(hex: "#2d1b69").opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
    }
    
    // MARK: - Sub-views
    @ViewBuilder
    private var confidenceSection: some View {
        HStack(spacing: 12) {
            Text("🎯")
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Confidence: 95%")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Excellent match")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#ffd700"))
            }
            
            Spacer()
            
            Text("95%")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#43e97b"))
        }
    }
    
    @ViewBuilder
    private var recipeInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            recipeHeader
            
            Divider()
                .overlay(Color.white.opacity(0.3))
            
            recipeDescriptionSection
        }
    }
    
    @ViewBuilder
    private var recipeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Generated Recipe")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(recipe.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Difficulty badge
            Text(recipe.difficulty.rawValue.capitalized)
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
    
    @ViewBuilder
    private var recipeDescriptionSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(recipe.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(3)
            }
            
            Spacer()
            
            Button(action: onSelect) {
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
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // Save button - with explicit hit testing priority
            Button {
                onSave()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isAuthenticated ? 
                          (isSaved ? "heart.fill" : "heart") : 
                          "lock.fill")
                    Text(isAuthenticated ? 
                         (isSaved ? "Saved" : "Save") : 
                         "Sign In to Save")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            !isAuthenticated ? 
                            AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: "#667eea").opacity(0.3), Color(hex: "#764ba2").opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )) : 
                            AnyShapeStyle(isSaved ? 
                             Color(hex: "#4CAF50").opacity(0.3) : 
                             Color.white.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(!isAuthenticated ? 
                                       Color(hex: "#667eea").opacity(0.5) : 
                                       Color.clear, lineWidth: 1)
                        )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(StudioSpringButtonStyle(pressedScale: 0.94, pressedYOffset: 1.4, activeRotation: 1.2))
            .zIndex(1)
            
            // Share button - with explicit hit testing priority
            Button {
                onShare()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(StudioSpringButtonStyle(pressedScale: 0.94, pressedYOffset: 1.4, activeRotation: 1.2))
            .zIndex(1)
        }
    }
    
    // Photo container exactly like DetectiveView
    private func detectivePhotoContainer(recipe: Recipe) -> some View {
        ZStack {
            // Background gradient
            Rectangle()
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
                // Before Photo (Left Side) - Fridge image
                Group {
                    if let beforePhoto = capturedImage {
                        Image(uiImage: beforePhoto)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
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
                .clipped()
                .overlay(
                    VStack {
                        Spacer()
                        if capturedImage != nil {
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
                
                // After Photo (Right Side) - Placeholder for cooked meal
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
                .clipped()
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
            }
        }
    }
}

private struct ShareMomentumCard: View {
    let monthlyShareCount: Int
    let message: String
    let pulse: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Viral Momentum", systemImage: "megaphone.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(monthlyShareCount) this month")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#43e97b"))
            }

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)

            Button(action: onTap) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                    Text("Share Lead Recipe")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FF8A00"), Color(hex: "#FF5E62")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .scaleEffect(pulse ? 1.01 : 0.985)
    }
}
// MARK: - Success Header (Legacy - now using Detective style)
struct SuccessHeaderView: View {
    var body: some View {
        VStack(spacing: 20) {
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
        }
        .padding(.top, 40)
    }
}

// MARK: - Time Indicator
struct TimeIndicator: View {
    let minutes: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 14, weight: .semibold))
            Text("\(minutes)m")
                .font(.system(size: 14, weight: .semibold))
                .fixedSize() // Prevent text wrapping
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.2))
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
                .frame(minWidth: 40)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.2))
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
            .padding(.horizontal, difficulty == .medium ? 8 : 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(difficultyColor)
            )
    }
}

// MARK: - Magical Recipe Card
struct MagicalRecipeCard: View {
    let recipe: Recipe
    let isSaved: Bool
    let capturedImage: UIImage?
    let onSelect: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    
    @State private var isHovered = false
    @State private var shimmerPhase: CGFloat = -1
    @StateObject private var likeManager = RecipeLikeManager.shared
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        GlassmorphicCard(content: {
            VStack(alignment: .leading, spacing: 20) {
                // Recipe title at top - clickable
                Text(recipe.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect()
                    }
                
                // Header with before/after photos
                HStack(spacing: 20) {
                    // Recipe photo view with before/after
                    CustomRecipePhotoView(
                        fridgeImage: capturedImage,
                        width: 100,
                        height: 100,
                        showLabels: true
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            TimeIndicator(minutes: recipe.prepTime + recipe.cookTime)
                            CalorieIndicator(calories: recipe.nutrition.calories)
                        }
                        
                        DifficultyBadge(difficulty: recipe.difficulty)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
                
                // Description - clickable
                Text(recipe.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect()
                    }
                
                // Action buttons
                HStack(spacing: 12) {
                    // Like button with count
                    LikeButton(
                        isLiked: likeManager.isRecipeLiked(recipe.id.uuidString),
                        likeCount: likeManager.getLikeCount(for: recipe.id.uuidString),
                        isLoading: false,
                        action: toggleLike
                    )
                    
                    ActionButton(
                        title: isSaved ? "✓" : "Save",
                        icon: isSaved ? "checkmark.circle.fill" : "bookmark.fill",
                        color: isSaved ? Color(hex: "#43e97b") : Color(hex: "#667eea"),
                        action: onSave
                    )
                    .disabled(isSaved)
                    
                    ActionButton(
                        title: "Share",
                        icon: "square.and.arrow.up",
                        color: Color(hex: "#9b59b6"),
                        action: onShare
                    )
                }
            }
            .padding(24)
        }, glowColor: Color(hex: "#667eea"))
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func toggleLike() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Use like manager for centralized state management
        Task {
            await likeManager.toggleLike(for: recipe.id.uuidString)
        }
    }
}

// MARK: - Like Button
struct LikeButton: View {
    let isLiked: Bool
    let likeCount: Int
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isLiked ? Color(hex: "#ff6b6b") : .white)
                    .scaleEffect(isLiked ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                
                if likeCount > 0 {
                    Text("\(likeCount)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isLiked ? Color(hex: "#ff6b6b").opacity(0.2) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isLiked ? Color(hex: "#ff6b6b") : Color.white.opacity(0.3), lineWidth: 1.5)
                    )
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        // Use ZStack with onTapGesture for reliable tap detection
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(color)
            
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .allowsHitTesting(false) // Prevent content from blocking taps
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44) // Fixed height for consistent tap target
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Results Hero
struct ResultsHeroCard: View {
    let recipeCount: Int
    let sourceImage: UIImage?
    let accent: Bool
    @State private var pulse = false
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#43e97b"), Color(hex: "#38f9d7")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .scaleEffect(pulse ? 1.06 : 1.0)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("\(recipeCount) recipes ready")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Pick one and start cooking")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
            }

            if let sourceImage {
                Image(uiImage: sourceImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "#38f9d7").opacity(0.22), radius: 12, y: 6)
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(accent ? 0.44 : 0.2),
                                    Color(hex: "#38f9d7").opacity(shimmer ? 0.52 : 0.22),
                                    Color(hex: "#f093fb").opacity(shimmer ? 0.46 : 0.18),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: shimmer ? .topLeading : .bottomTrailing,
                                endPoint: shimmer ? .bottomTrailing : .topLeading
                            ),
                            lineWidth: 1.2
                        )
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Viral Share Prompt
struct ViralSharePrompt: View {
    let action: () -> Void
    @State private var pulseAnimation = false
    @State private var borderShift = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Show off your best dish")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("One tap to create a branded share card.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.76))

            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Share This Result")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#667eea"), Color(hex: "#9b59b6")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(pulseAnimation ? 1.01 : 1)
                )
            }
            .buttonStyle(StudioSpringButtonStyle(pressedScale: 0.93, pressedYOffset: 1.8, activeRotation: 1.6))
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color(hex: "#38f9d7").opacity(0.55),
                                    Color(hex: "#f093fb").opacity(0.5),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: borderShift ? .topLeading : .bottomTrailing,
                                endPoint: borderShift ? .bottomTrailing : .topLeading
                            ),
                            lineWidth: 1.2
                        )
                )
        )
        .shadow(color: Color(hex: "#f093fb").opacity(0.18), radius: 18, y: 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                borderShift = true
            }
        }
    }
}

// MARK: - Fridge Inventory Card
struct FridgeInventoryCard: View {
    let ingredientCount: Int
    let onTap: () -> Void
    
    @State private var bounceAnimation = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#38f9d7"), Color(hex: "#43e97b")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .scaleEffect(bounceAnimation ? 1.05 : 1)
                Image(systemName: "refrigerator.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(ingredientCount) ingredients found")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Tap to review your inventory")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.76))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .offset(x: bounceAnimation ? 2 : 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onTapGesture {
            onTap()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                bounceAnimation = true
            }
        }
    }
}

// MARK: - Simple Fridge Inventory View
struct SimpleFridgeInventoryView: View {
    let ingredients: [IngredientAPI]
    let capturedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "refrigerator.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#38f9d7"),
                                            Color(hex: "#43e97b")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Found \(ingredients.count) ingredients!")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 40)
                        
                        // Ingredients list
                        ForEach(ingredients, id: \.name) { ingredient in
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(ingredient.name)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("\(ingredient.quantity) \(ingredient.unit)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    HStack(spacing: 12) {
                                        Label(ingredient.category, systemImage: "tag.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "#38f9d7"))
                                        
                                        Label(ingredient.freshness, systemImage: "leaf.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(freshnessColor(for: ingredient.freshness))
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                }
            })
    }
    
    private func freshnessColor(for freshness: String) -> Color {
        switch freshness.lowercased() {
        case "fresh": return Color(hex: "#43e97b")
        case "good": return Color(hex: "#38f9d7")
        case "use soon": return Color(hex: "#ffa726")
        default: return Color.gray
        }
    }
}

// MARK: - Activity View (ShareSheet replacement)
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Custom Recipe Photo View for Results
struct CustomRecipePhotoView: View {
    let fridgeImage: UIImage?
    let width: CGFloat
    let height: CGFloat
    let showLabels: Bool
    
    private var halfWidth: CGFloat {
        width / 2
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Before (Fridge) Photo - Left Side
            beforePhotoView
                .frame(width: halfWidth, height: height)
                .clipped()
                .overlay(beforeLabel)
            
            // Divider line
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 1)
            
            // After (Camera Icon) - Right Side
            afterPhotoPlaceholder
                .frame(width: halfWidth, height: height)
                .clipped()
                .overlay(afterLabel)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(width: width, height: height)
    }
    
    private var beforePhotoView: some View {
        Group {
            if let photo = fridgeImage {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(Color.black.opacity(0.2))
            } else {
                beforePhotoPlaceholder
            }
        }
    }
    
    private var beforePhotoPlaceholder: some View {
        VStack {
            Image(systemName: "refrigerator")
                .font(.system(size: max(height * 0.25, 20)))  // Ensure minimum size
                .foregroundColor(.white.opacity(0.5))
            if showLabels {
                Text("Fridge")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#667eea"),
                    Color(hex: "#764ba2")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private var afterPhotoPlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "camera.fill")
                .font(.system(size: max(height * 0.2, 16)))  // Ensure minimum size
                .foregroundColor(.white.opacity(0.7))
            if showLabels {
                Text("After")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#667eea"),
                    Color(hex: "#764ba2")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private var beforeLabel: some View {
        Group {
            if showLabels && fridgeImage != nil {
                VStack {
                    Spacer()
                    labelBadge(text: "BEFORE")
                        .padding(.bottom, 4)
                }
            }
        }
    }
    
    private var afterLabel: some View {
        Group {
            if showLabels {
                VStack {
                    Spacer()
                    labelBadge(text: "AFTER")
                        .padding(.bottom, 4)
                }
            }
        }
    }
    
    private func labelBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.6))
            )
    }
}

#Preview {
    RecipeResultsView(recipes: MockDataProvider.shared.mockRecipeResponse().recipes ?? [])
}
