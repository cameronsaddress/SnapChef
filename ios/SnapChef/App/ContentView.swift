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
        // Single NavigationStack at the root level
        NavigationStack {
            ZStack {
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case 0:
                        HomeView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    case 1:
                        CameraView(selectedTab: $selectedTab)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    case 2:
                        RecipesView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    case 3:
                        ChallengeHubView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    case 4:
                        ProfileView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    default:
                        HomeView()
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
                
                // Custom morphing tab bar (hide when camera is selected)
                if selectedTab != 1 {
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarHidden(true) // Hide the default navigation bar
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager())
        .environmentObject(DeviceManager())
}