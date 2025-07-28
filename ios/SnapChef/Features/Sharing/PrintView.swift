import SwiftUI
import UIKit

struct PrintView: View {
    let recipe: Recipe
    @Environment(\.dismiss) var dismiss
    @State private var isPrinting = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Recipe header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(recipe.name)
                            .font(.system(size: 28, weight: .bold))
                        
                        Text(recipe.description)
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            Label("\(recipe.prepTime + recipe.cookTime) min", systemImage: "clock")
                            Label("\(recipe.servings) servings", systemImage: "person.2")
                            Label(recipe.difficulty.rawValue, systemImage: "chart.bar")
                        }
                        .font(.system(size: 16))
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Ingredients
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ingredients")
                            .font(.system(size: 22, weight: .semibold))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(recipe.ingredients) { ingredient in
                                HStack {
                                    Text("•")
                                    Text(ingredient.name)
                                    Spacer()
                                    Text("\(ingredient.quantity) \(ingredient.unit ?? "")")
                                        .foregroundColor(.secondary)
                                }
                                .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Instructions")
                            .font(.system(size: 22, weight: .semibold))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1).")
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(width: 30, alignment: .leading)
                                    
                                    Text(instruction)
                                        .font(.system(size: 16))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Nutrition
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Nutrition (per serving)")
                            .font(.system(size: 22, weight: .semibold))
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            NutritionRow(label: "Calories", value: "\(recipe.nutrition.calories)")
                            NutritionRow(label: "Protein", value: "\(recipe.nutrition.protein)g")
                            NutritionRow(label: "Carbs", value: "\(recipe.nutrition.carbs)g")
                            NutritionRow(label: "Fat", value: "\(recipe.nutrition.fat)g")
                            if let fiber = recipe.nutrition.fiber {
                                NutritionRow(label: "Fiber", value: "\(fiber)g")
                            }
                            if let sodium = recipe.nutrition.sodium {
                                NutritionRow(label: "Sodium", value: "\(sodium)mg")
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Footer
                    VStack(spacing: 8) {
                        Divider()
                        Text("Created with SnapChef")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(Date().formatted(date: .long, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Print Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: printRecipe) {
                        if isPrinting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "printer")
                        }
                    }
                    .disabled(isPrinting)
                }
            }
        }
    }
    
    private func printRecipe() {
        isPrinting = true
        
        let printController = UIPrintInteractionController.shared
        
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "SnapChef Recipe - \(recipe.name)"
        printInfo.outputType = .general
        
        printController.printInfo = printInfo
        
        // Create formatted text
        let formatter = UIMarkupTextPrintFormatter(markupText: createHTMLContent())
        formatter.perPageContentInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
        
        printController.printFormatter = formatter
        
        printController.present(animated: true) { _, completed, error in
            isPrinting = false
            if completed {
                HapticManager.notification(.success)
                dismiss()
            } else if let error = error {
                print("Print error: \(error)")
                HapticManager.notification(.error)
            }
        }
    }
    
    private func createHTMLContent() -> String {
        var html = """
        <html>
        <head>
            <style>
                body { font-family: -apple-system, sans-serif; line-height: 1.6; color: #333; }
                h1 { color: #000; margin-bottom: 8px; }
                h2 { color: #333; margin-top: 24px; margin-bottom: 12px; }
                .info { color: #666; margin-bottom: 20px; }
                .ingredient { margin-bottom: 8px; }
                .instruction { margin-bottom: 12px; }
                .nutrition { display: inline-block; width: 48%; margin-bottom: 8px; }
                .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #999; font-size: 12px; text-align: center; }
            </style>
        </head>
        <body>
            <h1>\(recipe.name)</h1>
            <p>\(recipe.description)</p>
            <div class="info">
                ⏱ \(recipe.prepTime + recipe.cookTime) min &nbsp;&nbsp;
                👥 \(recipe.servings) servings &nbsp;&nbsp;
                \(recipe.difficulty.emoji) \(recipe.difficulty.rawValue)
            </div>
            
            <h2>Ingredients</h2>
        """
        
        for ingredient in recipe.ingredients {
            html += "<div class='ingredient'>• \(ingredient.name) - \(ingredient.quantity) \(ingredient.unit ?? "")</div>\n"
        }
        
        html += "<h2>Instructions</h2>\n"
        
        for (index, instruction) in recipe.instructions.enumerated() {
            html += "<div class='instruction'>\(index + 1). \(instruction)</div>\n"
        }
        
        html += """
            <h2>Nutrition (per serving)</h2>
            <div>
                <span class='nutrition'><strong>Calories:</strong> \(recipe.nutrition.calories)</span>
                <span class='nutrition'><strong>Protein:</strong> \(recipe.nutrition.protein)g</span>
                <span class='nutrition'><strong>Carbs:</strong> \(recipe.nutrition.carbs)g</span>
                <span class='nutrition'><strong>Fat:</strong> \(recipe.nutrition.fat)g</span>
        """
        
        if let fiber = recipe.nutrition.fiber {
            html += "<span class='nutrition'><strong>Fiber:</strong> \(fiber)g</span>"
        }
        
        if let sodium = recipe.nutrition.sodium {
            html += "<span class='nutrition'><strong>Sodium:</strong> \(sodium)mg</span>"
        }
        
        html += """
            </div>
            
            <div class='footer'>
                Created with SnapChef • \(Date().formatted(date: .long, time: .omitted))
            </div>
        </body>
        </html>
        """
        
        return html
    }
}

struct NutritionRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.system(size: 16))
    }
}

#Preview {
    PrintView(recipe: Recipe(
        name: "Chicken Stir Fry",
        description: "A quick and healthy Asian-inspired dish",
        ingredients: [
            Ingredient(name: "Chicken breast", quantity: "500", unit: "g", isAvailable: true),
            Ingredient(name: "Bell peppers", quantity: "2", unit: nil, isAvailable: true),
            Ingredient(name: "Soy sauce", quantity: "3", unit: "tbsp", isAvailable: false)
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
    ))
}