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
            // print("🔍 DEBUG: ContentView appeared")
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var pendingTabSelection: Int?
    @State private var showingCameraPermissionAlert = false
    @State private var showPremiumPrompt = false
    @State private var premiumPromptReason: PremiumUpgradePrompt.UpgradeReason = .dailyLimitReached
    @EnvironmentObject var authManager: UnifiedAuthManager

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
                        RecipesView(selectedTab: $selectedTab)
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
        .sheet(isPresented: $showPremiumPrompt) {
            PremiumUpgradePrompt(
                isPresented: $showPremiumPrompt,
                reason: premiumPromptReason
            )
        }
    }
    
    // Handle tab selection with camera permission and recipe limit checking
    private func handleTabSelection(_ newTab: Int) {
        // Check if user is trying to switch to camera tab (index 1)
        if newTab == 1 {
            // Check recipe limit first
            let usageTracker = UsageTracker.shared
            let subscriptionManager = SubscriptionManager.shared
            
            if !subscriptionManager.isPremium && usageTracker.hasReachedRecipeLimit() {
                // Show limit reached UI instead of camera
                premiumPromptReason = .dailyLimitReached
                showPremiumPrompt = true
                return
            }
            
            // If limit not reached, check camera permission
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
        } else if newTab == 2 {
            // Detective tab - just check camera permission
            Task {
                let granted = await requestCameraPermission()
                if granted {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = newTab
                        }
                    }
                }
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
            // Initial data load - use synchronized method to prevent race conditions
            guard !hasLoadedInitialData else { return }
            guard authManager.isAuthenticated else { return }
            guard !isRefreshing else { 
                print("⚠️ SocialFeedView: Refresh already in progress in .task")
                return 
            }
            
            print("🔍 DEBUG: SocialFeedView initial data load")
            hasLoadedInitialData = true // Set immediately to prevent double-load
            await authManager.refreshAllSocialData()
            print("✅ DEBUG: User data loaded - Followers: \(authManager.currentUser?.followerCount ?? 0), Following: \(authManager.currentUser?.followingCount ?? 0), Recipes Created: \(authManager.currentUser?.recipesCreated ?? 0)")
        }
        .onAppear {
            print("🔍 DEBUG: SocialFeedView appeared")
            print("🔍 DEBUG: Current user: \(authManager.currentUser?.username ?? "nil")")
            print("🔍 DEBUG: Followers: \(authManager.currentUser?.followerCount ?? 0)")
            print("🔍 DEBUG: Following: \(authManager.currentUser?.followingCount ?? 0)")
            print("🔍 DEBUG: Recipes Created: \(authManager.currentUser?.recipesCreated ?? 0)")
            
            // Only refresh if .task hasn't handled it
            guard hasLoadedInitialData else { 
                print("🔍 DEBUG: Initial load will be handled by .task")
                return 
            }
            
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
        guard !isRefreshing else { 
            print("⚠️ Refresh already in progress, skipping")
            return 
        }
        isRefreshing = true
        defer { isRefreshing = false }
        
        print("🔍 DEBUG: Refreshing social data...")
        
        // Use synchronized method to prevent race conditions
        if authManager.isAuthenticated {
            await authManager.refreshAllSocialData()
            print("✅ DEBUG: Social data refreshed - Followers: \(authManager.currentUser?.followerCount ?? 0), Following: \(authManager.currentUser?.followingCount ?? 0), Recipes Created: \(authManager.currentUser?.recipesCreated ?? 0)")
        }
    }

    private var socialStatsHeader: some View {
        Group {
            if authManager.isAuthenticated {
                // Authenticated user view
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
                                count: authManager.currentUser?.followerCount ?? 0,
                                label: "Followers"
                            )

                            socialStatItem(
                                count: authManager.currentUser?.followingCount ?? 0,
                                label: "Following"
                            )

                            socialStatItem(
                                count: authManager.currentUser?.recipesCreated ?? 0,
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
            } else {
                // Unauthenticated user view - Beautiful login prompt
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#667eea").opacity(0.3), Color(hex: "#764ba2").opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 35))
                            .foregroundColor(.white)
                    }
                    
                    // Welcome message
                    VStack(spacing: 8) {
                        Text("Join Our Community")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Connect with fellow food lovers and share your culinary creations")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Features list
                    VStack(alignment: .leading, spacing: 12) {
                        authFeatureRow(icon: "person.2.fill", text: "Follow your favorite chefs")
                        authFeatureRow(icon: "square.and.arrow.up", text: "Share your recipe creations")
                        authFeatureRow(icon: "trophy.fill", text: "Join cooking challenges")
                        authFeatureRow(icon: "heart.fill", text: "Like and save recipes")
                    }
                    .padding(.vertical, 10)
                    
                    // Sign in button
                    Button(action: {
                        authManager.showAuthSheet = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Sign In to Continue")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: Color(hex: "#667eea").opacity(0.4), radius: 12, y: 6)
                    }
                    
                    // Discover button (still accessible)
                    Button(action: {
                        showingDiscoverUsers = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                            Text("Browse Chefs")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
            }
        }
    }
    
    private func authFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#667eea"))
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
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
