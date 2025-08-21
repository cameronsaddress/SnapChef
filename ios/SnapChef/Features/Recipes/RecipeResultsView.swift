import SwiftUI

struct RecipeResultsView: View {
    let recipes: [Recipe]
    let ingredients: [IngredientAPI]
    let capturedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedRecipe: Recipe?
    @State private var showShareSheet = false
    @State private var showShareGenerator = false
    @State private var showSocialShare = false
    @State private var generatedShareImage: UIImage?
    @State private var confettiTrigger = false
    @State private var contentVisible = false
    @State private var activeSheet: ActiveSheet?
    @State private var savedRecipeIds: Set<UUID> = []
    @State private var showingExitConfirmation = false
    
    // New states for branded share
    @State private var showBrandedShare = false
    @State private var shareContent: ShareContent?
    
    // Detective-style animation states
    @State private var recipesDiscoveredAnimation = false
    @State private var sparkleAnimation = false
    @State private var cardEntranceAnimations = Array(repeating: false, count: 5)
    
    enum ActiveSheet: Identifiable {
        case recipeDetail(Recipe)
        case shareGenerator(Recipe)
        case fridgeInventory
        case brandedShare(Recipe)  // Add this for branded share
        
        var id: String {
            switch self {
            case .recipeDetail(let recipe): return "detail_\(recipe.id)"
            case .shareGenerator(let recipe): return "share_\(recipe.id)"
            case .fridgeInventory: return "fridge_inventory"
            case .brandedShare(let recipe): return "branded_\(recipe.id)"
            }
        }
    }
    
    init(recipes: [Recipe], ingredients: [IngredientAPI] = [], capturedImage: UIImage? = nil) {
        self.recipes = recipes
        self.ingredients = ingredients
        self.capturedImage = capturedImage
    }
    
    var body: some View {
        ZStack {
            // Dark detective background - exact same as DetectiveResultsView
            LinearGradient(
                colors: [
                    Color(hex: "#0f0625"),
                    Color(hex: "#1a0033"),
                    Color(hex: "#0a051a")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header with close button
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#9b59b6"), Color(hex: "#8e44ad")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Recipe Cards with Detective styling
                    ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                        DetectiveRecipeCard(
                            recipe: recipe,
                            isSaved: savedRecipeIds.contains(recipe.id),
                            capturedImage: capturedImage,
                            onSelect: {
                                activeSheet = .recipeDetail(recipe)
                                confettiTrigger = true
                            },
                            onShare: {
                                shareContent = ShareContent(
                                    type: .recipe(recipe),
                                    beforeImage: capturedImage,
                                    afterImage: nil
                                )
                                showBrandedShare = true
                            },
                            onSave: {
                                saveRecipe(recipe)
                            }
                        )
                        .padding(.horizontal, 20)
                        .opacity(cardEntranceAnimations[safe: index] == true ? 1 : 0)
                        .scaleEffect(cardEntranceAnimations[safe: index] == true ? 1 : 0.8)
                        .animation(
                            .spring(response: 0.8, dampingFraction: 0.7)
                                .delay(1.2 + Double(index) * 0.2),
                            value: cardEntranceAnimations[safe: index]
                        )
                    }
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("🔍 DEBUG: RecipeResultsView appeared")
            startAnimations()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .recipeDetail(let recipe):
                // Use the same detail view as Detective
                RecipeDetailView(recipe: recipe)
            case .shareGenerator(let recipe):
                ShareGeneratorView(
                    recipe: recipe,
                    ingredientsPhoto: capturedImage
                )
            case .fridgeInventory:
                SimpleFridgeInventoryView(
                    ingredients: ingredients,
                    capturedImage: capturedImage
                )
            case .brandedShare(_):
                // This case is handled by the separate sheet below
                EmptyView()
            }
        }
        // Add branded share popup sheet
        .sheet(isPresented: $showBrandedShare) {
            if let content = shareContent {
                BrandedSharePopup(content: content)
            }
        }
        // Keep old sheets for backward compatibility (not used but available)
        .sheet(isPresented: $showSocialShare) {
            if let recipe = selectedRecipe ?? recipes.first,
               let shareImage = generatedShareImage {
                // Use UIActivityViewController wrapper
                ActivityView(items: [
                    shareImage,
                    "Just turned my fridge into \(recipe.name)! 🔥"
                ])
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let recipe = recipes.first {
                EnhancedShareSheet(recipe: recipe)
            }
        }
        .alert("Exit Without Saving?", isPresented: $showingExitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Exit", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("You haven't saved any recipes yet. They will be lost if you exit now.")
        }
    }
    
    private func saveRecipe(_ recipe: Recipe) {
        print("🔍 DEBUG: Fridge recipe save started for '\(recipe.name)'")
        print("🔍   - savedRecipes count before: \(appState.savedRecipes.count)")
        
        // Save the recipe with the captured image
        appState.addRecentRecipe(recipe)
        appState.saveRecipeWithPhotos(recipe, beforePhoto: capturedImage, afterPhoto: nil)
        
        // CRITICAL FIX: Ensure the recipe is in savedRecipes array (same as Detective)
        // This guarantees it appears in Recipe Book view
        if !appState.savedRecipes.contains(where: { $0.id == recipe.id }) {
            appState.savedRecipes.append(recipe)
            print("🔍   - MANUALLY added recipe to savedRecipes (backup)")
        }
        
        print("🔍   - savedRecipes count after saveRecipeWithPhotos: \(appState.savedRecipes.count)")
        print("🔍   - Recipe now in savedRecipes: \(appState.savedRecipes.contains(where: { $0.id == recipe.id }))")
        
        savedRecipeIds.insert(recipe.id)
        
        // Create activity for recipe save if user is authenticated
        Task {
            if CloudKitAuthManager.shared.isAuthenticated,
               let userID = CloudKitAuthManager.shared.currentUser?.recordID {
                do {
                    try await CloudKitSyncService.shared.createActivity(
                        type: "recipeSaved",
                        actorID: userID,
                        recipeID: recipe.id.uuidString,
                        recipeName: recipe.name
                    )
                } catch {
                    print("Failed to create recipe save activity: \(error)")
                }
            }
            
            // Track streak activities
            await StreakManager.shared.recordActivity(for: .recipeCreation)
            
            // Check if recipe is healthy (under 500 calories)
            if recipe.nutrition.calories < 500 {
                await StreakManager.shared.recordActivity(for: .healthyEating)
            }
        }
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func startAnimations() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            recipesDiscoveredAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            sparkleAnimation = true
        }
        
        // Stagger card entrance animations
        for i in 0..<min(recipes.count, 5) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2 + Double(i) * 0.2) {
                if i < cardEntranceAnimations.count {
                    cardEntranceAnimations[i] = true
                }
            }
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
            Button(action: onSave) {
                HStack(spacing: 8) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                    Text(isSaved ? "Saved" : "Save")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSaved ? Color(hex: "#4CAF50").opacity(0.3) : Color.white.opacity(0.2))
                .cornerRadius(12)
            }
            .disabled(isSaved)
            
            Button(action: onShare) {
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
            .padding(.horizontal, 12)
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
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var isLoadingLike = false
    @StateObject private var cloudKitSync = CloudKitSyncService.shared
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
                        isLiked: isLiked,
                        likeCount: likeCount,
                        isLoading: isLoadingLike,
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
        .task {
            // Load like status when view appears
            await loadLikeStatus()
        }
    }
    
    private func toggleLike() {
        guard !isLoadingLike else { return }
        
        // Apply changes locally first for immediate feedback
        let previousLiked = isLiked
        let previousCount = likeCount
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            likeCount = isLiked ? likeCount + 1 : max(0, likeCount - 1)
        }
        
        // Store local like state
        UserDefaults.standard.set(isLiked, forKey: "like_\(recipe.id.uuidString)")
        UserDefaults.standard.set(likeCount, forKey: "likeCount_\(recipe.id.uuidString)")
        
        // Sync with CloudKit if authenticated
        Task {
            isLoadingLike = true
            defer { isLoadingLike = false }
            
            do {
                if CloudKitAuthManager.shared.isAuthenticated {
                    if previousLiked {
                        try await cloudKitSync.unlikeRecipe(recipe.id.uuidString)
                    } else {
                        let ownerID = CloudKitAuthManager.shared.currentUser?.recordID ?? "anonymous"
                        try await cloudKitSync.likeRecipe(recipe.id.uuidString, recipeOwnerID: ownerID)
                    }
                }
            } catch {
                print("Failed to sync like with CloudKit: \(error)")
                // Revert local changes on failure if authenticated
                if CloudKitAuthManager.shared.isAuthenticated {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isLiked = previousLiked
                            likeCount = previousCount
                        }
                        UserDefaults.standard.set(isLiked, forKey: "like_\(recipe.id.uuidString)")
                        UserDefaults.standard.set(likeCount, forKey: "likeCount_\(recipe.id.uuidString)")
                    }
                }
            }
        }
    }
    
    private func loadLikeStatus() async {
        // Load local like state first
        let localLiked = UserDefaults.standard.bool(forKey: "like_\(recipe.id.uuidString)")
        let localCount = UserDefaults.standard.integer(forKey: "likeCount_\(recipe.id.uuidString)")
        
        await MainActor.run {
            self.isLiked = localLiked
            self.likeCount = localCount
        }
        
        // Try to sync with CloudKit if authenticated
        if CloudKitAuthManager.shared.isAuthenticated {
            do {
                let cloudLiked = try await cloudKitSync.isRecipeLiked(recipe.id.uuidString)
                let cloudCount = try await cloudKitSync.getRecipeLikeCount(recipe.id.uuidString)
                
                await MainActor.run {
                    self.isLiked = cloudLiked
                    self.likeCount = cloudCount
                    // Update local storage with CloudKit data
                    UserDefaults.standard.set(cloudLiked, forKey: "like_\(recipe.id.uuidString)")
                    UserDefaults.standard.set(cloudCount, forKey: "likeCount_\(recipe.id.uuidString)")
                }
            } catch {
                print("Failed to load like status from CloudKit: \(error)")
                // Keep local state if CloudKit fails
            }
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
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
            )
        }
    }
}

// MARK: - Viral Share Prompt
struct ViralSharePrompt: View {
    let action: () -> Void
    @State private var glowAnimation = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎉 Amazing recipes!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Share your culinary journey and inspire others")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            MagneticButton(
                title: "Share & Earn Credits",
                icon: "sparkles",
                action: action
            )
            .shadow(
                color: Color(hex: "#667eea").opacity(glowAnimation ? 0.8 : 0.4),
                radius: glowAnimation ? 30 : 20
            )
        }
        .padding(30)
        .background(
            GlassmorphicCard(content: {
                Color.clear
            }, glowColor: Color(hex: "#9b59b6"))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
}

// MARK: - Fridge Inventory Card
struct FridgeInventoryCard: View {
    let ingredientCount: Int
    let onTap: () -> Void
    
    @State private var sparkleAnimation = false
    @State private var bounceAnimation = false
    
    var body: some View {
        GlassmorphicCard(content: {
            VStack(spacing: 20) {
                // Title at top
                Text("Here's what's in your fridge")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Icon and content
                HStack(spacing: 20) {
                    // Fridge icon with animation
                    ZStack {
                        // Background gradient circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#38f9d7"),
                                        Color(hex: "#43e97b")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .scaleEffect(bounceAnimation ? 1.1 : 1)
                        
                        // Fridge icon
                        Image(systemName: "refrigerator.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                        
                        // Sparkles around
                        ForEach(0..<3) { index in
                            Image(systemName: "sparkle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#ffa726"))
                                .offset(x: 40, y: 0)
                                .rotationEffect(.degrees(sparkleAnimation ? 360 : 0))
                                .rotationEffect(.degrees(Double(index) * 120))
                                .scaleEffect(sparkleAnimation ? 1.2 : 0.8)
                                .opacity(sparkleAnimation ? 1 : 0.6)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(ingredientCount) ingredients detected")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 14))
                            Text("See what we found")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "#38f9d7"))
                    }
                    
                    Spacer()
                    
                    // Arrow indicator
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color(hex: "#ffd700"))
                        .scaleEffect(bounceAnimation ? 1.2 : 1)
                }
                
                // Fun message
                Text("🎉 We analyzed your fridge like magic!")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }, glowColor: Color(hex: "#38f9d7"))
        .onTapGesture {
            onTap()
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                sparkleAnimation = true
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
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