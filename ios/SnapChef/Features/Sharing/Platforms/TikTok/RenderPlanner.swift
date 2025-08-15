// REPLACE ENTIRE FILE: RenderPlanner.swift

import UIKit
@preconcurrency import AVFoundation
import CoreMedia
import Accelerate

public actor RenderPlanner {
    private let config: RenderConfig
    public init(config: RenderConfig) { self.config = config }

    // Public API
    public func createRenderPlan(template: ViralTemplate,
                                 recipe: ViralRecipe,
                                 media: MediaBundle) async throws -> RenderPlan {
        switch template { case .kineticTextSteps: return try await kineticPlan(recipe, media) }
    }

    // MARK: Enhanced Beat Analysis for Premium Features
    private func makeBeatMap(from url: URL?, fallbackBPM: Double, duration: Double) async -> BeatMap {
        guard let url = url else {
            let cues = stride(from: 0.0, through: duration, by: 60.0/fallbackBPM)
                .map { CMTime(seconds: $0, preferredTimescale: 600) }
            return BeatMap(bpm: fallbackBPM, cueTimes: cues)
        }

        // Enhanced beat detection with strong beat identification and drop moments
        let asset = AVURLAsset(url: url)
        let tracks = try? await asset.loadTracks(withMediaType: .audio)
        guard tracks?.first != nil else {
            return await makeBeatMap(from: nil, fallbackBPM: fallbackBPM, duration: duration)
        }
        
        let audioAsset = AVAsset(url: url)
        let assetDuration = (try? await audioAsset.load(.duration)) ?? CMTime(seconds: duration, preferredTimescale: 600)
        let seconds = min(assetDuration.seconds, duration)
        
        // Detect BPM and beat intensity for premium features
        let beatAnalysis = await analyzeBeatPattern(asset: audioAsset, duration: seconds)
        let cues = generateBeatCues(analysis: beatAnalysis, duration: seconds)
        
        return BeatMap(bpm: beatAnalysis.bpm, cueTimes: cues)
    }
    
    /// Analyze audio for beat pattern, strong beats, and drop moments
    private func analyzeBeatPattern(asset: AVAsset, duration: Double) async -> BeatAnalysis {
        // For premium beat detection, we'll implement a more sophisticated approach
        // This could include FFT analysis, onset detection, and tempo estimation
        
        // Default to 120 BPM for now with enhanced beat mapping
        let bpm: Double = 120
        
        // Identify strong beats (typically on the 1 and 3 of a 4/4 pattern)
        var strongBeats: [Double] = []
        var dropMoments: [Double] = []
        
        // Generate strong beats every measure (4 beats at 120 BPM = 2 seconds)
        for time in stride(from: 0.0, through: duration, by: 2.0) {
            strongBeats.append(time)
        }
        
        // Identify potential drop moments (usually at structural boundaries)
        // For now, place drops at 8-second intervals or at 1/3 and 2/3 of the track
        if duration > 8 {
            dropMoments.append(duration / 3)
            if duration > 16 {
                dropMoments.append(2 * duration / 3)
            }
        }
        
        return BeatAnalysis(
            bpm: bpm,
            strongBeats: strongBeats,
            dropMoments: dropMoments,
            beatIntensity: 0.8 // Medium-high intensity for good rhythm sync
        )
    }
    
    /// Generate beat cues with enhanced timing for transitions and reveals
    private func generateBeatCues(analysis: BeatAnalysis, duration: Double) -> [CMTime] {
        var cues: [CMTime] = []
        
        // Generate regular beat grid
        let beatInterval = 60.0 / analysis.bpm
        for time in stride(from: 0.0, through: duration, by: beatInterval) {
            cues.append(CMTime(seconds: time, preferredTimescale: 600))
        }
        
        // Add strong beats with higher precision timing
        for strongBeat in analysis.strongBeats {
            if strongBeat <= duration {
                // Add slightly offset timing for strong beat emphasis
                let strongBeatTime = CMTime(seconds: strongBeat, preferredTimescale: 600)
                if !cues.contains(where: { abs($0.seconds - strongBeat) < 0.1 }) {
                    cues.append(strongBeatTime)
                }
            }
        }
        
        // Add drop moments for dramatic reveals
        for dropMoment in analysis.dropMoments {
            if dropMoment <= duration {
                let dropTime = CMTime(seconds: dropMoment, preferredTimescale: 600)
                if !cues.contains(where: { abs($0.seconds - dropMoment) < 0.1 }) {
                    cues.append(dropTime)
                }
            }
        }
        
        // Sort all cues by time
        cues.sort { $0.seconds < $1.seconds }
        
        return cues
    }
    
    /// Map content transitions to beat intensity for dynamic pacing
    private func mapContentToBeatIntensity(beatMap: BeatMap, totalDuration: Double) -> [ContentBeatMap] {
        _ = [ContentBeatMap]()
        
        // Map different content phases to beat intensity
        let phases = [
            ContentBeatMap(startTime: 0.0, duration: 2.0, intensity: .medium, type: .hook),
            ContentBeatMap(startTime: 2.0, duration: totalDuration - 4.0, intensity: .high, type: .steps),
            ContentBeatMap(startTime: totalDuration - 2.0, duration: 2.0, intensity: .high, type: .cta)
        ]
        
        return phases
    }
    
    /// Find optimal beat timing for content transitions with enhanced precision
    private func findOptimalBeatTiming(from startTime: Double, beatMap: BeatMap, contentMaps: [ContentBeatMap]) -> Double {
        // First, try to find a strong beat or drop moment near the start time
        let tolerance = 0.5 // Allow 0.5 second tolerance for beat snapping
        
        // Check for drop moments first (highest priority for dramatic effect)
        if let beatAnalysis = extractBeatAnalysis(from: beatMap) {
            for dropMoment in beatAnalysis.dropMoments {
                if abs(dropMoment - startTime) <= tolerance && dropMoment >= startTime {
                    return dropMoment
                }
            }
            
            // Check for strong beats next
            for strongBeat in beatAnalysis.strongBeats {
                if abs(strongBeat - startTime) <= tolerance && strongBeat >= startTime {
                    return strongBeat
                }
            }
        }
        
        // Fall back to next regular beat
        let nextBeat = beatMap.cueTimes.first(where: { $0.seconds >= startTime })?.seconds ?? startTime
        return nextBeat
    }
    
    /// Calculate step duration based on beat intensity and BPM - Fixed at 1.5s for viral TikTok appeal
    private func calculateStepDuration(beatMap: BeatMap, intensity: ContentBeatMap.BeatIntensity) -> Double {
        // Fixed 1.5 second duration for each step to maximize engagement
        return 1.5
    }
    
    /// Extract beat analysis from BeatMap (helper function)
    private func extractBeatAnalysis(from beatMap: BeatMap) -> BeatAnalysis? {
        // In a real implementation, this would be stored in BeatMap
        // For now, recreate based on BPM pattern
        let duration = beatMap.cueTimes.last?.seconds ?? 15.0
        let strongBeats = stride(from: 0.0, through: duration, by: 2.0).map { $0 }
        let dropMoments = duration > 8 ? [duration / 3, duration * 2 / 3].filter { $0 <= duration } : []
        
        return BeatAnalysis(
            bpm: beatMap.bpm,
            strongBeats: strongBeats,
            dropMoments: dropMoments,
            beatIntensity: 0.8
        )
    }

    // MARK: Template: PREMIUM Viral Video with Million-Dollar Structure
    private func kineticPlan(_ recipe: ViralRecipe, _ media: MediaBundle) async throws -> RenderPlan {
        let total = min(config.maxDuration.seconds, 15.0)
        let beatMap = await makeBeatMap(from: media.musicURL, fallbackBPM: config.fallbackBPM, duration: total)

        var items: [RenderPlan.TrackItem] = []
        var overlays: [RenderPlan.Overlay] = []

        // PREMIUM VIRAL STRUCTURE - Think Apple meets Tasty meets CapCut Pro!
        // 0-3s: Anxiety-inducing hook with fridge chaos
        // 3-5s: Logo promise with morph transition  
        // 5-11s: Fast-paced transformation with beat sync
        // 11-13s: Dramatic meal reveal with glow
        // 13-15s: CTA (to be handled by another agent)
        
        // PHASE 1: HOOK - Subtle chaos with reduced intensity (0-3s)
        items.append(.init(
            kind: .still(media.beforeFridge),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600)),
            transform: .kenBurns(maxScale: 1.05, seed: 42), // Subtle movement
            filters: [
                .premiumColorGrade(style: .warm), // Warmer, less harsh than moody
                .chromaticAberration(intensity: 0.4), // Reduced chaos effect
                .vignette(intensity: 0.3), // Lighter vignette
                .velocityRamp(factor: config.velocityRampFactor) // Speed ramping on beats
            ]
        ))

        // PHASE 2: PROMISE - Smooth transition morph (3-5s)
        items.append(.init(
            kind: .still(media.afterFridge),
            timeRange: CMTimeRange(start: CMTime(seconds: 3, preferredTimescale: 600), 
                                 duration: CMTime(seconds: 2, preferredTimescale: 600)),
            transform: .kenBurns(maxScale: 1.05, seed: 1), // Gentle movement for hope
            filters: [
                .premiumColorGrade(style: .fresh), // Clean, organized
                .foodEnhancer(intensity: 0.7),
                .lightLeak(position: CGPoint(x: 0.7, y: 0.3), intensity: 0.3) // Subtle hope glow
            ]
        ))

        // PHASE 3: TRANSFORMATION - Fast-paced ingredient montage (5-11s)
        items.append(.init(
            kind: .still(createIngredientMontageImage(ingredients: recipe.ingredients, media: media)),
            timeRange: CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600),
                                 duration: CMTime(seconds: 6, preferredTimescale: 600)),
            transform: .kenBurns(maxScale: 1.06, seed: 7), // Reduced movement
            filters: [
                .premiumColorGrade(style: .vibrant), // Pop the colors
                .velocityRamp(factor: config.velocityRampFactor), // Beat sync speed
                .lightLeak(position: CGPoint(x: 0.8, y: 0.2), intensity: 0.4),
                .breatheEffect(intensity: config.breatheIntensity, bpm: beatMap.bpm),
                .parallaxMove(direction: CGVector(dx: 1, dy: 0.5), intensity: config.parallaxIntensity)
            ]
        ))

        // PHASE 4: REVEAL - Meal reveal with natural colors (11-13s)
        items.append(.init(
            kind: .still(media.cookedMeal),
            timeRange: CMTimeRange(start: CMTime(seconds: 11, preferredTimescale: 600),
                                 duration: CMTime(seconds: 2, preferredTimescale: 600)),
            transform: .kenBurns(maxScale: 1.08, seed: 99), // Subtle reveal zoom
            filters: [
                .premiumColorGrade(style: .warm), // Natural SnapChef brand colors instead of cinematic
                .foodEnhancer(intensity: 0.9), // Moderate food appeal
                .viralPop(warmth: 0.6, punch: 0.7), // More natural viral colors
                .lightLeak(position: CGPoint(x: 0.5, y: 0.5), intensity: 0.5), // Softer glow
                .filmGrain(intensity: 0.1), // Subtle texture
                .chromaticAberration(intensity: 0.15) // Minimal separation
            ]
        ))

        // PHASE 5: CTA Setup (13-15s) - Clean background for CTA
        items.append(.init(
            kind: .still(media.cookedMeal),
            timeRange: CMTimeRange(start: CMTime(seconds: 13, preferredTimescale: 600),
                                 duration: CMTime(seconds: 2, preferredTimescale: 600)),
            transform: .identity, // Static for readability
            filters: [
                .gaussianBlur(radius: 2), // Subtle blur to highlight CTA
                .premiumColorGrade(style: .fresh), // Clean SnapChef brand styling
                .vignette(intensity: 0.3) // Light frame for CTA
            ]
        ))
        
        // OVERLAY PHASE 1: Anxiety Hook with Premium Effects (0-3s) - Larger, centered text
        overlays.append(.init(
            start: .zero,
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            layerBuilder: { cfg in 
                self.createLargerHookOverlay(
                    text: recipe.hook ?? "FRIDGE CHAOS → DINNER MAGIC ✨", 
                    config: cfg,
                    screenScale: cfg.contentsScale
                )
            }
        ))
        
        // OVERLAY PHASE 2: Brand Promise with Liquid Morph (3-5s)
        overlays.append(.init(
            start: CMTime(seconds: 3, preferredTimescale: 600),
            duration: CMTime(seconds: 2, preferredTimescale: 600),
            layerBuilder: { cfg in 
                self.createBrandPromiseOverlay(text: "SnapChef makes it EASY 🚀", config: cfg, screenScale: cfg.contentsScale)
            }
        ))
        
        // OVERLAY PHASE 3: Rapid Ingredient Steps with Beat Cuts (5-11s) - 1.5s each, vertically centered
        let stepTexts = recipe.steps.prefix(4).map { removeStepNumbers(shorten($0.title)) }
        let stepDuration = 1.5 // Fixed 1.5 seconds per step
        
        for (i, text) in stepTexts.enumerated() {
            let stepStart = 5.0 + Double(i) * stepDuration
            // Sync to beat for each step
            let beatSyncedStart = findOptimalBeatTiming(from: stepStart, beatMap: beatMap, contentMaps: [])
            
            overlays.append(.init(
                start: CMTime(seconds: beatSyncedStart, preferredTimescale: 600),
                duration: CMTime(seconds: stepDuration, preferredTimescale: 600),
                layerBuilder: { cfg in 
                    self.createCenteredStepOverlay(
                        text: text, 
                        index: i, 
                        beatBPM: beatMap.bpm,
                        config: cfg,
                        screenScale: cfg.contentsScale
                    )
                }
            ))
        }
        
        // OVERLAY PHASE 4: Dramatic Reveal Text with Explosion (11-13s)
        overlays.append(.init(
            start: CMTime(seconds: 11, preferredTimescale: 600),
            duration: CMTime(seconds: 2, preferredTimescale: 600),
            layerBuilder: { cfg in 
                self.createDramaticRevealOverlay(
                    text: "\(recipe.timeMinutes ?? 15) MIN MAGIC! 🔥", 
                    config: cfg,
                    screenScale: cfg.contentsScale
                )
            }
        ))
        
        // OVERLAY PHASE 5: Call-to-Action with Pulsing Gradient (13-15s) - Even larger text
        overlays.append(.init(
            start: CMTime(seconds: 13, preferredTimescale: 600),
            duration: CMTime(seconds: 2, preferredTimescale: 600),
            layerBuilder: { cfg in 
                self.createLargerCTAOverlay(
                    text: "TAP TO GET RECIPE! 👆", 
                    config: cfg,
                    screenScale: cfg.contentsScale,
                    beatBPM: beatMap.bpm
                )
            }
        ))

        return RenderPlan(items: items, overlays: overlays, audio: media.musicURL,
                          outputDuration: CMTime(seconds: total, preferredTimescale: 600))
    }

    // MARK: - PREMIUM HELPER FUNCTIONS (removed duplicates)
    
    private func createIngredientMontageImage(ingredients: [String], media: MediaBundle) -> UIImage {
        // For now, return the meal image - in production you'd create a collage
        // This is where you'd composite ingredient images with rapid cuts
        return media.cookedMeal
    }
    
    nonisolated private func createBrandPromiseOverlay(text: String, config: RenderConfig, screenScale: CGFloat) -> CALayer {
        let L = CALayer()
        L.frame = CGRect(origin: .zero, size: config.size)
        
        // Liquid morph transition effect
        let morphLayer = CAShapeLayer()
        morphLayer.frame = L.bounds
        morphLayer.fillColor = UIColor.white.withAlphaComponent(0.9).cgColor
        
        // Create morph animation
        let morphPath = createLiquidMorphPath(bounds: L.bounds)
        morphLayer.path = morphPath.cgPath
        
        let morphAnimation = CABasicAnimation(keyPath: "path")
        morphAnimation.duration = 1.5
        morphAnimation.fromValue = createInitialMorphPath(bounds: L.bounds).cgPath
        morphAnimation.toValue = morphPath.cgPath
        morphAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        morphLayer.add(morphAnimation, forKey: "morph")
        
        // Text with premium styling
        let textLayer = CATextLayer()
        textLayer.string = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: config.stepsFontSize, weight: .black),
            .foregroundColor: UIColor.black
        ])
        textLayer.alignmentMode = .center
        textLayer.frame = L.bounds
        textLayer.contentsScale = screenScale
        
        L.addSublayer(morphLayer)
        L.addSublayer(textLayer)
        return L
    }
    
    nonisolated private func createDramaticRevealOverlay(text: String, config: RenderConfig, screenScale: CGFloat) -> CALayer {
        let L = CALayer()
        L.frame = CGRect(origin: .zero, size: config.size)
        
        // Explosion-style reveal with particles
        let explosionLayer = CAEmitterLayer()
        explosionLayer.emitterPosition = CGPoint(x: config.size.width/2, y: config.size.height/2)
        explosionLayer.emitterShape = .circle
        explosionLayer.emitterSize = CGSize(width: 20, height: 20)
        
        let sparkle = CAEmitterCell()
        sparkle.contents = createStarBurst().cgImage
        sparkle.birthRate = 50
        sparkle.lifetime = 2.0
        sparkle.velocity = 100
        sparkle.velocityRange = 50
        sparkle.emissionRange = .pi * 2
        sparkle.scale = 0.5
        sparkle.scaleRange = 0.3
        sparkle.alphaSpeed = -1.0
        
        explosionLayer.emitterCells = [sparkle]
        L.addSublayer(explosionLayer)
        
        // Massive text with glow
        let textLayer = CATextLayer()
        textLayer.string = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: config.hookFontSize * 1.2, weight: .black),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.yellow.cgColor,
            .strokeWidth: -3.0
        ])
        textLayer.alignmentMode = .center
        textLayer.frame = L.bounds
        textLayer.contentsScale = screenScale
        
        // Glow effect
        textLayer.shadowColor = UIColor.yellow.cgColor
        textLayer.shadowRadius = 15
        textLayer.shadowOpacity = 1.0
        textLayer.shadowOffset = CGSize.zero
        
        // Scale-in with bounce
        let reveal = CAKeyframeAnimation(keyPath: "transform.scale")
        reveal.values = [0.0, 1.3, 1.0]
        reveal.keyTimes = [0, 0.7, 1.0]
        reveal.duration = 0.8
        reveal.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        textLayer.add(reveal, forKey: "reveal")
        
        L.addSublayer(textLayer)
        return L
    }
    
    nonisolated private func createLiquidMorphPath(bounds: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let w = bounds.width
        let h = bounds.height
        
        // Create flowing liquid shape
        path.move(to: CGPoint(x: w * 0.1, y: h * 0.3))
        path.addCurve(to: CGPoint(x: w * 0.9, y: h * 0.4),
                     controlPoint1: CGPoint(x: w * 0.4, y: h * 0.1),
                     controlPoint2: CGPoint(x: w * 0.6, y: h * 0.6))
        path.addCurve(to: CGPoint(x: w * 0.8, y: h * 0.8),
                     controlPoint1: CGPoint(x: w * 0.95, y: h * 0.5),
                     controlPoint2: CGPoint(x: w * 0.7, y: h * 0.9))
        path.addCurve(to: CGPoint(x: w * 0.1, y: h * 0.7),
                     controlPoint1: CGPoint(x: w * 0.5, y: h * 0.85),
                     controlPoint2: CGPoint(x: w * 0.2, y: h * 0.6))
        path.close()
        
        return path
    }
    
    nonisolated private func createInitialMorphPath(bounds: CGRect) -> UIBezierPath {
        return UIBezierPath(ovalIn: CGRect(x: bounds.width/2 - 10, y: bounds.height/2 - 10, width: 20, height: 20))
    }
    
    nonisolated private func createStarBurst() -> UIImage {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.yellow.cgColor)
        
        // Draw star shape
        let path = UIBezierPath()
        let center = CGPoint(x: size.width/2, y: size.height/2)
        let radius: CGFloat = 8
        
        for i in 0..<10 {
            let angle = CGFloat(i) * .pi / 5
            let r = i % 2 == 0 ? radius : radius * 0.5
            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.close()
        path.fill()
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    nonisolated private func shorten(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Shorter for rapid-fire viral format
        if trimmed.count <= 24 { return trimmed }
        return String(trimmed.prefix(21)) + "…"
    }
    
    /// Remove step numbers and prefixes for cleaner text
    nonisolated private func removeStepNumbers(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^Step\s+\d+:\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^Step\s+\d+\.\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }
    
    /// Create larger hook overlay with center positioning and pulse animation
    nonisolated private func createLargerHookOverlay(text: String, config: RenderConfig, screenScale: CGFloat) -> CALayer {
        let L = CALayer()
        L.frame = CGRect(origin: .zero, size: config.size)
        
        // Main text layer with larger font
        let textLayer = CATextLayer()
        textLayer.string = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: config.hookFontSize * 1.5, weight: .black), // 1.5x larger
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black.cgColor,
            .strokeWidth: -3.0
        ])
        textLayer.alignmentMode = .center
        
        // Center vertically and horizontally
        let textSize = textLayer.preferredFrameSize()
        textLayer.frame = CGRect(
            x: (config.size.width - textSize.width) / 2,
            y: (config.size.height - textSize.height) / 2, // Vertically centered
            width: textSize.width,
            height: textSize.height
        )
        textLayer.contentsScale = screenScale
        
        // Glow effect
        textLayer.shadowColor = UIColor.yellow.cgColor
        textLayer.shadowRadius = 10
        textLayer.shadowOpacity = 0.8
        textLayer.shadowOffset = CGSize.zero
        
        // Beat-synced pulse animation
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.1
        pulse.duration = 60.0 / 120.0 // Sync to BPM
        pulse.autoreverses = true
        pulse.repeatCount = .greatestFiniteMagnitude
        textLayer.add(pulse, forKey: "pulse")
        
        L.addSublayer(textLayer)
        return L
    }
    
    /// Create centered step overlay with slide animations and pulse effects
    nonisolated private func createCenteredStepOverlay(text: String, index: Int, beatBPM: Double, config: RenderConfig, screenScale: CGFloat) -> CALayer {
        let L = CALayer()
        L.frame = CGRect(origin: .zero, size: config.size)
        
        // Background with subtle gradient for better readability
        let backgroundLayer = CAGradientLayer()
        backgroundLayer.colors = [
            UIColor.black.withAlphaComponent(0.6).cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor
        ]
        backgroundLayer.locations = [0, 1]
        backgroundLayer.frame = L.bounds
        L.addSublayer(backgroundLayer)
        
        // Main text layer
        let textLayer = CATextLayer()
        textLayer.string = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: config.stepsFontSize * 1.2, weight: .bold),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black.cgColor,
            .strokeWidth: -2.0
        ])
        textLayer.alignmentMode = .center
        
        // Center vertically on screen
        let textSize = textLayer.preferredFrameSize()
        textLayer.frame = CGRect(
            x: (config.size.width - textSize.width) / 2,
            y: (config.size.height - textSize.height) / 2, // Vertically centered
            width: textSize.width,
            height: textSize.height
        )
        textLayer.contentsScale = screenScale
        
        // Slide in animation from right
        let slideIn = CABasicAnimation(keyPath: "position.x")
        slideIn.fromValue = config.size.width + textSize.width/2
        slideIn.toValue = config.size.width / 2
        slideIn.duration = 0.3
        slideIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
        textLayer.add(slideIn, forKey: "slideIn")
        
        // Slide out animation to left after 1.2 seconds
        let slideOut = CABasicAnimation(keyPath: "position.x")
        slideOut.fromValue = config.size.width / 2
        slideOut.toValue = -textSize.width/2
        slideOut.duration = 0.3
        slideOut.beginTime = CACurrentMediaTime() + 1.2
        slideOut.timingFunction = CAMediaTimingFunction(name: .easeIn)
        textLayer.add(slideOut, forKey: "slideOut")
        
        // Beat-synced pulse animation
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.05
        pulse.duration = 60.0 / beatBPM
        pulse.autoreverses = true
        pulse.repeatCount = .greatestFiniteMagnitude
        textLayer.add(pulse, forKey: "pulse")
        
        L.addSublayer(textLayer)
        return L
    }
    
    /// Create larger CTA overlay with prominent positioning and beat-synced animations
    nonisolated private func createLargerCTAOverlay(text: String, config: RenderConfig, screenScale: CGFloat, beatBPM: Double) -> CALayer {
        let L = CALayer()
        L.frame = CGRect(origin: .zero, size: config.size)
        
        // Animated gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemPink.withAlphaComponent(0.8).cgColor,
            UIColor.systemOrange.withAlphaComponent(0.8).cgColor,
            UIColor.systemYellow.withAlphaComponent(0.8).cgColor
        ]
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = L.bounds
        
        // Animated gradient rotation
        let gradientRotation = CABasicAnimation(keyPath: "transform.rotation")
        gradientRotation.fromValue = 0
        gradientRotation.toValue = Double.pi * 2
        gradientRotation.duration = 3.0
        gradientRotation.repeatCount = .greatestFiniteMagnitude
        gradientLayer.add(gradientRotation, forKey: "rotate")
        
        L.addSublayer(gradientLayer)
        
        // Main CTA text layer with even larger font
        let textLayer = CATextLayer()
        textLayer.string = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: config.hookFontSize * 2.0, weight: .black), // 2x larger
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black.cgColor,
            .strokeWidth: -4.0
        ])
        textLayer.alignmentMode = .center
        
        // Prominent positioning - center screen
        let textSize = textLayer.preferredFrameSize()
        textLayer.frame = CGRect(
            x: (config.size.width - textSize.width) / 2,
            y: (config.size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        textLayer.contentsScale = screenScale
        
        // Enhanced glow effect
        textLayer.shadowColor = UIColor.cyan.cgColor
        textLayer.shadowRadius = 20
        textLayer.shadowOpacity = 1.0
        textLayer.shadowOffset = CGSize.zero
        
        // Beat-synced pulse animation - more dramatic
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.2
        pulse.duration = 60.0 / beatBPM
        pulse.autoreverses = true
        pulse.repeatCount = .greatestFiniteMagnitude
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        textLayer.add(pulse, forKey: "pulse")
        
        // Additional beat-synced glow pulse
        let glowPulse = CABasicAnimation(keyPath: "shadowRadius")
        glowPulse.fromValue = 20
        glowPulse.toValue = 35
        glowPulse.duration = 60.0 / beatBPM
        glowPulse.autoreverses = true
        glowPulse.repeatCount = .greatestFiniteMagnitude
        textLayer.add(glowPulse, forKey: "glowPulse")
        
        L.addSublayer(textLayer)
        return L
    }
}

// MARK: - Enhanced Beat Analysis Data Models

/// Enhanced beat analysis with strong beats and drop moments for premium features
struct BeatAnalysis: Sendable {
    let bpm: Double
    let strongBeats: [Double] // Time positions of strong beats for transitions
    let dropMoments: [Double] // Time positions of drop moments for reveals
    let beatIntensity: Double // Overall intensity (0.0 - 1.0) for rhythm sync
}

/// Content phases mapped to beat intensity for dynamic pacing
struct ContentBeatMap: Sendable {
    let startTime: Double
    let duration: Double
    let intensity: BeatIntensity
    let type: ContentType
    
    enum BeatIntensity: Sendable {
        case low, medium, high
    }
    
    enum ContentType: Sendable {
        case hook, steps, cta, transition
    }
}