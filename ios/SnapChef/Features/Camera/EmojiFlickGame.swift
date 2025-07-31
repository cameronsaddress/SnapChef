import SwiftUI
import AVFoundation

// MARK: - Emoji Flick Game
struct EmojiFlickGame: View {
    let backgroundImage: UIImage?
    
    @State private var gameState = GameState()
    @State private var emojis: [GameEmoji] = []
    @State private var particles: [GameParticle] = []
    @State private var scorePopups: [ScorePopup] = []
    @State private var screenShake: CGFloat = 0
    @State private var touchSparks: [TouchSpark] = []
    @State private var swipeTrails: [SwipeTrail] = []
    @State private var backgroundDragPath: [CGPoint] = []
    @State private var showTutorial = true
    @State private var tutorialOpacity: Double = 1.0
    @State private var tutorialFingerPosition = CGPoint(x: 100, y: 300)
    // Haptic feedback is handled via static methods
    
    init(backgroundImage: UIImage? = nil) {
        self.backgroundImage = backgroundImage
    }
    
    // Special effects
    @State private var magneticFieldActive = false
    @State private var timeSlowActive = false
    @State private var comboFlameActive = false
    
    // Timers
    let gameTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect() // 60 FPS
    let spawnTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(hex: "#1a1a2e"),
                        Color(hex: "#0f0f1e")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Captured fridge image as transparent background
                if let backgroundImage = backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(0.3)
                        .blur(radius: 5)
                        .clipped()
                        .ignoresSafeArea()
                }
                
                // Ambient particles
                ForEach(particles.filter { $0.type == .ambient }) { particle in
                    ParticleView(particle: particle)
                }
                
                // Time slow overlay
                if timeSlowActive {
                    Color.blue.opacity(0.1)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.5), value: timeSlowActive)
                }
                
                // Magnetic field visualization
                if magneticFieldActive {
                    MagneticFieldView()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(0.3)
                }
                
                // Game content
                ZStack {
                    // Background touch detector
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    createTouchSpark(at: value.location)
                                    
                                    // Track drag path
                                    if backgroundDragPath.isEmpty {
                                        backgroundDragPath = [value.location]
                                    } else {
                                        backgroundDragPath.append(value.location)
                                        if backgroundDragPath.count > 20 {
                                            backgroundDragPath.removeFirst()
                                        }
                                        
                                        // Check if swipe line intersects any emoji
                                        if backgroundDragPath.count >= 2 {
                                            let lastPoint = backgroundDragPath[backgroundDragPath.count - 1]
                                            let prevPoint = backgroundDragPath[backgroundDragPath.count - 2]
                                            checkEmojiIntersection(from: prevPoint, to: lastPoint)
                                        }
                                    }
                                    updateSwipeTrail(points: backgroundDragPath)
                                }
                                .onEnded { _ in
                                    backgroundDragPath = []
                                }
                        )
                    
                    // Falling emojis
                    ForEach(emojis) { emoji in
                        SimpleFallingEmojiView(
                            emoji: emoji,
                            magneticFieldActive: magneticFieldActive
                        )
                    }
                    
                    // Particle effects
                    ForEach(particles.filter { $0.type != .ambient }) { particle in
                        ParticleView(particle: particle)
                    }
                    
                    // Score popups
                    ForEach(scorePopups) { popup in
                        ScorePopupView(popup: popup)
                    }
                    
                    // Swipe trails
                    ForEach(swipeTrails) { trail in
                        SwipeTrailView(trail: trail)
                    }
                    
                    // Touch sparks
                    ForEach(touchSparks) { spark in
                        TouchSparkView(spark: spark)
                    }
                }
                .offset(x: screenShake)
                .animation(.spring(response: 0.2, dampingFraction: 0.3), value: screenShake)
                
                // AI Analyzing indicator at top
                AIAnalyzingIndicator()
                    .position(x: geometry.size.width / 2, y: 30)
                
                // Animated scoreboard at bottom left
                AnimatedScoreboard(gameState: gameState)
                    .position(x: 120, y: geometry.size.height - 80)
                
                // Combo indicator at bottom right
                if gameState.combo > 0 {
                    ComboIndicator(combo: gameState.combo, multiplier: gameState.multiplier)
                        .position(x: geometry.size.width - 80, y: geometry.size.height - 80)
                }
                
                // Tutorial finger
                if showTutorial {
                    TutorialFingerView()
                        .position(tutorialFingerPosition)
                        .opacity(tutorialOpacity)
                        .allowsHitTesting(false)
                }
            }
        }
        .onReceive(gameTimer) { _ in
            updateGame()
        }
        .onReceive(spawnTimer) { _ in
            spawnEmoji()
        }
        .onAppear {
            spawnInitialEmojis()
            createAmbientParticles()
            startTutorialAnimation()
        }
    }
    
    // MARK: - Game Logic
    
    private func updateGame() {
        let timeMultiplier = timeSlowActive ? 0.3 : 1.0
        
        // Update emojis
        for i in emojis.indices.reversed() {
            emojis[i].position.y += emojis[i].velocity.dy * timeMultiplier
            emojis[i].position.x += emojis[i].velocity.dx * timeMultiplier
            emojis[i].rotation += emojis[i].rotationSpeed * timeMultiplier
            
            // Apply gravity (reduced for slower falling)
            if !emojis[i].isFlicked {
                emojis[i].velocity.dy += 25 * 0.016 * timeMultiplier // gravity
                // Apply air resistance (increased for slower motion)
                emojis[i].velocity.dx *= 0.98
                emojis[i].velocity.dy *= 0.98
            } else {
                // Flicked emojis have less gravity and less air resistance
                emojis[i].velocity.dy += 5 * 0.016 * timeMultiplier
                emojis[i].velocity.dx *= 0.995
                emojis[i].velocity.dy *= 0.995
                emojis[i].scale *= 0.98 // Shrink as they fly away
                emojis[i].rotationSpeed *= 1.1 // Spin faster
            }
            
            // Wall bounce
            if emojis[i].position.x <= 30 || emojis[i].position.x >= UIScreen.main.bounds.width - 30 {
                emojis[i].velocity.dx *= -0.7
                emojis[i].position.x = max(30, min(UIScreen.main.bounds.width - 30, emojis[i].position.x))
                HapticManager.impact(.light)
            }
            
            // Remove if off screen
            let offScreenBuffer: CGFloat = 200
            if emojis[i].position.y > UIScreen.main.bounds.height + offScreenBuffer ||
               emojis[i].position.y < -offScreenBuffer ||
               emojis[i].position.x < -offScreenBuffer ||
               emojis[i].position.x > UIScreen.main.bounds.width + offScreenBuffer ||
               emojis[i].scale < 0.1 {
                
                if !emojis[i].isFlicked && emojis[i].position.y > UIScreen.main.bounds.height {
                    // Reset combo only if emoji fell (not flicked)
                    if gameState.combo > 0 {
                        gameState.combo = 0
                        gameState.multiplier = 1
                    }
                }
                emojis.remove(at: i)
            }
        }
        
        // Update particles
        for i in particles.indices.reversed() {
            particles[i].lifetime -= 0.016
            particles[i].position.x += particles[i].velocity.dx * timeMultiplier
            particles[i].position.y += particles[i].velocity.dy * timeMultiplier
            particles[i].opacity = max(0, particles[i].lifetime / particles[i].maxLifetime)
            particles[i].scale = particles[i].baseScale * (0.5 + 0.5 * particles[i].opacity)
            
            if particles[i].lifetime <= 0 {
                particles.remove(at: i)
            }
        }
        
        // Update score popups
        for i in scorePopups.indices.reversed() {
            scorePopups[i].lifetime -= 0.016
            scorePopups[i].position.y -= 60 * 0.016 // Float up
            scorePopups[i].opacity = max(0, scorePopups[i].lifetime / 1.0)
            
            if scorePopups[i].lifetime <= 0 {
                scorePopups.remove(at: i)
            }
        }
        
        // Update screen shake
        if screenShake != 0 {
            screenShake *= 0.9
            if abs(screenShake) < 0.1 {
                screenShake = 0
            }
        }
        
        // Update touch sparks
        for i in touchSparks.indices.reversed() {
            touchSparks[i].lifetime -= 0.016
            touchSparks[i].scale *= 1.1
            touchSparks[i].opacity = max(0, touchSparks[i].lifetime / 0.5)
            
            if touchSparks[i].lifetime <= 0 {
                touchSparks.remove(at: i)
            }
        }
        
        // Update swipe trails
        for i in swipeTrails.indices.reversed() {
            swipeTrails[i].lifetime -= 0.016
            swipeTrails[i].opacity = max(0, swipeTrails[i].lifetime / 0.3)
            
            if swipeTrails[i].lifetime <= 0 {
                swipeTrails.remove(at: i)
            }
        }
    }
    
    private func handleEmojiFlick(emoji: GameEmoji, velocity: CGVector, position: CGPoint) {
        guard let index = emojis.firstIndex(where: { $0.id == emoji.id }) else { return }
        
        // Calculate flick power
        let flickPower = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        let minFlickPower: CGFloat = 200
        
        guard flickPower > minFlickPower else {
            // Too weak, just drop it
            return
        }
        
        // Apply flick velocity to emoji instead of removing it
        emojis[index].velocity = CGVector(
            dx: velocity.dx * 1.5,
            dy: velocity.dy * 1.5
        )
        emojis[index].isFlicked = true
        
        // Calculate score based on flick power
        let baseScore = emoji.isSpecial ? 20 : 10
        let speedBonus = min(2.0, 1.0 + (flickPower / 1000))
        let score = Int(Double(baseScore) * speedBonus * Double(gameState.multiplier))
        
        gameState.score += score
        if gameState.score > gameState.highScore {
            gameState.highScore = gameState.score
        }
        
        // Update combo
        gameState.combo += 1
        gameState.lastComboTime = Date()
        updateMultiplier()
        
        // Create effects
        createFlickEffects(at: position, velocity: velocity, emoji: emoji, score: score)
        
        // Create flick impact effect
        createFlickImpactEffect(at: position)
        
        // Haptic feedback based on flick strength
        if flickPower > 1000 {
            HapticManager.impact(.heavy)
        } else if flickPower > 500 {
            HapticManager.impact(.medium)
        } else {
            HapticManager.impact(.light)
        }
        
        // Handle special emoji effects
        if emoji.isSpecial {
            handleSpecialEmojiEffect(emoji: emoji, at: position)
        }
    }
    
    private func createFlickEffects(at position: CGPoint, velocity: CGVector, emoji: GameEmoji, score: Int) {
        // Trail particles (reduced for performance)
        let trailCount = 10
        for _ in 0..<trailCount {
            let angle = atan2(velocity.dy, velocity.dx) + .random(in: -0.5...0.5)
            let speed = CGFloat.random(in: 100...200)
            let particle = GameParticle(
                position: position,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                color: emoji.isSpecial ? .yellow : .white,
                size: CGFloat.random(in: 4...6),
                lifetime: 0.5,
                type: .trail
            )
            particles.append(particle)
        }
        
        // Score popup
        let popup = ScorePopup(
            position: position,
            value: score,
            color: gameState.combo > 10 ? .yellow : (gameState.combo > 5 ? .orange : .white)
        )
        scorePopups.append(popup)
        
        // Explosion for special emojis
        if emoji.isSpecial {
            createExplosion(at: position, intensity: .medium)
        }
    }
    
    private func createExplosion(at position: CGPoint, intensity: GameExplosionIntensity) {
        let particleCount = intensity.particleCount
        for _ in 0..<particleCount {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: intensity.speedRange)
            let particle = GameParticle(
                position: position,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                color: [.orange, .red, .yellow].randomElement()!,
                size: CGFloat.random(in: intensity.sizeRange),
                lifetime: intensity.lifetime,
                type: .explosion
            )
            particles.append(particle)
        }
        
        // Screen shake
        screenShake = intensity.shakeAmount
    }
    
    private func handleSpecialEmojiEffect(emoji: GameEmoji, at position: CGPoint) {
        switch emoji.emoji {
        case "🌟": // Golden star - bonus points
            createExplosion(at: position, intensity: .large)
            
        case "🍳": // Frying pan - clear nearby
            createExplosion(at: position, intensity: .mega)
            // Remove nearby emojis
            emojis.removeAll { other in
                let distance = sqrt(pow(other.position.x - position.x, 2) + pow(other.position.y - position.y, 2))
                return distance < 150 && other.id != emoji.id
            }
            
        case "🥘": // Pot - attract emojis
            magneticFieldActive = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                magneticFieldActive = false
            }
            
        case "🍯": // Honey - slow time
            timeSlowActive = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                timeSlowActive = false
            }
            
        default:
            break
        }
    }
    
    private func updateMultiplier() {
        // Update multiplier based on combo
        if gameState.combo >= 20 {
            gameState.multiplier = 5
        } else if gameState.combo >= 15 {
            gameState.multiplier = 4
        } else if gameState.combo >= 10 {
            gameState.multiplier = 3
        } else if gameState.combo >= 5 {
            gameState.multiplier = 2
        } else {
            gameState.multiplier = 1
        }
        
        // Activate combo effects
        comboFlameActive = gameState.combo >= 10
    }
    
    private func spawnEmoji() {
        let specialEmojis = ["🌟", "🍳", "🥘", "🍯"]
        let regularEmojis = ["🍕", "🍔", "🌮", "🍜", "🍱", "🥗", "🍰", "🍪", "🧁", "🍩", 
                           "🥐", "🥖", "🧀", "🍖", "🍗", "🥓", "🌭", "🍟", "🥙", "🌯",
                           "🥚", "🍳", "🥞", "🧇", "🥯", "🍞", "🥨", "🧈", "🥜", "🌰",
                           "🍄", "🥦", "🥒", "🌽", "🥕", "🥔", "🍠", "🌶️", "🥑", "🍆",
                           "🍅", "🥬", "🥭", "🍎", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓",
                           "🫐", "🍈", "🍒", "🍑", "🥝", "🍍", "🥥", "🍦", "🍧", "🍨",
                           "🍡", "🍢", "🍣", "🍤", "🍥", "🥮", "🍘", "🍙", "🍚", "🍛",
                           "🍝", "🍠", "🍲", "🍵", "☕", "🥛", "🍶", "🍾", "🧃", "🥤"]
        
        let isSpecial = Double.random(in: 0...1) < 0.2 // 20% chance for special
        let emoji = isSpecial ? specialEmojis.randomElement()! : regularEmojis.randomElement()!
        
        let newEmoji = GameEmoji(
            emoji: emoji,
            position: CGPoint(
                x: CGFloat.random(in: 50...(UIScreen.main.bounds.width - 50)),
                y: -50
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -5...5),
                dy: CGFloat.random(in: 2...8)
            ),
            isSpecial: isSpecial
        )
        
        emojis.append(newEmoji)
    }
    
    private func spawnInitialEmojis() {
        for _ in 0..<2 {
            spawnEmoji()
        }
    }
    
    private func createAmbientParticles() {
        // Create fewer floating background particles
        for _ in 0..<10 {
            let particle = GameParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                velocity: CGVector(
                    dx: CGFloat.random(in: -20...20),
                    dy: CGFloat.random(in: -30...(-10))
                ),
                color: .white,
                size: CGFloat.random(in: 2...3),
                lifetime: 10.0,
                type: .ambient
            )
            particles.append(particle)
        }
    }
    
    private func createTouchSpark(at position: CGPoint) {
        // Limit number of sparks
        if touchSparks.count > 5 {
            return
        }
        
        let spark = TouchSpark(
            position: position,
            color: [.white, .yellow, .cyan].randomElement()!
        )
        touchSparks.append(spark)
        
        // Create fewer particles for better performance
        for _ in 0..<3 {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 50...100)
            let particle = GameParticle(
                position: position,
                velocity: CGVector(
                    dx: cos(angle) * speed,
                    dy: sin(angle) * speed
                ),
                color: spark.color,
                size: CGFloat.random(in: 3...5),
                lifetime: 0.3,
                type: .trail
            )
            particles.append(particle)
        }
        
        // Limit total particles
        if particles.count > 100 {
            particles.removeFirst(particles.count - 100)
        }
    }
    
    private func updateSwipeTrail(points: [CGPoint]) {
        if points.count > 2 {
            swipeTrails.removeAll()
            let trail = SwipeTrail(
                points: points,
                color: [.white, .cyan, .yellow].randomElement()!
            )
            swipeTrails.append(trail)
        }
    }
    
    private func createFlickImpactEffect(at position: CGPoint) {
        // Create a larger spark at impact point
        let impactSpark = TouchSpark(
            position: position,
            scale: 1.5,
            lifetime: 0.8,
            color: .white
        )
        touchSparks.append(impactSpark)
        
        // Create ring explosion (reduced particles)
        for i in 0..<8 {
            let angle = (Double(i) / 8.0) * 2 * .pi
            let speed: CGFloat = 150
            let particle = GameParticle(
                position: position,
                velocity: CGVector(
                    dx: cos(angle) * speed,
                    dy: sin(angle) * speed
                ),
                color: [.white, .cyan, .yellow].randomElement()!,
                size: CGFloat.random(in: 6...10),
                lifetime: 0.4,
                type: .explosion
            )
            particles.append(particle)
        }
        
        // Add fewer sparkles
        for _ in 0..<8 {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 100...200)
            let particle = GameParticle(
                position: position,
                velocity: CGVector(
                    dx: cos(angle) * speed,
                    dy: sin(angle) * speed
                ),
                color: .white,
                size: CGFloat.random(in: 2...3),
                lifetime: Double.random(in: 0.3...0.6),
                type: .trail
            )
            particles.append(particle)
        }
    }
    
    private func checkEmojiIntersection(from: CGPoint, to: CGPoint) {
        let emojiRadius: CGFloat = 40 // Half of the 80pt font size
        
        for i in emojis.indices where !emojis[i].isFlicked {
            let emojiCenter = emojis[i].position
            
            // Check if line segment intersects with emoji circle
            if lineIntersectsCircle(lineStart: from, lineEnd: to, circleCenter: emojiCenter, radius: emojiRadius) {
                // Calculate flick velocity based on swipe direction
                let dx = to.x - from.x
                let dy = to.y - from.y
                let velocity = CGVector(dx: dx * 20, dy: dy * 20) // Scale up the velocity
                
                handleEmojiFlick(emoji: emojis[i], velocity: velocity, position: emojiCenter)
            }
        }
    }
    
    private func lineIntersectsCircle(lineStart: CGPoint, lineEnd: CGPoint, circleCenter: CGPoint, radius: CGFloat) -> Bool {
        // Calculate the closest point on the line segment to the circle center
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        
        if dx == 0 && dy == 0 {
            // Line start and end are the same point
            let distance = sqrt(pow(lineStart.x - circleCenter.x, 2) + pow(lineStart.y - circleCenter.y, 2))
            return distance <= radius
        }
        
        let t = max(0, min(1, ((circleCenter.x - lineStart.x) * dx + (circleCenter.y - lineStart.y) * dy) / (dx * dx + dy * dy)))
        
        let closestPoint = CGPoint(
            x: lineStart.x + t * dx,
            y: lineStart.y + t * dy
        )
        
        let distance = sqrt(pow(closestPoint.x - circleCenter.x, 2) + pow(closestPoint.y - circleCenter.y, 2))
        return distance <= radius
    }
    
    private func startTutorialAnimation() {
        guard showTutorial else { return }
        
        // Start finger visible on screen immediately
        tutorialFingerPosition = CGPoint(x: 200, y: 400)
        
        // Wait for emojis to reach middle of screen
        let screenHeight = UIScreen.main.bounds.height
        let targetMinY = screenHeight * 0.4
        let targetMaxY = screenHeight * 0.6
        
        // Check every 0.1 seconds for emojis at target position
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            // Find emojis in the middle zone
            let readyEmojis = self.emojis.filter { emoji in
                emoji.position.y >= targetMinY && emoji.position.y <= targetMaxY && !emoji.isFlicked
            }
            
            guard readyEmojis.count > 0 else { return }
            
            timer.invalidate()
            
            // Flick first emoji
            if let firstEmoji = readyEmojis.first {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.tutorialFingerPosition = CGPoint(
                        x: firstEmoji.position.x - 50,
                        y: firstEmoji.position.y
                    )
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.tutorialFingerPosition = CGPoint(
                            x: firstEmoji.position.x + 100,
                            y: firstEmoji.position.y - 50
                        )
                    }
                    
                    let velocity = CGVector(dx: 300, dy: -150)
                    self.handleEmojiFlick(emoji: firstEmoji, velocity: velocity, position: firstEmoji.position)
                }
            }
            
            // Flick second emoji
            if readyEmojis.count >= 2 {
                let secondEmoji = readyEmojis[1]
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.tutorialFingerPosition = CGPoint(
                            x: secondEmoji.position.x - 50,
                            y: secondEmoji.position.y
                        )
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.tutorialFingerPosition = CGPoint(
                                x: secondEmoji.position.x + 100,
                                y: secondEmoji.position.y - 50
                            )
                        }
                        
                        let velocity = CGVector(dx: 300, dy: -150)
                        self.handleEmojiFlick(emoji: secondEmoji, velocity: velocity, position: secondEmoji.position)
                    }
                }
            }
            
            // Flick third emoji
            if readyEmojis.count >= 3 {
                let thirdEmoji = readyEmojis[2]
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.tutorialFingerPosition = CGPoint(
                            x: thirdEmoji.position.x - 50,
                            y: thirdEmoji.position.y
                        )
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.tutorialFingerPosition = CGPoint(
                                x: thirdEmoji.position.x + 100,
                                y: thirdEmoji.position.y - 50
                            )
                        }
                        
                        let velocity = CGVector(dx: 300, dy: -150)
                        self.handleEmojiFlick(emoji: thirdEmoji, velocity: velocity, position: thirdEmoji.position)
                    }
                }
            }
            
            // Fade out tutorial
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.tutorialOpacity = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showTutorial = false
                }
            }
        }
    }
}

// MARK: - Data Models

struct GameState {
    var score: Int = 0
    var highScore: Int = UserDefaults.standard.integer(forKey: "emojiFlickHighScore")
    var combo: Int = 0
    var multiplier: Int = 1
    var lastComboTime: Date = Date()
    
    mutating func saveHighScore() {
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "emojiFlickHighScore")
        }
    }
}

struct GameEmoji: Identifiable {
    let id = UUID()
    var emoji: String
    var position: CGPoint
    var velocity: CGVector
    var rotation: Double = 0
    var rotationSpeed: Double = Double.random(in: -5...5)
    var scale: CGFloat = 1.0
    var isDragging: Bool = false
    var dragOffset: CGSize = .zero
    var isSpecial: Bool = false
    var isFlicked: Bool = false
}

struct GameParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var color: Color
    var size: CGFloat
    var lifetime: Double
    let maxLifetime: Double
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
    let baseScale: CGFloat = 1.0
    var type: ParticleType
    
    init(position: CGPoint, velocity: CGVector, color: Color, size: CGFloat, lifetime: Double, type: ParticleType) {
        self.position = position
        self.velocity = velocity
        self.color = color
        self.size = size
        self.lifetime = lifetime
        self.maxLifetime = lifetime
        self.type = type
    }
}

enum ParticleType {
    case trail, explosion, ambient
}

struct ScorePopup: Identifiable {
    let id = UUID()
    var position: CGPoint
    var value: Int
    var color: Color
    var lifetime: Double = 1.0
    var opacity: Double = 1.0
    var scale: CGFloat = 0.5
}

struct TouchSpark: Identifiable {
    let id = UUID()
    var position: CGPoint
    var scale: CGFloat = 0.5
    var opacity: Double = 1.0
    var lifetime: Double = 0.5
    var color: Color = .white
}

struct SwipeTrail: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var opacity: Double = 1.0
    var lifetime: Double = 0.3
    var color: Color = .white
}

enum GameExplosionIntensity {
    case small, medium, large, mega
    
    var particleCount: Int {
        switch self {
        case .small: return 12
        case .medium: return 24
        case .large: return 36
        case .mega: return 48
        }
    }
    
    var speedRange: ClosedRange<CGFloat> {
        switch self {
        case .small: return 50...150
        case .medium: return 100...250
        case .large: return 150...350
        case .mega: return 200...500
        }
    }
    
    var sizeRange: ClosedRange<CGFloat> {
        switch self {
        case .small: return 4...8
        case .medium: return 6...12
        case .large: return 8...16
        case .mega: return 10...20
        }
    }
    
    var lifetime: Double {
        switch self {
        case .small: return 0.6
        case .medium: return 0.8
        case .large: return 1.0
        case .mega: return 1.2
        }
    }
    
    var shakeAmount: CGFloat {
        switch self {
        case .small: return 5
        case .medium: return 10
        case .large: return 15
        case .mega: return 25
        }
    }
}

// MARK: - View Components

struct SimpleFallingEmojiView: View {
    let emoji: GameEmoji
    let magneticFieldActive: Bool
    @State private var glowAnimation: Bool = false
    
    var body: some View {
        Text(emoji.emoji)
            .font(.system(size: 80))
            .scaleEffect(emoji.scale)
            .rotationEffect(.degrees(emoji.rotation))
            .position(emoji.position)
            .shadow(color: emoji.isSpecial ? Color.yellow : Color.black.opacity(0.3), radius: 5)
            .overlay(
                // Special emoji glow
                emoji.isSpecial ?
                Circle()
                    .fill(Color.yellow.opacity(0.3))
                    .blur(radius: 40)
                    .scaleEffect(glowAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: glowAnimation)
                : nil
            )
            .allowsHitTesting(false) // No interaction needed
            .onAppear {
                if emoji.isSpecial {
                    glowAnimation = true
                }
            }
    }
}

struct FallingEmojiView: View {
    let emoji: GameEmoji
    let magneticFieldActive: Bool
    let onFlick: (CGVector, CGPoint) -> Void
    let onTouch: (CGPoint) -> Void
    let onDrag: ([CGPoint]) -> Void
    
    @State private var dragVelocity: CGVector = .zero
    @State private var lastDragPosition: CGPoint = .zero
    @State private var dragStartTime: Date = Date()
    @State private var isDragging: Bool = false
    @State private var glowAnimation: Bool = false
    @State private var dragPath: [CGPoint] = []
    
    var body: some View {
        Text(emoji.emoji)
            .font(.system(size: 80))
            .scaleEffect(emoji.scale)
            .rotationEffect(.degrees(emoji.rotation))
            .position(emoji.position)
            .shadow(color: emoji.isSpecial ? Color.yellow : Color.black.opacity(0.3), radius: 5)
            .overlay(
                // Special emoji glow
                emoji.isSpecial ?
                Circle()
                    .fill(Color.yellow.opacity(0.3))
                    .blur(radius: 40)
                    .scaleEffect(glowAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: glowAnimation)
                : nil
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartTime = Date()
                            lastDragPosition = value.location
                            dragPath = [value.location]
                            onTouch(value.location)
                        }
                        
                        let currentPosition = value.location
                        let timeDelta = Date().timeIntervalSince(dragStartTime)
                        
                        if timeDelta > 0 {
                            let dx = currentPosition.x - lastDragPosition.x
                            let dy = currentPosition.y - lastDragPosition.y
                            dragVelocity = CGVector(dx: dx / timeDelta, dy: dy / timeDelta)
                        }
                        
                        dragPath.append(currentPosition)
                        if dragPath.count > 20 {
                            dragPath.removeFirst()
                        }
                        onDrag(dragPath)
                        
                        lastDragPosition = currentPosition
                        dragStartTime = Date()
                    }
                    .onEnded { value in
                        isDragging = false
                        
                        // Calculate final velocity
                        let flickVelocity = CGVector(
                            dx: dragVelocity.dx * 0.8,
                            dy: dragVelocity.dy * 0.8
                        )
                        
                        onFlick(flickVelocity, value.location)
                    }
            )
            .onAppear {
                if emoji.isSpecial {
                    glowAnimation = true
                }
            }
    }
}

struct AnimatedScoreboard: View {
    let gameState: GameState
    @State private var scoreScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.6
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Score
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 20))
                
                Text("\(gameState.score)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .scaleEffect(scoreScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: gameState.score)
            }
            
            // High score
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                
                Text("BEST: \(gameState.highScore)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .pink, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .purple.opacity(glowOpacity), radius: 20)
        )
        .onChange(of: gameState.score) { _ in
            scoreScale = 1.2
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scoreScale = 1.0
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowOpacity = 0.3
            }
        }
    }
}

struct ComboIndicator: View {
    let combo: Int
    let multiplier: Int
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = 0
    
    var comboColor: Color {
        if combo >= 20 { return .red }
        if combo >= 15 { return .orange }
        if combo >= 10 { return .yellow }
        if combo >= 5 { return .green }
        return .blue
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(combo)")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            Text("×\(multiplier)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(comboColor)
        }
        .padding(16)
        .background(
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(comboColor, lineWidth: 3)
                )
        )
        .scaleEffect(scale)
        .rotationEffect(.degrees(rotation))
        .shadow(color: comboColor.opacity(0.6), radius: 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
            }
        }
        .onChange(of: combo) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.2
                rotation += 360
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) {
                scale = 1.0
            }
        }
    }
}

struct ParticleView: View {
    let particle: GameParticle
    
    var body: some View {
        Circle()
            .fill(particle.color)
            .frame(width: particle.size * particle.scale, height: particle.size * particle.scale)
            .opacity(particle.opacity)
            .position(particle.position)
            .blur(radius: particle.type == .ambient ? 2 : 0)
            .blendMode(particle.type == .explosion ? .plusLighter : .normal)
    }
}

struct ScorePopupView: View {
    let popup: ScorePopup
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        Text("+\(popup.value)")
            .font(.system(size: 32, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [popup.color, popup.color.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .scaleEffect(scale)
            .opacity(popup.opacity)
            .position(popup.position)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.2
                }
                withAnimation(.easeOut(duration: 0.2).delay(0.3)) {
                    scale = 1.0
                }
            }
    }
}

struct TouchSparkView: View {
    let spark: TouchSpark
    
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            spark.color.opacity(0.8),
                            spark.color.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 40 * spark.scale, height: 40 * spark.scale)
            
            // Inner bright core
            Circle()
                .fill(Color.white)
                .frame(width: 8 * spark.scale, height: 8 * spark.scale)
        }
        .opacity(spark.opacity)
        .position(spark.position)
        .allowsHitTesting(false)
    }
}

struct SwipeTrailView: View {
    let trail: SwipeTrail
    
    var body: some View {
        Canvas { context, size in
            guard trail.points.count > 2 else { return }
            
            var path = Path()
            path.move(to: trail.points[0])
            
            for i in 1..<trail.points.count {
                path.addLine(to: trail.points[i])
            }
            
            // Draw multiple strokes for glow effect
            for (index, width) in [12.0, 8.0, 4.0].enumerated() {
                let opacity = trail.opacity * (0.3 + 0.3 * Double(index))
                
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: trail.color.opacity(0), location: 0),
                            .init(color: trail.color.opacity(opacity * 0.5), location: 0.3),
                            .init(color: trail.color.opacity(opacity), location: 0.7),
                            .init(color: trail.color.opacity(opacity * 0.8), location: 1.0)
                        ]),
                        startPoint: trail.points.first ?? .zero,
                        endPoint: trail.points.last ?? .zero
                    ),
                    style: StrokeStyle(
                        lineWidth: width,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
            
            // Add bright core
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(trail.opacity * 0.6)
                    ]),
                    startPoint: trail.points.first ?? .zero,
                    endPoint: trail.points.last ?? .zero
                ),
                style: StrokeStyle(
                    lineWidth: 2,
                    lineCap: .round
                )
            )
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }
}

struct AIAnalyzingIndicator: View {
    @State private var dots = "."
    @State private var pulseScale: CGFloat = 1.0
    @State private var scannerOffset: CGFloat = -40
    @State private var scannerOpacity: Double = 0.8
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Main content
            HStack(spacing: 4) {
                Image(systemName: "brain")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(pulseScale)
                
                Text("AI Analyzing\(dots)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            
            // Scanner line effect
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0),
                            Color.cyan.opacity(scannerOpacity),
                            Color.white.opacity(scannerOpacity),
                            Color.cyan.opacity(scannerOpacity),
                            Color.cyan.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 100, height: 2)
                .blur(radius: 1)
                .offset(y: scannerOffset)
                .mask(
                    Capsule()
                        .padding(.horizontal, 8)
                )
        }
        .shadow(color: .purple.opacity(0.3), radius: 10)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                dots = dots.count >= 3 ? "." : dots + "."
            }
        }
        .onAppear {
            // Brain pulse animation
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
            
            // Scanner animation
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                scannerOffset = 40
            }
            
            // Scanner fade animation
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                scannerOpacity = 0.3
            }
        }
    }
}

struct TutorialFingerView: View {
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .scaleEffect(pulseScale)
            
            // Finger emoji
            Text("👆")
                .font(.system(size: 50))
                .rotationEffect(.degrees(45)) // Angle for swiping
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
        }
    }
}

struct MagneticFieldView: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .scaleEffect(scale + CGFloat(i) * 0.2)
                    .rotationEffect(.degrees(rotation + Double(i * 120)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scale = 1.2
            }
        }
    }
}

// MARK: - Preview
#Preview {
    EmojiFlickGame()
}