import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    @StateObject private var cloudKitAuth = CloudKitAuthManager.shared
    @State private var cloudKitFavorites: [Recipe] = []
    @State private var isLoadingCloudKit = false
    
    var favoriteRecipes: [Recipe] {
        // Get favorited recipes from local state
        let localFavorites = appState.allRecipes.filter { recipe in
            appState.isFavorited(recipe.id)
        }
        
        // Combine with CloudKit favorites
        var allFavorites = localFavorites + cloudKitFavorites
        
        // Remove duplicates
        var seenIds = Set<UUID>()
        allFavorites = allFavorites.filter { recipe in
            if seenIds.contains(recipe.id) {
                return false
            }
            seenIds.insert(recipe.id)
            return true
        }
        
        return allFavorites
    }
    
    var body: some View {
        ZStack {
            MagicalBackground()
                .ignoresSafeArea()
            
            if favoriteRecipes.isEmpty && !isLoadingCloudKit {
                VStack(spacing: 20) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("No Favorites Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Tap the heart on any recipe to save it here")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        if isLoadingCloudKit {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#667eea")))
                                Text("Loading favorites...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(favoriteRecipes) { recipe in
                                RecipeGridCard(recipe: recipe)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            if cloudKitAuth.isAuthenticated {
                loadCloudKitFavorites()
            }
        }
    }
    
    private func loadCloudKitFavorites() {
        guard !isLoadingCloudKit else { return }
        isLoadingCloudKit = true
        
        Task {
            do {
                let favorites = try await cloudKitRecipeManager.getUserFavoritedRecipes()
                await MainActor.run {
                    self.cloudKitFavorites = favorites
                    self.isLoadingCloudKit = false
                }
                print("✅ Loaded \(favorites.count) favorite recipes from CloudKit")
            } catch {
                print("❌ Failed to load CloudKit favorites: \(error)")
                await MainActor.run {
                    self.isLoadingCloudKit = false
                }
            }
        }
    }
}

#Preview {
    FavoritesView()
        .environmentObject(AppState())
}