import SwiftUI
import UIKit

struct InfluencerDetailView: View {
    let influencer: InfluencerRecipe
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var sparkleAnimation = false
    @State private var contentVisible = false
    @State private var showShareSheet = false
    @State private var showingSavedAlert = false
    @State private var showingUserProfile = false
    
    // MARK: - Computed Properties
    private var profileSection: some View {
        VStack(spacing: 16) {
            // Large profile picture
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Text(influencer.influencerName.prefix(2))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                )
                .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 20)
            
            VStack(spacing: 8) {
                Button(action: {
                    showingUserProfile = true
                }) {
                    HStack(spacing: 8) {
                        Text(influencer.influencerName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#4facfe"))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(influencer.influencerHandle + " • " + influencer.followerCount + " followers")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Quote
            Text("\"\(influencer.quote)\"")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            // Stats
            statsSection
        }
        .padding(.top, 20)
        .staggeredFade(index: 0, isShowing: contentVisible)
    }
    
    private var statsSection: some View {
        HStack(spacing: 40) {
            VStack(spacing: 4) {
                Text(formatNumber(influencer.likes))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("Likes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            VStack(spacing: 4) {
                Text(formatNumber(influencer.shares))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("Shares")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            VStack(spacing: 4) {
                Text(timeAgo(from: influencer.dateShared))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("Ago")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(title: "Recipe", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            TabButton(title: "Fridge Contents", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
        .padding(.horizontal, 20)
        .staggeredFade(index: 1, isShowing: contentVisible)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button(action: {
                tryRecipe()
            }) {
                HStack {
                    Image(systemName: "fork.knife")
                    Text("Try This Recipe")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 15, y: 5)
            }
            
            Button(action: {
                showShareSheet = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Recipe")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .staggeredFade(index: 3, isShowing: contentVisible)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header with influencer info
                        VStack(spacing: 20) {
                            profileSection
                            tabSelector
                        }
                        
                        // Content based on selected tab
                        Group {
                            if selectedTab == 0 {
                                RecipeTabContent(recipe: influencer.recipe)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            } else {
                                FridgeTabContent(ingredients: influencer.fridgeContents)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            }
                        }
                        .padding(.top, 20)
                        .staggeredFade(index: 2, isShowing: contentVisible)
                        .animation(.spring(response: 0.3), value: selectedTab)
                        
                        // Action buttons
                        actionButtons
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.2)))
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentVisible = true
            }
            sparkleAnimation = true
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareText = generateShareText() {
                ShareSheet(items: [shareText])
            }
        }
        .alert("Recipe Saved!", isPresented: $showingSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This recipe has been added to your collection with '\(influencer.influencerName)' in the title.")
        }
        .sheet(isPresented: $showingUserProfile) {
            UserProfileView(
                userID: influencer.influencerHandle.replacingOccurrences(of: "@", with: ""),
                userName: influencer.influencerName
            )
        }
    }
    
    private func tryRecipe() {
        // Create a new recipe with the celebrity name in the title
        let originalRecipe = influencer.recipe.recipe
        let modifiedRecipe = Recipe(
            id: UUID(), // New ID for the saved version
            name: "\(influencer.influencerName)'s \(originalRecipe.name)",
            description: originalRecipe.description,
            ingredients: originalRecipe.ingredients,
            instructions: originalRecipe.instructions,
            cookTime: originalRecipe.cookTime,
            prepTime: originalRecipe.prepTime,
            servings: originalRecipe.servings,
            difficulty: originalRecipe.difficulty,
            nutrition: originalRecipe.nutrition,
            imageURL: originalRecipe.imageURL,
            createdAt: Date(), // Current date for when it's saved
            tags: originalRecipe.tags,
            dietaryInfo: originalRecipe.dietaryInfo
        )
        
        // Save the recipe
        appState.addRecentRecipe(modifiedRecipe)
        appState.saveRecipeWithPhotos(modifiedRecipe, beforePhoto: nil, afterPhoto: nil)
        
        // Show confirmation
        showingSavedAlert = true
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func generateShareText() -> String? {
        let recipeNames = [
            "delicious \(influencer.recipe.recipe.name)",
            "amazing \(influencer.recipe.recipe.name)",
            "incredible \(influencer.recipe.recipe.name)",
            "mouth-watering \(influencer.recipe.recipe.name)"
        ].randomElement() ?? influencer.recipe.recipe.name
        
        let messages = [
            "I just discovered \(influencer.influencerName)'s \(recipeNames) on SnapChef! 🍳✨",
            "OMG! \(influencer.influencerName)'s \(recipeNames) looks absolutely amazing! Found it on SnapChef 📸🥘",
            "Check out this \(recipeNames) from \(influencer.influencerName)'s kitchen! Thanks @SnapChef 🌟",
            "I'm obsessed with \(influencer.influencerName)'s \(recipeNames)! Can't wait to try it 😍 #SnapChef",
            "Just found my new favorite recipe: \(influencer.influencerName)'s \(recipeNames) on SnapChef! 🎉"
        ]
        
        return messages.randomElement()
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.0fK", Double(number) / 1_000)
        }
        return "\(number)"
    }
    
    private func timeAgo(from date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "1 day"
        } else {
            return "\(days) days"
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isSelected ? 
                    AnyView(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .padding(4)
                    ) : 
                    AnyView(Color.clear)
                )
        }
    }
}

// MARK: - Recipe Tab Content
struct RecipeTabContent: View {
    let recipe: InfluencerShowcaseRecipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Recipe image placeholder
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#f093fb"), Color(hex: "#f5576c")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 250)
                .overlay(
                    VStack {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))
                        Text(recipe.recipe.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                )
                .padding(.horizontal, 20)
            
            // Recipe details
            VStack(alignment: .leading, spacing: 20) {
                // Info badges
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        InfoBadge(icon: "clock", text: "\(recipe.recipe.prepTime + recipe.recipe.cookTime) min", color: Color(hex: "#43e97b"))
                        InfoBadge(icon: "person.2", text: "\(recipe.recipe.servings) servings", color: Color(hex: "#4facfe"))
                        InfoBadge(icon: "flame", text: "\(recipe.recipe.nutrition.calories) cal", color: Color(hex: "#f5576c"))
                        InfoBadge(icon: "chart.bar", text: recipe.recipe.difficulty.rawValue, color: Color(hex: "#ffa726"))
                    }
                    .padding(.horizontal, 20)
                }
                
                // Description
                VStack(alignment: .leading, spacing: 12) {
                    Text("About this recipe")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(recipe.recipe.description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                .padding(.horizontal, 20)
                
                // Ingredients
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredients")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    ForEach(recipe.recipe.ingredients, id: \.name) { ingredient in
                        HStack {
                            Circle()
                                .fill(Color(hex: "#667eea"))
                                .frame(width: 8, height: 8)
                            
                            Text("\(ingredient.quantity) \(ingredient.unit ?? "") \(ingredient.name)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    ForEach(Array(recipe.recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(Color(hex: "#667eea"))
                                )
                            
                            Text(instruction)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .lineSpacing(2)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Fridge Tab Content
struct FridgeTabContent: View {
    let ingredients: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What was in their fridge")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                ForEach(ingredients, id: \.self) { ingredient in
                    HStack(spacing: 8) {
                        Image(systemName: "refrigerator")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#43e97b"))
                        
                        Text(ingredient)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
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
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Info Badge
struct InfoBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(text)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
        )
    }
}

#Preview {
    InfluencerDetailView(influencer: InfluencerRecipe.mockInfluencers[0])
}