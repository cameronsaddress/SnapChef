import SwiftUI

enum MotionProfile {
    case simulator
    case device
}

enum MotionTuning {
    static let profile: MotionProfile = {
        #if targetEnvironment(simulator)
        return .simulator
        #else
        return .device
        #endif
    }()

    static var speedMultiplier: Double {
        switch profile {
        case .simulator:
            return 0.82
        case .device:
            return 1.0
        }
    }

    static func seconds(_ base: Double) -> Double {
        max(0.02, base * speedMultiplier)
    }

    static func cameraSeconds(_ base: Double) -> Double {
        let growthMultiplier = GrowthRemoteConfig.shared.cameraMotionMultiplier
        return max(0.02, seconds(base * growthMultiplier))
    }

    static func nanoseconds(_ baseSeconds: Double) -> UInt64 {
        UInt64(seconds(baseSeconds) * 1_000_000_000)
    }

    static func crispCurve(_ duration: Double, delay: Double = 0) -> Animation {
        .timingCurve(
            0.16,
            0.78,
            0.22,
            1,
            duration: seconds(duration)
        )
        .delay(seconds(delay))
    }

    static func settleSpring(
        response: Double = 0.38,
        damping: Double = 0.84,
        delay: Double = 0
    ) -> Animation {
        .spring(
            response: seconds(response),
            dampingFraction: damping,
            blendDuration: seconds(0.06)
        )
        .delay(seconds(delay))
    }

    static func softExit(_ duration: Double = 0.24, delay: Double = 0) -> Animation {
        .easeOut(duration: seconds(duration))
            .delay(seconds(delay))
    }
}

enum StudioMomentumVisual {
    static let primaryColor = Color(hex: "#4facfe")
    static let secondaryColor = Color(hex: "#00f2fe")
    static let tertiaryColor = Color(hex: "#38f9d7")
    static let cornerRadius: CGFloat = 18
    static let borderOpacity = 0.24
    static let shadowOpacity = 0.25
    static let shadowRadius: CGFloat = 14
    static let shadowYOffset: CGFloat = 6
    static let chipOpacity = 0.16

    static func gradient(
        primary: Color = primaryColor,
        secondary: Color = secondaryColor
    ) -> LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.82), secondary.opacity(0.56)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum StudioMomentumTypography {
    static let title = Font.system(size: 15, weight: .heavy, design: .rounded)
    static let subtitle = Font.system(size: 12, weight: .medium, design: .rounded)
    static let statValue = Font.system(size: 15, weight: .heavy, design: .rounded)
    static let statLabel = Font.system(size: 10, weight: .semibold, design: .rounded)
    static let action = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let goalTitle = Font.system(size: 12, weight: .bold, design: .rounded)
    static let goalMono = Font.system(size: 11, weight: .semibold, design: .monospaced)
    static let goalBody = Font.system(size: 11, weight: .medium, design: .rounded)
}

struct StudioMomentumCardContainer<Content: View>: View {
    let primary: Color
    let secondary: Color
    let content: () -> Content

    init(
        primary: Color = StudioMomentumVisual.primaryColor,
        secondary: Color = StudioMomentumVisual.secondaryColor,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.primary = primary
        self.secondary = secondary
        self.content = content
    }

    var body: some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: StudioMomentumVisual.cornerRadius, style: .continuous)
                    .fill(StudioMomentumVisual.gradient(primary: primary, secondary: secondary))
                    .overlay(
                        RoundedRectangle(cornerRadius: StudioMomentumVisual.cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(StudioMomentumVisual.borderOpacity), lineWidth: 1)
                    )
            )
            .shadow(
                color: primary.opacity(StudioMomentumVisual.shadowOpacity),
                radius: StudioMomentumVisual.shadowRadius,
                y: StudioMomentumVisual.shadowYOffset
            )
    }
}

// MARK: - Glassmorphic Card
struct GlassmorphicCard<Content: View>: View {
    let content: () -> Content
    var cornerRadius: CGFloat = 20
    var glowColor = Color(hex: "#4facfe")

    @State private var isPressed = false
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        content()
            .background(
                ZStack {
                    // Glow effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(glowColor.opacity(0.3))
                        .blur(radius: 20)
                        .offset(y: 10)
                        .scaleEffect(isPressed ? 0.95 : 1.0)

                    // Glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            // Border gradient
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )

                    // Shimmer effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: UnitPoint(x: shimmerPhase - 0.3, y: 0),
                                endPoint: UnitPoint(x: shimmerPhase + 0.3, y: 1)
                            )
                        )
                        .allowsHitTesting(false)
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Magnetic Button
struct MagneticButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    @State private var offset: CGSize = .zero
    @State private var isPressed = false
    @State private var particleScale: CGFloat = 0

    var body: some View {
        Button(action: {
            impact(.medium)
            triggerParticles()
            action()
        }) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    // Gradient background
                    LinearGradient(
                        colors: [
                            Color(hex: "#667eea"),
                            Color(hex: "#764ba2")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Particle burst
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .scaleEffect(particleScale)
                        .opacity(particleScale > 0 ? 0 : 1)
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 20, y: 10)
            .offset(offset)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let translation = value.translation
                    let distance = sqrt(pow(translation.width, 2) + pow(translation.height, 2))
                    let maxDistance: CGFloat = 30

                    if distance < maxDistance {
                        offset = CGSize(
                            width: translation.width * 0.5,
                            height: translation.height * 0.5
                        )
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = .zero
                    }
                }
        )
    }

    private func triggerParticles() {
        particleScale = 0
        withAnimation(.easeOut(duration: 0.6)) {
            particleScale = 3
        }
    }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let badge: String?
    let action: () -> Void

    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1
    @State private var showRipple = false

    init(icon: String, badge: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.badge = badge
        self.action = action
    }

    var body: some View {
        Button(action: {
            triggerAnimation()
            action()
        }) {
            ZStack {
                // Ripple effect
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .scaleEffect(showRipple ? 2.5 : 1)
                    .opacity(showRipple ? 0 : 1)

                // Button background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#f093fb"),
                                Color(hex: "#f5576c")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "#f093fb").opacity(0.5), radius: 15, y: 8)

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))

                // Badge
                if let badge = badge {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color(hex: "#667eea"))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(badge)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        }
                        Spacer()
                    }
                    .offset(x: 5, y: -5)
                }
            }
            .frame(width: 60, height: 60)
            .scaleEffect(scale)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func triggerAnimation() {
        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Scale animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 0.9
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
            scale = 1.0
        }

        // Rotation animation
        withAnimation(.easeInOut(duration: 0.5)) {
            rotation += 360
        }

        // Ripple animation
        showRipple = true
        withAnimation(.easeOut(duration: 0.6)) {
            showRipple = false
        }
    }
}

// MARK: - Neumorphic Toggle
struct NeumorphicToggle: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            ZStack {
                // Track
                Capsule()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 50, height: 30)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                // Thumb
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isOn ? [
                                Color(hex: "#43e97b"),
                                Color(hex: "#38f9d7")
                            ] : [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                    .offset(x: isOn ? 10 : -10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
            }
            .onTapGesture {
                withAnimation {
                    isOn.toggle()
                }

                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Animated Progress Ring
struct AnimatedProgressRing: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat = 8

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#667eea"),
                            Color(hex: "#764ba2"),
                            Color(hex: "#f093fb"),
                            Color(hex: "#667eea")
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 5)

            // Center text
            Text("\(Int(animatedProgress * 100))%")
                .font(.system(size: size / 4, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Studio Interaction
struct StudioSpringButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.94
    var pressedYOffset: CGFloat = 1.5
    var activeRotation: Double = 1.8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .offset(y: configuration.isPressed ? pressedYOffset : 0)
            .rotation3DEffect(
                .degrees(configuration.isPressed ? activeRotation : 0),
                axis: (x: 1, y: 0, z: 0)
            )
            .saturation(configuration.isPressed ? 1.08 : 1.0)
            .brightness(configuration.isPressed ? 0.03 : 0.0)
            .animation(.spring(response: MotionTuning.seconds(0.22), dampingFraction: 0.72), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 30) {
            GlassmorphicCard {
                VStack {
                    Text("Glassmorphic Card")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Beautiful glass effect")
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(30)
            }

            MagneticButton(
                title: "Get Started",
                icon: "arrow.right",
                action: {}
            )

            FloatingActionButton(
                icon: "camera.fill",
                action: {}
            )
        }
    }
}
