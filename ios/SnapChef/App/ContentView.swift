import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var deviceManager: DeviceManager
    
    var body: some View {
        ZStack {
            // Gradient background
            GradientBackground()
                .ignoresSafeArea()
            
            // Main navigation
            if appState.isFirstLaunch {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .background(
            // Floating food animations behind everything
            FloatingFoodAnimation()
                .allowsHitTesting(false)
                .zIndex(-1)
        )
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            CameraView()
                .tabItem {
                    Label("Snap", systemImage: "camera.fill")
                }
                .tag(1)
            
            RecipesView()
                .tabItem {
                    Label("Recipes", systemImage: "book.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .accentColor(.white)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager())
        .environmentObject(DeviceManager())
}