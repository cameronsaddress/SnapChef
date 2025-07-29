import SwiftUI

struct FallingEmoji: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var rotation: Double = 0
    var rotationSpeed: Double = Double.random(in: -360...360)
}

struct LaunchAnimationView: View {
    @State private var letterOpacities: [Double] = Array(repeating: 0, count: 8)
    @State private var letterScales: [CGFloat] = Array(repeating: 0.5, count: 8)
    @State private var fallingEmojis: [FallingEmoji] = []
    @State private var animationComplete = false
    @State private var letterBounds: [CGRect] = Array(repeating: .zero, count: 8)
    
    let letters = ["S", "n", "a", "p", "C", "h", "e", "f"]
    let onAnimationComplete: () -> Void
    let gravity: Double = 500
    let bounceDamping: Double = 0.7
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "#667eea"),
                    Color(hex: "#764ba2")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
            ForEach(fallingEmojis) { emoji in
                Text("✨")
                    .font(.system(size: 20))
                    .position(emoji.position)
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
            // Create 20 falling emojis
            let screenWidth = UIScreen.main.bounds.width
            for i in 0..<20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    let emoji = FallingEmoji(
                        position: CGPoint(
                            x: CGFloat.random(in: 50...screenWidth - 50),
                            y: -50
                        ),
                        velocity: CGVector(
                            dx: CGFloat.random(in: -50...50),
                            dy: 0
                        )
                    )
                    fallingEmojis.append(emoji)
                }
            }
            
            // Start physics animation
            Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
                updatePhysics()
                
                // Check if all emojis have settled
                let allSettled = fallingEmojis.allSatisfy { emoji in
                    emoji.position.y > UIScreen.main.bounds.height - 100 &&
                    abs(emoji.velocity.dy) < 10
                }
                
                if allSettled {
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        }
    }
    
    private func updatePhysics() {
        let deltaTime = 0.016
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width
        
        for i in fallingEmojis.indices {
            // Apply gravity
            fallingEmojis[i].velocity.dy += gravity * deltaTime
            
            // Update position
            fallingEmojis[i].position.x += fallingEmojis[i].velocity.dx * deltaTime
            fallingEmojis[i].position.y += fallingEmojis[i].velocity.dy * deltaTime
            
            // Update rotation
            fallingEmojis[i].rotation += fallingEmojis[i].rotationSpeed * deltaTime
            
            // Check collision with letters
            for letterBound in letterBounds {
                if letterBound != .zero && isColliding(emoji: fallingEmojis[i], with: letterBound) {
                    // Bounce off letter
                    let bounceDirection = getBounceDirection(emoji: fallingEmojis[i], rect: letterBound)
                    fallingEmojis[i].velocity.dx = bounceDirection.dx * bounceDamping
                    fallingEmojis[i].velocity.dy = abs(bounceDirection.dy) * bounceDamping * -1
                    
                    // Move emoji outside collision
                    fallingEmojis[i].position.y = letterBound.minY - 20
                }
            }
            
            // Check floor collision
            if fallingEmojis[i].position.y > screenHeight - 50 {
                fallingEmojis[i].position.y = screenHeight - 50
                fallingEmojis[i].velocity.dy *= -bounceDamping
                fallingEmojis[i].velocity.dx *= 0.8 // Friction
                
                // Stop tiny bounces
                if abs(fallingEmojis[i].velocity.dy) < 50 {
                    fallingEmojis[i].velocity.dy = 0
                }
            }
            
            // Keep within screen bounds
            if fallingEmojis[i].position.x < 20 {
                fallingEmojis[i].position.x = 20
                fallingEmojis[i].velocity.dx *= -bounceDamping
            } else if fallingEmojis[i].position.x > screenWidth - 20 {
                fallingEmojis[i].position.x = screenWidth - 20
                fallingEmojis[i].velocity.dx *= -bounceDamping
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