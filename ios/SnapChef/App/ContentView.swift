import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: UnifiedAuthManager
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
        .onAppear {
            print("🔍 DEBUG: ContentView appeared")
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var pendingTabSelection: Int?
    @EnvironmentObject var authManager: UnifiedAuthManager
        @State private var showingCameraPermissionAlert = false

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
                        DetectiveView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    case 3:
                        RecipesView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    case 4:
                        SocialFeedView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    case 5:
                        ProfileView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    default:
                        HomeView()
                    }
                }

                // Custom morphing tab bar (hide when camera is selected)
                if selectedTab != 1 {
                    VStack {
                        Spacer()

                        MorphingTabBar(selectedTab: $selectedTab, onTabSelection: handleTabSelection)
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
        .sheet(isPresented: $authManager.showUsernameSetup) {
            UsernameSetupView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $authManager.showAuthSheet) {
            UnifiedAuthView()
                .environmentObject(authManager)
        }
        .alert("Camera Access Required", isPresented: $showingCameraPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("SnapChef needs camera access to capture photos of your ingredients. Please enable camera access in Settings.")
        }
    }
    
    // Handle tab selection with camera permission checking
    private func handleTabSelection(_ newTab: Int) {
        // Check if user is trying to switch to camera tab (index 1) or detective tab (index 2)
        if newTab == 1 || newTab == 2 {
            Task {
                let granted = await requestCameraPermission()
                if granted {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = newTab
                        }
                    }
                }
                // If permission denied, stay on current tab
            }
        } else {
            // For non-camera tabs, switch immediately
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = newTab
            }
        }
    }
    
    // MARK: - Camera Permission Handling
    @MainActor
    private func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return true
            
        case .notDetermined:
            // Request permission
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted
            
        case .denied, .restricted:
            showingCameraPermissionAlert = true
            return false
            
        @unknown default:
            showingCameraPermissionAlert = true
            return false
        }
    }
}

// MARK: - Social Feed View
struct SocialFeedView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: UnifiedAuthManager
    @State private var showingDiscoverUsers = false
    @State private var isRefreshing = false
    @State private var hasLoadedInitialData = false

    var body: some View {
        let _ = print("🔍 DEBUG: SocialFeedView body called")
        return NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Social Stats Header
                    Group {
                        let _ = print("🔍 DEBUG: Building socialStatsHeader")
                        socialStatsHeader
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                    // Activity Feed Content
                    Group {
                        let _ = print("🔍 DEBUG: Building ActivityFeedView")
                        ActivityFeedView()
                            .environmentObject(appState)
                    }
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingDiscoverUsers = true
                    }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showingDiscoverUsers) {
            DiscoverUsersView()
                .environmentObject(appState)
        }
        .task {
            // Initial data load
            if !hasLoadedInitialData && authManager.isAuthenticated {
                print("🔍 DEBUG: SocialFeedView initial data load")
                do {
                    try await authManager.refreshCurrentUserData()
                    await authManager.updateSocialCounts()
                    await authManager.updateRecipeCounts()
                    hasLoadedInitialData = true
                    print("✅ DEBUG: User data loaded - Followers: \(authManager.currentUser?.followerCount ?? 0), Following: \(authManager.currentUser?.followingCount ?? 0), Recipes Created: \(authManager.currentUser?.recipesCreated ?? 0)")
                } catch {
                    print("❌ Failed to refresh user data: \(error)")
                }
            }
        }
        .onAppear {
            print("🔍 DEBUG: SocialFeedView appeared")
            print("🔍 DEBUG: Current user: \(authManager.currentUser?.username ?? "nil")")
            print("🔍 DEBUG: Followers: \(authManager.currentUser?.followerCount ?? 0)")
            print("🔍 DEBUG: Following: \(authManager.currentUser?.followingCount ?? 0)")
            print("🔍 DEBUG: Recipes Created: \(authManager.currentUser?.recipesCreated ?? 0)")
            
            // Force refresh if data looks stale
            if authManager.isAuthenticated && authManager.currentUser != nil {
                let needsRefresh = (authManager.currentUser?.followerCount ?? 0) == 0 &&
                                  (authManager.currentUser?.followingCount ?? 0) == 0 &&
                                  (authManager.currentUser?.recipesCreated ?? 0) == 0
                
                if needsRefresh && !isRefreshing {
                    print("🔍 DEBUG: Data looks stale, forcing refresh")
                    Task {
                        await refreshSocialData()
                    }
                }
            }
        }
    }

    private func refreshSocialData() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        print("🔍 DEBUG: Refreshing social data...")
        
        // Refresh user data to get latest counts
        if authManager.isAuthenticated {
            do {
                // First refresh user data
                try await authManager.refreshCurrentUserData()
                
                // Update social counts (followers/following)
                await authManager.updateSocialCounts()
                
                // Then update recipe counts from CloudKit
                await authManager.updateRecipeCounts()
                
                print("✅ DEBUG: Social data refreshed - Followers: \(authManager.currentUser?.followerCount ?? 0), Following: \(authManager.currentUser?.followingCount ?? 0), Recipes Created: \(authManager.currentUser?.recipesCreated ?? 0)")
            } catch {
                print("❌ Failed to refresh user data: \(error)")
            }
        }
        
        isRefreshing = false
    }

    private var socialStatsHeader: some View {
        VStack(spacing: 16) {
            // User Info Row
            HStack(spacing: 16) {
                // Profile Image
                if let user = authManager.currentUser {
                    UserAvatarView(
                        userID: user.recordID,
                        username: user.username,
                        displayName: user.displayName,
                        size: 60
                    )
                }

                // Stats
                HStack(spacing: 24) {
                    socialStatItem(
                        count: {
                            let count = authManager.currentUser?.followerCount ?? 0
                            print("🔍 DEBUG SocialFeedView - Followers field: authManager.currentUser?.followerCount = \(count)")
                            print("    └─ CloudKit field: CKField.User.followerCount")
                            return count
                        }(),
                        label: "Followers"
                    )

                    socialStatItem(
                        count: {
                            let count = authManager.currentUser?.followingCount ?? 0
                            print("🔍 DEBUG SocialFeedView - Following field: authManager.currentUser?.followingCount = \(count)")
                            print("    └─ CloudKit field: CKField.User.followingCount")
                            return count
                        }(),
                        label: "Following"
                    )

                    socialStatItem(
                        count: {
                            let count = authManager.currentUser?.recipesCreated ?? 0
                            print("🔍 DEBUG SocialFeedView - Recipes field: authManager.currentUser?.recipesCreated = \(count)")
                            print("    └─ CloudKit field: CKField.User.recipesCreated")
                            return count
                        }(),
                        label: "Recipes"
                    )
                }

                Spacer()
            }

            // Discover Button
            Button(action: {
                showingDiscoverUsers = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Discover Chefs")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private func socialStatItem(count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager())
        .environmentObject(DeviceManager())
}
