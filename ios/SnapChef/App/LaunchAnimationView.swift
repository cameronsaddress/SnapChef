import SwiftUI

struct FallingEmoji: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    let emoji: String
    var isSettled = false
}

class EmojiAnimator: ObservableObject {
    @Published var emojis: [FallingEmoji] = []
}

struct LaunchAnimationView: View {
    @State private var letterOpacities: [Double] = Array(repeating: 0, count: 8)
    @State private var letterScales: [CGFloat] = Array(repeating: 0.5, count: 8)
    @StateObject private var emojiAnimator = EmojiAnimator()
    @State private var animationComplete = false
    @State private var letterBounds: [CGRect] = Array(repeating: .zero, count: 8)
    
    let letters = ["S", "n", "a", "p", "C", "h", "e", "f"]
    let onAnimationComplete: () -> Void
    let gravity: Double = 600
    let bounceDamping: Double = 0.4
    let foodEmojis = ["🍕", "🍔", "🌮", "🍜", "🍝", "🥗", "🍣", "🥘", "🍛", "🥙", "🍱", "🥪", "🌯", "🍖", "🍗", "🥓", "🧀", "🥚", "🍳", "🥞", "🧇", "🥐", "🍞", "🥖", "🥨", "🥯", "🍟", "🥔", "🌽", "🥕", "🥦", "🥒", "🥬", "🍅", "🍆", "🥑", "🌶️", "🫑", "🥭", "🍇", "🍓", "🫐", "🍒", "🍑", "🍊", "🍋", "🍌", "🍉", "🍈", "🍏", "🍎", "🍐", "🥝"]
    
    var body: some View {
        ZStack {
            // Match MagicalBackground from EnhancedHomeView
            MagicalBackground()
                .ignoresSafeArea()
            
            // SnapChef letters with sparkle emoji
            ZStack {
                HStack(spacing: 2) {
                    ForEach(0..<letters.count, id: \.self) { index in
                        Text(letters[index])
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.9)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .opacity(letterOpacities[index])
                            .scaleEffect(letterScales[index])
                            .animation(
                                .spring(
                                    response: 0.4,
                                    dampingFraction: 0.7,
                                    blendDuration: 0
                                ).delay(Double(index) * 0.08),
                                value: letterOpacities[index]
                            )
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            letterBounds[index] = geometry.frame(in: .global)
                                        }
                                        .onChange(of: geometry.frame(in: .global)) { newFrame in
                                            letterBounds[index] = newFrame
                                        }
                                }
                            )
                    }
                }
                
                // Sparkle emoji
                Text("✨")
                    .font(.system(size: 36))
                    .offset(x: 110, y: -20)
                    .opacity(letterOpacities[7])
                    .scaleEffect(letterScales[7])
                    .animation(
                        .spring(
                            response: 0.4,
                            dampingFraction: 0.7,
                            blendDuration: 0
                        ).delay(0.64),
                        value: letterOpacities[7]
                    )
            }
            
            // Falling food emojis
            ForEach(emojiAnimator.emojis) { emoji in
                Text(emoji.emoji)
                    .font(.system(size: 36))  // Larger but smaller than letters
                    .position(x: emoji.position.x, y: emoji.position.y)
                    // No rotation - emojis fall straight down
            }
        }
        .onAppear {
            animateLetters()
            startFallingEmojis()
        }
    }
    
    private func animateLetters() {
        // Animate each letter popping in
        for index in 0..<letters.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                letterOpacities[index] = 1.0
                letterScales[index] = 1.0
            }
        }
    }
    
    private func startFallingEmojis() {
        // Wait for letters to appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let screenWidth = UIScreen.main.bounds.width
            
            // Start physics animation
            let animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                DispatchQueue.main.async {
                    self.updatePhysics()
                    self.removeOffscreenEmojis()
                }
            }
            
            // Drop first 3 emojis randomly within 1.5 seconds
            for _ in 0..<3 {
                let delay = Double.random(in: 0...1.5)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let emoji = FallingEmoji(
                        position: CGPoint(
                            x: CGFloat.random(in: 30...screenWidth - 30),
                            y: -50
                        ),
                        velocity: CGVector(
                            dx: CGFloat.random(in: -20...20),
                            dy: CGFloat.random(in: 50...150)
                        ),
                        emoji: self.foodEmojis.randomElement() ?? "🍕"
                    )
                    self.emojiAnimator.emojis.append(emoji)
                }
            }
            
            // After 1.5 seconds, drop all the rest
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // Create a burst of emojis
                for _ in 0..<40 {
                    let emoji = FallingEmoji(
                        position: CGPoint(
                            x: CGFloat.random(in: 20...screenWidth - 20),
                            y: CGFloat.random(in: -200 ... -50)
                        ),
                        velocity: CGVector(
                            dx: CGFloat.random(in: -30...30),
                            dy: CGFloat.random(in: 100...200)
                        ),
                        emoji: self.foodEmojis.randomElement() ?? "🍕"
                    )
                    self.emojiAnimator.emojis.append(emoji)
                }
            }
            
            // End animation after exactly 4 seconds total (0.8s delay + 3.2s animation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                animationTimer.invalidate()
                
                withAnimation(.easeOut(duration: 0.3)) {
                    animationComplete = true
                }
                
                // Notify completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onAnimationComplete()
                }
            }
        }
    }
    
    private func removeOffscreenEmojis() {
        let screenHeight = UIScreen.main.bounds.height
        emojiAnimator.emojis.removeAll { emoji in
            emoji.position.y > screenHeight + 50
        }
    }
    
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
            
            // Check collision with letters
            for letterBound in letterBounds {
                if letterBound != .zero && isCollidingWithTop(emoji: emojiAnimator.emojis[i], with: letterBound) {
                    // Bounce off top of letter
                    emojiAnimator.emojis[i].velocity.dy = -abs(emojiAnimator.emojis[i].velocity.dy) * bounceDamping
                    emojiAnimator.emojis[i].velocity.dx += CGFloat.random(in: -50...50) // Add some random horizontal bounce
                    
                    // Move emoji to top of letter
                    emojiAnimator.emojis[i].position.y = letterBound.minY - 10
                }
            }
            
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
    
    private func isCollidingWithTop(emoji: FallingEmoji, with rect: CGRect) -> Bool {
        // Check if emoji is within horizontal bounds of letter
        let emojiLeft = emoji.position.x - 18
        let emojiRight = emoji.position.x + 18
        
        if emojiLeft < rect.maxX && emojiRight > rect.minX {
            // Check if emoji bottom is touching letter top
            let emojiBottom = emoji.position.y + 18
            return emojiBottom >= rect.minY && emojiBottom <= rect.minY + 25 && emoji.velocity.dy > 0
        }
        return false
    }
    
    private func checkEmojiCollision(i: Int, j: Int) -> Bool {
        let distance = hypot(
            emojiAnimator.emojis[i].position.x - emojiAnimator.emojis[j].position.x,
            emojiAnimator.emojis[i].position.y - emojiAnimator.emojis[j].position.y
        )
        return distance < 35 // Emoji radius ~17.5 each
    }
    
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