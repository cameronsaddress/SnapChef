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
            let cues = stride(from: 0.0, through: duration, by: 60.0 / fallbackBPM)
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
                .premiumColorGrade(style: .natural), // Remove green tint with natural colors
                .chromaticAberration(intensity: 0.2), // Minimal effect
                .vignette(intensity: 0.1), // Very light vignette
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
                .premiumColorGrade(style: .natural), // Clean, natural colors
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
                .premiumColorGrade(style: .natural), // Natural vibrant colors
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
                .premiumColorGrade(style: .natural), // Clean natural colors without tint
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
                .premiumColorGrade(style: .natural), // Clean natural styling
                .vignette(intensity: 0.3) // Light frame for CTA
            ]
        ))

        // OVERLAY SEQUENCE: Perfectly timed viral text sequence with alternating animations

        // OVERLAY PHASE 1: "POV: You're hungry" (0-3s) - Slide in from RIGHT
        overlays.append(.init(
            start: .zero,
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            layerBuilder: { cfg in
                self.createAlternatingSequenceOverlay(
                    text: "POV: You're hungry",
                    config: cfg,
                    screenScale: cfg.contentsScale,
                    slideDirection: .right
                )
            }
        ))

        // OVERLAY PHASE 2: "Open your fridge" (3-6s) - Slide in from LEFT  
        overlays.append(.init(
            start: CMTime(seconds: 3, preferredTimescale: 600),
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            layerBuilder: { cfg in
                self.createAlternatingSequenceOverlay(
                    text: "Open your fridge",
                    config: cfg,
                    screenScale: cfg.contentsScale,
                    slideDirection: .left
                )
            }
        ))

        // OVERLAY PHASE 3: "AI enters chat" (6-9s) - Slide in from RIGHT
        overlays.append(.init(
            start: CMTime(seconds: 6, preferredTimescale: 600),
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            layerBuilder: { cfg in
                self.createAlternatingSequenceOverlay(
                    text: "AI enters chat",
                    config: cfg,
                    screenScale: cfg.contentsScale,
                    slideDirection: .right
                )
            }
        ))

        // OVERLAY PHASE 4: "Dinner served" (9-12s) - Slide in from LEFT
        overlays.append(.init(
            start: CMTime(seconds: 9, preferredTimescale: 600),
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            layerBuilder: { cfg in
                self.createAlternatingSequenceOverlay(
                    text: "Dinner served 🤌",
                    config: cfg,
                    screenScale: cfg.contentsScale,
                    slideDirection: .left
                )
            }
        ))

        // OVERLAY PHASE 5: Call-to-Action Text (12-15s) - Special CTA animation
        overlays.append(.init(
            start: CMTime(seconds: 12, preferredTimescale: 600),
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            layerBuilder: { cfg in
                self.createCTATextOverlay(
                    text: "Awesome recipes from what you have",
                    config: cfg,
                    screenScale: cfg.contentsScale
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
        explosionLayer.emitterPosition = CGPoint(x: config.size.width / 2, y: config.size.height / 2)
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
        return UIBezierPath(ovalIn: CGRect(x: bounds.width / 2 - 10, y: bounds.height / 2 - 10, width: 20, height: 20))
    }

    nonisolated private func createStarBurst() -> UIImage {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else {
            print("❌ Failed to get graphics context")
            return UIImage()
        }
        context.setFillColor(UIColor.yellow.cgColor)

        // Draw star shape
        let path = UIBezierPath()
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
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
        slideIn.fromValue = config.size.width + textSize.width / 2
        slideIn.toValue = config.size.width / 2
        slideIn.duration = 0.3
        slideIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
        textLayer.add(slideIn, forKey: "slideIn")

        // Slide out animation to left after 1.2 seconds
        let slideOut = CABasicAnimation(keyPath: "position.x")
        slideOut.fromValue = config.size.width / 2
        slideOut.toValue = -textSize.width / 2
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

    /// Create sequence text overlay with proper animations and text rendering
    nonisolated private func createSequenceTextOverlay(text: String, config: RenderConfig, screenScale: CGFloat) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)

        // Create gradient background container
        let gradientContainer = CALayer()

        // Create gradient background with SnapChef colors
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 0.95).cgColor, // Orange #FF6B35
            UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 0.95).cgColor  // Pink #FF1493
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 16

        // Create text layer with proper configuration
        let textLayer = CATextLayer()
        textLayer.string = text  // FIXED: Use plain string instead of attributed string
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, config.stepsFontSize * 1.4, nil)
        textLayer.fontSize = config.stepsFontSize * 1.4
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = screenScale
        textLayer.isWrapped = true

        // Calculate proper sizing
        let textSize = textLayer.preferredFrameSize()
        let padding: CGFloat = 20
        let containerWidth = min(textSize.width + padding * 2, config.size.width - 80)
        let containerHeight = max(textSize.height + padding * 2, 60) // Minimum height

        // Position container in center of screen  
        let containerFrame = CGRect(
            x: (config.size.width - containerWidth) / 2,
            y: (config.size.height - containerHeight) / 2,
            width: containerWidth,
            height: containerHeight
        )

        // Set up layer hierarchy properly
        gradientContainer.frame = containerFrame
        gradientLayer.frame = CGRect(origin: .zero, size: containerFrame.size)
        textLayer.frame = CGRect(
            x: padding,
            y: padding,
            width: containerFrame.width - padding * 2,
            height: containerFrame.height - padding * 2
        )

        // Add shadow for depth
        gradientLayer.shadowColor = UIColor.black.cgColor
        gradientLayer.shadowOffset = CGSize(width: 0, height: 4)
        gradientLayer.shadowRadius = 8
        gradientLayer.shadowOpacity = 0.4

        // FIXED: Proper video composition animations
        // Slide in from right animation
        let slideIn = CABasicAnimation(keyPath: "position.x")
        slideIn.fromValue = config.size.width + containerFrame.width / 2 // Start off-screen right
        slideIn.toValue = config.size.width / 2 // Center position
        slideIn.duration = 0.8
        slideIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
        slideIn.beginTime = AVCoreAnimationBeginTimeAtZero
        slideIn.fillMode = .both
        slideIn.isRemovedOnCompletion = false

        // Slide out to left animation (after 2 seconds)
        let slideOut = CABasicAnimation(keyPath: "position.x")
        slideOut.fromValue = config.size.width / 2
        slideOut.toValue = -containerFrame.width / 2 // Exit off-screen left
        slideOut.duration = 0.6
        slideOut.beginTime = AVCoreAnimationBeginTimeAtZero + 2.0
        slideOut.timingFunction = CAMediaTimingFunction(name: .easeIn)
        slideOut.fillMode = .both
        slideOut.isRemovedOnCompletion = false

        // Beat-synced pulse with proper timing
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.06
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = 4 // Finite repeat for video composition
        pulse.beginTime = AVCoreAnimationBeginTimeAtZero + 0.5 // Start after slide-in
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.fillMode = .both
        pulse.isRemovedOnCompletion = false

        // Assemble layer hierarchy
        gradientContainer.addSublayer(gradientLayer)
        gradientContainer.addSublayer(textLayer)

        // Apply animations to the container
        gradientContainer.add(slideIn, forKey: "slideIn")
        gradientContainer.add(slideOut, forKey: "slideOut")
        gradientContainer.add(pulse, forKey: "pulse")

        container.addSublayer(gradientContainer)
        return container
    }

    /// Create alternating sequence overlay with FADE animations and spark effects
    nonisolated private func createAlternatingSequenceOverlay(text: String, config: RenderConfig, screenScale: CGFloat, slideDirection: SlideDirection) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)

        // Create sequence container
        let sequenceContainer = CALayer()

        // Create gradient background with SnapChef colors
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 0.95).cgColor, // Orange #FF6B35
            UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 0.95).cgColor  // Pink #FF1493
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 16

        // FIXED: Create text layer with proper font calculation for full text width
        let textLayer = CATextLayer()
        textLayer.string = text  // Use plain string for reliable rendering
        let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, config.stepsFontSize * 1.4, nil)
        textLayer.font = font
        textLayer.fontSize = config.stepsFontSize * 1.4
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = screenScale
        textLayer.isWrapped = true

        // Debug: Ensure text is being set
        print("[RenderPlanner] Creating alternating sequence overlay with text: '\(text)'")
        print("[RenderPlanner] Text layer string set to: '\(textLayer.string ?? "nil")'")
        print("[RenderPlanner] Font size: \(textLayer.fontSize)")

        // FIXED: Calculate actual text dimensions using the font
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        let textSize = (text as NSString).size(withAttributes: textAttributes)
        let padding: CGFloat = 50 // Increased padding to ensure full text visibility
        let containerWidth = min(textSize.width + padding * 2, config.size.width - 60) // Ensure text fits
        let containerHeight = max(textSize.height + padding * 2, 70) // Adequate height

        print("[RenderPlanner] Calculated text size: \(textSize)")
        print("[RenderPlanner] Container size: \(CGSize(width: containerWidth, height: containerHeight))")

        // Position container in center of screen
        let containerFrame = CGRect(
            x: (config.size.width - containerWidth) / 2,
            y: (config.size.height - containerHeight) / 2,
            width: containerWidth,
            height: containerHeight
        )

        // Set up layer hierarchy properly
        sequenceContainer.frame = containerFrame
        sequenceContainer.opacity = 0.0  // Start invisible for fade in
        gradientLayer.frame = CGRect(origin: .zero, size: containerFrame.size)
        gradientLayer.opacity = 1.0
        textLayer.frame = CGRect(
            x: padding,
            y: (containerFrame.height - textSize.height) / 2, // Center text vertically
            width: containerFrame.width - padding * 2,
            height: textSize.height
        )
        textLayer.opacity = 1.0

        // Debug positioning
        print("[RenderPlanner] Sequence container frame: \(sequenceContainer.frame)")
        print("[RenderPlanner] Text layer frame: \(textLayer.frame)")

        // Add shadow for depth and visibility
        gradientLayer.shadowColor = UIColor.black.cgColor
        gradientLayer.shadowOffset = CGSize(width: 0, height: 4)
        gradientLayer.shadowRadius = 8
        gradientLayer.shadowOpacity = 0.4

        // ADD SPARK EFFECTS: Create particle emitter behind text
        let sparkEmitter = CAEmitterLayer()
        sparkEmitter.emitterPosition = CGPoint(x: containerFrame.width / 2, y: containerFrame.height / 2)
        sparkEmitter.emitterShape = .rectangle
        sparkEmitter.emitterSize = CGSize(width: containerFrame.width * 1.6, height: containerFrame.height * 1.6)  // Double the emitter size
        sparkEmitter.zPosition = -1 // Behind text but in front of background

        // RESTORED: Use regular sparkles "✨" for text containers (phases 1-4)
        let sparkleCell = CAEmitterCell()
        sparkleCell.contents = createSparkleImage().cgImage
        sparkleCell.birthRate = 15 // Good rate for sparkles
        sparkleCell.lifetime = 2.0
        sparkleCell.velocity = 50
        sparkleCell.velocityRange = 30
        sparkleCell.emissionRange = .pi * 2
        sparkleCell.yAcceleration = 80 // Gravity effect
        sparkleCell.scale = 0.8  // Good size for sparkles
        sparkleCell.scaleRange = 0.4
        sparkleCell.alphaSpeed = -0.5
        sparkleCell.spin = .pi
        sparkleCell.spinRange = .pi

        let foodCells = [sparkleCell]

        sparkEmitter.emitterCells = [sparkleCell]

        // FIXED: FADE ANIMATIONS instead of sliding
        // Fade in animation (0-0.5s)
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0.0
        fadeIn.toValue = 1.0
        fadeIn.duration = 0.5
        fadeIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
        fadeIn.beginTime = AVCoreAnimationBeginTimeAtZero
        fadeIn.fillMode = .both
        fadeIn.isRemovedOnCompletion = false

        // Stay visible with full opacity (0.5-2.5s)

        // Fade out animation (2.5-3.0s) 
        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1.0
        fadeOut.toValue = 0.0
        fadeOut.duration = 0.5
        fadeOut.beginTime = AVCoreAnimationBeginTimeAtZero + 2.5
        fadeOut.timingFunction = CAMediaTimingFunction(name: .easeIn)
        fadeOut.fillMode = .both
        fadeOut.isRemovedOnCompletion = false

        // Start spark explosion when fade-in completes (at 0.5s)
        let sparkStart = CABasicAnimation(keyPath: "birthRate")
        sparkStart.fromValue = 0
        sparkStart.toValue = 15
        sparkStart.duration = 0.1
        sparkStart.beginTime = AVCoreAnimationBeginTimeAtZero + 0.5
        sparkStart.fillMode = .both
        sparkStart.isRemovedOnCompletion = false

        // Stop sparks when fading out (at 2.5s)
        let sparkStop = CABasicAnimation(keyPath: "birthRate")
        sparkStop.fromValue = 15
        sparkStop.toValue = 0
        sparkStop.duration = 0.1
        sparkStop.beginTime = AVCoreAnimationBeginTimeAtZero + 2.5
        sparkStop.fillMode = .both
        sparkStop.isRemovedOnCompletion = false

        // Beat-synced pulse while visible (0.8-2.3s)
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.06
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = 3 // About 3.6s of pulsing total
        pulse.beginTime = AVCoreAnimationBeginTimeAtZero + 0.8
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.fillMode = .both
        pulse.isRemovedOnCompletion = false

        // Assemble layer hierarchy
        sequenceContainer.addSublayer(gradientLayer)
        sequenceContainer.addSublayer(sparkEmitter) // Sparks behind text
        sequenceContainer.addSublayer(textLayer)

        // Apply animations
        sequenceContainer.add(fadeIn, forKey: "fadeIn")
        sequenceContainer.add(fadeOut, forKey: "fadeOut")
        sequenceContainer.add(pulse, forKey: "pulse")
        sparkEmitter.add(sparkStart, forKey: "sparkStart")
        sparkEmitter.add(sparkStop, forKey: "sparkStop")

        container.addSublayer(sequenceContainer)
        return container
    }

    /// Create sparkle image for particle effects (✨)
    nonisolated private func createSparkleImage() -> UIImage {
        let size = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else {
            print("❌ Failed to get graphics context")
            return UIImage()
        }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // Create golden spark with SnapChef branding colors
        let sparkColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.9) // Gold
        context.setFillColor(sparkColor.cgColor)

        // Draw a four-pointed star shape
        context.beginPath()
        let radius: CGFloat = 5
        let innerRadius: CGFloat = 2

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

        // Add a bright center
        context.setFillColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.fillEllipse(in: CGRect(x: center.x - 1, y: center.y - 1, width: 2, height: 2))

        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }

    /// Create CTA text overlay with SnapChef logo and FADE animations
    nonisolated private func createCTATextOverlay(text: String, config: RenderConfig, screenScale: CGFloat) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)

        // STEP 1: Create CTA container ABOVE the logo (at 35% screen height)
        let ctaContainer = CALayer()

        // STEP 2: Create large SnapChef logo at 40% screen height (middle)
        let logoContainer = createSnapChefLogo(config: config, screenScale: screenScale)
        // Get the actual logo size from the container
        let actualLogoSize = logoContainer.frame.size
        logoContainer.frame = CGRect(
            x: (config.size.width - actualLogoSize.width) / 2, // FIXED: Center horizontally
            y: config.size.height * 0.4 - actualLogoSize.height / 2, // Vertically centered at 40%
            width: actualLogoSize.width,
            height: actualLogoSize.height
        )
        logoContainer.opacity = 0.0 // Start invisible for fade in

        // STEP 3: Setup CTA styling (moved from bottom to above logo)

        // Create pulsing gradient background for CTA
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 0.95).cgColor,  // Pink
            UIColor(red: 0.6, green: 0.196, blue: 0.8, alpha: 0.95).cgColor   // Purple
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 20

        // Create main CTA text
        let mainTextLayer = CATextLayer()
        let font = CTFontCreateWithName("HelveticaNeue-Black" as CFString, config.ctaFontSize * 1.4, nil)
        mainTextLayer.font = font
        mainTextLayer.fontSize = config.ctaFontSize * 1.4
        mainTextLayer.foregroundColor = UIColor.white.cgColor
        mainTextLayer.alignmentMode = .center
        mainTextLayer.contentsScale = screenScale
        mainTextLayer.isWrapped = true
        mainTextLayer.string = text

        // Debug: Ensure CTA text is being set
        print("[RenderPlanner] Creating CTA overlay with text: '\(text)'")
        print("[RenderPlanner] CTA main text layer string set to: '\(mainTextLayer.string ?? "nil")'")
        print("[RenderPlanner] CTA font size: \(mainTextLayer.fontSize)")

        // Calculate actual text dimensions using the font
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        let textSize = (text as NSString).size(withAttributes: textAttributes)
        let padding: CGFloat = 30 // Adequate padding for CTA
        let containerWidth = min(textSize.width + padding * 2, config.size.width - 60)
        let containerHeight = max(textSize.height + padding * 2, 80) // Minimum height for CTA

        print("[RenderPlanner] CTA calculated text size: \(textSize)")
        print("[RenderPlanner] CTA container size: \(CGSize(width: containerWidth, height: containerHeight))")

        // FIXED: Position CTA BELOW the logo with proper spacing
        let containerFrame = CGRect(
            x: (config.size.width - containerWidth) / 2,
            y: config.size.height * 0.55 - containerHeight / 2, // MOVED: 55% to be well below logo at 40%
            width: containerWidth,
            height: containerHeight
        )

        // Set up proper layer hierarchy for CTA
        ctaContainer.frame = containerFrame
        ctaContainer.opacity = 0.0  // Start invisible for fade in
        gradientLayer.frame = CGRect(origin: .zero, size: containerFrame.size)
        gradientLayer.opacity = 1.0
        mainTextLayer.frame = CGRect(
            x: padding,
            y: padding,
            width: containerFrame.width - padding * 2,
            height: textSize.height
        )
        mainTextLayer.opacity = 1.0

        // Add App Store badge below text
        let appStoreBadge = createAppStoreBadge(config: config, screenScale: screenScale)
        appStoreBadge.frame = CGRect(
            x: (containerFrame.width - 120) / 2,
            y: textSize.height + padding + 10,
            width: 120,
            height: 30
        )

        // Debug positioning
        print("[RenderPlanner] Logo container frame: \(logoContainer.frame)")
        print("[RenderPlanner] CTA container frame: \(ctaContainer.frame)")
        print("[RenderPlanner] CTA main text layer frame: \(mainTextLayer.frame)")

        // Enhanced shadow and glow for CTA
        gradientLayer.shadowColor = UIColor.magenta.cgColor
        gradientLayer.shadowOffset = CGSize(width: 0, height: 6)
        gradientLayer.shadowRadius = 15
        gradientLayer.shadowOpacity = 0.6

        // Add spark effects for CTA
        let ctaSparkEmitter = CAEmitterLayer()
        ctaSparkEmitter.emitterPosition = CGPoint(x: containerFrame.width / 2, y: containerFrame.height / 2)
        ctaSparkEmitter.emitterShape = .rectangle
        ctaSparkEmitter.emitterSize = CGSize(width: containerFrame.width, height: containerFrame.height)
        ctaSparkEmitter.zPosition = -1 // Behind text but in front of background

        // FIXED: Use food emojis for CTA sparks too
        let foodEmojis = ["🍕", "🍔", "🌮", "🥗", "🍜", "🍣", "🥘", "🍝"]
        var foodCells: [CAEmitterCell] = []

        for emoji in foodEmojis {
            let foodCell = CAEmitterCell()
            foodCell.contents = createFoodEmojiImage(emoji: emoji).cgImage
            foodCell.birthRate = 2.5 // Slightly higher rate for CTA
            foodCell.lifetime = 2.5
            foodCell.velocity = 60
            foodCell.velocityRange = 40
            foodCell.emissionRange = .pi * 2
            foodCell.yAcceleration = 100 // Strong gravity
            foodCell.scale = 0.9
            foodCell.scaleRange = 0.6
            foodCell.alphaSpeed = -0.4
            foodCell.spin = .pi * 1.5
            foodCell.spinRange = .pi
            foodCells.append(foodCell)
        }

        ctaSparkEmitter.emitterCells = foodCells

        // ANIMATIONS: Logo and CTA fade in together
        // Logo fade in animation (0-0.5s)
        let logoFadeIn = CABasicAnimation(keyPath: "opacity")
        logoFadeIn.fromValue = 0.0
        logoFadeIn.toValue = 1.0
        logoFadeIn.duration = 0.5
        logoFadeIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
        logoFadeIn.beginTime = AVCoreAnimationBeginTimeAtZero
        logoFadeIn.fillMode = .both
        logoFadeIn.isRemovedOnCompletion = false

        // CTA fade in animation (0.2s delay for stagger effect)
        let ctaFadeIn = CABasicAnimation(keyPath: "opacity")
        ctaFadeIn.fromValue = 0.0
        ctaFadeIn.toValue = 1.0
        ctaFadeIn.duration = 0.5
        ctaFadeIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ctaFadeIn.beginTime = AVCoreAnimationBeginTimeAtZero + 0.2
        ctaFadeIn.fillMode = .both
        ctaFadeIn.isRemovedOnCompletion = false

        // Start spark explosion when CTA fade-in completes (at 0.7s)
        let sparkStart = CABasicAnimation(keyPath: "birthRate")
        sparkStart.fromValue = 0
        sparkStart.toValue = 20
        sparkStart.duration = 0.1
        sparkStart.beginTime = AVCoreAnimationBeginTimeAtZero + 0.7
        sparkStart.fillMode = .both
        sparkStart.isRemovedOnCompletion = false

        // Attention-grabbing pulse animation for CTA
        let ctaPulse = CAKeyframeAnimation(keyPath: "transform.scale")
        ctaPulse.values = [1.0, 1.12, 1.0, 1.18, 1.0]
        ctaPulse.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        ctaPulse.duration = 1.2
        ctaPulse.repeatCount = 3 // Finite repeat for video composition
        ctaPulse.beginTime = AVCoreAnimationBeginTimeAtZero + 1.0 // Start after fade-in
        ctaPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        ctaPulse.fillMode = .both
        ctaPulse.isRemovedOnCompletion = false

        // Glow pulse with proper timing
        let glowPulse = CABasicAnimation(keyPath: "shadowRadius")
        glowPulse.fromValue = 15
        glowPulse.toValue = 30
        glowPulse.duration = 0.8
        glowPulse.autoreverses = true
        glowPulse.repeatCount = 4 // Finite repeat
        glowPulse.beginTime = AVCoreAnimationBeginTimeAtZero + 1.2
        glowPulse.fillMode = .both
        glowPulse.isRemovedOnCompletion = false

        // Assemble CTA layer hierarchy
        ctaContainer.addSublayer(gradientLayer)
        ctaContainer.addSublayer(ctaSparkEmitter) // Sparks behind CTA text
        ctaContainer.addSublayer(mainTextLayer)
        ctaContainer.addSublayer(appStoreBadge) // App Store badge

        // Apply animations
        logoContainer.add(logoFadeIn, forKey: "logoFadeIn")
        ctaContainer.add(ctaFadeIn, forKey: "ctaFadeIn")
        ctaContainer.add(ctaPulse, forKey: "ctaPulse")
        gradientLayer.add(glowPulse, forKey: "glowPulse")
        ctaSparkEmitter.add(sparkStart, forKey: "sparkStart")

        // Add both logo and CTA to main container
        container.addSublayer(logoContainer)
        container.addSublayer(ctaContainer)
        return container
    }

    // MARK: - Helper Functions for CTA

    /// Create large SnapChef logo with gradient and sparkles
    nonisolated private func createSnapChefLogo(config: RenderConfig, screenScale: CGFloat) -> CALayer {
        let container = CALayer()

        // Create gradient background with SnapChef viral colors: Pink → Purple → Cyan
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 0.98).cgColor,  // Pink #FF1493
            UIColor(red: 0.6, green: 0.196, blue: 0.8, alpha: 0.98).cgColor,  // Purple #9932CC
            UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.98).cgColor     // Cyan #00FFFF
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 25

        // Create "Get the SNAPCHEF! App!" text with 56pt heavy font (smaller to fit)
        let logoTextLayer = CATextLayer()
        let logoFont = CTFontCreateWithName("HelveticaNeue-Black" as CFString, 56, nil) // Reduced size for longer text
        logoTextLayer.font = logoFont
        logoTextLayer.fontSize = 56
        logoTextLayer.foregroundColor = UIColor.white.cgColor
        logoTextLayer.alignmentMode = .center
        logoTextLayer.contentsScale = screenScale
        logoTextLayer.string = "Get the SNAPCHEF! App!"

        // Calculate text dimensions
        let logoTextAttributes: [NSAttributedString.Key: Any] = [
            .font: logoFont
        ]
        let logoTextSize = ("Get the SNAPCHEF! App!" as NSString).size(withAttributes: logoTextAttributes)
        let logoPadding: CGFloat = 40 // Large padding for prominent logo
        let logoContainerWidth = logoTextSize.width + logoPadding * 2
        let logoContainerHeight = logoTextSize.height + logoPadding * 2

        // Set up layer frames
        container.frame = CGRect(origin: .zero, size: CGSize(width: logoContainerWidth, height: logoContainerHeight))
        gradientLayer.frame = container.bounds
        logoTextLayer.frame = CGRect(
            x: logoPadding,
            y: (logoContainerHeight - logoTextSize.height) / 2, // Center text vertically
            width: logoTextSize.width,
            height: logoTextSize.height
        )

        // Add dramatic shadow and glow effects
        gradientLayer.shadowColor = UIColor.cyan.cgColor
        gradientLayer.shadowOffset = CGSize(width: 0, height: 8)
        gradientLayer.shadowRadius = 25
        gradientLayer.shadowOpacity = 0.8

        // Additional text shadow for depth
        logoTextLayer.shadowColor = UIColor.black.cgColor
        logoTextLayer.shadowOffset = CGSize(width: 2, height: 2)
        logoTextLayer.shadowRadius = 4
        logoTextLayer.shadowOpacity = 0.5

        // Create sparkle effects around the logo
        let logoSparkEmitter = CAEmitterLayer()
        logoSparkEmitter.emitterPosition = CGPoint(x: logoContainerWidth / 2, y: logoContainerHeight / 2)
        logoSparkEmitter.emitterShape = .rectangle
        logoSparkEmitter.emitterSize = CGSize(width: logoContainerWidth * 1.4, height: logoContainerHeight * 1.4)
        logoSparkEmitter.zPosition = -1 // Behind text but in front of background

        // FIXED: Create multiple food emoji cells instead of sparkles
        let foodEmojis = ["🍕", "🍔", "🌮", "🥗", "🍜", "🍣", "🥘", "🍝"]
        var foodCells: [CAEmitterCell] = []

        for emoji in foodEmojis {
            let foodCell = CAEmitterCell()
            foodCell.contents = createFoodEmojiImage(emoji: emoji).cgImage
            foodCell.birthRate = 3 // Lower rate per emoji, but multiple emojis
            foodCell.lifetime = 3.0
            foodCell.velocity = 80
            foodCell.velocityRange = 50
            foodCell.emissionRange = .pi * 2
            foodCell.yAcceleration = 120 // Strong gravity for dynamic effect
            foodCell.scale = 1.2  // Larger food emojis
            foodCell.scaleRange = 0.8
            foodCell.alphaSpeed = -0.3
            foodCell.spin = .pi * 2
            foodCell.spinRange = .pi * 1.5
            foodCells.append(foodCell)
        }

        logoSparkEmitter.emitterCells = foodCells

        // Add pulsing animation for logo prominence
        let logoPulse = CABasicAnimation(keyPath: "transform.scale")
        logoPulse.fromValue = 1.0
        logoPulse.toValue = 1.08
        logoPulse.duration = 1.0
        logoPulse.autoreverses = true
        logoPulse.repeatCount = .greatestFiniteMagnitude
        logoPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // Gradient color cycling animation
        let colorCycle = CABasicAnimation(keyPath: "colors")
        colorCycle.fromValue = gradientLayer.colors
        colorCycle.toValue = [
            UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.98).cgColor,     // Cyan #00FFFF
            UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 0.98).cgColor,  // Pink #FF1493
            UIColor(red: 0.6, green: 0.196, blue: 0.8, alpha: 0.98).cgColor   // Purple #9932CC
        ]
        colorCycle.duration = 2.0
        colorCycle.autoreverses = true
        colorCycle.repeatCount = .greatestFiniteMagnitude

        // Assemble layer hierarchy
        container.addSublayer(gradientLayer)
        container.addSublayer(logoSparkEmitter) // Sparkles behind logo text
        container.addSublayer(logoTextLayer)

        // Apply animations
        container.add(logoPulse, forKey: "logoPulse")
        gradientLayer.add(colorCycle, forKey: "colorCycle")

        print("[RenderPlanner] Created SnapChef logo with size: \(container.frame.size)")
        return container
    }

    /// Create food emoji image for particle effects
    nonisolated private func createFoodEmojiImage(emoji: String) -> UIImage {
        let size = CGSize(width: 32, height: 32) // Larger size for emojis
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        // Create attributed string with the emoji
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28), // Large emoji size
            .foregroundColor: UIColor.black
        ]
        let attributedString = NSAttributedString(string: emoji, attributes: attributes)

        // Calculate centering position
        let textSize = attributedString.size()
        let drawPoint = CGPoint(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2
        )

        // Draw the emoji
        attributedString.draw(at: drawPoint)

        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }

    /// Create viral sparkle image for logo effects (kept as backup)
    nonisolated private func createViralSparkImage() -> UIImage {
        let size = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else {
            print("❌ Failed to get graphics context for viral spark")
            return UIImage()
        }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // Create viral sparkle with gradient colors
        let sparkColor = UIColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0) // Bright gold
        context.setFillColor(sparkColor.cgColor)

        // Draw a six-pointed star shape (more dramatic than four-pointed)
        context.beginPath()
        let radius: CGFloat = 7
        let innerRadius: CGFloat = 3

        for i in 0..<12 {
            let angle = CGFloat(i) * .pi / 6
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

        // Add a bright center with viral colors
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))

        // Add outer glow effect
        context.setFillColor(UIColor.cyan.withAlphaComponent(0.6).cgColor)
        context.fillEllipse(in: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16))

        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }

    /// Create gradient text layer for "SNAPCHEF!" with orange to pink gradient
    nonisolated private func createGradientTextLayer(_ text: String, font: CTFont, screenScale: CGFloat) -> CALayer {
        let container = CALayer()

        // Create gradient background for text
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1.0).cgColor, // #FF6B35
            UIColor(red: 1.0, green: 0.08, blue: 0.58, alpha: 1.0).cgColor  // #FF1493
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)

        // Create text layer as mask
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.font = font
        textLayer.fontSize = CTFontGetSize(font)
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = screenScale

        // Set frames
        let textSize = textLayer.preferredFrameSize()
        container.frame = CGRect(origin: .zero, size: textSize)
        gradientLayer.frame = container.bounds
        textLayer.frame = container.bounds

        // Apply text as mask to gradient
        gradientLayer.mask = textLayer

        container.addSublayer(gradientLayer)
        return container
    }

    /// Create App Store badge with icon
    nonisolated private func createAppStoreBadge(config: RenderConfig, screenScale: CGFloat) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: CGSize(width: 120, height: 30))

        // Background
        let background = CALayer()
        background.frame = container.bounds
        background.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
        background.cornerRadius = 15

        // App Store icon (simplified - square with rounded corners)
        let iconLayer = CALayer()
        iconLayer.frame = CGRect(x: 5, y: 5, width: 20, height: 20)
        iconLayer.backgroundColor = UIColor.systemBlue.cgColor
        iconLayer.cornerRadius = 4

        // Text
        let textLayer = CATextLayer()
        textLayer.string = "App Store"
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 12, nil)
        textLayer.fontSize = 12
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .left
        textLayer.contentsScale = screenScale
        textLayer.frame = CGRect(x: 30, y: 8, width: 85, height: 14)

        container.addSublayer(background)
        container.addSublayer(iconLayer)
        container.addSublayer(textLayer)

        return container
    }

    // MARK: - Helper Enums

    /// Slide direction for alternating text animations
    nonisolated private enum SlideDirection {
        case left, right
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
