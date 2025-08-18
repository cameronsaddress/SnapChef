import SwiftUI

struct RecipeResultsView: View {
    let recipes: [Recipe]
    let ingredients: [IngredientAPI]
    let capturedImage: UIImage?
    @Environment(\.dismiss)
    var dismiss
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

    // Progressive authentication trigger
    @StateObject private var authTrigger = AuthPromptTrigger.shared

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
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(recipes) { recipe in
                            VStack(alignment: .leading) {
                                Text(recipe.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(recipe.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
            
            ToolbarItem(placement: .principal) {
                Text("Your Recipes")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Missing Components Placeholders
struct DifficultyBadge: View {
    let difficulty: Recipe.Difficulty
    
    var body: some View {
        Text(difficulty.rawValue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            .font(.caption)
    }
}

struct ConfettiView: View {
    var body: some View {
        ZStack {
            // Simple confetti placeholder
            ForEach(0..<20, id: \.self) { _ in
                Circle()
                    .fill(Color.random)
                    .frame(width: 8, height: 8)
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

extension Color {
    static var random: Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}

#Preview {
    RecipeResultsView(recipes: [])
}
