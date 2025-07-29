import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.dismiss) var dismiss
    @State private var showingPrintView = false
    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingPrintView = true }) {
                        Image(systemName: "printer")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPrintView) {
                RecipePrintView(recipe: recipe)
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

// MARK: - Recipe Print View
struct RecipePrintView: View {
    let recipe: Recipe
    @Environment(\.dismiss) var dismiss
    @State private var isPrinting = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .center, spacing: 12) {
                        Text("SnapChef Recipe")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(recipe.name)
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 20) {
                            Label("\(recipe.prepTime + recipe.cookTime) min", systemImage: "clock")
                            Label("\(recipe.servings) servings", systemImage: "person.2")
                            Label(recipe.difficulty.rawValue, systemImage: "star")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                    
                    Divider()
                    
                    // Ingredients
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredients")
                            .font(.system(size: 20, weight: .bold))
                        
                        ForEach(recipe.ingredients) { ingredient in
                            HStack {
                                Text("•")
                                    .font(.system(size: 16))
                                Text("\(ingredient.quantity) \(ingredient.unit ?? "") \(ingredient.name)")
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(.bottom, 10)
                    
                    Divider()
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Instructions")
                            .font(.system(size: 20, weight: .bold))
                        
                        ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1).")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 25, alignment: .trailing)
                                Text(instruction)
                                    .font(.system(size: 16))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(.bottom, 10)
                    
                    Divider()
                    
                    // Nutrition
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nutrition Facts (per serving)")
                            .font(.system(size: 16, weight: .bold))
                        
                        HStack(spacing: 20) {
                            Text("Calories: \(recipe.nutrition.calories)")
                            Text("Protein: \(recipe.nutrition.protein)g")
                            Text("Carbs: \(recipe.nutrition.carbs)g")
                            Text("Fat: \(recipe.nutrition.fat)g")
                        }
                        .font(.system(size: 14))
                    }
                    
                    Spacer(minLength: 40)
                    
                    // Footer
                    Text("Created with SnapChef • \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(30)
                .background(Color.white)
                .cornerRadius(0)
            }
            .background(Color.gray.opacity(0.1))
            .navigationTitle("Print Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: printRecipe) {
                        Label("Print", systemImage: "printer.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .disabled(isPrinting)
                }
            }
        }
    }
    
    private func printRecipe() {
        isPrinting = true
        
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "SnapChef Recipe - \(recipe.name)"
        printInfo.outputType = .general
        
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        
        // Create a text representation of the recipe
        let formatter = UISimpleTextPrintFormatter(text: createPrintableText())
        formatter.perPageContentInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
        
        printController.printFormatter = formatter
        
        printController.present(animated: true) { _, completed, error in
            isPrinting = false
            if completed {
                dismiss()
            } else if let error = error {
                print("Print error: \(error.localizedDescription)")
            }
        }
    }
    
    private func createPrintableText() -> String {
        var text = "SNAPCHEF RECIPE\n\n"
        text += "\(recipe.name.uppercased())\n\n"
        text += "Prep Time: \(recipe.prepTime) min | Cook Time: \(recipe.cookTime) min\n"
        text += "Servings: \(recipe.servings) | Difficulty: \(recipe.difficulty.rawValue)\n\n"
        
        text += "INGREDIENTS\n"
        text += String(repeating: "-", count: 40) + "\n"
        for ingredient in recipe.ingredients {
            text += "• \(ingredient.quantity) \(ingredient.unit ?? "") \(ingredient.name)\n"
        }
        
        text += "\nINSTRUCTIONS\n"
        text += String(repeating: "-", count: 40) + "\n"
        for (index, instruction) in recipe.instructions.enumerated() {
            text += "\(index + 1). \(instruction)\n\n"
        }
        
        text += "\nNUTRITION FACTS (per serving)\n"
        text += String(repeating: "-", count: 40) + "\n"
        text += "Calories: \(recipe.nutrition.calories) | "
        text += "Protein: \(recipe.nutrition.protein)g | "
        text += "Carbs: \(recipe.nutrition.carbs)g | "
        text += "Fat: \(recipe.nutrition.fat)g\n\n"
        
        text += "\nCreated with SnapChef • \(Date().formatted(date: .abbreviated, time: .omitted))"
        
        return text
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