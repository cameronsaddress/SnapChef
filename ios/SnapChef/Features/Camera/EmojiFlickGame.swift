import SwiftUI

// MARK: - Game Models
struct FlickableEmoji: Identifiable {
    let id = UUID()
    let emoji: String
    var position: CGPoint
    var velocity: CGVector
    var rotation: Double = 0
    var scale: CGFloat = 1.0
    var isBeingDragged = false
    var isDraggable = true
    var hasBeenFlicked = false
}

struct ScoreAnimation: Identifiable {
    let id = UUID()
    let points: Int
    let position: CGPoint
    var opacity: Double = 1.0
    var offset: CGFloat = 0
}

struct BasketHitEffect: Identifiable {
    let id = UUID()
    let position: CGPoint
}

// MARK: - Tutorial Finger View
struct TutorialFinger: View {
    @State private var fingerOffset: CGFloat = 0
    @State private var fingerOpacity: Double = 1
    let startPosition: CGPoint
    
    var body: some View {
        Image(systemName: "hand.point.up.fill")
            .font(.system(size: 50))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.3), radius: 10)
            .position(startPosition)
            .offset(y: fingerOffset)
            .opacity(fingerOpacity)
            .onAppear {
                // Animate the finger moving up
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    fingerOffset = -150
                    fingerOpacity = 0
                }
            }
    }
}

// MARK: - Grocery Basket View
struct GroceryBasket: View {
    let isHit: Bool
    @State private var bounceScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Basket glow when hit
            if isHit {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#43e97b").opacity(0.6),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(bounceScale)
            }
            
            // Basket icon
            Image(systemName: "basket.fill")
                .font(.system(size: 60, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#43e97b"),
                            Color(hex: "#38f9d7")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(bounceScale)
                .shadow(color: .black.opacity(0.3), radius: 5)
        }
        .onChange(of: isHit) { newValue in
            if newValue {
                // Bounce animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    bounceScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        bounceScale = 1.0
                    }
                }
            }
        }
    }
}

// MARK: - Score Display
struct ScoreDisplay: View {
    let score: Int
    let highScore: Int
    @Binding var showNewHighScore: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current Score
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#ffa726"))
                
                Text("\(score)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: score)
            }
            
            // High Score
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(showNewHighScore ? Color(hex: "#f093fb") : Color.white.opacity(0.6))
                
                Text("Best: \(highScore)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(showNewHighScore ? Color(hex: "#f093fb") : Color.white.opacity(0.6))
            }
            .scaleEffect(showNewHighScore ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showNewHighScore)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            showNewHighScore ? 
                            Color(hex: "#f093fb").opacity(0.6) : 
                            Color.white.opacity(0.2),
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: showNewHighScore ? Color(hex: "#f093fb").opacity(0.3) : .clear, radius: 20)
    }
}

// MARK: - Main Game View
struct EmojiFlickGameOverlay: View {
    @State private var emojis: [FlickableEmoji] = []
    @State private var score = 0
    @State private var highScore = UserDefaults.standard.integer(forKey: "EmojiFlickHighScore")
    @State private var showNewHighScore = false
    @State private var scoreAnimations: [ScoreAnimation] = []
    @State private var basketHitEffects: [BasketHitEffect] = []
    @State private var basketPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: 80)
    @State private var isBasketHit = false
    @State private var showTutorial = true
    @State private var tutorialEmojisShown = 0
    @State private var showShareSheet = false
    @State private var draggedEmoji: FlickableEmoji?
    @State private var messageIndex = 0
    
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
                
                // Main content
                VStack {
                    // Top area with basket and score
                    HStack {
                        ScoreDisplay(
                            score: score, 
                            highScore: highScore, 
                            showNewHighScore: $showNewHighScore
                        )
                        
                        Spacer()
                        
                        // Basket
                        GroceryBasket(isHit: isBasketHit)
                            .position(x: basketPosition.x - 120, y: 0)
                    }
                    .padding(.top, 50)
                    .frame(height: 100)
                    
                    Spacer()
                    
                    // SNAPCHEF text in the center
                    ZStack {
                        // Glow effect
                        Text("SNAPCHEF")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "#667eea"))
                            .blur(radius: 20)
                            .opacity(0.6)
                        
                        // Main text
                        Text("SNAPCHEF")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#667eea"),
                                        Color(hex: "#764ba2")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    // Loading message
                    Text(messages[messageIndex])
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.bottom, 100)
                    
                    Spacer()
                }
                
                // Falling and draggable emojis
                ForEach(emojis) { emoji in
                    Text(emoji.emoji)
                        .font(.system(size: 36))
                        .scaleEffect(emoji.scale)
                        .rotationEffect(.degrees(emoji.rotation))
                        .position(emoji.position)
                        .opacity(emoji.hasBeenFlicked ? 0.8 : 1.0)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if emoji.isDraggable && !emoji.hasBeenFlicked {
                                        if let index = emojis.firstIndex(where: { $0.id == emoji.id }) {
                                            emojis[index].position = value.location
                                            emojis[index].isBeingDragged = true
                                            draggedEmoji = emojis[index]
                                            
                                            // Hide tutorial on first drag
                                            if showTutorial {
                                                showTutorial = false
                                            }
                                        }
                                    }
                                }
                                .onEnded { value in
                                    if let index = emojis.firstIndex(where: { $0.id == emoji.id }) {
                                        // Calculate flick velocity
                                        let velocity = CGVector(
                                            dx: value.predictedEndLocation.x - value.location.x,
                                            dy: value.predictedEndLocation.y - value.location.y
                                        )
                                        
                                        // Apply flick physics
                                        emojis[index].velocity = CGVector(
                                            dx: velocity.dx * 0.1,
                                            dy: velocity.dy * 0.1
                                        )
                                        emojis[index].isBeingDragged = false
                                        emojis[index].hasBeenFlicked = true
                                        emojis[index].isDraggable = false
                                        
                                        // Award point for flicking
                                        addScore(1, at: emojis[index].position)
                                        
                                        // Haptic feedback
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                    }
                                    draggedEmoji = nil
                                }
                        )
                }
                
                // Tutorial finger
                if showTutorial && tutorialEmojisShown < 3 {
                    if let firstEmoji = emojis.first(where: { !$0.hasBeenFlicked }) {
                        TutorialFinger(startPosition: firstEmoji.position)
                    }
                }
                
                // Score animations
                ForEach(scoreAnimations) { animation in
                    Text("+\(animation.points)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(animation.points == 5 ? Color(hex: "#43e97b") : Color(hex: "#ffa726"))
                        .position(animation.position)
                        .offset(y: animation.offset)
                        .opacity(animation.opacity)
                }
                
                // Basket hit effects
                ForEach(basketHitEffects) { effect in
                    GameParticleExplosion(position: effect.position)
                }
            }
            .onAppear {
                startGame(in: geometry.size)
            }
            .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
                updatePhysics(in: geometry.size)
                updateAnimations()
            }
            .onReceive(Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()) { _ in
                addNewEmoji(in: geometry.size)
            }
            .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
                withAnimation {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
            .sheet(isPresented: $showShareSheet) {
                GameShareSheet(score: highScore)
            }
        }
    }
    
    private func startGame(in size: CGSize) {
        // Initialize basket position
        basketPosition = CGPoint(x: size.width / 2, y: 80)
        
        // Add initial emojis
        for _ in 0..<3 {
            addNewEmoji(in: size)
        }
    }
    
    private func addNewEmoji(in size: CGSize) {
        let emoji = FlickableEmoji(
            emoji: foodEmojis.randomElement()!,
            position: CGPoint(
                x: CGFloat.random(in: 50...(size.width - 50)),
                y: -50
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -1...1),
                dy: CGFloat.random(in: 5...8)
            ),
            isDraggable: true
        )
        emojis.append(emoji)
        
        // Track tutorial emojis
        if showTutorial {
            tutorialEmojisShown += 1
            if tutorialEmojisShown >= 3 {
                showTutorial = false
            }
        }
    }
    
    private func updatePhysics(in size: CGSize) {
        for index in emojis.indices {
            guard !emojis[index].isBeingDragged else { continue }
            
            // Apply gravity
            emojis[index].velocity.dy += 0.8
            
            // Update position
            emojis[index].position.x += emojis[index].velocity.dx
            emojis[index].position.y += emojis[index].velocity.dy
            
            // Update rotation for flicked emojis
            if emojis[index].hasBeenFlicked {
                emojis[index].rotation += Double(emojis[index].velocity.dx) * 2
            }
            
            // Check basket collision
            if emojis[index].hasBeenFlicked {
                let distance = hypot(
                    emojis[index].position.x - basketPosition.x,
                    emojis[index].position.y - basketPosition.y
                )
                
                if distance < 50 && emojis[index].velocity.dy < 0 {
                    // Hit the basket!
                    basketHit(at: emojis[index].position)
                    emojis.remove(at: index)
                    return
                }
            }
            
            // Bounce off walls
            if emojis[index].position.x < 20 || emojis[index].position.x > size.width - 20 {
                emojis[index].velocity.dx = -emojis[index].velocity.dx * 0.8
            }
            
            // Apply damping
            emojis[index].velocity.dx *= 0.99
        }
        
        // Remove off-screen emojis
        emojis.removeAll { $0.position.y > size.height + 100 }
    }
    
    private func updateAnimations() {
        // Update score animations
        for index in scoreAnimations.indices.reversed() {
            scoreAnimations[index].offset -= 2
            scoreAnimations[index].opacity -= 0.02
            
            if scoreAnimations[index].opacity <= 0 {
                scoreAnimations.remove(at: index)
            }
        }
        
        // Remove old basket hit effects
        basketHitEffects.removeAll { effect in
            // Remove after 0.5 seconds (30 frames)
            true
        }
    }
    
    private func addScore(_ points: Int, at position: CGPoint) {
        score += points
        
        // Check for new high score
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "EmojiFlickHighScore")
            
            if !showNewHighScore {
                showNewHighScore = true
                
                // Haptic celebration
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Offer to share after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showShareSheet = true
                }
            }
        }
        
        // Add score animation
        let animation = ScoreAnimation(
            points: points,
            position: position
        )
        scoreAnimations.append(animation)
    }
    
    private func basketHit(at position: CGPoint) {
        // Award 5 points
        addScore(5, at: basketPosition)
        
        // Visual feedback
        isBasketHit = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isBasketHit = false
        }
        
        // Add particle effect
        basketHitEffects.append(BasketHitEffect(position: basketPosition))
        
        // Strong haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
}

// MARK: - Particle Explosion Effect
struct GameParticleExplosion: View {
    let position: CGPoint
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var offset: CGSize
        var opacity: Double
        let color: Color
    }
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: 8, height: 8)
                    .offset(particle.offset)
                    .opacity(particle.opacity)
            }
        }
        .position(position)
        .onAppear {
            createParticles()
        }
    }
    
    private func createParticles() {
        for i in 0..<12 {
            let angle = Double(i) * 30 * .pi / 180
            let particle = Particle(
                offset: .zero,
                opacity: 1,
                color: [Color(hex: "#43e97b"), Color(hex: "#38f9d7"), Color.white].randomElement()!
            )
            particles.append(particle)
            
            withAnimation(.easeOut(duration: 0.6)) {
                if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                    particles[index].offset = CGSize(
                        width: cos(angle) * 100,
                        height: sin(angle) * 100
                    )
                    particles[index].opacity = 0
                }
            }
        }
    }
}

// MARK: - Game Share Sheet
struct GameShareSheet: View {
    let score: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                Text("🎉")
                    .font(.system(size: 80))
                
                Text("New High Score!")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "#f093fb"),
                                Color(hex: "#f5576c")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("\(score) points")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                Text("You're a flicking master! 🏆")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Button(action: shareScore) {
                    Label("Share Score", systemImage: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#f093fb"),
                                            Color(hex: "#f5576c")
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .padding(.horizontal, 40)
                
                Button("Maybe Later") {
                    dismiss()
                }
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MagicalBackground())
            .navigationBarHidden(true)
        }
    }
    
    private func shareScore() {
        let text = "I just scored \(score) points in SnapChef's Emoji Flick game! 🎮✨ Can you beat my score?"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
        
        dismiss()
    }
}

#Preview {
    EmojiFlickGameOverlay()
}