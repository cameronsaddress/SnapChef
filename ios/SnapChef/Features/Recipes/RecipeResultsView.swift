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
    @State private var cloudKitPhotos: [UUID: (before: UIImage?, after: UIImage?)] = [:]
    
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
        NavigationStack {
            ZStack {
                // Animated background
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Success header
                        SuccessHeaderView()
                            .staggeredFade(index: 0, isShowing: contentVisible)
                        
                        // In Your Fridge card
                        if !ingredients.isEmpty {
                            FridgeInventoryCard(
                                ingredientCount: ingredients.count,
                                onTap: {
                                    activeSheet = .fridgeInventory
                                }
                            )
                            .staggeredFade(index: 1, isShowing: contentVisible)
                        }
                        
                        // Recipe cards
                        ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                            MagicalRecipeCard(
                                recipe: recipe,
                                isSaved: savedRecipeIds.contains(recipe.id),
                                onSelect: {
                                    activeSheet = .recipeDetail(recipe)
                                    confettiTrigger = true
                                },
                                onShare: {
                                    // Use branded share popup instead
                                    // Check if we have CloudKit photos cached
                                    if let photos = cloudKitPhotos[recipe.id] {
                                        shareContent = ShareContent(
                                            type: .recipe(recipe),
                                            beforeImage: photos.before ?? capturedImage,
                                            afterImage: photos.after ?? getAfterPhotoForRecipe(recipe)
                                        )
                                        showBrandedShare = true
                                    } else {
                                        // Fetch from CloudKit first
                                        fetchCloudKitPhotosForRecipe(recipe) { beforePhoto, afterPhoto in
                                            cloudKitPhotos[recipe.id] = (beforePhoto, afterPhoto)
                                            shareContent = ShareContent(
                                                type: .recipe(recipe),
                                                beforeImage: beforePhoto ?? capturedImage,
                                                afterImage: afterPhoto ?? getAfterPhotoForRecipe(recipe)
                                            )
                                            showBrandedShare = true
                                        }
                                    }
                                },
                                onSave: {
                                    saveRecipe(recipe)
                                }
                            )
                            .staggeredFade(index: index + (ingredients.isEmpty ? 1 : 2), isShowing: contentVisible)
                        }
                        
                        // Viral share prompt
                        ViralSharePrompt(action: {
                            if let firstRecipe = recipes.first {
                                // Use branded share for viral prompt too
                                // Check if we have CloudKit photos cached
                                if let photos = cloudKitPhotos[firstRecipe.id] {
                                    shareContent = ShareContent(
                                        type: .recipe(firstRecipe),
                                        beforeImage: photos.before ?? capturedImage,
                                        afterImage: photos.after ?? getAfterPhotoForRecipe(firstRecipe)
                                    )
                                    showBrandedShare = true
                                } else {
                                    // Fetch from CloudKit first
                                    fetchCloudKitPhotosForRecipe(firstRecipe) { beforePhoto, afterPhoto in
                                        cloudKitPhotos[firstRecipe.id] = (beforePhoto, afterPhoto)
                                        shareContent = ShareContent(
                                            type: .recipe(firstRecipe),
                                            beforeImage: beforePhoto ?? capturedImage,
                                            afterImage: afterPhoto ?? getAfterPhotoForRecipe(firstRecipe)
                                        )
                                        showBrandedShare = true
                                    }
                                }
                            }
                        })
                        .staggeredFade(index: recipes.count + (ingredients.isEmpty ? 1 : 2), isShowing: contentVisible)
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                
                // Confetti effect
                if confettiTrigger {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { 
                        if savedRecipeIds.isEmpty && !recipes.isEmpty {
                            showingExitConfirmation = true
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.2)))
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Your Recipes")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentVisible = true
            }
            // Pre-fetch CloudKit photos for all recipes
            Task {
                await fetchAllCloudKitPhotos()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .recipeDetail(let recipe):
                RecipeDetailView(recipe: recipe)
            case .shareGenerator(let recipe):
                BrandedSharePopup(
                    content: ShareContent(
                        type: .recipe(recipe),
                        beforeImage: capturedImage,
                        afterImage: getAfterPhotoForRecipe(recipe)
                    )
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
                // TODO: SocialShareView was moved to archive
                ShareSheet(items: [
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
        // Save the recipe with the captured image
        appState.addRecentRecipe(recipe)
        appState.saveRecipeWithPhotos(recipe, beforePhoto: capturedImage, afterPhoto: nil)
        savedRecipeIds.insert(recipe.id)
        
        // Track streak activities
        Task {
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
    
    private func getAfterPhotoForRecipe(_ recipe: Recipe) -> UIImage? {
        // Check if we have a saved recipe with photos
        if let savedRecipe = appState.savedRecipesWithPhotos.first(where: { $0.recipe.id == recipe.id }) {
            return savedRecipe.afterPhoto
        }
        // If not found locally, we could fetch from CloudKit here if needed
        // For now, return nil which will use a placeholder
        return nil
    }
    
    private func fetchCloudKitPhotosForRecipe(_ recipe: Recipe, completion: @escaping (UIImage?, UIImage?) -> Void) {
        Task {
            do {
                let photos = try await CloudKitRecipeManager.shared.fetchRecipePhotos(for: recipe.id.uuidString)
                await MainActor.run {
                    completion(photos.before, photos.after)
                }
            } catch {
                print("Failed to fetch CloudKit photos: \(error)")
                await MainActor.run {
                    completion(nil, nil)
                }
            }
        }
    }
    
    private func fetchAllCloudKitPhotos() async {
        // Fetch photos for all recipes in parallel
        await withTaskGroup(of: (UUID, UIImage?, UIImage?).self) { group in
            for recipe in recipes {
                group.addTask {
                    do {
                        let photos = try await CloudKitRecipeManager.shared.fetchRecipePhotos(for: recipe.id.uuidString)
                        print("📸 Pre-fetched CloudKit photos for recipe '\(recipe.name)': before=\(photos.before != nil), after=\(photos.after != nil)")
                        return (recipe.id, photos.before, photos.after)
                    } catch {
                        print("❌ Failed to fetch CloudKit photos for recipe '\(recipe.name)': \(error)")
                        return (recipe.id, nil, nil)
                    }
                }
            }
            
            // Collect results
            for await (recipeId, beforePhoto, afterPhoto) in group {
                await MainActor.run {
                    cloudKitPhotos[recipeId] = (beforePhoto, afterPhoto)
                }
            }
        }
    }
}

// MARK: - Success Header
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

// MARK: - Magical Recipe Card
struct MagicalRecipeCard: View {
    let recipe: Recipe
    let isSaved: Bool
    let onSelect: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    
    @State private var isHovered = false
    @State private var shimmerPhase: CGFloat = -1
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var isLoadingLike = false
    @StateObject private var cloudKitSync = CloudKitSyncService.shared
    
    var body: some View {
        GlassmorphicCard(content: {
            VStack(alignment: .leading, spacing: 20) {
                // Recipe title at top
                Text(recipe.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Header with image
                HStack(spacing: 20) {
                    // Recipe before/after photos
                    RecipePhotoView(
                        recipe: recipe,
                        width: 100,
                        height: 100,
                        showLabels: true
                    )
                    
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
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect()
                }
                
                // Description
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
                        title: isSaved ? "Saved" : "Save",
                        icon: isSaved ? "checkmark.circle.fill" : "bookmark.fill",
                        color: isSaved ? Color(hex: "#43e97b") : Color(hex: "#667eea"),
                        action: onSave
                    )
                    .disabled(isSaved)
                    
                    ActionButton(
                        title: "Cook",
                        icon: "flame.fill",
                        color: Color(hex: "#f093fb"),
                        action: onSelect
                    )
                    
                    ActionButton(
                        title: "Share",
                        icon: "square.and.arrow.up",
                        color: Color(hex: "#4facfe"),
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
        
        Task {
            isLoadingLike = true
            defer { isLoadingLike = false }
            
            do {
                if isLiked {
                    try await cloudKitSync.unlikeRecipe(recipe.id.uuidString)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked = false
                        likeCount = max(0, likeCount - 1)
                    }
                } else {
                    // For demo purposes, use current user ID as owner ID
                    let ownerID = CloudKitAuthManager.shared.currentUser?.recordID ?? "anonymous"
                    try await cloudKitSync.likeRecipe(recipe.id.uuidString, recipeOwnerID: ownerID)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked = true
                        likeCount += 1
                    }
                }
            } catch {
                print("Failed to toggle like: \(error)")
            }
        }
    }
    
    private func loadLikeStatus() async {
        do {
            isLiked = try await cloudKitSync.isRecipeLiked(recipe.id.uuidString)
            likeCount = try await cloudKitSync.getRecipeLikeCount(recipe.id.uuidString)
        } catch {
            print("Failed to load like status: \(error)")
        }
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
        .foregroundColor(Color(hex: "#4facfe"))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "#4facfe").opacity(0.2))
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
        .foregroundColor(Color(hex: "#f093fb"))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "#f093fb").opacity(0.2))
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
            }, glowColor: Color(hex: "#f093fb"))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
}

// MARK: - Share Floating Button
struct ShareFloatingButton: View {
    let action: () -> Void
    @State private var bounceAnimation = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Ripple effect
                Circle()
                    .stroke(Color(hex: "#f093fb").opacity(0.3), lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .scaleEffect(bounceAnimation ? 1.3 : 1)
                    .opacity(bounceAnimation ? 0 : 1)
                
                // Button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#f093fb"),
                                Color(hex: "#f5576c")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color(hex: "#f093fb").opacity(0.5), radius: 15, y: 5)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                Task { @MainActor in
                    withAnimation(.easeOut(duration: 1)) {
                        bounceAnimation = true
                    }
                    
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    bounceAnimation = false
                }
            }
        }
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        Canvas { context, size in
            for piece in confettiPieces {
                context.fill(
                    RoundedRectangle(cornerRadius: 2)
                        .path(in: CGRect(
                            x: piece.position.x,
                            y: piece.position.y,
                            width: piece.size.width,
                            height: piece.size.height
                        )),
                    with: .color(piece.color)
                )
            }
        }
        .onAppear {
            createConfetti()
        }
    }
    
    private func createConfetti() {
        let colors: [Color] = [
            Color(hex: "#667eea"),
            Color(hex: "#764ba2"),
            Color(hex: "#f093fb"),
            Color(hex: "#4facfe"),
            Color(hex: "#43e97b"),
            Color(hex: "#ffa726")
        ]
        
        confettiPieces = (0..<100).map { _ in
            ConfettiPiece(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: -20
                ),
                velocity: CGVector(
                    dx: CGFloat.random(in: -100...100),
                    dy: CGFloat.random(in: 200...400)
                ),
                size: CGSize(
                    width: CGFloat.random(in: 5...10),
                    height: CGFloat.random(in: 10...20)
                ),
                color: colors.randomElement()!,
                rotation: CGFloat.random(in: 0...360)
            )
        }
        
        var confettiTimer: Timer?
        confettiTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            Task { @MainActor in
                updateConfetti()
                
                if confettiPieces.isEmpty {
                    confettiTimer?.invalidate()
                    confettiTimer = nil
                }
            }
        }
    }
    
    private func updateConfetti() {
        confettiPieces = confettiPieces.compactMap { piece in
            var updated = piece
            updated.position.x += updated.velocity.dx * 0.016
            updated.position.y += updated.velocity.dy * 0.016
            updated.velocity.dy += 500 * 0.016 // Gravity
            updated.rotation += 5
            
            return updated.position.y < UIScreen.main.bounds.height + 50 ? updated : nil
        }
    }
}

struct ConfettiPiece {
    var position: CGPoint
    var velocity: CGVector
    var size: CGSize
    var color: Color
    var rotation: CGFloat
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
                        .foregroundColor(Color(hex: "#38f9d7"))
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                }
            }
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

#Preview {
    RecipeResultsView(recipes: MockDataProvider.shared.mockRecipeResponse().recipes ?? [])
}