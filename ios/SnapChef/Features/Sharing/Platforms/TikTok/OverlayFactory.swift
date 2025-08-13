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
public final class OverlayFactory: @unchecked Sendable {
    
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
        fadeAnimation.beginTime = CACurrentMediaTime() + delay
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
        scaleAnimation.beginTime = CACurrentMediaTime() + delay
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
        scaleAnimation.beginTime = CACurrentMediaTime() + delay
        scaleAnimation.fillMode = .backwards
        
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0.0
        fadeAnimation.toValue = 1.0
        fadeAnimation.duration = config.fadeDuration
        fadeAnimation.beginTime = CACurrentMediaTime() + delay
        fadeAnimation.fillMode = .backwards
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, fadeAnimation]
        animationGroup.duration = config.fadeDuration
        animationGroup.beginTime = CACurrentMediaTime() + delay
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
        animationGroup.beginTime = CACurrentMediaTime() + Double(index) * 0.2
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
        
        // Get video tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw OverlayError.cannotLoadVideoTrack
        }
        
        let duration = try await asset.load(.duration)
        
        // Create instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        
        // Create layer instruction
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]
        
        // Add animation layer for overlays
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: config.size)
        
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: config.size)
        
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Add all overlay layers
        for overlay in overlays {
            let layer = overlay.layerBuilder(config)
            
            // Set time range for overlay
            layer.beginTime = overlay.start.seconds
            layer.duration = overlay.duration.seconds
            
            overlayLayer.addSublayer(layer)
        }
        
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)
        
        composition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
        
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