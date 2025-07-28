import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Recipe Image Placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
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
                            .frame(height: 250)
                        
                        Text(recipe.difficulty.emoji)
                            .font(.system(size: 80))
                    }
                    
                    // Recipe Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text(recipe.name)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        
                        Text(recipe.description)
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            Label("\(recipe.prepTime + recipe.cookTime)m", systemImage: "clock")
                            Label("\(recipe.servings) servings", systemImage: "person.2")
                            Label(recipe.difficulty.rawValue, systemImage: "star.fill")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                    
                    // Ingredients
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredients")
                            .font(.system(size: 24, weight: .bold))
                        
                        ForEach(recipe.ingredients) { ingredient in
                            HStack {
                                Image(systemName: ingredient.isAvailable ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(ingredient.isAvailable ? .green : .gray)
                                Text("\(ingredient.quantity) \(ingredient.unit ?? "") \(ingredient.name)")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Instructions")
                            .font(.system(size: 24, weight: .bold))
                        
                        ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top) {
                                Text("\(index + 1).")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                Text(instruction)
                                    .font(.system(size: 16))
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // Nutrition
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nutrition Facts")
                            .font(.system(size: 24, weight: .bold))
                        
                        HStack(spacing: 16) {
                            RecipeDetailNutritionItem(label: "Calories", value: "\(recipe.nutrition.calories)")
                            RecipeDetailNutritionItem(label: "Protein", value: "\(recipe.nutrition.protein)g")
                            RecipeDetailNutritionItem(label: "Carbs", value: "\(recipe.nutrition.carbs)g")
                            RecipeDetailNutritionItem(label: "Fat", value: "\(recipe.nutrition.fat)g")
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RecipeDetailNutritionItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    RecipeDetailView(recipe: MockDataProvider.shared.mockRecipeResponse().recipes?.first ?? Recipe(
        id: UUID(),
        name: "Sample Recipe",
        description: "A delicious sample recipe",
        ingredients: [
            Ingredient(id: UUID(), name: "Flour", quantity: "2", unit: "cups", isAvailable: true),
            Ingredient(id: UUID(), name: "Sugar", quantity: "1", unit: "cup", isAvailable: true)
        ],
        instructions: ["Step 1", "Step 2"],
        cookTime: 30,
        prepTime: 15,
        servings: 4,
        difficulty: .easy,
        nutrition: Nutrition(calories: 300, protein: 20, carbs: 40, fat: 10, fiber: 5, sugar: 5, sodium: 500),
        imageURL: nil,
        createdAt: Date()
    ))
}