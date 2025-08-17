import SwiftUI
import SpriteKit

// MARK: - Reward Animation Type
enum RewardAnimationType {
    case confetti
    case coins
    case stars
    case fireworks
    case levelUp
    case achievement

    var particleImageName: String {
        switch self {
        case .confetti: return "confetti"
        case .coins: return "dollarsign.circle.fill"
        case .stars: return "star.fill"
        case .fireworks: return "sparkles"
        case .levelUp: return "arrow.up.circle.fill"
        case .achievement: return "medal.fill"
        }
    }

    var particleColors: [Color] {
        switch self {
        case .confetti:
            return [.red, .blue, .green, .yellow, .purple, .orange, .pink]
        case .coins:
            return [Color(hex: "#FFD700"), Color(hex: "#FFA500")]
        case .stars:
            return [.yellow, Color(hex: "#FFD700")]
        case .fireworks:
            return [.red, .white, .blue]
        case .levelUp:
            return [Color(hex: "#667eea"), Color(hex: "#764ba2")]
        case .achievement:
            return [Color(hex: "#f093fb"), Color(hex: "#f5576c")]
        }
    }
}

// MARK: - Confetti Scene
@MainActor
class ConfettiScene: SKScene {
    var animationType: RewardAnimationType = .confetti
    var emitterNode: SKEmitterNode?

    override func didMove(to view: SKView) {
        backgroundColor = .clear

        // Create emitter based on animation type
        emitterNode = createEmitter(for: animationType)
        if let emitterNode = emitterNode {
            emitterNode.position = CGPoint(x: size.width / 2, y: size.height)
            addChild(emitterNode)
        }
    }

    private func createEmitter(for type: RewardAnimationType) -> SKEmitterNode {
        let emitter = SKEmitterNode()

        switch type {
        case .confetti:
            configureConfettiEmitter(emitter)
        case .coins:
            configureCoinEmitter(emitter)
        case .stars:
            configureStarEmitter(emitter)
        case .fireworks:
            configureFireworksEmitter(emitter)
        case .levelUp:
            configureLevelUpEmitter(emitter)
        case .achievement:
            configureAchievementEmitter(emitter)
        }

        return emitter
    }

    private func configureConfettiEmitter(_ emitter: SKEmitterNode) {
        emitter.particleTexture = SKTexture(imageNamed: "confetti_particle")
        emitter.particleBirthRate = 100
        emitter.numParticlesToEmit = 0
        emitter.particleLifetime = 3
        emitter.particleLifetimeRange = 1
        emitter.particlePositionRange = CGVector(dx: frame.width, dy: 0)
        emitter.emissionAngle = .pi
        emitter.emissionAngleRange = .pi / 4
        emitter.particleSpeed = 200
        emitter.particleSpeedRange = 50
        emitter.particleAlpha = 0.8
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.3
        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.2
        emitter.particleScaleSpeed = -0.1
        emitter.particleRotation = 0
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = 2
        emitter.particleColorBlendFactor = 1
        emitter.particleColorSequence = createColorSequence()
        emitter.particleBlendMode = .alpha
    }

    private func configureCoinEmitter(_ emitter: SKEmitterNode) {
        emitter.particleTexture = SKTexture(systemImageName: "dollarsign.circle.fill")
        emitter.particleBirthRate = 30
        emitter.numParticlesToEmit = 50
        emitter.particleLifetime = 2
        emitter.particleLifetimeRange = 0.5
        emitter.particlePositionRange = CGVector(dx: 100, dy: 0)
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi / 6
        emitter.particleSpeed = 300
        emitter.particleSpeedRange = 100
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -0.5
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.1
        emitter.particleRotation = 0
        emitter.particleRotationSpeed = 5
        emitter.particleColor = SKColor(Color(hex: "#FFD700"))
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.yAcceleration = -500
    }

    private func configureStarEmitter(_ emitter: SKEmitterNode) {
        emitter.particleTexture = SKTexture(systemImageName: "star.fill")
        emitter.particleBirthRate = 50
        emitter.numParticlesToEmit = 0
        emitter.particleLifetime = 2.5
        emitter.particleLifetimeRange = 1
        emitter.particlePositionRange = CGVector(dx: frame.width, dy: 0)
        emitter.emissionAngle = .pi
        emitter.emissionAngleRange = .pi / 3
        emitter.particleSpeed = 150
        emitter.particleSpeedRange = 50
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -0.4
        emitter.particleScale = 0.2
        emitter.particleScaleRange = 0.2
        emitter.particleScaleSpeed = 0.3
        emitter.particleRotation = 0
        emitter.particleRotationSpeed = 3
        emitter.particleColor = SKColor.yellow
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
    }

    private func configureFireworksEmitter(_ emitter: SKEmitterNode) {
        emitter.particleTexture = SKTexture(systemImageName: "sparkles")
        emitter.particleBirthRate = 200
        emitter.numParticlesToEmit = 100
        emitter.particleLifetime = 1
        emitter.particleLifetimeRange = 0.5
        emitter.particlePositionRange = CGVector(dx: 50, dy: 50)
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 200
        emitter.particleSpeedRange = 100
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -1
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.2
        emitter.particleScaleSpeed = -0.3
        emitter.particleColorSequence = createFireworkColorSequence()
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.targetNode = self
    }

    private func configureLevelUpEmitter(_ emitter: SKEmitterNode) {
        emitter.particleTexture = SKTexture(systemImageName: "arrow.up.circle.fill")
        emitter.particleBirthRate = 20
        emitter.numParticlesToEmit = 30
        emitter.particleLifetime = 3
        emitter.particleLifetimeRange = 1
        emitter.particlePositionRange = CGVector(dx: 200, dy: 0)
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi / 6
        emitter.particleSpeed = 200
        emitter.particleSpeedRange = 50
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -0.3
        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.2
        emitter.particleScaleSpeed = 0.2
        emitter.particleColor = SKColor(Color(hex: "#667eea"))
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.yAcceleration = 100
    }

    private func configureAchievementEmitter(_ emitter: SKEmitterNode) {
        emitter.particleTexture = SKTexture(systemImageName: "medal.fill")
        emitter.particleBirthRate = 15
        emitter.numParticlesToEmit = 20
        emitter.particleLifetime = 4
        emitter.particleLifetimeRange = 1
        emitter.particlePositionRange = CGVector(dx: 150, dy: 0)
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi / 4
        emitter.particleSpeed = 150
        emitter.particleSpeedRange = 50
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -0.25
        emitter.particleScale = 0.4
        emitter.particleScaleRange = 0.2
        emitter.particleScaleSpeed = 0.1
        emitter.particleRotation = -.pi / 6
        emitter.particleRotationRange = .pi / 3
        emitter.particleRotationSpeed = 1
        emitter.particleColor = SKColor(Color(hex: "#f093fb"))
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
    }

    private func createColorSequence() -> SKKeyframeSequence {
        let colors: [SKColor] = [
            SKColor.red, SKColor.blue, SKColor.green,
            SKColor.yellow, SKColor.purple, SKColor.orange
        ]

        do {
            let keyframeSequence = SKKeyframeSequence(
                keyframeValues: colors,
                times: [0, 0.2, 0.4, 0.6, 0.8, 1.0]
            )

            let data = try NSKeyedArchiver.archivedData(
                withRootObject: keyframeSequence,
                requiringSecureCoding: false
            )

            let colorKeyframes = try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [SKKeyframeSequence.self, SKColor.self, NSNumber.self, NSArray.self],
                from: data
            ) as? SKKeyframeSequence

            return colorKeyframes ?? SKKeyframeSequence(keyframeValues: [SKColor.white], times: [0])
        } catch {
            return SKKeyframeSequence(keyframeValues: [SKColor.white], times: [0])
        }
    }

    private func createFireworkColorSequence() -> SKKeyframeSequence {
        let colors: [SKColor] = [
            SKColor.red, SKColor.white, SKColor.blue
        ]

        do {
            let keyframeSequence = SKKeyframeSequence(
                keyframeValues: colors,
                times: [0, 0.5, 1.0]
            )

            let data = try NSKeyedArchiver.archivedData(
                withRootObject: keyframeSequence,
                requiringSecureCoding: false
            )

            let colorKeyframes = try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [SKKeyframeSequence.self, SKColor.self, NSNumber.self, NSArray.self],
                from: data
            ) as? SKKeyframeSequence

            return colorKeyframes ?? SKKeyframeSequence(keyframeValues: [SKColor.white], times: [0])
        } catch {
            return SKKeyframeSequence(keyframeValues: [SKColor.white], times: [0])
        }
    }

    func stopEmitting() {
        emitterNode?.particleBirthRate = 0
    }
}

// MARK: - SKTexture Extension
extension SKTexture {
    convenience init(systemImageName: String) {
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .medium)
        let image = UIImage(systemName: systemImageName, withConfiguration: config) ?? UIImage()
        self.init(image: image)
    }
}

// MARK: - Reward Animation View
struct RewardAnimationView: View {
    let animationType: RewardAnimationType
    let duration: Double
    @State private var scene: ConfettiScene?
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            if let scene = scene {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if animationType == .levelUp {
                LevelUpAnimationOverlay()
                    .opacity(isAnimating ? 1 : 0)
                    .scaleEffect(isAnimating ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isAnimating)
            }
        }
        .onAppear {
            setupScene()
            startAnimation()
        }
    }

    private func setupScene() {
        let newScene = ConfettiScene()
        newScene.size = UIScreen.main.bounds.size
        newScene.scaleMode = .fill
        newScene.backgroundColor = .clear
        newScene.animationType = animationType
        scene = newScene
    }

    private func startAnimation() {
        isAnimating = true

        // Stop emitting after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            scene?.stopEmitting()
        }

        // Remove scene after particles fade
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 4) {
            scene = nil
        }
    }
}

// MARK: - Level Up Animation Overlay
struct LevelUpAnimationOverlay: View {
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(rotationAngle))
                .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 20)

            Text("LEVEL UP!")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#f093fb"), Color(hex: "#f5576c")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Challenge Reward Animator
@MainActor
final class ChallengeRewardAnimator: ObservableObject {
    // Fix for Swift concurrency issue with @MainActor singletons
    static let shared: ChallengeRewardAnimator = {
        let instance = ChallengeRewardAnimator()
        return instance
    }()

    @Published var currentAnimation: RewardAnimationType?
    @Published var isAnimating = false
    @Published var rewardMessage: String?
    @Published var rewardValue: String?
    @Published var tier: RewardTier?

    private init() {}

    /// Trigger reward animation
    func playRewardAnimation(
        type: RewardAnimationType,
        message: String? = nil,
        value: String? = nil,
        tier: RewardTier? = nil,
        duration: Double = 2.0
    ) {
        currentAnimation = type
        rewardMessage = message
        rewardValue = value
        self.tier = tier
        isAnimating = true

        // Auto-hide after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 2) {
            self.isAnimating = false
            self.currentAnimation = nil
            self.rewardMessage = nil
            self.rewardValue = nil
            self.tier = nil
        }
    }

    /// Play challenge completion animation
    func playChallengeCompletion(tier: RewardTier, coins: Int) {
        let animationType: RewardAnimationType
        let message: String

        switch tier {
        case .bronze:
            animationType = .stars
            message = "Challenge Complete!"
        case .silver:
            animationType = .confetti
            message = "Excellent Work!"
        case .gold:
            animationType = .fireworks
            message = "Perfect Score!"
        }

        playRewardAnimation(
            type: animationType,
            message: message,
            value: "+\(coins) Chef Coins",
            tier: tier
        )
    }

    /// Play level up animation
    func playLevelUp(newLevel: Int) {
        playRewardAnimation(
            type: .levelUp,
            message: "Level \(newLevel) Unlocked!",
            value: "New rewards available",
            duration: 3.0
        )
    }

    /// Play achievement animation
    func playAchievement(name: String) {
        playRewardAnimation(
            type: .achievement,
            message: "Achievement Unlocked!",
            value: name,
            duration: 3.0
        )
    }
}

// MARK: - Reward Animation Overlay
struct RewardAnimationOverlay: View {
    @ObservedObject var animator = ChallengeRewardAnimator.shared

    var body: some View {
        ZStack {
            if animator.isAnimating, let animationType = animator.currentAnimation {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                RewardAnimationView(
                    animationType: animationType,
                    duration: 2.0
                )

                if let message = animator.rewardMessage {
                    VStack(spacing: 16) {
                        if let tier = animator.tier {
                            Image(systemName: tier.icon)
                                .font(.system(size: 60))
                                .foregroundColor(tier.color)
                                .shadow(color: tier.color.opacity(0.5), radius: 20)
                        }

                        Text(message)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 10)

                        if let value = animator.rewardValue {
                            Text(value)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.5), radius: 5)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animator.isAnimating)
    }
}
