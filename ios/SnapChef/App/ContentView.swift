import SwiftUI
import AVFoundation
import UIKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: UnifiedAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingLaunchAnimation = true

    var body: some View {
        ZStack {
            if showingLaunchAnimation && !reduceMotion {
                LaunchAnimationView {
                    withAnimation(MotionTuning.crispCurve(0.44)) {
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
            if reduceMotion {
                showingLaunchAnimation = false
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Int
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
    @State private var milestoneCelebration: MilestoneCelebration?
    @State private var viralCoachStep: ViralCoachStep?
    @State private var tabLaunchOverlay: TabLaunchOverlayState?
    @State private var tabLaunchDismissTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var authManager: UnifiedAuthManager

    init() {
        _selectedTab = State(initialValue: LaunchRouting.initialTab)
    }

    var body: some View {
        // Single NavigationStack at the root level
        NavigationStack {
            ZStack {
                // Content based on selected tab
                Group {
                    switch AppTab(rawValue: selectedTab) ?? .home {
                    case .home:
                        HomeView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    case .camera:
                        CameraView(selectedTab: $selectedTab)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    case .detective:
                        DetectiveView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    case .recipes:
                        RecipesView(selectedTab: $selectedTab)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    case .socialFeed:
                        SocialFeedView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    case .profile:
                        ProfileView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 1.02))
                            ))
                    }
                }
                .offset(x: tabContentOffset)
                .scaleEffect(isTabTransitioning ? 0.994 : 1.0)

                // Custom morphing tab bar (hide when camera is selected)
                if selectedTab != AppTab.camera.rawValue {
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

                if let milestoneCelebration {
                    MilestoneCelebrationOverlay(
                        milestone: milestoneCelebration.milestone,
                        conversions: milestoneCelebration.conversions,
                        tint: milestoneCelebration.tint,
                        accent: milestoneCelebration.accent
                    )
                    .id(milestoneCelebration.id)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(26)
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

                if let launch = tabLaunchOverlay {
                    StudioTabLaunchOverlay(
                        title: launch.title,
                        icon: launch.icon,
                        tint: launch.color
                    )
                    .id(launch.id)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
                    .zIndex(28)
                    .allowsHitTesting(false)
                }
            }
            .navigationBarHidden(true) // Hide the default navigation bar
            .overlayPreferenceValue(ViralCoachSpotlightAnchorsKey.self) { anchors in
                GeometryReader { proxy in
                    if let step = viralCoachStep {
                        ViralCoachMarksOverlay(
                            step: step,
                            index: step.rawValue + 1,
                            total: ViralCoachStep.allCases.count,
                            spotlightRect: spotlightRect(for: step, anchors: anchors, proxy: proxy),
                            onPrimary: handleViralCoachPrimaryAction,
                            onSkip: skipViralCoach
                        )
                        .id(step.rawValue)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .zIndex(30)
                    }
                }
            }
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
            maybePresentViralCoach(triggeredByShare: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapchefViralMilestoneUnlocked)) { notification in
            let milestone = notification.userInfo?["milestone"] as? Int ?? 0
            let conversions = notification.userInfo?["conversions"] as? Int ?? milestone
            guard milestone > 0 else { return }

            heroMomentCenter.showViralMilestoneUnlocked(
                milestone: milestone,
                conversions: conversions
            )
            playCelebrationBurst(
                tint: Color(hex: "#f6d365"),
                accent: Color(hex: "#fda085"),
                pieceCount: min(74, 38 + milestone),
                spread: 1.12,
                duration: 1.1
            )
            playMilestoneCelebration(milestone: milestone, conversions: conversions)
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
        .onReceive(NotificationCenter.default.publisher(for: .snapchefNavigateToTab)) { notification in
            guard let tabValue = notification.userInfo?["tab"] as? Int,
                  AppTab(rawValue: tabValue) != nil else {
                return
            }
            handleTabSelection(tabValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapchefInviteLinkCopied)) { _ in
            guard viralCoachStep == .feedInvite else { return }
            advanceViralCoachProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapchefInviteCenterOpened)) { _ in
            guard viralCoachStep == .profileTrack else { return }
            advanceViralCoachProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapchefGrowthHubOpened)) { _ in
            guard viralCoachStep == .guardrail else { return }
            completeViralCoach()
        }
        .onAppear {
            maybePresentViralCoach(triggeredByShare: false)
        }
        .onDisappear {
            tabLaunchDismissTask?.cancel()
            tabLaunchDismissTask = nil
            tabLaunchOverlay = nil
        }
    }

    private enum LaunchRouting {
        static var initialTab: Int {
            let args = ProcessInfo.processInfo.arguments
            guard let idx = args.firstIndex(of: "-startTab"), idx + 1 < args.count else {
                return AppTab.home.rawValue
            }

            let value = args[idx + 1].lowercased()
            if let intValue = Int(value), let tab = AppTab(rawValue: intValue) {
                return tab.rawValue
            }

            switch value {
            case "home":
                return AppTab.home.rawValue
            case "camera", "snap":
                return AppTab.camera.rawValue
            case "detective":
                return AppTab.detective.rawValue
            case "recipes":
                return AppTab.recipes.rawValue
            case "feed", "social", "socialfeed":
                return AppTab.socialFeed.rawValue
            case "profile":
                return AppTab.profile.rawValue
            default:
                return AppTab.home.rawValue
            }
        }
    }
    
    // Handle tab selection with camera permission and recipe limit checking
    private func handleTabSelection(_ newTab: Int) {
        guard let targetTab = AppTab(rawValue: newTab) else { return }

        if targetTab == .camera {
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
                        performTabTransition(to: targetTab)
                    }
                }
                // If permission denied, stay on current tab
            }
        } else if targetTab.requiresCameraPermission {
            // Detective and any future camera-required tabs
            Task {
                let granted = await requestCameraPermission()
                if granted {
                    await MainActor.run {
                        performTabTransition(to: targetTab)
                    }
                }
            }
        } else {
            // For non-camera tabs, switch immediately
            performTabTransition(to: targetTab)
        }
    }

    private func performTabTransition(to targetTab: AppTab) {
        guard !reduceMotion else {
            animateToTab(targetTab.rawValue)
            return
        }

        if targetTab == .camera || targetTab == .detective {
            showTabLaunchOverlay(for: targetTab)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(0.22))
                animateToTab(targetTab.rawValue)
            }
        } else {
            animateToTab(targetTab.rawValue)
        }
    }

    private func showTabLaunchOverlay(for targetTab: AppTab) {
        let title: String
        switch targetTab {
        case .camera:
            title = "Snap Mode"
        case .detective:
            title = "Detective Mode"
        default:
            title = targetTab.momentTitle
        }

        let launch = TabLaunchOverlayState(
            title: title,
            icon: targetTab.momentIcon,
            color: targetTab.momentColor
        )

        tabLaunchDismissTask?.cancel()
        withAnimation(MotionTuning.settleSpring(response: 0.36, damping: 0.82)) {
            tabLaunchOverlay = launch
        }

        tabLaunchDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(0.52))
            guard !Task.isCancelled else { return }
            guard tabLaunchOverlay?.id == launch.id else { return }
            withAnimation(MotionTuning.softExit(0.2)) {
                tabLaunchOverlay = nil
            }
        }
    }

    private func animateToTab(_ newTab: Int) {
        guard newTab != selectedTab else { return }

        if reduceMotion {
            selectedTab = newTab
            tabContentOffset = 0
            tabFlashOpacity = 0
            isTabTransitioning = false
            return
        }

        let previousTab = selectedTab
        let details = tabMomentDetails(for: newTab)
        triggerTabHaptic(for: newTab)
        tabTransitionDirection = newTab > previousTab ? 1 : -1
        tabFlashColor = details.color
        isTabTransitioning = true

        withAnimation(MotionTuning.crispCurve(0.1)) {
            tabContentOffset = -20 * tabTransitionDirection
            tabFlashOpacity = 0.24
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(0.1)) {
            selectedTab = newTab
            tabContentOffset = 24 * tabTransitionDirection

            withAnimation(MotionTuning.settleSpring(response: 0.34, damping: 0.87)) {
                tabContentOffset = 0
                tabFlashOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(0.2)) {
                isTabTransitioning = false
            }
        }

        triggerTabMoment(for: newTab)
    }

    private func triggerTabHaptic(for tab: Int) {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()

        // Give key creation flows a richer tap response.
        if tab == AppTab.camera.rawValue || tab == AppTab.detective.rawValue {
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred(intensity: 0.8)
        }
    }

    private func triggerTabMoment(for tab: Int) {
        guard !reduceMotion else {
            showTabMoment = false
            return
        }

        let details = tabMomentDetails(for: tab)
        tabMomentLabel = details.title
        tabMomentIcon = details.icon
        tabMomentColor = details.color

        withAnimation(MotionTuning.settleSpring(response: 0.46, damping: 0.8)) {
            showTabMoment = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(0.9)) {
            withAnimation(MotionTuning.softExit(0.24)) {
                showTabMoment = false
            }
        }
    }

    private func tabMomentDetails(for tab: Int) -> (title: String, icon: String, color: Color) {
        guard let targetTab = AppTab(rawValue: tab) else {
            return ("SnapChef", "sparkles", .white)
        }
        return (targetTab.momentTitle, targetTab.momentIcon, targetTab.momentColor)
    }

    private func handleNotificationTap(_ userInfo: [AnyHashable: Any]?) {
        guard let categoryIdentifier = userInfo?["categoryIdentifier"] as? String else {
            animateToTab(AppTab.home.rawValue)
            return
        }

        switch categoryIdentifier {
        case NotificationCategory.streakReminder.rawValue:
            handleTabSelection(AppTab.camera.rawValue)
        case NotificationCategory.challengeReminder.rawValue,
             NotificationCategory.newChallenge.rawValue,
             NotificationCategory.teamChallenge.rawValue,
             NotificationCategory.leaderboardUpdate.rawValue:
            animateToTab(AppTab.home.rawValue)
        default:
            animateToTab(AppTab.home.rawValue)
        }
    }

    private func playCelebrationBurst(
        tint: Color,
        accent: Color,
        pieceCount: Int,
        spread: CGFloat,
        duration: Double
    ) {
        guard !reduceMotion else {
            celebrationBurst = nil
            return
        }

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
                withAnimation(MotionTuning.softExit(0.18)) {
                    celebrationBurst = nil
                }
            }
        }
    }

    private func playMilestoneCelebration(milestone: Int, conversions: Int) {
        guard !reduceMotion else { return }

        let celebration = MilestoneCelebration(
            milestone: milestone,
            conversions: conversions,
            tint: Color(hex: "#f6d365"),
            accent: Color(hex: "#fda085"),
            duration: 1.7
        )
        milestoneCelebration = celebration

        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(celebration.duration)) {
            guard milestoneCelebration?.id == celebration.id else { return }
            withAnimation(MotionTuning.softExit(0.22)) {
                milestoneCelebration = nil
            }
        }
    }

    private func maybePresentViralCoach(triggeredByShare: Bool) {
        guard viralCoachStep == nil else { return }

        let hasMomentum = ShareMomentumStore.latest(maxAge: 60 * 60 * 12) != nil
        guard ViralCoachMarksProgress.shouldPresent(hasMomentum: hasMomentum) else { return }

        let show = {
            if reduceMotion {
                viralCoachStep = .feedInvite
            } else {
                withAnimation(MotionTuning.settleSpring(response: 0.45, damping: 0.82)) {
                    viralCoachStep = .feedInvite
                }
            }
        }

        if triggeredByShare {
            show()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + MotionTuning.seconds(1.05)) {
                guard viralCoachStep == nil else { return }
                show()
            }
        }
    }

    private func handleViralCoachPrimaryAction() {
        guard let step = viralCoachStep else { return }

        if let targetTab = step.targetTab {
            animateToTab(targetTab.rawValue)
        }
    }

    private func advanceViralCoachProgress() {
        guard let current = viralCoachStep else { return }
        guard let next = ViralCoachStep(rawValue: current.rawValue + 1) else {
            completeViralCoach()
            return
        }

        if reduceMotion {
            viralCoachStep = next
        } else {
            withAnimation(MotionTuning.crispCurve(0.22)) {
                viralCoachStep = next
            }
        }
    }

    private func skipViralCoach() {
        completeViralCoach()
    }

    private func completeViralCoach() {
        ViralCoachMarksProgress.markCompleted()
        if reduceMotion {
            viralCoachStep = nil
        } else {
            withAnimation(MotionTuning.softExit(0.18)) {
                viralCoachStep = nil
            }
        }
    }

    private func spotlightRect(
        for step: ViralCoachStep,
        anchors: [ViralCoachSpotlightTarget: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> CGRect? {
        guard let target = spotlightTarget(for: step) else { return nil }
        guard let anchor = anchors[target] else { return nil }
        return proxy[anchor]
    }

    private func spotlightTarget(for step: ViralCoachStep) -> ViralCoachSpotlightTarget? {
        switch step {
        case .feedInvite:
            return selectedTab == AppTab.socialFeed.rawValue ? .feedCopyInvite : .tab(.socialFeed)
        case .profileTrack:
            return selectedTab == AppTab.profile.rawValue ? .profileInviteCenter : .tab(.profile)
        case .guardrail:
            return selectedTab == AppTab.profile.rawValue ? .profileGrowthHub : .tab(.profile)
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

private struct TabLaunchOverlayState: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}

private struct StudioTabLaunchOverlay: View {
    let title: String
    let icon: String
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: CGFloat = 0

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [tint.opacity(0.42), Color.black.opacity(0.7), Color.clear],
                center: .center,
                startRadius: 22,
                endRadius: 360
            )
            .ignoresSafeArea()
            .opacity(Double(reveal))
            .blendMode(.screen)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.95), tint.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: tint.opacity(0.45), radius: 24, y: 8)

                    Circle()
                        .stroke(Color.white.opacity(0.42), lineWidth: 2)
                        .frame(width: 122, height: 122)
                        .scaleEffect(0.9 + (0.18 * reveal))
                        .opacity(Double(1 - min(reveal, 1)))

                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(0.85 + (0.15 * reveal))
                }

                Text(title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(Double(reveal))
            }
            .padding(.bottom, 58)
            .scaleEffect(0.9 + (0.1 * reveal))
        }
        .onAppear {
            if reduceMotion {
                reveal = 1
                return
            }
            withAnimation(MotionTuning.settleSpring(response: 0.38, damping: 0.8)) {
                reveal = 1
            }
        }
    }
}

private struct MilestoneCelebration: Identifiable {
    let id = UUID()
    let milestone: Int
    let conversions: Int
    let tint: Color
    let accent: Color
    let duration: Double
}

private struct MilestoneCelebrationOverlay: View {
    let milestone: Int
    let conversions: Int
    let tint: Color
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black
                .opacity(0.45 * Double(progress))
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    tint.opacity(0.75),
                    accent.opacity(0.55),
                    .clear
                ],
                center: .center,
                startRadius: 16,
                endRadius: 360
            )
            .ignoresSafeArea()
            .opacity(Double(progress))
            .blendMode(.screen)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.92), accent.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 144, height: 144)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: tint.opacity(0.38), radius: 24, y: 10)

                    Circle()
                        .stroke(Color.white.opacity(0.45), lineWidth: 2)
                        .frame(width: 170, height: 170)
                        .scaleEffect(0.88 + 0.2 * progress)
                        .opacity(Double(1 - min(progress, 1)))

                    VStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.95))
                        Text("\(milestone)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                }

                Text("Milestone Unlocked")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(conversions) total conversions in your invite loop")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .padding(.horizontal, 30)
            .scaleEffect(0.88 + 0.12 * progress)
            .opacity(Double(progress))
        }
        .onAppear {
            if reduceMotion {
                progress = 1
                return
            }
            withAnimation(MotionTuning.settleSpring(response: 0.52, damping: 0.82)) {
                progress = 1
            }
        }
    }
}

private enum ViralCoachStep: Int, CaseIterable {
    case feedInvite
    case profileTrack
    case guardrail

    var title: String {
        switch self {
        case .feedInvite:
            return "Step 1: Multiply This Share"
        case .profileTrack:
            return "Step 2: Track Conversion Lift"
        case .guardrail:
            return "Step 3: Keep Push Premium"
        }
    }

    var subtitle: String {
        switch self {
        case .feedInvite:
            return "Open Feed, tap Copy Invite, and drop your link into one active channel."
        case .profileTrack:
            return "Go to Profile and open Invite Center to track conversions and coin yield."
        case .guardrail:
            return "Open Growth Hub from Profile to audit monthly push guardrails and retention controls."
        }
    }

    var icon: String {
        switch self {
        case .feedInvite:
            return "paperplane.fill"
        case .profileTrack:
            return "person.2.wave.2.fill"
        case .guardrail:
            return "bell.badge.fill"
        }
    }

    var tint: Color {
        switch self {
        case .feedInvite:
            return Color(hex: "#4facfe")
        case .profileTrack:
            return Color(hex: "#43e97b")
        case .guardrail:
            return Color(hex: "#f6d365")
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .feedInvite:
            return "Open Feed"
        case .profileTrack:
            return "Open Profile"
        case .guardrail:
            return "Go To Profile"
        }
    }

    var autoAdvanceHint: String? {
        switch self {
        case .feedInvite:
            return "Auto-advances when you tap Copy Invite."
        case .profileTrack:
            return "Auto-advances when you open Invite Center."
        case .guardrail:
            return "Auto-completes when you open Growth Hub."
        }
    }

    var targetTab: AppTab? {
        switch self {
        case .feedInvite:
            return .socialFeed
        case .profileTrack:
            return .profile
        case .guardrail:
            return nil
        }
    }
}

private struct ViralCoachMarksOverlay: View {
    let step: ViralCoachStep
    let index: Int
    let total: Int
    let spotlightRect: CGRect?
    let onPrimary: () -> Void
    let onSkip: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                backdropLayer(in: proxy.size)

                if let spotlight = expandedSpotlightRect(in: proxy.size) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(step.tint.opacity(0.98), lineWidth: 2)
                        .frame(width: spotlight.width, height: spotlight.height)
                        .position(x: spotlight.midX, y: spotlight.midY)
                        .shadow(color: step.tint.opacity(0.58), radius: 18, y: 0)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.62), lineWidth: 1)
                        .frame(width: spotlight.width + 10, height: spotlight.height + 10)
                        .position(x: spotlight.midX, y: spotlight.midY)
                        .opacity(0.92)
                }

                VStack {
                    Spacer()

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(step.tint.opacity(0.24))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: step.icon)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(step.tint)
                                    )

                                Text(step.title)
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Button("Skip") {
                                onSkip()
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                        }

                        Text(step.subtitle)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineSpacing(2)

                        HStack(spacing: 6) {
                            ForEach(0..<total, id: \.self) { marker in
                                Capsule(style: .continuous)
                                    .fill(marker == index - 1 ? step.tint : Color.white.opacity(0.24))
                                    .frame(width: marker == index - 1 ? 22 : 8, height: 6)
                            }
                        }

                        Button(action: onPrimary) {
                            Text(step.primaryButtonTitle)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [step.tint.opacity(0.95), step.tint.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                        }
                        .buttonStyle(.plain)

                        if let hint = step.autoAdvanceHint {
                            Text(hint)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.66))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func expandedSpotlightRect(in size: CGSize) -> CGRect? {
        guard let base = spotlightRect else { return nil }
        let expanded = base.insetBy(dx: -12, dy: -8)
        let minX = max(8, expanded.minX)
        let minY = max(8, expanded.minY)
        let maxX = min(size.width - 8, expanded.maxX)
        let maxY = min(size.height - 8, expanded.maxY)
        guard maxX > minX, maxY > minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    @ViewBuilder
    private func backdropLayer(in size: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.52)
            if let spotlight = expandedSpotlightRect(in: size) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .frame(width: spotlight.width, height: spotlight.height)
                    .position(x: spotlight.midX, y: spotlight.midY)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
        .ignoresSafeArea()
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

    func showViralMilestoneUnlocked(milestone: Int, conversions: Int) {
        let conversionNoun = conversions == 1 ? "conversion" : "conversions"
        show(
            key: "viral_milestone_\(milestone)",
            title: "Milestone Unlocked",
            subtitle: "\(milestone) reached • \(conversions) \(conversionNoun)",
            icon: "bolt.badge.checkmark.fill",
            tint: Color(hex: "#f6d365")
        )
    }

    private func show(key: String, title: String, subtitle: String, icon: String, tint: Color) {
        let now = Date()
        if let last = cooldowns[key], now.timeIntervalSince(last) < 1.2 {
            return
        }
        cooldowns[key] = now

        withAnimation(MotionTuning.settleSpring(response: 0.42, damping: 0.82)) {
            currentMoment = HeroMoment(
                title: title,
                subtitle: subtitle,
                icon: icon,
                tint: tint
            )
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: MotionTuning.nanoseconds(1.9))
            withAnimation(MotionTuning.softExit(0.24)) {
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
    static let snapchefNavigateToTab = Notification.Name("snapchef_navigate_to_tab")
    static let snapchefViralMilestoneUnlocked = Notification.Name("snapchef_viral_milestone_unlocked")
    static let snapchefInviteLinkCopied = Notification.Name("snapchef_invite_link_copied")
    static let snapchefInviteCenterOpened = Notification.Name("snapchef_invite_center_opened")
    static let snapchefGrowthHubOpened = Notification.Name("snapchef_growth_hub_opened")
}

// MARK: - Social Feed View
struct SocialFeedView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: UnifiedAuthManager
    @State private var showingDiscoverUsers = false
    @State private var isRefreshing = false
    @State private var hasLoadedInitialData = false
    @State private var inviteSnapshot: SocialShareManager.InviteCenterSnapshot?
    @State private var isLoadingInviteSnapshot = false
    @State private var copiedInviteLink = false
    @State private var showingGrowthHub = false

    private var shareMomentumSnapshot: ShareMomentumSnapshot? {
        ShareMomentumStore.latest(maxAge: 60 * 60 * 12)
    }

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
                    .padding(.bottom, shareMomentumSnapshot == nil ? 16 : 10)

                    if shareMomentumSnapshot != nil {
                        momentumPanel
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .move(edge: .top).combined(with: .opacity)
                            )
                    }

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
        .sheet(isPresented: $showingGrowthHub) {
            GrowthHubView()
        }
        .task {
            await refreshInviteSnapshot(force: false)
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
        .onReceive(NotificationCenter.default.publisher(for: .snapchefShareCompleted)) { _ in
            Task {
                await refreshInviteSnapshot(force: true)
            }
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

    @ViewBuilder
    private var momentumPanel: some View {
        if let momentum = shareMomentumSnapshot {
            let snapshot = inviteSnapshot
            let goal = ViralFunnelProgress(conversions: snapshot?.totalConversions ?? 0)
            StudioMomentumCardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Momentum live on \(formattedPlatform(momentum.platform))")
                                .font(StudioMomentumTypography.title)
                                .foregroundColor(.white)
                            Text("Turn this share into new followers and coin rewards.")
                                .font(StudioMomentumTypography.subtitle)
                                .foregroundColor(.white.opacity(0.82))
                        }
                        Spacer()
                        if isLoadingInviteSnapshot {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.85)
                        }
                    }

                    HStack(spacing: 10) {
                        momentumStatPill(value: "\(snapshot?.totalConversions ?? 0)", label: "Conversions")
                        momentumStatPill(value: "\(snapshot?.pendingCoins ?? 0)", label: "Pending Coins")
                        momentumStatPill(value: "\(snapshot?.earnedCoins ?? 0)", label: "Earned Coins")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(goal.goalTitle)
                                .font(StudioMomentumTypography.goalTitle)
                                .foregroundColor(.white.opacity(0.86))
                            Spacer()
                            if let next = goal.nextMilestone {
                                Text("\(goal.conversionsToNext) to \(next)")
                                    .font(StudioMomentumTypography.goalMono)
                                    .foregroundColor(.white.opacity(0.7))
                            } else {
                                Text("Maxed")
                                    .font(StudioMomentumTypography.goalTitle)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        ProgressView(value: goal.progressToNext, total: 1)
                            .progressViewStyle(.linear)
                            .tint(.white.opacity(0.95))
                            .scaleEffect(x: 1, y: 1.12, anchor: .center)
                        Text(goal.goalSubtitle)
                            .font(StudioMomentumTypography.goalBody)
                            .foregroundColor(.white.opacity(0.78))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 10) {
                        Button(action: copyInviteLink) {
                            HStack(spacing: 8) {
                                Image(systemName: copiedInviteLink ? "checkmark.circle.fill" : "link")
                                    .font(.system(size: 13, weight: .bold))
                                Text(copiedInviteLink ? "Copied" : "Copy Invite")
                                    .font(StudioMomentumTypography.action)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(StudioMomentumVisual.chipOpacity))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .viralCoachSpotlightAnchor(.feedCopyInvite)

                        Button(action: {
                            NotificationCenter.default.post(name: .snapchefGrowthHubOpened, object: nil)
                            showingGrowthHub = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Growth Hub")
                                    .font(StudioMomentumTypography.action)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.24))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
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

    private func refreshInviteSnapshot(force: Bool) async {
        guard !isLoadingInviteSnapshot else { return }
        if inviteSnapshot != nil && !force { return }

        isLoadingInviteSnapshot = true
        let snapshot = await SocialShareManager.shared.fetchInviteCenterSnapshot()
        if reduceMotion {
            inviteSnapshot = snapshot
        } else {
            withAnimation(MotionTuning.crispCurve(0.22)) {
                inviteSnapshot = snapshot
            }
        }
        isLoadingInviteSnapshot = false

        if let unlocked = ViralMilestoneTracker.unlockedMilestone(for: snapshot.totalConversions) {
            NotificationCenter.default.post(
                name: .snapchefViralMilestoneUnlocked,
                object: nil,
                userInfo: [
                    "milestone": unlocked,
                    "conversions": snapshot.totalConversions
                ]
            )
        }
    }

    private func copyInviteLink() {
        UIPasteboard.general.string = SocialShareManager.shared.referralInviteURL().absoluteString
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        NotificationCenter.default.post(name: .snapchefInviteLinkCopied, object: nil)
        copiedInviteLink = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedInviteLink = false
        }
    }

    private func formattedPlatform(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Social" }
        if trimmed.lowercased() == "tiktok" { return "TikTok" }
        if trimmed.lowercased() == "whatsapp" { return "WhatsApp" }
        if trimmed.lowercased() == "instagramstory" { return "Instagram Story" }
        return trimmed.capitalized
    }

    private func momentumStatPill(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(StudioMomentumTypography.statValue)
                .foregroundColor(.white)
                .monospacedDigit()
            Text(label)
                .font(StudioMomentumTypography.statLabel)
                .foregroundColor(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(StudioMomentumVisual.chipOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
