import SwiftUI

struct AIProcessingView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false
    @State private var textOpacity = 0.0
    @State private var sparkleScale: CGFloat = 1.0
    @State private var buttonShake: CGFloat = 0
    @State private var buttonShakeTimer: Timer?
    @State private var autoAdvanceTask: Task<Void, Never>?
    @State private var didLaunchGame = false
    @State private var backendProgress = CameraProcessingPhase.idle.progressFraction
    @State private var ambientShift = false
    @State private var tipIndex = 0
    @State private var tipPulse = false
    @State private var tipTimer: Timer?
    @State private var statusBadgePulse = false
    @State private var completionBurst = false
    @State private var completionBurstScale: CGFloat = 0.85
    @State private var lastMilestonePhase: CameraProcessingPhase = .idle
    @State private var statusResetTask: Task<Void, Never>?

    // Photo properties
    let fridgeImage: UIImage?
    let pantryImage: UIImage?
    let processingMilestone: CameraProcessingMilestone

    // Callbacks
    var onPlayGameTapped: (() -> Void)?
    var onAutoPlayGameTapped: (() -> Void)?
    var onClose: (() -> Void)?

    // Computed property to determine if we have both photos
    private var hasBothPhotos: Bool {
        fridgeImage != nil && pantryImage != nil
    }

    private let waitingTips = [
        "Tap fast streaks in the mini-game to multiply score.",
        "Share your best recipe card to bring friends into SnapChef.",
        "Mix fridge + pantry photos for better recipe variety.",
        "Quick wins go viral: before/after photos beat plain screenshots."
    ]

    private var statusAccentColor: Color {
        switch processingMilestone.phase {
        case .completed:
            return Color(hex: "#4ade80")
        case .failed:
            return Color(hex: "#fb7185")
        case .waitingForRecipes:
            return Color(hex: "#f093fb")
        case .uploadingPhotos:
            return Color(hex: "#60a5fa")
        default:
            return Color.white
        }
    }

    private var canLaunchWaitingGame: Bool {
        switch processingMilestone.phase {
        case .completed, .failed, .decodingResponse, .finalizingResults:
            return false
        default:
            return true
        }
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(hex: "#06080f"),
                    Color(hex: "#141b34"),
                    Color(hex: "#27123b")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#38f9d7").opacity(0.35), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 200
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 14)
                .offset(x: ambientShift ? -120 : -40, y: ambientShift ? -280 : -220)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#f093fb").opacity(0.28), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 240
                    )
                )
                .frame(width: 360, height: 360)
                .blur(radius: 18)
                .offset(x: ambientShift ? 140 : 90, y: ambientShift ? 220 : 150)

            Circle()
                .stroke(
                    statusAccentColor.opacity(completionBurst ? 0.72 : 0.0),
                    lineWidth: completionBurst ? 4 : 0
                )
                .frame(width: 260, height: 260)
                .scaleEffect(completionBurstScale)
                .blur(radius: completionBurst ? 1.5 : 0)

            // Close button at top left
            VStack {
                HStack {
                    if let onClose = onClose {
                        Button(action: onClose) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .accessibilityLabel("Close recipe generation")
                        .accessibilityHint("Stops processing and returns to the previous screen")
                        .padding(.leading, 20)
                        .padding(.top, 60)
                    }
                    Spacer()
                }
                Spacer()
            }
            
            VStack(spacing: 40) {
                Spacer()

                // Animated AI Icon
                ZStack {
                    // Conditional glow effect based on performance
                    if deviceManager.shouldUseHeavyEffects {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: "#667eea").opacity(0.5),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .scaleEffect(isAnimating ? 1.3 : 1.0)
                            .opacity(isAnimating ? 0.5 : 0.8)
                    }

                    // Conditional rotating ring
                    if deviceManager.shouldUseContinuousAnimations {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#667eea"),
                                        Color(hex: "#764ba2"),
                                        Color(hex: "#f093fb")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    } else {
                        // Static circle for low power mode
                        Circle()
                            .stroke(
                                Color(hex: "#667eea"),
                                lineWidth: 4
                            )
                            .frame(width: 120, height: 120)
                    }

                    // Inner circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    // AI Icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(sparkleScale)
                }

                // Text content with professional animation
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text(hasBothPhotos ? "Analyzing your fridge and pantry..." : "Analyzing your fridge...")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(textOpacity)
                            .scaleEffect(textOpacity)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: textOpacity)

                        Text("Detecting food items,\nquantity & freshness")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .opacity(textOpacity)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: textOpacity)
                    }

                    // Loading dots animation
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 10, height: 10)
                                .scaleEffect(isAnimating ? 1.0 : 0.5)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }
                    .padding(.vertical, 4)

                    // Photo thumbnails when both photos are provided
                    if hasBothPhotos {
                        HStack(spacing: 20) {
                            // Fridge photo thumbnail
                            VStack(spacing: 8) {
                                if let fridgeImage = fridgeImage {
                                    Image(uiImage: fridgeImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                        .opacity(textOpacity)
                                        .scaleEffect(textOpacity)
                                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.6), value: textOpacity)
                                }

                                Text("Fridge")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .opacity(textOpacity)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.6), value: textOpacity)
                            }

                            // Pantry photo thumbnail
                            VStack(spacing: 8) {
                                if let pantryImage = pantryImage {
                                    Image(uiImage: pantryImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                        .opacity(textOpacity)
                                        .scaleEffect(textOpacity)
                                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7), value: textOpacity)
                                }

                                Text("Pantry")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .opacity(textOpacity)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7), value: textOpacity)
                            }
                        }
                        .padding(.vertical, 12)
                    }

                    Text("While our chef prepares\nyour recipes...")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#f093fb"))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .opacity(textOpacity)
                        .animation(.easeInOut(duration: 0.5).delay(0.8), value: textOpacity)

                    Text("Status: \(processingMilestone.phase.displayTitle)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(statusAccentColor.opacity(0.92))
                        .monospacedDigit()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(statusAccentColor.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(statusAccentColor.opacity(0.35), lineWidth: 1)
                                )
                        )
                        .scaleEffect(statusBadgePulse ? 1.04 : 1.0)
                        .opacity(textOpacity)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: MotionTuning.seconds(0.4)).delay(MotionTuning.seconds(0.95)), value: textOpacity)
                        .animation(.spring(response: MotionTuning.seconds(0.3), dampingFraction: 0.86), value: processingMilestone.phase)
                        .accessibilityLabel("Processing status")
                        .accessibilityValue(processingMilestone.phase.displayTitle)

                    ProgressView(value: backendProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(statusAccentColor)
                        .frame(width: 240)
                        .opacity(textOpacity)
                        .animation(.spring(response: MotionTuning.seconds(0.28), dampingFraction: 0.9), value: backendProgress)
                        .accessibilityLabel("Recipe generation progress")
                        .accessibilityValue("\(Int(backendProgress * 100)) percent")
                    
                    VStack(spacing: 6) {
                        Text("Pro tip")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.62))
                            .textCase(.uppercase)
                            .tracking(1.2)
                        Text(waitingTips[tipIndex])
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .id(tipIndex)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )
                    )
                    .scaleEffect(tipPulse ? 1.015 : 0.985)
                    .opacity(textOpacity)

                    // Prominent game button
                    Button(action: {
                        guard canLaunchWaitingGame else { return }
                        launchGame(manuallyTriggered: true)
                    }) {
                        ZStack {
                            // Pulsing background
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#f093fb"), Color(hex: "#f5576c")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 336, height: 56)
                                .scaleEffect(isAnimating ? 1.05 : 1.0)
                                .opacity(isAnimating ? 0.9 : 1.0)
                                .animation(
                                    Animation.easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )

                            HStack(spacing: 10) {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 20))
                                Text("Play a game with your fridge while you wait!")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                        }
                    }
                    .buttonStyle(PlainButtonStyle()) // Remove default button styling
                    .accessibilityLabel("Play waiting game")
                    .accessibilityHint("Starts a mini game while recipes are being generated")
                    .opacity(textOpacity * (canLaunchWaitingGame ? 1.0 : 0.45))
                    .scaleEffect(textOpacity)
                    .rotation3DEffect(
                        .degrees(buttonShake),
                        axis: (x: 0, y: 0, z: 1)
                    )
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.0), value: textOpacity)
                    .padding(.top, 8)
                    .disabled(!canLaunchWaitingGame || didLaunchGame)
                }
                .padding(.horizontal, 30)
                .frame(maxWidth: 400) // Limit width for readability

                Spacer()
            }
        }
        .onAppear {
            // Start animations
            withAnimation(.easeInOut(duration: MotionTuning.seconds(2)).repeatForever(autoreverses: true)) {
                isAnimating = true
            }

            withAnimation(.easeInOut(duration: MotionTuning.seconds(6)).repeatForever(autoreverses: true)) {
                ambientShift = true
            }

            withAnimation(.easeInOut(duration: MotionTuning.seconds(1)).repeatForever(autoreverses: true)) {
                sparkleScale = 1.2
            }
            
            withAnimation(.easeInOut(duration: MotionTuning.seconds(1.7)).repeatForever(autoreverses: true)) {
                tipPulse = true
            }

            withAnimation(.easeInOut(duration: MotionTuning.seconds(0.6))) {
                textOpacity = 1.0
            }

            GrowthLoopManager.shared.trackWaitingGameShown(hasBothPhotos: hasBothPhotos)
            startButtonShakeTimer()
            lastMilestonePhase = processingMilestone.phase
            applyMilestone(phase: processingMilestone.phase)
            startTipRotation()
        }
        .onChange(of: processingMilestone.phase) { newPhase in
            applyMilestone(phase: newPhase)
        }
        .onDisappear {
            buttonShakeTimer?.invalidate()
            buttonShakeTimer = nil
            tipTimer?.invalidate()
            tipTimer = nil
            autoAdvanceTask?.cancel()
            autoAdvanceTask = nil
            statusResetTask?.cancel()
            statusResetTask = nil
            if !didLaunchGame {
                GrowthLoopManager.shared.trackWaitingGameDismissed()
            }
        }
    }

    private func startButtonShakeTimer() {
        buttonShakeTimer?.invalidate()
        buttonShakeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(
                    Animation.easeInOut(duration: 0.1)
                        .repeatCount(5, autoreverses: true)
                ) {
                    buttonShake = 3
                }

                try? await Task.sleep(nanoseconds: 500_000_000)
                buttonShake = 0
            }
        }
    }

    private func scheduleAutoAdvanceToGame(after delay: TimeInterval) {
        guard autoAdvanceTask == nil else { return }
        autoAdvanceTask = Task { @MainActor in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            launchGame(manuallyTriggered: false)
        }
    }

    private func startTipRotation() {
        tipTimer?.invalidate()
        tipTimer = Timer.scheduledTimer(withTimeInterval: MotionTuning.seconds(2.6), repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.spring(response: MotionTuning.seconds(0.38), dampingFraction: 0.9)) {
                    tipIndex = (tipIndex + 1) % waitingTips.count
                }
            }
        }
    }

    private func applyMilestone(phase: CameraProcessingPhase) {
        withAnimation(.easeInOut(duration: MotionTuning.seconds(0.35))) {
            backendProgress = phase.progressFraction
        }

        if phase != lastMilestonePhase {
            statusResetTask?.cancel()
            statusResetTask = nil
            lastMilestonePhase = phase
            switch phase {
            case .completed:
                if !reduceMotion {
                    withAnimation(.spring(response: MotionTuning.seconds(0.48), dampingFraction: 0.7)) {
                        completionBurst = true
                        completionBurstScale = 1.26
                    }
                }
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                withAnimation(.spring(response: MotionTuning.seconds(0.36), dampingFraction: 0.65)) {
                    statusBadgePulse = true
                }
                statusResetTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 650_000_000)
                    withAnimation(.easeOut(duration: MotionTuning.seconds(0.3))) {
                        statusBadgePulse = false
                        completionBurst = false
                        completionBurstScale = 0.85
                    }
                }
            case .failed:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                withAnimation(.easeInOut(duration: MotionTuning.seconds(0.22))) {
                    statusBadgePulse = true
                }
                statusResetTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    withAnimation(.easeOut(duration: MotionTuning.seconds(0.25))) {
                        statusBadgePulse = false
                    }
                }
            default:
                withAnimation(.easeInOut(duration: MotionTuning.seconds(0.2))) {
                    statusBadgePulse = phase == .waitingForRecipes || phase == .uploadingPhotos
                    completionBurst = false
                    completionBurstScale = 0.85
                }
            }
        }

        guard !didLaunchGame else { return }

        switch phase {
        case .waitingForRecipes:
            guard !reduceMotion else { return }
            guard GrowthLoopManager.shared.shouldAutoStartWaitingGame(hasBothPhotos: hasBothPhotos) else {
                return
            }
            let delay = GrowthLoopManager.shared.waitingGameAutoStartDelay(hasBothPhotos: hasBothPhotos)
            scheduleAutoAdvanceToGame(after: delay)
        case .completed, .failed, .decodingResponse, .finalizingResults:
            autoAdvanceTask?.cancel()
            autoAdvanceTask = nil
        default:
            break
        }
    }

    private func launchGame(manuallyTriggered: Bool) {
        guard !didLaunchGame else { return }
        didLaunchGame = true
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil

        if manuallyTriggered {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            GrowthLoopManager.shared.trackWaitingGameManualStart()
            onPlayGameTapped?()
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            GrowthLoopManager.shared.trackWaitingGameAutoStart()
            onAutoPlayGameTapped?()
        }
    }
}

#Preview {
    AIProcessingView(fridgeImage: nil, pantryImage: nil, processingMilestone: .idle)
}
