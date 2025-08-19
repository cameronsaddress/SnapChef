import SwiftUI

struct DetectiveResultsView: View {
    let detectedRecipe: DetectedRecipe
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var showingSaveSuccess = false
    @State private var showingShareSheet = false
    @State private var caseSolvedAnimation = false
    @State private var confidenceAnimation = false
    @State private var sparkleAnimation = false
    @State private var showingRecipeDetail = false
    
    var body: some View {
        ZStack {
            // Dark detective background
            LinearGradient(
                colors: [
                    Color(hex: "#0f0625"),
                    Color(hex: "#1a0033"),
                    Color(hex: "#0a051a")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header with close button
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Case Solved Celebration
                    VStack(spacing: 20) {
                        ZStack {
                            // Animated celebration burst
                            ForEach(0..<8, id: \.self) { index in
                                Image(systemName: "sparkle")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "#ffd700"))
                                    .offset(
                                        x: cos(Double(index) * .pi / 4) * (caseSolvedAnimation ? 80 : 0),
                                        y: sin(Double(index) * .pi / 4) * (caseSolvedAnimation ? 80 : 0)
                                    )
                                    .opacity(caseSolvedAnimation ? 1 : 0)
                                    .scaleEffect(caseSolvedAnimation ? 1.5 : 0.5)
                                    .animation(
                                        .easeOut(duration: 1.2)
                                            .delay(Double(index) * 0.1),
                                        value: caseSolvedAnimation
                                    )
                            }
                            
                            VStack(spacing: 12) {
                                Text("🎉")
                                    .font(.system(size: 60))
                                    .scaleEffect(caseSolvedAnimation ? 1.2 : 0.8)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: caseSolvedAnimation)
                                
                                Text("Case Solved!")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#ffd700"),
                                                Color(hex: "#ffed4e")
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .scaleEffect(caseSolvedAnimation ? 1 : 0.5)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3), value: caseSolvedAnimation)
                            }
                        }
                        .frame(height: 160)
                        
                        Text("Your dish has been successfully analyzed and reverse-engineered!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .opacity(caseSolvedAnimation ? 1 : 0)
                            .animation(.easeIn(duration: 0.8).delay(0.6), value: caseSolvedAnimation)
                    }
                    
                    // Original Dish Image
                    VStack(spacing: 16) {
                        Text("Evidence")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "#ffd700"))
                        
                        Image(uiImage: detectedRecipe.originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: Color(hex: "#ffd700").opacity(0.3), radius: 15, y: 8)
                    }
                    .padding(.horizontal, 20)
                    
                    // Dish Identification & Confidence Score
                    VStack(spacing: 20) {
                        // Identified Dish
                        DetectiveCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "target")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color(hex: "#ffd700"))
                                    
                                    Text("Dish Identified")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                }
                                
                                Text(detectedRecipe.dishName)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#ffd700"),
                                                Color(hex: "#ffed4e")
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                        }
                        
                        // Confidence Score
                        DetectiveCard {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color(hex: "#ffd700"))
                                    
                                    Text("Confidence Score")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                }
                                
                                // Animated confidence meter
                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                                        .frame(width: 120, height: 120)
                                    
                                    Circle()
                                        .trim(from: 0, to: confidenceAnimation ? Double(detectedRecipe.confidenceScore) / 100 : 0)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                        )
                                        .frame(width: 120, height: 120)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.spring(response: 1.5, dampingFraction: 0.8), value: confidenceAnimation)
                                    
                                    VStack(spacing: 4) {
                                        Text("\(detectedRecipe.confidenceScore)%")
                                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                                            .foregroundColor(Color(hex: "#ffd700"))
                                        
                                        Text("Match")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                
                                Text(getConfidenceDescription(detectedRecipe.confidenceScore))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Estimated Ingredients
                    DetectiveCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "list.bullet.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(hex: "#ffd700"))
                                
                                Text("Detected Ingredients")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(Array(detectedRecipe.estimatedIngredients.enumerated()), id: \.offset) { index, ingredient in
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "#ffd700"))
                                        
                                        Text(ingredient)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.9))
                                        
                                        Spacer()
                                    }
                                    .opacity(sparkleAnimation ? 1 : 0)
                                    .animation(.easeIn(duration: 0.5).delay(Double(index) * 0.1), value: sparkleAnimation)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // View Full Recipe Button
                        Button(action: {
                            showingRecipeDetail = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("View Full Recipe")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#ffd700"),
                                                Color(hex: "#ffb347")
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .shadow(color: Color(hex: "#ffd700").opacity(0.6), radius: 20, y: 10)
                        }
                        
                        // Save to Recipe Book Button
                        Button(action: {
                            saveToRecipeBook()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color(hex: "#ffd700"))
                                
                                Text("Save to Recipe Book")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                // Detective badge
                                HStack(spacing: 4) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color(hex: "#2d1b69"))
                                    
                                    Text("DETECTIVE")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color(hex: "#2d1b69"))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#ffd700"))
                                )
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                            )
                            .shadow(color: Color(hex: "#ffd700").opacity(0.3), radius: 15, y: 8)
                        }
                        
                        // Share Button
                        Button(action: {
                            showingShareSheet = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Share Discovery")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 50)
                }
            }
            
            // Save Success Overlay
            if showingSaveSuccess {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#ffd700"))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(Color(hex: "#2d1b69"))
                        }
                        
                        VStack(spacing: 8) {
                            Text("Recipe Saved!")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Added to your recipe book with Detective badge")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "#1a0033"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(hex: "#ffd700"), lineWidth: 2)
                            )
                    )
                    .padding(.horizontal, 40)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startAnimations()
        }
        .fullScreenCover(isPresented: $showingRecipeDetail) {
            RecipeDetailView(recipe: detectedRecipe.reconstructedRecipe)
        }
        .sheet(isPresented: $showingShareSheet) {
            DetectiveShareSheet(items: [createShareText()])
        }
    }
    
    private func startAnimations() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            caseSolvedAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            confidenceAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            sparkleAnimation = true
        }
    }
    
    private func getConfidenceDescription(_ score: Int) -> String {
        switch score {
        case 90...100:
            return "Excellent match! This analysis is highly accurate."
        case 80..<90:
            return "Very good match! High confidence in the analysis."
        case 70..<80:
            return "Good match! Solid identification with minor variations."
        case 60..<70:
            return "Fair match! Some similarities detected."
        default:
            return "Basic match! Recipe may vary significantly."
        }
    }
    
    private func saveToRecipeBook() {
        // Add detective badge to recipe
        let recipeWithBadge = Recipe(
            id: detectedRecipe.reconstructedRecipe.id,
            name: detectedRecipe.reconstructedRecipe.name,
            description: detectedRecipe.reconstructedRecipe.description,
            ingredients: detectedRecipe.reconstructedRecipe.ingredients,
            instructions: detectedRecipe.reconstructedRecipe.instructions,
            cookTime: detectedRecipe.reconstructedRecipe.cookTime,
            prepTime: detectedRecipe.reconstructedRecipe.prepTime,
            servings: detectedRecipe.reconstructedRecipe.servings,
            difficulty: detectedRecipe.reconstructedRecipe.difficulty,
            nutrition: detectedRecipe.reconstructedRecipe.nutrition,
            imageURL: detectedRecipe.reconstructedRecipe.imageURL,
            createdAt: detectedRecipe.reconstructedRecipe.createdAt,
            tags: detectedRecipe.reconstructedRecipe.tags + ["Detective"],
            dietaryInfo: detectedRecipe.reconstructedRecipe.dietaryInfo,
            isDetectiveRecipe: true,
            cookingTechniques: detectedRecipe.reconstructedRecipe.cookingTechniques,
            flavorProfile: detectedRecipe.reconstructedRecipe.flavorProfile,
            secretIngredients: detectedRecipe.reconstructedRecipe.secretIngredients,
            proTips: detectedRecipe.reconstructedRecipe.proTips,
            visualClues: detectedRecipe.reconstructedRecipe.visualClues,
            shareCaption: detectedRecipe.reconstructedRecipe.shareCaption
        )
        
        appState.savedRecipes.append(recipeWithBadge)
        
        showingSaveSuccess = true
        
        // Auto-dismiss save success
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingSaveSuccess = false
            }
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func createShareText() -> String {
        return """
        🔍 Recipe Detective Success! 🎉
        
        Just reverse-engineered: \(detectedRecipe.dishName)
        Confidence: \(detectedRecipe.confidenceScore)% match
        
        Ingredients detected:
        \(detectedRecipe.estimatedIngredients.prefix(5).joined(separator: ", "))
        
        Now I can recreate this delicious dish at home! 👨‍🍳
        
        #RecipeDetective #SnapChef #CookingAtHome
        """
    }
}

// MARK: - Supporting Views

struct DetectiveCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#ffd700").opacity(0.4),
                                        Color(hex: "#2d1b69").opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial.opacity(0.2))
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
    }
}

struct DetectiveShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    DetectiveResultsView(
        detectedRecipe: DetectedRecipe(
            originalImage: UIImage(systemName: "photo") ?? UIImage(),
            dishName: "Classic Chicken Parmesan",
            confidenceScore: 87,
            estimatedIngredients: [
                "Chicken breast",
                "Parmesan cheese",
                "Breadcrumbs",
                "Marinara sauce",
                "Mozzarella cheese",
                "Italian seasoning"
            ],
            reconstructedRecipe: Recipe(
                id: UUID(),
                name: "Classic Chicken Parmesan",
                description: "Crispy breaded chicken breast topped with marinara sauce and melted cheese",
                ingredients: [
                    Ingredient(id: UUID(), name: "2 chicken breasts, pounded thin", quantity: "2", unit: "pieces", isAvailable: true),
                    Ingredient(id: UUID(), name: "1 cup panko breadcrumbs", quantity: "1", unit: "cup", isAvailable: true),
                    Ingredient(id: UUID(), name: "1/2 cup grated Parmesan cheese", quantity: "1/2", unit: "cup", isAvailable: true)
                ],
                instructions: [
                    "Preheat oven to 425°F",
                    "Set up breading station",
                    "Dredge chicken and bake"
                ],
                cookTime: 35,
                prepTime: 15,
                servings: 4,
                difficulty: .medium,
                nutrition: Nutrition(
                    calories: 485,
                    protein: 42,
                    carbs: 28,
                    fat: 22,
                    fiber: 3,
                    sugar: 8,
                    sodium: 650
                ),
                imageURL: nil,
                createdAt: Date(),
                tags: ["Italian", "Main Course"],
                dietaryInfo: DietaryInfo(
                    isVegetarian: false,
                    isVegan: false,
                    isGlutenFree: false,
                    isDairyFree: false
                ),
                isDetectiveRecipe: true,
                cookingTechniques: ["breading", "baking"],
                flavorProfile: FlavorProfile(sweet: 3, salty: 7, sour: 2, bitter: 1, umami: 6),
                secretIngredients: ["Italian seasoning blend"],
                proTips: ["Pound chicken evenly for consistent cooking"],
                visualClues: ["Golden brown crust", "Melted cheese topping"],
                shareCaption: "Homemade Chicken Parmesan! 🍗🧀 #ChickenParmesan #Homemade"
            )
        )
    )
    .environmentObject(AppState())
}