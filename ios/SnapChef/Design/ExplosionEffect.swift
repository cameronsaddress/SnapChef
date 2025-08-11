import SwiftUI
import CoreHaptics

// MARK: - Explosion Particle
struct ExplosionParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var color: Color
    var size: CGFloat
    var opacity: Double = 1.0
    var rotation: Double = 0
    var rotationSpeed: Double
    var lifespan: Double = 1.0
    var age: Double = 0
    var glow: Bool = false
    var trail: [CGPoint] = []
    
    mutating func update(deltaTime: Double) {
        age += deltaTime
        let progress = age / lifespan
        
        // Physics update
        velocity.dy += 300 * deltaTime // Gravity
        position.x += velocity.dx * deltaTime
        position.y += velocity.dy * deltaTime
        
        // Rotation
        rotation += rotationSpeed * deltaTime
        
        // Fade and shrink
        opacity = 1.0 - progress
        size *= 0.98
        
        // Update trail
        trail.append(position)
        if trail.count > 10 {
            trail.removeFirst()
        }
    }
    
    var isAlive: Bool {
        opacity > 0.01 && age < lifespan
    }
}

// MARK: - Shockwave Ring
struct ShockwaveRing: View {
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 1.0
    let color: Color
    
    var body: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [
                        color,
                        color.opacity(0.5),
                        Color.clear
                    ],
                    startPoint: .center,
                    endPoint: .trailing
                ),
                lineWidth: 3
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .blur(radius: scale > 2 ? 2 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    scale = 4.0
                    opacity = 0
                }
            }
    }
}

// MARK: - Screen Shake Modifier
struct ScreenShakeModifier: ViewModifier {
    @State private var offset: CGSize = .zero
    let magnitude: CGFloat
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .onAppear {
                shake()
            }
    }
    
    private func shake() {
        let numberOfShakes = Int(duration * 10)
        
        for i in 0..<numberOfShakes {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                withAnimation(.linear(duration: 0.1)) {
                    offset = CGSize(
                        width: CGFloat.random(in: -magnitude...magnitude),
                        height: CGFloat.random(in: -magnitude...magnitude)
                    )
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.linear(duration: 0.1)) {
                offset = .zero
            }
        }
    }
}

// MARK: - Chromatic Aberration
struct ChromaticAberrationView: View {
    let content: AnyView
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            content
                .colorMultiply(.red)
                .offset(x: -offset)
                .blendMode(.plusLighter)
            
            content
                .colorMultiply(.green)
                .blendMode(.plusLighter)
            
            content
                .colorMultiply(.blue)
                .offset(x: offset)
                .blendMode(.plusLighter)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                offset = 3
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeIn(duration: 0.2)) {
                    offset = 0
                }
            }
        }
    }
}

// MARK: - Explosion Manager
@MainActor
final class ExplosionManager: ObservableObject {
    @Published var particles: [ExplosionParticle] = []
    @Published var shockwaves: [UUID] = []
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
    
    func explode(at position: CGPoint, intensity: ExplosionIntensity = .medium) {
        // Create shockwave
        let shockwaveId = UUID()
        shockwaves.append(shockwaveId)
        
        // Remove shockwave after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.shockwaves.removeAll { $0 == shockwaveId }
        }
        
        // Create particles
        let config = intensity.configuration
        
        for i in 0..<config.particleCount {
            let angle = (Double(i) / Double(config.particleCount)) * 2 * .pi + Double.random(in: -0.2...0.2)
            let speed = CGFloat.random(in: config.speedRange)
            let color = config.colors.randomElement() ?? .white
            
            let particle = ExplosionParticle(
                position: position,
                velocity: CGVector(
                    dx: cos(angle) * speed,
                    dy: sin(angle) * speed - 50 // Initial upward bias
                ),
                color: color,
                size: CGFloat.random(in: config.sizeRange),
                rotationSpeed: Double.random(in: -720...720),
                lifespan: Double.random(in: config.lifespanRange),
                glow: i % 3 == 0 // Every third particle glows
            )
            
            particles.append(particle)
        }
        
        // Create debris particles
        for _ in 0..<config.debrisCount {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 50...150)
            
            let debris = ExplosionParticle(
                position: position,
                velocity: CGVector(
                    dx: cos(angle) * speed,
                    dy: sin(angle) * speed - 100
                ),
                color: config.debrisColors.randomElement() ?? .gray,
                size: CGFloat.random(in: 15...25),
                rotationSpeed: Double.random(in: -360...360),
                lifespan: Double.random(in: 0.8...1.2),
                glow: false
            )
            
            particles.append(debris)
        }
    }
    
    func cleanup() {
        displayLink?.invalidate()
        displayLink = nil
    }
}

// MARK: - Explosion Intensity
enum ExplosionIntensity {
    case small
    case medium
    case large
    case mega
    
    var configuration: ExplosionConfiguration {
        switch self {
        case .small:
            return ExplosionConfiguration(
                particleCount: 20,
                debrisCount: 5,
                speedRange: 50...150,
                sizeRange: 4...8,
                lifespanRange: 0.4...0.8,
                colors: [Color(hex: "#ffa726"), Color(hex: "#fb8c00")],
                debrisColors: [Color.gray, Color.brown]
            )
        case .medium:
            return ExplosionConfiguration(
                particleCount: 40,
                debrisCount: 10,
                speedRange: 100...250,
                sizeRange: 6...12,
                lifespanRange: 0.6...1.0,
                colors: [Color(hex: "#f093fb"), Color(hex: "#f5576c"), Color(hex: "#ffa726")],
                debrisColors: [Color.gray, Color.brown, Color.orange]
            )
        case .large:
            return ExplosionConfiguration(
                particleCount: 60,
                debrisCount: 15,
                speedRange: 150...350,
                sizeRange: 8...16,
                lifespanRange: 0.8...1.2,
                colors: [Color(hex: "#fa709a"), Color(hex: "#fee140"), Color(hex: "#f5576c")],
                debrisColors: [Color.gray, Color.brown, Color.orange, Color.yellow]
            )
        case .mega:
            return ExplosionConfiguration(
                particleCount: 100,
                debrisCount: 25,
                speedRange: 200...500,
                sizeRange: 10...20,
                lifespanRange: 1.0...1.5,
                colors: [Color(hex: "#30cfd0"), Color(hex: "#330867"), Color(hex: "#fa709a"), Color.white],
                debrisColors: [Color.gray, Color.brown, Color.orange, Color.yellow, Color.red]
            )
        }
    }
}

struct ExplosionConfiguration {
    let particleCount: Int
    let debrisCount: Int
    let speedRange: ClosedRange<CGFloat>
    let sizeRange: ClosedRange<CGFloat>
    let lifespanRange: ClosedRange<Double>
    let colors: [Color]
    let debrisColors: [Color]
}

// MARK: - Explosion Effect View
struct ExplosionEffectView: View {
    @ObservedObject var manager: ExplosionManager
    let position: CGPoint
    let intensity: ExplosionIntensity
    @State private var showEffect = false
    
    var body: some View {
        ZStack {
            // Shockwaves
            ForEach(manager.shockwaves, id: \.self) { _ in
                ShockwaveRing(color: intensity.configuration.colors.first ?? .white)
                    .position(position)
            }
            
            // Particles
            Canvas { context, size in
                for particle in manager.particles {
                    drawParticle(particle, in: &context)
                }
            }
            .allowsHitTesting(false)
            .blendMode(.plusLighter)
            
            // Flash effect
            if showEffect {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.5),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .position(position)
                    .opacity(showEffect ? 1 : 0)
                    .scaleEffect(showEffect ? 2 : 0.5)
                    .blur(radius: 10)
            }
        }
        .onAppear {
            showEffect = true
            withAnimation(.easeOut(duration: 0.2)) {
                showEffect = false
            }
            manager.explode(at: position, intensity: intensity)
        }
    }
    
    private func drawParticle(_ particle: ExplosionParticle, in context: inout GraphicsContext) {
        context.opacity = particle.opacity
        
        // Draw trail
        if !particle.trail.isEmpty && particle.trail.count > 1 {
            var path = Path()
            path.move(to: particle.trail[0])
            for point in particle.trail.dropFirst() {
                path.addLine(to: point)
            }
            
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        particle.color.opacity(0),
                        particle.color.opacity(0.5)
                    ]),
                    startPoint: particle.trail.first ?? .zero,
                    endPoint: particle.trail.last ?? .zero
                ),
                style: StrokeStyle(lineWidth: particle.size * 0.3, lineCap: .round)
            )
        }
        
        // Transform for rotation
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: particle.position.x, y: particle.position.y)
        transform = transform.rotated(by: particle.rotation * .pi / 180)
        
        context.transform = transform
        
        // Draw particle
        if particle.glow {
            // Glowing particle
            for i in 0..<3 {
                let scale = 1.0 + CGFloat(i) * 0.5
                let opacity = particle.opacity / CGFloat(i + 1)
                
                let rect = CGRect(
                    x: -particle.size * scale / 2,
                    y: -particle.size * scale / 2,
                    width: particle.size * scale,
                    height: particle.size * scale
                )
                
                context.fill(Circle().path(in: rect), with: .radialGradient(
                    Gradient(colors: [
                        particle.color.opacity(opacity),
                        particle.color.opacity(opacity * 0.3),
                        Color.clear
                    ]),
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    startRadius: 0,
                    endRadius: particle.size * scale
                ))
            }
        } else {
            // Regular particle
            let rect = CGRect(
                x: -particle.size / 2,
                y: -particle.size / 2,
                width: particle.size,
                height: particle.size
            )
            
            // Debris shape (irregular)
            if particle.size > 10 {
                var path = Path()
                let points = 6
                for i in 0..<points {
                    let angle = (Double(i) / Double(points)) * 2 * .pi
                    let radius = particle.size / 2 * CGFloat.random(in: 0.7...1.0)
                    let point = CGPoint(
                        x: CGFloat(cos(angle)) * radius,
                        y: CGFloat(sin(angle)) * radius
                    )
                    if i == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                path.closeSubpath()
                
                context.fill(path, with: .color(particle.color))
            } else {
                context.fill(Circle().path(in: rect), with: .color(particle.color))
            }
        }
        
        context.transform = .identity
    }
}

// MARK: - Convenience Extensions
extension View {
    func screenShake(magnitude: CGFloat = 10, duration: Double = 0.5) -> some View {
        modifier(ScreenShakeModifier(magnitude: magnitude, duration: duration))
    }
    
    func chromaticAberration() -> some View {
        ChromaticAberrationView(content: AnyView(self))
    }
}