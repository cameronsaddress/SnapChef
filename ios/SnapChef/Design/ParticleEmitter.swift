import SwiftUI
import Combine

// MARK: - Particle Emitter System
class ParticleEmitter: NSObject, ObservableObject {
    @Published var particles: [EmitterParticle] = []
    private var particlePool: [EmitterParticle] = []
    private var cancellables = Set<AnyCancellable>()
    private var displayLink: CADisplayLink?

    // Configuration
    var configuration: EmitterConfiguration
    var isEmitting: Bool = false
    private var lastEmissionTime: TimeInterval = 0
    private var isLowPowerMode: Bool = false
    private var maxActiveParticles: Int = 200
    private var deviceCapabilities: DeviceCapabilities
    private var frameRateTarget: Int = 60
    private var lastFrameTime: TimeInterval = 0
    private var frameDropCounter: Int = 0
    
    // Performance throttling
    private var particleThrottleRatio: Float = 1.0
    private var shouldUpdateParticles: Bool = true
    private var updateCounter: Int = 0

    init(configuration: EmitterConfiguration = .trail, deviceManager: DeviceManager? = nil) {
        self.configuration = configuration
        
        // Initialize with default capabilities - we'll update on main actor if needed
        self.deviceCapabilities = DeviceCapabilities.default
        
        // For isolated properties, use ProcessInfo as fallback since we can't access main actor here
        self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        super.init()
        
        setupPerformanceSettings(deviceManager: deviceManager)
        setupParticlePool()
        setupPerformanceMonitoring()
    }
    
    private func setupPerformanceSettings(deviceManager: DeviceManager?) {
        let deviceType = deviceCapabilities.deviceType
        
        switch deviceType {
        case .highEnd:
            maxActiveParticles = isLowPowerMode ? 50 : 200
            frameRateTarget = 60
            particleThrottleRatio = 1.0
        case .midRange:
            maxActiveParticles = isLowPowerMode ? 25 : 100
            frameRateTarget = 45
            particleThrottleRatio = 0.7
        case .lowEnd:
            maxActiveParticles = isLowPowerMode ? 10 : 50
            frameRateTarget = 30
            particleThrottleRatio = 0.4
        }
        
        // Override with device manager settings if available
        // Note: We'll update these asynchronously on the main actor if needed
        // For now, use the default settings from device capabilities
    }
    
    private func setupPerformanceMonitoring() {
        // Monitor performance and adjust particle count dynamically
        _ = Timer.scheduledTimer(
            timeInterval: 2.0,
            target: self,
            selector: #selector(handlePerformanceMonitoringTick),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func handlePerformanceMonitoringTick() {
        adjustPerformanceSettings()
    }
    
    private func adjustPerformanceSettings() {
        // If we're dropping frames, reduce particle count
        if frameDropCounter > 5 {
            particleThrottleRatio = max(0.2, particleThrottleRatio * 0.8)
            frameDropCounter = 0
        } else if frameDropCounter == 0 && particleThrottleRatio < 1.0 {
            // Gradually increase if performance is good
            particleThrottleRatio = min(1.0, particleThrottleRatio * 1.1)
        }
    }

    // MARK: - Particle Pool Management
    private func setupParticlePool() {
        // Pre-allocate particles for better performance
        let poolSize = min(maxActiveParticles * 2, isLowPowerMode ? 100 : 400)
        particlePool.reserveCapacity(poolSize)
        for _ in 0..<poolSize {
            particlePool.append(EmitterParticle())
        }
    }

    private func getParticleFromPool() -> EmitterParticle? {
        if let particle = particlePool.first(where: { !$0.isActive }) {
            return particle
        }
        // Create new particle if pool is exhausted
        let newParticle = EmitterParticle()
        particlePool.append(newParticle)
        return newParticle
    }

    // MARK: - Emission Control
    func startEmitting() {
        isEmitting = true
        setupDisplayLink()
    }

    func stopEmitting() {
        isEmitting = false
        displayLink?.invalidate()
        displayLink = nil
    }

    func emit(at position: CGPoint, velocity: CGVector = .zero) {
        // Apply throttling based on performance
        guard Float.random(in: 0...1) <= particleThrottleRatio else { return }
        
        // Limit particles based on performance mode
        let currentLimit = Int(Float(maxActiveParticles) * particleThrottleRatio)
        guard particles.count < currentLimit else { return }
        guard let particle = getParticleFromPool() else { return }

        let angle = CGFloat.random(in: 0...(2 * .pi))
        let speed = CGFloat.random(in: configuration.speedRange)
        let spreadAngle = configuration.spread * (.pi / 180)
        let finalAngle = angle + CGFloat.random(in: -spreadAngle...spreadAngle)
        
        // Adjust properties based on device capabilities and power mode
        let performanceMultiplier = deviceCapabilities.performanceMultiplier * particleThrottleRatio
        let adjustedLifetime = configuration.lifetime * (isLowPowerMode ? 0.5 : 1.0) * Double(performanceMultiplier)
        let adjustedSize = configuration.baseSize * (isLowPowerMode ? 0.7 : 1.0) * CGFloat(performanceMultiplier)

        particle.reset(
            position: position,
            velocity: CGVector(
                dx: cos(finalAngle) * speed + velocity.dx * configuration.velocityInheritance,
                dy: sin(finalAngle) * speed + velocity.dy * configuration.velocityInheritance
            ),
            color: configuration.colors.randomElement() ?? .white,
            size: adjustedSize * CGFloat.random(in: (1 - configuration.sizeVariation)...(1 + configuration.sizeVariation)),
            lifetime: adjustedLifetime,
            rotation: CGFloat.random(in: 0...(2 * .pi)),
            rotationSpeed: CGFloat.random(in: -configuration.rotationSpeed...configuration.rotationSpeed)
        )

        particles.append(particle)
    }

    // MARK: - Update Loop
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func update() {
        let currentTime = CACurrentMediaTime()
        let frameDelta = currentTime - lastFrameTime
        
        // Monitor frame rate and adjust accordingly
        let expectedFrameTime = 1.0 / Double(frameRateTarget)
        if frameDelta > expectedFrameTime * 1.5 {
            frameDropCounter += 1
        } else {
            frameDropCounter = max(0, frameDropCounter - 1)
        }
        
        lastFrameTime = currentTime
        
        // Throttle updates based on performance
        updateCounter += 1
        shouldUpdateParticles = updateCounter % max(1, Int(1.0 / particleThrottleRatio)) == 0
        
        let deltaTime = currentTime - lastEmissionTime
        
        // Adjust emission rate based on power mode and performance
        let baseEmissionRate = configuration.emissionRate
        let adjustedEmissionRate = Int(Float(baseEmissionRate) * particleThrottleRatio * (isLowPowerMode ? 0.5 : 1.0))

        // Emit new particles
        if isEmitting && adjustedEmissionRate > 0 && deltaTime > (1.0 / Double(adjustedEmissionRate)) {
            emit(at: configuration.emissionPoint)
            lastEmissionTime = currentTime
        }

        // Update existing particles with adaptive frame rate
        if shouldUpdateParticles {
            let updateRate = 1.0 / Double(frameRateTarget)
            updateParticles(deltaTime: updateRate)
        }
    }

    private func updateParticles(deltaTime: TimeInterval) {
        // Use removeAll with closure for better performance
        particles.removeAll { particle in
            particle.update(deltaTime: deltaTime, configuration: configuration)
            return !particle.isActive
        }
    }
}

// MARK: - Particle Model
class EmitterParticle: Identifiable, ObservableObject {
    let id = UUID()
    @Published var position: CGPoint = .zero
    @Published var velocity: CGVector = .zero
    @Published var color: Color = .white
    @Published var size: CGFloat = 10
    @Published var opacity: Double = 1.0
    @Published var scale: CGFloat = 1.0
    @Published var rotation: CGFloat = 0
    @Published var blur: CGFloat = 0

    var lifetime: TimeInterval = 0
    var maxLifetime: TimeInterval = 1.0
    var rotationSpeed: CGFloat = 0
    var isActive: Bool = false

    func reset(position: CGPoint, velocity: CGVector, color: Color, size: CGFloat, lifetime: TimeInterval, rotation: CGFloat, rotationSpeed: CGFloat) {
        self.position = position
        self.velocity = velocity
        self.color = color
        self.size = size
        self.lifetime = lifetime
        self.maxLifetime = lifetime
        self.opacity = 1.0
        self.scale = 1.0
        self.rotation = rotation
        self.rotationSpeed = rotationSpeed
        self.blur = 0
        self.isActive = true
    }

    func update(deltaTime: TimeInterval, configuration: EmitterConfiguration) {
        guard isActive else { return }

        // Update lifetime
        lifetime -= deltaTime
        if lifetime <= 0 {
            isActive = false
            return
        }

        // Update position
        position.x += velocity.dx * deltaTime
        position.y += velocity.dy * deltaTime

        // Apply gravity
        velocity.dy += configuration.gravity * deltaTime

        // Apply drag
        velocity.dx *= (1 - configuration.drag * deltaTime)
        velocity.dy *= (1 - configuration.drag * deltaTime)

        // Update rotation
        rotation += rotationSpeed * deltaTime

        // Update visual properties
        let lifeRatio = lifetime / maxLifetime
        opacity = configuration.fadeOut ? Double(lifeRatio) : 1.0
        scale = configuration.scaleOverTime.evaluate(at: 1 - lifeRatio)
        blur = configuration.blurOverTime ? (1 - lifeRatio) * 5 : 0
    }
}

// MARK: - Configuration
struct EmitterConfiguration {
    var emissionRate: Int = 30
    var emissionPoint: CGPoint = .zero
    var lifetime: TimeInterval = 1.0
    var baseSize: CGFloat = 10
    var sizeVariation: CGFloat = 0.3
    var speedRange: ClosedRange<CGFloat> = 50...150
    var spread: CGFloat = 30 // degrees
    var colors: [Color] = [.white]
    var velocityInheritance: CGFloat = 0.3
    var gravity: CGFloat = 0
    var drag: CGFloat = 0.1
    var rotationSpeed: CGFloat = 2.0
    var fadeOut: Bool = true
    var blurOverTime: Bool = false
    var scaleOverTime: AnimationCurve = .linear

    // Presets
    static let trail = EmitterConfiguration(
        emissionRate: 30,
        lifetime: 0.8,
        baseSize: 8,
        speedRange: 20...80,
        spread: 15,
        colors: [.yellow, .orange, .pink],
        gravity: -50,
        fadeOut: true
    )

    static let explosion = EmitterConfiguration(
        emissionRate: 0, // Manual emission
        lifetime: 1.2,
        baseSize: 12,
        speedRange: 100...400,
        spread: 360,
        colors: [.orange, .red, .yellow],
        gravity: 300,
        fadeOut: true,
        scaleOverTime: .easeOut
    )

    static let ambient = EmitterConfiguration(
        emissionRate: 2,
        lifetime: 5.0,
        baseSize: 4,
        speedRange: 10...30,
        spread: 360,
        colors: [.white.opacity(0.3), .blue.opacity(0.2)],
        gravity: -20,
        fadeOut: true,
        blurOverTime: true
    )
}

// MARK: - Animation Curves
enum AnimationCurve {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case bounce

    func evaluate(at progress: CGFloat) -> CGFloat {
        let t = max(0, min(1, progress))

        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t
        case .easeOut:
            return 1 - (1 - t) * (1 - t)
        case .easeInOut:
            return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        case .bounce:
            if t < 0.5 {
                return 8 * t * t
            } else {
                let f = t - 1
                return 1 + 8 * f * f
            }
        }
    }
}

// MARK: - Particle Emitter View
struct ParticleEmitterView: View {
    @ObservedObject var emitter: ParticleEmitter

    var body: some View {
        Canvas { context, _ in
            for particle in emitter.particles {
                guard particle.isActive else { continue }

                var particleContext = context

                // Apply transformations
                particleContext.translateBy(x: particle.position.x, y: particle.position.y)
                particleContext.rotate(by: Angle(radians: Double(particle.rotation)))
                particleContext.scaleBy(x: particle.scale, y: particle.scale)
                particleContext.opacity = particle.opacity

                // Apply blur if needed
                if particle.blur > 0 {
                    particleContext.addFilter(.blur(radius: particle.blur))
                }

                // Draw particle
                let rect = CGRect(
                    x: -particle.size / 2,
                    y: -particle.size / 2,
                    width: particle.size,
                    height: particle.size
                )

                particleContext.fill(
                    Circle().path(in: rect),
                    with: .color(particle.color)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

//MARK: - Device Capabilities
struct DeviceCapabilities {
    enum DeviceType {
        case highEnd
        case midRange
        case lowEnd
    }
    
    let deviceType: DeviceType
    let performanceMultiplier: Float
    
    // Static default for non-main-actor initialization
    static let `default` = DeviceCapabilities(deviceType: .midRange, performanceMultiplier: 0.7)
    
    private init(deviceType: DeviceType, performanceMultiplier: Float) {
        self.deviceType = deviceType
        self.performanceMultiplier = performanceMultiplier
    }
    
    @MainActor init() {
        let deviceModel = UIDevice.current.model
        
        // Detect device capabilities based on model and processor count
        if deviceModel.contains("iPhone") {
            if ProcessInfo.processInfo.processorCount >= 6 {
                deviceType = .highEnd
                performanceMultiplier = 1.0
            } else if ProcessInfo.processInfo.processorCount >= 4 {
                deviceType = .midRange
                performanceMultiplier = 0.7
            } else {
                deviceType = .lowEnd
                performanceMultiplier = 0.4
            }
        } else {
            // iPad or other devices - assume higher performance
            deviceType = .highEnd
            performanceMultiplier = 1.0
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black

        ParticleEmitterView(emitter: {
            let emitter = ParticleEmitter(configuration: .explosion)
            emitter.configuration.emissionPoint = CGPoint(x: 200, y: 400)
            emitter.startEmitting()
            return emitter
        }())
    }
    .ignoresSafeArea()
}
