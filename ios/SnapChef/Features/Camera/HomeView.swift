import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showingCamera = false
    
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Logo and tagline
                        VStack(spacing: 10) {
                            Text("SnapChef")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .overlay(
                                    Text("✨")
                                        .font(.system(size: 36))
                                        .offset(x: 80, y: -10)
                                )
                            
                            Text("Turn your fridge into a feast!")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 50)
                        
                        // Free uses indicator
                        if !deviceManager.hasUnlimitedAccess {
                            FreeUsesIndicator(remaining: deviceManager.freeUsesRemaining)
                                .padding(.horizontal, 40)
                        }
                        
                        // Main CTA button
                        Button(action: {
                            showingCamera = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24))
                                Text("Snap Your Fridge")
                                    .font(.system(size: 20, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(Color.black.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 30)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 40)
                        
                        // Features grid
                        FeaturesGrid()
                            .padding(.horizontal, 20)
                        
                        // Recent recipes
                        if !appState.recentRecipes.isEmpty {
                            RecentRecipesSection(recipes: appState.recentRecipes)
                                .padding(.top, 20)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView()
        }
    }
}

struct FreeUsesIndicator: View {
    let remaining: Int
    
    var body: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
            Text("\(remaining) free snaps remaining")
                .font(.system(size: 16, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct FeaturesGrid: View {
    let features = [
        ("🤖", "AI-Powered", "Smart recipe suggestions"),
        ("🎯", "Personalized", "Tailored to your taste"),
        ("⚡", "Instant", "Results in seconds"),
        ("🌟", "Share & Earn", "Get credits for sharing")
    ]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
            ForEach(features, id: \.1) { emoji, title, description in
                FeatureCard(emoji: emoji, title: title, description: description)
            }
        }
    }
}

struct FeatureCard: View {
    let emoji: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 36))
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
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

struct RecentRecipesSection: View {
    let recipes: [Recipe]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Recent Creations")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(recipes) { recipe in
                        RecipeCard(recipe: recipe)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
            
            HStack {
                Label("\(recipe.cookTime)m", systemImage: "clock")
                    .font(.system(size: 12))
                
                Spacer()
                
                Text(recipe.difficulty.emoji)
                    .font(.system(size: 14))
            }
            .foregroundColor(.white.opacity(0.8))
        }
        .padding(15)
        .frame(width: 180, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(DeviceManager())
}