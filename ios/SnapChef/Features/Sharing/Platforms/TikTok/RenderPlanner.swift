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
public final class RenderPlanner: @unchecked Sendable {
    
    private let config: RenderConfig
    
    public init(config: RenderConfig) {
        self.config = config
    }
    
    // MARK: - Public Interface
    
    /// Create render plan for specified template
    public func createRenderPlan(
        template: ViralTemplate,
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RenderPlan {
        
        switch template {
        // Commented out templates - focusing on kinetic text only
        // case .beatSyncedCarousel:
        //     return try await createBeatSyncedCarouselPlan(recipe: recipe, media: media)
        // case .splitScreenSwipe:
        //     return try await createSplitScreenSwipePlan(recipe: recipe, media: media)
        case .kineticTextSteps:
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
        
        // Background: looping motion between images
        let backgroundImages = [media.beforeFridge, media.cookedMeal, media.cookedMeal]  // Use cookedMeal for after
        let segmentDuration = CMTime(seconds: 5, preferredTimescale: 600)
        
        for (index, image) in backgroundImages.enumerated() {
            items.append(RenderPlan.TrackItem(
                kind: .still(image),
                timeRange: CMTimeRange(
                    start: CMTime(seconds: Double(index) * 5, preferredTimescale: 600),
                    duration: segmentDuration
                ),
                transform: createKenBurnsTransform(index: index)
            ))
        }
        
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
        
        // Step text overlays (2-13s, 1.6s minimum each)
        let steps = Array(recipe.steps.prefix(6)) // Max 6 steps
        let stepDuration = CMTime(seconds: max(1.6, 11.0 / Double(steps.count)), preferredTimescale: 600)
        
        for (index, step) in steps.enumerated() {
            let startTime = CMTime(seconds: 2 + (Double(index) * stepDuration.seconds), preferredTimescale: 600)
            
            overlays.append(RenderPlan.Overlay(
                start: startTime,
                duration: stepDuration,
                layerBuilder: { config in
                    return self.createKineticStepOverlay(
                        text: CaptionGenerator.processStepText(step, index: index),
                        index: index,
                        config: config
                    )
                }
            ))
        }
        
        // Final CTA (13-15s)
        overlays.append(RenderPlan.Overlay(
            start: CMTime(seconds: 13, preferredTimescale: 600),
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
        
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = ciImage
        colorFilter.contrast = 1.1    // +0.1 contrast as specified
        colorFilter.saturation = 1.08 // +0.08 saturation as specified
        
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
        
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = ciImage
        blurFilter.radius = 3 // Reduced from 10 - more subtle blur
        
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
        scaleAnimation.beginTime = CACurrentMediaTime() + Double(index) * 0.12 // 120ms stagger
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
        
        let padding: CGFloat = 20
        let stickerWidth = textSize.width + (padding * 2)
        let stickerHeight: CGFloat = 60
        
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
        textLayer.frame = CGRect(x: padding, y: 15, width: textSize.width, height: 30)
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
        // Stub implementation - will be moved to OverlayFactory
        let layer = CATextLayer()
        layer.string = text
        return layer
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
}