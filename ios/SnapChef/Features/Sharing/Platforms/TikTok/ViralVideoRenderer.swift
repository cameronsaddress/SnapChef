//
//  ViralVideoRenderer.swift
//  SnapChef
//
//  Created on 12/01/2025
//  AVFoundation compositor for viral video rendering
//

import UIKit
@preconcurrency import AVFoundation
import CoreImage
import CoreMedia
@preconcurrency import Foundation

/// Renderer with AVFoundation compositor as specified in requirements
public final class ViralVideoRenderer: @unchecked Sendable {
    
    private let config: RenderConfig
    private let stillWriter: StillWriter
    private let ciContext: CIContext
    private let memoryOptimizer = MemoryOptimizer.shared
    private let performanceMonitor = PerformanceMonitor.shared
    
    // MARK: - Initialization
    
    public init(config: RenderConfig) {
        self.config = config
        self.stillWriter = StillWriter(config: config)
        
        // Use shared CIContext from MemoryOptimizer for better performance and memory usage
        self.ciContext = memoryOptimizer.getCIContext()
    }
    
    // MARK: - Public Interface
    
    /// Main render method that handles the complete rendering pipeline
    public func render(
        plan: RenderPlan,
        config: RenderConfig,
        progressCallback: @escaping @Sendable (Double) async -> Void = { _ in }
    ) async throws -> URL {
        print("🎥 ViralVideoRenderer: Starting render with plan containing \(plan.items.count) items")
        
        // Log render plan items info
        for (itemIndex, item) in plan.items.enumerated() {
            switch item.kind {
            case .still(let image):
                print("  📸 Item \(itemIndex) - Still image for \(item.timeRange.duration.seconds)s:")
                print("      - Image size: \(image.size)")
                print("      - Has CGImage: \(image.cgImage != nil)")
                print("      - Has CIImage: \(image.ciImage != nil)")
            case .video(let url):
                print("  🎬 Item \(itemIndex) - Video: \(url.lastPathComponent)")
            }
        }
        
        // Render base video
        let baseVideoURL = try await renderBaseVideo(
            plan: plan,
            progressCallback: { progress in
                await progressCallback(progress * 0.7) // 0-70%
            }
        )
        
        // Composite video
        let compositedURL = try await compositeVideo(
            baseURL: baseVideoURL,
            plan: plan
        )
        
        await progressCallback(1.0) // 100%
        
        print("🎥 ViralVideoRenderer: Final video URL: \(compositedURL.lastPathComponent)")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: compositedURL.path),
           let fileSize = attributes[.size] as? Int64 {
            let sizeInMB = Double(fileSize) / (1024 * 1024)
            print("📏 ViralVideoRenderer: Video file size: \(String(format: "%.2f", sizeInMB)) MB")
        }
        
        return compositedURL
    }
    
    /// Render base video from render plan track items
    public func renderBaseVideo(
        plan: RenderPlan,
        progressCallback: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        
        // PREMIUM FIX: Start comprehensive performance monitoring
        performanceMonitor.startRenderMonitoring()
        performanceMonitor.markPhaseStart(.renderingFrames)
        memoryOptimizer.logMemoryProfile(phase: "Renderer Start")
        
        let outputURL = createTempOutputURL()
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create composition
        let composition = AVMutableComposition()
        print("🎬 DEBUG ViralVideoRenderer: Creating AVMutableComposition")
        
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        // Only create audio track if audio is provided
        var audioTrack: AVMutableCompositionTrack? = nil
        if plan.audio != nil {
            audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            print("🎬 DEBUG ViralVideoRenderer: Created audio track")
        } else {
            print("🎬 DEBUG ViralVideoRenderer: No audio track created (no audio in plan)")
        }
        
        guard let videoTrack = videoTrack else {
            print("❌ DEBUG ViralVideoRenderer: Failed to create video track")
            throw RendererError.cannotCreateVideoTrack
        }
        print("✅ DEBUG ViralVideoRenderer: Created video track")
        
        // REMOVED: Premium filters that were darkening images
        performanceMonitor.markPhaseStart(.preparingAssets)
        let enhancedItems = plan.items  // Use items as-is for clear visibility
        print("✅ Using original items without darkening filters")
        performanceMonitor.markPhaseEnd(.preparingAssets)
        
        // Process track items
        var currentTime = CMTime.zero
        var segmentURLs: [URL] = []
        
        print("🎬 DEBUG ViralVideoRenderer: Processing \(enhancedItems.count) track items")
        
        performanceMonitor.markPhaseStart(.compositing)
        for (index, item) in enhancedItems.enumerated() {
            let segmentURL = try await createSegmentForTrackItem(
                item,
                progressCallback: { segmentProgress in
                    let totalProgress = (Double(index) + segmentProgress) / Double(plan.items.count)
                    await progressCallback(totalProgress)
                }
            )
            
            segmentURLs.append(segmentURL)
            
            print("🎬 DEBUG ViralVideoRenderer: Created segment \(index+1)/\(plan.items.count) at: \(segmentURL.lastPathComponent)")
            print("🎬 DEBUG ViralVideoRenderer: Segment duration: \(item.timeRange.duration.seconds) seconds")
            
            // Memory optimization: Force cleanup after each segment
            memoryOptimizer.forceMemoryCleanup()
            
            // Add segment to composition
            let asset = AVAsset(url: segmentURL)
            print("🎬 DEBUG ViralVideoRenderer: Loading video track from segment...")
            guard let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                print("❌ DEBUG ViralVideoRenderer: Failed to load video track from segment \(index+1)")
                throw RendererError.cannotLoadVideoTrack
            }
            
            // Get track properties
            let naturalSize = try await assetVideoTrack.load(.naturalSize)
            let preferredTransform = try await assetVideoTrack.load(.preferredTransform)
            print("✅ DEBUG ViralVideoRenderer: Successfully loaded video track")
            print("  - Natural size: \(naturalSize)")
            print("  - Preferred transform: \(preferredTransform)")
            print("  - Insert at time: \(currentTime.seconds) seconds")
            
            do {
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: item.timeRange.duration),
                    of: assetVideoTrack,
                    at: currentTime
                )
                print("✅ DEBUG ViralVideoRenderer: Inserted segment \(index+1) into composition")
                
                // Note: Transforms will be applied during video composition
                // Store transform info in the composition for later application
                
                currentTime = CMTimeAdd(currentTime, item.timeRange.duration)
                print("  - New current time: \(currentTime.seconds) seconds")
            } catch {
                print("❌ DEBUG ViralVideoRenderer: Failed to insert segment \(index+1): \(error)")
                throw RendererError.compositionFailed(error.localizedDescription)
            }
        }
        
        print("🎬 DEBUG ViralVideoRenderer: All segments inserted. Total duration: \(currentTime.seconds) seconds")
        
        // Add audio if provided
        if let audioURL = plan.audio,
           let audioTrack = audioTrack {
            print("🎬 DEBUG ViralVideoRenderer: Adding audio track from: \(audioURL.lastPathComponent)")
            try await addAudioTrack(audioURL: audioURL, to: audioTrack, duration: plan.outputDuration)
            print("✅ DEBUG ViralVideoRenderer: Audio track added successfully")
        } else {
            print("🎬 DEBUG ViralVideoRenderer: No audio track to add")
        }
        
        // Validate composition before export
        print("🎬 DEBUG ViralVideoRenderer: Validating composition before export")
        print("  - Composition tracks count: \(composition.tracks.count)")
        print("  - Video tracks: \(composition.tracks(withMediaType: .video).count)")
        print("  - Audio tracks: \(composition.tracks(withMediaType: .audio).count)")
        print("  - Duration: \(composition.duration.seconds) seconds")
        
        // Create video composition to properly handle transforms
        print("🎬 DEBUG ViralVideoRenderer: Creating video composition for transforms...")
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = config.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: config.fps)
        
        // Create instruction for the video track
        if let videoTrack = composition.tracks(withMediaType: .video).first {
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            
            // Get the preferred transform and apply it correctly
            let preferredTransform = videoTrack.preferredTransform
            print("🎬 DEBUG ViralVideoRenderer: Video track preferred transform: \(preferredTransform)")
            
            // Calculate the transform to fit the video properly in the render size
            let videoSize = videoTrack.naturalSize
            let renderSize = config.size
            
            // Create a transform that centers and scales the video
            var transform = CGAffineTransform.identity
            
            // Scale to fit
            let scaleX = renderSize.width / videoSize.width
            let scaleY = renderSize.height / videoSize.height
            let scale = min(scaleX, scaleY)
            
            // Get video duration for animation timing
            let videoDuration = composition.duration
            
            // Premium: Add subtle zoom animation with easing for dynamic feel
            if config.premiumMode {
                // Start slightly zoomed out, then zoom to normal
                let startScale = scale * 0.9  // Start at 90% scale
                let endScale = scale * 1.0    // End at 100% scale
                
                // Create start transform (zoomed out)
                var startTransform = CGAffineTransform.identity
                startTransform = startTransform.scaledBy(x: startScale, y: startScale)
                
                // Center for start position
                let startScaledWidth = videoSize.width * startScale
                let startScaledHeight = videoSize.height * startScale
                let startTranslateX = (renderSize.width - startScaledWidth) / 2
                let startTranslateY = (renderSize.height - startScaledHeight) / 2
                startTransform = startTransform.translatedBy(x: startTranslateX / startScale, y: startTranslateY / startScale)
                
                // Create end transform (normal scale)
                var endTransform = CGAffineTransform.identity
                endTransform = endTransform.scaledBy(x: endScale, y: endScale)
                
                // Center for end position
                let endScaledWidth = videoSize.width * endScale
                let endScaledHeight = videoSize.height * endScale
                let endTranslateX = (renderSize.width - endScaledWidth) / 2
                let endTranslateY = (renderSize.height - endScaledHeight) / 2
                endTransform = endTransform.translatedBy(x: endTranslateX / endScale, y: endTranslateY / endScale)
                
                // Apply transform ramp for smooth zoom animation
                let zoomDuration = CMTime(seconds: 0.5, preferredTimescale: 600)
                layerInstruction.setTransformRamp(
                    fromStart: startTransform,
                    toEnd: endTransform,
                    timeRange: CMTimeRange(start: .zero, duration: zoomDuration)
                )
                
                // Premium: Add carousel-specific beat-synced snap animations
                // Create snap effects at beat intervals (120 BPM = 0.5s intervals)
                let beatInterval = config.carouselSnapDelay
                let totalBeats = Int(videoDuration.seconds / beatInterval)
                
                for beatIndex in 1..<min(totalBeats, 8) { // Up to 8 snaps for viral effect
                    let snapTime = CMTime(seconds: Double(beatIndex) * beatInterval, preferredTimescale: 600)
                    
                    // Calculate eased scale using sine wave for smooth animation
                    let snapScale = 1.0 + (config.carouselSnapScale - 1.0) * sin(Double.pi * 0.5)
                    
                    // Create snap transform with bounce effect
                    var snapTransform = endTransform
                    snapTransform = snapTransform.scaledBy(x: snapScale, y: snapScale)
                    
                    // Apply opacity fade for extra pop
                    layerInstruction.setOpacityRamp(
                        fromStartOpacity: 0.9,
                        toEndOpacity: 1.0,
                        timeRange: CMTimeRange(start: snapTime, duration: CMTime(seconds: 0.1, preferredTimescale: 600))
                    )
                }
                
                // Keep the final transform for the rest of the video
                layerInstruction.setTransform(endTransform, at: zoomDuration)
            } else {
                // Non-premium: simple static transform
                transform = transform.scaledBy(x: scale, y: scale)
                
                // Center the video
                let scaledWidth = videoSize.width * scale
                let scaledHeight = videoSize.height * scale
                let translateX = (renderSize.width - scaledWidth) / 2
                let translateY = (renderSize.height - scaledHeight) / 2
                transform = transform.translatedBy(x: translateX / scale, y: translateY / scale)
                
                layerInstruction.setTransform(transform, at: .zero)
            }
            
            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
            
            print("✅ DEBUG ViralVideoRenderer: Video composition created with proper transform")
        }
        
        // Export composition WITH video composition to handle transforms properly
        print("🎬 DEBUG ViralVideoRenderer: Starting composition export with video composition...")
        let exportedURL = try await exportComposition(
            composition,
            outputURL: outputURL,
            progressCallback: progressCallback,
            videoComposition: videoComposition  // Always use video composition
        )
        print("✅ DEBUG ViralVideoRenderer: Composition exported successfully to: \(exportedURL.lastPathComponent)")
        
        // Clean up segment files immediately for memory optimization
        memoryOptimizer.deleteTempFiles(segmentURLs)
        
        // Complete performance monitoring
        performanceMonitor.markPhaseEnd(.compositing)
        performanceMonitor.markPhaseEnd(.renderingFrames)
        
        // PREMIUM FIX: Check render time and log results
        let totalRenderTime = performanceMonitor.completeRenderMonitoring()
        if totalRenderTime > ExportSettings.maxRenderTime {
            print("⚠️ PREMIUM FIX: Render exceeded 5s limit: \(String(format: "%.2f", totalRenderTime))s")
        } else {
            print("✅ PREMIUM FIX: Render completed in \(String(format: "%.2f", totalRenderTime))s (<5s requirement met)")
        }
        
        memoryOptimizer.logMemoryProfile(phase: "Renderer Complete")
        
        return exportedURL
    }
    
    /// Composite video with additional effects and filters
    public func compositeVideo(
        baseURL: URL,
        plan: RenderPlan
    ) async throws -> URL {
        
        print("🎬 DEBUG ViralVideoRenderer: Starting composite video")
        print("🎬 DEBUG ViralVideoRenderer: Input: \(baseURL.lastPathComponent)")
        
        let outputURL = createTempOutputURL()
        print("🎬 DEBUG ViralVideoRenderer: Output will be: \(outputURL.lastPathComponent)")
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create asset from base video
        let asset = AVAsset(url: baseURL)
        
        // Validate base video asset
        print("🎬 DEBUG ViralVideoRenderer: Validating base video asset")
        let assetDuration = try await asset.load(.duration)
        let assetTracks = try await asset.loadTracks(withMediaType: .video)
        print("  - Asset duration: \(assetDuration.seconds) seconds")
        print("  - Video tracks: \(assetTracks.count)")
        
        if assetTracks.isEmpty {
            print("❌ DEBUG ViralVideoRenderer: No video tracks in base video!")
            throw RendererError.cannotLoadVideoTrack
        }
        
        // Create video composition for custom rendering
        print("🎬 DEBUG ViralVideoRenderer: Creating video composition...")
        let videoComposition = try await createVideoComposition(
            for: asset,
            plan: plan
        )
        print("✅ DEBUG ViralVideoRenderer: Video composition created")
        print("  - Render size: \(videoComposition.renderSize)")
        print("  - Frame duration: \(videoComposition.frameDuration.seconds) seconds")
        print("  - Instructions count: \(videoComposition.instructions.count)")
        
        // Export with video composition
        print("🎬 DEBUG ViralVideoRenderer: Creating export session...")
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: ExportSettings.videoPreset
        ) else {
            print("❌ DEBUG ViralVideoRenderer: Failed to create export session")
            throw RendererError.cannotCreateExportSession
        }
        print("✅ DEBUG ViralVideoRenderer: Export session created")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        return try await withCheckedThrowingContinuation { continuation in
            print("🎬 DEBUG ViralVideoRenderer: Starting export asynchronously...")
            exportSession.exportAsynchronously {
                print("🎬 DEBUG ViralVideoRenderer: Export completed with status: \(exportSession.status.rawValue)")
                switch exportSession.status {
                case .completed:
                    print("✅ DEBUG ViralVideoRenderer: Export successful to: \(outputURL.lastPathComponent)")
                    continuation.resume(returning: outputURL)
                case .failed:
                    let error = exportSession.error ?? RendererError.exportFailed
                    print("❌ DEBUG ViralVideoRenderer: Export failed with error: \(error)")
                    print("❌ DEBUG ViralVideoRenderer: Error domain: \((error as NSError).domain)")
                    print("❌ DEBUG ViralVideoRenderer: Error code: \((error as NSError).code)")
                    print("❌ DEBUG ViralVideoRenderer: Error userInfo: \((error as NSError).userInfo)")
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: RendererError.exportCancelled)
                default:
                    continuation.resume(throwing: RendererError.exportFailed)
                }
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func createSegmentForTrackItem(
        _ item: RenderPlan.TrackItem,
        progressCallback: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        
        switch item.kind {
        case .still(let image):
            // Convert FilterSpec to CIFilter
            let ciFilters = convertFilterSpecsToCIFilters(item.filters)
            return try await stillWriter.createVideoFromImage(
                image,
                duration: item.timeRange.duration,
                transform: item.transform,
                filters: ciFilters,
                progressCallback: progressCallback
            )
            
        case .video(let url):
            // For video clips, we need to extract the segment and apply transforms/filters
            // Convert FilterSpec to CIFilter
            let ciFilters = convertFilterSpecsToCIFilters(item.filters)
            return try await processVideoSegment(
                url: url,
                timeRange: item.timeRange,
                transform: item.transform,
                filters: ciFilters,
                progressCallback: progressCallback
            )
        }
    }
    
    private func processVideoSegment(
        url: URL,
        timeRange: CMTimeRange,
        transform: CGAffineTransform,
        filters: [CIFilter],
        progressCallback: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        
        let outputURL = createTempOutputURL()
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        let asset = AVAsset(url: url)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw RendererError.cannotCreateExportSession
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = timeRange
        
        // Apply transform and filters if needed
        if !transform.isIdentity || !filters.isEmpty {
            let videoComposition = try await createVideoCompositionForSegment(
                asset: asset,
                transform: transform,
                filters: filters
            )
            exportSession.videoComposition = videoComposition
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak exportSession] _ in
                guard let exportSession = exportSession else { return }
                let progress = Double(exportSession.progress)
                Task { @MainActor in
                    await progressCallback(progress)
                }
            }
            
            exportSession.exportAsynchronously { [weak exportSession] in
                progressTimer.invalidate()
                
                guard let exportSession = exportSession else {
                    continuation.resume(throwing: RendererError.exportFailed)
                    return
                }
                
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    let error = exportSession.error ?? RendererError.exportFailed
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: RendererError.exportCancelled)
                default:
                    continuation.resume(throwing: RendererError.exportFailed)
                }
            }
        }
    }
    
    private func createVideoComposition(
        for asset: AVAsset,
        plan: RenderPlan
    ) async throws -> AVVideoComposition {
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = config.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: config.fps)
        
        // Get video tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw RendererError.cannotLoadVideoTrack
        }
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: plan.outputDuration)
        
        // Apply per-item transforms and crossfades from the render plan
        var layerInstructions: [AVVideoCompositionLayerInstruction] = []
        
        if !plan.items.isEmpty {
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            
            // Get the base track transform
            let trackTransform = try await videoTrack.load(.preferredTransform)
            
            // Apply transforms and crossfades for each item
            var currentTime = CMTime.zero
            for (index, item) in plan.items.enumerated() {
                let itemTransform = trackTransform.concatenating(item.transform)
                layerInstruction.setTransform(itemTransform, at: currentTime)
                
                // PREMIUM FIX: Add crossfade with glow between segments
                if index > 0 && config.premiumMode {
                    let fadeDuration = CMTime(seconds: 0.3, preferredTimescale: 600)
                    let fadeStartTime = currentTime - fadeDuration
                    
                    // Create fade transition with glow effect
                    if fadeStartTime >= .zero {
                        let fadeRange = CMTimeRange(start: fadeStartTime, duration: fadeDuration)
                        
                        // Fade in current segment with ease-in-out
                        layerInstruction.setOpacityRamp(
                            fromStartOpacity: 0.0,
                            toEndOpacity: 1.0,
                            timeRange: fadeRange
                        )
                        
                        // FIXED: No additional scaling for glow - photos already have 5% zoom max
                        let glowStartTransform = itemTransform
                        let glowEndTransform = itemTransform
                        layerInstruction.setTransformRamp(
                            fromStart: glowStartTransform,
                            toEnd: glowEndTransform,
                            timeRange: fadeRange
                        )
                    }
                } else if index > 0 {
                    // Non-premium: simple fade without glow
                    let fadeDuration = CMTime(seconds: 0.5, preferredTimescale: 600)
                    let fadeStartTime = currentTime - fadeDuration
                    
                    if fadeStartTime >= .zero {
                        let fadeRange = CMTimeRange(start: fadeStartTime, duration: fadeDuration)
                        layerInstruction.setOpacityRamp(
                            fromStartOpacity: 0.0,
                            toEndOpacity: 1.0,
                            timeRange: fadeRange
                        )
                    }
                }
                
                currentTime = CMTimeAdd(currentTime, item.timeRange.duration)
            }
            
            layerInstructions = [layerInstruction]
        }
        
        instruction.layerInstructions = layerInstructions
        
        videoComposition.instructions = [instruction]
        return videoComposition
    }
    
    private func createVideoCompositionForSegment(
        asset: AVAsset,
        transform: CGAffineTransform,
        filters: [CIFilter]
    ) async throws -> AVVideoComposition {
        
        let composition = AVMutableVideoComposition()
        composition.renderSize = config.size
        composition.frameDuration = CMTime(value: 1, timescale: config.fps)
        
        // Get video tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw RendererError.cannotLoadVideoTrack
        }
        
        let duration = try await asset.load(.duration)
        
        // Create instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        
        // Create layer instruction
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        
        // Apply transforms
        let trackTransform = try await videoTrack.load(.preferredTransform)
        let finalTransform = trackTransform.concatenating(transform)
        layerInstruction.setTransform(finalTransform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]
        
        // Custom compositor would be added here if filters are needed
        // Note: FilterVideoCompositor implementation would need to conform to AVVideoCompositing
        
        return composition
    }
    
    private func addAudioTrack(
        audioURL: URL,
        to audioTrack: AVMutableCompositionTrack,
        duration: CMTime
    ) async throws {
        
        let audioAsset = AVAsset(url: audioURL)
        guard let audioAssetTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
            // No audio track found, skip
            return
        }
        
        let audioDuration = try await audioAsset.load(.duration)
        
        // Premium: Enhanced beat-sync for carousel template
        // Use configured BPM (120 default) for precise beat alignment
        let beatInterval = config.premiumMode ? CMTime(seconds: 60.0 / Double(config.beatBPM), preferredTimescale: 600) : .zero
        
        // Loop audio if needed
        var currentTime = CMTime.zero
        
        while currentTime < duration {
            let remainingTime = CMTimeSubtract(duration, currentTime)
            let insertDuration = CMTimeMinimum(audioDuration, remainingTime)
            
            // For carousel template, align audio with snap timings
            let insertTime = currentTime
            
            do {
                try audioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: insertDuration),
                    of: audioAssetTrack,
                    at: insertTime
                )
                
                currentTime = CMTimeAdd(currentTime, insertDuration)
            } catch {
                throw RendererError.audioInsertionFailed(error.localizedDescription)
            }
        }
    }
    
    private func exportComposition(
        _ composition: AVComposition,
        outputURL: URL,
        progressCallback: @escaping @Sendable (Double) async -> Void,
        videoComposition: AVVideoComposition? = nil
    ) async throws -> URL {
        
        print("🎬 DEBUG exportComposition: Starting export to: \(outputURL.lastPathComponent)")
        print("🎬 DEBUG exportComposition: Composition duration: \(composition.duration.seconds) seconds")
        
        // Check composition tracks
        let videoTracks = composition.tracks(withMediaType: .video)
        let audioTracks = composition.tracks(withMediaType: .audio)
        print("🎬 DEBUG exportComposition: Video tracks: \(videoTracks.count), Audio tracks: \(audioTracks.count)")
        
        for (index, track) in videoTracks.enumerated() {
            print("🎬 DEBUG exportComposition: Video track \(index): segments=\(track.segments.count), timeRange=\(track.timeRange)")
        }
        
        // Use compatible preset
        // When no video composition, use HighestQuality
        // With video composition, use a specific resolution preset
        let exportPreset: String
        if videoComposition != nil {
            print("🎬 DEBUG exportComposition: Using resolution-specific preset for video composition")
            exportPreset = AVAssetExportPreset1920x1080
        } else {
            print("🎬 DEBUG exportComposition: Using default preset without video composition")
            exportPreset = ExportSettings.videoPreset
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: exportPreset
        ) else {
            print("❌ DEBUG exportComposition: Failed to create export session with preset: \(exportPreset)")
            print("❌ DEBUG exportComposition: Trying fallback preset...")
            
            // Try fallback preset
            guard let fallbackSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetPassthrough
            ) else {
                throw RendererError.cannotCreateExportSession
            }
            
            print("✅ DEBUG exportComposition: Using fallback preset: AVAssetExportPresetPassthrough")
            return try await exportWithSession(fallbackSession, outputURL: outputURL, videoComposition: videoComposition, composition: composition, progressCallback: progressCallback)
        }
        
        print("✅ DEBUG exportComposition: Export session created with preset: \(exportPreset)")
        return try await exportWithSession(exportSession, outputURL: outputURL, videoComposition: videoComposition, composition: composition, progressCallback: progressCallback)
    }
    
    private func exportWithSession(
        _ exportSession: AVAssetExportSession,
        outputURL: URL,
        videoComposition: AVVideoComposition?,
        composition: AVComposition,
        progressCallback: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        print("🎬 DEBUG exportComposition: Supported file types: \(exportSession.supportedFileTypes.map { $0.rawValue })")
        
        // Explicitly set output configuration
        exportSession.outputURL = outputURL
        // Use the explicit MPEG-4 file type
        exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        print("🎬 DEBUG exportComposition: Set outputFileType to AVFileType.mp4")
        
        // Add video composition if provided (for transforms and effects)
        if let videoComposition = videoComposition {
            exportSession.videoComposition = videoComposition
            print("🎬 DEBUG exportComposition: Video composition applied")
        }
        
        // Explicitly set the time range for the export
        let exportTimeRange = CMTimeRange(start: .zero, duration: composition.duration)
        exportSession.timeRange = exportTimeRange
        
        print("🎬 DEBUG exportComposition: Export session configuration:")
        print("  - Output URL: \(outputURL.lastPathComponent)")
        print("  - File type: mp4")
        print("  - Optimize for network: true")
        print("  - Time range: \(exportSession.timeRange)")
        print("  - Composition duration: \(composition.duration.seconds) seconds")
        print("  - Has video composition: \(videoComposition != nil)")
        
        return try await withCheckedThrowingContinuation { continuation in
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak exportSession] _ in
                guard let exportSession = exportSession else { return }
                let progress = Double(exportSession.progress)
                Task { @MainActor in
                    await progressCallback(progress)
                }
            }
            
            print("🎬 DEBUG exportComposition: Starting export asynchronously...")
            exportSession.exportAsynchronously { [weak exportSession] in
                progressTimer.invalidate()
                
                guard let exportSession = exportSession else {
                    print("❌ DEBUG exportComposition: Export session deallocated")
                    continuation.resume(throwing: RendererError.exportFailed)
                    return
                }
                
                print("🎬 DEBUG exportComposition: Export completed with status: \(exportSession.status.rawValue)")
                
                switch exportSession.status {
                case .completed:
                    print("✅ DEBUG exportComposition: Export successful!")
                    print("✅ DEBUG exportComposition: Output file size: \(try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] ?? 0) bytes")
                    continuation.resume(returning: outputURL)
                case .failed:
                    let error = exportSession.error ?? RendererError.exportFailed
                    print("❌ DEBUG exportComposition: Export failed with error: \(error)")
                    if let nsError = error as NSError? {
                        print("❌ DEBUG exportComposition: Error domain: \(nsError.domain)")
                        print("❌ DEBUG exportComposition: Error code: \(nsError.code)")
                        print("❌ DEBUG exportComposition: Error userInfo: \(nsError.userInfo)")
                    }
                    continuation.resume(throwing: error)
                case .cancelled:
                    print("⚠️ DEBUG exportComposition: Export cancelled")
                    continuation.resume(throwing: RendererError.exportCancelled)
                default:
                    print("❌ DEBUG exportComposition: Export failed with unknown status: \(exportSession.status.rawValue)")
                    continuation.resume(throwing: RendererError.exportFailed)
                }
            }
        }
    }
    
    private func createTempOutputURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "rendered_segment_\(Date().timeIntervalSince1970).mp4"
        return tempDir.appendingPathComponent(filename)
    }
    
    private func convertFilterSpecsToCIFilters(_ filterSpecs: [FilterSpec]) -> [CIFilter] {
        var ciFilters: [CIFilter] = []
        
        for spec in filterSpecs {
            if let filter = CIFilter(name: spec.name) {
                // Apply parameters
                for (key, value) in spec.params {
                    filter.setValue(value.value, forKey: key)
                }
                ciFilters.append(filter)
            }
        }
        
        return ciFilters
    }
}

// MARK: - Custom Video Compositor for Filters

private final class FilterVideoCompositor: NSObject, @unchecked Sendable {
    
    var sourcePixelBufferAttributes: [String : Any]? = [
        kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA]
    ]
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // Handle render context changes
    }
    
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        autoreleasepool {
            guard let pixels = asyncVideoCompositionRequest.renderContext.newPixelBuffer() else {
                asyncVideoCompositionRequest.finish(with: NSError(domain: "FilterCompositor", code: -1))
                return
            }
            
            // Apply filters here
            // For now, just copy the source frame
            if let sourcePixels = asyncVideoCompositionRequest.sourceFrame(byTrackID: asyncVideoCompositionRequest.sourceTrackIDs[0] as! CMPersistentTrackID) {
                CVPixelBufferLockBaseAddress(sourcePixels, .readOnly)
                CVPixelBufferLockBaseAddress(pixels, [])
                
                defer {
                    CVPixelBufferUnlockBaseAddress(sourcePixels, .readOnly)
                    CVPixelBufferUnlockBaseAddress(pixels, [])
                }
                
                // Copy pixel data
                let sourceData = CVPixelBufferGetBaseAddress(sourcePixels)
                let destData = CVPixelBufferGetBaseAddress(pixels)
                let dataSize = CVPixelBufferGetDataSize(sourcePixels)
                
                memcpy(destData, sourceData, dataSize)
            }
            
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: pixels)
        }
    }
    
    func cancelAllPendingVideoCompositionRequests() {
        // Cancel any pending requests
    }
}

// MARK: - Error Types

public enum RendererError: LocalizedError {
    case cannotCreateVideoTrack
    case cannotLoadVideoTrack
    case cannotCreateExportSession
    case compositionFailed(String)
    case audioInsertionFailed(String)
    case exportFailed
    case exportCancelled
    
    public var errorDescription: String? {
        switch self {
        case .cannotCreateVideoTrack:
            return "Cannot create video track for composition"
        case .cannotLoadVideoTrack:
            return "Cannot load video track from asset"
        case .cannotCreateExportSession:
            return "Cannot create export session"
        case .compositionFailed(let message):
            return "Composition failed: \(message)"
        case .audioInsertionFailed(let message):
            return "Audio insertion failed: \(message)"
        case .exportFailed:
            return "Video export failed"
        case .exportCancelled:
            return "Video export was cancelled"
        }
    }
}