import SwiftUI

struct RecipesView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if appState.recentRecipes.isEmpty {
                            EmptyRecipesView()
                                .padding(.top, 100)
                        } else {
                            ForEach(appState.recentRecipes) { recipe in
                                RecipeHistoryCard(recipe: recipe)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
                .navigationTitle("My Recipes")
                .navigationBarTitleDisplayMode(.large)
            }
        }
    }
}

struct EmptyRecipesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.5))
            
            Text("No recipes yet")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Start snapping your fridge to create amazing recipes!")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

struct RecipeHistoryCard: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(recipe.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(recipe.difficulty.emoji)
                        .font(.system(size: 24))
                    
                    Text("\(recipe.nutrition.calories) cal")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            HStack(spacing: 16) {
                Label("\(recipe.prepTime + recipe.cookTime) min", systemImage: "clock")
                Label("\(recipe.servings) servings", systemImage: "person.2")
            }
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.8))
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
}

#Preview {
    RecipesView()
        .environmentObject(AppState())
}