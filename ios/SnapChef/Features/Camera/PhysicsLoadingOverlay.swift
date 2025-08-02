import SwiftUI

// MARK: - Falling Emoji Model
struct PhysicsFallingEmoji: Identifiable {
    let id = UUID()
    let emoji: String
    var position: CGPoint
    var velocity: CGVector
    var rotation: Double = 0
    var scale: CGFloat = 1.0
}


// MARK: - Physics Loading Overlay
struct PhysicsLoadingOverlay: View {
    @State private var fallingEmojis: [PhysicsFallingEmoji] = []
    @State private var messageIndex = 0
    @State private var textOpacity = 0.0
    @State private var textScale: CGFloat = 0.8
    
    let messages = [
        "Analyzing ingredients...",
        "Discovering recipes...",
        "Adding magic touches...",
        "Almost ready..."
    ]
    
    let foodEmojis = ["🍎", "🥕", "🍊", "🥦", "🍇", "🧀", "🥚", "🍞", "🥛", "🍗", 
                      "🍖", "🥗", "🍕", "🌮", "🍝", "🥘", "🍱", "🍜", "🧁", "🍪"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark overlay
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                VStack(spacing: 50) {
                    Spacer()
                    
                    // SnapChef logo in the center
                    SnapchefLogo()
                        .scaleEffect(textScale)
                        .opacity(textOpacity)
                    
                    // Animated loading message
                    Text(messages[messageIndex])
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                        .id(messageIndex)
                    
                    Spacer()
                }
                
                // Falling emojis
                ForEach(fallingEmojis) { emoji in
                    Text(emoji.emoji)
                        .font(.system(size: 32))
                        .position(emoji.position)
                        // No rotation - emojis fall straight down
                        .scaleEffect(emoji.scale)
                }
            }
            .onAppear {
                startAnimations(in: geometry.size)
            }
            .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
                updatePhysics(in: geometry.size)
            }
            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
                addNewEmoji(in: geometry.size)
            }
            .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
                withAnimation {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
    }
    
    private func startAnimations(in size: CGSize) {
        // Animate text appearance
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            textOpacity = 1.0
            textScale = 1.0
        }
        
        // Initialize some falling emojis
        for _ in 0..<5 {
            addNewEmoji(in: size)
        }
    }
    
    private func addNewEmoji(in size: CGSize) {
        let emoji = PhysicsFallingEmoji(
            emoji: foodEmojis.randomElement()!,
            position: CGPoint(
                x: CGFloat.random(in: 50...(size.width - 50)),
                y: -50
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -1...1),
                dy: CGFloat.random(in: 5...8)
            )
        )
        fallingEmojis.append(emoji)
        
        // Remove old emojis that are off screen
        fallingEmojis.removeAll { $0.position.y > size.height + 100 }
    }
    
    private func updatePhysics(in size: CGSize) {
        for index in fallingEmojis.indices {
            // Apply gravity (increased for better falling effect)
            fallingEmojis[index].velocity.dy += 0.8
            
            // Update position
            fallingEmojis[index].position.x += fallingEmojis[index].velocity.dx
            fallingEmojis[index].position.y += fallingEmojis[index].velocity.dy
            
            // Update rotation (removed - emojis should fall straight)
            // fallingEmojis[index].rotation += Double(fallingEmojis[index].velocity.dx) * 2
            
            
            // Bounce off walls
            if fallingEmojis[index].position.x < 20 || fallingEmojis[index].position.x > size.width - 20 {
                fallingEmojis[index].velocity.dx = -fallingEmojis[index].velocity.dx * 0.8
            }
            
            // Apply some damping
            fallingEmojis[index].velocity.dx *= 0.99
        }
    }
}

// MARK: - Emoji Flick Game Overlay
struct EmojiFlickGameOverlay: View {
    let capturedImage: UIImage?
    @State private var progress: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack {
                // AI Analyzing indicator with progress bar
                ZStack {
                    // Progress bar background
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                            .position(x: geometry.size.width / 2, y: 30)
                        
                        // Progress bar
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#667eea"),
                                        Color(hex: "#764ba2"),
                                        Color(hex: "#f093fb")
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 4)
                            .position(x: (geometry.size.width * progress) / 2, y: 30)
                            .animation(.linear(duration: 0.5), value: progress)
                    }
                    
                    // AI Analyzing indicator
                    AIAnalyzingIndicator()
                        .position(x: UIScreen.main.bounds.width / 2, y: 30)
                }
                .frame(height: 60)
                .padding(.top, 50)
                
                Spacer()
                
                // Embed the emoji flick game
                EmojiFlickGame(backgroundImage: capturedImage)
                    .frame(maxHeight: .infinity)
                
                Spacer()
                
                Text("Flick the falling ingredients!")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            // Start progress animation immediately
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 60)) {
                    progress = 1.0
                }
            }
        }
    }
}

// MARK: - Integration with MagicalProcessingOverlay
struct MagicalProcessingOverlay: View {
    let capturedImage: UIImage?
    @State private var useGameMode = true
    @State private var showAIProcessingView = true
    
    var body: some View {
        if useGameMode {
            if showAIProcessingView {
                AIProcessingView(onPlayGameTapped: {
                    // User tapped the play game button - transition immediately
                    withAnimation(.easeOut(duration: 0.3)) {
                        showAIProcessingView = false
                    }
                })
                .onAppear {
                    // Auto-hide AI processing view after 6 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showAIProcessingView = false
                        }
                    }
                }
            } else {
                EmojiFlickGameOverlay(capturedImage: capturedImage)
            }
        } else {
            PhysicsLoadingOverlay()
        }
    }
}

// Original implementation preserved
struct OriginalProcessingOverlay: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var messageIndex = 0
    
    let messages = [
        "Analyzing ingredients...",
        "Discovering recipes...",
        "Adding magic touches...",
        "Almost ready..."
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                ZStack {
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#667eea").opacity(0.8 - Double(index) * 0.2),
                                        Color(hex: "#764ba2").opacity(0.6 - Double(index) * 0.2),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 3
                            )
                            .frame(
                                width: CGFloat(80 + index * 30),
                                height: CGFloat(80 + index * 30)
                            )
                            .rotationEffect(.degrees(rotation + Double(index * 120)))
                    }
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(scale)
                }
                
                Text(messages[messageIndex])
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                    .id(messageIndex)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                scale = 1.2
            }
            
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                withAnimation {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
    }
}

#Preview {
    PhysicsLoadingOverlay()
}