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
    @State private var headerVisible = false
    @State private var gridVisible = false
    @State private var ctaVisible = false
    @State private var ctaPulse = false
    @State private var orbDrift = false
    @State private var revealedTileIndex = -1
    
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
        GeometryReader { _ in
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#FFB347").opacity(0.38), .clear],
                            center: .center,
                            startRadius: 12,
                            endRadius: 180
                        )
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 12)
                    .offset(x: orbDrift ? -120 : -20, y: orbDrift ? -340 : -260)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#FF5E62").opacity(0.28), .clear],
                            center: .center,
                            startRadius: 8,
                            endRadius: 220
                        )
                    )
                    .frame(width: 340, height: 340)
                    .blur(radius: 14)
                    .offset(x: orbDrift ? 150 : 70, y: orbDrift ? 260 : 180)

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
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 12)
                
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
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 8)
                
                // 4x4 grid of cuisine options - taking up maximum space
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                    ForEach(Array(cuisineOptions.enumerated()), id: \.element.0) { index, item in
                        let cuisine = item.0
                        let emoji = item.1
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
                        .opacity(gridVisible && index <= revealedTileIndex ? 1 : 0)
                        .scaleEffect(gridVisible && index <= revealedTileIndex ? 1 : 0.9)
                        .offset(y: gridVisible && index <= revealedTileIndex ? 0 : 10)
                    }
                }
                .padding(.horizontal, 8)
                .frame(maxHeight: .infinity)
                .opacity(gridVisible ? 1 : 0.001)
                .offset(y: gridVisible ? 0 : 10)
                
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
                                colors: [Color(hex: "#FF8A00"), Color(hex: "#FF5E62")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .cornerRadius(25)
                            .shadow(color: Color(hex: "#FF8A00").opacity(0.45), radius: 12, x: 0, y: 4)
                        )
                }
                .disabled(selectedCuisines.count < 3)
                .opacity(selectedCuisines.count < 3 ? 0.6 : 1.0)
                .scaleEffect(selectedCuisines.count >= 3 ? (ctaPulse ? 1.01 : 0.99) : 1.0)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 16)
            }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                headerVisible = true
            }
            withAnimation(.spring(response: 0.58, dampingFraction: 0.84).delay(0.08)) {
                gridVisible = true
            }
            withAnimation(.spring(response: 0.65, dampingFraction: 0.85).delay(0.16)) {
                ctaVisible = true
            }
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) {
                orbDrift = true
            }

            revealedTileIndex = -1
            for index in cuisineOptions.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14 + Double(index) * 0.02) {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        revealedTileIndex = index
                    }
                }
            }
        }
        .onChange(of: selectedCuisines.count) { count in
            guard count >= 3 else {
                ctaPulse = false
                return
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                ctaPulse = true
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
        Color(hex: "#FF8A00").opacity(0.28)
    }
    
    private var unselectedColor: Color {
        Color.white.opacity(0.1)
    }
    
    private var borderSelectedColor: Color {
        Color(hex: "#FF8A00")
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
                color: isSelected ? Color(hex: "#FF8A00").opacity(0.45) : Color.black.opacity(0.1),
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
