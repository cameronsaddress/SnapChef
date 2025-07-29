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
    let gravity: Double = 400  // Reduced gravity for spark-like fall
    let bounceDamping: Double = 0.65
    
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
                    .font(.system(size: 12))  // Smaller size
                    .position(x: emoji.position.x, y: emoji.position.y)
                    // Removed rotation to prevent circling appearance
            }
            
            // Debug: Show this is LaunchAnimationView
            VStack {
                Spacer()
                Text("Loading...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 100)
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
            var emojiCreationTimer: Timer?
            
            // Start physics animation
            let animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                DispatchQueue.main.async {
                    self.updatePhysics()
                    self.removeOffscreenEmojis()
                }
            }
            
            // Continuously create emojis like falling sparks
            emojiCreationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                // Create 1-3 emojis at a time
                let count = Int.random(in: 1...3)
                for _ in 0..<count {
                    let emoji = FallingEmoji(
                        position: CGPoint(
                            x: CGFloat.random(in: 20...screenWidth - 20),
                            y: CGFloat.random(in: -100 ... -20)  // Start just above screen
                        ),
                        velocity: CGVector(
                            dx: CGFloat.random(in: -15...15),  // Slight horizontal drift
                            dy: CGFloat.random(in: 60...100)  // Varied falling speeds
                        )
                    )
                    self.emojiAnimator.emojis.append(emoji)
                }
            }
            
            // End animation after exactly 4 seconds total (0.8s delay + 3.2s animation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                emojiCreationTimer?.invalidate()
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
    
    private func isCollidingWithTop(emoji: FallingEmoji, with rect: CGRect) -> Bool {
        // Check if emoji is within horizontal bounds of letter
        let emojiLeft = emoji.position.x - 6
        let emojiRight = emoji.position.x + 6
        
        if emojiLeft < rect.maxX && emojiRight > rect.minX {
            // Check if emoji bottom is touching letter top
            let emojiBottom = emoji.position.y + 6
            return emojiBottom >= rect.minY && emojiBottom <= rect.minY + 20 && emoji.velocity.dy > 0
        }
        return false
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