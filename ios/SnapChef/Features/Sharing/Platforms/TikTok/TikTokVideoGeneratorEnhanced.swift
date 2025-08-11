//
//  TikTokVideoGeneratorEnhanced.swift
//  SnapChef
//
//  Enhanced video generation with viral features
//

import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Photos

@MainActor
class TikTokVideoGeneratorEnhanced: ObservableObject {
    @Published var isGenerating = false
    @Published var currentProgress: Double = 0
    @Published var statusMessage = ""
    
    private let videoSize = CGSize(width: 1080, height: 1920) // 9:16 TikTok aspect ratio
    private let frameDuration = CMTime(value: 1, timescale: 30) // 30 fps
    private let context = CIContext()
    
    // Viral video best practices
    private let viralTiming = [
        "hook": 0.0...3.0,      // First 3 seconds are crucial
        "reveal": 3.0...5.0,     // Big reveal moment
        "details": 5.0...12.0,   // Show the process/details
        "cta": 12.0...15.0       // Call to action
    ]
    
    // MARK: - Main Video Generation
    
    func generateVideo(
        template: TikTokTemplate,
        content: ShareContent,
        selectedAudio: TrendingAudio? = nil,
        selectedHashtags: [String] = [],
        progress: @escaping (Double) async -> Void
    ) async throws -> URL {
        isGenerating = true
        currentProgress = 0
        statusMessage = "Initializing video generator..."
        
        // Create temporary output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiktok_\(UUID().uuidString).mp4")
        
        // Remove existing file if needed
        try? FileManager.default.removeItem(at: outputURL)
        
        // Generate based on template
        let result: URL
        switch template {
        case .beforeAfterReveal:
            result = try await generateBeforeAfterReveal(
                content: content,
                outputURL: outputURL,
                progress: progress
            )
        case .quickRecipe:
            result = try await generateQuickRecipe(
                content: content,
                outputURL: outputURL,
                progress: progress
            )
        case .ingredients360:
            result = try await generateIngredients360(
                content: content,
                outputURL: outputURL,
                progress: progress
            )
        case .timelapse:
            result = try await generateTimelapse(
                content: content,
                outputURL: outputURL,
                progress: progress
            )
        case .splitScreen:
            result = try await generateSplitScreen(
                content: content,
                outputURL: outputURL,
                progress: progress
            )
        }
        
        // Add audio if selected
        if let audio = selectedAudio {
            statusMessage = "Adding trending audio..."
            // In production, would add actual audio track
        }
        
        // Add watermark and branding
        statusMessage = "Adding SnapChef branding..."
        
        isGenerating = false
        statusMessage = "Video ready to share!"
        return result
    }
    
    // MARK: - Before/After Reveal Template
    
    private func generateBeforeAfterReveal(
        content: ShareContent,
        outputURL: URL,
        progress: @escaping (Double) async -> Void
    ) async throws -> URL {
        statusMessage = "Creating dramatic reveal..."
        
        let videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings = createVideoSettings()
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        
        let pixelBufferAdaptor = createPixelBufferAdaptor(for: videoInput)
        
        videoWriter.add(videoInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        // Video structure (15 seconds total)
        let scenes = [
            VideoScene(name: "hook", duration: 3.0, frames: 90),      // Hook with question
            VideoScene(name: "before", duration: 2.0, frames: 60),    // Show ingredients
            VideoScene(name: "transition", duration: 1.0, frames: 30), // Swipe transition
            VideoScene(name: "after", duration: 3.0, frames: 90),     // Reveal result
            VideoScene(name: "details", duration: 4.0, frames: 120),  // Recipe details
            VideoScene(name: "cta", duration: 2.0, frames: 60)        // Call to action
        ]
        
        var totalFramesProcessed = 0
        let totalFrames = scenes.reduce(0) { $0 + $1.frames }
        
        for scene in scenes {
            statusMessage = "Processing \(scene.name)..."
            print("🎬 Processing scene: \(scene.name) with \(scene.frames) frames")
            
            for frameIndex in 0..<scene.frames {
                // Wait for video input to be ready
                while !videoInput.isReadyForMoreMediaData {
                    print("⚠️ Video input not ready for more data at frame \(totalFramesProcessed)")
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                
                autoreleasepool {
                    if let pixelBuffer = createBeforeAfterFrame(
                        scene: scene,
                        frameIndex: frameIndex,
                        content: content
                    ) {
                        let presentationTime = CMTime(
                            value: Int64(totalFramesProcessed),
                            timescale: 30
                        )
                        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    }
                }
                
                totalFramesProcessed += 1
                let progressValue = Double(totalFramesProcessed) / Double(totalFrames)
                await progress(progressValue)
                currentProgress = progressValue
            }
        }
        
        print("🎬 Total frames processed: \(totalFramesProcessed) of \(totalFrames)")
        videoInput.markAsFinished()
        
        await withCheckedContinuation { continuation in
            videoWriter.finishWriting {
                print("🎬 Video writing finished with status: \(videoWriter.status.rawValue)")
                if let error = videoWriter.error {
                    print("❌ Video writer error: \(error)")
                }
                continuation.resume()
            }
        }
        
        print("🎬 Video saved to: \(outputURL)")
        return outputURL
    }
    
    // MARK: - Quick Recipe Template (60 seconds)
    
    private func generateQuickRecipe(
        content: ShareContent,
        outputURL: URL,
        progress: @escaping (Double) async -> Void
    ) async throws -> URL {
        statusMessage = "Creating quick recipe tutorial..."
        
        // Extract recipe details
        guard case .recipe(let recipe) = content.type else {
            throw VideoGenerationError.invalidContent
        }
        
        let videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings = createVideoSettings()
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        
        let pixelBufferAdaptor = createPixelBufferAdaptor(for: videoInput)
        
        videoWriter.add(videoInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        // 60-second recipe breakdown
        let segments = [
            RecipeSegment(title: "Ingredients", duration: 10, items: recipe.ingredients.map { $0.name }),
            RecipeSegment(title: "Step 1", duration: 15, items: [recipe.instructions.first ?? ""]),
            RecipeSegment(title: "Step 2", duration: 15, items: [recipe.instructions.dropFirst().first ?? ""]),
            RecipeSegment(title: "Final Touch", duration: 10, items: ["Season to taste"]),
            RecipeSegment(title: "Enjoy!", duration: 10, items: ["Ready in \(recipe.prepTime + recipe.cookTime) minutes"])
        ]
        
        var totalFramesProcessed = 0
        let totalFrames = segments.reduce(0) { $0 + ($1.duration * 30) }
        
        for segment in segments {
            statusMessage = "Adding \(segment.title)..."
            
            for frameIndex in 0..<(segment.duration * 30) {
                if videoInput.isReadyForMoreMediaData {
                    autoreleasepool {
                        if let pixelBuffer = createQuickRecipeFrame(
                            segment: segment,
                            frameIndex: frameIndex,
                            recipe: recipe
                        ) {
                            let presentationTime = CMTime(
                                value: Int64(totalFramesProcessed),
                                timescale: 30
                            )
                            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                        }
                    }
                    
                    totalFramesProcessed += 1
                    await progress(Double(totalFramesProcessed) / Double(totalFrames))
                }
            }
        }
        
        videoInput.markAsFinished()
        
        await withCheckedContinuation { continuation in
            videoWriter.finishWriting {
                continuation.resume()
            }
        }
        
        return outputURL
    }
    
    // MARK: - 360° Ingredients Template
    
    private func generateIngredients360(
        content: ShareContent,
        outputURL: URL,
        progress: @escaping (Double) async -> Void
    ) async throws -> URL {
        statusMessage = "Creating 360° ingredient showcase..."
        
        let videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings = createVideoSettings()
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        
        let pixelBufferAdaptor = createPixelBufferAdaptor(for: videoInput)
        
        videoWriter.add(videoInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        let totalFrames = 300 // 10 seconds
        
        for frameIndex in 0..<totalFrames {
            if videoInput.isReadyForMoreMediaData {
                autoreleasepool {
                    let rotation = Double(frameIndex) / Double(totalFrames) * 360
                    if let pixelBuffer = create360Frame(
                        rotation: rotation,
                        content: content
                    ) {
                        let presentationTime = CMTime(value: Int64(frameIndex), timescale: 30)
                        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    }
                }
                
                await progress(Double(frameIndex) / Double(totalFrames))
            }
        }
        
        videoInput.markAsFinished()
        
        await withCheckedContinuation { continuation in
            videoWriter.finishWriting {
                continuation.resume()
            }
        }
        
        return outputURL
    }
    
    // MARK: - Timelapse Template
    
    private func generateTimelapse(
        content: ShareContent,
        outputURL: URL,
        progress: @escaping (Double) async -> Void
    ) async throws -> URL {
        statusMessage = "Creating cooking timelapse..."
        
        // Similar implementation with speed ramping effects
        return try await generateBeforeAfterReveal(content: content, outputURL: outputURL, progress: progress)
    }
    
    // MARK: - Split Screen Template
    
    private func generateSplitScreen(
        content: ShareContent,
        outputURL: URL,
        progress: @escaping (Double) async -> Void
    ) async throws -> URL {
        statusMessage = "Creating split screen comparison..."
        
        let videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings = createVideoSettings()
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        
        let pixelBufferAdaptor = createPixelBufferAdaptor(for: videoInput)
        
        videoWriter.add(videoInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        let totalFrames = 450 // 15 seconds
        
        for frameIndex in 0..<totalFrames {
            if videoInput.isReadyForMoreMediaData {
                autoreleasepool {
                    if let pixelBuffer = createSplitScreenFrame(
                        frameIndex: frameIndex,
                        totalFrames: totalFrames,
                        content: content
                    ) {
                        let presentationTime = CMTime(value: Int64(frameIndex), timescale: 30)
                        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    }
                }
                
                await progress(Double(frameIndex) / Double(totalFrames))
            }
        }
        
        videoInput.markAsFinished()
        
        await withCheckedContinuation { continuation in
            videoWriter.finishWriting {
                continuation.resume()
            }
        }
        
        return outputURL
    }
    
    // MARK: - Frame Creation Helpers
    
    private func createBeforeAfterFrame(
        scene: VideoScene,
        frameIndex: Int,
        content: ShareContent
    ) -> CVPixelBuffer? {
        let pixelBuffer = createPixelBuffer()
        guard let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = createGraphicsContext(from: buffer) else { return nil }
        
        // Black background
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: videoSize))
        
        // Draw based on scene
        switch scene.name {
        case "hook":
            drawHookScene(in: context, progress: Double(frameIndex) / Double(scene.frames))
        case "before":
            drawBeforeScene(in: context, content: content)
        case "transition":
            drawTransitionScene(in: context, progress: Double(frameIndex) / Double(scene.frames))
        case "after":
            drawAfterScene(in: context, content: content)
        case "details":
            drawDetailsScene(in: context, content: content)
        case "cta":
            drawCTAScene(in: context)
        default:
            break
        }
        
        // Add SnapChef watermark
        drawWatermark(in: context)
        
        return buffer
    }
    
    private func createQuickRecipeFrame(
        segment: RecipeSegment,
        frameIndex: Int,
        recipe: Recipe
    ) -> CVPixelBuffer? {
        let pixelBuffer = createPixelBuffer()
        guard let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = createGraphicsContext(from: buffer) else { return nil }
        
        // Gradient background
        drawGradientBackground(in: context)
        
        // Title with animation
        let titleY = 200 + sin(Double(frameIndex) * 0.1) * 10
        drawText(
            segment.title,
            in: context,
            at: CGPoint(x: videoSize.width / 2, y: titleY),
            fontSize: 60,
            color: .white,
            weight: .black
        )
        
        // Content items
        var yOffset: CGFloat = 400
        for item in segment.items {
            drawText(
                item,
                in: context,
                at: CGPoint(x: videoSize.width / 2, y: yOffset),
                fontSize: 32,
                color: .white.withAlphaComponent(0.9),
                weight: .medium
            )
            yOffset += 60
        }
        
        // Progress bar at bottom
        let progress = Double(frameIndex) / Double(segment.duration * 30)
        drawProgressBar(in: context, progress: progress)
        
        return buffer
    }
    
    private func create360Frame(
        rotation: Double,
        content: ShareContent
    ) -> CVPixelBuffer? {
        let pixelBuffer = createPixelBuffer()
        guard let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = createGraphicsContext(from: buffer) else { return nil }
        
        // Dark gradient background
        drawGradientBackground(in: context)
        
        // 3D-style rotation effect
        let centerX = videoSize.width / 2
        let centerY = videoSize.height / 2
        
        // Draw rotating elements
        for i in 0..<6 {
            let angle = (rotation + Double(i) * 60) * .pi / 180
            let radius: CGFloat = 200
            let x = centerX + CGFloat(cos(angle)) * radius
            let y = centerY + CGFloat(sin(angle)) * radius * 0.5 // Elliptical path
            
            // Scale based on position (front = larger)
            let scale = 1.0 + sin(angle) * 0.3
            
            drawIngredientCircle(
                in: context,
                at: CGPoint(x: x, y: y),
                scale: scale,
                alpha: CGFloat(0.5 + sin(angle) * 0.5)
            )
        }
        
        // Center text
        if case .recipe(let recipe) = content.type {
            drawText(
                recipe.name,
                in: context,
                at: CGPoint(x: centerX, y: centerY - 300),
                fontSize: 48,
                color: .white,
                weight: .bold
            )
        }
        
        return buffer
    }
    
    private func createSplitScreenFrame(
        frameIndex: Int,
        totalFrames: Int,
        content: ShareContent
    ) -> CVPixelBuffer? {
        let pixelBuffer = createPixelBuffer()
        guard let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = createGraphicsContext(from: buffer) else { return nil }
        
        // Black background
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: videoSize))
        
        let halfWidth = videoSize.width / 2
        
        // Left side - Process
        context.saveGState()
        context.clip(to: CGRect(x: 0, y: 0, width: halfWidth - 1, height: videoSize.height))
        drawProcessSide(in: context, progress: Double(frameIndex) / Double(totalFrames))
        context.restoreGState()
        
        // Center divider
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: halfWidth - 1, y: 0, width: 2, height: videoSize.height))
        
        // Right side - Result
        context.saveGState()
        context.clip(to: CGRect(x: halfWidth + 1, y: 0, width: halfWidth - 1, height: videoSize.height))
        drawResultSide(in: context, content: content)
        context.restoreGState()
        
        return buffer
    }
    
    // MARK: - Drawing Helpers
    
    private func drawHookScene(in context: CGContext, progress: Double) {
        let text = "Can you turn THIS..."
        let alpha = min(progress * 2, 1.0)
        
        drawText(
            text,
            in: context,
            at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2),
            fontSize: 56,
            color: UIColor.white.withAlphaComponent(alpha),
            weight: .black
        )
    }
    
    private func drawBeforeScene(in context: CGContext, content: ShareContent) {
        // Draw the before photo if available
        if let beforeImage = content.beforeImage {
            drawImage(beforeImage, in: context, fitting: videoSize)
            
            // Add text overlay
            drawText(
                "Can you turn THIS...",
                in: context,
                at: CGPoint(x: videoSize.width / 2, y: videoSize.height - 200),
                fontSize: 48,
                color: .white,
                weight: .bold,
                shadow: true
            )
        } else {
            // Fallback to text if no image
            drawText(
                "🥗 Random Fridge Items",
                in: context,
                at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2),
                fontSize: 48,
                color: .white,
                weight: .bold
            )
        }
    }
    
    private func drawTransitionScene(in context: CGContext, progress: Double) {
        // Swipe effect
        let swipeX = videoSize.width * progress
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: swipeX, height: videoSize.height))
    }
    
    private func drawAfterScene(in context: CGContext, content: ShareContent) {
        // Draw the after photo if available
        if let afterImage = content.afterImage {
            drawImage(afterImage, in: context, fitting: videoSize)
            
            if case .recipe(let recipe) = content.type {
                // Add text overlay on the image
                drawText(
                    "Into THIS! 🍽",
                    in: context,
                    at: CGPoint(x: videoSize.width / 2, y: 150),
                    fontSize: 48,
                    color: .white,
                    weight: .black,
                    shadow: true
                )
                
                drawText(
                    recipe.name,
                    in: context,
                    at: CGPoint(x: videoSize.width / 2, y: videoSize.height - 200),
                    fontSize: 42,
                    color: UIColor(hex: "#00F2EA") ?? .cyan,
                    weight: .bold,
                    shadow: true
                )
            }
        } else {
            // Fallback to text-only if no after image
            if case .recipe(let recipe) = content.type {
                drawText(
                    "Into THIS! 🍽",
                    in: context,
                    at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2 - 100),
                    fontSize: 48,
                    color: .white,
                    weight: .black
                )
                
                drawText(
                    recipe.name,
                    in: context,
                    at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2 + 50),
                    fontSize: 42,
                    color: UIColor(hex: "#00F2EA") ?? .cyan,
                    weight: .bold
                )
            }
        }
    }
    
    private func drawDetailsScene(in context: CGContext, content: ShareContent) {
        if case .recipe(let recipe) = content.type {
            drawText(
                "⏱ \(recipe.prepTime + recipe.cookTime) minutes",
                in: context,
                at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2 - 100),
                fontSize: 36,
                color: .white,
                weight: .medium
            )
            
            drawText(
                "🍽 \(recipe.servings) servings",
                in: context,
                at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2),
                fontSize: 36,
                color: .white,
                weight: .medium
            )
            
            drawText(
                "⭐ \(recipe.difficulty.rawValue) difficulty",
                in: context,
                at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2 + 100),
                fontSize: 36,
                color: .white,
                weight: .medium
            )
        }
    }
    
    private func drawCTAScene(in context: CGContext) {
        drawText(
            "Get SnapChef 👇",
            in: context,
            at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2 - 50),
            fontSize: 52,
            color: UIColor(hex: "#FF0050") ?? .systemPink,
            weight: .black
        )
        
        drawText(
            "Turn YOUR fridge into magic!",
            in: context,
            at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2 + 50),
            fontSize: 32,
            color: .white,
            weight: .medium
        )
    }
    
    private func drawWatermark(in context: CGContext) {
        drawText(
            "@snapchef",
            in: context,
            at: CGPoint(x: videoSize.width - 120, y: videoSize.height - 50),
            fontSize: 24,
            color: UIColor.white.withAlphaComponent(0.7),
            weight: .medium
        )
    }
    
    private func drawGradientBackground(in context: CGContext) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            UIColor.black.cgColor,
            UIColor(hex: "#1a1a1a")?.cgColor ?? UIColor.darkGray.cgColor
        ] as CFArray
        
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: videoSize.height),
                options: []
            )
        }
    }
    
    private func drawProgressBar(in context: CGContext, progress: Double) {
        let barHeight: CGFloat = 6
        let barY = videoSize.height - 100
        
        // Background
        context.setFillColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        context.fill(CGRect(x: 50, y: barY, width: videoSize.width - 100, height: barHeight))
        
        // Progress
        context.setFillColor(UIColor(hex: "#00F2EA")?.cgColor ?? UIColor.cyan.cgColor)
        context.fill(CGRect(x: 50, y: barY, width: (videoSize.width - 100) * progress, height: barHeight))
    }
    
    private func drawText(
        _ text: String,
        in context: CGContext,
        at point: CGPoint,
        fontSize: CGFloat,
        color: UIColor,
        weight: UIFont.Weight = .regular,
        shadow: Bool = false
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        var attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        // Add shadow if requested (for text over images)
        if shadow {
            let shadowColor = UIColor.black.withAlphaComponent(0.8)
            let shadow = NSShadow()
            shadow.shadowColor = shadowColor
            shadow.shadowOffset = CGSize(width: 2, height: 2)
            shadow.shadowBlurRadius = 4
            attributes[.shadow] = shadow
            
            // Add stroke for better visibility
            attributes[.strokeColor] = UIColor.black
            attributes[.strokeWidth] = -2.0
        }
        
        let size = text.size(withAttributes: attributes)
        let rect = CGRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        
        // Save the current context state
        context.saveGState()
        
        // Flip the coordinate system for text rendering
        context.translateBy(x: 0, y: videoSize.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Adjust the rect for the flipped coordinate system
        let flippedRect = CGRect(
            x: rect.origin.x,
            y: videoSize.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
        
        UIGraphicsPushContext(context)
        text.draw(in: flippedRect, withAttributes: attributes)
        UIGraphicsPopContext()
        
        // Restore the context state
        context.restoreGState()
    }
    
    private func drawImage(
        _ image: UIImage,
        in context: CGContext,
        fitting targetSize: CGSize,
        contentMode: UIView.ContentMode = .scaleAspectFill
    ) {
        let imageSize = image.size
        var drawRect = CGRect(origin: .zero, size: targetSize)
        
        if contentMode == .scaleAspectFill {
            // Calculate aspect fill
            let widthRatio = targetSize.width / imageSize.width
            let heightRatio = targetSize.height / imageSize.height
            let scale = max(widthRatio, heightRatio)
            
            let scaledWidth = imageSize.width * scale
            let scaledHeight = imageSize.height * scale
            
            // Center the image
            drawRect = CGRect(
                x: (targetSize.width - scaledWidth) / 2,
                y: (targetSize.height - scaledHeight) / 2,
                width: scaledWidth,
                height: scaledHeight
            )
        } else if contentMode == .scaleAspectFit {
            // Calculate aspect fit
            let widthRatio = targetSize.width / imageSize.width
            let heightRatio = targetSize.height / imageSize.height
            let scale = min(widthRatio, heightRatio)
            
            let scaledWidth = imageSize.width * scale
            let scaledHeight = imageSize.height * scale
            
            // Center the image
            drawRect = CGRect(
                x: (targetSize.width - scaledWidth) / 2,
                y: (targetSize.height - scaledHeight) / 2,
                width: scaledWidth,
                height: scaledHeight
            )
        }
        
        // Save the current context state
        context.saveGState()
        
        // No need to flip coordinate system - CGContext already uses the correct orientation
        // Draw the image directly
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: drawRect)
        }
        
        // Add a subtle vignette effect for better text visibility
        let vignettePath = CGPath(rect: CGRect(origin: .zero, size: targetSize), transform: nil)
        context.addPath(vignettePath)
        context.setFillColor(UIColor.black.withAlphaComponent(0.2).cgColor)
        context.fillPath()
        
        // Restore the context state
        context.restoreGState()
    }
    
    private func drawIngredientCircle(
        in context: CGContext,
        at point: CGPoint,
        scale: Double,
        alpha: CGFloat
    ) {
        let radius: CGFloat = 80 * scale
        
        context.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
        context.fillEllipse(in: CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }
    
    private func drawProcessSide(in context: CGContext, progress: Double) {
        drawText(
            "PROCESS",
            in: context,
            at: CGPoint(x: videoSize.width / 4, y: 200),
            fontSize: 32,
            color: .white,
            weight: .bold
        )
        
        // Animated cooking icon
        let iconY = 600 + sin(progress * .pi * 2) * 50
        drawText(
            "👨‍🍳",
            in: context,
            at: CGPoint(x: videoSize.width / 4, y: iconY),
            fontSize: 120,
            color: .white,
            weight: .regular
        )
    }
    
    private func drawResultSide(in context: CGContext, content: ShareContent) {
        drawText(
            "RESULT",
            in: context,
            at: CGPoint(x: videoSize.width * 0.75, y: 200),
            fontSize: 32,
            color: .white,
            weight: .bold
        )
        
        drawText(
            "✨",
            in: context,
            at: CGPoint(x: videoSize.width * 0.75, y: 600),
            fontSize: 120,
            color: .white,
            weight: .regular
        )
    }
    
    // MARK: - Helper Methods
    
    private func createVideoSettings() -> [String: Any] {
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6000000, // 6 Mbps for good quality
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
    }
    
    private func createPixelBufferAdaptor(for input: AVAssetWriterInput) -> AVAssetWriterInputPixelBufferAdaptor {
        return AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: videoSize.width,
                kCVPixelBufferHeightKey as String: videoSize.height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
        )
    }
    
    private func createPixelBuffer() -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(videoSize.width),
            Int(videoSize.height),
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ] as CFDictionary,
            &pixelBuffer
        )
        
        return status == kCVReturnSuccess ? pixelBuffer : nil
    }
    
    private func createGraphicsContext(from pixelBuffer: CVPixelBuffer) -> CGContext? {
        return CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(videoSize.width),
            height: Int(videoSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
    }
}

// MARK: - Supporting Types

struct VideoScene {
    let name: String
    let duration: Double
    let frames: Int
}

struct RecipeSegment {
    let title: String
    let duration: Int // seconds
    let items: [String]
}

enum VideoGenerationError: LocalizedError {
    case invalidContent
    case writingFailed
    case audioProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidContent:
            return "Invalid content for video generation"
        case .writingFailed:
            return "Failed to write video file"
        case .audioProcessingFailed:
            return "Failed to process audio track"
        }
    }
}

// MARK: - UIColor Extension for Hex
extension UIColor {
    convenience init?(hex: String) {
        let r, g, b: CGFloat
        
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    
                    self.init(red: r, green: g, blue: b, alpha: 1.0)
                    return
                }
            }
        }
        
        return nil
    }
}