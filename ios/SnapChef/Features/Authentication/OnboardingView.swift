import SwiftUI
import Foundation

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCuisines: Set<String> = []
    
    var body: some View {
        ZStack {
            MagicalBackground()
                .ignoresSafeArea()
            
            // Food Preferences Screen (full screen)
            OnboardingFoodPreferencesView(selectedCuisines: $selectedCuisines) {
                completeOnboarding()
            }
        }
        .onAppear {
            print("🔍 DEBUG: [OnboardingView] appeared")
        }
    }
    
    private func completeOnboarding() {
        appState.completeOnboarding()
    }
}

// MARK: - Food Preferences View
struct OnboardingFoodPreferencesView: View {
    @Binding var selectedCuisines: Set<String>
    let onComplete: () -> Void
    
    // Cuisine grid data reordered from most popular to least popular
    let cuisineOptions = [
        ("Italian", "🍝"), ("Mexican", "🌮"), ("American", "🍔"), ("Asian", "🥢"), 
        ("Mediterranean", "🥙"), ("Indian", "🍛"), ("Healthy", "🥗"), ("Comfort", "🍲"), 
        ("Seafood", "🦐"), ("BBQ", "🔥"), ("Breakfast", "🥞"), ("Quick", "🚀"), 
        ("Desserts", "🍰"), ("Vegan", "🌱"), ("Keto", "🥑"), ("Spicy", "🌶️")
    ]
    
    var buttonText: String {
        if selectedCuisines.count >= 3 {
            return "Let's Cook!"
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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Headline - compact at top
                VStack(spacing: 4) {
                    Text("What Makes You Hungry?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Pick 3+ favorites for recipes you'll actually crave")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                // Counter pill
                HStack {
                    Text(counterText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
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
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                
                // 4x4 grid of cuisine options - taking up maximum space
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
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
                .padding(.horizontal, 8)
                .frame(maxHeight: .infinity)
                
                // Start Creating! button - compact at bottom
                Button(action: {
                    if selectedCuisines.count >= 3 {
                        // Save to UserDefaults
                        UserDefaults.standard.set(Array(selectedCuisines), forKey: "SelectedFoodPreferences")
                        
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Complete onboarding and navigate to HomeView
                        onComplete()
                    }
                }) {
                    Text(buttonText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .cornerRadius(25)
                            .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 10, x: 0, y: 4)
                        )
                }
                .disabled(selectedCuisines.count < 3)
                .opacity(selectedCuisines.count < 3 ? 0.6 : 1.0)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
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
    
    @State private var isPressed = false
    
    // MARK: - Helper Properties
    
    private var selectedColor: Color {
        Color(hex: "#667eea").opacity(0.3)
    }
    
    private var unselectedColor: Color {
        Color.white.opacity(0.1)
    }
    
    private var borderSelectedColor: Color {
        Color(hex: "#667eea")
    }
    
    private var borderUnselectedColor: Color {
        Color.white.opacity(0.2)
    }
    
    // MARK: - Computed Views
    
    @ViewBuilder
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? selectedColor : unselectedColor)
    }
    
    @ViewBuilder
    private var overlayBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected ? borderSelectedColor : borderUnselectedColor, lineWidth: isSelected ? 2 : 1)
    }
    
    var body: some View {
        Button(action: {
            if canSelect {
                // Haptic feedback with enhanced animation
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    isPressed = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
                
                action()
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    // Emoji with bounce animation
                    Text(emoji)
                        .font(.system(size: 32))
                        .scaleEffect(isPressed ? 1.3 : 1.0)
                    
                    // Animated checkmark with scale effect and proper positioning
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 16, height: 16)
                                        .scaleEffect(isPressed ? 1.2 : 1.0)
                                    
                                    Text("✓")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .shadow(color: Color.green.opacity(0.5), radius: 4, x: 0, y: 2)
                                .padding(.top, 4)
                                .padding(.trailing, 4)
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
                    .scaleEffect(isPressed ? 1.1 : 1.0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                backgroundView
            )
            .overlay(
                overlayBorder
            )
            .scaleEffect(isSelected ? (isPressed ? 1.1 : 1.05) : (isPressed ? 0.95 : 1.0))
            .shadow(
                color: isSelected ? Color(hex: "#667eea").opacity(0.5) : Color.black.opacity(0.1),
                radius: isSelected ? 12 : 4,
                x: 0,
                y: isSelected ? 6 : 2
            )
        }
        .disabled(!canSelect)
        .opacity(canSelect ? 1.0 : 0.5)
    }
}


#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .environmentObject(DeviceManager())
}