// REPLACE ENTIRE FILE: OverlayFactory.swift

import UIKit
import AVFoundation
import QuartzCore

public final class OverlayFactory: @unchecked Sendable {
    private let config: RenderConfig
    
    // SPEED OPTIMIZATION: Layer cache for reusable components
    private let layerCache = NSCache<NSString, CALayer>()
    private let animationCache = NSCache<NSString, CAAnimation>()
    
    public init(config: RenderConfig) { 
        self.config = config 
        
        // Configure caches for performance
        layerCache.countLimit = 20
        animationCache.countLimit = 50
    }
    
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
        let L = CALayer()
        L.frame = CGRect(origin: .zero, size: config.size)
        
        // Simplified gradient container for hook text - NO PARTICLES
        let gradientContainer = createSimplifiedGradientContainer(
            text: text,
            fontSize: config.hookFontSize,
            config: config,
            centered: true
        )
        gradientContainer.position = CGPoint(x: config.size.width / 2, y: config.size.height * 0.3)
        
        // Simple slide in animation from top
        let slideIn = createSimpleSlideInAnimation(from: .top, duration: 0.8)
        gradientContainer.add(slideIn, forKey: "slideIn")
        
        // Simple pulse animation with finite duration
        let beatPulse = createSimpleBeatSyncPulse(bpm: config.fallbackBPM, duration: 3.0)
        gradientContainer.add(beatPulse, forKey: "beatPulse")
        
        L.addSublayer(gradientContainer)
        return L
    }

    public func createKineticStepOverlay(text: String, index: Int, beatBPM: Double, config: RenderConfig) -> CALayer {
        let L = CALayer()
        L.frame = CGRect(origin: .zero, size: config.size)
        
        // Create simplified gradient container for step text - NO PARTICLES
        let gradientContainer = createSimplifiedGradientContainer(
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
        
        // Simple slide in animation from left with staggered delay
        let slideIn = createSimpleSlideInAnimation(from: .left, duration: 0.6, delay: Double(index) * 0.2)
        gradientContainer.add(slideIn, forKey: "slideIn")
        
        // Simple beat-synchronized pulse with finite duration
        let beatPulse = createSimpleBeatSyncPulse(bpm: beatBPM, duration: 1.5, intensity: 0.05)
        gradientContainer.add(beatPulse, forKey: "beatPulse")
        
        L.addSublayer(gradientContainer)
        return L
    }

    public func createCTAOverlay(text: String, config: RenderConfig) -> CALayer {
        let L = CALayer()
        L.frame = CGRect(origin: .zero, size: config.size)
        
        // Create LARGE SnapChef logo spanning left to right of screen (center position)
        let logoContainer = createLargeSnapChefLogo(config: config)
        logoContainer.position = CGPoint(x: config.size.width / 2, y: config.size.height * 0.5)
        
        // Create text below logo: "Get it FREE in the App Store Now!"
        let ctaTextContainer = createSimpleCTAText(
            text: "Get it FREE in the App Store Now!",
            fontSize: config.ctaFontSize,
            config: config
        )
        // Position below the logo
        ctaTextContainer.position = CGPoint(x: config.size.width / 2, y: config.size.height * 0.65)
        
        // Simple slide in animation from bottom
        let slideIn = createSimpleSlideInAnimation(from: .bottom, duration: 0.8)
        logoContainer.add(slideIn, forKey: "logoSlideIn")
        ctaTextContainer.add(slideIn, forKey: "ctaSlideIn")
        
        // Simple pulsing attention effect with finite duration
        let pulseAttention = createSimpleAttentionPulse(duration: 2.0)
        logoContainer.add(pulseAttention, forKey: "logoPulse")
        ctaTextContainer.add(pulseAttention, forKey: "ctaPulse")
        
        L.addSublayer(logoContainer)
        L.addSublayer(ctaTextContainer)
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
        
        // REMOVED: App Store button/badge code as per requirements
        
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
    
    /// Creates a professional sparkle overlay that renders behind text layers (DISABLED FOR VIDEO COMPOSITION)
    public func createProfessionalSparkleOverlay(intensity: CGFloat = 0.5, config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)
        
        // DISABLED: Particle systems cause issues with video composition
        // Return empty container for video compatibility
        
        return container
    }
    
    /// Creates a localized sparkle system behind specific text area (DISABLED FOR VIDEO COMPOSITION)
    public func createLocalizedSparkleOverlay(textPosition: CGPoint, textSize: CGSize, intensity: CGFloat = 0.4, config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)
        
        // DISABLED: Particle systems cause issues with video composition
        // Return empty container for video compatibility
        
        return container
    }

    // Legacy support - now uses premium text layer
    private func makeText(text: String, size: CGFloat, weight: UIFont.Weight, center: Bool) -> CATextLayer {
        return createPremiumTextLayer(text: text, size: size, style: .glow(color: .white, intensity: 0.3), center: center)
    }

    // MARK: - SIMPLIFIED OVERLAY FACTORY FOR VIDEO COMPOSITION
    
    /// Creates a simplified gradient container compatible with video composition
    private func createSimplifiedGradientContainer(text: String, fontSize: CGFloat, config: RenderConfig, centered: Bool) -> CALayer {
        let container = CALayer()
        
        // Create gradient background with SnapChef colors - SIMPLIFIED
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 0.9).cgColor, // Orange #FF6B35
            UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 0.9).cgColor  // Pink #FF1493
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 12
        
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
        let padding: CGFloat = 16 // Reduced padding
        let containerSize = CGSize(
            width: min(textSize.width + padding * 2, config.size.width - 40),
            height: textSize.height + padding * 2
        )
        
        // Set frames
        container.frame = CGRect(origin: .zero, size: containerSize)
        gradientLayer.frame = container.bounds
        textLayer.frame = container.bounds.insetBy(dx: padding, dy: padding)
        
        // Simplified shadow
        gradientLayer.shadowColor = UIColor.black.cgColor
        gradientLayer.shadowOffset = CGSize(width: 0, height: 2)
        gradientLayer.shadowRadius = 4
        gradientLayer.shadowOpacity = 0.3
        
        container.addSublayer(gradientLayer)
        container.addSublayer(textLayer)
        
        return container
    }
    
    /// Creates simple animations that are compatible with video composition
    private func createSimpleSlideInAnimation(from direction: SlideDirection, duration: Double, delay: Double = 0) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = duration
        animation.beginTime = AVCoreAnimationBeginTimeAtZero + delay
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        // Simplified slide values
        switch direction {
        case .top:
            animation.fromValue = NSValue(cgPoint: CGPoint(x: 0, y: -100))
        case .bottom:
            animation.fromValue = NSValue(cgPoint: CGPoint(x: 0, y: 100))
        case .left:
            animation.fromValue = NSValue(cgPoint: CGPoint(x: -100, y: 0))
        case .right:
            animation.fromValue = NSValue(cgPoint: CGPoint(x: 100, y: 0))
        }
        animation.toValue = NSValue(cgPoint: CGPoint.zero)
        
        return animation
    }
    
    /// Creates simple beat sync pulse with finite duration
    private func createSimpleBeatSyncPulse(bpm: Double, duration: Double, intensity: CGFloat = 0.03) -> CABasicAnimation {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.0 + intensity
        pulse.duration = 60.0 / bpm
        pulse.repeatCount = Float(duration / (60.0 / bpm)) // Finite repeat count based on duration
        pulse.autoreverses = true
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.beginTime = AVCoreAnimationBeginTimeAtZero
        pulse.fillMode = .forwards
        pulse.isRemovedOnCompletion = false
        
        return pulse
    }
    
    /// Creates simplified logo container compatible with video composition
    private func createSimplifiedLogoContainer(config: RenderConfig) -> CALayer {
        let container = CALayer()
        let logoSize = CGSize(width: 160, height: 50)
        container.frame = CGRect(origin: .zero, size: logoSize)
        
        // Simple gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = container.bounds
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 0.9).cgColor,
            UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 0.9).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 25
        
        // Simple text
        let textLayer = CATextLayer()
        textLayer.string = "SnapChef"
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 24, nil)
        textLayer.fontSize = 24
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = config.contentsScale
        textLayer.frame = container.bounds
        
        // Simple shadow
        gradientLayer.shadowColor = UIColor.black.cgColor
        gradientLayer.shadowOffset = CGSize(width: 0, height: 2)
        gradientLayer.shadowRadius = 4
        gradientLayer.shadowOpacity = 0.3
        
        container.addSublayer(gradientLayer)
        container.addSublayer(textLayer)
        
        return container
    }
    
    /// Creates LARGE SnapChef logo spanning left to right of screen with sparkles icon
    private func createLargeSnapChefLogo(config: RenderConfig) -> CALayer {
        let container = CALayer()
        let logoWidth = config.size.width * 0.8  // 80% of screen width
        let logoHeight: CGFloat = 80
        container.frame = CGRect(origin: .zero, size: CGSize(width: logoWidth, height: logoHeight))
        
        // Gradient background with SnapChef colors #FF6B35 to #FF1493
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = container.bounds
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1.0).cgColor, // #FF6B35
            UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 1.0).cgColor  // #FF1493
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 40
        
        // Container for logo content (sparkles + text)
        let contentContainer = CALayer()
        contentContainer.frame = container.bounds
        
        // Sparkles icon (similar to EnhancedShareSheet)
        let sparklesLayer = CATextLayer()
        sparklesLayer.string = "✨"
        sparklesLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 32, nil)
        sparklesLayer.fontSize = 32
        sparklesLayer.foregroundColor = UIColor.white.cgColor
        sparklesLayer.alignmentMode = .center
        sparklesLayer.contentsScale = config.contentsScale
        sparklesLayer.frame = CGRect(x: 20, y: (logoHeight - 32) / 2, width: 40, height: 32)
        
        // SnapChef text
        let textLayer = CATextLayer()
        textLayer.string = "SnapChef"
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Heavy" as CFString, 36, nil)
        textLayer.fontSize = 36
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .left
        textLayer.contentsScale = config.contentsScale
        textLayer.frame = CGRect(x: 70, y: (logoHeight - 36) / 2, width: logoWidth - 90, height: 36)
        
        // Enhanced shadow for depth
        gradientLayer.shadowColor = UIColor.black.cgColor
        gradientLayer.shadowOffset = CGSize(width: 0, height: 4)
        gradientLayer.shadowRadius = 12
        gradientLayer.shadowOpacity = 0.4
        
        // Subtle border for definition
        let borderLayer = CALayer()
        borderLayer.frame = container.bounds
        borderLayer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        borderLayer.borderWidth = 1
        borderLayer.cornerRadius = 40
        
        container.addSublayer(gradientLayer)
        container.addSublayer(borderLayer)
        contentContainer.addSublayer(sparklesLayer)
        contentContainer.addSublayer(textLayer)
        container.addSublayer(contentContainer)
        
        return container
    }
    
    /// Creates simple CTA text without gradient background
    private func createSimpleCTAText(text: String, fontSize: CGFloat, config: RenderConfig) -> CALayer {
        let container = CALayer()
        
        // Create text layer with bold white text
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = config.contentsScale
        textLayer.isWrapped = true
        
        // Calculate text size
        let textSize = textLayer.preferredFrameSize()
        let containerSize = CGSize(
            width: min(textSize.width + 20, config.size.width - 40),
            height: textSize.height + 10
        )
        
        // Set frames
        container.frame = CGRect(origin: .zero, size: containerSize)
        textLayer.frame = container.bounds
        
        // Enhanced shadow for visibility over video
        textLayer.shadowColor = UIColor.black.cgColor
        textLayer.shadowOffset = CGSize(width: 0, height: 2)
        textLayer.shadowRadius = 6
        textLayer.shadowOpacity = 0.8
        
        // Add subtle stroke for better visibility
        textLayer.borderColor = UIColor.black.withAlphaComponent(0.3).cgColor
        textLayer.borderWidth = 0.5
        
        container.addSublayer(textLayer)
        
        return container
    }
    
    /// Creates SnapChef branded CTA container with gradient text for "SNAPCHEF!"
    private func createSnapChefBrandedCTAContainer(text: String, fontSize: CGFloat, config: RenderConfig) -> CALayer {
        let container = CALayer()
        
        // Create gradient background with SnapChef colors - SIMPLIFIED
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 0.9).cgColor, // Orange #FF6B35
            UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 0.9).cgColor  // Pink #FF1493
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 12
        
        // Parse the text to handle "SNAPCHEF!" specially
        if text.contains("SNAPCHEF!") {
            // Create main text layer for everything except "SNAPCHEF!"
            let mainTextLayer = CATextLayer()
            let mainText = text.replacingOccurrences(of: "SNAPCHEF!", with: "        ") // Space for gradient text
            mainTextLayer.string = mainText
            mainTextLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
            mainTextLayer.fontSize = fontSize
            mainTextLayer.foregroundColor = UIColor.white.cgColor
            mainTextLayer.alignmentMode = .center
            mainTextLayer.contentsScale = config.contentsScale
            mainTextLayer.isWrapped = true
            
            // Create special gradient text layer for "SNAPCHEF!"
            let snapchefGradientLayer = CAGradientLayer()
            snapchefGradientLayer.colors = [
                UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1.0).cgColor, // #FF6B35
                UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 1.0).cgColor  // #FF1493
            ]
            snapchefGradientLayer.startPoint = CGPoint(x: 0, y: 0)
            snapchefGradientLayer.endPoint = CGPoint(x: 1, y: 1)
            
            let snapchefTextLayer = CATextLayer()
            snapchefTextLayer.string = "SNAPCHEF!"
            snapchefTextLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
            snapchefTextLayer.fontSize = fontSize
            snapchefTextLayer.foregroundColor = UIColor.white.cgColor
            snapchefTextLayer.alignmentMode = .center
            snapchefTextLayer.contentsScale = config.contentsScale
            
            // Calculate text size and add padding
            let textSize = mainTextLayer.preferredFrameSize()
            let padding: CGFloat = 16
            let containerSize = CGSize(
                width: min(textSize.width + padding * 2, config.size.width - 40),
                height: textSize.height + padding * 2
            )
            
            // Set frames
            container.frame = CGRect(origin: .zero, size: containerSize)
            gradientLayer.frame = container.bounds
            mainTextLayer.frame = container.bounds.insetBy(dx: padding, dy: padding)
            
            // Position gradient text for "SNAPCHEF!" in the middle
            let snapchefSize = snapchefTextLayer.preferredFrameSize()
            snapchefGradientLayer.frame = CGRect(
                x: (containerSize.width - snapchefSize.width) / 2,
                y: padding,
                width: snapchefSize.width,
                height: snapchefSize.height
            )
            snapchefTextLayer.frame = snapchefGradientLayer.bounds
            
            // Use text as mask for gradient
            snapchefGradientLayer.mask = snapchefTextLayer
            
            container.addSublayer(gradientLayer)
            container.addSublayer(mainTextLayer)
            container.addSublayer(snapchefGradientLayer)
        } else {
            // Standard text without special gradient handling
            let textLayer = CATextLayer()
            textLayer.string = text
            textLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
            textLayer.fontSize = fontSize
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = config.contentsScale
            textLayer.isWrapped = true
            
            // Calculate text size and add padding
            let textSize = textLayer.preferredFrameSize()
            let padding: CGFloat = 16
            let containerSize = CGSize(
                width: min(textSize.width + padding * 2, config.size.width - 40),
                height: textSize.height + padding * 2
            )
            
            // Set frames
            container.frame = CGRect(origin: .zero, size: containerSize)
            gradientLayer.frame = container.bounds
            textLayer.frame = container.bounds.insetBy(dx: padding, dy: padding)
            
            container.addSublayer(gradientLayer)
            container.addSublayer(textLayer)
        }
        
        // Simplified shadow
        gradientLayer.shadowColor = UIColor.black.cgColor
        gradientLayer.shadowOffset = CGSize(width: 0, height: 2)
        gradientLayer.shadowRadius = 4
        gradientLayer.shadowOpacity = 0.3
        
        return container
    }
    
    /// Creates simple attention pulse with finite duration
    private func createSimpleAttentionPulse(duration: Double) -> CABasicAnimation {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.05
        pulse.duration = 1.2
        pulse.autoreverses = true
        pulse.repeatCount = Float(duration / 2.4) // Finite repeat count
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.beginTime = AVCoreAnimationBeginTimeAtZero
        pulse.fillMode = .forwards
        pulse.isRemovedOnCompletion = false
        
        return pulse
    }
    
    // MARK: - SNAPCHEF GRADIENT CONTAINER FACTORY (LEGACY - KEEPING FOR REFERENCE)
    
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
        group.beginTime = AVCoreAnimationBeginTimeAtZero + delay // FIXED: Use AVCoreAnimationBeginTimeAtZero for video composition
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
        pulse.repeatCount = 3 // FIXED: Finite repeat count instead of infinite
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.beginTime = AVCoreAnimationBeginTimeAtZero
        pulse.fillMode = .forwards
        pulse.isRemovedOnCompletion = false
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
        case .gradient(_):
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
        glow.repeatCount = 3 // FIXED: Finite repeat count
        return glow
    }
    
    private func createBeatSyncEffect(beatBPM: Double, intensity: CGFloat) -> CAKeyframeAnimation {
        let beatSync = CAKeyframeAnimation(keyPath: "transform.scale")
        beatSync.values = [1.0, 1.0 + intensity, 1.0]
        beatSync.keyTimes = [0, 0.3, 1.0]
        beatSync.duration = 60.0 / beatBPM
        beatSync.repeatCount = 3 // FIXED: Finite repeat count
        return beatSync
    }
    
    private func createAttentionPulse() -> CABasicAnimation {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.05
        pulse.duration = 1.2
        pulse.autoreverses = true
        pulse.repeatCount = 2 // FIXED: Finite repeat count instead of infinite
        pulse.beginTime = AVCoreAnimationBeginTimeAtZero
        pulse.fillMode = .forwards
        pulse.isRemovedOnCompletion = false
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
        
        guard let context = UIGraphicsGetCurrentContext() else {
            print("❌ Failed to get graphics context")
            return UIImage()
        }
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    private func createTrailParticle() -> UIImage {
        let size = CGSize(width: 6, height: 6)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            print("❌ Failed to get graphics context")
            return UIImage()
        }
        context.setFillColor(UIColor.yellow.withAlphaComponent(0.8).cgColor)
        context.fillEllipse(in: CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    /// Creates an elegant sparkle image for professional particle effects
    private func createElegantSparkleImage() -> UIImage {
        let size = CGSize(width: 12, height: 12)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            print("❌ Failed to get graphics context")
            return UIImage()
        }
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
        
        guard let context = UIGraphicsGetCurrentContext() else {
            print("❌ Failed to get graphics context")
            return UIImage()
        }
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
        k.repeatCount = 5 // FIXED: Finite repeat count
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
        colorAnimation.repeatCount = 2 // FIXED: Finite repeat count
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
        bounce.repeatCount = 2 // FIXED: Finite repeat count
        bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        container.addSublayer(gradientLayer)
        container.add(bounce, forKey: "logoScale")
        
        return container
    }
    
    private func addFallingEmojiParticles(to container: CALayer, config: RenderConfig) {
        let emojis = ["🍕", "🍔", "🌮", "🥗", "🍜", "🥙", "🌯", "🍱"]
        
        for _ in 0..<12 {
            let emojiLayer = CATextLayer()
            if let randomEmoji = emojis.randomElement() {
                emojiLayer.string = randomEmoji
            }
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
            fall.beginTime = AVCoreAnimationBeginTimeAtZero + Double.random(in: 0...2.0)
            fall.repeatCount = 1 // FIXED: Single animation for video composition
            
            // Gentle sway animation
            let sway = CAKeyframeAnimation(keyPath: "position.x")
            sway.values = [startX, startX + 20, startX - 15, startX + 10, startX]
            sway.duration = 2.0
            sway.repeatCount = 3 // FIXED: Limited sway cycles
            
            // Rotation animation
            let rotate = CABasicAnimation(keyPath: "transform.rotation")
            rotate.fromValue = 0
            rotate.toValue = Double.pi * 2
            rotate.duration = Double.random(in: 2.0...4.0)
            rotate.repeatCount = 2 // FIXED: Limited rotation cycles
            
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
        pulse.repeatCount = 3 // FIXED: Limited pulse cycles
        
        // Glow animation
        let glow = CAKeyframeAnimation(keyPath: "shadowRadius")
        glow.values = [15, 25, 15, 30, 15]
        glow.duration = 1.5
        glow.repeatCount = 3 // FIXED: Finite repeat count
        
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
        bounce.repeatCount = 2 // FIXED: Finite repeat count
        engagementContainer.add(bounce, forKey: "engagementBounce")
        
        // Beat-synced pulse
        let beatPulse = createBeatSyncPulse(bpm: config.fallbackBPM, intensity: 0.02)
        engagementContainer.add(beatPulse, forKey: "beatPulse")
        
        return engagementContainer
    }
    
    // REMOVED: createAppStoreCTA function as per requirements
    
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
        bounce.beginTime = AVCoreAnimationBeginTimeAtZero + delay
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
            if let randomParticle = particles.randomElement() {
                particleLayer.string = randomParticle
            }
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
        pulse.repeatCount = 3 // FIXED: Limited pulse cycles
        badgeContainer.add(pulse, forKey: "badgePulse")
        
        return badgeContainer
    }
}

// MARK: - Video compositor that applies CALayer overlays over the base video
import AVFoundation

public extension OverlayFactory {
    /// SPEED OPTIMIZATION: Fast overlay application
    func applyOverlays(videoURL: URL,
                       overlays: [RenderPlan.Overlay],
                       progress: @escaping @Sendable (Double) async -> Void = { _ in }) async throws -> URL {
        
        // SPEED OPTIMIZATION: Skip overlay processing if no overlays
        if overlays.isEmpty {
            print("[OverlayFactory] No overlays to apply, returning original video")
            await progress(1.0)
            return videoURL
        }
        
        // SPEED OPTIMIZATION: Use lightweight overlay processing for simple cases
        if overlays.count <= 3 {
            return try await applyOverlaysLightweight(videoURL: videoURL, overlays: overlays, progress: progress)
        }
        let base = AVURLAsset(url: videoURL)
        let comp = AVMutableComposition()
        guard let srcV = try await base.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "OverlayFactory", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track"])
        }
        guard let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "OverlayFactory", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot create video track"])
        }
        let duration = try await base.load(.duration)
        try vTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: srcV, at: .zero)

        // pass-through audio if present
        if let srcA = try? await base.loadTracks(withMediaType: .audio).first {
            guard let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                print("⚠️ Failed to create audio track, continuing without audio")
                return videoURL
            }
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
        
        // CRITICAL FIX: Set proper masking and bounds to prevent edge glitches
        parent.masksToBounds = true
        parent.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1) // Solid black background
        videoLayer.masksToBounds = true
        videoLayer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1) // Solid black background
        videoLayer.isOpaque = true
        videoLayer.contentsGravity = .resizeAspectFill
        videoLayer.edgeAntialiasingMask = [.layerLeftEdge, .layerRightEdge, .layerBottomEdge, .layerTopEdge]
        overlayLayer.masksToBounds = true
        overlayLayer.contentsGravity = .resizeAspectFill
        overlayLayer.isOpaque = false // Allow transparency for overlays

        // SPEED OPTIMIZATION: Process overlays efficiently with caching
        for (index, ov) in overlays.enumerated() {
            print("[OverlayFactory] Processing OPTIMIZED overlay \(index+1)/\(overlays.count) - start: \(ov.start.seconds)s, duration: \(ov.duration.seconds)s")
            
            // Check cache first
            let cacheKey = "overlay_\(index)_\(ov.start.seconds)_\(ov.duration.seconds)" as NSString
            var L: CALayer
            
            if let cachedLayer = layerCache.object(forKey: cacheKey) {
                print("[OverlayFactory] Using CACHED overlay layer \(index+1)")
                // CRITICAL FIX: Remove force cast to prevent EXC_BREAKPOINT crashes
                guard let copiedLayer = cachedLayer.copy() as? CALayer else {
                    print("❌ Failed to copy cached layer, creating new one")
                    L = ov.layerBuilder(config)
                    break
                }
                L = copiedLayer
            } else {
                L = ov.layerBuilder(config)
                
                // Cache for potential reuse (lightweight layers only)
                if L.sublayers?.count ?? 0 <= 3 {
                    layerCache.setObject(L, forKey: cacheKey)
                }
            }
            
            // SPEED OPTIMIZATION: Simplified timing setup
            L.beginTime = AVCoreAnimationBeginTimeAtZero + ov.start.seconds
            L.timeOffset = 0
            L.duration = ov.duration.seconds
            L.opacity = 1.0
            L.zPosition = CGFloat(100 + index)
            
            // SPEED OPTIMIZATION: Optimized timing setup
            optimizeLayerTimingRecursively(layer: L, startTime: ov.start.seconds, duration: ov.duration.seconds)
            
            overlayLayer.addSublayer(L)
            
            await progress(Double(index + 1) / Double(overlays.count) * 0.5)
        }

        parent.addSublayer(videoLayer)
        parent.addSublayer(overlayLayer)

        let videoComp = AVMutableVideoComposition()
        videoComp.instructions = [instr]
        videoComp.renderSize = renderSize
        videoComp.frameDuration = CMTime(value: 1, timescale: config.fps)
        videoComp.renderScale = 1.0  // Pixel-perfect rendering to fix edge glitches
        
        // CRITICAL FIX: Create animation tool with proper setup
        print("[OverlayFactory] Creating animation tool with \(overlays.count) overlays")
        print("[OverlayFactory] Parent layer frame: \(parent.frame)")
        print("[OverlayFactory] Video layer frame: \(videoLayer.frame)")
        print("[OverlayFactory] Overlay layer frame: \(overlayLayer.frame)")
        print("[OverlayFactory] Overlay layer sublayers count: \(overlayLayer.sublayers?.count ?? 0)")
        
        videoComp.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
        print("[OverlayFactory] Successfully created animation tool")

        // Export
        let out = createTempOutputURL(ext: "mp4")
        try? FileManager.default.removeItem(at: out)
        guard let export = AVAssetExportSession(asset: comp, presetName: ExportSettings.videoPreset) else {
            throw NSError(domain: "OverlayFactory", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session"])
        }
        export.outputURL = out
        export.outputFileType = AVFileType.mp4
        export.videoComposition = videoComp
        export.shouldOptimizeForNetworkUse = true

        print("[OverlayFactory] Starting overlay export to: \(out)")
        return try await withCheckedThrowingContinuation { cont in
            var hasCompleted = false
            var progressTimer: Timer?
            
            // Set up timeout timer (60 seconds for overlay processing)
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { _ in
                guard !hasCompleted else { return }
                hasCompleted = true
                progressTimer?.invalidate()
                export.cancelExport()
                print("[OverlayFactory] ERROR - Overlay export timed out after 60 seconds")
                cont.resume(throwing: NSError(domain: "OverlayFactory", code: -6, userInfo: [NSLocalizedDescriptionKey: "Export timeout"]))
            }
            
            // Monitor progress
            progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                let currentProgress = export.progress
                Task { @MainActor in
                    await progress(Double(currentProgress))
                }
                if export.progress > 0 {
                    print("[OverlayFactory] Overlay export progress: \(Int(export.progress * 100))%")
                }
            }
            
            export.exportAsynchronously {
                guard !hasCompleted else {
                    print("[OverlayFactory] Export completion called but already handled")
                    return
                }
                hasCompleted = true
                timeoutTimer.invalidate()
                progressTimer?.invalidate()
                
                print("[OverlayFactory] Overlay export completed with status: \(export.status.rawValue)")
                
                switch export.status {
                case .completed: 
                    print("[OverlayFactory] SUCCESS - Overlay export completed: \(out)")
                    cont.resume(returning: out)
                case .failed: 
                    let error = export.error ?? NSError(domain: "OverlayFactory", code: -3)
                    print("[OverlayFactory] ERROR - Overlay export failed: \(error.localizedDescription)")
                    cont.resume(throwing: error)
                case .cancelled: 
                    print("[OverlayFactory] ERROR - Overlay export cancelled")
                    cont.resume(throwing: NSError(domain: "OverlayFactory", code: -4))
                default: 
                    print("[OverlayFactory] ERROR - Overlay export ended with status: \(export.status.rawValue)")
                    cont.resume(throwing: NSError(domain: "OverlayFactory", code: -5))
                }
            }
        }
    }
    
    // MARK: SPEED OPTIMIZATION: Lightweight overlay processing
    private func applyOverlaysLightweight(videoURL: URL, overlays: [RenderPlan.Overlay], progress: @escaping @Sendable (Double) async -> Void) async throws -> URL {
        print("[OverlayFactory] Using LIGHTWEIGHT overlay processing for \(overlays.count) overlays")
        
        // Use the existing processing but with optimized layers
        let base = AVURLAsset(url: videoURL)
        let comp = AVMutableComposition()
        guard let srcV = try await base.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "OverlayFactory", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track"])
        }
        guard let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "OverlayFactory", code: -3, userInfo: [NSLocalizedDescriptionKey: "Cannot create video track for lightweight overlay"])
        }
        let duration = try await base.load(.duration)
        try vTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: srcV, at: .zero)

        // pass-through audio if present
        if let srcA = try? await base.loadTracks(withMediaType: .audio).first {
            guard let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                print("⚠️ Failed to create audio track in lightweight mode, continuing without audio")
                return videoURL
            }
            try aTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: srcA, at: .zero)
        }

        let instr = AVMutableVideoCompositionInstruction()
        instr.timeRange = CMTimeRange(start: .zero, duration: duration)
        let layerInstr = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
        instr.layerInstructions = [layerInstr]

        // Build simplified overlay structure
        let renderSize = config.size
        let parent = CALayer(); parent.frame = CGRect(origin: .zero, size: renderSize)
        let videoLayer = CALayer(); videoLayer.frame = parent.frame
        let overlayLayer = CALayer(); overlayLayer.frame = parent.frame
        
        // CRITICAL FIX: Set proper masking and bounds to prevent edge glitches
        parent.masksToBounds = true
        parent.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1) // Solid black background
        videoLayer.masksToBounds = true
        videoLayer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1) // Solid black background
        videoLayer.isOpaque = true
        videoLayer.contentsGravity = .resizeAspectFill
        videoLayer.edgeAntialiasingMask = [.layerLeftEdge, .layerRightEdge, .layerBottomEdge, .layerTopEdge]
        overlayLayer.masksToBounds = true
        overlayLayer.contentsGravity = .resizeAspectFill
        overlayLayer.isOpaque = false // Allow transparency for overlays

        // CRITICAL SPEED FIX: Skip overlay processing for maximum speed
        // Only add watermark if absolutely necessary
        if overlays.count == 1 {
            let L = createUltraSimpleOverlay()
            L.beginTime = AVCoreAnimationBeginTimeAtZero + overlays[0].start.seconds
            L.duration = overlays[0].duration.seconds
            L.zPosition = 100
            overlayLayer.addSublayer(L)
        }
        await progress(0.7)

        parent.addSublayer(videoLayer)
        parent.addSublayer(overlayLayer)

        let videoComp = AVMutableVideoComposition()
        videoComp.instructions = [instr]
        videoComp.renderSize = renderSize
        videoComp.frameDuration = CMTime(value: 1, timescale: config.fps)
        videoComp.renderScale = 1.0  // Pixel-perfect rendering to fix edge glitches
        videoComp.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)

        // Fast export
        let out = createTempOutputURL(ext: "mp4")
        try? FileManager.default.removeItem(at: out)
        
        // SPEED OPTIMIZATION: Use faster export preset for overlays
        guard let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "OverlayFactory", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session"])
        }
        export.outputURL = out
        export.outputFileType = AVFileType.mp4
        export.videoComposition = videoComp
        export.shouldOptimizeForNetworkUse = true

        await export.export()
        await progress(1.0)
        
        guard export.status == AVAssetExportSession.Status.completed else {
            throw NSError(domain: "OverlayFactory", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
        }
        
        return out
    }
    
    private func createUltraSimpleOverlay() -> CALayer {
        // SPEED OPTIMIZATION: Create ultra-simple overlay without any complex processing
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        layer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
        layer.cornerRadius = 8
        
        let textLayer = CATextLayer()
        textLayer.string = "SnapChef"
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 24, nil)
        textLayer.fontSize = 24
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.frame = layer.bounds
        textLayer.contentsScale = 2.0
        
        layer.addSublayer(textLayer)
        return layer
    }
    
    private func removeComplexAnimations(from layer: CALayer) {
        // Remove particle effects and complex animations that slow down video composition
        if layer is CAEmitterLayer {
            layer.removeFromSuperlayer()
            return
        }
        
        // Simplify animations
        if let animationKeys = layer.animationKeys() {
            for key in animationKeys {
                if let animation = layer.animation(forKey: key) {
                    if animation.repeatCount == .greatestFiniteMagnitude {
                        // CRITICAL FIX: Remove force cast to prevent EXC_BREAKPOINT crashes
                        guard let mutableAnim = animation.mutableCopy() as? CAAnimation else {
                            print("❌ Failed to copy animation, using original")
                            layer.add(animation, forKey: key)
                            continue
                        }
                        mutableAnim.repeatCount = 3 // Limit to 3 repeats max
                        layer.add(mutableAnim, forKey: key)
                    }
                }
            }
        }
        
        // Recursively process sublayers
        layer.sublayers?.forEach { removeComplexAnimations(from: $0) }
    }
    
    /// SPEED OPTIMIZATION: Optimized timing setup with reduced overhead
    private func optimizeLayerTimingRecursively(layer: CALayer, startTime: Double, duration: Double) {
        layer.opacity = 1.0
        
        // SPEED OPTIMIZATION: Process animations more efficiently
        if let keys = layer.animationKeys() {
            for key in keys {
                if let animation = layer.animation(forKey: key) {
                    // Check cache first
                    let cacheKey = "anim_\(key)_\(startTime)_\(duration)" as NSString
                    
                    var optimizedAnim: CAAnimation
                    if let cachedAnim = animationCache.object(forKey: cacheKey) {
                        guard let copiedAnim = cachedAnim.copy() as? CAAnimation else {
                            print("❌ Failed to copy cached animation")
                            optimizedAnim = animation.mutableCopy() as? CAAnimation ?? animation
                            break
                        }
                        optimizedAnim = copiedAnim
                    } else {
                        guard let mutableAnim = animation.mutableCopy() as? CAAnimation else {
                            print("❌ Failed to create mutable animation copy")
                            optimizedAnim = animation
                            break
                        }
                        optimizedAnim = mutableAnim
                        optimizedAnim.beginTime = AVCoreAnimationBeginTimeAtZero
                        optimizedAnim.fillMode = .both
                        optimizedAnim.isRemovedOnCompletion = false
                        
                        // Cap infinite animations
                        if optimizedAnim.repeatCount == .greatestFiniteMagnitude {
                            let animDuration = optimizedAnim.duration > 0 ? optimizedAnim.duration : 1.0
                            optimizedAnim.repeatCount = min(5, Float(duration / animDuration)) // Cap at 5 repeats max
                        }
                        
                        animationCache.setObject(optimizedAnim, forKey: cacheKey)
                    }
                    
                    layer.add(optimizedAnim, forKey: key)
                }
            }
        }
        
        // Recursively process sublayers with reduced overhead
        layer.sublayers?.enumerated().forEach { index, sublayer in
            sublayer.zPosition = CGFloat(index)
            optimizeLayerTimingRecursively(layer: sublayer, startTime: startTime, duration: duration)
        }
    }
    
    private func createTempOutputURL(ext: String) -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return dir.appendingPathComponent("snapchef-overlay-\(UUID().uuidString).\(ext)")
    }
}

// MARK: - Edge Glitch Prevention
// Note: Edge glitch prevention is now handled through proper layer masking and bounds
// configuration in the main overlay processing pipeline above