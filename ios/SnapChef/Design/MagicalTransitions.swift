import SwiftUI

// MARK: - Liquid Transition
struct LiquidTransition: ViewModifier {
    let isActive: Bool
    @EnvironmentObject var deviceManager: DeviceManager

    func body(content: Content) -> some View {
        content
            .mask(
                GeometryReader { geometry in
                    if deviceManager.shouldUseHeavyEffects {
                        LiquidMask(
                            size: geometry.size,
                            progress: isActive ? 1 : 0
                        )
                    } else {
                        // Simple fade mask for low-end devices
                        Rectangle()
                            .opacity(isActive ? 1 : 0)
                    }
                }
            )
    }
}

struct LiquidMask: View {
    let size: CGSize
    let progress: CGFloat
    @EnvironmentObject var deviceManager: DeviceManager

    var body: some View {
        Canvas { context, _ in
            var path = Path()

            let radius = size.width * 1.5 * progress
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // Adjust detail level based on device capabilities
            let angleStep = deviceManager.isLowPowerModeEnabled ? 5 : 1
            
            // Create liquid blob shape with adaptive detail
            for angle in stride(from: 0, to: 360, by: angleStep) {
                let radian = Double(angle) * .pi / 180
                let variation = sin(radian * 5) * 20 * progress
                let currentRadius = radius + variation

                let x = center.x + cos(radian) * currentRadius
                let y = center.y + sin(radian) * currentRadius

                if angle == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            path.closeSubpath()
            context.fill(path, with: .color(.white))
        }
    }
}

// MARK: - Particle Explosion Transition
struct ParticleExplosion: ViewModifier {
    @Binding var trigger: Bool
    @EnvironmentObject var deviceManager: DeviceManager

    @State private var particles: [TransitionExplosionParticle] = []
    @State private var animationTimer: Timer?

    func body(content: Content) -> some View {
        content
            .overlay(
                Canvas { context, _ in
                    // Skip rendering if particles are disabled
                    guard deviceManager.shouldShowParticles else { return }
                    
                    // Simply render current particle state without modifying anything
                    for particle in particles {
                        context.opacity = particle.opacity

                        let rect = CGRect(
                            x: particle.position.x - particle.size / 2,
                            y: particle.position.y - particle.size / 2,
                            width: particle.size,
                            height: particle.size
                        )

                        context.fill(
                            Circle().path(in: rect),
                            with: .color(particle.color)
                        )
                    }
                }
                .allowsHitTesting(false)
            )
            .onChange(of: trigger) { _ in
                if trigger && deviceManager.shouldShowParticles {
                    explode()
                }
            }
            .onDisappear {
                // Clean up timer when view disappears
                animationTimer?.invalidate()
                animationTimer = nil
                particles.removeAll()
            }
    }

    private func explode() {
        let colors: [Color] = [
            Color(hex: "#667eea"),
            Color(hex: "#764ba2"),
            Color(hex: "#f093fb"),
            Color(hex: "#4facfe"),
            Color(hex: "#43e97b")
        ]

        // Adjust particle count based on device capabilities
        let particleCount = deviceManager.recommendedParticleCount
        guard particleCount > 0 else {
            trigger = false
            return
        }

        particles = (0..<particleCount).map { _ in
            TransitionExplosionParticle(
                position: CGPoint(
                    x: UIScreen.main.bounds.width / 2,
                    y: UIScreen.main.bounds.height / 2
                ),
                velocity: CGVector(
                    dx: CGFloat.random(in: -200...200),
                    dy: CGFloat.random(in: -200...200)
                ),
                size: CGFloat.random(in: 4...12),
                color: colors.randomElement()!,
                opacity: 1
            )
        }

        // Clean up any existing timer
        animationTimer?.invalidate()
        
        // Use adaptive frame rate based on device capabilities
        let updateInterval = deviceManager.isLowPowerModeEnabled ? 0.033 : 0.016 // 30fps vs 60fps
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { @MainActor in
                updateParticles()

                if particles.isEmpty {
                    animationTimer?.invalidate()
                    animationTimer = nil
                    trigger = false
                }
            }
        }
    }

    @MainActor
    private func updateParticles() {
        particles = particles.compactMap { particle in
            var updated = particle
            updated.position.x += updated.velocity.dx * 0.016
            updated.position.y += updated.velocity.dy * 0.016
            updated.velocity.dx *= 0.98
            updated.velocity.dy *= 0.98
            updated.opacity -= 0.02

            return updated.opacity > 0 ? updated : nil
        }
    }
}

struct TransitionExplosionParticle {
    var position: CGPoint
    var velocity: CGVector
    var size: CGFloat
    var color: Color
    var opacity: Double
}

// MARK: - Morphing Shape Transition
struct MorphingShapeTransition: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            .clipShape(
                MorphingShape(progress: progress)
            )
    }
}

struct MorphingShape: Shape {
    var progress: CGFloat

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let corners = progress * rect.height / 2
        let controlPoint = (1 - progress) * 100

        // Top left
        path.move(to: CGPoint(x: corners, y: 0))

        // Top edge with curve
        path.addQuadCurve(
            to: CGPoint(x: rect.width - corners, y: 0),
            control: CGPoint(x: rect.width / 2, y: -controlPoint)
        )

        // Top right corner
        path.addArc(
            center: CGPoint(x: rect.width - corners, y: corners),
            radius: corners,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )

        // Right edge with curve
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height - corners),
            control: CGPoint(x: rect.width + controlPoint, y: rect.height / 2)
        )

        // Continue for other edges...
        path.addArc(
            center: CGPoint(x: rect.width - corners, y: rect.height - corners),
            radius: corners,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        path.addQuadCurve(
            to: CGPoint(x: corners, y: rect.height),
            control: CGPoint(x: rect.width / 2, y: rect.height + controlPoint)
        )

        path.addArc(
            center: CGPoint(x: corners, y: rect.height - corners),
            radius: corners,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        path.addQuadCurve(
            to: CGPoint(x: 0, y: corners),
            control: CGPoint(x: -controlPoint, y: rect.height / 2)
        )

        path.addArc(
            center: CGPoint(x: corners, y: corners),
            radius: corners,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        return path
    }
}

// MARK: - Staggered Fade Transition
struct StaggeredFade: ViewModifier {
    let index: Int
    let isShowing: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isShowing ? 1 : 0)
            .scaleEffect(isShowing ? 1 : 0.8)
            .offset(y: isShowing ? 0 : 20)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8)
                    .delay(Double(index) * 0.05),
                value: isShowing
            )
    }
}

// MARK: - Portal Transition
struct PortalTransition: GeometryEffect {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    nonisolated func effectValue(size: CGSize) -> ProjectionTransform {
        let scaled = 1 - (1 - progress) * 0.5
        let rotation = progress * .pi * 2

        var transform = CGAffineTransform.identity

        // Move to center
        transform = transform.translatedBy(x: size.width / 2, y: size.height / 2)

        // Apply rotation and scale
        transform = transform.rotated(by: rotation)
        transform = transform.scaledBy(x: scaled, y: scaled)

        // Move back
        transform = transform.translatedBy(x: -size.width / 2, y: -size.height / 2)

        return ProjectionTransform(transform)
    }
}

// MARK: - Spring Chain Animation
struct SpringChain: ViewModifier {
    let index: Int
    @Binding var trigger: Bool

    @State private var offset: CGFloat = 0
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .rotationEffect(.degrees(rotation))
            .onChange(of: trigger) { _ in
                if trigger {
                    animate()
                }
            }
    }

    private func animate() {
        let delay = Double(index) * 0.1

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(delay)) {
            offset = -30
            rotation = -5
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(delay + 0.2)) {
            offset = 0
            rotation = 0
        }
    }
}

// MARK: - Elastic Bounce
struct ElasticBounce: AnimatableModifier {
    var progress: CGFloat

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let scale = 1 + sin(progress * .pi * 4) * 0.1 * (1 - progress)
        let rotation = sin(progress * .pi * 6) * 5 * (1 - progress)

        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - View Extensions
extension View {
    func liquidTransition(isActive: Bool) -> some View {
        modifier(LiquidTransition(isActive: isActive))
    }

    func particleExplosion(trigger: Binding<Bool>) -> some View {
        modifier(ParticleExplosion(trigger: trigger))
    }

    func morphingTransition(progress: CGFloat) -> some View {
        modifier(MorphingShapeTransition(progress: progress))
    }

    func staggeredFade(index: Int, isShowing: Bool) -> some View {
        modifier(StaggeredFade(index: index, isShowing: isShowing))
    }

    func portalTransition(progress: Double) -> some View {
        modifier(PortalTransition(progress: progress))
    }

    func springChain(index: Int, trigger: Binding<Bool>) -> some View {
        modifier(SpringChain(index: index, trigger: trigger))
    }

    func elasticBounce(progress: CGFloat) -> some View {
        modifier(ElasticBounce(progress: progress))
    }
}

#Preview {
    VStack {
        Text("Magical Transitions")
            .font(.largeTitle.bold())
            .foregroundColor(.white)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
