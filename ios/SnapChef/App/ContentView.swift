import SwiftUI
import AVFoundation
import UIKit

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
    @State private var showingCameraPermissionAlert = false
    @State private var showPremiumPrompt = false
    @State private var premiumPromptReason: PremiumUpgradePrompt.UpgradeReason = .dailyLimitReached
    @State private var showTabMoment = false
    @State private var tabMomentLabel = ""
    @State private var tabMomentIcon = "sparkles"
    @State private var tabMomentColor: Color = .white
    @State private var tabContentOffset: CGFloat = 0
    @State private var tabTransitionDirection: CGFloat = 1
    @State private var tabFlashOpacity: Double = 0
    @State private var tabFlashColor: Color = .white
    @State private var isTabTransitioning = false
    @StateObject private var heroMomentCenter = HeroMomentCenter.shared
    @State private var celebrationBurst: CelebrationBurst?
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
                .offset(x: tabContentOffset)
                .scaleEffect(isTabTransitioning ? 0.994 : 1.0)

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

                if showTabMoment {
                    VStack {
                        KeyMomentChip(
                            title: tabMomentLabel,
                            icon: tabMomentIcon,
                            color: tabMomentColor
                        )
                        .padding(.top, 16)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
                }

                if let moment = heroMomentCenter.currentMoment {
                    VStack {
                        HeroMomentBanner(moment: moment)
                            .padding(.top, 12)
                        Spacer()
                    }
                    .id(moment.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(25)
                    .allowsHitTesting(false)
                }

                if let burst = celebrationBurst {
                    CelebrationConfettiOverlay(
                        tint: burst.tint,
                        accent: burst.accent,
                        pieceCount: burst.pieceCount,
                        spread: burst.spread,
                        duration: burst.duration
                    )
                    .id(burst.id)
                    .transition(.opacity)
                    .zIndex(24)
                    .allowsHitTesting(false)
                }

                if tabFlashOpacity > 0.001 {
                    LinearGradient(
                        colors: [
                            .clear,
                            tabFlashColor.opacity(0.5),
                            .clear
                        ],
                        startPoint: tabTransitionDirection > 0 ? .leading : .trailing,
                        endPoint: tabTransitionDirection > 0 ? .trailing : .leading
                    )
                    .ignoresSafeArea()
                    .blendMode(.screen)
                    .opacity(tabFlashOpacity)
                    .allowsHitTesting(false)
                    .zIndex(10)
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
        .onReceive(NotificationCenter.default.publisher(for: .snapchefNotificationTapped)) { notification in
            handleNotificationTap(notification.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapchefRecipeGenerated)) { notification in
            let count = notification.userInfo?["count"] as? Int ?? 1
            heroMomentCenter.showRecipeGenerated(count: max(1, count))
            playCelebrationBurst(
                tint: Color(hex: "#43e97b"),
                accent: Color(hex: "#38f9d7"),
                pieceCount: count >= 3 ? 44 : 34,
                spread: count >= 3 ? 1.0 : 0.86,
                duration: count >= 3 ? 1.0 : 0.86
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapchefShareCompleted)) { notification in
            let platform = (notification.userInfo?["platform"] as? String) ?? "Share"
            heroMomentCenter.showShareCompleted(platform: platform)
            playCelebrationBurst(
                tint: Color(hex: "#4facfe"),
                accent: Color(hex: "#00f2fe"),
                pieceCount: 40,
                spread: 0.95,
                duration: 0.92
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ChallengeCompleted"))) { notification in
            let title = notification.userInfo?["title"] as? String
            let points = notification.userInfo?["points"] as? Int
            heroMomentCenter.showChallengeCompleted(title: title, points: points)
            playCelebrationBurst(
                tint: Color(hex: "#f6d365"),
                accent: Color(hex: "#fda085"),
                pieceCount: 52,
                spread: 1.05,
                duration: 1.08
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
                        animateToTab(newTab)
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
                        animateToTab(newTab)
                    }
                }
            }
        } else {
            // For non-camera tabs, switch immediately
            animateToTab(newTab)
        }
    }

    private func animateToTab(_ newTab: Int) {
        guard newTab != selectedTab else { return }

        let previousTab = selectedTab
        let details = tabMomentDetails(for: newTab)
        triggerTabHaptic(for: newTab)
        tabTransitionDirection = newTab > previousTab ? 1 : -1
        tabFlashColor = details.color
        isTabTransitioning = true

        withAnimation(.easeOut(duration: MotionTuning.seconds(0.11))) {
            tabContentOffset = -20 * tabTransitionDirection
            tabFlashOpacity = 0.24
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(0.11)) {
            selectedTab = newTab
            tabContentOffset = 24 * tabTransitionDirection

            withAnimation(.spring(response: MotionTuning.seconds(0.38), dampingFraction: 0.84)) {
                tabContentOffset = 0
                tabFlashOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(0.24)) {
                isTabTransitioning = false
            }
        }

        triggerTabMoment(for: newTab)
    }

    private func triggerTabHaptic(for tab: Int) {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()

        // Give key creation flows a richer tap response.
        if tab == 1 || tab == 2 {
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred(intensity: 0.8)
        }
    }

    private func triggerTabMoment(for tab: Int) {
        let details = tabMomentDetails(for: tab)
        tabMomentLabel = details.title
        tabMomentIcon = details.icon
        tabMomentColor = details.color

        withAnimation(.spring(response: MotionTuning.seconds(0.5), dampingFraction: 0.78)) {
            showTabMoment = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(1.0)) {
            withAnimation(.easeOut(duration: MotionTuning.seconds(0.3))) {
                showTabMoment = false
            }
        }
    }

    private func tabMomentDetails(for tab: Int) -> (title: String, icon: String, color: Color) {
        switch tab {
        case 0: return ("Home", "house.fill", Color(hex: "#4facfe"))
        case 1: return ("Snap Time", "camera.fill", Color(hex: "#f093fb"))
        case 2: return ("Detective Mode", "magnifyingglass", Color(hex: "#43e97b"))
        case 3: return ("Recipes", "book.fill", Color(hex: "#f6d365"))
        case 4: return ("Social Feed", "heart.text.square.fill", Color(hex: "#f77062"))
        case 5: return ("Profile", "person.fill", Color(hex: "#84fab0"))
        default: return ("SnapChef", "sparkles", .white)
        }
    }

    private func handleNotificationTap(_ userInfo: [AnyHashable: Any]?) {
        guard let categoryIdentifier = userInfo?["categoryIdentifier"] as? String else {
            animateToTab(0)
            return
        }

        switch categoryIdentifier {
        case NotificationCategory.streakReminder.rawValue:
            handleTabSelection(1)
        case NotificationCategory.challengeReminder.rawValue,
             NotificationCategory.newChallenge.rawValue,
             NotificationCategory.teamChallenge.rawValue,
             NotificationCategory.leaderboardUpdate.rawValue:
            animateToTab(0)
        default:
            animateToTab(0)
        }
    }

    private func playCelebrationBurst(
        tint: Color,
        accent: Color,
        pieceCount: Int,
        spread: CGFloat,
        duration: Double
    ) {
        let burst = CelebrationBurst(
            tint: tint,
            accent: accent,
            pieceCount: pieceCount,
            spread: spread,
            duration: duration
        )
        celebrationBurst = burst
        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(duration + 0.18)) {
            if celebrationBurst?.id == burst.id {
                withAnimation(.easeOut(duration: MotionTuning.seconds(0.18))) {
                    celebrationBurst = nil
                }
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

private struct KeyMomentChip: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.95), color.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.35), radius: 18, y: 8)
    }
}

private struct CelebrationBurst: Identifiable {
    let id = UUID()
    let tint: Color
    let accent: Color
    let pieceCount: Int
    let spread: CGFloat
    let duration: Double
}

private struct CelebrationConfettiOverlay: View {
    let tint: Color
    let accent: Color
    let pieceCount: Int
    let spread: CGFloat
    let duration: Double

    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<pieceCount, id: \.self) { index in
                    let spec = specForPiece(index)
                    RoundedRectangle(cornerRadius: 2.6, style: .continuous)
                        .fill(spec.color)
                        .frame(width: spec.width, height: spec.height)
                        .rotationEffect(.degrees(spec.baseRotation + spec.spin * Double(progress)))
                        .offset(
                            x: spec.horizontal * spread * progress,
                            y: spec.rise * progress + spec.fall * progress * progress
                        )
                        .opacity(max(0, 1 - Double(progress * 1.06)))
                }
            }
            .position(x: proxy.size.width / 2, y: 96)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            withAnimation(.timingCurve(0.14, 0.74, 0.22, 1, duration: MotionTuning.seconds(duration))) {
                progress = 1
            }
        }
    }

    private func specForPiece(_ index: Int) -> (horizontal: CGFloat, rise: CGFloat, fall: CGFloat, width: CGFloat, height: CGFloat, baseRotation: Double, spin: Double, color: Color) {
        let count = max(pieceCount, 1)
        let baseAngle = (Double(index) / Double(count)) * 2 * .pi + Double((index % 7) - 3) * 0.08
        let horizontal = CGFloat(cos(baseAngle)) * CGFloat(88 + ((index * 17) % 76))
        let rise = -CGFloat(90 + ((index * 13) % 80))
        let fall = CGFloat(165 + ((index * 19) % 110))
        let width = CGFloat(4 + (index % 3))
        let height = CGFloat(8 + ((index * 5) % 6))
        let baseRotation = Double((index * 27) % 360)
        let spin = Double(240 + (index % 5) * 70)

        let color: Color = switch index % 4 {
        case 0: tint
        case 1: accent
        case 2: .white.opacity(0.95)
        default: tint.opacity(0.7)
        }

        return (horizontal, rise, fall, width, height, baseRotation, spin, color)
    }
}

private struct HeroMoment: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
}

@MainActor
private final class HeroMomentCenter: ObservableObject {
    static let shared = HeroMomentCenter()

    @Published var currentMoment: HeroMoment?
    private var cooldowns: [String: Date] = [:]

    private init() {}

    func showRecipeGenerated(count: Int) {
        let noun = count == 1 ? "recipe" : "recipes"
        show(
            key: "recipe_generated",
            title: "Fresh Results Ready",
            subtitle: "\(count) \(noun) created from your ingredients",
            icon: "wand.and.stars.inverse",
            tint: Color(hex: "#43e97b")
        )
    }

    func showChallengeCompleted(title: String?, points: Int?) {
        let titleText = title ?? "Challenge complete"
        let pointText = points.map { "\($0) pts locked in" } ?? "Momentum boosted"
        show(
            key: "challenge_completed",
            title: "Challenge Complete",
            subtitle: "\(titleText) • \(pointText)",
            icon: "trophy.fill",
            tint: Color(hex: "#f6d365")
        )
    }

    func showShareCompleted(platform: String) {
        show(
            key: "share_completed",
            title: "Shared to \(platform)",
            subtitle: "New viewers are now entering your growth loop",
            icon: "paperplane.fill",
            tint: Color(hex: "#4facfe")
        )
    }

    private func show(key: String, title: String, subtitle: String, icon: String, tint: Color) {
        let now = Date()
        if let last = cooldowns[key], now.timeIntervalSince(last) < 1.2 {
            return
        }
        cooldowns[key] = now

        withAnimation(.spring(response: MotionTuning.seconds(0.42), dampingFraction: 0.82)) {
            currentMoment = HeroMoment(
                title: title,
                subtitle: subtitle,
                icon: icon,
                tint: tint
            )
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(1.9))
            withAnimation(.easeOut(duration: MotionTuning.seconds(0.26))) {
                currentMoment = nil
            }
        }
    }
}

private struct HeroMomentBanner: View {
    let moment: HeroMoment

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(moment.tint.opacity(0.24))
                    .frame(width: 36, height: 36)
                Image(systemName: moment.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(moment.title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(moment.subtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [moment.tint.opacity(0.9), moment.tint.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        )
        .padding(.horizontal, 18)
        .shadow(color: moment.tint.opacity(0.35), radius: 18, y: 8)
    }
}

extension Notification.Name {
    static let snapchefRecipeGenerated = Notification.Name("snapchef_recipe_generated")
    static let snapchefShareCompleted = Notification.Name("snapchef_share_completed")
}

// MARK: - Social Feed View
struct SocialFeedView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: UnifiedAuthManager
    @State private var showingDiscoverUsers = false
    @State private var isRefreshing = false
    @State private var hasLoadedInitialData = false

    var body: some View {
        return NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Social Stats Header
                    Group { socialStatsHeader }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                    // Activity Feed Content
                    Group { ActivityFeedView().environmentObject(appState) }
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
                return 
            }
            hasLoadedInitialData = true // Set immediately to prevent double-load
            await authManager.refreshAllSocialData()
        }
        .onAppear {
            // Only refresh if .task hasn't handled it
            guard hasLoadedInitialData else { 
                return 
            }
            
            // Force refresh if data looks stale
            if authManager.isAuthenticated && authManager.currentUser != nil {
                let needsRefresh = (authManager.currentUser?.followerCount ?? 0) == 0 &&
                                  (authManager.currentUser?.followingCount ?? 0) == 0 &&
                                  (authManager.currentUser?.recipesCreated ?? 0) == 0
                
                if needsRefresh && !isRefreshing {
                    Task {
                        await refreshSocialData()
                    }
                }
            }
        }
    }

    private func refreshSocialData() async {
        guard !isRefreshing else { 
            return 
        }
        isRefreshing = true
        defer { isRefreshing = false }

        // Use synchronized method to prevent race conditions
        if authManager.isAuthenticated {
            await authManager.refreshAllSocialData()
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
