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
    
    /// Calculate step duration based on beat intensity and BPM
    private func calculateStepDuration(beatMap: BeatMap, intensity: ContentBeatMap.BeatIntensity) -> Double {
        let baseDuration = 60.0 / beatMap.bpm * 2 // Base duration of 2 beats
        
        switch intensity {
        case .low:
            return max(1.2, baseDuration * 0.8) // Shorter for low intensity
        case .medium:
            return max(1.6, baseDuration) // Standard duration
        case .high:
            return max(2.0, baseDuration * 1.2) // Longer for high intensity
        }
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
        
        // PHASE 1: HOOK - Anxiety-inducing fridge chaos (0-3s)
        items.append(.init(
            kind: .still(media.beforeFridge),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600)),
            transform: .kenBurns(maxScale: 1.08, seed: 42), // Frantic zoom for anxiety
            filters: [
                .premiumColorGrade(style: .moody), // Dark, dramatic
                .chromaticAberration(intensity: 0.8), // Chaos effect
                .vignette(intensity: 0.6), // Focus attention
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
            transform: .kenBurns(maxScale: 1.12, seed: 7), // Dynamic movement
            filters: [
                .premiumColorGrade(style: .vibrant), // Pop the colors
                .velocityRamp(factor: config.velocityRampFactor), // Beat sync speed
                .lightLeak(position: CGPoint(x: 0.8, y: 0.2), intensity: 0.4),
                .breatheEffect(intensity: config.breatheIntensity, bpm: beatMap.bpm),
                .parallaxMove(direction: CGVector(dx: 1, dy: 0.5), intensity: config.parallaxIntensity)
            ]
        ))

        // PHASE 4: REVEAL - Dramatic meal reveal with shock zoom (11-13s)
        items.append(.init(
            kind: .still(media.cookedMeal),
            timeRange: CMTimeRange(start: CMTime(seconds: 11, preferredTimescale: 600),
                                 duration: CMTime(seconds: 2, preferredTimescale: 600)),
            transform: .kenBurns(maxScale: 1.25, seed: 99), // DRAMATIC shock zoom
            filters: [
                .premiumColorGrade(style: .cinematic), // Hollywood feel
                .foodEnhancer(intensity: 1.2), // Maximum food appeal
                .viralPop(warmth: 0.8, punch: 1.0), // Viral-ready colors
                .lightLeak(position: CGPoint(x: 0.5, y: 0.5), intensity: 0.8), // Heavenly glow
                .filmGrain(intensity: 0.2), // Premium texture
                .chromaticAberration(intensity: 0.3) // Dramatic separation
            ]
        ))

        // PHASE 5: CTA Setup (13-15s) - Simple background for CTA
        items.append(.init(
            kind: .still(media.cookedMeal),
            timeRange: CMTimeRange(start: CMTime(seconds: 13, preferredTimescale: 600),
                                 duration: CMTime(seconds: 2, preferredTimescale: 600)),
            transform: .identity, // Static for readability
            filters: [
                .gaussianBlur(radius: 2), // Subtle blur to highlight CTA
                .premiumColorGrade(style: .warm),
                .vignette(intensity: 0.4) // Frame the CTA
            ]
        ))
        
        // OVERLAY PHASE 1: Anxiety Hook with Premium Effects (0-3s)
        overlays.append(.init(
            start: .zero,
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            layerBuilder: { cfg in 
                OverlayFactory(config: cfg).createHookOverlay(
                    text: recipe.hook ?? "FRIDGE CHAOS → DINNER MAGIC ✨", config: cfg) 
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
        
        // OVERLAY PHASE 3: Rapid Ingredient Steps with Beat Cuts (5-11s)
        let stepTexts = recipe.steps.prefix(4).map { shorten($0.title) }
        let stepDuration = 6.0 / Double(max(stepTexts.count, 1)) // Divide time evenly
        
        for (i, text) in stepTexts.enumerated() {
            let stepStart = 5.0 + Double(i) * stepDuration
            // Sync to beat for each step
            let beatSyncedStart = findOptimalBeatTiming(from: stepStart, beatMap: beatMap, contentMaps: [])
            
            overlays.append(.init(
                start: CMTime(seconds: beatSyncedStart, preferredTimescale: 600),
                duration: CMTime(seconds: stepDuration * 0.8, preferredTimescale: 600), // Slight overlap
                layerBuilder: { cfg in 
                    OverlayFactory(config: cfg).createKineticStepOverlay(
                        text: "\(i+1). \(text)", 
                        index: i, 
                        beatBPM: beatMap.bpm * 1.2, // Faster for urgency
                        config: cfg
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
        
        // OVERLAY PHASE 5: Call-to-Action with Pulsing Gradient (13-15s)
        overlays.append(.init(
            start: CMTime(seconds: 13, preferredTimescale: 600),
            duration: CMTime(seconds: 2, preferredTimescale: 600),
            layerBuilder: { cfg in 
                OverlayFactory(config: cfg).createCTAOverlay(
                    text: "TAP TO GET RECIPE! 👆", 
                    config: cfg
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