import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var showingFoodPreferences = false
    
    let pages = [
        OnboardingPage(
            emoji: "📸",
            title: "Snap Your Fridge",
            description: "Take a photo of your fridge or pantry contents"
        ),
        OnboardingPage(
            emoji: "🤖",
            title: "AI Magic",
            description: "Our AI analyzes your ingredients and creates custom recipes"
        ),
        OnboardingPage(
            emoji: "🍳",
            title: "Cook & Share",
            description: "Follow easy instructions and share your creations for rewards"
        )
    ]
    
    var body: some View {
        ZStack {
            MagicalBackground()
                .ignoresSafeArea()
            
            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
                }
                .padding(.top, 50)
                
                // Pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.bottom, 20)
                
                // Continue button
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        // Show food preferences before completing onboarding
                        showingFoodPreferences = true
                    }
                }) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
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
                .padding(.bottom, 50)
            }
        }
        .onChange(of: showingFoodPreferences) { newValue in
            if newValue {
                // For now, just complete onboarding
                // TODO: Show FoodPreferencesView when it's properly added to the project
                completeOnboarding()
            }
        }
    }
    
    private func completeOnboarding() {
        appState.completeOnboarding()
    }
}

struct OnboardingPage {
    let emoji: String
    let title: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text(page.emoji)
                .font(.system(size: 100))
                .scaleEffect(isAnimating ? 1.0 : 0.9)
                .animation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text(page.description)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}