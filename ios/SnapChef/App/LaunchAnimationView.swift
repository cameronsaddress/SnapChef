import SwiftUI

struct FallingEmoji: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    let emoji: String
    var isSettled = false
    var hasBouncedOffLetter = false
    let shouldBounce: Bool // Only some emojis will bounce
}

@MainActor
final class EmojiAnimator: ObservableObject {
    @Published var emojis: [FallingEmoji] = []
}

struct LaunchAnimationView: View {
    @StateObject private var emojiAnimator = EmojiAnimator()
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var animationComplete = false

    let onAnimationComplete: () -> Void
    let gravity: Double = 600
    let bounceDamping: Double = 0.4
    let foodEmojis = ["🍕", "🍔", "🌮", "🍜", "🍝", "🥗", "🍣", "🥘", "🍛", "🥙", "🍱", "🥪", "🌯", "🍖", "🍗", "🥓", "🧀", "🥚", "🍳", "🥞", "🧇", "🥐", "🍞", "🥖", "🥨", "🥯", "🍟", "🥔", "🌽", "🥕", "🥦", "🥒", "🥬", "🍅", "🍆", "🥑", "🌶️", "🫑", "🥭", "🍇", "🍓", "🫐", "🍒", "🍑", "🍊", "🍋", "🍌", "🍉", "🍈", "🍏", "🍎", "🍐", "🥝"]

    var body: some View {
        ZStack {
            // Match MagicalBackground from EnhancedHomeView
            MagicalBackground()
                .ignoresSafeArea()

            // SNAPCHEF logo
            SnapchefLogo()
                .opacity(animationComplete ? 0 : 1)
                .animation(.easeOut(duration: 0.3), value: animationComplete)

            // Conditional falling food emojis
            if deviceManager.shouldShowParticles {
                ForEach(emojiAnimator.emojis.prefix(deviceManager.recommendedParticleCount)) { emoji in
                    Text(emoji.emoji)
                        .font(.system(size: 36))  // Larger but smaller than letters
                        .position(x: emoji.position.x, y: emoji.position.y)
                        .opacity(animationComplete ? 0 : 1)
                        .animation(.easeOut(duration: deviceManager.recommendedAnimationDuration), value: animationComplete)
                        // No rotation - emojis fall straight down
                }
            }
        }
        .onAppear {
            print("🔍 DEBUG: [LaunchAnimationView] appeared")
            if deviceManager.shouldShowParticles {
                startFallingEmojis()
            } else {
                // Skip animation and complete immediately
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onAnimationComplete()
                }
            }
        }
        .onTapGesture {
            // Skip animation on tap
            onAnimationComplete()
        }
    }

    @MainActor
    private func startFallingEmojis() {
        let screenWidth = UIScreen.main.bounds.width

        // Create initial emojis
        for i in 0..<10 {
            let emoji = FallingEmoji(
                position: CGPoint(
                    x: CGFloat.random(in: 30...screenWidth - 30),
                    y: CGFloat(i) * -100 - 50  // Stagger vertically
                ),
                velocity: CGVector(
                    dx: CGFloat.random(in: -20...20),
                    dy: CGFloat.random(in: 50...150)
                ),
                emoji: self.foodEmojis.randomElement() ?? "🍕",
                shouldBounce: false
            )
            self.emojiAnimator.emojis.append(emoji)
        }

        // Start physics updates
        Task { @MainActor in
            // Run physics simulation for 3 seconds
            for _ in 0..<180 { // 3 seconds at 60fps
                updatePhysics()
                removeOffscreenEmojis()
                try? await Task.sleep(nanoseconds: 16_666_667) // ~60fps
            }

            // Complete animation
            withAnimation(.easeOut(duration: 0.3)) {
                animationComplete = true
            }

            // Notify completion
            try? await Task.sleep(nanoseconds: 300_000_000)
            onAnimationComplete()
        }
    }

    private func removeOffscreenEmojis() {
        // Don't remove emojis - let them continue falling during entire animation
        // This creates a continuous rain effect
    }

    @MainActor
    private func updatePhysics() {
        let deltaTime = 0.016
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width

        for i in emojiAnimator.emojis.indices {
            // Skip if settled
            if emojiAnimator.emojis[i].isSettled {
                continue
            }

            // Apply gravity
            emojiAnimator.emojis[i].velocity.dy += gravity * deltaTime

            // Update position
            emojiAnimator.emojis[i].position.x += emojiAnimator.emojis[i].velocity.dx * deltaTime
            emojiAnimator.emojis[i].position.y += emojiAnimator.emojis[i].velocity.dy * deltaTime

            // Check collision with other emojis
            for j in emojiAnimator.emojis.indices where j != i {
                if checkEmojiCollision(i: i, j: j) {
                    resolveEmojiCollision(i: i, j: j)
                }
            }

            // Check floor collision - allow emojis to fall to the very bottom
            if emojiAnimator.emojis[i].position.y > screenHeight - 20 {
                emojiAnimator.emojis[i].position.y = screenHeight - 20
                emojiAnimator.emojis[i].velocity.dy *= -bounceDamping
                emojiAnimator.emojis[i].velocity.dx *= 0.7 // Friction

                // Settle if moving slowly
                if abs(emojiAnimator.emojis[i].velocity.dy) < 30 && abs(emojiAnimator.emojis[i].velocity.dx) < 30 {
                    emojiAnimator.emojis[i].velocity = .zero
                    emojiAnimator.emojis[i].isSettled = true
                }
            }

            // Keep within screen bounds
            if emojiAnimator.emojis[i].position.x < 20 {
                emojiAnimator.emojis[i].position.x = 20
                emojiAnimator.emojis[i].velocity.dx *= -bounceDamping
            } else if emojiAnimator.emojis[i].position.x > screenWidth - 20 {
                emojiAnimator.emojis[i].position.x = screenWidth - 20
                emojiAnimator.emojis[i].velocity.dx *= -bounceDamping
            }
        }
    }

    @MainActor
    private func checkEmojiCollision(i: Int, j: Int) -> Bool {
        let distance = hypot(
            emojiAnimator.emojis[i].position.x - emojiAnimator.emojis[j].position.x,
            emojiAnimator.emojis[i].position.y - emojiAnimator.emojis[j].position.y
        )
        return distance < 35 // Emoji radius ~17.5 each
    }

    @MainActor
    private func resolveEmojiCollision(i: Int, j: Int) {
        let dx = emojiAnimator.emojis[i].position.x - emojiAnimator.emojis[j].position.x
        let dy = emojiAnimator.emojis[i].position.y - emojiAnimator.emojis[j].position.y
        let distance = hypot(dx, dy)

        if distance == 0 { return }

        // Normalize
        let nx = dx / distance
        let ny = dy / distance

        // Separate emojis
        let overlap = 35 - distance
        emojiAnimator.emojis[i].position.x += nx * overlap * 0.5
        emojiAnimator.emojis[i].position.y += ny * overlap * 0.5
        emojiAnimator.emojis[j].position.x -= nx * overlap * 0.5
        emojiAnimator.emojis[j].position.y -= ny * overlap * 0.5

        // Exchange velocities (simplified)
        let v1 = emojiAnimator.emojis[i].velocity
        let v2 = emojiAnimator.emojis[j].velocity

        emojiAnimator.emojis[i].velocity.dx = v2.dx * 0.8
        emojiAnimator.emojis[i].velocity.dy = v2.dy * 0.8
        emojiAnimator.emojis[j].velocity.dx = v1.dx * 0.8
        emojiAnimator.emojis[j].velocity.dy = v1.dy * 0.8
    }
}

#Preview {
    LaunchAnimationView {
        print("Animation complete!")
    }
}
