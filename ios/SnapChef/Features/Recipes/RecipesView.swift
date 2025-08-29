import SwiftUI

struct RecipesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cloudKitRecipeCache = CloudKitRecipeCache.shared
    @StateObject private var cloudKitAuth = UnifiedAuthManager.shared
    @StateObject private var photoStorage = PhotoStorageManager.shared
    @State private var selectedCategory = "All"
    @State private var searchText = ""
    @State private var contentVisible = false
    @State private var showingFilters = false
    @State private var hasInitiallyLoaded = false
    @State private var isBackgroundSyncing = false

    // Filter states
    @State private var selectedDifficulty: Recipe.Difficulty?
    @State private var maxCookTime: Double = 120
    @State private var maxCalories: Double = 2_000
    @State private var dietaryRestrictions: Set<String> = []

    let categories = ["All", "Quick", "Healthy", "Comfort", "Dessert", "Trending"]

    var body: some View {
        ZStack {
            // Full screen animated background
            MagicalBackground()
                .ignoresSafeArea()

            ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        EnhancedRecipesHeader()
                            .padding(.top, 20)
                            .staggeredFade(index: 0, isShowing: contentVisible)

                        // Search Bar
                        MagicalSearchBar(text: $searchText)
                            .padding(.horizontal, 20)
                            .staggeredFade(index: 1, isShowing: contentVisible)

                        // Categories
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(categories, id: \.self) { category in
                                    CategoryPill(
                                        title: category,
                                        isSelected: selectedCategory == category,
                                        action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedCategory = category
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .staggeredFade(index: 2, isShowing: contentVisible)

                        // Featured Recipe
                        if let featuredRecipe = appState.recentRecipes.first {
                            FeaturedRecipeCard(recipe: featuredRecipe)
                                .padding(.horizontal, 20)
                                .staggeredFade(index: 3, isShowing: contentVisible)
                        }

                        // Subtle background sync indicator (non-blocking)
                        if isBackgroundSyncing && hasInitiallyLoaded {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#667eea")))
                                    .scaleEffect(0.7)
                                Text("Syncing new recipes...")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.3), value: isBackgroundSyncing)
                        }

                        // Recipe Grid
                        RecipeGridView(recipes: filteredRecipes)
                            .padding(.horizontal, 20)
                            .staggeredFade(index: 4, isShowing: contentVisible)

                        // Empty State
                        if filteredRecipes.isEmpty && !cloudKitRecipeCache.isLoading {
                            EmptyRecipesView()
                                .padding(.top, 50)
                                .staggeredFade(index: 5, isShowing: contentVisible)
                        }
                    }
                    .padding(.bottom, 100)
            }
                .scrollContentBackground(.hidden)

                // Floating Filter Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton(
                            icon: "slider.horizontal.3",
                            badge: activeFilterCount > 0 ? "\(activeFilterCount)" : nil
                        ) {
                            showingFilters = true
                        }
                        .padding(30)
                    }
                }
        }
        .navigationBarHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            print("🔍 DEBUG: RecipesView appeared")
            
            // Defer UI state changes to avoid modifying state during view update
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.5)) {
                    contentVisible = true
                }
                hasInitiallyLoaded = true
            }

            // Load like data for authenticated users
            if cloudKitAuth.isAuthenticated {
                // Load user's liked recipes and counts for all visible recipes
                Task {
                    await RecipeLikeManager.shared.loadUserLikes()
                    
                    // Get all recipe IDs and load their like counts
                    let allRecipeIDs = filteredRecipes.map { $0.id.uuidString }
                    if !allRecipeIDs.isEmpty {
                        await RecipeLikeManager.shared.refreshLikeCounts(for: allRecipeIDs)
                    }
                }
                
                // OPTIMIZATION: Start background CloudKit sync without blocking UI
                startBackgroundCloudKitSync()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // OPTIMIZATION: Background sync when returning to foreground
            if cloudKitAuth.isAuthenticated && hasInitiallyLoaded {
                startBackgroundCloudKitSync()
            }
        }
        .refreshable {
            // OPTIMIZATION: Pull to refresh is faster - only trigger explicit sync
            if cloudKitAuth.isAuthenticated {
                await performForegroundSync()
            }
        }
        .sheet(isPresented: $showingFilters) {
            RecipeFiltersView(
                selectedDifficulty: $selectedDifficulty,
                maxCookTime: $maxCookTime,
                maxCalories: $maxCalories,
                dietaryRestrictions: $dietaryRestrictions
            )
        }
    }

    var activeFilterCount: Int {
        var count = 0
        if selectedDifficulty != nil { count += 1 }
        if maxCookTime < 120 { count += 1 }
        if maxCalories < 2_000 { count += 1 }
        if !dietaryRestrictions.isEmpty { count += 1 }
        return count
    }

    var filteredRecipes: [Recipe] {
        // OPTIMIZATION: Prioritize local recipes for instant display
        // Show local recipes immediately, then merge CloudKit recipes
        let localRecipes = appState.recentRecipes + appState.savedRecipes
        let cloudKitRecipes = cloudKitRecipeCache.cachedRecipes
        
        // DEBUG: Log recipe counts
        print("🔍 DEBUG: RecipesView filteredRecipes called")
        print("🔍   - recentRecipes count: \(appState.recentRecipes.count)")
        print("🔍   - savedRecipes count: \(appState.savedRecipes.count)")
        print("🔍   - localRecipes total: \(localRecipes.count)")
        print("🔍   - cloudKitRecipes count: \(cloudKitRecipes.count)")

        // Remove duplicates - local recipes take precedence
        let localRecipeIds = Set(localRecipes.map { $0.id })
        let uniqueCloudKitRecipes = cloudKitRecipes.filter { !localRecipeIds.contains($0.id) }

        // Combine with local recipes first for instant display
        var allRecipes = localRecipes + uniqueCloudKitRecipes
        
        // Additional deduplication check using Dictionary to ensure uniqueness
        let uniqueRecipes = Dictionary(grouping: allRecipes, by: { $0.id })
            .compactMap { $0.value.first }
        allRecipes = uniqueRecipes
        
        // Sort by creation date (newest first) for consistent left-to-right, top-to-bottom ordering
        allRecipes.sort { $0.createdAt > $1.createdAt }

        return allRecipes.filter { recipe in
            // Search filter
            let matchesSearch = searchText.isEmpty ||
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.description.localizedCaseInsensitiveContains(searchText) ||
                recipe.ingredients.contains { $0.name.localizedCaseInsensitiveContains(searchText) }

            // Category filter
            let matchesCategory = selectedCategory == "All" || self.matchesCategory(recipe, category: selectedCategory)

            // Difficulty filter
            let matchesDifficulty = selectedDifficulty == nil || recipe.difficulty == selectedDifficulty

            // Cook time filter
            let matchesCookTime = Double(recipe.prepTime + recipe.cookTime) <= maxCookTime

            // Calories filter
            let matchesCalories = Double(recipe.nutrition.calories) <= maxCalories

            // Dietary restrictions filter
            let matchesDietary = dietaryRestrictions.isEmpty || checkDietaryRestrictions(recipe)

            return matchesSearch && matchesCategory && matchesDifficulty &&
                   matchesCookTime && matchesCalories && matchesDietary
        }
    }

    private func checkDietaryRestrictions(_ recipe: Recipe) -> Bool {
        // This is a simplified check - in production, you'd have more detailed ingredient data
        for restriction in dietaryRestrictions {
            switch restriction {
            case "Vegetarian", "Vegan":
                let meatKeywords = ["meat", "chicken", "beef", "pork", "fish", "seafood", "bacon", "ham"]
                if recipe.ingredients.contains(where: { ingredient in
                    meatKeywords.contains { ingredient.name.localizedCaseInsensitiveContains($0) }
                }) {
                    return false
                }
            case "Gluten-Free":
                let glutenKeywords = ["flour", "bread", "pasta", "wheat", "barley", "rye"]
                if recipe.ingredients.contains(where: { ingredient in
                    glutenKeywords.contains { ingredient.name.localizedCaseInsensitiveContains($0) }
                }) {
                    return false
                }
            case "Dairy-Free":
                let dairyKeywords = ["milk", "cheese", "butter", "cream", "yogurt"]
                if recipe.ingredients.contains(where: { ingredient in
                    dairyKeywords.contains { ingredient.name.localizedCaseInsensitiveContains($0) }
                }) {
                    return false
                }
            default:
                break
            }
        }
        return true
    }

    func matchesCategory(_ recipe: Recipe, category: String) -> Bool {
        switch category {
        case "Quick": return (recipe.prepTime + recipe.cookTime) <= 30
        case "Healthy": return recipe.nutrition.calories < 500
        case "Comfort": return recipe.difficulty == .easy
        case "Dessert": return recipe.name.localizedCaseInsensitiveContains("dessert") || recipe.name.localizedCaseInsensitiveContains("sweet")
        case "Trending": return true // Would use actual trending logic
        default: return true
        }
    }

    // MARK: - Optimized CloudKit Integration

    /// Start background CloudKit sync without blocking UI
    private func startBackgroundCloudKitSync() {
        guard !isBackgroundSyncing else { return }

        print("📱 RecipesView: Starting background CloudKit sync...")
        
        Task {
            await MainActor.run {
                isBackgroundSyncing = true
            }
            
            // Get recipes from cache (intelligent caching)
            let recipes = await cloudKitRecipeCache.getRecipes(forceRefresh: false)
            print("✅ RecipesView: Background sync got \(recipes.count) recipes")

            // Fetch photos in background without blocking UI
            await fetchPhotosInBackground(for: recipes)

            // Trigger manual sync for latest data
            await CloudKitDataManager.shared.triggerManualSync()

            await MainActor.run {
                isBackgroundSyncing = false
            }
        }
    }

    /// Perform foreground sync for pull-to-refresh
    private func performForegroundSync() async {
        print("📱 RecipesView: Performing foreground sync...")
        
        await MainActor.run {
            isBackgroundSyncing = true
        }

        // Force refresh for pull-to-refresh
        let recipes = await cloudKitRecipeCache.getRecipes(forceRefresh: true)
        print("✅ RecipesView: Foreground sync got \(recipes.count) recipes")

        // Fetch photos with higher priority
        await fetchPhotosInBackground(for: recipes)

        // Trigger manual sync
        await CloudKitDataManager.shared.triggerManualSync()

        await MainActor.run {
            isBackgroundSyncing = false
        }
    }

    /// Fetch photos in background without blocking main UI thread
    private func fetchPhotosInBackground(for recipes: [Recipe]) async {
        guard !recipes.isEmpty else { return }

        print("📸 RecipesView: Fetching photos for \(recipes.count) recipes in background...")

        // Filter recipes that need photos and aren't already in PhotoStorageManager
        let recipesNeedingPhotos = recipes.filter { recipe in
            // Check PhotoStorageManager first (single source of truth)
            if let photos = photoStorage.getPhotos(for: recipe.id) {
                return photos.fridgePhoto == nil || photos.mealPhoto == nil
            }
            // Fallback check for recipes not in PhotoStorageManager
            return !appState.savedRecipesWithPhotos.contains(where: { $0.recipe.id == recipe.id })
        }

        if !recipesNeedingPhotos.isEmpty {
            print("📸 RecipesView: \(recipesNeedingPhotos.count) recipes need photos")
            await CloudKitRecipeManager.shared.fetchPhotosForRecipes(recipesNeedingPhotos, appState: appState)
        } else {
            print("✅ RecipesView: All recipes already have photos cached locally")
        }
    }
}

// MARK: - Enhanced Recipes Header
struct EnhancedRecipesHeader: View {
    @State private var sparkleAnimation = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipe Collection")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text("Your culinary masterpieces")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Animated icon
                ZStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(Color(hex: "#f093fb"))
                        .rotationEffect(.degrees(sparkleAnimation ? 360 : 0))
                        .scaleEffect(sparkleAnimation ? 1.2 : 1)
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: false)) {
                sparkleAnimation = true
            }
        }
    }
}

// MARK: - Magical Search Bar
struct MagicalSearchBar: View {
    @Binding var text: String
    @State private var isEditing = false

    var body: some View {
        GlassmorphicCard {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#667eea"))

                TextField("Search recipes...", text: $text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .onTapGesture {
                        isEditing = true
                    }

                if isEditing && !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scaleEffect(isEditing ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditing)
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var categoryEmoji: String {
        switch title {
        case "Quick": return "⚡"
        case "Healthy": return "🥗"
        case "Comfort": return "🍲"
        case "Dessert": return "🍰"
        case "Trending": return "🔥"
        default: return "✨"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(categoryEmoji)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.8))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected
                                    ? Color.clear
                                    : Color.white.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1)
        }
    }
}

// MARK: - Featured Recipe Card
struct FeaturedRecipeCard: View {
    let recipe: Recipe
    @State private var isAnimating = false
    @State private var showDetail = false

    var body: some View {
        GlassmorphicCard(content: {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Featured Recipe")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#f093fb"))

                        Text("Today's Star")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    // Animated star
                    Image(systemName: "star.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color(hex: "#ffa726"))
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                }

                // Recipe content
                HStack(spacing: 20) {
                    // Recipe before/after photos
                    RecipePhotoView(
                        recipe: recipe,
                        width: 120,
                        height: 120,
                        showLabels: true
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text(recipe.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Text(recipe.description)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)

                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(recipe.prepTime + recipe.cookTime)m")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "#4facfe"))

                            HStack(spacing: 6) {
                                Image(systemName: "flame")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(recipe.nutrition.calories)")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "#f093fb"))
                        }
                    }

                    Spacer()
                }

                // Action button
                MagneticButton(
                    title: "Cook This Now",
                    icon: "arrow.right",
                    action: {
                        showDetail = true
                    }
                )
            }
            .padding(24)
        }, glowColor: Color(hex: "#f093fb"))
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
        .sheet(isPresented: $showDetail) {
            RecipeDetailView(recipe: recipe)
        }
    }
}

// MARK: - Recipe Grid View
struct RecipeGridView: View {
    let recipes: [Recipe]
    let columns = [
        GridItem(.fixed(UIScreen.main.bounds.width / 2 - 28), spacing: 16),
        GridItem(.fixed(UIScreen.main.bounds.width / 2 - 28), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("All Recipes")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    RecipeGridCard(recipe: recipe)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.05), // Stagger by 50ms per card
                            value: recipes.count
                        )
                }
            }
        }
    }
}

// MARK: - Recipe Grid Card
struct RecipeGridCard: View {
    let recipe: Recipe
    @State private var showDetail = false
    @State private var showSharePopup = false
    @State private var showingUserProfile = false
    @State private var creatorUsername: String = "Anonymous"
    @State private var isLoadingUsername = false
    @State private var isLikeAnimating = false
    @EnvironmentObject var appState: AppState
    @StateObject private var cloudKitAuth = UnifiedAuthManager.shared
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    @StateObject private var cloudKitUserManager = CloudKitUserManager.shared
    @StateObject private var cloudKitRecipeCache = CloudKitRecipeCache.shared
    @StateObject private var likeManager = RecipeLikeManager.shared
    
    // Computed properties for like state from manager
    private var isLiked: Bool {
        likeManager.isRecipeLiked(recipe.id.uuidString)
    }
    
    private var likeCount: Int {
        likeManager.getLikeCount(for: recipe.id.uuidString)
    }

    var body: some View {
        // Base card with tap gesture for viewing details
        ZStack {
            GlassmorphicCard {
                VStack(alignment: .leading, spacing: 0) {
                    // Recipe before/after photos
                    ZStack {
                        RecipePhotoView(
                            recipe: recipe,
                            width: UIScreen.main.bounds.width / 2 - 44, // Account for padding
                            height: 120,
                            showLabels: true
                        )
                        .frame(height: 120) // Ensure consistent height
                        .clipped()
                        .allowsHitTesting(false) // Allow scroll to pass through


                        // Like button overlay with animation
                        VStack {
                            HStack {
                                // Like button - saves to CloudKit
                                Button(action: {
                                    toggleLike()
                                }) {
                                    ZStack {
                                        Image(systemName: isLiked ? "heart.fill" : "heart")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(isLiked ? .pink : .white)
                                            .padding(8)
                                            .background(
                                                Circle()
                                                    .fill(isLiked ? Color.pink.opacity(0.15) : Color.black.opacity(0.3))
                                            )
                                            .scaleEffect(isLikeAnimating ? 1.3 : 1.0)
                                        
                                        // Like count badge - always show to see immediate updates
                                        Text("\(likeCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(isLiked ? Color.pink : Color.gray)
                                            )
                                            .offset(x: 18, y: -15)
                                            .opacity(likeCount > 0 ? 1 : 0.6)
                                    }
                                }

                            Spacer()
                        }
                        .padding(8)
                        Spacer()
                    }
                    .padding(.top, 8)
                }

                // Content
                VStack(alignment: .leading, spacing: 6) {
                        Text(recipe.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(minHeight: 40, alignment: .topLeading)
                            .allowsHitTesting(false) // Allow scroll to pass through

                        // Author row with dynamic username fetching
                        Button(action: {
                            if cloudKitAuth.isAuthenticated {
                                showingUserProfile = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                if isLoadingUsername {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                                        .scaleEffect(0.5)
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Text(creatorUsername)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle()) // Use BorderlessButtonStyle to not block scroll

                        HStack {
                            Label("\(recipe.cookTime)m", systemImage: "clock")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .allowsHitTesting(false) // Allow scroll to pass through

                            Spacer()

                            Label("\(recipe.nutrition.calories)", systemImage: "flame")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .allowsHitTesting(false) // Allow scroll to pass through
                        }

                        // Difficulty badge and Share button
                        HStack {
                            Spacer()
                            
                            // Difficulty badge
                            DifficultyBadge(difficulty: recipe.difficulty)
                                .allowsHitTesting(false)
                            
                            // Share button
                            Button(action: {
                                showSharePopup = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Share")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(Color(hex: "#4facfe"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#4facfe").opacity(0.2))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(hex: "#4facfe").opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(BorderlessButtonStyle()) // Use BorderlessButtonStyle to not block scroll
                        }
                }
            }
            .padding(12)
        }
        
        // Detective recipe gold magnifying glass icon
        if recipe.isFromDetective {
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "#FFD700"))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        .rotationEffect(.degrees(15)) // Tilted at an angle
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                }
                Spacer()
            }
            .allowsHitTesting(false) // Let touches pass through
        }
        }
        .frame(height: 280) // Ensure consistent card height
        .clipped() // Prevent content overflow
        .contentShape(Rectangle()) // Define hit testing area for the entire card
        .onTapGesture {
            // This tap gesture will only fire if no button was tapped
            showDetail = true
        }
        .sheet(isPresented: $showDetail) {
            RecipeDetailView(recipe: recipe)
        }
        .sheet(isPresented: $showSharePopup) {
            BrandedSharePopup(
                content: ShareContent(
                    type: .recipe(recipe),
                    beforeImage: getBeforePhotoForRecipe(),
                    afterImage: getAfterPhotoForRecipe()
                )
            )
        }
        .sheet(isPresented: $showingUserProfile) {
            if let currentUser = cloudKitAuth.currentUser {
                UserProfileView(
                    userID: currentUser.recordID ?? "current-user",
                    userName: currentUser.displayName
                )
            }
        }
        .task {
            await fetchCreatorUsername()
        }
    }
    
    private func toggleLike() {
        // Haptic feedback immediately
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Animate button
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            isLikeAnimating = true
        }
        
        // Animate button scale back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isLikeAnimating = false
            }
        }
        
        // Update via manager (handles auth check and optimistic updates)
        Task {
            await likeManager.toggleLike(for: recipe.id.uuidString)
        }
    }

    private func deleteRecipe() {
        withAnimation(.easeOut(duration: 0.3)) {
            appState.deleteRecipe(recipe)
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func getBeforePhotoForRecipe() -> UIImage? {
        // OPTIMIZATION: Use PhotoStorageManager as primary source for instant retrieval
        if let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id),
           let photo = photos.fridgePhoto {
            return photo
        }

        // Fallback to appState for backwards compatibility with controlled migration
        if let savedRecipe = appState.savedRecipesWithPhotos.first(where: { $0.recipe.id == recipe.id }),
           let photo = savedRecipe.beforePhoto {
            // Use the shared migration coordinator to prevent duplicates
            if PhotoMigrationCoordinator.shared.startMigration(for: recipe.id) {
                Task(priority: .background) {
                    PhotoStorageManager.shared.storePhotos(
                        fridgePhoto: photo,
                        mealPhoto: savedRecipe.afterPhoto,
                        for: recipe.id
                    )
                    await MainActor.run {
                        PhotoMigrationCoordinator.shared.completeMigration(for: recipe.id)
                        print("📸 RecipeCard: Successfully migrated legacy photos to PhotoStorageManager for \(recipe.name)")
                    }
                }
            }
            return photo
        }

        return nil
    }

    private func getAfterPhotoForRecipe() -> UIImage? {
        // OPTIMIZATION: Use PhotoStorageManager as primary source for instant retrieval
        if let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id),
           let photo = photos.mealPhoto {
            return photo
        }

        // Fallback to appState for backwards compatibility (migration handled in getBeforePhotoForRecipe)
        if let savedRecipe = appState.savedRecipesWithPhotos.first(where: { $0.recipe.id == recipe.id }),
           let photo = savedRecipe.afterPhoto {
            return photo
        }

        return nil
    }
    
    /// Fetch the actual creator username from CloudKit or use current user info
    private func fetchCreatorUsername() async {
        // Skip if already loaded
        guard creatorUsername == "Anonymous" && !isLoadingUsername else {
            return
        }
        
        await MainActor.run {
            isLoadingUsername = true
        }
        
        let ownerName = await getOwnerName(for: recipe)
        
        await MainActor.run {
            creatorUsername = ownerName
            isLoadingUsername = false
        }
        
        print("✅ RecipeCard: Set creator username to '\(ownerName)' for recipe '\(recipe.name)'")
    }
    
    /// Get the owner name for a recipe
    private func getOwnerName(for recipe: Recipe) async -> String {
        // Try to get owner name from the cache first
        let cachedOwnerName = cloudKitRecipeCache.getRecipeOwnerName(for: recipe)
        if cachedOwnerName != "Me" && cachedOwnerName != "Anonymous Chef" {
            return cachedOwnerName
        }
        
        // If no cached owner info, check if it's current user's recipe
        if let currentUser = cloudKitAuth.currentUser, cloudKitAuth.isAuthenticated {
            return currentUser.username ?? currentUser.displayName
        }
        
        return "Me"
    }
    
}

// MARK: - Empty Recipes View
struct EmptyRecipesView: View {
    @State private var bounceAnimation = false

    var body: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#667eea").opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(bounceAnimation ? 1.2 : 1)

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(Color(hex: "#667eea"))
                    .scaleEffect(bounceAnimation ? 1.1 : 1)
            }

            Text("No recipes yet!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Snap your fridge to create your first masterpiece")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            MagneticButton(
                title: "Start Cooking",
                icon: "camera.fill",
                action: {}
            )
            .padding(.top, 10)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                bounceAnimation = true
            }
        }
    }
}

// MARK: - Recipe Filters View
struct RecipeFiltersView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDifficulty: Recipe.Difficulty?
    @Binding var maxCookTime: Double
    @Binding var maxCalories: Double
    @Binding var dietaryRestrictions: Set<String>

    let restrictions = ["Vegetarian", "Vegan", "Gluten-Free", "Dairy-Free", "Keto", "Paleo"]

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 30) {
                        // Difficulty
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Difficulty")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                ForEach(Recipe.Difficulty.allCases, id: \.self) { difficulty in
                                    DifficultyFilterPill(
                                        difficulty: difficulty,
                                        isSelected: selectedDifficulty == difficulty,
                                        action: {
                                            selectedDifficulty = selectedDifficulty == difficulty ? nil : difficulty
                                        }
                                    )
                                }
                            }
                        }

                        // Cook Time
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Max Cook Time")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                Spacer()

                                Text("\(Int(maxCookTime)) min")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hex: "#4facfe"))
                            }

                            Slider(value: $maxCookTime, in: 15...120, step: 15)
                                .accentColor(Color(hex: "#4facfe"))
                        }

                        // Calories
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Max Calories")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                Spacer()

                                Text("\(Int(maxCalories))")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hex: "#f093fb"))
                            }

                            Slider(value: $maxCalories, in: 200...2_000, step: 100)
                                .accentColor(Color(hex: "#f093fb"))
                        }

                        // Dietary Restrictions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Dietary Restrictions")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(restrictions, id: \.self) { restriction in
                                    RestrictionPill(
                                        title: restriction,
                                        isSelected: dietaryRestrictions.contains(restriction),
                                        action: {
                                            if dietaryRestrictions.contains(restriction) {
                                                dietaryRestrictions.remove(restriction)
                                            } else {
                                                dietaryRestrictions.insert(restriction)
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        // Apply button
                        MagneticButton(
                            title: "Apply Filters",
                            icon: "checkmark",
                            action: {
                                dismiss()
                            }
                        )
                        .padding(.top, 20)
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Filter Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        selectedDifficulty = nil
                        maxCookTime = 60
                        maxCalories = 1_000
                        dietaryRestrictions = []
                    }
                    .foregroundColor(Color(hex: "#667eea"))
                }
            }
        }
    }
}

// MARK: - Difficulty Filter Pill
struct DifficultyFilterPill: View {
    let difficulty: Recipe.Difficulty
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(difficulty.emoji)
                    .font(.system(size: 16))
                Text(difficulty.rawValue.capitalized)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.8))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? difficulty.swiftUIColor
                            : Color.white.opacity(0.2)
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected
                                    ? Color.clear
                                    : Color.white.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Restriction Pill
struct RestrictionPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isSelected
                                ? Color(hex: "#43e97b")
                                : Color.white.opacity(0.2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSelected
                                        ? Color.clear
                                        : Color.white.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        MagicalBackground()
            .ignoresSafeArea()

        RecipesView()
            .environmentObject(AppState())
    }
}
