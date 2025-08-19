import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var selectedCuisines: Set<String> = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                TabView(selection: $currentPage) {
                    // Screen 1: Welcome Screen
                    Screen1View {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            currentPage = 1
                        }
                    }
                    .tag(0)
                    
                    // Screen 2: Food Preferences
                    Screen2View(selectedCuisines: $selectedCuisines) {
                        completeOnboarding()
                    }
                    .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.width > 50 && currentPage == 1 {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    currentPage = 0
                                }
                            } else if value.translation.width < -50 && currentPage == 0 {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    currentPage = 1
                                }
                            }
                        }
                )
                
                // Skip button (only on screen 1)
                if currentPage == 0 {
                    VStack {
                        HStack {
                            Spacer()
                            Button("Skip") {
                                completeOnboarding()
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                        }
                        .padding(.top, 50)
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func completeOnboarding() {
        appState.completeOnboarding()
    }
}

// MARK: - Screen 1 View
struct Screen1View: View {
    let onContinue: () -> Void
    @State private var animateElements = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Headline
            VStack(spacing: 8) {
                Text("Turn Leftovers into")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .scaleEffect(animateElements ? 1.0 : 0.8)
                    .opacity(animateElements ? 1.0 : 0.0)
                
                Text("Chef-Level Meals!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .scaleEffect(animateElements ? 1.0 : 0.8)
                    .opacity(animateElements ? 1.0 : 0.0)
                
                Text("Join 50K+ home chefs creating magic with AI")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .scaleEffect(animateElements ? 1.0 : 0.8)
                    .opacity(animateElements ? 1.0 : 0.0)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Two simple panels side by side
            HStack(spacing: 20) {
                // Left Panel - SnapChef Mode
                SimpleSnapChefPanel()
                    .scaleEffect(animateElements ? 1.0 : 0.9)
                    .opacity(animateElements ? 1.0 : 0.0)
                
                // Right Panel - Detective Mode  
                SimpleDetectivePanel()
                    .scaleEffect(animateElements ? 1.0 : 0.9)
                    .opacity(animateElements ? 1.0 : 0.0)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Three benefit pills
            VStack(spacing: 12) {
                BenefitPill(icon: "⚡", text: "Generate recipes in 30 seconds")
                    .scaleEffect(animateElements ? 1.0 : 0.9)
                    .opacity(animateElements ? 1.0 : 0.0)
                
                BenefitPill(icon: "🎯", text: "Use exactly what you have")
                    .scaleEffect(animateElements ? 1.0 : 0.9)
                    .opacity(animateElements ? 1.0 : 0.0)
                
                BenefitPill(icon: "✨", text: "AI-powered meal suggestions")
                    .scaleEffect(animateElements ? 1.0 : 0.9)
                    .opacity(animateElements ? 1.0 : 0.0)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Let's Cook! gradient button
            Button(action: onContinue) {
                Text("Let's Cook!")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .cornerRadius(30)
                        .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 15, x: 0, y: 5)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
            .scaleEffect(animateElements ? 1.0 : 0.9)
            .opacity(animateElements ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animateElements = true
            }
        }
    }
}

// MARK: - Screen 2 View
struct Screen2View: View {
    @Binding var selectedCuisines: Set<String>
    let onComplete: () -> Void
    
    // Cuisine grid data as specified
    let cuisineOptions = [
        ("Italian", "🍝"), ("Mexican", "🌮"), ("Asian", "🥢"), ("Indian", "🍛"),
        ("American", "🍔"), ("Healthy", "🥗"), ("Comfort", "🍲"), ("Mediterranean", "🥙"),
        ("Vegan", "🌱"), ("Quick", "🚀"), ("Desserts", "🍰"), ("Seafood", "🦐"),
        ("BBQ", "🔥"), ("Breakfast", "🥞"), ("Keto", "🥑"), ("Spicy", "🌶️")
    ]
    
    var buttonText: String {
        if selectedCuisines.count >= 3 {
            return "Start Creating!"
        } else {
            return "Select \(3 - selectedCuisines.count) more to continue"
        }
    }
    
    var counterText: String {
        if selectedCuisines.count >= 3 {
            return "\(selectedCuisines.count)/3 selected"
        } else {
            return "\(selectedCuisines.count)/3 selected"
        }
    }
    
    var counterColor: Color {
        selectedCuisines.count >= 3 ? .green : .orange
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Headline
            VStack(spacing: 8) {
                Text("What Makes You Hungry?")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Pick 3+ favorites for recipes you'll actually crave")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Counter pill
            HStack {
                Text(counterText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(counterColor.opacity(0.3))
                            .overlay(
                                Capsule()
                                    .stroke(counterColor, lineWidth: 1.5)
                            )
                    )
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // 4x4 grid of cuisine options
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(cuisineOptions, id: \.0) { cuisine, emoji in
                    CuisineGridItem(
                        title: cuisine,
                        emoji: emoji,
                        isSelected: selectedCuisines.contains(cuisine),
                        canSelect: selectedCuisines.count < 8 || selectedCuisines.contains(cuisine)
                    ) {
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedCuisines.contains(cuisine) {
                                selectedCuisines.remove(cuisine)
                            } else if selectedCuisines.count < 8 {
                                selectedCuisines.insert(cuisine)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Start Creating! button
            Button(action: {
                if selectedCuisines.count >= 3 {
                    // Save to UserDefaults
                    UserDefaults.standard.set(Array(selectedCuisines), forKey: "SelectedFoodPreferences")
                    
                    // Haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    onComplete()
                }
            }) {
                Text(buttonText)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .cornerRadius(30)
                        .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 15, x: 0, y: 5)
                    )
            }
            .disabled(selectedCuisines.count < 3)
            .opacity(selectedCuisines.count < 3 ? 0.6 : 1.0)
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Cuisine Grid Item
struct CuisineGridItem: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let canSelect: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if canSelect {
                action()
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Text(emoji)
                        .font(.system(size: 24))
                    
                    // Checkmark in corner for selected items
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Text("✓")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.green)
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                    }
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ).opacity(0.3) :
                        Color.white.opacity(0.1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ?
                                AnyShapeStyle(LinearGradient(
                                    colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )) :
                                AnyShapeStyle(Color.white.opacity(0.2)),
                                lineWidth: isSelected ? 2 : 1.5
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(
                color: isSelected ? Color(hex: "#667eea").opacity(0.4) : Color.clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: isSelected ? 4 : 0
            )
        }
        .disabled(!canSelect)
        .opacity(canSelect ? 1.0 : 0.5)
    }
}

// MARK: - Simple SnapChef Mode Panel
struct SimpleSnapChefPanel: View {
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("SnapChef Mode")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                VStack(spacing: 16) {
                    // Simple fridge icon
                    Text("🔥")
                        .font(.system(size: 60))
                        .scaleEffect(animateIcon ? 1.1 : 1.0)
                    
                    // Arrow down
                    Text("↓")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Dish icon
                    Text("🍝")
                        .font(.system(size: 40))
                        .scaleEffect(animateIcon ? 1.0 : 0.9)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateIcon = true
            }
        }
    }
}

// MARK: - Simple Detective Mode Panel
struct SimpleDetectivePanel: View {
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Detective Mode")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                VStack(spacing: 16) {
                    // Simple camera icon
                    Text("📱")
                        .font(.system(size: 60))
                        .scaleEffect(animateIcon ? 1.1 : 1.0)
                    
                    // Arrow down
                    Text("↓")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Recipe cards
                    Text("📄")
                        .font(.system(size: 40))
                        .scaleEffect(animateIcon ? 1.0 : 0.9)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateIcon = true
            }
        }
    }
}

// MARK: - Benefit Pills
struct BenefitPill: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 20))
            
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}