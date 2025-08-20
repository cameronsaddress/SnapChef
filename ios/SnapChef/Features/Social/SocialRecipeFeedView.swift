import SwiftUI
import CloudKit

// MARK: - Social Recipe Feed View
struct SocialRecipeFeedView: View {
    @StateObject private var feedManager = SocialRecipeFeedManager()
    @EnvironmentObject var appState: AppState
    @State private var selectedRecipe: SocialRecipeCard?
    @State private var showingRecipeDetail = false
    @State private var searchText = ""
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var filteredRecipes: [SocialRecipeCard] {
        if searchText.isEmpty {
            return feedManager.recipes
        } else {
            return feedManager.recipes.filter { recipe in
                recipe.title.localizedCaseInsensitiveContains(searchText) ||
                recipe.creatorName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 16)
                    
                    // Recipe Grid
                    if feedManager.showingSkeletonViews {
                        // Skeleton Loading Views
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(0..<6, id: \.self) { _ in
                                    SkeletonRecipeCardView()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    } else if feedManager.isLoading && feedManager.recipes.isEmpty {
                        loadingView
                    } else if feedManager.recipes.isEmpty {
                        emptyStateView
                    } else {
                        recipeGridView
                    }
                }
            }
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await feedManager.refresh()
            }
        }
        .task {
            await feedManager.loadInitialRecipes()
        }
        .sheet(item: $selectedRecipe) { recipe in
            if let recipe = createRecipeFromCard(recipe) {
                RecipeDetailView(recipe: recipe)
                    .environmentObject(appState)
            } else {
                Text("Failed to load recipe")
                    .foregroundColor(.white)
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 16))
                
                TextField("Search recipes or chefs...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .accentColor(.white)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text("Loading recipes from chefs you follow...")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            VStack(spacing: 12) {
                Text("No recipes yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Follow other chefs to see their latest recipes here")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                // Navigate to discover users - handled by parent
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Discover Chefs")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var recipeGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredRecipes) { recipe in
                    RecipeCardView(recipe: recipe) { selectedRecipe in
                        self.selectedRecipe = selectedRecipe
                        showingRecipeDetail = true
                    }
                    .onAppear {
                        // Load more when near the end
                        if recipe.id == filteredRecipes.last?.id {
                            Task {
                                await feedManager.loadMoreRecipes()
                            }
                        }
                    }
                }
                
                if feedManager.hasMore && !feedManager.isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding()
                        .onAppear {
                            Task {
                                await feedManager.loadMoreRecipes()
                            }
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private func createRecipeFromCard(_ card: SocialRecipeCard) -> Recipe? {
        // Create a basic Recipe object from the SocialRecipeCard
        // Note: This is a simplified version - in a real app you might fetch the full recipe data
        return Recipe(
            id: UUID(uuidString: card.id) ?? UUID(),
            name: card.title,
            description: card.description,
            ingredients: [], // Would need to fetch full recipe data
            instructions: [], // Would need to fetch full recipe data
            cookTime: card.cookingTime / 2,
            prepTime: card.cookingTime / 2,
            servings: 4,
            difficulty: Recipe.Difficulty(rawValue: card.difficulty.capitalized) ?? .medium,
            nutrition: Nutrition(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: nil, sugar: nil, sodium: nil),
            imageURL: card.imageURL,
            createdAt: card.createdAt,
            tags: [],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false),
            isDetectiveRecipe: false,
            cookingTechniques: [],
            flavorProfile: nil,
            secretIngredients: [],
            proTips: [],
            visualClues: [],
            shareCaption: ""
        )
    }
}

// MARK: - Recipe Card View
struct RecipeCardView: View {
    let recipe: SocialRecipeCard
    let onTap: (SocialRecipeCard) -> Void
    @State private var isLiked = false
    
    var body: some View {
        Button(action: {
            onTap(recipe)
        }) {
            VStack(spacing: 0) {
                // Recipe Image
                ZStack {
                    if let imageURL = recipe.imageURL, !imageURL.isEmpty {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white.opacity(0.3))
                                )
                        }
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    }
                    
                    // Difficulty Badge
                    VStack {
                        HStack {
                            Spacer()
                            DifficultyBadge(difficulty: recipe.difficulty)
                                .padding(.top, 12)
                                .padding(.trailing, 12)
                        }
                        Spacer()
                    }
                    
                    // Like Button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    isLiked.toggle()
                                }
                                Task {
                                    await toggleLike()
                                }
                            }) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(isLiked ? Color(hex: "#ff6b6b") : .white)
                                    .scaleEffect(isLiked ? 1.2 : 1.0)
                            }
                            .padding(.bottom, 12)
                            .padding(.trailing, 12)
                        }
                    }
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Recipe Info
                VStack(alignment: .leading, spacing: 8) {
                    // Creator Info
                    HStack(spacing: 8) {
                        // Creator Avatar
                        if let imageURL = recipe.creatorImageURL {
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        Text(recipe.creatorName.prefix(1).uppercased())
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(recipe.creatorName.prefix(1).uppercased())
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        HStack(spacing: 4) {
                            Text(recipe.creatorName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                            
                            if recipe.creatorIsVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "#667eea"))
                            }
                        }
                        
                        Spacer()
                        
                        Text(formatTimeAgo(recipe.createdAt))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // Recipe Title
                    Text(recipe.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Recipe Stats
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart")
                                .font(.system(size: 10))
                            Text("\(recipe.likeCount)")
                                .font(.system(size: 10, weight: .medium))
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("\(recipe.cookingTime)m")
                                .font(.system(size: 10, weight: .medium))
                        }
                        
                        Spacer()
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            isLiked = recipe.isLiked
        }
    }
    
    private func toggleLike() async {
        do {
            if isLiked {
                try await CloudKitSyncService.shared.likeRecipe(recipe.id, recipeOwnerID: recipe.creatorID)
            } else {
                try await CloudKitSyncService.shared.unlikeRecipe(recipe.id)
            }
        } catch {
            print("Failed to toggle like: \(error)")
            // Revert UI state on error
            await MainActor.run {
                withAnimation {
                    isLiked.toggle()
                }
            }
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Difficulty Badge
struct DifficultyBadge: View {
    let difficulty: String
    
    var difficultyInfo: (color: Color, emoji: String) {
        switch difficulty.lowercased() {
        case "easy":
            return (Color(hex: "#43e97b"), "🧑‍🍳")
        case "hard":
            return (Color(hex: "#ef5350"), "👩‍🍳🔥")
        default: // medium
            return (Color(hex: "#ffa726"), "👨‍🍳")
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(difficultyInfo.emoji)
                .font(.system(size: 10))
            Text(difficulty.capitalized)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(difficultyInfo.color)
        )
    }
}

// MARK: - Social Recipe Feed Manager
@MainActor
final class SocialRecipeFeedManager: ObservableObject {
    @Published var recipes: [SocialRecipeCard] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var error: Error?
    @Published var showingSkeletonViews = false
    
    private let cloudKitSync = CloudKitSyncService.shared
    private let cloudKitAuth = CloudKitAuthManager.shared
    private var lastLoadedDate: Date?
    private let pageSize = 20
    
    // Caching
    private let cacheKey = "social_recipe_feed_cache"
    private let cacheTimestampKey = "social_recipe_feed_cache_timestamp"
    private let cacheExpirationTime: TimeInterval = 10 * 60 // 10 minutes
    
    func loadInitialRecipes() async {
        guard !isLoading else { return }
        
        showingSkeletonViews = true
        
        // Load cached recipes immediately
        await loadCachedRecipes()
        
        // Load fresh recipes in background
        isLoading = true
        recipes = []
        lastLoadedDate = nil
        hasMore = true
        error = nil
        
        await loadRecipes()
        await saveCachedRecipes()
        
        isLoading = false
        showingSkeletonViews = false
    }
    
    func loadMoreRecipes() async {
        guard !isLoading && hasMore else { return }
        
        isLoading = true
        await loadRecipes()
        isLoading = false
    }
    
    func refresh() async {
        await loadInitialRecipes()
    }
    
    private func loadRecipes() async {
        do {
            let newRecipes = try await cloudKitSync.fetchSocialRecipeFeed(
                lastDate: lastLoadedDate,
                limit: pageSize
            )
            
            if newRecipes.isEmpty {
                hasMore = false
            } else {
                recipes.append(contentsOf: newRecipes)
                lastLoadedDate = newRecipes.last?.createdAt
                hasMore = newRecipes.count == pageSize
            }
            
            print("✅ Loaded \(newRecipes.count) social recipes, total: \(recipes.count)")
        } catch {
            print("❌ Failed to load social recipes: \(error)")
            self.error = error
            // Show mock data on error for development
            if recipes.isEmpty {
                recipes = generateMockRecipes()
                hasMore = false
            }
        }
    }
    
    private func generateMockRecipes() -> [SocialRecipeCard] {
        // Create a mock CloudKit record for the creator
        let mockUserRecord = CKRecord(recordType: CloudKitConfig.userRecordType, recordID: CKRecord.ID(recordName: "mock-user-1"))
        mockUserRecord[CKField.User.username] = "chef_gordon"
        mockUserRecord[CKField.User.displayName] = "Gordon Ramsay"
        mockUserRecord[CKField.User.email] = "gordon@example.com"
        mockUserRecord[CKField.User.authProvider] = "apple"
        mockUserRecord[CKField.User.totalPoints] = Int64(5000)
        mockUserRecord[CKField.User.currentStreak] = Int64(30)
        mockUserRecord[CKField.User.longestStreak] = Int64(45)
        mockUserRecord[CKField.User.challengesCompleted] = Int64(20)
        mockUserRecord[CKField.User.recipesShared] = Int64(50)
        mockUserRecord[CKField.User.recipesCreated] = Int64(50)
        mockUserRecord[CKField.User.coinBalance] = Int64(1000)
        mockUserRecord[CKField.User.followerCount] = Int64(1500)
        mockUserRecord[CKField.User.followingCount] = Int64(150)
        mockUserRecord[CKField.User.isVerified] = Int64(1)
        mockUserRecord[CKField.User.isProfilePublic] = Int64(1)
        mockUserRecord[CKField.User.showOnLeaderboard] = Int64(1)
        mockUserRecord[CKField.User.subscriptionTier] = "premium"
        mockUserRecord[CKField.User.createdAt] = Date()
        mockUserRecord[CKField.User.lastLoginAt] = Date()
        mockUserRecord[CKField.User.lastActiveAt] = Date()
        
        let mockCreator = CloudKitUser(from: mockUserRecord)
        
        return [
            SocialRecipeCard(
                id: "mock-recipe-1",
                title: "Perfect Beef Wellington",
                description: "A masterclass in pastry and beef",
                imageURL: nil,
                createdAt: Date().addingTimeInterval(-3600),
                likeCount: 245,
                commentCount: 23,
                viewCount: 1200,
                difficulty: "hard",
                cookingTime: 120,
                isLiked: false,
                creatorID: "mock-user-1",
                creatorName: "Gordon Ramsay",
                creatorImageURL: nil,
                creatorIsVerified: true
            ),
            SocialRecipeCard(
                id: "mock-recipe-2",
                title: "Simple Pasta Carbonara",
                description: "Traditional Italian comfort food",
                imageURL: nil,
                createdAt: Date().addingTimeInterval(-7200),
                likeCount: 89,
                commentCount: 12,
                viewCount: 450,
                difficulty: "easy",
                cookingTime: 20,
                isLiked: true,
                creatorID: "mock-user-1",
                creatorName: "Gordon Ramsay",
                creatorImageURL: nil,
                creatorIsVerified: true
            )
        ]
    }
    
    // MARK: - Caching Methods
    
    private func loadCachedRecipes() async {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date,
              Date().timeIntervalSince(timestamp) < cacheExpirationTime else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cachedRecipes = try decoder.decode([SocialRecipeCard].self, from: data)
            recipes = cachedRecipes
            print("✅ Loaded \(recipes.count) cached social recipes")
        } catch {
            print("❌ Failed to load cached social recipes: \(error)")
        }
    }
    
    private func saveCachedRecipes() async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(recipes)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
        } catch {
            print("❌ Failed to save cached social recipes: \(error)")
        }
    }
}

// MARK: - SocialRecipeCard Codable Extension
extension SocialRecipeCard: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, description, imageURL, createdAt
        case likeCount, commentCount, viewCount, difficulty, cookingTime, isLiked
        case creatorID, creatorName, creatorImageURL, creatorIsVerified
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        commentCount = try container.decode(Int.self, forKey: .commentCount)
        viewCount = try container.decode(Int.self, forKey: .viewCount)
        difficulty = try container.decode(String.self, forKey: .difficulty)
        cookingTime = try container.decode(Int.self, forKey: .cookingTime)
        isLiked = try container.decode(Bool.self, forKey: .isLiked)
        creatorID = try container.decode(String.self, forKey: .creatorID)
        creatorName = try container.decode(String.self, forKey: .creatorName)
        creatorImageURL = try container.decodeIfPresent(String.self, forKey: .creatorImageURL)
        creatorIsVerified = try container.decode(Bool.self, forKey: .creatorIsVerified)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(likeCount, forKey: .likeCount)
        try container.encode(commentCount, forKey: .commentCount)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(cookingTime, forKey: .cookingTime)
        try container.encode(isLiked, forKey: .isLiked)
        try container.encode(creatorID, forKey: .creatorID)
        try container.encode(creatorName, forKey: .creatorName)
        try container.encodeIfPresent(creatorImageURL, forKey: .creatorImageURL)
        try container.encode(creatorIsVerified, forKey: .creatorIsVerified)
    }
}

// MARK: - Skeleton Recipe Card View
struct SkeletonRecipeCardView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Recipe Image Skeleton
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 160)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0.8 : 0.4)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            // Recipe Info Skeleton
            VStack(alignment: .leading, spacing: 8) {
                // Creator Info Skeleton
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 24, height: 24)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 80, height: 12)
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 10)
                        .cornerRadius(5)
                }
                
                // Recipe Title Skeleton
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(7)
                
                // Recipe Stats Skeleton
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 30, height: 10)
                        .cornerRadius(5)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 35, height: 10)
                        .cornerRadius(5)
                    
                    Spacer()
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    SocialRecipeFeedView()
        .environmentObject(AppState())
}