import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authManager = UnifiedAuthManager.shared
    @StateObject private var likeManager = RecipeLikeManager.shared
    @StateObject private var cloudKit = CloudKitService.shared
    @State private var cloudLikedRecipes: [Recipe] = []
    @State private var isLoading = false

    var favoriteRecipes: [Recipe] {
        // Heart likes are backed by RecipeLikeManager (CloudKit RecipeLike records),
        // not the legacy AppState "favorited" set.
        let localPool = appState.allRecipes + appState.recentRecipes + appState.savedRecipes
        let localLiked = localPool.filter { likeManager.likedRecipeIDs.contains($0.id.uuidString) }

        var combined = localLiked + cloudLikedRecipes

        var seen = Set<UUID>()
        combined = combined.filter { recipe in
            seen.insert(recipe.id).inserted
        }

        combined.sort { $0.createdAt > $1.createdAt }
        return combined
    }

    var body: some View {
        ZStack {
            MagicalBackground()
                .ignoresSafeArea()

            if !authManager.isAuthenticated {
                VStack(spacing: 18) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 56))
                        .foregroundColor(.white.opacity(0.6))

                    Text("Sign In to See Likes")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Likes sync with iCloud + CloudKit so they show up on every device.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)

                    Button {
                        authManager.promptAuthForFeature(.socialSharing)
                    } label: {
                        Text("Sign In")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 30)
            } else if favoriteRecipes.isEmpty && !isLoading {
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
                        if isLoading {
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
        .task {
            guard authManager.isAuthenticated else { return }
            await refreshLikedRecipes()
            if CloudKitRuntimeSupport.hasCloudKitEntitlement {
                await CloudKitDataManager.shared.triggerManualSync()
            }
        }
    }

    private func refreshLikedRecipes() async {
        guard !isLoading else { return }
        isLoading = true

        defer { isLoading = false }

        // Ensure we have the latest liked recipe IDs.
        await likeManager.loadUserLikes()

        let likedIDs = Array(likeManager.likedRecipeIDs)
        guard !likedIDs.isEmpty else {
            cloudLikedRecipes = []
            return
        }

        let localPool = appState.allRecipes + appState.recentRecipes + appState.savedRecipes
        let localIDs = Set(localPool.map { $0.id.uuidString })
        let alreadyFetched = Set(cloudLikedRecipes.map { $0.id.uuidString })
        let missingIDs = likedIDs.filter { !localIDs.contains($0) && !alreadyFetched.contains($0) }

        guard !missingIDs.isEmpty else { return }

        do {
            let fetched = try await cloudKit.fetchRecipes(by: missingIDs)
            var merged = cloudLikedRecipes + fetched
            var seen = Set<UUID>()
            merged = merged.filter { seen.insert($0.id).inserted }
            cloudLikedRecipes = merged
        } catch {
            // CloudKit might be unavailable in the current runtime (simulator/local-only). Keep local-only favorites.
            print("⚠️ FavoritesView: Failed to fetch liked recipes from CloudKit: \(error)")
        }
    }
}

#Preview {
    FavoritesView()
        .environmentObject(AppState())
}
