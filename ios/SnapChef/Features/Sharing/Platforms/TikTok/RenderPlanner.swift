//
//  RenderPlanner.swift
//  SnapChef
//
//  Created on 12/01/2025
//  Render planner for creating template-specific render plans
//

import UIKit
import AVFoundation
import CoreImage
import CoreMedia
import CoreText

/// Creates RenderPlan for each template as specified in requirements
public actor RenderPlanner {  // Swift 6: Actor for isolated state
    
    private let config: RenderConfig
    
    public init(config: RenderConfig) {
        self.config = config
    }
    
    // MARK: - Beat Sync Support
    
    /// Get beat times for a given duration at 80 BPM
    private func getBeatTimes(duration: Double, bpm: Double = 80.0) -> [Double] {
        let beatInterval = 60.0 / bpm  // seconds per beat
        return stride(from: 0.0, to: duration, by: beatInterval).map { $0 }
    }
    
    /// Detect BPM from audio file (placeholder for real implementation)
    private func detectBPM(from url: URL) async -> Double {
        // TODO: Implement real BPM detection using AVAudioEngine
        // For now, return default 80 BPM
        // Real implementation would analyze audio onset detection
        return 80.0
    }
    
    // MARK: - Public Interface
    
    /// Create render plan for specified template
    public func createRenderPlan(
        template: ViralTemplate,
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        
        print("🎬 RenderPlanner: Creating render plan for template: \(template.rawValue)")
        print("🎬 RenderPlanner: Template description: \(template.description)")
        
        switch template {
        // Commented out templates - focusing on kinetic text only
        // case .beatSyncedCarousel:
        //     return try await createBeatSyncedCarouselPlan(recipe: recipe, media: media)
        // case .splitScreenSwipe:
        //     return try await createSplitScreenSwipePlan(recipe: recipe, media: media)
        case .kineticTextSteps:
            print("✅ RenderPlanner: Using KINETIC TEXT STEPS template")
            return try await createKineticTextStepsPlan(recipe: recipe, media: media)
        // case .priceTimeChallenge:
        //     return try await createPriceTimeChallengePlan(recipe: recipe, media: media)
        // case .greenScreenPIP:
        //     return try await createGreenScreenPIPPlan(recipe: recipe, media: media)
        // case .test:
        //     return try await createTestTemplatePlan(recipe: recipe, media: media)
        }
    }
    
    // MARK: - TD1 Agent Interface
    // Template Developer 1 methods as specified in TIKTOK_VIRAL_COMPLETE_REQUIREMENTS.md
    
    /// TEMPLATE 1: Beat-Synced Photo Carousel "Snap Reveal"
    /// Duration: 10-12 seconds
    /// Hook on blurred BEFORE (2s) with CIGaussianBlur radius 10
    /// Ingredient/meal snaps with Ken Burns effect (1.08x scale, alternating pan)
    /// Beat-aligned transitions (1s per snap if no music)
    /// Final CTA overlay
    public func planBeatSynced(
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        return try await createBeatSyncedCarouselPlan(recipe: recipe, media: media)
    }
    
    /// TEMPLATE 2: Split-Screen "Swipe" Before/After + Counters
    /// Duration: 9 seconds exactly
    /// BEFORE full screen (1.5s)
    /// AFTER masked reveal with circular wipe from center (1.5s)
    /// Ingredient counters animation (4s) with staggered appearance (150ms delay)
    /// End card with CTA (2s)
    public func planSplitSwipe(
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        return try await createSplitScreenSwipePlan(recipe: recipe, media: media)
    }
    
    /// TEMPLATE 3: Kinetic-Text "Recipe in 5 Steps"
    /// Duration: 15 seconds
    /// Hook overlay on BEFORE (2s)
    /// Animated step text overlays (max 6 steps, min 1.6s each)
    /// Background: looping motion between images or b-roll
    /// Steps shortened to 5-7 words max
    /// Auto-captioned for accessibility
    public func planKinetic(
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        return try await createKineticTextStepsPlan(recipe: recipe, media: media)
    }
    
    // MARK: - TD2 Agent Interface
    // Template Developer 2 methods as specified in TIKTOK_VIRAL_COMPLETE_REQUIREMENTS.md
    
    /// TEMPLATE 4: "Price & Time Challenge" Sticker Pack
    /// Duration: 12 seconds exactly
    /// BEFORE with sticker stack animation (1s + 2s overlap)
    /// Progress bar with b-roll or still (8s)
    /// AFTER with CTA (3s)
    /// Animated stickers for cost/time/calories
    /// Gradient progress bar animation
    public func planPriceTime(
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        return try await createPriceTimeChallengePlan(recipe: recipe, media: media)
    }
    
    /// TEMPLATE 5: Green-Screen "My Fridge → My Plate" (PIP)
    /// Duration: 15 seconds
    /// Picture-in-picture face overlay (340x340 circle)
    /// Base: BEFORE (3s) → B-ROLL/MEAL (6s) → AFTER (6s)
    /// Dynamic callouts for salvaged ingredients
    /// Face placeholder for future selfie integration
    /// PIP positioned top-right with shadow
    public func planGreenScreen(
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        return try await createGreenScreenPIPPlan(recipe: recipe, media: media)
    }
    
    // MARK: - Template 1: Beat-Synced Photo Carousel "Snap Reveal"
    // Duration: 10-12 seconds
    // Timeline: BEFORE (blurred) → ingredient snaps → cooked meal → AFTER
    
    private func createBeatSyncedCarouselPlan(
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        
        let totalDuration = CMTime(seconds: 11, preferredTimescale: 600)  // ViralTemplate.beatSyncedCarousel.duration
        var items: [RenderPlan.TrackItem] = []
        var overlays: [RenderPlan.Overlay] = []
        
        // Timeline breakdown:
        // 0-2s: Hook on blurred BEFORE
        // 2s-8s: Ingredient/meal snaps with Ken Burns (1.08x scale)
        // 8s-11s: Final CTA overlay
        
        // 1. BEFORE (blurred) - 2 seconds
        let blurredBefore = applyEnhancedBlurEffect(to: media.beforeFridge)
        items.append(RenderPlan.TrackItem(
            kind: .still(blurredBefore),
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 2, preferredTimescale: 600)
            ),
            transform: createKenBurnsTransform(index: 0),
            filters: []
        ))
        
        // 2. Ingredient snaps - 6 seconds total (distributed)
        let ingredientDuration = CMTime(seconds: 6, preferredTimescale: 600)
        let snapCount = min(recipe.ingredients.count, 4) // Max 4 ingredient snaps
        let snapDuration = CMTime(
            seconds: ingredientDuration.seconds / Double(snapCount),
            preferredTimescale: 600
        )
        
        for (index, _) in recipe.ingredients.prefix(snapCount).enumerated() {
            let startTime = CMTime(seconds: 2 + (Double(index) * snapDuration.seconds), preferredTimescale: 600)
            
            // Use cooked meal image for ingredient snaps (placeholder - would use actual ingredient photos)
            items.append(RenderPlan.TrackItem(
                kind: .still(media.cookedMeal),
                timeRange: CMTimeRange(start: startTime, duration: snapDuration),
                transform: createKenBurnsTransform(index: index + 1),
                filters: []
            ))
        }
        
        // 3. AFTER image - final 3 seconds
        let afterImage = applyColorPopEffect(to: media.cookedMeal)  // Use cookedMeal for after photo
        items.append(RenderPlan.TrackItem(
            kind: .still(afterImage),
            timeRange: CMTimeRange(
                start: CMTime(seconds: 8, preferredTimescale: 600),
                duration: CMTime(seconds: 3, preferredTimescale: 600)
            ),
            transform: createKenBurnsTransform(index: snapCount + 1),
            filters: []
        ))
        
        // Add overlays
        
        // Hook overlay (0-2s)
        overlays.append(RenderPlan.Overlay(
            start: .zero,
            duration: CMTime(seconds: 2, preferredTimescale: 600),
            layerBuilder: { config in
                return self.createHookOverlay(
                    text: CaptionGenerator.generateHook(from: recipe),
                    config: config
                )
            }
        ))
        
        // CTA overlay (8-11s)
        overlays.append(RenderPlan.Overlay(
            start: CMTime(seconds: 8, preferredTimescale: 600),
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            layerBuilder: { config in
                return self.createCTAOverlay(
                    text: CaptionGenerator.randomCTA(),
                    config: config
                )
            }
        ))
        
        return RenderPlan(
            items: items,
            overlays: overlays,
            audio: media.musicURL,
            outputDuration: totalDuration
        )
    }
    
    // MARK: - Template 2: Split-Screen "Swipe" Before/After + Counters
    // Duration: 9 seconds
    // Timeline: BEFORE full screen (1.5s) → AFTER masked reveal (1.5s) → ingredient counters (4s) → CTA (2s)
    
    private func createSplitScreenSwipePlan(
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        
        let totalDuration = CMTime(seconds: 9, preferredTimescale: 600)
        var items: [RenderPlan.TrackItem] = []
        var overlays: [RenderPlan.Overlay] = []
        
        // 1. BEFORE full screen (0-1.5s)
        items.append(RenderPlan.TrackItem(
            kind: .still(media.beforeFridge),
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 1.5, preferredTimescale: 600)
            )
        ))
        
        // 2. AFTER with circular wipe reveal (1.5-3s)
        let afterImage = applyColorPopEffect(to: media.cookedMeal)  // Use cookedMeal for after photo
        items.append(RenderPlan.TrackItem(
            kind: .still(afterImage),
            timeRange: CMTimeRange(
                start: CMTime(seconds: 1.5, preferredTimescale: 600),
                duration: CMTime(seconds: 1.5, preferredTimescale: 600)
            ),
            filters: [createCircularWipeFilter()]
        ))
        
        // 3. Background for counters (3-7s)
        items.append(RenderPlan.TrackItem(
            kind: .still(media.cookedMeal),
            timeRange: CMTimeRange(
                start: CMTime(seconds: 3, preferredTimescale: 600),
                duration: CMTime(seconds: 4, preferredTimescale: 600)
            )
        ))
        
        // 4. CTA background (7-9s)
        items.append(RenderPlan.TrackItem(
            kind: .still(afterImage),
            timeRange: CMTimeRange(
                start: CMTime(seconds: 7, preferredTimescale: 600),
                duration: CMTime(seconds: 2, preferredTimescale: 600)
            )
        ))
        
        // Add ingredient counter overlays (staggered appearance)
        let ingredients = CaptionGenerator.processIngredientText(recipe.ingredients)
        for (index, ingredient) in ingredients.enumerated() {
            let startTime = CMTime(
                seconds: 3 + (Double(index) * config.staggerDelay),
                preferredTimescale: 600
            )
            
            overlays.append(RenderPlan.Overlay(
                start: startTime,
                duration: CMTime(seconds: 4 - (Double(index) * config.staggerDelay), preferredTimescale: 600),
                layerBuilder: { config in
                    return self.createIngredientCounterOverlay(
                        text: ingredient,
                        index: index,
                        config: config
                    )
                }
            ))
        }
        
        // CTA overlay (7-9s)
        overlays.append(RenderPlan.Overlay(
            start: CMTime(seconds: 7, preferredTimescale: 600),
            duration: CMTime(seconds: 2, preferredTimescale: 600),
            layerBuilder: { config in
                return self.createCTAOverlay(
                    text: CaptionGenerator.randomCTA(),
                    config: config
                )
            }
        ))
        
        return RenderPlan(
            items: items,
            overlays: overlays,
            audio: media.musicURL,
            outputDuration: totalDuration
        )
    }
    
    // MARK: - Template 3: Kinetic-Text "Recipe in 5 Steps"
    // Duration: 15 seconds
    // Timeline: Hook overlay (2s) → animated step text (max 6 steps, 1.6s each minimum) → background motion
    
    private func createKineticTextStepsPlan(
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        let totalDuration = CMTime(seconds: 15, preferredTimescale: 600)
        var items: [RenderPlan.TrackItem] = []
        var overlays: [RenderPlan.Overlay] = []
        
        // PREMIUM FIX: Generate beat times for synced animations at 80 BPM
        let bpm: Double = 80.0
        let beatInterval = 60.0 / bpm  // 0.75 seconds per beat
        let beatTimes = stride(from: 0.0, to: 15.0, by: beatInterval).map { $0 }
        
        // Background segments with effects + transforms for movement
        let segments = [
            (image: media.beforeFridge, duration: CMTime(seconds: 3.5, preferredTimescale: 600), transform: createDimGlowTransform(), filters: createDimFilterSpecs()),
            (image: media.cookedMeal, duration: CMTime(seconds: 11.5, preferredTimescale: 600), transform: createCinematicZoomTransform(), filters: createCinematicFilterSpecs())
        ]
        var currentTime = CMTime.zero
        for segment in segments {
            items.append(RenderPlan.TrackItem(
                kind: .still(segment.image),
                timeRange: CMTimeRange(start: currentTime, duration: segment.duration),
                transform: segment.transform,
                filters: segment.filters
            ))
            currentTime = currentTime + segment.duration
        }
        
        // Hook overlay (0-3.5s) with beat-synced bounce
        let hookText = CaptionGenerator.generateHook(from: recipe)
        overlays.append(RenderPlan.Overlay(
            start: .zero,
            duration: CMTime(seconds: 3.5, preferredTimescale: 600),
            layerBuilder: { config in
                return self.createKineticStepOverlay(
                    text: "✨ \(hookText) ✨",
                    index: 0,
                    beatTime: 0.0,
                    config: config
                )
            }
        ))
        
        // PREMIUM FIX: Process steps with emoji formatting
        let processedSteps = recipe.steps.enumerated().map { index, step in
            CaptionGenerator.processStepText(step, index: index)
        }
        
        // Create beat-synced overlays for each step (3.5-12s)
        let stepsStartTime = 3.5
        for (index, stepText) in processedSteps.prefix(6).enumerated() {  // Max 6 steps
            let beatIndex = index + 4  // Start after hook (4th beat)
            if beatIndex < beatTimes.count {
                let startTime = CMTime(seconds: stepsStartTime + Double(index) * beatInterval, preferredTimescale: 600)
                let duration = CMTime(seconds: beatInterval, preferredTimescale: 600)
                
                overlays.append(RenderPlan.Overlay(
                    start: startTime,
                    duration: duration,
                    layerBuilder: { config in
                        return self.createKineticStepOverlay(
                            text: stepText,
                            index: index + 1,
                            beatTime: beatTimes[beatIndex],
                            config: config
                        )
                    }
                ))
            }
        }
        
        // CTA overlay (12-15s) with pulse animation
        let ctaText = CaptionGenerator.randomCTA()
        overlays.append(RenderPlan.Overlay(
            start: CMTime(seconds: 12, preferredTimescale: 600),
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            layerBuilder: { config in
                return self.createKineticStepOverlay(
                    text: "🔥 \(ctaText) 🔥",
                    index: 99,  // Special index for CTA
                    beatTime: 12.0,
                    config: config
                )
            }
        ))
        
        return RenderPlan(
            items: items,
            overlays: overlays,
            audio: media.musicURL,
            outputDuration: totalDuration
        )
    }
    
    // MARK: - Template 4: "Price & Time Challenge" Sticker Pack
    // Duration: 12 seconds exactly
    // Timeline: BEFORE with sticker stack animation (1s + 2s overlap) → progress bar with b-roll (8s) → AFTER with CTA (3s)
    
    private func createPriceTimeChallengePlan(
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        
        let totalDuration = CMTime(seconds: 12, preferredTimescale: 600)  // ViralTemplate.priceTimeChallenge.duration
        var items: [RenderPlan.TrackItem] = []
        var overlays: [RenderPlan.Overlay] = []
        
        // 1. BEFORE with sticker stack (0-3s) - EXACT requirement timing
        items.append(RenderPlan.TrackItem(
            kind: .still(media.beforeFridge),
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 3, preferredTimescale: 600)
            )
        ))
        
        // 2. Progress background - b-roll or cooked meal (3-11s) - 8 seconds as specified
        items.append(RenderPlan.TrackItem(
            kind: .still(media.cookedMeal),
            timeRange: CMTimeRange(
                start: CMTime(seconds: 3, preferredTimescale: 600),
                duration: CMTime(seconds: 8, preferredTimescale: 600)
            ),
            transform: createEnhancedKenBurnsTransform(index: 1)
        ))
        
        // 3. AFTER with CTA (11-12s) - Only 1 second overlap as per timeline
        let afterImage = applyEnhancedColorPopEffect(to: media.cookedMeal)  // Use cookedMeal for after photo
        items.append(RenderPlan.TrackItem(
            kind: .still(afterImage),
            timeRange: CMTimeRange(
                start: CMTime(seconds: 9, preferredTimescale: 600),
                duration: CMTime(seconds: 3, preferredTimescale: 600)
            )
        ))
        
        // STICKER STACK ANIMATION (1s + 2s overlap as specified)
        let stickers = createEnhancedStickerData(recipe: recipe)
        for (index, stickerData) in stickers.enumerated() {
            // Start at 1s with stagger delay for stack animation
            let startTime = CMTime(seconds: 1 + (Double(index) * 0.12), preferredTimescale: 600) // 120ms stagger
            
            overlays.append(RenderPlan.Overlay(
                start: startTime,
                duration: CMTime(seconds: 2, preferredTimescale: 600), // 2s overlap duration
                layerBuilder: { config in
                    return self.createAnimatedStickerOverlay(
                        stickerData: stickerData,
                        index: index,
                        config: config
                    )
                }
            ))
        }
        
        // GRADIENT PROGRESS BAR ANIMATION (3-11s) - 8 seconds as specified
        overlays.append(RenderPlan.Overlay(
            start: CMTime(seconds: 3, preferredTimescale: 600),
            duration: CMTime(seconds: 8, preferredTimescale: 600),
            layerBuilder: { config in
                return self.createGradientProgressBarOverlay(
                    recipe: recipe,
                    duration: 8.0,
                    config: config
                )
            }
        ))
        
        // CTA overlay (9-12s) - 3 seconds as specified
        overlays.append(RenderPlan.Overlay(
            start: CMTime(seconds: 9, preferredTimescale: 600),
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            layerBuilder: { config in
                return self.createEnhancedCTAOverlay(
                    text: CaptionGenerator.randomCTA(),
                    config: config
                )
            }
        ))
        
        return RenderPlan(
            items: items,
            overlays: overlays,
            audio: media.musicURL,
            outputDuration: totalDuration
        )
    }
    
    // MARK: - Template 5: Green-Screen "My Fridge → My Plate" (PIP)
    // Duration: 15 seconds
    // Timeline: BEFORE (3s) → B-ROLL/MEAL (6s) → AFTER (6s) with 340x340 PIP face overlay
    
    private func createGreenScreenPIPPlan(
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        
        let totalDuration = CMTime(seconds: 15, preferredTimescale: 600)  // ViralTemplate.greenScreenPIP.duration
        var items: [RenderPlan.TrackItem] = []
        var overlays: [RenderPlan.Overlay] = []
        
        // 1. BEFORE (0-3s) - EXACT timing as specified
        items.append(RenderPlan.TrackItem(
            kind: .still(media.beforeFridge),
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 3, preferredTimescale: 600)
            )
        ))
        
        // 2. B-ROLL/MEAL (3-9s) - 6 seconds as specified
        items.append(RenderPlan.TrackItem(
            kind: .still(media.cookedMeal),
            timeRange: CMTimeRange(
                start: CMTime(seconds: 3, preferredTimescale: 600),
                duration: CMTime(seconds: 6, preferredTimescale: 600)
            ),
            transform: createEnhancedKenBurnsTransform(index: 1)
        ))
        
        // 3. AFTER (9-15s) - 6 seconds as specified with color pop
        let afterImage = applyEnhancedColorPopEffect(to: media.cookedMeal)  // Use cookedMeal for after photo
        items.append(RenderPlan.TrackItem(
            kind: .still(afterImage),
            timeRange: CMTimeRange(
                start: CMTime(seconds: 9, preferredTimescale: 600),
                duration: CMTime(seconds: 6, preferredTimescale: 600)
            )
        ))
        
        // PIP FACE OVERLAY (340x340 circle, top-right with shadow) - ENTIRE DURATION
        overlays.append(RenderPlan.Overlay(
            start: .zero,
            duration: totalDuration,
            layerBuilder: { config in
                return self.createPIPFaceOverlay340x340(config: config)
            }
        ))
        
        // DYNAMIC CALLOUTS for salvaged ingredients - positioned to avoid PIP
        let ingredients = CaptionGenerator.processIngredientText(recipe.ingredients)
        for (index, ingredient) in ingredients.prefix(3).enumerated() {
            // Distribute throughout B-ROLL section (3-9s)
            let startTime = CMTime(seconds: 4 + (Double(index) * 1.5), preferredTimescale: 600)
            
            overlays.append(RenderPlan.Overlay(
                start: startTime,
                duration: CMTime(seconds: 1.5, preferredTimescale: 600),
                layerBuilder: { config in
                    return self.createSalvagedIngredientCallout(
                        text: "✓ \(ingredient)",
                        index: index,
                        config: config
                    )
                }
            ))
        }
        
        // "My Fridge → My Plate" title overlay (0-3s during BEFORE)
        overlays.append(RenderPlan.Overlay(
            start: .zero,
            duration: CMTime(seconds: 3, preferredTimescale: 600),
            layerBuilder: { config in
                return self.createGreenScreenTitleOverlay(
                    text: "My Fridge → My Plate",
                    config: config
                )
            }
        ))
        
        return RenderPlan(
            items: items,
            overlays: overlays,
            audio: media.musicURL,
            outputDuration: totalDuration
        )
    }
    
    // MARK: - Enhanced Visual Effects System
    // Implementing all effects from TIKTOK_VIRAL_COMPLETE_REQUIREMENTS.md
    
    /// Enhanced Ken Burns Effect with EXACT specifications
    /// Scale: 1.08x, Direction: Alternating (index % 2), Translation: ±2% of size
    private func createEnhancedKenBurnsTransform(index: Int) -> CGAffineTransform {
        let scale: CGFloat = 1.08 // EXACT specification from requirements
        let direction: CGFloat = index % 2 == 0 ? 1.0 : -1.0 // Alternating direction
        let translation = config.size.width * 0.02 * direction // ±2% translation
        
        return CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: translation, y: 0)
    }
    
    /// Legacy Ken Burns for backward compatibility
    private func createKenBurnsTransform(index: Int) -> CGAffineTransform {
        return createEnhancedKenBurnsTransform(index: index)
    }
    
    /// Enhanced Color Pop Effect (AFTER images only)
    /// Contrast: +0.1, Saturation: +0.08, Apply via CIColorControls filter
    private func applyEnhancedColorPopEffect(to image: UIImage) -> UIImage {
        // First ensure we have a CGImage to work with
        guard let cgImage = image.cgImage ?? CIContext().createCGImage(CIImage(image: image)!, from: CIImage(image: image)!.extent) else {
            print("⚠️ RenderPlanner: Failed to get CGImage for color pop effect")
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        let colorFilter = CIFilter(name: "CIColorControls")!
        colorFilter.setValue(ciImage, forKey: kCIInputImageKey)
        colorFilter.setValue(1.1, forKey: "inputContrast")    // +0.1 contrast as specified
        colorFilter.setValue(1.08, forKey: "inputSaturation") // +0.08 saturation as specified
        
        guard let outputImage = colorFilter.outputImage,
              let outputCGImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            print("⚠️ RenderPlanner: Failed to apply color pop effect")
            return image
        }
        
        let result = UIImage(cgImage: outputCGImage)
        print("✅ RenderPlanner: Applied color pop effect - has CGImage: \(result.cgImage != nil)")
        return result
    }
    
    /// Legacy Color Pop for backward compatibility
    private func applyColorPopEffect(to image: UIImage) -> UIImage {
        return applyEnhancedColorPopEffect(to: image)
    }
    
    /// Enhanced Blur Effect (BEFORE hook)
    /// Filter: CIGaussianBlur, Radius: 10
    private func applyEnhancedBlurEffect(to image: UIImage) -> UIImage {
        // First ensure we have a CGImage to work with
        guard let cgImage = image.cgImage ?? CIContext().createCGImage(CIImage(image: image)!, from: CIImage(image: image)!.extent) else {
            print("⚠️ RenderPlanner: Failed to get CGImage for blur effect")
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(3, forKey: "inputRadius") // Reduced from 10 - more subtle blur
        
        // Need to crop the output to original extent since blur expands the image
        let originalExtent = ciImage.extent
        guard let outputImage = blurFilter.outputImage?.cropped(to: originalExtent),
              let outputCGImage = CIContext().createCGImage(outputImage, from: originalExtent) else {
            print("⚠️ RenderPlanner: Failed to apply blur effect")
            return image
        }
        
        let result = UIImage(cgImage: outputCGImage)
        print("✅ RenderPlanner: Applied blur effect - has CGImage: \(result.cgImage != nil)")
        return result
    }
    
    /// Legacy Blur for backward compatibility
    private func applyBlurEffect(to image: UIImage) -> UIImage {
        return applyEnhancedBlurEffect(to: image)
    }
    
    private func createCircularWipeFilter() -> FilterSpec {
        // Placeholder for circular wipe mask filter
        return FilterSpec(name: "CIColorMatrix", params: [:])
    }
    
    // MARK: - Enhanced Data Creation Methods for Template 4 & 5
    
    /// Enhanced sticker data creation for Template 4
    private func createEnhancedStickerData(recipe: ViralRecipe) -> [(text: String, color: UIColor, icon: String)] {
        var stickers: [(String, UIColor, String)] = []
        
        if let time = recipe.timeMinutes {
            stickers.append(("\(time) MIN", .systemBlue, "⏱️"))
        }
        
        if let cost = recipe.costDollars {
            stickers.append(("$\(cost)", .systemGreen, "💰"))
        }
        
        if let calories = recipe.calories {
            stickers.append(("\(calories) CAL", .systemOrange, "🔥"))
        }
        
        return stickers
    }
    
    /// Legacy sticker data for backward compatibility
    private func createStickerData(recipe: ViralRecipe) -> [(text: String, color: UIColor)] {
        return createEnhancedStickerData(recipe: recipe).map { (text: $0.text, color: $0.color) }
    }
    
    // MARK: - Enhanced Overlay Creation Methods for Templates 4 & 5
    
    /// Enhanced animated sticker overlay for Template 4 with pop animation
    private func createAnimatedStickerOverlay(
        stickerData: (text: String, color: UIColor, icon: String), 
        index: Int, 
        config: RenderConfig
    ) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Sticker background with rounded corners
        let stickerLayer = CALayer()
        let stickerSize = CGSize(width: 120, height: 60)
        let xPosition = config.safeInsets.left + CGFloat(index * 140) // Staggered horizontal positioning
        let yPosition = config.size.height - config.safeInsets.bottom - 100
        
        stickerLayer.frame = CGRect(
            x: xPosition,
            y: yPosition,
            width: stickerSize.width,
            height: stickerSize.height
        )
        stickerLayer.backgroundColor = stickerData.color.withAlphaComponent(0.9).cgColor
        stickerLayer.cornerRadius = 30
        
        // Add shadow
        stickerLayer.shadowColor = UIColor.black.cgColor
        stickerLayer.shadowOffset = CGSize(width: 0, height: 4)
        stickerLayer.shadowOpacity = 0.3
        stickerLayer.shadowRadius = 8
        
        // Icon layer
        let iconLayer = CATextLayer()
        iconLayer.string = stickerData.icon
        iconLayer.fontSize = 20
        iconLayer.frame = CGRect(x: 10, y: 15, width: 30, height: 30)
        iconLayer.alignmentMode = .center
        stickerLayer.addSublayer(iconLayer)
        
        // Text layer
        let textLayer = CATextLayer()
        textLayer.string = stickerData.text
        textLayer.fontSize = 16
        if let font = UIFont(name: config.fontNameBold, size: 16) {
            textLayer.font = CTFontCreateWithName(font.fontName as CFString, 16, nil)
        }
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.frame = CGRect(x: 40, y: 20, width: 70, height: 20)
        textLayer.alignmentMode = .center
        stickerLayer.addSublayer(textLayer)
        
        // Pop animation - Spring with scale 0.6→1.0 as specified
        let scaleAnimation = CASpringAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.6 // From config.scaleRange
        scaleAnimation.toValue = 1.0   // To config.scaleRange
        scaleAnimation.damping = config.springDamping // 12-14 for pop animations
        scaleAnimation.duration = 0.6
        scaleAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + Double(index) * 0.12 // 120ms stagger
        stickerLayer.add(scaleAnimation, forKey: "stickerPop")
        
        containerLayer.addSublayer(stickerLayer)
        return containerLayer
    }
    
    /// Enhanced gradient progress bar overlay for Template 4
    private func createGradientProgressBarOverlay(
        recipe: ViralRecipe, 
        duration: TimeInterval,
        config: RenderConfig
    ) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Progress bar background
        let progressBgLayer = CALayer()
        let barWidth = config.size.width - (config.safeInsets.left + config.safeInsets.right)
        let barHeight: CGFloat = 8
        
        progressBgLayer.frame = CGRect(
            x: config.safeInsets.left,
            y: config.size.height - config.safeInsets.bottom - 60,
            width: barWidth,
            height: barHeight
        )
        progressBgLayer.backgroundColor = UIColor.white.withAlphaComponent(0.3).cgColor
        progressBgLayer.cornerRadius = barHeight / 2
        
        // Gradient progress bar
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 0, height: barHeight)
        gradientLayer.colors = [
            UIColor.systemBlue.cgColor,
            UIColor.systemPurple.cgColor,
            UIColor.systemPink.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerRadius = barHeight / 2
        
        // Animation - Linear fill over 8 seconds as specified
        let widthAnimation = CABasicAnimation(keyPath: "bounds.size.width")
        widthAnimation.fromValue = 0
        widthAnimation.toValue = barWidth
        widthAnimation.duration = duration
        widthAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        gradientLayer.add(widthAnimation, forKey: "progressFill")
        
        progressBgLayer.addSublayer(gradientLayer)
        containerLayer.addSublayer(progressBgLayer)
        
        return containerLayer
    }
    
    /// Enhanced 340x340 PIP face overlay for Template 5 with shadow
    private func createPIPFaceOverlay340x340(config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // PIP face circle - EXACT 340x340 as specified, positioned top-right
        let faceLayer = CAShapeLayer()
        let diameter: CGFloat = 340 // EXACT specification
        let margin: CGFloat = 20
        
        let faceFrame = CGRect(
            x: config.size.width - diameter - margin - config.safeInsets.right,
            y: config.safeInsets.top + margin,
            width: diameter,
            height: diameter
        )
        
        faceLayer.frame = faceFrame
        faceLayer.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))).cgPath
        
        // Face placeholder with gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(origin: .zero, size: CGSize(width: diameter, height: diameter))
        gradientLayer.colors = [
            UIColor.systemGray4.cgColor,
            UIColor.systemGray5.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.mask = faceLayer
        
        // Shadow as specified
        faceLayer.shadowColor = UIColor.black.cgColor
        faceLayer.shadowOffset = CGSize(width: 0, height: 8)
        faceLayer.shadowOpacity = 0.25
        faceLayer.shadowRadius = 12
        
        // Face placeholder icon
        let faceIconLayer = CATextLayer()
        faceIconLayer.string = "👤"
        faceIconLayer.fontSize = 120
        faceIconLayer.frame = CGRect(
            x: (diameter - 120) / 2,
            y: (diameter - 120) / 2,
            width: 120,
            height: 120
        )
        faceIconLayer.alignmentMode = .center
        
        faceLayer.fillColor = UIColor.systemGray4.cgColor
        containerLayer.addSublayer(faceLayer)
        containerLayer.addSublayer(faceIconLayer)
        
        return containerLayer
    }
    
    /// Enhanced salvaged ingredient callout for Template 5
    private func createSalvagedIngredientCallout(
        text: String, 
        index: Int, 
        config: RenderConfig
    ) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Position callouts on left side to avoid PIP (which is on right)
        let calloutWidth: CGFloat = 200
        let calloutHeight: CGFloat = 40
        let xPosition = config.safeInsets.left + 20
        let yPosition = config.safeInsets.top + 200 + CGFloat(index * 60)
        
        // Callout background
        let bgLayer = CALayer()
        bgLayer.frame = CGRect(
            x: xPosition,
            y: yPosition,
            width: calloutWidth,
            height: calloutHeight
        )
        bgLayer.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9).cgColor
        bgLayer.cornerRadius = 20
        
        // Shadow
        bgLayer.shadowColor = UIColor.black.cgColor
        bgLayer.shadowOffset = CGSize(width: 0, height: 2)
        bgLayer.shadowOpacity = 0.3
        bgLayer.shadowRadius = 4
        
        // Text layer
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.fontSize = config.ingredientFontSize
        if let font = UIFont(name: config.fontNameBold, size: config.ingredientFontSize) {
            textLayer.font = CTFontCreateWithName(font.fontName as CFString, config.ingredientFontSize, nil)
        }
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.frame = CGRect(x: 15, y: 8, width: calloutWidth - 30, height: 24)
        textLayer.alignmentMode = .left
        
        // Drop animation as specified (0.5s with Y+50 offset)
        let dropAnimation = CABasicAnimation(keyPath: "transform.translation.y")
        dropAnimation.fromValue = -50
        dropAnimation.toValue = 0
        dropAnimation.duration = 0.5
        dropAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        bgLayer.add(dropAnimation, forKey: "ingredientDrop")
        
        bgLayer.addSublayer(textLayer)
        containerLayer.addSublayer(bgLayer)
        
        return containerLayer
    }
    
    /// Enhanced green screen title overlay for Template 5
    private func createGreenScreenTitleOverlay(text: String, config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Title positioning - centered but avoiding PIP area
        let titleLayer = CATextLayer()
        titleLayer.string = text
        titleLayer.fontSize = config.hookFontSize
        if let font = UIFont(name: config.fontNameBold, size: titleLayer.fontSize) {
            titleLayer.font = CTFontCreateWithName(font.fontName as CFString, titleLayer.fontSize, nil)
        }
        titleLayer.foregroundColor = UIColor.white.cgColor
        
        // Text stroke/shadow for readability
        titleLayer.shadowColor = config.brandShadow.cgColor
        titleLayer.shadowOffset = CGSize(width: 0, height: 4)
        titleLayer.shadowOpacity = 1.0
        titleLayer.shadowRadius = 0
        
        let textSize = text.size(withAttributes: [
            .font: UIFont.systemFont(ofSize: config.hookFontSize, weight: .bold)
        ])
        
        titleLayer.frame = CGRect(
            x: config.safeInsets.left,
            y: config.safeInsets.top + 50,
            width: config.size.width - config.safeInsets.left - config.safeInsets.right - 360, // Avoid PIP
            height: textSize.height
        )
        
        // Fade in animation
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0
        fadeAnimation.toValue = 1
        fadeAnimation.duration = config.fadeDuration
        titleLayer.add(fadeAnimation, forKey: "titleFadeIn")
        
        containerLayer.addSublayer(titleLayer)
        return containerLayer
    }
    
    /// Enhanced CTA overlay with rounded sticker styling
    private func createEnhancedCTAOverlay(text: String, config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // CTA sticker background
        let textSize = text.size(withAttributes: [
            .font: UIFont.systemFont(ofSize: config.ctaFontSize, weight: .bold)
        ])
        
        let padding: CGFloat = 40  // More padding for larger text
        let stickerWidth = textSize.width + (padding * 2)
        let stickerHeight: CGFloat = 140  // DOUBLED: Was 60, now tall enough for text
        
        let stickerLayer = CALayer()
        stickerLayer.frame = CGRect(
            x: (config.size.width - stickerWidth) / 2,
            y: config.size.height - config.safeInsets.bottom - 80,
            width: stickerWidth,
            height: stickerHeight
        )
        stickerLayer.backgroundColor = UIColor.systemBlue.cgColor
        stickerLayer.cornerRadius = stickerHeight / 2
        
        // Shadow
        stickerLayer.shadowColor = UIColor.black.cgColor
        stickerLayer.shadowOffset = CGSize(width: 0, height: 4)
        stickerLayer.shadowOpacity = 0.3
        stickerLayer.shadowRadius = 8
        
        // Text
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.fontSize = config.ctaFontSize
        if let font = UIFont(name: config.fontNameBold, size: config.ctaFontSize) {
            textLayer.font = CTFontCreateWithName(font.fontName as CFString, config.ctaFontSize, nil)
        }
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.frame = CGRect(x: padding, y: padding / 2, width: stickerWidth - padding * 2, height: stickerHeight - padding)
        textLayer.alignmentMode = .center
        
        // CTA pop animation
        let scaleAnimation = CASpringAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.6
        scaleAnimation.toValue = 1.0
        scaleAnimation.damping = config.springDamping
        scaleAnimation.duration = 0.6
        stickerLayer.add(scaleAnimation, forKey: "ctaPop")
        
        stickerLayer.addSublayer(textLayer)
        containerLayer.addSublayer(stickerLayer)
        
        return containerLayer
    }
    
    // MARK: - Legacy Overlay Methods (Stub implementations for backward compatibility)
    
    private func createHookOverlay(text: String, config: RenderConfig) -> CALayer {
        // Stub implementation - will be moved to OverlayFactory
        let layer = CATextLayer()
        layer.string = text
        return layer
    }
    
    private func createCTAOverlay(text: String, config: RenderConfig) -> CALayer {
        return createEnhancedCTAOverlay(text: text, config: config)
    }
    
    private func createIngredientCounterOverlay(text: String, index: Int, config: RenderConfig) -> CALayer {
        // Stub implementation - will be moved to OverlayFactory
        let layer = CATextLayer()
        layer.string = text
        return layer
    }
    
    private func createKineticStepOverlay(text: String, index: Int, config: RenderConfig) -> CALayer {
        // Forward to beat-synced version with default beat time
        return createKineticStepOverlay(text: text, index: index, beatTime: 0.0, config: config)
    }
    
    // PREMIUM FIX: New beat-synced overlay creator
    private func createKineticStepOverlay(text: String, index: Int, beatTime: Double, config: RenderConfig) -> CALayer {
        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: config.size)
        
        // Calculate wrapped text dimensions
        let maxTextWidth = config.size.width - 200  // Allow for margins
        let font = UIFont.systemFont(ofSize: config.stepsFontSize, weight: .bold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        // Calculate the actual size needed for wrapped text
        let textSize = text.boundingRect(
            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).size
        
        // Background with gradient
        let bgLayer = CAGradientLayer()
        let padding: CGFloat = 40  // Padding on all sides
        let bgWidth = min(config.size.width - 100, textSize.width + padding * 2)
        let bgHeight = max(180, textSize.height + padding * 2)  // Dynamic height, minimum 180
        
        // Center horizontally, position vertically based on index
        let yPosition = config.safeInsets.top + 100 + CGFloat(index % 3) * 100
        
        bgLayer.frame = CGRect(
            x: (config.size.width - bgWidth) / 2,
            y: yPosition,
            width: bgWidth,
            height: bgHeight
        )
        
        // Premium gradient colors
        if index == 99 {  // CTA special styling
            bgLayer.colors = [
                UIColor.systemOrange.cgColor,
                UIColor.systemRed.cgColor
            ]
        } else if index == 0 {  // Hook special styling
            bgLayer.colors = [
                UIColor.systemPurple.cgColor,
                UIColor.systemIndigo.cgColor
            ]
        } else {  // Step styling
            bgLayer.colors = [
                UIColor.systemBlue.cgColor,
                UIColor.systemTeal.cgColor
            ]
        }
        
        bgLayer.startPoint = CGPoint(x: 0, y: 0.5)
        bgLayer.endPoint = CGPoint(x: 1, y: 0.5)
        bgLayer.cornerRadius = bgHeight / 2
        
        // Shadow
        bgLayer.shadowColor = UIColor.black.cgColor
        bgLayer.shadowOffset = CGSize(width: 0, height: 4)
        bgLayer.shadowOpacity = 0.3
        bgLayer.shadowRadius = 8
        
        // Text layer with proper wrapping using NSAttributedString
        let textLayer = CATextLayer()
        
        // Create attributed string for proper text wrapping
        let textParagraphStyle = NSMutableParagraphStyle()
        textParagraphStyle.lineBreakMode = .byWordWrapping
        textParagraphStyle.alignment = .center
        
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: config.stepsFontSize, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: textParagraphStyle
            ]
        )
        
        textLayer.string = attributedString
        textLayer.frame = CGRect(
            x: padding / 2,
            y: padding / 2,
            width: bgWidth - padding,
            height: bgHeight - padding
        )
        textLayer.alignmentMode = .center
        textLayer.isWrapped = true
        textLayer.truncationMode = .none  // Don't truncate
        textLayer.contentsScale = 2.0  // Use standard retina scale
        
        // PREMIUM FIX: Beat-synced animations with props set before add
        if beatTime > 0 {
            // Slide in from side
            let slideAnimation = CABasicAnimation(keyPath: "transform.translation.x")
            slideAnimation.fromValue = index % 2 == 0 ? -config.size.width : config.size.width
            slideAnimation.toValue = 0
            slideAnimation.duration = 0.3
            slideAnimation.beginTime = AVCoreAnimationBeginTimeAtZero
            slideAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            slideAnimation.fillMode = .forwards  // PREMIUM FIX: Set before add
            slideAnimation.isRemovedOnCompletion = false  // PREMIUM FIX: Set before add
            bgLayer.add(slideAnimation, forKey: "slideIn")
            
            // Scale pop
            let scaleAnimation = CASpringAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 0.8
            scaleAnimation.toValue = 1.0
            scaleAnimation.damping = 10
            scaleAnimation.duration = 0.4
            scaleAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + 0.1
            scaleAnimation.fillMode = .forwards  // PREMIUM FIX: Set before add
            scaleAnimation.isRemovedOnCompletion = false  // PREMIUM FIX: Set before add
            bgLayer.add(scaleAnimation, forKey: "scalePop")
            
            // Pulse for CTA
            if index == 99 {
                let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                pulseAnimation.fromValue = 1.0
                pulseAnimation.toValue = 1.05
                pulseAnimation.duration = 0.75  // Match beat interval
                pulseAnimation.autoreverses = true
                pulseAnimation.repeatCount = .infinity
                pulseAnimation.beginTime = AVCoreAnimationBeginTimeAtZero + 0.5
                pulseAnimation.fillMode = .forwards  // PREMIUM FIX: Set before add
                pulseAnimation.isRemovedOnCompletion = false  // PREMIUM FIX: Set before add
                bgLayer.add(pulseAnimation, forKey: "pulse")
            }
        }
        
        bgLayer.addSublayer(textLayer)
        containerLayer.addSublayer(bgLayer)
        
        return containerLayer
    }
    
    private func createStickerOverlay(stickerData: (text: String, color: UIColor), index: Int, config: RenderConfig) -> CALayer {
        // Convert legacy format to enhanced format
        let enhanced = (text: stickerData.text, color: stickerData.color, icon: "⭐")
        return createAnimatedStickerOverlay(stickerData: enhanced, index: index, config: config)
    }
    
    private func createProgressBarOverlay(recipe: ViralRecipe, config: RenderConfig) -> CALayer {
        return createGradientProgressBarOverlay(recipe: recipe, duration: 5.0, config: config)
    }
    
    private func createPIPFaceOverlay(config: RenderConfig) -> CALayer {
        return createPIPFaceOverlay340x340(config: config)
    }
    
    // PREMIUM FIX: New method with beat times array for multiple pops
    private func createKineticStepOverlay(text: String, config: RenderConfig, fontSize: CGFloat, beatTimes: [Double]) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: config.size.width, height: config.size.height)
        
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.frame = layer.bounds.inset(by: config.safeInsets)
        textLayer.contentsScale = 2.0  // Use standard retina scale
        
        // Beat-synced pop group
        let group = CAAnimationGroup()
        group.duration = config.fadeDuration
        group.beginTime = AVCoreAnimationBeginTimeAtZero  // PREMIUM FIX: Set before add
        group.fillMode = .forwards  // PREMIUM FIX: Set before add
        group.isRemovedOnCompletion = false  // PREMIUM FIX: Set before add
        
        var pops: [CAAnimation] = []
        for beat in beatTimes {
            let pop = CASpringAnimation(keyPath: "transform.scale")
            pop.fromValue = 1.0
            pop.toValue = 1.2
            pop.stiffness = 100
            pop.damping = 10
            pop.duration = 0.2
            pop.beginTime = beat  // Relative to group
            pop.fillMode = .forwards  // PREMIUM FIX: Set before add
            pop.isRemovedOnCompletion = false  // PREMIUM FIX: Set before add
            pops.append(pop)
        }
        group.animations = pops
        
        textLayer.add(group, forKey: "kineticPop")  // Add after setting all props
        layer.addSublayer(textLayer)
        
        return layer
    }
    
    private func createIngredientCalloutOverlay(text: String, index: Int, config: RenderConfig) -> CALayer {
        return createSalvagedIngredientCallout(text: text, index: index, config: config)
    }
    
    // MARK: - Test Template Plan
    
    private func createTestTemplatePlan(
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        
        let totalDuration = CMTime(seconds: 2, preferredTimescale: 600)  // ViralTemplate.test.duration
        var items: [RenderPlan.TrackItem] = []
        
        print("🧪 TEST TEMPLATE: Creating render plan")
        print("    - beforeFridge: \(media.beforeFridge.size)")
        print("    - cookedMeal: \(media.cookedMeal.size)")
        
        // 1. BEFORE photo (0-1s) - Fridge photo, no effects
        items.append(RenderPlan.TrackItem(
            kind: .still(media.beforeFridge),
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 1, preferredTimescale: 600)
            ),
            transform: .identity,
            filters: []  // No filters
        ))
        
        // 2. AFTER photo (1-2s) - Cooked meal photo, no effects
        items.append(RenderPlan.TrackItem(
            kind: .still(media.cookedMeal),  // Use cookedMeal, not afterFridge
            timeRange: CMTimeRange(
                start: CMTime(seconds: 1, preferredTimescale: 600),
                duration: CMTime(seconds: 1, preferredTimescale: 600)
            ),
            transform: .identity,
            filters: []  // No filters
        ))
        
        print("🧪 TEST TEMPLATE: Render plan created with \(items.count) items")
        
        // No overlays, no audio, no effects - just the photos
        return RenderPlan(
            items: items,
            overlays: [],  // No overlays
            audio: nil,    // No audio
            outputDuration: totalDuration,
            pip: nil       // No PIP
        )
    }
    
    // MARK: - Cinematic Transform Functions
    
    private func createDimGlowTransform() -> CGAffineTransform {
        // Subtle scale and pan for dramatic effect on fridge photo
        return CGAffineTransform(scaleX: 1.05, y: 1.05)
            .translatedBy(x: -10, y: -10)
    }
    
    private func createCinematicZoomTransform() -> CGAffineTransform {
        // Dramatic zoom in for meal reveal
        return CGAffineTransform(scaleX: 1.2, y: 1.2)
            .translatedBy(x: 20, y: 15)
    }
    
    // MARK: - Visual Effect Filters
    
    private func createDimFilterSpecs() -> [FilterSpec] {
        var filters: [FilterSpec] = []
        
        // Gaussian blur for dreamy effect
        filters.append(FilterSpec(
            name: "CIGaussianBlur",
            params: ["inputRadius": AnyCodable(5.0)]
        ))
        
        // REMOVED: Brightness dimming that was darkening images
        
        return filters
    }
    
    private func createCinematicFilterSpecs() -> [FilterSpec] {
        var filters: [FilterSpec] = []
        
        // REMOVED: Bloom filter that was affecting visibility
        
        // REMOVED: Vibrance filter
        
        // REMOVED: Sharpen filter
        
        // REMOVED: Vignette filter that was darkening edges
        
        return filters
    }
    
    // MARK: - Premium Overlay Creation Methods
    
    private func createPremiumHookOverlay(text: String, config: RenderConfig, fontSize: CGFloat) -> CALayer {
        let overlayFactory = OverlayFactory(config: config)
        return overlayFactory.createPremiumHookOverlay(text: text, config: config, fontSize: fontSize)
    }
    
    private func createCarouselItemOverlay(text: String, index: Int, config: RenderConfig, fontSize: CGFloat) -> CALayer {
        let overlayFactory = OverlayFactory(config: config)
        return overlayFactory.createCarouselItemOverlay(text: text, index: index, config: config, fontSize: fontSize)
    }
    
    private func createCinematicRevealOverlay(text: String, config: RenderConfig) -> CALayer {
        let overlayFactory = OverlayFactory(config: config)
        return overlayFactory.createCinematicRevealOverlay(text: text, config: config)
    }
    
    private func createPremiumCTAOverlay(text: String, config: RenderConfig, fontSize: CGFloat) -> CALayer {
        let overlayFactory = OverlayFactory(config: config)
        return overlayFactory.createPremiumCTAOverlay(text: text, config: config, fontSize: fontSize)
    }
}