import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showingLaunchAnimation = true
    
    var body: some View {
        ZStack {
            if showingLaunchAnimation {
                LaunchAnimationView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showingLaunchAnimation = false
                    }
                }
                .zIndex(3)
            } else {
                // Magical animated background
                MagicalBackground()
                    .ignoresSafeArea()
                    .zIndex(0)
                
                // Main navigation on top
                Group {
                    if appState.isFirstLaunch {
                        OnboardingView()
                    } else {
                        MainTabView()
                    }
                }
                .zIndex(2)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showingLaunchAnimation)
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Content based on selected tab
            Group {
                switch selectedTab {
                case 0:
                    EnhancedHomeView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .scale(scale: 1.02))
                        ))
                case 1:
                    CameraTabView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .scale(scale: 1.02))
                        ))
                case 2:
                    EnhancedRecipesView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .scale(scale: 1.02))
                        ))
                case 3:
                    EnhancedProfileView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .scale(scale: 1.02))
                        ))
                default:
                    EnhancedHomeView()
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
            
            // Custom morphing tab bar
            VStack {
                Spacer()
                
                MorphingTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 20,
                        y: 10
                    )
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager())
        .environmentObject(DeviceManager())
}