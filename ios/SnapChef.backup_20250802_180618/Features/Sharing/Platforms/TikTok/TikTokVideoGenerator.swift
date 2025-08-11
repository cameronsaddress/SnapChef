//
//  TikTokVideoGenerator.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import AVFoundation
import CoreImage
import UIKit

@MainActor
class TikTokVideoGenerator: ObservableObject {
    @Published var isGenerating = false
    @Published var currentProgress: Double = 0
    
    private let videoSize = CGSize(width: 1080, height: 1920) // 9:16 aspect ratio for TikTok
    private let frameDuration = CMTime(value: 1, timescale: 30) // 30 fps
    
    func generateVideo(
        template: TikTokTemplate,
        content: ShareContent,
        progress: @escaping (Double) async -> Void
    ) async throws -> URL {
        isGenerating = true
        currentProgress = 0
        
        // Create temporary output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiktok_video_\(Date().timeIntervalSince1970).mp4")
        
        // Remove existing file if needed
        try? FileManager.default.removeItem(at: outputURL)
        
        // Generate video based on template
        switch template {
        case .beforeAfterReveal:
            return try await generateBeforeAfterVideo(content: content, outputURL: outputURL, progress: progress)
        case .quickRecipe:
            return try await generateQuickRecipeVideo(content: content, outputURL: outputURL, progress: progress)
        case .ingredients360:
            return try await generateIngredients360Video(content: content, outputURL: outputURL, progress: progress)
        case .timelapse:
            return try await generateTimelapseVideo(content: content, outputURL: outputURL, progress: progress)
        case .splitScreen:
            return try await generateSplitScreenVideo(content: content, outputURL: outputURL, progress: progress)
        }
    }
    
    // MARK: - Template Implementations
    
    private func generateBeforeAfterVideo(
        content: ShareContent,
        outputURL: URL,
        progress: @escaping (Double) async -> Void
    ) async throws -> URL {
        // Create video writer
        let videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // Configure video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height
        ]
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: videoSize.width,
                kCVPixelBufferHeightKey as String: videoSize.height
            ]
        )
        
        videoWriter.add(videoInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        // Generate frames
        let totalFrames = 150 // 5 seconds at 30fps
        var frameCount = 0
        
        while frameCount < totalFrames {
            if videoInput.isReadyForMoreMediaData {
                autoreleasepool {
                    if let pixelBuffer = createFrame(
                        for: .beforeAfterReveal,
                        content: content,
                        frameIndex: frameCount,
                        totalFrames: totalFrames
                    ) {
                        let presentationTime = CMTime(value: Int64(frameCount), timescale: 30)
                        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    }
                }
                
                frameCount += 1
                let progressValue = Double(frameCount) / Double(totalFrames)
                Task {
                    await progress(progressValue)
                    await MainActor.run {
                        currentProgress = progressValue
                    }
                }
            }
        }
        
        // Finish writing
        videoInput.markAsFinished()
        await videoWriter.finishWriting()
        
        isGenerating = false
        return outputURL
    }
    
    private func generateQuickRecipeVideo(
        content: ShareContent,
        outputURL: URL,
        progress: @escaping (Double) async -> Void
    ) async throws -> URL {
        // Simplified implementation - would create recipe steps animation
        return try await generateBeforeAfterVideo(content: content, outputURL: outputURL, progress: progress)
    }
    
    private func generateIngredients360Video(
        content: ShareContent,
        outputURL: URL,
        progress: @escaping (Double) async -> Void
    ) async throws -> URL {
        // Simplified implementation - would create 360 rotation of ingredients
        return try await generateBeforeAfterVideo(content: content, outputURL: outputURL, progress: progress)
    }
    
    private func generateTimelapseVideo(
        content: ShareContent,
        outputURL: URL,
        progress: @escaping (Double) async -> Void
    ) async throws -> URL {
        // Simplified implementation - would create timelapse effect
        return try await generateBeforeAfterVideo(content: content, outputURL: outputURL, progress: progress)
    }
    
    private func generateSplitScreenVideo(
        content: ShareContent,
        outputURL: URL,
        progress: @escaping (Double) async -> Void
    ) async throws -> URL {
        // Simplified implementation - would create split screen comparison
        return try await generateBeforeAfterVideo(content: content, outputURL: outputURL, progress: progress)
    }
    
    // MARK: - Frame Generation
    
    private func createFrame(
        for template: TikTokTemplate,
        content: ShareContent,
        frameIndex: Int,
        totalFrames: Int
    ) -> CVPixelBuffer? {
        // Create pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(videoSize.width),
            Int(videoSize.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        // Lock buffer
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        // Create graphics context
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(videoSize.width),
            height: Int(videoSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        
        // Draw frame content
        drawFrameContent(
            in: context,
            template: template,
            content: content,
            frameIndex: frameIndex,
            totalFrames: totalFrames
        )
        
        return buffer
    }
    
    private func drawFrameContent(
        in context: CGContext,
        template: TikTokTemplate,
        content: ShareContent,
        frameIndex: Int,
        totalFrames: Int
    ) {
        let progress = Double(frameIndex) / Double(totalFrames)
        
        // Fill background
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: videoSize))
        
        // Draw template-specific content
        switch template {
        case .beforeAfterReveal:
            drawBeforeAfterReveal(in: context, content: content, progress: progress)
        default:
            drawDefaultTemplate(in: context, content: content, progress: progress)
        }
        
        // Add overlays
        drawTikTokOverlays(in: context, content: content)
    }
    
    private func drawBeforeAfterReveal(in context: CGContext, content: ShareContent, progress: Double) {
        // Draw gradient background
        let gradientColors = [
            UIColor(red: 1, green: 0, blue: 0.31, alpha: 1).cgColor, // #FF0050
            UIColor(red: 0, green: 0.95, blue: 0.92, alpha: 1).cgColor  // #00F2EA
        ]
        
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: gradientColors as CFArray,
            locations: nil
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: videoSize.width, y: videoSize.height),
                options: []
            )
        }
        
        // Draw reveal animation
        let revealWidth = videoSize.width * CGFloat(progress)
        
        // Draw "before" text
        if progress < 0.5 {
            drawCenteredText(
                "BEFORE",
                in: context,
                at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2 - 100),
                fontSize: 60,
                color: .white
            )
        }
        
        // Draw "after" text
        if progress > 0.5 {
            drawCenteredText(
                "AFTER",
                in: context,
                at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2 - 100),
                fontSize: 60,
                color: .white
            )
        }
        
        // Draw recipe name
        if case .recipe(let recipe) = content.type {
            drawCenteredText(
                recipe.name.uppercased(),
                in: context,
                at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2 + 100),
                fontSize: 40,
                color: .white
            )
        }
    }
    
    private func drawDefaultTemplate(in context: CGContext, content: ShareContent, progress: Double) {
        // Simple default template
        drawCenteredText(
            "SNAPCHEF",
            in: context,
            at: CGPoint(x: videoSize.width / 2, y: videoSize.height / 2),
            fontSize: 48,
            color: .white
        )
    }
    
    private func drawTikTokOverlays(in context: CGContext, content: ShareContent) {
        // Add SnapChef watermark
        drawCenteredText(
            "@snapchef",
            in: context,
            at: CGPoint(x: videoSize.width - 100, y: videoSize.height - 50),
            fontSize: 20,
            color: UIColor.white.withAlphaComponent(0.8)
        )
    }
    
    private func drawCenteredText(
        _ text: String,
        in context: CGContext,
        at point: CGPoint,
        fontSize: CGFloat,
        color: UIColor
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()
        
        let rect = CGRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        
        UIGraphicsPushContext(context)
        attributedString.draw(in: rect)
        UIGraphicsPopContext()
    }
}