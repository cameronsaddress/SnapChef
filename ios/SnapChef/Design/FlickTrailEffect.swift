import SwiftUI

// MARK: - Trail Particle
struct TrailParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var color: Color
    var size: CGFloat
    var opacity: Double
    var glow: CGFloat
    var stretch: CGFloat = 1.0
    var age: Double = 0
    var lifespan: Double = 0.5

    mutating func update(deltaTime: Double) {
        age += deltaTime
        let progress = age / lifespan

        // Fade out
        opacity = 1.0 - progress

        // Shrink
        size *= 0.98

        // Apply velocity with damping
        position.x += velocity.dx * deltaTime
        position.y += velocity.dy * deltaTime
        velocity.dx *= 0.95
        velocity.dy *= 0.95
    }

    var isAlive: Bool {
        opacity > 0.01 && size > 0.5
    }
}

// MARK: - Flick Trail Manager
class FlickTrailManager: ObservableObject {
    @Published var particles: [TrailParticle] = []
    private var lastPosition: CGPoint?
    private var displayLink: CADisplayLink?
    private var lastUpdateTime = Date()

    init() {
        setupDisplayLink()
    }

    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func update() {
        let currentTime = Date()
        let deltaTime = currentTime.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = currentTime

        // Update particles
        particles = particles.compactMap { particle in
            var updated = particle
            updated.update(deltaTime: deltaTime)
            return updated.isAlive ? updated : nil
        }

        objectWillChange.send()
    }

    func addTrailPoint(at position: CGPoint, velocity: CGVector, color: Color) {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)

        // Dynamic particle count based on speed
        let particleCount = min(Int(speed / 20), 5)

        for _ in 0..<particleCount {
            let offsetAngle = Double.random(in: 0...(2 * .pi))
            let offsetDistance = CGFloat.random(in: 0...5)

            let particle = TrailParticle(
                position: CGPoint(
                    x: position.x + CGFloat(cos(offsetAngle)) * offsetDistance,
                    y: position.y + CGFloat(sin(offsetAngle)) * offsetDistance
                ),
                velocity: CGVector(
                    dx: velocity.dx * 0.1 + CGFloat.random(in: -10...10),
                    dy: velocity.dy * 0.1 + CGFloat.random(in: -10...10)
                ),
                color: color,
                size: CGFloat.random(in: 4...12) * (1 + speed / 200),
                opacity: 0.8,
                glow: min(speed / 100, 3.0),
                stretch: 1.0 + min(speed / 300, 2.0),
                lifespan: Double.random(in: 0.3...0.6)
            )

            particles.append(particle)
        }

        lastPosition = position
    }

    func clear() {
        particles.removeAll()
        lastPosition = nil
    }

    deinit {
        displayLink?.invalidate()
    }
}

// MARK: - Flick Trail View
struct FlickTrailView: View {
    @ObservedObject var manager: FlickTrailManager

    var body: some View {
        Canvas { context, _ in
            // Apply bloom effect to entire layer
            context.addFilter(.blur(radius: 0.5))

            for particle in manager.particles {
                drawParticle(particle, in: &context)
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }

    private func drawParticle(_ particle: TrailParticle, in context: inout GraphicsContext) {
        context.opacity = particle.opacity

        // Calculate stretch based on velocity
        let angle = atan2(particle.velocity.dy, particle.velocity.dx)

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: particle.position.x, y: particle.position.y)
        transform = transform.rotated(by: angle)
        transform = transform.scaledBy(x: particle.stretch, y: 1.0)

        context.transform = transform

        // Multi-layer glow effect
        let glowLayers = 3
        for layer in 0..<glowLayers {
            let layerScale = 1.0 + CGFloat(layer) * 0.5

            let rect = CGRect(
                x: -particle.size * layerScale / 2,
                y: -particle.size * layerScale / 2,
                width: particle.size * layerScale,
                height: particle.size * layerScale
            )

            context.fill(Ellipse().path(in: rect), with: .radialGradient(
                Gradient(colors: [particle.color.opacity(0.6), particle.color.opacity(0)]),
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: 0,
                endRadius: particle.size * layerScale / 2
            ))
        }

        context.transform = .identity
    }
}

// MARK: - Enhanced Trail Effect
struct EnhancedFlickTrailView: View {
    let trail: [CGPoint]
    let velocity: CGVector
    let baseColor: Color

    @State private var trailManager = FlickTrailManager()

    var body: some View {
        ZStack {
            // Main trail line
            TrailPathView(trail: trail, velocity: velocity, color: baseColor)

            // Particle trail
            FlickTrailView(manager: trailManager)
        }
        .onChange(of: trail) { newTrail in
            if let lastPoint = newTrail.last {
                let trailColor = colorForVelocity(velocity)
                trailManager.addTrailPoint(at: lastPoint, velocity: velocity, color: trailColor)
            }
        }
    }

    private func colorForVelocity(_ velocity: CGVector) -> Color {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)

        // Color gradient based on speed
        if speed < 50 {
            return baseColor
        } else if speed < 150 {
            return Color(hex: "#4facfe")
        } else if speed < 300 {
            return Color(hex: "#f093fb")
        } else {
            return Color(hex: "#fa709a")
        }
    }
}

// MARK: - Trail Path View
struct TrailPathView: View {
    let trail: [CGPoint]
    let velocity: CGVector
    let color: Color

    var body: some View {
        Canvas { context, _ in
            guard trail.count > 2 else { return }

            // Create smooth path
            var path = Path()
            path.move(to: trail[0])

            // Use Catmull-Rom spline for smooth curves
            for i in 1..<trail.count {
                if i == 1 {
                    path.addLine(to: trail[i])
                } else {
                    let controlPoint1 = CGPoint(
                        x: (trail[i - 1].x + trail[i].x) / 2,
                        y: (trail[i - 1].y + trail[i].y) / 2
                    )
                    let controlPoint2 = trail[i]
                    path.addCurve(to: trail[i], control1: controlPoint1, control2: controlPoint2)
                }
            }

            // Calculate gradient colors
            let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
            let gradientColors = [
                color.opacity(0),
                color.opacity(0.3),
                color.opacity(0.6),
                color.opacity(0.8),
                color
            ]

            // Draw multiple strokes for glow effect
            for (index, width) in [8.0, 5.0, 3.0].enumerated() {
                let opacity = 0.3 + (0.3 * Double(index))

                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: gradientColors),
                        startPoint: trail.first ?? .zero,
                        endPoint: trail.last ?? .zero
                    ),
                    style: StrokeStyle(
                        lineWidth: width * (1.0 + speed / 500.0),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                context.opacity = opacity
            }

            // Add bright core
            context.opacity = 1.0
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.5),
                        Color.white.opacity(0.8)
                    ]),
                    startPoint: trail.first ?? .zero,
                    endPoint: trail.last ?? .zero
                ),
                style: StrokeStyle(
                    lineWidth: 1.5,
                    lineCap: .round
                )
            )
        }
        .blur(radius: 0.5)
    }
}

// MARK: - Motion Blur Effect
struct MotionBlurModifier: ViewModifier {
    let velocity: CGVector
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .blur(radius: isActive ? blurRadius : 0)
            .scaleEffect(
                x: isActive ? stretchFactor : 1.0,
                y: 1.0,
                anchor: .center
            )
            .rotationEffect(.radians(angle))
    }

    private var blurRadius: CGFloat {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        return min(speed / 100, 5)
    }

    private var stretchFactor: CGFloat {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        return 1.0 + min(speed / 500, 0.5)
    }

    private var angle: Double {
        atan2(velocity.dy, velocity.dx)
    }
}

extension View {
    func motionBlur(velocity: CGVector, isActive: Bool = true) -> some View {
        modifier(MotionBlurModifier(velocity: velocity, isActive: isActive))
    }
}
