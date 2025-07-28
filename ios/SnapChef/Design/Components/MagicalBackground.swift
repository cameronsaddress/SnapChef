import SwiftUI
import CoreMotion

// MARK: - Magical Animated Background
struct MagicalBackground: View {
    @State private var phase: CGFloat = 0
    @State private var breathe: CGFloat = 0
    @State private var shimmer: CGFloat = 0
    @State private var particleSystem = ParticleSystem()
    
    // Motion manager for parallax effect
    @StateObject private var motionManager = MotionObserver()
    
    var body: some View {
        ZStack {
            // Layer 1: Animated Mesh Gradient
            MeshGradientLayer(phase: phase, breathe: breathe)
                .ignoresSafeArea()
            
            // Layer 2: Aurora Borealis Effect
            AuroraLayer(shimmer: shimmer)
                .ignoresSafeArea()
                .blendMode(.screen)
                .opacity(0.3)
            
            // Layer 3: Floating Orbs
            FloatingOrbsLayer(phase: phase)
                .ignoresSafeArea()
                .blendMode(.plusLighter)
            
            // Layer 4: Particle System
            ParticleSystemView(system: particleSystem)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            // Layer 5: Interactive Ripples
            RippleEffectLayer()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .modifier(ParallaxEffect(motion: motionManager))
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Main phase animation
        withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: false)) {
            phase = .pi * 2
        }
        
        // Breathing animation
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            breathe = 1
        }
        
        // Shimmer animation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            shimmer = 1
        }
        
        // Start particle system
        particleSystem.start()
    }
}

// MARK: - Mesh Gradient Layer
struct MeshGradientLayer: View {
    let phase: CGFloat
    let breathe: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let colors: [Color] = [
                Color(hex: "#667eea"), // Purple
                Color(hex: "#764ba2"), // Deep Purple
                Color(hex: "#f093fb"), // Pink
                Color(hex: "#4facfe"), // Blue
                Color(hex: "#00f2fe"), // Cyan
                Color(hex: "#43e97b"), // Green
                Color(hex: "#38f9d7")  // Teal
            ]
            
            // Create mesh points
            let cols = 4
            let rows = 5
            
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = (size.width / CGFloat(cols - 1)) * CGFloat(col)
                    let y = (size.height / CGFloat(rows - 1)) * CGFloat(row)
                    
                    // Animate position with sine waves
                    let offsetX = sin(phase + CGFloat(col) * 0.5) * 20 * (1 + breathe)
                    let offsetY = cos(phase + CGFloat(row) * 0.5) * 20 * (1 + breathe)
                    
                    let center = CGPoint(x: x + offsetX, y: y + offsetY)
                    let radius = 200 + sin(phase * 2 + CGFloat(col + row)) * 50
                    
                    let gradient = RadialGradient(
                        colors: [colors[(col + row) % colors.count], Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                    
                    context.fill(
                        Circle().path(in: CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .radialGradient(gradient)
                    )
                }
            }
        }
    }
}

// MARK: - Aurora Borealis Effect
struct AuroraLayer: View {
    let shimmer: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<3) { index in
                    Wave(
                        amplitude: 50 + CGFloat(index) * 20,
                        frequency: 0.5 + CGFloat(index) * 0.2,
                        phase: shimmer * .pi * 2 + CGFloat(index) * 0.5,
                        opacity: 0.3 - CGFloat(index) * 0.1
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#00f2fe").opacity(0.3),
                                Color(hex: "#4facfe").opacity(0.2),
                                Color(hex: "#667eea").opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Wave Shape
struct Wave: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat
    var opacity: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, to: width, by: 1) {
            let relativeX = x / width
            let y = sin(relativeX * .pi * frequency * 2 + phase) * amplitude + midHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Floating Orbs
struct FloatingOrbsLayer: View {
    let phase: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<8) { index in
                FloatingOrb(
                    size: CGFloat.random(in: 80...200),
                    initialPosition: CGPoint(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    ),
                    phase: phase,
                    delay: Double(index) * 0.2
                )
            }
        }
    }
}

struct FloatingOrb: View {
    let size: CGFloat
    let initialPosition: CGPoint
    let phase: CGFloat
    let delay: Double
    
    private var position: CGPoint {
        let x = initialPosition.x + sin(phase + delay) * 50
        let y = initialPosition.y + cos(phase * 0.7 + delay) * 30
        return CGPoint(x: x, y: y)
    }
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.3),
                        Color(hex: "#4facfe").opacity(0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .position(position)
            .blur(radius: 2)
    }
}

// MARK: - Particle System
class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    private var timer: Timer?
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.createParticle()
            self.updateParticles()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func createParticle() {
        let particle = Particle(
            position: CGPoint(x: CGFloat.random(in: 0...UIScreen.main.bounds.width), y: UIScreen.main.bounds.height + 50),
            velocity: CGVector(dx: CGFloat.random(in: -20...20), dy: CGFloat.random(in: -100...-50)),
            size: CGFloat.random(in: 2...6),
            lifespan: Double.random(in: 3...5)
        )
        particles.append(particle)
    }
    
    private func updateParticles() {
        particles = particles.compactMap { particle in
            var updatedParticle = particle
            updatedParticle.position.x += updatedParticle.velocity.dx * 0.016
            updatedParticle.position.y += updatedParticle.velocity.dy * 0.016
            updatedParticle.lifespan -= 0.016
            
            return updatedParticle.lifespan > 0 ? updatedParticle : nil
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var size: CGFloat
    var lifespan: Double
}

struct ParticleSystemView: View {
    @ObservedObject var system: ParticleSystem
    
    var body: some View {
        Canvas { context, size in
            for particle in system.particles {
                let opacity = particle.lifespan / 5.0
                context.fill(
                    Circle().path(in: CGRect(
                        x: particle.position.x - particle.size / 2,
                        y: particle.position.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )),
                    with: .color(Color.white.opacity(opacity * 0.6))
                )
            }
        }
    }
}

// MARK: - Ripple Effect Layer
struct RippleEffectLayer: View {
    @State private var ripples: [Ripple] = []
    
    var body: some View {
        Canvas { context, size in
            for ripple in ripples {
                let opacity = 1.0 - (ripple.scale / 3.0)
                context.stroke(
                    Circle().path(in: CGRect(
                        x: ripple.position.x - ripple.radius * ripple.scale,
                        y: ripple.position.y - ripple.radius * ripple.scale,
                        width: ripple.radius * 2 * ripple.scale,
                        height: ripple.radius * 2 * ripple.scale
                    )),
                    with: .color(Color.white.opacity(opacity * 0.3)),
                    lineWidth: 2
                )
            }
        }
        .onTapGesture { location in
            createRipple(at: location)
        }
    }
    
    private func createRipple(at location: CGPoint) {
        let ripple = Ripple(position: location)
        ripples.append(ripple)
        
        withAnimation(.easeOut(duration: 1.5)) {
            if let index = ripples.firstIndex(where: { $0.id == ripple.id }) {
                ripples[index].scale = 3
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            ripples.removeAll { $0.id == ripple.id }
        }
    }
}

struct Ripple: Identifiable {
    let id = UUID()
    let position: CGPoint
    var scale: CGFloat = 0
    let radius: CGFloat = 50
}

// MARK: - Motion Observer
class MotionObserver: ObservableObject {
    @Published var x: Double = 0
    @Published var y: Double = 0
    
    private let manager = CMMotionManager()
    
    init() {
        manager.deviceMotionUpdateInterval = 0.1
        manager.startDeviceMotionUpdates(to: .main) { motion, error in
            guard let motion = motion else { return }
            self.x = motion.gravity.x
            self.y = motion.gravity.y
        }
    }
}

// MARK: - Parallax Effect Modifier
struct ParallaxEffect: ViewModifier {
    @ObservedObject var motion: MotionObserver
    
    func body(content: Content) -> some View {
        content
            .offset(
                x: CGFloat(motion.x * 20),
                y: CGFloat(motion.y * 20)
            )
            .animation(.interactiveSpring(), value: motion.x)
            .animation(.interactiveSpring(), value: motion.y)
    }
}

#Preview {
    MagicalBackground()
}