import SwiftUI

struct RecipeResultsView: View {
    let recipes: [Recipe]
    @Environment(\.dismiss) var dismiss
    @State private var selectedRecipeIndex = 0
    @State private var showingShareSheet = false
    @State private var showingPrintView = false
    
    var body: some View {
        ZStack {
            GradientBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                        .font(.system(size: 17))
                    }
                    
                    Spacer()
                    
                    Text("Your Recipes")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible spacer for balance
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                // Recipe cards
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                            RecipeDetailCard(
                                recipe: recipe,
                                isExpanded: selectedRecipeIndex == index,
                                onTap: {
                                    withAnimation(.spring()) {
                                        selectedRecipeIndex = index
                                    }
                                },
                                onShare: {
                                    selectedRecipeIndex = index
                                    showingShareSheet = true
                                },
                                onPrint: {
                                    selectedRecipeIndex = index
                                    showingPrintView = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if recipes.indices.contains(selectedRecipeIndex) {
                ShareSheet(recipe: recipes[selectedRecipeIndex])
            }
        }
        .sheet(isPresented: $showingPrintView) {
            if recipes.indices.contains(selectedRecipeIndex) {
                PrintView(recipe: recipes[selectedRecipeIndex])
            }
        }
    }
}

struct RecipeDetailCard: View {
    let recipe: Recipe
    let isExpanded: Bool
    let onTap: () -> Void
    let onShare: () -> Void
    let onPrint: () -> Void
    
    @State private var showIngredients = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(recipe.description)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Difficulty badge
                DifficultyBadge(difficulty: recipe.difficulty)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            
            // Quick info
            HStack(spacing: 20) {
                InfoPill(icon: "clock", text: "\(recipe.prepTime + recipe.cookTime) min")
                InfoPill(icon: "person.2", text: "\(recipe.servings) servings")
                InfoPill(icon: "flame", text: "\(recipe.nutrition.calories) cal")
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // Ingredients section
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: { withAnimation { showIngredients.toggle() } }) {
                            HStack {
                                Text("Ingredients")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: showIngredients ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        if showIngredients {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(recipe.ingredients) { ingredient in
                                        IngredientRow(ingredient: ingredient)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Instructions")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Color.white.opacity(0.2)))
                                    
                                    Text(instruction)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    
                    // Nutrition
                    NutritionGrid(nutrition: recipe.nutrition)
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        ShareButton(onTap: onShare)
                        
                        Button(action: onPrint) {
                            HStack {
                                Image(systemName: "printer")
                                Text("Print")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct DifficultyBadge: View {
    let difficulty: Recipe.Difficulty
    
    var body: some View {
        HStack(spacing: 4) {
            Text(difficulty.emoji)
                .font(.system(size: 20))
            
            Text(difficulty.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: difficulty.color))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: difficulty.color).opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(Color(hex: difficulty.color).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct InfoPill: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.8))
    }
}

struct IngredientRow: View {
    let ingredient: Ingredient
    
    var body: some View {
        HStack {
            Image(systemName: ingredient.isAvailable ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(ingredient.isAvailable ? .green : .white.opacity(0.5))
            
            Text(ingredient.name)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Text("\(ingredient.quantity) \(ingredient.unit ?? "")")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct NutritionGrid: View {
    let nutrition: Nutrition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition per serving")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NutritionItem(label: "Calories", value: "\(nutrition.calories)")
                NutritionItem(label: "Protein", value: "\(nutrition.protein)g")
                NutritionItem(label: "Carbs", value: "\(nutrition.carbs)g")
                NutritionItem(label: "Fat", value: "\(nutrition.fat)g")
                if let fiber = nutrition.fiber {
                    NutritionItem(label: "Fiber", value: "\(fiber)g")
                }
                if let sodium = nutrition.sodium {
                    NutritionItem(label: "Sodium", value: "\(sodium)mg")
                }
            }
        }
    }
}

struct NutritionItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct ShareButton: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share for credits!")
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(12)
            )
        }
    }
}

#Preview {
    RecipeResultsView(recipes: [
        Recipe(
            id: UUID(),
            name: "Chicken Stir Fry",
            description: "A quick and healthy Asian-inspired dish",
            ingredients: [
                Ingredient(id: UUID(), name: "Chicken breast", quantity: "500", unit: "g", isAvailable: true),
                Ingredient(id: UUID(), name: "Bell peppers", quantity: "2", unit: nil, isAvailable: true),
                Ingredient(id: UUID(), name: "Soy sauce", quantity: "3", unit: "tbsp", isAvailable: false)
            ],
            instructions: [
                "Cut chicken into bite-sized pieces",
                "Heat oil in a wok over high heat",
                "Stir fry chicken until golden",
                "Add vegetables and cook for 3-4 minutes",
                "Add sauce and toss everything together"
            ],
            cookTime: 15,
            prepTime: 10,
            servings: 4,
            difficulty: .medium,
            nutrition: Nutrition(calories: 320, protein: 28, carbs: 15, fat: 12, fiber: 3, sugar: 5, sodium: 580),
            imageURL: nil,
            createdAt: Date()
        )
    ])
}