import SwiftUI

// MARK: - Fire Particle
struct FireParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var color: Color
    var temperature: CGFloat // 0-1, affects color
    var size: CGFloat
    var opacity: Double = 1.0
    var age: Double = 0
    var lifespan: Double = 1.0
    var turbulence: CGFloat = 0
    
    mutating func update(deltaTime: Double) {
        age += deltaTime
        let progress = age / lifespan
        
        // Rise and spread
        velocity.dy -= 150 * deltaTime // Fire rises
        velocity.dx += sin(age * 10) * turbulence * deltaTime
        
        position.x += velocity.dx * deltaTime
        position.y += velocity.dy * deltaTime
        
        // Cool down (temperature affects color)
        temperature = max(0, temperature - 0.5 * deltaTime)
        
        // Fade and shrink
        opacity = 1.0 - progress
        size *= 0.98
    }
    
    var isAlive: Bool {
        opacity > 0.01 && size > 0.5
    }
    
    var fireColor: Color {
        if temperature > 0.8 {
            return Color.white
        } else if temperature > 0.6 {
            return Color(hex: "#fff59d")
        } else if temperature > 0.4 {
            return Color(hex: "#ffa726")
        } else if temperature > 0.2 {
            return Color(hex: "#ff5252")
        } else {
            return Color(hex: "#b71c1c")
        }
    }
}

// MARK: - Rainbow Trail
struct RainbowTrailParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var hue: Double
    var size: CGFloat
    var opacity: Double = 1.0
    var age: Double = 0
    var lifespan: Double = 0.5
    
    mutating func update(deltaTime: Double) {
        age += deltaTime
        opacity = 1.0 - (age / lifespan)
        size *= 0.95
    }
    
    var isAlive: Bool {
        opacity > 0.01
    }
    
    var color: Color {
        Color(hue: hue, saturation: 1.0, brightness: 1.0)
    }
}

// MARK: - Screen Edge Glow
struct ScreenEdgeGlow: View {
    let intensity: CGFloat
    let color: Color
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Top edge
                drawEdgeGlow(
                    in: &context,
                    rect: CGRect(x: 0, y: 0, width: size.width, height: 100),
                    edge: .top
                )
                
                // Bottom edge
                drawEdgeGlow(
                    in: &context,
                    rect: CGRect(x: 0, y: size.height - 100, width: size.width, height: 100),
                    edge: .bottom
                )
                
                // Left edge
                drawEdgeGlow(
                    in: &context,
                    rect: CGRect(x: 0, y: 0, width: 100, height: size.height),
                    edge: .leading
                )
                
                // Right edge
                drawEdgeGlow(
                    in: &context,
                    rect: CGRect(x: size.width - 100, y: 0, width: 100, height: size.height),
                    edge: .trailing
                )
            }
            .allowsHitTesting(false)
            .blendMode(.plusLighter)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = 1.0
            }
        }
    }
    
    private func drawEdgeGlow(in context: inout GraphicsContext, rect: CGRect, edge: Edge) {
        let gradient: Gradient
        let startPoint: CGPoint
        let endPoint: CGPoint
        
        switch edge {
        case .top:
            gradient = Gradient(colors: [color.opacity(intensity), Color.clear])
            startPoint = CGPoint(x: rect.midX, y: rect.minY)
            endPoint = CGPoint(x: rect.midX, y: rect.maxY)
        case .bottom:
            gradient = Gradient(colors: [Color.clear, color.opacity(intensity)])
            startPoint = CGPoint(x: rect.midX, y: rect.minY)
            endPoint = CGPoint(x: rect.midX, y: rect.maxY)
        case .leading:
            gradient = Gradient(colors: [color.opacity(intensity), Color.clear])
            startPoint = CGPoint(x: rect.minX, y: rect.midY)
            endPoint = CGPoint(x: rect.maxX, y: rect.midY)
        case .trailing:
            gradient = Gradient(colors: [Color.clear, color.opacity(intensity)])
            startPoint = CGPoint(x: rect.minX, y: rect.midY)
            endPoint = CGPoint(x: rect.maxX, y: rect.midY)
        }
        
        context.fill(
            Rectangle().path(in: rect),
            with: .linearGradient(gradient, startPoint: startPoint, endPoint: endPoint)
        )
        
        // Add pulsing lines
        let lineCount = 3
        for i in 0..<lineCount {
            let offset = (phase + CGFloat(i) / CGFloat(lineCount)).truncatingRemainder(dividingBy: 1.0)
            drawPulseLine(in: &context, rect: rect, edge: edge, offset: offset)
        }
    }
    
    private func drawPulseLine(in context: inout GraphicsContext, rect: CGRect, edge: Edge, offset: CGFloat) {
        context.opacity = (1.0 - offset) * 0.5
        
        let path: Path
        switch edge {
        case .top, .bottom:
            let y = edge == .top ? rect.minY + offset * rect.height : rect.maxY - offset * rect.height
            path = Path { p in
                p.move(to: CGPoint(x: rect.minX, y: y))
                p.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        case .leading, .trailing:
            let x = edge == .leading ? rect.minX + offset * rect.width : rect.maxX - offset * rect.width
            path = Path { p in
                p.move(to: CGPoint(x: x, y: rect.minY))
                p.addLine(to: CGPoint(x: x, y: rect.maxY))
            }
        }
        
        context.stroke(path, with: .color(color), lineWidth: 2)
    }
}

// MARK: - Particle Vortex
struct ParticleVortex: View {
    let center: CGPoint
    let intensity: CGFloat
    @State private var particles: [VortexParticle] = []
    @State private var rotation: Double = 0
    
    struct VortexParticle: Identifiable {
        let id = UUID()
        var angle: Double
        var radius: CGFloat
        var height: CGFloat
        var color: Color
        var size: CGFloat
    }
    
    var body: some View {
        Canvas { context, size in
            for particle in particles {
                let x = center.x + cos(particle.angle + rotation) * particle.radius
                let y = center.y + sin(particle.angle + rotation) * particle.radius * 0.5 - particle.height
                
                let rect = CGRect(
                    x: x - particle.size / 2,
                    y: y - particle.size / 2,
                    width: particle.size,
                    height: particle.size
                )
                
                context.opacity = 1.0 - (particle.height / 200)
                context.fill(Ellipse().path(in: rect), with: .radialGradient(
                    Gradient(colors: [
                        particle.color,
                        particle.color.opacity(0.5),
                        Color.clear
                    ]),
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    startRadius: 0,
                    endRadius: particle.size
                ))
            }
        }
        .onAppear {
            generateParticles()
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = .pi * 2
            }
        }
        .onChange(of: intensity) { _ in
            generateParticles()
        }
    }
    
    private func generateParticles() {
        particles.removeAll()
        
        let particleCount = Int(50 * intensity)
        for i in 0..<particleCount {
            let angle = (Double(i) / Double(particleCount)) * .pi * 2
            let heightFactor = CGFloat(i) / CGFloat(particleCount)
            
            particles.append(VortexParticle(
                angle: angle + Double.random(in: -0.2...0.2),
                radius: CGFloat.random(in: 20...80) * intensity,
                height: heightFactor * 200 * intensity,
                color: Color(hue: heightFactor, saturation: 1.0, brightness: 1.0),
                size: CGFloat.random(in: 4...12) * (1.0 - heightFactor * 0.5)
            ))
        }
    }
}

// MARK: - Combo Effect Manager
class ComboEffectManager: ObservableObject {
    @Published var fireParticles: [FireParticle] = []
    @Published var rainbowParticles: [RainbowTrailParticle] = []
    @Published var edgeGlowIntensity: CGFloat = 0
    @Published var vortexIntensity: CGFloat = 0
    
    private var displayLink: CADisplayLink?
    private var lastUpdateTime = Date()
    private var currentCombo: Int = 0
    private var fireEmissionTimer: Timer?
    
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
        
        // Update fire particles
        fireParticles = fireParticles.compactMap { particle in
            var updated = particle
            updated.update(deltaTime: deltaTime)
            return updated.isAlive ? updated : nil
        }
        
        // Update rainbow particles
        rainbowParticles = rainbowParticles.compactMap { particle in
            var updated = particle
            updated.update(deltaTime: deltaTime)
            return updated.isAlive ? updated : nil
        }
        
        objectWillChange.send()
    }
    
    func updateCombo(_ combo: Int, at position: CGPoint) {
        currentCombo = combo
        
        // Fire effect for combos > 5
        if combo > 5 {
            startFireEffect(at: position, intensity: min(CGFloat(combo - 5) / 10, 1.0))
        } else {
            stopFireEffect()
        }
        
        // Rainbow trail for combos > 10
        if combo > 10 {
            addRainbowBurst(at: position)
        }
        
        // Edge glow for combos > 15
        withAnimation(.easeInOut(duration: 0.5)) {
            edgeGlowIntensity = combo > 15 ? min(CGFloat(combo - 15) / 20, 1.0) : 0
        }
        
        // Vortex for combos > 20
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            vortexIntensity = combo > 20 ? min(CGFloat(combo - 20) / 30, 1.0) : 0
        }
    }
    
    private func startFireEffect(at position: CGPoint, intensity: CGFloat) {
        fireEmissionTimer?.invalidate()
        
        fireEmissionTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.emitFire(at: position, intensity: intensity)
        }
    }
    
    private func stopFireEffect() {
        fireEmissionTimer?.invalidate()
        fireEmissionTimer = nil
    }
    
    private func emitFire(at position: CGPoint, intensity: CGFloat) {
        let particleCount = Int(5 * intensity)
        
        for _ in 0..<particleCount {
            let angle = Double.random(in: -0.5...0.5) - .pi / 2 // Upward bias
            let speed = CGFloat.random(in: 50...150) * intensity
            
            let particle = FireParticle(
                position: CGPoint(
                    x: position.x + CGFloat.random(in: -20...20),
                    y: position.y
                ),
                velocity: CGVector(
                    dx: CGFloat(cos(angle)) * speed,
                    dy: CGFloat(sin(angle)) * speed
                ),
                color: .white,
                temperature: 1.0,
                size: CGFloat.random(in: 8...20) * intensity,
                lifespan: Double.random(in: 0.5...1.0),
                turbulence: CGFloat.random(in: 20...50)
            )
            
            fireParticles.append(particle)
        }
    }
    
    private func addRainbowBurst(at position: CGPoint) {
        let particleCount = 20
        
        for i in 0..<particleCount {
            let angle = (Double(i) / Double(particleCount)) * .pi * 2
            let radius = CGFloat.random(in: 10...30)
            
            let particle = RainbowTrailParticle(
                position: CGPoint(
                    x: position.x + CGFloat(cos(angle)) * radius,
                    y: position.y + CGFloat(sin(angle)) * radius
                ),
                hue: Double(i) / Double(particleCount),
                size: CGFloat.random(in: 6...12),
                lifespan: Double.random(in: 0.3...0.6)
            )
            
            rainbowParticles.append(particle)
        }
    }
    
    func reset() {
        currentCombo = 0
        stopFireEffect()
        fireParticles.removeAll()
        rainbowParticles.removeAll()
        
        withAnimation(.easeOut(duration: 0.3)) {
            edgeGlowIntensity = 0
            vortexIntensity = 0
        }
    }
    
    deinit {
        displayLink?.invalidate()
        fireEmissionTimer?.invalidate()
    }
}

// MARK: - Combo Effect View
struct ComboEffectView: View {
    @ObservedObject var manager: ComboEffectManager
    let screenSize: CGSize
    
    var body: some View {
        ZStack {
            // Screen edge glow
            if manager.edgeGlowIntensity > 0 {
                ScreenEdgeGlow(
                    intensity: manager.edgeGlowIntensity,
                    color: Color(hex: "#f093fb")
                )
                .transition(.opacity)
            }
            
            // Particle vortex
            if manager.vortexIntensity > 0 {
                ParticleVortex(
                    center: CGPoint(x: screenSize.width / 2, y: screenSize.height / 2),
                    intensity: manager.vortexIntensity
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Fire particles
            Canvas { context, size in
                for particle in manager.fireParticles {
                    drawFireParticle(particle, in: &context)
                }
                
                for particle in manager.rainbowParticles {
                    drawRainbowParticle(particle, in: &context)
                }
            }
            .allowsHitTesting(false)
            .blendMode(.plusLighter)
        }
    }
    
    private func drawFireParticle(_ particle: FireParticle, in context: inout GraphicsContext) {
        context.opacity = particle.opacity
        
        // Multi-layer fire effect
        for i in 0..<3 {
            let scale = 1.0 + CGFloat(i) * 0.5
            let opacity = particle.opacity / CGFloat(i + 1)
            
            let rect = CGRect(
                x: particle.position.x - particle.size * scale / 2,
                y: particle.position.y - particle.size * scale / 2,
                width: particle.size * scale,
                height: particle.size * scale
            )
            
            context.fill(Ellipse().path(in: rect), with: .radialGradient(
                Gradient(colors: [
                    particle.fireColor.opacity(opacity),
                    particle.fireColor.opacity(opacity * 0.5),
                    Color.clear
                ]),
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: 0,
                endRadius: particle.size * scale
            ))
        }
    }
    
    private func drawRainbowParticle(_ particle: RainbowTrailParticle, in context: inout GraphicsContext) {
        context.opacity = particle.opacity
        
        let rect = CGRect(
            x: particle.position.x - particle.size / 2,
            y: particle.position.y - particle.size / 2,
            width: particle.size,
            height: particle.size
        )
        
        context.fill(Circle().path(in: rect), with: .radialGradient(
            Gradient(colors: [
                particle.color,
                particle.color.opacity(0.5),
                Color.clear
            ]),
            center: CGPoint(x: rect.midX, y: rect.midY),
            startRadius: 0,
            endRadius: particle.size
        ))
    }
}

// MARK: - Combo Text Effect
struct ComboTextEffect: View {
    let combo: Int
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = -10
    @State private var offset: CGFloat = 20
    
    var body: some View {
        VStack(spacing: 0) {
            Text("\(combo)x")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: comboGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: comboGradient[0].opacity(0.5), radius: 20)
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
            
            Text("COMBO!")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .textCase(.uppercase)
                .tracking(2)
        }
        .scaleEffect(scale)
        .rotationEffect(.degrees(rotation))
        .offset(y: offset)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                scale = 1.0
                rotation = 0
                offset = 0
            }
        }
    }
    
    private var comboGradient: [Color] {
        switch combo {
        case 5...9: return [Color(hex: "#4facfe"), Color(hex: "#00f2fe")]
        case 10...14: return [Color(hex: "#f093fb"), Color(hex: "#f5576c")]
        case 15...19: return [Color(hex: "#fa709a"), Color(hex: "#fee140")]
        case 20...29: return [Color(hex: "#30cfd0"), Color(hex: "#330867")]
        default: return [Color(hex: "#ffa726"), Color(hex: "#fb8c00")]
        }
    }
}