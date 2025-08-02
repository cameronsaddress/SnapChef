import SwiftUI

struct RecipesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    @StateObject private var cloudKitAuth = CloudKitAuthManager.shared
    @State private var selectedCategory = "All"
    @State private var searchText = ""
    @State private var contentVisible = false
    @State private var showingFilters = false
    @State private var cloudKitRecipes: [Recipe] = []
    @State private var isLoadingCloudKit = false
    
    // Filter states
    @State private var selectedDifficulty: Recipe.Difficulty?
    @State private var maxCookTime: Double = 120
    @State private var maxCalories: Double = 2000
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
                        
                        // Loading indicator for CloudKit
                        if isLoadingCloudKit {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#667eea")))
                                Text("Loading saved recipes...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .staggeredFade(index: 4, isShowing: contentVisible)
                        }
                        
                        // Recipe Grid
                        RecipeGridView(recipes: filteredRecipes)
                            .padding(.horizontal, 20)
                            .staggeredFade(index: 4, isShowing: contentVisible)
                        
                        // Empty State
                        if filteredRecipes.isEmpty && !isLoadingCloudKit {
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentVisible = true
            }
            // Load CloudKit recipes if authenticated
            if cloudKitAuth.isAuthenticated {
                loadCloudKitRecipes()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Reload CloudKit recipes when app comes to foreground
            if cloudKitAuth.isAuthenticated {
                loadCloudKitRecipes()
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
        if maxCalories < 2000 { count += 1 }
        if !dietaryRestrictions.isEmpty { count += 1 }
        return count
    }
    
    var filteredRecipes: [Recipe] {
        // Combine local and CloudKit recipes
        let allRecipes = appState.recentRecipes + cloudKitRecipes
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
    
    // MARK: - CloudKit Integration
    private func loadCloudKitRecipes() {
        guard !isLoadingCloudKit else { return }
        isLoadingCloudKit = true
        
        print("📱 Starting to load CloudKit recipes...")
        
        Task {
            do {
                // Load user's saved recipes from CloudKit
                print("📱 Loading saved recipes...")
                let savedRecipes = try await cloudKitRecipeManager.getUserSavedRecipes()
                print("📱 Loaded \(savedRecipes.count) saved recipes")
                
                // Also load user's created recipes (recipes generated via LLM)
                print("📱 Loading created recipes...")
                let createdRecipes = try await cloudKitRecipeManager.getUserCreatedRecipes()
                print("📱 Loaded \(createdRecipes.count) created recipes")
                
                // Combine and deduplicate
                var uniqueRecipes: [Recipe] = []
                var seenIds = Set<UUID>()
                
                for recipe in savedRecipes + createdRecipes {
                    if !seenIds.contains(recipe.id) {
                        seenIds.insert(recipe.id)
                        uniqueRecipes.append(recipe)
                    }
                }
                
                print("📱 Total unique recipes after deduplication: \(uniqueRecipes.count)")
                
                await MainActor.run {
                    self.cloudKitRecipes = uniqueRecipes
                    self.isLoadingCloudKit = false
                }
                
                print("✅ Loaded \(uniqueRecipes.count) recipes from CloudKit")
            } catch {
                print("❌ Failed to load CloudKit recipes: \(error)")
                await MainActor.run {
                    self.isLoadingCloudKit = false
                }
            }
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
                    // Image placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
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
                            .frame(width: 120, height: 120)
                        
                        Text(recipe.difficulty.emoji)
                            .font(.system(size: 50))
                    }
                    
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
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("All Recipes")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(recipes) { recipe in
                    RecipeGridCard(recipe: recipe)
                }
            }
        }
    }
}

// MARK: - Recipe Grid Card
struct RecipeGridCard: View {
    let recipe: Recipe
    @State private var isPressed = false
    @State private var showDetail = false
    @State private var showShareGenerator = false
    @State private var showDeleteAlert = false
    @State private var deleteOffset: CGFloat = 0
    @State private var showingUserProfile = false
    @EnvironmentObject var appState: AppState
    @StateObject private var cloudKitAuth = CloudKitAuthManager.shared
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 12) {
                // Image placeholder
                Button(action: {
                    showDetail = true
                }) {
                    ZStack {
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
                            .frame(height: 140)
                        
                        Text(recipe.difficulty.emoji)
                            .font(.system(size: 40))
                        
                        // Difficulty badge and favorite button
                        VStack {
                            HStack {
                                // Favorite button
                                Button(action: {
                                    appState.toggleFavorite(recipe.id)
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }) {
                                    Image(systemName: appState.isFavorited(recipe.id) ? "heart.fill" : "heart")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(appState.isFavorited(recipe.id) ? Color(hex: "#ff6b6b") : .white)
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(Color.black.opacity(0.3))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Spacer()
                                DifficultyBadge(difficulty: recipe.difficulty)
                            }
                            .padding(8)
                            Spacer()
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Author row
                        Button(action: {
                            if let currentUser = cloudKitAuth.currentUser {
                                showingUserProfile = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                                Text(cloudKitAuth.currentUser?.displayName ?? "Me")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .underline()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        HStack {
                            Label("\(recipe.cookTime)m", systemImage: "clock")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Label("\(recipe.nutrition.calories)", systemImage: "flame")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        // Share button
                        HStack {
                            Spacer()
                            Button(action: {
                                showShareGenerator = true
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
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
            }
            .padding(16)
        }
        .scaleEffect(isPressed ? 0.95 : 1)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .contextMenu {
            Button(action: {
                showDetail = true
            }) {
                Label("View Details", systemImage: "eye")
            }
            
            Button(action: {
                showShareGenerator = true
            }) {
                Label("Share Recipe", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                showDeleteAlert = true
            }) {
                Label("Delete Recipe", systemImage: "trash")
            }
        }
        .offset(x: deleteOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width < -50 {
                        withAnimation(.spring()) {
                            deleteOffset = -60
                        }
                    } else if value.translation.width > 50 {
                        withAnimation(.spring()) {
                            deleteOffset = 0
                        }
                    }
                }
                .onEnded { value in
                    if value.translation.width < -100 {
                        showDeleteAlert = true
                    }
                    withAnimation(.spring()) {
                        deleteOffset = 0
                    }
                }
        )
        .sheet(isPresented: $showDetail) {
            RecipeDetailView(recipe: recipe)
        }
        .sheet(isPresented: $showShareGenerator) {
            ShareGeneratorView(recipe: recipe, ingredientsPhoto: nil)
        }
        .alert("Delete Recipe?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation(.spring()) {
                    appState.deleteRecipe(recipe)
                    // Also remove from CloudKit if it's a CloudKit recipe
                    if cloudKitAuth.isAuthenticated {
                        Task {
                            do {
                                // Remove from saved recipes in CloudKit
                                try await cloudKitRecipeManager.removeRecipeFromUserProfile(
                                    recipe.id.uuidString, 
                                    type: .saved
                                )
                                // Also remove from created if it was created by user
                                try await cloudKitRecipeManager.removeRecipeFromUserProfile(
                                    recipe.id.uuidString, 
                                    type: .created
                                )
                                print("✅ Removed recipe from CloudKit")
                            } catch {
                                print("❌ Failed to remove recipe from CloudKit: \(error)")
                            }
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(recipe.name)\"? This action cannot be undone.")
        }
        .sheet(isPresented: $showingUserProfile) {
            if let currentUser = cloudKitAuth.currentUser {
                UserProfileView(
                    userID: currentUser.recordID ?? "current-user",
                    userName: currentUser.displayName ?? "Me"
                )
            }
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
                            
                            Slider(value: $maxCalories, in: 200...2000, step: 100)
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
                        maxCalories = 1000
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