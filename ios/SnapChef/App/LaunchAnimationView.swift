import SwiftUI

struct FallingEmoji: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var rotation: Double = 0
    var rotationSpeed: Double = Double.random(in: -360...360)
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
    let gravity: Double = 800  // Increased gravity for faster fall
    let bounceDamping: Double = 0.7
    
    var body: some View {
        ZStack {
            // Match MagicalBackground from EnhancedHomeView
            MagicalBackground()
                .ignoresSafeArea()
            
            // SnapChef letters
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
            
            // Falling emojis
            ForEach(emojiAnimator.emojis) { emoji in
                Text("✨")
                    .font(.system(size: 20))
                    .position(x: emoji.position.x, y: emoji.position.y)
                    .rotationEffect(.degrees(emoji.rotation))
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
            // Create emojis all at once, spread across the screen width
            let screenWidth = UIScreen.main.bounds.width
            let emojiCount = 30
            
            // Create all emojis at once to simulate bucket dump
            for i in 0..<emojiCount {
                let emoji = FallingEmoji(
                    position: CGPoint(
                        x: CGFloat.random(in: 20...screenWidth - 20),
                        y: CGFloat.random(in: -200 ... -50)  // Start above screen
                    ),
                    velocity: CGVector(
                        dx: CGFloat.random(in: -10...10),  // Minimal horizontal movement
                        dy: CGFloat.random(in: 100...150)  // Strong downward velocity
                    )
                )
                emojiAnimator.emojis.append(emoji)
            }
            
            // Start physics animation
            let animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                DispatchQueue.main.async {
                    updatePhysics()
                }
            }
            
            // End animation after exactly 3 seconds total (0.8s delay + 2.2s animation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
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
    
    private func updatePhysics() {
        let deltaTime = 0.016
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width
        
        for i in emojiAnimator.emojis.indices {
            // Apply gravity
            emojiAnimator.emojis[i].velocity.dy += gravity * deltaTime
            
            // Update position
            emojiAnimator.emojis[i].position.x += emojiAnimator.emojis[i].velocity.dx * deltaTime
            emojiAnimator.emojis[i].position.y += emojiAnimator.emojis[i].velocity.dy * deltaTime
            
            // Update rotation
            emojiAnimator.emojis[i].rotation += emojiAnimator.emojis[i].rotationSpeed * deltaTime
            
            // Check collision with letters
            for letterBound in letterBounds {
                if letterBound != .zero && isColliding(emoji: emojiAnimator.emojis[i], with: letterBound) {
                    // Bounce off letter
                    let bounceDirection = getBounceDirection(emoji: emojiAnimator.emojis[i], rect: letterBound)
                    emojiAnimator.emojis[i].velocity.dx = bounceDirection.dx * bounceDamping
                    emojiAnimator.emojis[i].velocity.dy = abs(bounceDirection.dy) * bounceDamping * -1
                    
                    // Move emoji outside collision
                    emojiAnimator.emojis[i].position.y = letterBound.minY - 20
                }
            }
            
            // Check floor collision
            if emojiAnimator.emojis[i].position.y > screenHeight - 50 {
                emojiAnimator.emojis[i].position.y = screenHeight - 50
                emojiAnimator.emojis[i].velocity.dy *= -bounceDamping
                emojiAnimator.emojis[i].velocity.dx *= 0.8 // Friction
                
                // Stop tiny bounces
                if abs(emojiAnimator.emojis[i].velocity.dy) < 50 {
                    emojiAnimator.emojis[i].velocity.dy = 0
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
    
    private func isColliding(emoji: FallingEmoji, with rect: CGRect) -> Bool {
        let emojiRect = CGRect(
            x: emoji.position.x - 10,
            y: emoji.position.y - 10,
            width: 20,
            height: 20
        )
        return emojiRect.intersects(rect)
    }
    
    private func getBounceDirection(emoji: FallingEmoji, rect: CGRect) -> CGVector {
        let centerX = rect.midX
        let centerY = rect.midY
        
        let dx = emoji.position.x - centerX
        let dy = emoji.position.y - centerY
        
        let magnitude = sqrt(dx * dx + dy * dy)
        
        return CGVector(
            dx: (dx / magnitude) * 200,
            dy: (dy / magnitude) * 200
        )
    }
}

#Preview {
    LaunchAnimationView {
        print("Animation complete!")
    }
}