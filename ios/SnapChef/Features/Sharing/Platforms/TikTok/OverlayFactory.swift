// REPLACE ENTIRE FILE: OverlayFactory.swift

import UIKit
import AVFoundation
import QuartzCore

public final class OverlayFactory: @unchecked Sendable {
    private let config: RenderConfig
    public init(config: RenderConfig) { self.config = config }
    
    // PREMIUM ANIMATION STYLES
    public enum TextAnimationStyle {
        case typewriter(speed: Double)
        case glitch(intensity: CGFloat)
        case bounce(height: CGFloat)
        case kinetic(zoom: Bool)
        case gradient(colors: [UIColor])
        case glow(color: UIColor, intensity: CGFloat)
    }

    public func createHookOverlay(text: String, config: RenderConfig) -> CALayer {
        let L = CALayer(); L.frame = CGRect(origin: .zero, size: config.size)
        
        // Add professional sparkles behind text
        let sparkles = createParticleSystem(type: .professionalSparkles, intensity: 0.6)
        sparkles.position = CGPoint(x: config.size.width / 2, y: -50)
        sparkles.zPosition = -200
        L.addSublayer(sparkles)
        
        // Create gradient container for hook text
        let gradientContainer = createSnapChefGradientContainer(
            text: text,
            fontSize: config.hookFontSize,
            config: config,
            centered: true
        )
        gradientContainer.position = CGPoint(x: config.size.width / 2, y: config.size.height * 0.3)
        gradientContainer.zPosition = 0 // Text in middle layer
        
        // Add particle system for dramatic moment (foreground)
        let particles = createParticleSystem(type: .sparkle, intensity: 0.8)
        particles.position = CGPoint(x: config.size.width / 2, y: config.size.height / 2)
        particles.zPosition = 100
        L.addSublayer(particles)
        
        // Slide in animation from top
        let slideIn = createSlideInAnimation(from: .top, duration: 0.8)
        gradientContainer.add(slideIn, forKey: "slideIn")
        
        // Beat-synced pulse animation
        let beatPulse = createBeatSyncPulse(bpm: config.fallbackBPM)
        gradientContainer.add(beatPulse, forKey: "beatPulse")
        
        L.addSublayer(gradientContainer)
        return L
    }

    public func createKineticStepOverlay(text: String, index: Int, beatBPM: Double, config: RenderConfig) -> CALayer {
        let L = CALayer(); L.frame = CGRect(origin: .zero, size: config.size)
        
        // Add subtle professional sparkles behind step text
        let sparkles = createParticleSystem(type: .professionalSparkles, intensity: 0.3)
        sparkles.position = CGPoint(x: config.size.width / 2, y: -50)
        sparkles.zPosition = -200
        L.addSublayer(sparkles)
        
        // Create gradient container for step text (no step numbers)
        let gradientContainer = createSnapChefGradientContainer(
            text: text,
            fontSize: config.stepsFontSize,
            config: config,
            centered: false
        )
        
        // Position step text on left side with safe area insets
        let yPosition = config.safeInsets.top + 100 + CGFloat(index * 80)
        gradientContainer.position = CGPoint(
            x: config.safeInsets.left + gradientContainer.frame.width / 2,
            y: yPosition
        )
        gradientContainer.zPosition = 0 // Text in middle layer
        
        // Slide in animation from left with staggered delay
        let slideIn = createSlideInAnimation(from: .left, duration: 0.6, delay: Double(index) * 0.2)
        gradientContainer.add(slideIn, forKey: "slideIn")
        
        // Beat-synchronized pulse
        let beatPulse = createBeatSyncPulse(bpm: beatBPM, intensity: 0.05)
        gradientContainer.add(beatPulse, forKey: "beatPulse")
        
        // Add subtle particle trail for movement
        if index % 2 == 0 {
            let trail = createParticleSystem(type: .trail, intensity: 0.4)
            trail.position = CGPoint(x: config.safeInsets.left + 50, y: yPosition)
            L.addSublayer(trail)
        }
        
        L.addSublayer(gradientContainer)
        return L
    }

    public func createCTAOverlay(text: String, config: RenderConfig) -> CALayer {
        let L = CALayer(); L.frame = CGRect(origin: .zero, size: config.size)
        
        // Create SnapChef logo with gradient
        let logoContainer = createSnapChefLogoContainer(config: config)
        logoContainer.position = CGPoint(x: config.size.width / 2, y: config.size.height - config.safeInsets.bottom - 150)
        
        // Create gradient container for CTA text
        let ctaContainer = createSnapChefGradientContainer(
            text: text,
            fontSize: config.ctaFontSize,
            config: config,
            centered: true
        )
        ctaContainer.position = CGPoint(x: config.size.width / 2, y: config.size.height - config.safeInsets.bottom - 80)
        
        // Slide in animation from bottom
        let slideIn = createSlideInAnimation(from: .bottom, duration: 0.8)
        logoContainer.add(slideIn, forKey: "logoSlideIn")
        ctaContainer.add(slideIn, forKey: "ctaSlideIn")
        
        // Pulsing attention effect
        let pulseAttention = createAttentionPulse()
        logoContainer.add(pulseAttention, forKey: "logoPulse")
        ctaContainer.add(pulseAttention, forKey: "ctaPulse")
        
        L.addSublayer(logoContainer)
        L.addSublayer(ctaContainer)
        return L
    }
    
    // MARK: - Premium CTA Overlay (13-15 seconds)
    public func createPremiumCTAOverlay(config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)
        
        // Animated SnapChef logo with gradient
        let logoLayer = createAnimatedSnapChefLogo(config: config)
        logoLayer.position = CGPoint(x: config.size.width/2, y: config.size.height * 0.3)
        container.addSublayer(logoLayer)
        
        // Falling emoji particles
        addFallingEmojiParticles(to: container, config: config)
        
        // Pulsing "Get SnapChef FREE" button
        let ctaButton = createPulsingCTAButton(config: config)
        ctaButton.position = CGPoint(x: config.size.width/2, y: config.size.height * 0.6)
        container.addSublayer(ctaButton)
        
        // "Drop a 🔥 if you'd try this!" text
        let engagementText = createEngagementText(config: config)
        engagementText.position = CGPoint(x: config.size.width/2, y: config.size.height * 0.75)
        container.addSublayer(engagementText)
        
        // App Store CTA with icon
        let appStoreCTA = createAppStoreCTA(config: config)
        appStoreCTA.position = CGPoint(x: config.size.width/2, y: config.size.height * 0.85)
        container.addSublayer(appStoreCTA)
        
        return container
    }
    
    // MARK: - Premium Overlays for Different Segments
    
    public func createHookPremiumOverlay(config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)
        
        let hookContainer = createSnapChefGradientContainer(
            text: "POV: Your fridge is giving NOTHING",
            fontSize: config.hookFontSize * 0.8,
            config: config,
            centered: true
        )
        hookContainer.position = CGPoint(x: config.size.width/2, y: config.size.height * 0.2)
        
        // Add kinetic bounce animation
        let bounce = createBounceAnimation(delay: 0.0)
        hookContainer.add(bounce, forKey: "hookBounce")
        
        // Add beat-synced pulse
        let beatPulse = createBeatSyncPulse(bpm: config.fallbackBPM)
        hookContainer.add(beatPulse, forKey: "beatPulse")
        
        container.addSublayer(hookContainer)
        return container
    }
    
    public func createTransformOverlay(stepText: String, config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)
        
        let stepContainer = createSnapChefGradientContainer(
            text: stepText,
            fontSize: config.stepsFontSize,
            config: config,
            centered: true
        )
        stepContainer.position = CGPoint(x: config.size.width/2, y: config.size.height * 0.15)
        
        // Slide in from top animation
        let slideIn = createSlideInAnimation(from: .top, duration: 0.5)
        stepContainer.add(slideIn, forKey: "transformEntry")
        
        // Beat-synced pulse
        let beatPulse = createBeatSyncPulse(bpm: config.fallbackBPM, intensity: 0.04)
        stepContainer.add(beatPulse, forKey: "beatPulse")
        
        container.addSublayer(stepContainer)
        return container
    }
    
    public func createRevealOverlay(config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)
        
        let revealContainer = createSnapChefGradientContainer(
            text: "30 MINUTES LATER...",
            fontSize: config.ctaFontSize * 1.2,
            config: config,
            centered: true
        )
        revealContainer.position = CGPoint(x: config.size.width/2, y: config.size.height/2)
        
        // Add particle explosion effect
        addParticleExplosion(to: container, at: revealContainer.position, config: config)
        
        // Dramatic entrance
        let dramatic = createDramaticEntrance()
        revealContainer.add(dramatic, forKey: "revealDramatic")
        
        // Beat-synced pulse
        let beatPulse = createBeatSyncPulse(bpm: config.fallbackBPM, intensity: 0.06)
        revealContainer.add(beatPulse, forKey: "beatPulse")
        
        container.addSublayer(revealContainer)
        return container
    }
    
    public func createStatsOverlay(timeMinutes: Int?, difficulty: String, servings: Int, config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)
        
        let badges = createStatsBadges(time: timeMinutes, difficulty: difficulty, servings: servings, config: config)
        for (index, badge) in badges.enumerated() {
            badge.position = CGPoint(
                x: config.size.width/2,
                y: config.size.height * 0.8 + CGFloat(index * 60)
            )
            
            // Staggered bounce entrances
            let bounce = createBounceAnimation(delay: Double(index) * 0.2)
            badge.add(bounce, forKey: "badgeBounce\(index)")
            
            container.addSublayer(badge)
        }
        
        return container
    }
    
    /// Creates a professional sparkle overlay that renders behind text layers
    public func createProfessionalSparkleOverlay(intensity: CGFloat = 0.5, config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)
        
        // Create the professional sparkle particle system
        let sparkleSystem = createParticleSystem(type: .professionalSparkles, intensity: intensity)
        sparkleSystem.position = CGPoint(x: config.size.width / 2, y: -50)
        
        // Ensure particles are behind text by setting low z-position
        sparkleSystem.zPosition = -200
        
        container.addSublayer(sparkleSystem)
        return container
    }
    
    /// Creates a localized sparkle system behind specific text area
    public func createLocalizedSparkleOverlay(textPosition: CGPoint, textSize: CGSize, intensity: CGFloat = 0.4, config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)
        
        // Create sparkles that emanate from above the text area
        let sparkleSystem = createParticleSystem(type: .professionalSparkles, intensity: intensity)
        sparkleSystem.position = CGPoint(x: textPosition.x, y: textPosition.y - textSize.height - 50)
        
        // Modify emitter size to match text width
        if let emitterSystem = sparkleSystem as? CAEmitterLayer {
            emitterSystem.emitterSize = CGSize(width: textSize.width * 1.2, height: 10)
        }
        
        sparkleSystem.zPosition = -150
        container.addSublayer(sparkleSystem)
        return container
    }

    // Legacy support - now uses premium text layer
    private func makeText(text: String, size: CGFloat, weight: UIFont.Weight, center: Bool) -> CATextLayer {
        return createPremiumTextLayer(text: text, size: size, style: .glow(color: .white, intensity: 0.3), center: center)
    }

    // MARK: - SNAPCHEF GRADIENT CONTAINER FACTORY
    
    private func createSnapChefGradientContainer(text: String, fontSize: CGFloat, config: RenderConfig, centered: Bool) -> CALayer {
        let container = CALayer()
        
        // Create gradient background with SnapChef colors
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1.0).cgColor, // Orange #FF6B35
            UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 1.0).cgColor  // Pink #FF1493
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 16
        
        // Create white text layer
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = centered ? .center : .left
        textLayer.contentsScale = config.contentsScale
        textLayer.isWrapped = true
        
        // Calculate text size and add padding
        let textSize = textLayer.preferredFrameSize()
        let padding: CGFloat = 24
        let containerSize = CGSize(
            width: min(textSize.width + padding * 2, config.size.width - 40),
            height: textSize.height + padding * 2
        )
        
        // Set frames
        container.frame = CGRect(origin: .zero, size: containerSize)
        gradientLayer.frame = container.bounds
        textLayer.frame = container.bounds.insetBy(dx: padding, dy: padding)
        
        // Add shadow for depth
        gradientLayer.shadowColor = UIColor.black.cgColor
        gradientLayer.shadowOffset = CGSize(width: 0, height: 4)
        gradientLayer.shadowRadius = 8
        gradientLayer.shadowOpacity = 0.3
        
        container.addSublayer(gradientLayer)
        container.addSublayer(textLayer)
        
        return container
    }
    
    private func createSnapChefLogoContainer(config: RenderConfig) -> CALayer {
        let container = CALayer()
        let logoSize = CGSize(width: 200, height: 60)
        container.frame = CGRect(origin: .zero, size: logoSize)
        
        // Create gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = container.bounds
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1.0).cgColor, // Orange #FF6B35
            UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 1.0).cgColor  // Pink #FF1493
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 30
        
        // Create SnapChef text
        let textLayer = CATextLayer()
        textLayer.string = "SnapChef"
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Heavy" as CFString, 28, nil)
        textLayer.fontSize = 28
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = config.contentsScale
        textLayer.frame = container.bounds
        
        // Add shadow
        gradientLayer.shadowColor = UIColor.black.cgColor
        gradientLayer.shadowOffset = CGSize(width: 0, height: 4)
        gradientLayer.shadowRadius = 12
        gradientLayer.shadowOpacity = 0.4
        
        container.addSublayer(gradientLayer)
        container.addSublayer(textLayer)
        
        return container
    }
    
    // MARK: - SLIDE ANIMATIONS
    
    private enum SlideDirection {
        case top, bottom, left, right
    }
    
    private func createSlideInAnimation(from direction: SlideDirection, duration: Double, delay: Double = 0) -> CAAnimationGroup {
        let group = CAAnimationGroup()
        group.duration = duration
        group.beginTime = CACurrentMediaTime() + delay
        group.fillMode = .both
        group.isRemovedOnCompletion = false
        
        // Slide animation
        let slide = CABasicAnimation(keyPath: "transform.translation")
        switch direction {
        case .top:
            slide.fromValue = NSValue(cgSize: CGSize(width: 0, height: -100))
        case .bottom:
            slide.fromValue = NSValue(cgSize: CGSize(width: 0, height: 100))
        case .left:
            slide.fromValue = NSValue(cgSize: CGSize(width: -150, height: 0))
        case .right:
            slide.fromValue = NSValue(cgSize: CGSize(width: 150, height: 0))
        }
        slide.toValue = NSValue(cgSize: .zero)
        slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        // Fade in
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        
        // Scale bounce
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.8, 1.1, 1.0]
        scale.keyTimes = [0, 0.6, 1.0]
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        group.animations = [slide, fade, scale]
        return group
    }
    
    private func createBeatSyncPulse(bpm: Double, intensity: CGFloat = 0.03) -> CAKeyframeAnimation {
        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [1.0, 1.0 + intensity, 1.0]
        pulse.keyTimes = [0, 0.3, 1.0]
        pulse.duration = 60.0 / bpm
        pulse.repeatCount = .greatestFiniteMagnitude
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return pulse
    }
    
    // MARK: - PREMIUM TEXT LAYER FACTORY
    
    private func createPremiumTextLayer(text: String, size: CGFloat, style: TextAnimationStyle, center: Bool) -> CATextLayer {
        let tl = CATextLayer()
        
        // Base text setup
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        switch style {
        case .gradient(let colors):
            // Create gradient text
            let gradientText = NSMutableAttributedString(string: text, attributes: attrs)
            // Note: Gradient text requires custom drawing, simplified here
            tl.string = gradientText
            
        case .glow(let color, let intensity):
            let glowAttrs = attrs.merging([
                .strokeColor: color.cgColor,
                .strokeWidth: -2.0 * intensity
            ]) { _, new in new }
            tl.string = NSAttributedString(string: text, attributes: glowAttrs)
            tl.shadowColor = color.cgColor
            tl.shadowRadius = 8 * intensity
            tl.shadowOpacity = Float(intensity)
            tl.shadowOffset = CGSize.zero
            
        default:
            tl.string = NSAttributedString(string: text, attributes: attrs)
        }
        
        tl.alignmentMode = center ? .center : .left
        tl.contentsScale = config.contentsScale
        
        // Enhanced stroke + shadow for visibility
        if config.textStrokeEnabled {
            tl.shadowRadius = 6
            tl.shadowOpacity = 1
            tl.shadowOffset = CGSize(width: 0, height: 3)
            tl.shadowColor = UIColor.black.cgColor
        }
        
        // Layout
        let maxW = config.size.width - (config.safeInsets.left + config.safeInsets.right)
        let preferred = tl.preferredFrameSize()
        let x = center ? config.safeInsets.left : config.safeInsets.left
        let y = center ? (config.size.height - preferred.height)/2 : (config.safeInsets.top)
        tl.frame = CGRect(x: x, y: y, width: maxW, height: preferred.height)
        tl.isWrapped = true
        
        // Apply animation based on style
        switch style {
        case .typewriter(let speed):
            tl.add(createTypewriterAnimation(text: text, speed: speed), forKey: "typewriter")
        case .glitch(let intensity):
            tl.add(createGlitchEffect(intensity: intensity, duration: 1.0), forKey: "glitch")
        case .bounce(let height):
            tl.add(createBounceAnimation(height: height), forKey: "bounce")
        case .kinetic(let zoom):
            if zoom {
                tl.add(createKineticEntry(duration: 0.6), forKey: "kinetic")
            }
        default:
            break
        }
        
        return tl
    }
    
    // MARK: - PREMIUM ANIMATION FACTORIES
    
    private func createKineticEntry(duration: Double) -> CAAnimationGroup {
        let group = CAAnimationGroup()
        group.duration = duration
        group.fillMode = .both
        group.isRemovedOnCompletion = false
        group.beginTime = AVCoreAnimationBeginTimeAtZero
        
        // Shock zoom: 0.5x → 1.2x → 1.0x
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.5, 1.2, 1.0]
        scale.keyTimes = [0, 0.6, 1.0]
        scale.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        
        // Opacity fade in
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = duration * 0.3
        
        // Rotation for dynamic feel
        let rotate = CABasicAnimation(keyPath: "transform.rotation")
        rotate.fromValue = -0.1
        rotate.toValue = 0
        rotate.duration = duration
        
        group.animations = [scale, fade, rotate]
        return group
    }
    
    private func createGlitchEffect(intensity: CGFloat, duration: Double) -> CAAnimationGroup {
        let group = CAAnimationGroup()
        group.duration = duration
        group.repeatCount = 2
        group.autoreverses = true
        
        // Horizontal shake
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        let shakeAmount = intensity * 5
        shake.values = [0, -shakeAmount, shakeAmount, -shakeAmount, 0]
        shake.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        
        // Color shift
        let colorShift = CABasicAnimation(keyPath: "filters.colorMonochrome.inputColor")
        colorShift.fromValue = CIColor.white
        colorShift.toValue = CIColor.red
        
        group.animations = [shake, colorShift]
        return group
    }
    
    private func createTypewriterAnimation(text: String, speed: Double) -> CABasicAnimation {
        // Simulate typewriter by revealing text gradually
        let typewriter = CABasicAnimation(keyPath: "string")
        typewriter.duration = Double(text.count) * speed
        typewriter.fillMode = .both
        typewriter.isRemovedOnCompletion = false
        return typewriter
    }
    
    private func createBounceAnimation(height: CGFloat) -> CAKeyframeAnimation {
        let bounce = CAKeyframeAnimation(keyPath: "transform.translation.y")
        bounce.values = [0, -height, -height * 0.6, -height * 0.3, 0]
        bounce.keyTimes = [0, 0.3, 0.5, 0.7, 1.0]
        bounce.duration = 0.8
        bounce.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeOut), count: 4)
        return bounce
    }
    
    private func createVelocityRampEntry(index: Int, beatBPM: Double) -> CAAnimationGroup {
        let group = CAAnimationGroup()
        let beatDuration = 60.0 / beatBPM
        group.duration = beatDuration * 1.5
        group.fillMode = .both
        group.isRemovedOnCompletion = false
        group.beginTime = AVCoreAnimationBeginTimeAtZero
        
        // Velocity ramp based on index for staggered effect
        let delay = Double(index) * 0.1
        group.beginTime += delay
        
        // Overshoot entry
        let slide = CAKeyframeAnimation(keyPath: "transform.translation.y")
        slide.values = [80, -10, 0]
        slide.keyTimes = [0, 0.7, 1.0]
        slide.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.68, -0.55, 0.265, 1.55),
            CAMediaTimingFunction(name: .easeOut)
        ]
        
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.8
        scale.toValue = 1.0
        
        group.animations = [slide, scale]
        return group
    }
    
    private func createGlowPulse(color: UIColor, intensity: CGFloat, bpm: Double) -> CABasicAnimation {
        let glow = CABasicAnimation(keyPath: "shadowRadius")
        glow.fromValue = 4
        glow.toValue = 12 * intensity
        glow.duration = 60.0 / bpm
        glow.autoreverses = true
        glow.repeatCount = .greatestFiniteMagnitude
        return glow
    }
    
    private func createBeatSyncEffect(beatBPM: Double, intensity: CGFloat) -> CAKeyframeAnimation {
        let beatSync = CAKeyframeAnimation(keyPath: "transform.scale")
        beatSync.values = [1.0, 1.0 + intensity, 1.0]
        beatSync.keyTimes = [0, 0.3, 1.0]
        beatSync.duration = 60.0 / beatBPM
        beatSync.repeatCount = .greatestFiniteMagnitude
        return beatSync
    }
    
    private func createAttentionPulse() -> CABasicAnimation {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.05
        pulse.duration = 1.2
        pulse.autoreverses = true
        pulse.repeatCount = .greatestFiniteMagnitude
        return pulse
    }
    
    // MARK: - PARTICLE SYSTEM FACTORY
    
    private func createParticleSystem(type: ParticleType, intensity: CGFloat) -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        
        switch type {
        case .sparkle:
            emitter.emitterShape = .circle
            emitter.emitterSize = CGSize(width: 50, height: 50)
            
            let cell = CAEmitterCell()
            cell.contents = createSparkleImage().cgImage
            cell.birthRate = Float(20 * intensity)
            cell.lifetime = Float(2.0)
            cell.velocity = CGFloat(50 * intensity)
            cell.velocityRange = CGFloat(20 * intensity)
            cell.emissionRange = .pi * 2
            cell.scale = 0.3
            cell.scaleRange = 0.2
            cell.alphaSpeed = -1.0
            
            emitter.emitterCells = [cell]
            
        case .trail:
            emitter.emitterShape = .line
            emitter.emitterSize = CGSize(width: 100, height: 5)
            
            let cell = CAEmitterCell()
            cell.contents = createTrailParticle().cgImage
            cell.birthRate = Float(10 * intensity)
            cell.lifetime = Float(1.0)
            cell.velocity = CGFloat(30)
            cell.emissionLongitude = -.pi / 2
            cell.scale = 0.2
            cell.alphaSpeed = -2.0
            
            emitter.emitterCells = [cell]
            
        case .professionalSparkles:
            return createProfessionalSparkleSystem(intensity: intensity)
        }
        
        return emitter
    }
    
    /// Creates a professional, subtle sparkle system that streams down behind text
    private func createProfessionalSparkleSystem(intensity: CGFloat) -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: config.size.width, height: 10)
        emitter.emitterPosition = CGPoint(x: config.size.width / 2, y: -50)
        
        // Primary sparkle particles
        let sparkleCell = CAEmitterCell()
        sparkleCell.contents = createElegantSparkleImage().cgImage
        sparkleCell.birthRate = Float(8 * intensity) // Subtle birth rate
        sparkleCell.lifetime = Float(4.0) // Longer lifetime for graceful fall
        sparkleCell.velocity = CGFloat(60) // Gentle downward velocity
        sparkleCell.velocityRange = CGFloat(20) // Slight variation
        sparkleCell.emissionLongitude = .pi / 2 // Downward direction
        sparkleCell.emissionRange = .pi / 6 // Narrow cone for controlled direction
        
        // Physics-based movement with subtle wind effect
        sparkleCell.yAcceleration = 20 // Gentle gravity effect
        sparkleCell.xAcceleration = 5 // Subtle horizontal drift (wind effect)
        
        // Scale properties for elegance
        sparkleCell.scale = 0.15 // Small, elegant size
        sparkleCell.scaleRange = 0.08 // Variation in size
        sparkleCell.scaleSpeed = -0.02 // Gentle shrinking over time
        
        // Alpha properties for fade in/out
        sparkleCell.alphaRange = 0.3 // Variation in opacity
        sparkleCell.alphaSpeed = -0.25 // Gentle fade out
        
        // Rotation for dynamic feel
        sparkleCell.spin = .pi / 4 // Gentle rotation
        sparkleCell.spinRange = .pi / 2 // Variation in rotation speed
        
        // Horizontal drift for realism
        sparkleCell.emissionLongitude = .pi / 2 + CGFloat.random(in: -0.1...0.1)
        
        // Secondary micro-sparkles for depth
        let microCell = CAEmitterCell()
        microCell.contents = createMicroSparkleImage().cgImage
        microCell.birthRate = Float(15 * intensity)
        microCell.lifetime = Float(3.0)
        microCell.velocity = CGFloat(40)
        microCell.velocityRange = CGFloat(15)
        microCell.emissionLongitude = .pi / 2
        microCell.emissionRange = .pi / 4
        
        microCell.yAcceleration = 15
        microCell.xAcceleration = 3 // Lighter wind effect for micro particles
        microCell.scale = 0.08
        microCell.scaleRange = 0.04
        microCell.scaleSpeed = -0.01
        microCell.alphaRange = 0.2
        microCell.alphaSpeed = -0.3
        microCell.spin = .pi / 6
        microCell.spinRange = .pi / 3
        
        emitter.emitterCells = [sparkleCell, microCell]
        emitter.zPosition = -100 // Ensure particles render behind text
        
        return emitter
    }
    
    private enum ParticleType {
        case sparkle
        case trail
        case professionalSparkles
    }
    
    private func createSparkleImage() -> UIImage {
        let size = CGSize(width: 10, height: 10)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    private func createTrailParticle() -> UIImage {
        let size = CGSize(width: 6, height: 6)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.yellow.withAlphaComponent(0.8).cgColor)
        context.fillEllipse(in: CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    /// Creates an elegant sparkle image for professional particle effects
    private func createElegantSparkleImage() -> UIImage {
        let size = CGSize(width: 12, height: 12)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        
        // Create a subtle white sparkle with light gold tint
        let sparkleColor = UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 0.6)
        context.setFillColor(sparkleColor.cgColor)
        
        // Draw a four-pointed star shape
        context.beginPath()
        let radius: CGFloat = 4
        let innerRadius: CGFloat = 1.5
        
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            let currentRadius = i % 2 == 0 ? radius : innerRadius
            let x = center.x + cos(angle) * currentRadius
            let y = center.y + sin(angle) * currentRadius
            
            if i == 0 {
                context.move(to: CGPoint(x: x, y: y))
            } else {
                context.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.closePath()
        context.fillPath()
        
        // Add a subtle glow effect
        context.setShadow(offset: .zero, blur: 2, color: sparkleColor.withAlphaComponent(0.8).cgColor)
        context.fillEllipse(in: CGRect(x: center.x - 1, y: center.y - 1, width: 2, height: 2))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    /// Creates micro sparkle particles for depth and subtlety
    private func createMicroSparkleImage() -> UIImage {
        let size = CGSize(width: 6, height: 6)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        
        // Very subtle white dot with minimal opacity
        let microColor = UIColor.white.withAlphaComponent(0.4)
        context.setFillColor(microColor.cgColor)
        
        // Small circular sparkle
        context.fillEllipse(in: CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3))
        
        // Even smaller bright center
        context.setFillColor(UIColor.white.withAlphaComponent(0.7).cgColor)
        context.fillEllipse(in: CGRect(x: center.x - 0.5, y: center.y - 0.5, width: 1, height: 1))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    // Legacy support
    private func beatScale(duration: Double) -> CAAnimation {
        let k = CAKeyframeAnimation(keyPath: "transform.scale")
        k.values = [1.0, 1.04, 1.0]  // labels can breathe a bit more than bg
        k.keyTimes = [0, 0.5, 1]
        k.duration = max(0.3, duration)
        k.repeatCount = .greatestFiniteMagnitude
        k.isRemovedOnCompletion = false
        k.fillMode = .both
        k.beginTime = AVCoreAnimationBeginTimeAtZero + 0.2
        return k
    }
    
    // MARK: - Premium UI Component Helpers
    
    private func createAnimatedSnapChefLogo(config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(x: 0, y: 0, width: config.size.width * 0.8, height: 120)
        
        // Create gradient text layer for "SNAPCHEF!"
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = container.bounds
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.078, blue: 0.576, alpha: 1.0).cgColor,  // Hot Pink
            UIColor(red: 0.6, green: 0.196, blue: 0.8, alpha: 1.0).cgColor,    // Purple
            UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0).cgColor       // Cyan
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        
        // Animate gradient colors
        let colorAnimation = CAKeyframeAnimation(keyPath: "colors")
        colorAnimation.values = [
            [UIColor(red: 1.0, green: 0.078, blue: 0.576, alpha: 1.0).cgColor,
             UIColor(red: 0.6, green: 0.196, blue: 0.8, alpha: 1.0).cgColor,
             UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0).cgColor],
            [UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0).cgColor,
             UIColor(red: 1.0, green: 0.078, blue: 0.576, alpha: 1.0).cgColor,
             UIColor(red: 0.6, green: 0.196, blue: 0.8, alpha: 1.0).cgColor],
            [UIColor(red: 0.6, green: 0.196, blue: 0.8, alpha: 1.0).cgColor,
             UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0).cgColor,
             UIColor(red: 1.0, green: 0.078, blue: 0.576, alpha: 1.0).cgColor]
        ]
        colorAnimation.duration = 3.0
        colorAnimation.repeatCount = .greatestFiniteMagnitude
        gradientLayer.add(colorAnimation, forKey: "gradientAnimation")
        
        // Text layer
        let textLayer = CATextLayer()
        textLayer.string = "SNAPCHEF!"
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Heavy" as CFString, 48, nil)
        textLayer.fontSize = 48
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = 2.0
        textLayer.frame = container.bounds
        
        // Mask the gradient with the text
        gradientLayer.mask = textLayer
        
        // Scale bounce animation
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1.0, 1.1, 0.95, 1.05, 1.0]
        bounce.keyTimes = [0, 0.3, 0.6, 0.8, 1.0]
        bounce.duration = 2.0
        bounce.repeatCount = .greatestFiniteMagnitude
        bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        container.addSublayer(gradientLayer)
        container.add(bounce, forKey: "logoScale")
        
        return container
    }
    
    private func addFallingEmojiParticles(to container: CALayer, config: RenderConfig) {
        let emojis = ["🍕", "🍔", "🌮", "🥗", "🍜", "🥙", "🌯", "🍱"]
        
        for _ in 0..<12 {
            let emojiLayer = CATextLayer()
            emojiLayer.string = emojis.randomElement()!
            emojiLayer.fontSize = 28
            emojiLayer.alignmentMode = .center
            emojiLayer.contentsScale = 2.0
            emojiLayer.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            
            // Random starting position across the width
            let startX = CGFloat.random(in: 50...(config.size.width - 50))
            emojiLayer.position = CGPoint(x: startX, y: -50)
            
            // Fall animation
            let fall = CABasicAnimation(keyPath: "position.y")
            fall.fromValue = -50
            fall.toValue = config.size.height + 50
            fall.duration = Double.random(in: 3.0...6.0)
            fall.beginTime = CACurrentMediaTime() + Double.random(in: 0...2.0)
            fall.repeatCount = .greatestFiniteMagnitude
            
            // Gentle sway animation
            let sway = CAKeyframeAnimation(keyPath: "position.x")
            sway.values = [startX, startX + 20, startX - 15, startX + 10, startX]
            sway.duration = 2.0
            sway.repeatCount = .greatestFiniteMagnitude
            
            // Rotation animation
            let rotate = CABasicAnimation(keyPath: "transform.rotation")
            rotate.fromValue = 0
            rotate.toValue = Double.pi * 2
            rotate.duration = Double.random(in: 2.0...4.0)
            rotate.repeatCount = .greatestFiniteMagnitude
            
            emojiLayer.add(fall, forKey: "fall")
            emojiLayer.add(sway, forKey: "sway")
            emojiLayer.add(rotate, forKey: "rotate")
            
            container.addSublayer(emojiLayer)
        }
    }
    
    private func createPulsingCTAButton(config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(x: 0, y: 0, width: config.size.width * 0.8, height: 80)
        
        // Background with gradient
        let background = CAGradientLayer()
        background.frame = container.bounds
        background.colors = [
            UIColor(red: 1.0, green: 0.078, blue: 0.576, alpha: 1.0).cgColor,
            UIColor(red: 0.6, green: 0.196, blue: 0.8, alpha: 1.0).cgColor
        ]
        background.cornerRadius = 40
        background.shadowColor = UIColor.magenta.cgColor
        background.shadowOpacity = 0.6
        background.shadowRadius = 15
        background.shadowOffset = .zero
        
        // Text layer
        let textLayer = CATextLayer()
        textLayer.string = "Get SnapChef FREE"
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 32, nil)
        textLayer.fontSize = 32
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = 2.0
        textLayer.frame = container.bounds
        
        // Pulsing animation
        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [1.0, 1.05, 1.0, 1.08, 1.0]
        pulse.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        pulse.duration = 1.5
        pulse.repeatCount = .greatestFiniteMagnitude
        
        // Glow animation
        let glow = CAKeyframeAnimation(keyPath: "shadowRadius")
        glow.values = [15, 25, 15, 30, 15]
        glow.duration = 1.5
        glow.repeatCount = .greatestFiniteMagnitude
        
        container.addSublayer(background)
        container.addSublayer(textLayer)
        container.add(pulse, forKey: "pulse")
        background.add(glow, forKey: "glow")
        
        return container
    }
    
    private func createEngagementText(config: RenderConfig) -> CALayer {
        let engagementContainer = createSnapChefGradientContainer(
            text: "Drop a 🔥 if you'd try this!",
            fontSize: 28,
            config: config,
            centered: true
        )
        
        // Gentle bounce animation
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1.0, 1.02, 1.0]
        bounce.duration = 1.8
        bounce.repeatCount = .greatestFiniteMagnitude
        engagementContainer.add(bounce, forKey: "engagementBounce")
        
        // Beat-synced pulse
        let beatPulse = createBeatSyncPulse(bpm: config.fallbackBPM, intensity: 0.02)
        engagementContainer.add(beatPulse, forKey: "beatPulse")
        
        return engagementContainer
    }
    
    private func createAppStoreCTA(config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        
        // App Store icon (simplified)
        let iconLayer = CALayer()
        iconLayer.frame = CGRect(x: 0, y: 5, width: 30, height: 30)
        iconLayer.backgroundColor = UIColor.white.cgColor
        iconLayer.cornerRadius = 6
        
        // "Download Free" text
        let textLayer = CATextLayer()
        textLayer.string = "Download Free"
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 18, nil)
        textLayer.fontSize = 18
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.contentsScale = 2.0
        textLayer.frame = CGRect(x: 40, y: 10, width: 160, height: 20)
        
        container.addSublayer(iconLayer)
        container.addSublayer(textLayer)
        
        return container
    }
    
    private func createNeonGradientText(text: String, fontSize: CGFloat, config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(x: 0, y: 0, width: config.size.width * 0.9, height: fontSize * 1.5)
        
        // Gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = container.bounds
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.078, blue: 0.576, alpha: 1.0).cgColor,
            UIColor(red: 0.6, green: 0.196, blue: 0.8, alpha: 1.0).cgColor,
            UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0)
        
        // Text layer
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Heavy" as CFString, fontSize, nil)
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = 2.0
        textLayer.frame = container.bounds
        textLayer.isWrapped = true
        
        // Shadow for neon effect
        textLayer.shadowColor = UIColor.cyan.cgColor
        textLayer.shadowOpacity = 0.8
        textLayer.shadowRadius = 8
        textLayer.shadowOffset = .zero
        
        // Mask gradient with text
        gradientLayer.mask = textLayer
        
        container.addSublayer(gradientLayer)
        
        return container
    }
    
    private func createBounceAnimation(delay: Double) -> CAAnimation {
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [0.3, 1.2, 0.9, 1.1, 1.0]
        bounce.keyTimes = [0, 0.3, 0.6, 0.8, 1.0]
        bounce.duration = 0.8
        bounce.beginTime = CACurrentMediaTime() + delay
        bounce.timingFunction = CAMediaTimingFunction(name: .easeOut)
        bounce.fillMode = .both
        bounce.isRemovedOnCompletion = false
        return bounce
    }
    
    private func createDramaticEntrance() -> CAAnimation {
        let group = CAAnimationGroup()
        
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.1, 1.3, 0.8, 1.1, 1.0]
        scale.keyTimes = [0, 0.4, 0.6, 0.8, 1.0]
        
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = -Double.pi
        rotation.toValue = 0
        
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0
        opacity.toValue = 1
        
        group.animations = [scale, rotation, opacity]
        group.duration = 1.2
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.fillMode = .both
        group.isRemovedOnCompletion = false
        
        return group
    }
    
    private func addParticleExplosion(to container: CALayer, at position: CGPoint, config: RenderConfig) {
        let particles = ["✨", "💥", "🔥", "⭐", "🌟"]
        
        for i in 0..<8 {
            let particleLayer = CATextLayer()
            particleLayer.string = particles.randomElement()!
            particleLayer.fontSize = 24
            particleLayer.alignmentMode = .center
            particleLayer.contentsScale = 2.0
            particleLayer.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            particleLayer.position = position
            
            // Explosion animation
            let angle = Double(i) * (Double.pi * 2 / 8)
            let distance: CGFloat = 100
            let endX = position.x + cos(angle) * distance
            let endY = position.y + sin(angle) * distance
            
            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = NSValue(cgPoint: position)
            move.toValue = NSValue(cgPoint: CGPoint(x: endX, y: endY))
            move.duration = 1.0
            move.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1.0
            fade.toValue = 0.0
            fade.duration = 1.0
            
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 1.0
            scale.toValue = 0.1
            scale.duration = 1.0
            
            particleLayer.add(move, forKey: "explode")
            particleLayer.add(fade, forKey: "fadeOut")
            particleLayer.add(scale, forKey: "shrink")
            
            container.addSublayer(particleLayer)
        }
    }
    
    private func createStatsBadges(time: Int?, difficulty: String, servings: Int, config: RenderConfig) -> [CALayer] {
        var badges: [CALayer] = []
        
        // Time badge
        if let timeMinutes = time {
            let timeBadge = createBadge(icon: "⏱️", text: "\(timeMinutes) min", config: config)
            badges.append(timeBadge)
        }
        
        // Difficulty badge
        let difficultyIcon = difficulty.lowercased().contains("easy") ? "😊" : 
                           difficulty.lowercased().contains("medium") ? "🤔" : "💪"
        let difficultyBadge = createBadge(icon: difficultyIcon, text: difficulty, config: config)
        badges.append(difficultyBadge)
        
        // Servings badge
        let servingsBadge = createBadge(icon: "👥", text: "\(servings) servings", config: config)
        badges.append(servingsBadge)
        
        return badges
    }
    
    private func createBadge(icon: String, text: String, config: RenderConfig) -> CALayer {
        let badgeContainer = createSnapChefGradientContainer(
            text: "\(icon) \(text)",
            fontSize: 16,
            config: config,
            centered: true
        )
        
        // Add subtle pulse animation
        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [1.0, 1.01, 1.0]
        pulse.duration = 2.0
        pulse.repeatCount = .greatestFiniteMagnitude
        badgeContainer.add(pulse, forKey: "badgePulse")
        
        return badgeContainer
    }
}

// MARK: - Video compositor that applies CALayer overlays over the base video
import AVFoundation

public extension OverlayFactory {
    /// Renders overlays into the video using CoreAnimationTool and exports a new file.
    func applyOverlays(videoURL: URL,
                       overlays: [RenderPlan.Overlay],
                       progress: @escaping @Sendable (Double) async -> Void = { _ in }) async throws -> URL {
        let base = AVURLAsset(url: videoURL)
        let comp = AVMutableComposition()
        guard let srcV = try await base.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "OverlayFactory", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track"])
        }
        let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let duration = try await base.load(.duration)
        try vTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: srcV, at: .zero)

        // pass-through audio if present
        if let srcA = try? await base.loadTracks(withMediaType: .audio).first {
            let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
            try aTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: srcA, at: .zero)
        }

        // One instruction covering the whole timeline
        let instr = AVMutableVideoCompositionInstruction()
        instr.timeRange = CMTimeRange(start: .zero, duration: duration)
        let layerInstr = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
        instr.layerInstructions = [layerInstr]

        // Build overlay parent with sublayers inserted at their time windows
        let renderSize = config.size
        let parent = CALayer(); parent.frame = CGRect(origin: .zero, size: renderSize)
        let videoLayer = CALayer(); videoLayer.frame = parent.frame
        let overlayLayer = CALayer(); overlayLayer.frame = parent.frame

        // Time-window each overlay
        for ov in overlays {
            let L = ov.layerBuilder(config)
            L.beginTime = ov.start.seconds
            L.duration = ov.duration.seconds
            overlayLayer.addSublayer(L)
        }

        parent.addSublayer(videoLayer)
        parent.addSublayer(overlayLayer)

        let videoComp = AVMutableVideoComposition()
        videoComp.instructions = [instr]
        videoComp.renderSize = renderSize
        videoComp.frameDuration = CMTime(value: 1, timescale: config.fps)
        videoComp.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)

        // Export
        let out = SnapChef.createTempOutputURL()
        try? FileManager.default.removeItem(at: out)
        guard let export = AVAssetExportSession(asset: comp, presetName: ExportSettings.videoPreset) else {
            throw NSError(domain: "OverlayFactory", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session"])
        }
        export.outputURL = out
        export.outputFileType = .mp4
        export.videoComposition = videoComp

        return try await withCheckedThrowingContinuation { cont in
            export.exportAsynchronously {
                switch export.status {
                case .completed: cont.resume(returning: out)
                case .failed: cont.resume(throwing: export.error ?? NSError(domain: "OverlayFactory", code: -3))
                case .cancelled: cont.resume(throwing: NSError(domain: "OverlayFactory", code: -4))
                default: cont.resume(throwing: NSError(domain: "OverlayFactory", code: -5))
                }
            }
        }
    }
}