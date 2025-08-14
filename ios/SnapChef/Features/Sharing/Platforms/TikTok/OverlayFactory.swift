//
//  OverlayFactory.swift
//  SnapChef
//
//  Created on 12/01/2025
//  Text and sticker generation with exact typography specifications from requirements
//

import UIKit
import AVFoundation
import CoreImage
import CoreMedia
import QuartzCore

/// OverlayFactory for text and sticker generation following exact specifications
public final class OverlayFactory: @unchecked Sendable {  // Swift 6: Sendable for thread safety
    
    private let config: RenderConfig
    private let memoryOptimizer: MemoryOptimizer
    private let performanceAnalyzer: PerformanceAnalyzer
    
    // Pre-computed layer cache for performance optimization
    private var layerCache: [String: CALayer] = [:]
    private let cacheQueue = DispatchQueue(label: "com.snapchef.overlay.cache", attributes: .concurrent)
    private let maxCacheSize = 20 // Limit cache size to prevent memory bloat
    
    public init(config: RenderConfig) {
        self.config = config
        self.memoryOptimizer = MemoryOptimizer.shared
        self.performanceAnalyzer = PerformanceAnalyzer.shared
    }
    
    // MARK: - Public Interface
    
    /// Apply overlays to video with progress tracking
    public func applyOverlays(
        videoURL: URL,
        overlays: [RenderPlan.Overlay],
        progressCallback: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        
        print("🎨 DEBUG OverlayFactory: Starting overlay application")
        print("🎨 DEBUG OverlayFactory: Input video: \(videoURL.lastPathComponent)")
        print("🎨 DEBUG OverlayFactory: Number of overlays: \(overlays.count)")
        
        // Start performance monitoring
        memoryOptimizer.logMemoryProfile(phase: "OverlayFactory Start")
        
        let outputURL = createTempOutputURL()
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        let asset = AVAsset(url: videoURL)
        
        // Create video composition with overlays
        print("🎨 DEBUG OverlayFactory: Creating video composition...")
        let videoComposition = try await createVideoCompositionWithOverlays(
            asset: asset,
            overlays: overlays
        )
        print("✅ DEBUG OverlayFactory: Video composition created")
        
        // Export with overlays
        print("🎨 DEBUG OverlayFactory: Creating export session...")
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: ExportSettings.videoPreset
        ) else {
            print("❌ DEBUG OverlayFactory: Failed to create export session")
            throw OverlayError.cannotCreateExportSession
        }
        print("✅ DEBUG OverlayFactory: Export session created")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        return try await withCheckedThrowingContinuation { continuation in
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak exportSession] _ in
                guard let exportSession = exportSession else { return }
                let progress = Double(exportSession.progress)
                Task { @MainActor in
                    await progressCallback(progress)
                }
            }
            
            print("🎨 DEBUG OverlayFactory: Starting export asynchronously...")
            exportSession.exportAsynchronously {
                progressTimer.invalidate()
                
                // Complete performance monitoring
                self.memoryOptimizer.logMemoryProfile(phase: "OverlayFactory Complete")
                
                print("🎨 DEBUG OverlayFactory: Export completed with status: \(exportSession.status.rawValue)")
                
                switch exportSession.status {
                case .completed:
                    print("✅ DEBUG OverlayFactory: Export successful to: \(outputURL.lastPathComponent)")
                    // Clean up input file immediately
                    self.memoryOptimizer.deleteTempFile(videoURL)
                    continuation.resume(returning: outputURL)
                case .failed:
                    let error = exportSession.error ?? OverlayError.exportFailed
                    print("❌ DEBUG OverlayFactory: Export failed with error: \(error)")
                    print("❌ DEBUG OverlayFactory: Error domain: \((error as NSError).domain)")
                    print("❌ DEBUG OverlayFactory: Error code: \((error as NSError).code)")
                    print("❌ DEBUG OverlayFactory: Error userInfo: \((error as NSError).userInfo)")
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: OverlayError.exportCancelled)
                default:
                    continuation.resume(throwing: OverlayError.exportFailed)
                }
            }
        }
    }
    
    // MARK: - Required Overlays (Exact Typography Specifications)
    
    /// 1. heroHookOverlay - 64pt white text with stroke
    public func createHeroHookOverlay(text: String, config: RenderConfig) -> CALayer {
        return createHookOverlay(text: text, config: config)
    }
    
    /// Create hook overlay - 60-72pt bold (64pt default)
    public func createHookOverlay(text: String, config: RenderConfig) -> CALayer {
        // Check cache first for performance
        let cacheKey = "hook_\(text)_\(config.size.width)x\(config.size.height)"
        if let cachedLayer = getCachedLayer(key: cacheKey) {
            return cachedLayer
        }
        
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Validate safe zones (MANDATORY)
        validateSafeZones(config: config)
        
        // Hook text with exact specifications - 64pt white with stroke
        let textLayer = createTextLayer(
            text: text,
            fontSize: config.hookFontSize,
            fontWeight: .bold,
            color: config.brandTint,
            maxWidth: config.size.width - (config.safeInsets.left + config.safeInsets.right),
            alignment: .center,
            strokeEnabled: true
        )
        
        // Position in safe area - center vertically
        let textSize = textLayer.preferredFrameSize()
        textLayer.frame = CGRect(
            x: config.safeInsets.left,
            y: (config.size.height - textSize.height) / 2,
            width: config.size.width - (config.safeInsets.left + config.safeInsets.right),
            height: textSize.height
        )
        
        // Add hero hook animation - fade in 0.3s
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0.0
        fadeAnimation.toValue = 1.0
        fadeAnimation.duration = config.fadeDuration
        fadeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        textLayer.add(fadeAnimation, forKey: "fadeIn")
        
        containerLayer.addSublayer(textLayer)
        
        // Cache the layer for future use
        cacheLayer(key: cacheKey, layer: containerLayer)
        
        return containerLayer
    }
    
    /// 2. ctaOverlay - Rounded sticker with spring animation (already implemented)
    /// Create CTA overlay - 40pt bold in rounded stickers with pop animation
    public func createCTAOverlay(text: String, config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Validate safe zones (MANDATORY)
        validateSafeZones(config: config)
        
        // Create rounded sticker background
        let stickerLayer = CALayer()
        stickerLayer.backgroundColor = UIColor.black.withAlphaComponent(0.8).cgColor
        stickerLayer.cornerRadius = 25
        
        // CTA text
        let textLayer = createTextLayer(
            text: text,
            fontSize: config.ctaFontSize,
            fontWeight: .bold,
            color: config.brandTint,
            maxWidth: config.size.width - (config.safeInsets.left + config.safeInsets.right) - 40, // Padding for sticker
            alignment: .center
        )
        
        let textSize = textLayer.preferredFrameSize()
        let stickerWidth = textSize.width + 40 // 20px padding each side
        let stickerHeight = textSize.height + 20 // 10px padding top/bottom
        
        // Position sticker in bottom safe area
        stickerLayer.frame = CGRect(
            x: (config.size.width - stickerWidth) / 2,
            y: config.size.height - config.safeInsets.bottom - stickerHeight - 20,
            width: stickerWidth,
            height: stickerHeight
        )
        
        textLayer.frame = CGRect(
            x: 20,
            y: 10,
            width: textSize.width,
            height: textSize.height
        )
        
        // CTA Pop animation - Spring 0.6s with scale 0.6→1.0
        let scaleAnimation = CASpringAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = config.scaleRange.lowerBound
        scaleAnimation.toValue = config.scaleRange.upperBound
        scaleAnimation.duration = 0.6
        scaleAnimation.damping = config.springDamping
        scaleAnimation.stiffness = 100
        scaleAnimation.mass = 1
        
        stickerLayer.add(scaleAnimation, forKey: "ctaPop")
        
        stickerLayer.addSublayer(textLayer)
        containerLayer.addSublayer(stickerLayer)
        return containerLayer
    }
    
    /// 4. splitWipeMaskOverlay - Circular reveal from center
    public func createSplitWipeMaskOverlay(progress: Double, config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Create circular mask that reveals from center
        let maskLayer = CAShapeLayer()
        let centerPoint = CGPoint(x: config.size.width / 2, y: config.size.height / 2)
        let maxRadius = sqrt(pow(config.size.width / 2, 2) + pow(config.size.height / 2, 2))
        let currentRadius = maxRadius * CGFloat(progress)
        
        let circlePath = UIBezierPath(arcCenter: centerPoint, radius: currentRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        maskLayer.path = circlePath.cgPath
        maskLayer.fillColor = UIColor.white.cgColor
        
        containerLayer.mask = maskLayer
        
        // Animate the circular reveal
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = UIBezierPath(arcCenter: centerPoint, radius: 0, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        animation.toValue = circlePath.cgPath
        animation.duration = 1.5 // As specified in requirements
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        maskLayer.add(animation, forKey: "circularReveal")
        
        return containerLayer
    }
    
    /// 5. ingredientCountersOverlay - Staggered chips
    public func createIngredientCountersOverlay(ingredients: [String], config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Validate safe zones
        validateSafeZones(config: config)
        
        let processedIngredients = CaptionGenerator.processIngredientText(ingredients)
        
        for (index, ingredient) in processedIngredients.enumerated() {
            let chipLayer = createIngredientChip(text: ingredient, index: index, config: config)
            containerLayer.addSublayer(chipLayer)
        }
        
        return containerLayer
    }
    
    /// Create ingredient counter overlay - 36-48pt regular (42pt default)
    public func createIngredientCounterOverlay(text: String, index: Int, config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Validate safe zones (MANDATORY)
        validateSafeZones(config: config)
        
        let textLayer = createTextLayer(
            text: text,
            fontSize: config.countersFontSize,
            fontWeight: .regular,
            color: config.brandTint,
            maxWidth: config.size.width - (config.safeInsets.left + config.safeInsets.right),
            alignment: .left
        )
        
        let textSize = textLayer.preferredFrameSize()
        
        // Position staggered vertically
        let yPosition = config.safeInsets.top + 100 + (CGFloat(index) * 60)
        textLayer.frame = CGRect(
            x: config.safeInsets.left,
            y: yPosition,
            width: textSize.width,
            height: textSize.height
        )
        
        // Staggered appearance with delay
        let delay = Double(index) * config.staggerDelay
        
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0.0
        fadeAnimation.toValue = 1.0
        fadeAnimation.duration = config.fadeDuration
        fadeAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + delay
        fadeAnimation.fillMode = .backwards
        textLayer.add(fadeAnimation, forKey: "staggeredFade")
        
        containerLayer.addSublayer(textLayer)
        return containerLayer
    }
    
    /// 6. kineticStepOverlay - Slide up animation (already implemented)
    /// Create kinetic step overlay - 44-52pt bold (48pt default) with slide animation
    public func createKineticStepOverlay(text: String, index: Int, config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Validate safe zones (MANDATORY)
        validateSafeZones(config: config)
        
        let textLayer = createTextLayer(
            text: text,
            fontSize: config.stepsFontSize,
            fontWeight: .bold,
            color: config.brandTint,
            maxWidth: config.size.width - (config.safeInsets.left + config.safeInsets.right),
            alignment: .center
        )
        
        let textSize = textLayer.preferredFrameSize()
        
        // Position in center area
        textLayer.frame = CGRect(
            x: config.safeInsets.left,
            y: (config.size.height - textSize.height) / 2,
            width: config.size.width - (config.safeInsets.left + config.safeInsets.right),
            height: textSize.height
        )
        
        // Kinetic Steps animation - slide up with 0.35s group animation
        let slideAnimation = CABasicAnimation(keyPath: "transform.translation.y")
        slideAnimation.fromValue = 50
        slideAnimation.toValue = 0
        slideAnimation.duration = 0.35
        slideAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0.0
        fadeAnimation.toValue = 1.0
        fadeAnimation.duration = 0.35
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [slideAnimation, fadeAnimation]
        animationGroup.duration = 0.35
        animationGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        textLayer.add(animationGroup, forKey: "kineticSlide")
        
        containerLayer.addSublayer(textLayer)
        return containerLayer
    }
    
    /// 7. stickerStackOverlay - Pop with 120ms stagger
    public func createStickerStackOverlay(stickers: [(text: String, color: UIColor)], config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Validate safe zones
        validateSafeZones(config: config)
        
        for (index, stickerData) in stickers.enumerated() {
            let stickerLayer = createStickerOverlay(stickerData: stickerData, index: index, config: config)
            containerLayer.addSublayer(stickerLayer)
        }
        
        return containerLayer
    }
    
    /// Create sticker overlay with pop animation
    public func createStickerOverlay(stickerData: (text: String, color: UIColor), index: Int, config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Validate safe zones (MANDATORY)
        validateSafeZones(config: config)
        
        // Create sticker background
        let stickerLayer = CALayer()
        stickerLayer.backgroundColor = stickerData.color.withAlphaComponent(0.9).cgColor
        stickerLayer.cornerRadius = 20
        
        // Sticker text
        let textLayer = createTextLayer(
            text: stickerData.text,
            fontSize: 32,
            fontWeight: .bold,
            color: .white,
            maxWidth: 120,
            alignment: .center
        )
        
        let textSize = textLayer.preferredFrameSize()
        let stickerSize = CGSize(width: max(80, textSize.width + 20), height: max(40, textSize.height + 16))
        
        // Position stickers in stack formation
        let xPosition = config.safeInsets.left + 20 + (CGFloat(index) * 15)
        let yPosition = config.safeInsets.top + 50 + (CGFloat(index) * 10)
        
        stickerLayer.frame = CGRect(
            x: xPosition,
            y: yPosition,
            width: stickerSize.width,
            height: stickerSize.height
        )
        
        textLayer.frame = CGRect(
            x: (stickerSize.width - textSize.width) / 2,
            y: (stickerSize.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        // Sticker Stack animation - staggered pop with 120ms delay per item (exact spec)
        let delay = Double(index) * 0.12
        
        let scaleAnimation = CASpringAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.0
        scaleAnimation.toValue = 1.0
        scaleAnimation.duration = 0.5
        scaleAnimation.damping = config.springDamping
        scaleAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + delay
        scaleAnimation.fillMode = .backwards
        
        stickerLayer.add(scaleAnimation, forKey: "stickerPop")
        
        stickerLayer.addSublayer(textLayer)
        containerLayer.addSublayer(stickerLayer)
        return containerLayer
    }
    
    /// 8. progressOverlay - Gradient animation (already implemented as createProgressBarOverlay)
    /// Create progress bar overlay with gradient animation
    public func createProgressBarOverlay(recipe: ViralRecipe, config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Validate safe zones (MANDATORY)
        validateSafeZones(config: config)
        
        // Progress bar background
        let backgroundLayer = CALayer()
        backgroundLayer.backgroundColor = UIColor.black.withAlphaComponent(0.3).cgColor
        backgroundLayer.cornerRadius = 8
        
        let barWidth: CGFloat = config.size.width - (config.safeInsets.left + config.safeInsets.right)
        let barHeight: CGFloat = 16
        
        backgroundLayer.frame = CGRect(
            x: config.safeInsets.left,
            y: config.size.height - config.safeInsets.bottom - 100,
            width: barWidth,
            height: barHeight
        )
        
        // Gradient progress bar
        let progressLayer = CAGradientLayer()
        progressLayer.colors = [
            UIColor.systemBlue.cgColor,
            UIColor.systemPurple.cgColor
        ]
        progressLayer.startPoint = CGPoint(x: 0, y: 0.5)
        progressLayer.endPoint = CGPoint(x: 1, y: 0.5)
        progressLayer.cornerRadius = 8
        progressLayer.frame = CGRect(x: 0, y: 0, width: 0, height: barHeight)
        
        // Progress bar animation - linear animation matching duration
        let progressAnimation = CABasicAnimation(keyPath: "bounds.size.width")
        progressAnimation.fromValue = 0
        progressAnimation.toValue = barWidth
        progressAnimation.duration = 5.0 // 5 seconds as specified
        progressAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        
        progressLayer.add(progressAnimation, forKey: "progressFill")
        
        backgroundLayer.addSublayer(progressLayer)
        containerLayer.addSublayer(backgroundLayer)
        
        // Add time/cost labels if available
        if let time = recipe.timeMinutes {
            let timeLabel = createTextLayer(
                text: "\(time) MIN",
                fontSize: 20,
                fontWeight: .bold,
                color: config.brandTint,
                maxWidth: 100,
                alignment: .center
            )
            
            timeLabel.frame = CGRect(
                x: config.safeInsets.left,
                y: backgroundLayer.frame.minY - 30,
                width: 100,
                height: 25
            )
            
            containerLayer.addSublayer(timeLabel)
        }
        
        if let cost = recipe.costDollars {
            let costLabel = createTextLayer(
                text: "$\(cost)",
                fontSize: 20,
                fontWeight: .bold,
                color: config.brandTint,
                maxWidth: 100,
                alignment: .center
            )
            
            costLabel.frame = CGRect(
                x: config.size.width - config.safeInsets.right - 100,
                y: backgroundLayer.frame.minY - 30,
                width: 100,
                height: 25
            )
            
            containerLayer.addSublayer(costLabel)
        }
        
        return containerLayer
    }
    
    /// 9. pipFaceOverlay - 340x340 circle placeholder (already implemented)
    /// Create PIP face overlay - 340x340 circle, top-right with shadow
    public func createPIPFaceOverlay(config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Validate safe zones (MANDATORY)
        validateSafeZones(config: config)
        
        // PIP circle - placeholder for future selfie integration
        let pipLayer = CAShapeLayer()
        pipLayer.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 340, height: 340)).cgPath
        pipLayer.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
        pipLayer.strokeColor = config.brandTint.cgColor
        pipLayer.lineWidth = 4
        
        // Position top-right with shadow as specified
        pipLayer.frame = CGRect(
            x: config.size.width - 340 - config.safeInsets.right - 20,
            y: config.safeInsets.top + 20,
            width: 340,
            height: 340
        )
        
        // Add shadow
        pipLayer.shadowColor = config.brandShadow.cgColor
        pipLayer.shadowOffset = CGSize(width: 0, height: 8)
        pipLayer.shadowOpacity = 0.3
        pipLayer.shadowRadius = 12
        
        // Add placeholder icon
        let iconLayer = CATextLayer()
        iconLayer.string = "👤"
        iconLayer.fontSize = 120
        iconLayer.alignmentMode = .center
        iconLayer.frame = CGRect(x: 110, y: 110, width: 120, height: 120)
        
        pipLayer.addSublayer(iconLayer)
        containerLayer.addSublayer(pipLayer)
        return containerLayer
    }
    
    /// 10. calloutsOverlay - Angled ingredient tags
    public func createCalloutsOverlay(ingredients: [String], config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Validate safe zones
        validateSafeZones(config: config)
        
        let processedIngredients = CaptionGenerator.processIngredientText(ingredients)
        
        for (index, ingredient) in processedIngredients.enumerated() {
            let calloutLayer = createAngledCallout(text: ingredient, index: index, config: config)
            containerLayer.addSublayer(calloutLayer)
        }
        
        return containerLayer
    }
    
    /// Create ingredient callout overlay - 42pt bold with drop animation
    public func createIngredientCalloutOverlay(text: String, index: Int, config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Validate safe zones (MANDATORY)
        validateSafeZones(config: config)
        
        // Create callout bubble
        let bubbleLayer = CALayer()
        bubbleLayer.backgroundColor = UIColor.black.withAlphaComponent(0.8).cgColor
        bubbleLayer.cornerRadius = 15
        
        let textLayer = createTextLayer(
            text: text,
            fontSize: config.ingredientFontSize,
            fontWeight: .bold,
            color: config.brandTint,
            maxWidth: 200,
            alignment: .center
        )
        
        let textSize = textLayer.preferredFrameSize()
        let bubbleSize = CGSize(width: textSize.width + 24, height: textSize.height + 16)
        
        // Position callouts on left side, staggered
        let xPosition = config.safeInsets.left + 20
        let yPosition = 300 + (CGFloat(index) * 80)
        
        bubbleLayer.frame = CGRect(
            x: xPosition,
            y: yPosition,
            width: bubbleSize.width,
            height: bubbleSize.height
        )
        
        textLayer.frame = CGRect(
            x: 12,
            y: 8,
            width: textSize.width,
            height: textSize.height
        )
        
        // Ingredient Callout animation - drop animation 0.5s with Y+50 offset
        let dropAnimation = CABasicAnimation(keyPath: "transform.translation.y")
        dropAnimation.fromValue = -50
        dropAnimation.toValue = 0
        dropAnimation.duration = 0.5
        dropAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0.0
        fadeAnimation.toValue = 1.0
        fadeAnimation.duration = 0.5
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [dropAnimation, fadeAnimation]
        animationGroup.duration = 0.5
        
        bubbleLayer.add(animationGroup, forKey: "ingredientDrop")
        
        bubbleLayer.addSublayer(textLayer)
        containerLayer.addSublayer(bubbleLayer)
        return containerLayer
    }
    
    // MARK: - Private Helper Methods
    
    /// Create ingredient chip for counters overlay
    private func createIngredientChip(text: String, index: Int, config: RenderConfig) -> CALayer {
        let chipLayer = CALayer()
        chipLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
        chipLayer.cornerRadius = 20
        
        let textLayer = createTextLayer(
            text: text,
            fontSize: config.countersFontSize,
            fontWeight: .regular,
            color: config.brandTint,
            maxWidth: 200,
            alignment: .center
        )
        
        let textSize = textLayer.preferredFrameSize()
        let chipSize = CGSize(width: textSize.width + 24, height: textSize.height + 16)
        
        // Position chips in staggered formation within safe zones
        let xPosition = config.safeInsets.left + 20 + (CGFloat(index) * 10)
        let yPosition = config.safeInsets.top + 200 + (CGFloat(index) * 60)
        
        chipLayer.frame = CGRect(
            x: xPosition,
            y: yPosition,
            width: chipSize.width,
            height: chipSize.height
        )
        
        textLayer.frame = CGRect(
            x: 12,
            y: 8,
            width: textSize.width,
            height: textSize.height
        )
        
        // Staggered appearance animation (120-150ms between items)
        let delay = Double(index) * config.staggerDelay
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.6
        scaleAnimation.toValue = 1.0
        scaleAnimation.duration = config.fadeDuration
        scaleAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + delay
        scaleAnimation.fillMode = .backwards
        
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0.0
        fadeAnimation.toValue = 1.0
        fadeAnimation.duration = config.fadeDuration
        fadeAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + delay
        fadeAnimation.fillMode = .backwards
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, fadeAnimation]
        animationGroup.duration = config.fadeDuration
        animationGroup.beginTime = AVCoreAnimationBeginTimeAtZero + delay
        animationGroup.fillMode = .backwards
        
        chipLayer.add(animationGroup, forKey: "chipAppear")
        
        chipLayer.addSublayer(textLayer)
        return chipLayer
    }
    
    /// Create angled callout for ingredients
    private func createAngledCallout(text: String, index: Int, config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        
        // Create angled background
        let backgroundLayer = CAShapeLayer()
        let path = UIBezierPath()
        
        // Create angled tag shape
        let width: CGFloat = 180
        let height: CGFloat = 50
        let angle: CGFloat = 10 // Degrees
        
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: width - 20, y: height))
        path.addLine(to: CGPoint(x: width, y: height / 2))
        path.addLine(to: CGPoint(x: width - 20, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.close()
        
        backgroundLayer.path = path.cgPath
        backgroundLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.8).cgColor
        
        // Position angled callouts on right side, staggered
        let xPosition = config.size.width - config.safeInsets.right - width - 20
        let yPosition = config.safeInsets.top + 150 + (CGFloat(index) * 70)
        
        backgroundLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        
        // Rotate the callout for angled effect
        let rotationAngle = (CGFloat(index % 2 == 0 ? 1 : -1) * angle) * .pi / 180
        backgroundLayer.transform = CATransform3DMakeRotation(rotationAngle, 0, 0, 1)
        
        // Text layer
        let textLayer = createTextLayer(
            text: text,
            fontSize: config.ingredientFontSize,
            fontWeight: .bold,
            color: .white,
            maxWidth: width - 30,
            alignment: .left
        )
        
        let textSize = textLayer.preferredFrameSize()
        textLayer.frame = CGRect(
            x: 15,
            y: (height - textSize.height) / 2,
            width: min(textSize.width, width - 30),
            height: textSize.height
        )
        
        // Container positioning
        containerLayer.frame = CGRect(
            x: xPosition,
            y: yPosition,
            width: width,
            height: height
        )
        
        // Drop animation with Y offset
        let dropAnimation = CABasicAnimation(keyPath: "transform.translation.y")
        dropAnimation.fromValue = -50
        dropAnimation.toValue = 0
        dropAnimation.duration = 0.5
        dropAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0.0
        fadeAnimation.toValue = 1.0
        fadeAnimation.duration = 0.5
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [dropAnimation, fadeAnimation]
        animationGroup.duration = 0.5
        animationGroup.beginTime = AVCoreAnimationBeginTimeAtZero + Double(index) * 0.2
        animationGroup.fillMode = .backwards
        
        containerLayer.add(animationGroup, forKey: "angledCalloutDrop")
        
        backgroundLayer.addSublayer(textLayer)
        containerLayer.addSublayer(backgroundLayer)
        return containerLayer
    }
    
    /// Validate safe zones (MANDATORY)
    private func validateSafeZones(config: RenderConfig) {
        assert(config.safeInsets.top >= 192, "Top safe zone must be at least 192px (10% of 1920px)")
        assert(config.safeInsets.bottom >= 192, "Bottom safe zone must be at least 192px (10% of 1920px)")
        assert(config.safeInsets.left >= 72, "Left safe zone must be at least 72px")
        assert(config.safeInsets.right >= 72, "Right safe zone must be at least 72px")
    }
    
    // MARK: - Text Layer Creation
    
    private func createTextLayer(
        text: String,
        fontSize: CGFloat,
        fontWeight: UIFont.Weight,
        color: UIColor,
        maxWidth: CGFloat,
        alignment: CATextLayerAlignmentMode,
        strokeEnabled: Bool = false
    ) -> CATextLayer {
        
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.fontSize = fontSize
        textLayer.alignmentMode = alignment
        textLayer.isWrapped = true
        textLayer.truncationMode = .end
        
        // Font setup with fallback as specified in requirements
        if let font = UIFont(name: config.fontNameBold, size: fontSize) {
            textLayer.font = font
        } else {
            // Fallback to system font if SF-Pro-Display unavailable
            textLayer.font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        }
        
        textLayer.foregroundColor = color.cgColor
        
        // Text stroke as specified: 4px shadow as fake stroke
        if config.textStrokeEnabled || strokeEnabled {
            textLayer.shadowColor = config.brandShadow.cgColor
            textLayer.shadowOffset = CGSize(width: 0, height: 0)
            textLayer.shadowOpacity = 1.0
            textLayer.shadowRadius = 4
            
            // Additional stroke effect for hero overlays
            if strokeEnabled {
                textLayer.borderWidth = 2
                textLayer.borderColor = config.brandShadow.cgColor
            }
        }
        
        // Calculate frame size respecting max width and line limits
        let maxSize = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        let textSize = text.boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: textLayer.font as Any],
            context: nil
        ).size
        
        textLayer.bounds = CGRect(origin: .zero, size: textSize)
        
        return textLayer
    }
    
    private func createVideoCompositionWithOverlays(
        asset: AVAsset,
        overlays: [RenderPlan.Overlay]
    ) async throws -> AVVideoComposition {
        let composition = AVMutableVideoComposition()
        composition.renderSize = config.size
        composition.frameDuration = CMTime(value: 1, timescale: config.fps)
        
        // Create animation layer with all overlays
        let animationLayer = CALayer()
        animationLayer.frame = CGRect(origin: .zero, size: config.size)
        animationLayer.masksToBounds = true
        animationLayer.beginTime = AVCoreAnimationBeginTimeAtZero  // Critical: Set animation layer begin time
        
        for overlay in overlays {
            let layer = overlay.layerBuilder(config)
            layer.beginTime = AVCoreAnimationBeginTimeAtZero + overlay.start.seconds  // Set correct timing
            
            // Set initial opacity for fade animations
            layer.opacity = 0
            
            // Fade in at start time
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.beginTime = AVCoreAnimationBeginTimeAtZero + overlay.start.seconds
            fadeIn.duration = 0.2
            fadeIn.fillMode = .forwards
            fadeIn.isRemovedOnCompletion = false
            layer.add(fadeIn, forKey: "fadeIn")
            
            // Fade out at end time
            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1
            fadeOut.toValue = 0
            fadeOut.beginTime = AVCoreAnimationBeginTimeAtZero + overlay.start.seconds + overlay.duration.seconds - 0.2
            fadeOut.duration = 0.2
            fadeOut.fillMode = .forwards
            fadeOut.isRemovedOnCompletion = false
            layer.add(fadeOut, forKey: "fadeOut")
            
            animationLayer.addSublayer(layer)
        }
        
        // Use CoreAnimationTool for rendering animations
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: config.size)
        videoLayer.frame = CGRect(origin: .zero, size: config.size)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(animationLayer)
        
        composition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
        
        // Instruction for passthrough with overlays
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))
        if let videoTrack = try await asset.loadTracks(withMediaType: .video).first {
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            instruction.layerInstructions = [layerInstruction]
        }
        composition.instructions = [instruction]
        
        return composition
    }
    
    private func createTempOutputURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "overlay_video_\(Date().timeIntervalSince1970).mp4"
        return tempDir.appendingPathComponent(filename)
    }
    
    // MARK: - Layer Caching for Performance Optimization
    
    /// Get cached layer if available
    private func getCachedLayer(key: String) -> CALayer? {
        return cacheQueue.sync {
            return layerCache[key]?.copy() as? CALayer
        }
    }
    
    /// Cache a layer for future reuse
    private func cacheLayer(key: String, layer: CALayer) {
        cacheQueue.async(flags: .barrier) {
            // Enforce cache size limit
            if self.layerCache.count >= self.maxCacheSize {
                // Remove oldest entries (simple FIFO)
                let keysToRemove = Array(self.layerCache.keys.prefix(5))
                keysToRemove.forEach { self.layerCache.removeValue(forKey: $0) }
            }
            
            // Cache the layer
            self.layerCache[key] = layer.copy() as? CALayer
        }
    }
    
    /// Clear layer cache to free memory
    public func clearLayerCache() {
        cacheQueue.async(flags: .barrier) {
            self.layerCache.removeAll()
        }
    }
    
    /// Get cache statistics for monitoring
    public func getCacheStats() -> (count: Int, memoryEstimate: Double) {
        return cacheQueue.sync {
            let count = layerCache.count
            // Rough estimate: each cached layer ~50KB
            let memoryEstimate = Double(count) * 50 * 1024
            return (count: count, memoryEstimate: memoryEstimate)
        }
    }
    
    /// Pre-warm cache with common overlays
    public func preWarmCache(for recipe: ViralRecipe, config: RenderConfig) {
        // Pre-cache common text overlays
        let hook = CaptionGenerator.generateHook(from: recipe)
        let cta = CaptionGenerator.randomCTA()
        
        Task {
            // Create layers in background to warm cache
            _ = self.createHookOverlay(text: hook, config: config)
            _ = self.createCTAOverlay(text: cta, config: config)
            
            // Pre-cache ingredient overlays
            let processedIngredients = CaptionGenerator.processIngredientText(recipe.ingredients)
            for (index, ingredient) in processedIngredients.enumerated() {
                _ = self.createIngredientCounterOverlay(text: ingredient, index: index, config: config)
            }
        }
    }
}

// MARK: - Error Types

public enum OverlayError: LocalizedError {
    case cannotCreateExportSession
    case cannotLoadVideoTrack
    case exportFailed
    case exportCancelled
    
    public var errorDescription: String? {
        switch self {
        case .cannotCreateExportSession:
            return "Cannot create export session for overlays"
        case .cannotLoadVideoTrack:
            return "Cannot load video track for overlay composition"
        case .exportFailed:
            return "Overlay export failed"
        case .exportCancelled:
            return "Overlay export was cancelled"
        }
    }
}

// MARK: - Premium Kinetic Text Animations

extension OverlayFactory {
    
    /// Create premium hook overlay with golden glow and bounce animation (0-3s)
    public func createPremiumHookOverlay(text: String, config: RenderConfig, fontSize: CGFloat = 72) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Create attributed string for better formatting
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0), // Golden
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // Text layer with golden tint
        let textLayer = CATextLayer()
        textLayer.string = attributedString
        textLayer.fontSize = fontSize
        textLayer.font = UIFont.boldSystemFont(ofSize: fontSize)
        textLayer.foregroundColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0).cgColor // Golden color
        textLayer.alignmentMode = .center
        textLayer.isWrapped = true
        textLayer.contentsScale = 2.0 // Use fixed scale instead of UIScreen
        textLayer.truncationMode = .end
        
        // Better positioning - center properly
        let safeAreaPadding: CGFloat = 80
        let textHeight: CGFloat = 300 // More height for wrapping
        textLayer.frame = CGRect(
            x: safeAreaPadding,
            y: (config.size.height - textHeight) / 2,
            width: config.size.width - (safeAreaPadding * 2),
            height: textHeight
        )
        
        // Add glow shadow
        textLayer.shadowColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0).cgColor
        textLayer.shadowRadius = 20
        textLayer.shadowOpacity = 0
        textLayer.shadowOffset = CGSize.zero
        
        // Use AVCoreAnimationBeginTimeAtZero for proper video composition timing
        let startTime = AVCoreAnimationBeginTimeAtZero
        
        // Initial state
        textLayer.opacity = 0
        textLayer.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        
        // Fade in with scale bounce animation (0.95 → 1.05 → 1.0)
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnimation.values = [0.95, 1.05, 1.0]
        scaleAnimation.keyTimes = [0, 0.6, 1.0]
        scaleAnimation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        scaleAnimation.beginTime = startTime
        scaleAnimation.duration = 1.5
        scaleAnimation.fillMode = .forwards
        scaleAnimation.isRemovedOnCompletion = false
        
        // Glow animation
        let glowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        glowAnimation.fromValue = 0.0
        glowAnimation.toValue = 0.8
        glowAnimation.beginTime = startTime
        glowAnimation.duration = 1.5
        glowAnimation.fillMode = .forwards
        glowAnimation.isRemovedOnCompletion = false
        
        // Fade in
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0.0
        fadeAnimation.toValue = 1.0
        fadeAnimation.beginTime = startTime
        fadeAnimation.duration = 0.5
        fadeAnimation.fillMode = .forwards
        fadeAnimation.isRemovedOnCompletion = false
        
        // Fade out at 2.8s (before 3s end)
        let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
        fadeOutAnimation.fromValue = 1.0
        fadeOutAnimation.toValue = 0.0
        fadeOutAnimation.beginTime = startTime + 2.8
        fadeOutAnimation.duration = 0.2
        fadeOutAnimation.fillMode = .forwards
        fadeOutAnimation.isRemovedOnCompletion = false
        
        // Add animations
        textLayer.add(scaleAnimation, forKey: "hookBounce")
        textLayer.add(glowAnimation, forKey: "hookGlow")
        textLayer.add(fadeAnimation, forKey: "hookFade")
        textLayer.add(fadeOutAnimation, forKey: "hookFadeOut")
        
        containerLayer.addSublayer(textLayer)
        return containerLayer
    }
    
    /// Create carousel item with beat-synced pop animation (3-10s)
    // Update createCarouselItemOverlay for beat pop + scrolling
    public func createCarouselItemOverlay(text: String, index: Int, config: RenderConfig, fontSize: CGFloat = 52) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(x: config.size.width, y: config.size.height / 2 - 100, width: config.size.width - 200, height: 200)  // Start right edge, wider for wrapping
        
        let textLayer = CATextLayer()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping  // Fix wrapping
        let attributedString = NSAttributedString(string: text, attributes: [
            .font: UIFont(name: config.fontNameBold, size: fontSize) ?? UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ])
        textLayer.string = attributedString
        textLayer.frame = layer.bounds.insetBy(dx: 20, dy: 20)  // Padding
        textLayer.contentsScale = 2.0  // Use fixed scale instead of UIScreen.main
        textLayer.isWrapped = true  // Enable multiline
        textLayer.alignmentMode = .center
        textLayer.truncationMode = .end  // If still long
        
        // Add white glow for premium effect
        textLayer.shadowColor = UIColor.white.cgColor
        textLayer.shadowOpacity = 1.0
        textLayer.shadowRadius = 10
        textLayer.shadowOffset = .zero
        
        layer.addSublayer(textLayer)
        
        // Scrolling animation (full screen left)
        let scrollAnimation = CABasicAnimation(keyPath: "position.x")
        scrollAnimation.fromValue = config.size.width
        scrollAnimation.toValue = -layer.frame.width
        scrollAnimation.duration = 0.75  // Per beat
        scrollAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        scrollAnimation.beginTime = AVCoreAnimationBeginTimeAtZero
        layer.add(scrollAnimation, forKey: "scroll")
        
        // Pop animation with bigger effect
        let popAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        popAnimation.values = [0.8, 1.2, 1.0]  // Bigger pop for awesome
        popAnimation.keyTimes = [0, 0.5, 1.0]
        popAnimation.duration = 0.75
        popAnimation.beginTime = AVCoreAnimationBeginTimeAtZero
        layer.add(popAnimation, forKey: "pop")
        
        // Add glow animation
        let glowAnim = CABasicAnimation(keyPath: "shadowOpacity")
        glowAnim.fromValue = 0.0
        glowAnim.toValue = 1.0
        glowAnim.duration = 0.75
        glowAnim.beginTime = AVCoreAnimationBeginTimeAtZero
        textLayer.add(glowAnim, forKey: "glow")
        
        return layer
    }
    
    // Original version for compatibility (can be called from other places)
    public func createCarouselItemOverlay_OLD(text: String, index: Int, config: RenderConfig, fontSize: CGFloat = 52) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Create attributed string for better text formatting
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 1.0), // Orange brand
            .strokeWidth: -3.0, // Negative for stroke + fill
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // Text layer
        let textLayer = CATextLayer()
        textLayer.string = attributedString
        textLayer.fontSize = fontSize
        textLayer.alignmentMode = .center
        textLayer.isWrapped = true
        textLayer.contentsScale = 2.0
        
        // Center position initially
        let textWidth: CGFloat = 600
        let textHeight: CGFloat = 150
        textLayer.frame = CGRect(
            x: (config.size.width - textWidth) / 2,
            y: (config.size.height - textHeight) / 2,
            width: textWidth,
            height: textHeight
        )
        
        // Beat-synced animations with proper AVFoundation timing
        let beatTime = 0.75 // Each beat is 0.75 seconds
        let itemStartTime = AVCoreAnimationBeginTimeAtZero + 3.0 + (Double(index) * beatTime)
        
        // Initial state: invisible and scaled down
        textLayer.opacity = 0
        textLayer.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
        
        // Pop in animation synced to beat
        let popIn = CAKeyframeAnimation(keyPath: "transform.scale")
        popIn.values = [0.8, 1.1, 1.0]
        popIn.keyTimes = [0, 0.3, 1.0]
        popIn.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        popIn.beginTime = itemStartTime
        popIn.duration = beatTime * 0.5 // Half a beat for the pop
        popIn.fillMode = .forwards
        popIn.isRemovedOnCompletion = false
        
        // Fade in
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.beginTime = itemStartTime
        fadeIn.duration = 0.2
        fadeIn.fillMode = .forwards
        fadeIn.isRemovedOnCompletion = false
        
        // Fade out before next item
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1
        fadeOut.toValue = 0
        fadeOut.beginTime = itemStartTime + beatTime - 0.1
        fadeOut.duration = 0.1
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false
        
        // Add glow effect on beat
        let glowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        glowAnimation.fromValue = 0
        glowAnimation.toValue = 0.8
        glowAnimation.beginTime = itemStartTime
        glowAnimation.duration = beatTime * 0.5
        glowAnimation.autoreverses = true
        glowAnimation.fillMode = .forwards
        glowAnimation.isRemovedOnCompletion = false
        
        textLayer.shadowColor = UIColor.white.cgColor
        textLayer.shadowRadius = 20
        textLayer.shadowOpacity = 0
        
        // Add scrolling animation for carousel effect
        let scroll = CABasicAnimation(keyPath: "position.x")
        scroll.fromValue = config.size.width + textWidth/2  // Start from right edge
        scroll.toValue = -textWidth/2  // End at left edge
        scroll.duration = 7.0  // Full carousel duration (3-10s)
        scroll.beginTime = AVCoreAnimationBeginTimeAtZero + 3.0  // Start at 3s
        scroll.fillMode = .forwards
        scroll.isRemovedOnCompletion = false
        
        // Add all animations
        textLayer.add(scroll, forKey: "scrollLeft")
        textLayer.add(popIn, forKey: "popIn")
        textLayer.add(fadeIn, forKey: "fadeIn")
        textLayer.add(fadeOut, forKey: "fadeOut")
        textLayer.add(glowAnimation, forKey: "glow")
        
        containerLayer.addSublayer(textLayer)
        return containerLayer
    }
    
    /// Create cinematic reveal overlay with sparkle particles (10-13s)
    public func createCinematicRevealOverlay(text: String, config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Main text layer
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.fontSize = 64
        textLayer.font = UIFont.boldSystemFont(ofSize: 64)
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.isWrapped = true
        textLayer.contentsScale = 2.0 // Use fixed scale instead of UIScreen
        textLayer.frame = CGRect(
            x: 50,
            y: config.size.height/2 - 60,
            width: config.size.width - 100,
            height: 120
        )
        
        // Add dramatic shadow
        textLayer.shadowColor = UIColor.black.cgColor
        textLayer.shadowRadius = 15
        textLayer.shadowOpacity = 0.8
        textLayer.shadowOffset = CGSize(width: 0, height: 5)
        
        // Zoom in animation
        let zoomAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        zoomAnimation.values = [0.3, 1.2, 1.0]
        zoomAnimation.keyTimes = [0, 0.7, 1.0]
        zoomAnimation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        zoomAnimation.duration = 1.5
        zoomAnimation.fillMode = .forwards
        zoomAnimation.isRemovedOnCompletion = false
        
        // Fade in
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0.0
        fadeAnimation.toValue = 1.0
        fadeAnimation.duration = 0.5
        fadeAnimation.fillMode = .forwards
        fadeAnimation.isRemovedOnCompletion = false
        
        // Create sparkle particles
        for _ in 0..<15 {
            let sparkle = createSparkleLayer(in: containerLayer.bounds)
            containerLayer.addSublayer(sparkle)
        }
        
        textLayer.add(zoomAnimation, forKey: "cinematicZoom")
        textLayer.add(fadeAnimation, forKey: "cinematicFade")
        
        containerLayer.addSublayer(textLayer)
        return containerLayer
    }
    
    /// Create premium CTA overlay with pulse animation (13-15s)
    public func createPremiumCTAOverlay(text: String, config: RenderConfig, fontSize: CGFloat = 44) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Translucent rounded sticker background - position at bottom with safe area
        let stickerLayer = CALayer()
        let stickerWidth: CGFloat = 300  // Fixed width for hashtags
        let stickerHeight: CGFloat = 100  // Smaller height, larger font
        stickerLayer.frame = CGRect(
            x: config.size.width / 2 - 150,  // Centered
            y: config.size.height - 250,  // Lower to avoid clip
            width: stickerWidth,
            height: stickerHeight
        )
        stickerLayer.backgroundColor = UIColor.black.withAlphaComponent(0.8).cgColor
        stickerLayer.cornerRadius = 25
        stickerLayer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        stickerLayer.borderWidth = 2
        
        // Add sparkle particles to sticker
        for _ in 0..<8 {
            let sparkle = createSparkleLayer(in: stickerLayer.bounds)
            stickerLayer.addSublayer(sparkle)
        }
        
        // Text layer with attributed string for better hashtag formatting
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        let textLayer = CATextLayer()
        textLayer.string = attributedString
        textLayer.fontSize = fontSize
        textLayer.font = UIFont.boldSystemFont(ofSize: fontSize)
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.isWrapped = true
        textLayer.contentsScale = 2.0 // Use fixed scale instead of UIScreen
        textLayer.frame = CGRect(
            x: 20,
            y: 20,
            width: stickerWidth - 40,
            height: stickerHeight - 40
        )
        
        // Set initial opacity
        stickerLayer.opacity = 0
        
        // Timing for CTA (starts at 13s)
        let ctaStartTime = AVCoreAnimationBeginTimeAtZero + 13.0
        
        // Fade in
        let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
        fadeInAnimation.fromValue = 0.0
        fadeInAnimation.toValue = 1.0
        fadeInAnimation.beginTime = ctaStartTime
        fadeInAnimation.duration = 0.3
        fadeInAnimation.fillMode = .forwards
        fadeInAnimation.isRemovedOnCompletion = false
        
        // Pulse animation (1.0 → 1.1 → 1.0)
        let pulseAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        pulseAnimation.values = [1.0, 1.1, 1.0]
        pulseAnimation.keyTimes = [0, 0.5, 1.0]
        pulseAnimation.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        pulseAnimation.beginTime = ctaStartTime + 0.3
        pulseAnimation.duration = 1.0
        pulseAnimation.repeatCount = 2 // Pulse twice during the 2 seconds
        pulseAnimation.fillMode = .forwards
        pulseAnimation.isRemovedOnCompletion = false
        
        stickerLayer.add(pulseAnimation, forKey: "ctaPulse")
        stickerLayer.add(fadeInAnimation, forKey: "ctaFade")
        
        stickerLayer.addSublayer(textLayer)
        containerLayer.addSublayer(stickerLayer)
        
        return containerLayer
    }
    
    /// Helper function to create sparkle emitter layer with keyframed birthRate
    // Update createPremiumCTAOverlay for keyframed sparkles
    private func createSparkleLayer(in bounds: CGRect) -> CALayer {
        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        emitter.emitterSize = CGSize(width: bounds.width * 0.8, height: bounds.height * 0.8)
        emitter.emitterShape = .rectangle
        emitter.renderMode = .additive
        
        // Create sparkle cell
        let sparkleCell = CAEmitterCell()
        sparkleCell.name = "sparkle"
        sparkleCell.birthRate = 5.0  // Base rate for visibility
        sparkleCell.lifetime = 2.0
        sparkleCell.lifetimeRange = 0.5
        sparkleCell.velocity = 50
        sparkleCell.velocityRange = 20
        sparkleCell.emissionRange = .pi  // Narrower for focused bursts
        sparkleCell.scale = 0.8  // Larger for premium effect
        sparkleCell.scaleRange = 0.3
        sparkleCell.scaleSpeed = -0.3
        sparkleCell.alphaRange = 0.8
        sparkleCell.alphaSpeed = -0.5
        sparkleCell.color = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0).cgColor  // Premium gold sparkles
        
        // Sparkle image (white circle)
        let sparkleImage = UIImage.circle(diameter: 8, color: .white)
        sparkleCell.contents = sparkleImage?.cgImage
        
        emitter.emitterCells = [sparkleCell]
        
        // Keyframe birthRate for dynamic sparkles over time
        let birthAnimation = CAKeyframeAnimation(keyPath: "emitterCells.sparkle.birthRate")
        birthAnimation.values = [0, 50, 20, 50, 0]  // Stronger bursts for awesome
        birthAnimation.keyTimes = [0, 0.2, 0.5, 0.8, 1.0]
        birthAnimation.duration = 3.0  // CTA duration
        birthAnimation.repeatCount = 1
        birthAnimation.beginTime = AVCoreAnimationBeginTimeAtZero
        birthAnimation.fillMode = .forwards
        birthAnimation.isRemovedOnCompletion = false
        
        emitter.add(birthAnimation, forKey: "sparkleBirth")
        
        // Add position animation for moving sparkles
        let posAnim = CAKeyframeAnimation(keyPath: "position")
        posAnim.values = [
            CGPoint(x: bounds.midX, y: bounds.midY),
            CGPoint(x: bounds.midX + 100, y: bounds.midY - 100),
            CGPoint(x: bounds.midX - 100, y: bounds.midY + 100),
            CGPoint(x: bounds.midX, y: bounds.midY)
        ]
        posAnim.keyTimes = [0, 0.33, 0.66, 1.0]
        posAnim.duration = 3.0
        posAnim.beginTime = AVCoreAnimationBeginTimeAtZero
        emitter.add(posAnim, forKey: "move")
        
        return emitter
    }
}

// MARK: - UIImage Extension for Sparkle Generation

extension UIImage {
    /// Create a circular image with the specified diameter and color
    static func circle(diameter: CGFloat, color: UIColor) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { context in
            color.setFill()
            let rect = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
            context.cgContext.fillEllipse(in: rect)
        }
    }
}