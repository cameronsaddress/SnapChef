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
        
        // PREMIUM: Create dramatic hook with multiple effects
        let textContainer = createPremiumTextLayer(text: text, 
                                                  size: config.hookFontSize, 
                                                  style: .gradient(colors: [.white, .yellow]), 
                                                  center: true)
        
        // Add particle system for dramatic moment
        let particles = createParticleSystem(type: .sparkle, intensity: 0.8)
        particles.position = CGPoint(x: config.size.width / 2, y: config.size.height / 2)
        L.addSublayer(particles)
        
        textContainer.opacity = 0
        
        // PREMIUM: Kinetic entry with shock zoom (0.5x → 1.2x → 1.0x)
        let kineticEntry = createKineticEntry(duration: 0.8)
        textContainer.add(kineticEntry, forKey: "kineticEntry")
        
        // Add glitch effect for viral attention
        let glitch = createGlitchEffect(intensity: 0.3, duration: 2.0)
        textContainer.add(glitch, forKey: "glitch")
        
        // Beat-synced glow pulse
        let glowPulse = createGlowPulse(color: .yellow, intensity: 0.6, bpm: config.fallbackBPM)
        textContainer.add(glowPulse, forKey: "glowPulse")
        
        L.addSublayer(textContainer)
        return L
    }

    public func createKineticStepOverlay(text: String, index: Int, beatBPM: Double, config: RenderConfig) -> CALayer {
        let L = CALayer(); L.frame = CGRect(origin: .zero, size: config.size)
        
        // PREMIUM: Alternating animation styles for each step
        let animationStyle: TextAnimationStyle = index % 3 == 0 ? .typewriter(speed: 0.05) : 
                                               index % 3 == 1 ? .bounce(height: 20) : 
                                                               .kinetic(zoom: true)
        
        let t = createPremiumTextLayer(text: text, 
                                      size: config.stepsFontSize, 
                                      style: animationStyle, 
                                      center: false)
        
        // PREMIUM: Velocity ramping entry with overshoot
        let velocityEntry = createVelocityRampEntry(index: index, beatBPM: beatBPM)
        t.add(velocityEntry, forKey: "velocityEntry")
        
        // Add beat-synchronized effects
        t.add(createBeatSyncEffect(beatBPM: beatBPM, intensity: 0.08), forKey: "beatSync")
        
        // Add subtle particle trail for movement
        if index % 2 == 0 {
            let trail = createParticleSystem(type: .trail, intensity: 0.4)
            trail.position = CGPoint(x: config.safeInsets.left + 50, y: config.safeInsets.top + 100)
            L.addSublayer(trail)
        }
        
        L.addSublayer(t)
        return L
    }

    public func createCTAOverlay(text: String, config: RenderConfig) -> CALayer {
        let L = CALayer(); L.frame = CGRect(origin: .zero, size: config.size)
        
        // PREMIUM: Animated gradient background
        let sticker = CAGradientLayer()
        sticker.colors = [UIColor.black.withAlphaComponent(0.9).cgColor, 
                         UIColor.systemBlue.withAlphaComponent(0.8).cgColor]
        sticker.startPoint = CGPoint(x: 0, y: 0)
        sticker.endPoint = CGPoint(x: 1, y: 1)
        sticker.cornerRadius = 40
        
        // Animated gradient colors
        let gradientAnimation = CABasicAnimation(keyPath: "colors")
        gradientAnimation.fromValue = sticker.colors
        gradientAnimation.toValue = [UIColor.systemBlue.withAlphaComponent(0.9).cgColor, 
                                    UIColor.systemPurple.withAlphaComponent(0.8).cgColor]
        gradientAnimation.duration = 2.0
        gradientAnimation.autoreverses = true
        gradientAnimation.repeatCount = .greatestFiniteMagnitude
        sticker.add(gradientAnimation, forKey: "gradientShift")
        
        let pad: CGFloat = 28
        let t = createPremiumTextLayer(text: text, 
                                      size: config.ctaFontSize, 
                                      style: .glow(color: .white, intensity: 0.8), 
                                      center: true)
        
        let w = config.size.width - 120
        let h = t.preferredFrameSize().height + pad*2
        sticker.frame = CGRect(x: (config.size.width - w)/2,
                               y: config.size.height - config.safeInsets.bottom - h - 16,
                               width: w, height: h)
        t.frame = sticker.bounds.insetBy(dx: pad, dy: pad)
        
        // PREMIUM: Pulsing attention effect
        let pulseAttention = createAttentionPulse()
        sticker.add(pulseAttention, forKey: "attention")
        
        sticker.addSublayer(t)
        L.addSublayer(sticker)
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
        
        let hookText = createNeonGradientText(
            text: "POV: Your fridge is giving NOTHING",
            fontSize: config.hookFontSize * 0.8,
            config: config
        )
        hookText.position = CGPoint(x: config.size.width/2, y: config.size.height * 0.2)
        
        // Add kinetic bounce animation
        let bounce = createBounceAnimation(delay: 0.0)
        hookText.add(bounce, forKey: "hookBounce")
        
        container.addSublayer(hookText)
        return container
    }
    
    public func createTransformOverlay(stepText: String, config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)
        
        let text = createNeonGradientText(
            text: stepText,
            fontSize: config.stepsFontSize,
            config: config
        )
        text.position = CGPoint(x: config.size.width/2, y: config.size.height * 0.15)
        
        // Kinetic entry animation
        let slideUp = CABasicAnimation(keyPath: "transform.translation.y")
        slideUp.fromValue = 80
        slideUp.toValue = 0
        slideUp.duration = 0.5
        slideUp.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.8
        scale.toValue = 1.0
        scale.duration = 0.5
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let group = CAAnimationGroup()
        group.animations = [slideUp, scale]
        group.duration = 0.5
        group.fillMode = .both
        group.isRemovedOnCompletion = false
        
        text.add(group, forKey: "transformEntry")
        container.addSublayer(text)
        
        return container
    }
    
    public func createRevealOverlay(config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)
        
        let revealText = createNeonGradientText(
            text: "30 MINUTES LATER...",
            fontSize: config.ctaFontSize * 1.2,
            config: config
        )
        revealText.position = CGPoint(x: config.size.width/2, y: config.size.height/2)
        
        // Add particle explosion effect
        addParticleExplosion(to: container, at: revealText.position, config: config)
        
        // Dramatic entrance
        let dramatic = createDramaticEntrance()
        revealText.add(dramatic, forKey: "revealDramatic")
        
        container.addSublayer(revealText)
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

    // Legacy support - now uses premium text layer
    private func makeText(text: String, size: CGFloat, weight: UIFont.Weight, center: Bool) -> CATextLayer {
        return createPremiumTextLayer(text: text, size: size, style: .glow(color: .white, intensity: 0.3), center: center)
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
        }
        
        return emitter
    }
    
    private enum ParticleType {
        case sparkle
        case trail
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
        let textLayer = createNeonGradientText(
            text: "Drop a 🔥 if you'd try this!",
            fontSize: 28,
            config: config
        )
        
        // Gentle bounce animation
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1.0, 1.02, 1.0]
        bounce.duration = 1.8
        bounce.repeatCount = .greatestFiniteMagnitude
        textLayer.add(bounce, forKey: "engagementBounce")
        
        return textLayer
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
        let container = CALayer()
        container.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        
        // Background
        let background = CALayer()
        background.frame = container.bounds
        background.backgroundColor = UIColor.black.withAlphaComponent(0.8).cgColor
        background.cornerRadius = 20
        background.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        background.borderWidth = 1
        
        // Icon
        let iconLayer = CATextLayer()
        iconLayer.string = icon
        iconLayer.fontSize = 20
        iconLayer.alignmentMode = .center
        iconLayer.contentsScale = 2.0
        iconLayer.frame = CGRect(x: 10, y: 10, width: 20, height: 20)
        
        // Text
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 16, nil)
        textLayer.fontSize = 16
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.contentsScale = 2.0
        textLayer.frame = CGRect(x: 40, y: 12, width: 150, height: 16)
        
        container.addSublayer(background)
        container.addSublayer(iconLayer)
        container.addSublayer(textLayer)
        
        return container
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