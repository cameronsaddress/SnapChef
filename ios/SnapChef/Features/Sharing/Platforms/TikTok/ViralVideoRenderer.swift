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
    
    /// Render base video from render plan track items
    public func renderBaseVideo(
        plan: RenderPlan,
        progressCallback: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        
        // Start performance monitoring
        performanceMonitor.markPhaseStart(.renderingFrames)
        memoryOptimizer.logMemoryProfile(phase: "Renderer Start")
        
        let outputURL = createTempOutputURL()
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create composition
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        guard let videoTrack = videoTrack else {
            throw RendererError.cannotCreateVideoTrack
        }
        
        // Process track items
        var currentTime = CMTime.zero
        var segmentURLs: [URL] = []
        
        for (index, item) in plan.items.enumerated() {
            let segmentURL = try await createSegmentForTrackItem(
                item,
                progressCallback: { segmentProgress in
                    let totalProgress = (Double(index) + segmentProgress) / Double(plan.items.count)
                    await progressCallback(totalProgress)
                }
            )
            
            segmentURLs.append(segmentURL)
            
            // Add segment to composition
            let asset = AVAsset(url: segmentURL)
            guard let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw RendererError.cannotLoadVideoTrack
            }
            
            do {
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: item.timeRange.duration),
                    of: assetVideoTrack,
                    at: currentTime
                )
                
                // Note: Transforms will be applied during video composition
                // Store transform info in the composition for later application
                
                currentTime = CMTimeAdd(currentTime, item.timeRange.duration)
            } catch {
                throw RendererError.compositionFailed(error.localizedDescription)
            }
        }
        
        // Add audio if provided
        if let audioURL = plan.audio,
           let audioTrack = audioTrack {
            try await addAudioTrack(audioURL: audioURL, to: audioTrack, duration: plan.outputDuration)
        }
        
        // Export composition
        let exportedURL = try await exportComposition(
            composition,
            outputURL: outputURL,
            progressCallback: progressCallback
        )
        
        // Clean up segment files immediately for memory optimization
        memoryOptimizer.deleteTempFiles(segmentURLs)
        
        // Complete performance monitoring
        performanceMonitor.markPhaseEnd(.renderingFrames)
        memoryOptimizer.logMemoryProfile(phase: "Renderer Complete")
        
        return exportedURL
    }
    
    /// Composite video with additional effects and filters
    public func compositeVideo(
        baseURL: URL,
        plan: RenderPlan
    ) async throws -> URL {
        
        let outputURL = createTempOutputURL()
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create asset from base video
        let asset = AVAsset(url: baseURL)
        
        // Create video composition for custom rendering
        let videoComposition = try await createVideoComposition(
            for: asset,
            plan: plan
        )
        
        // Export with video composition
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: ExportSettings.videoPreset
        ) else {
            throw RendererError.cannotCreateExportSession
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
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
    
    // MARK: - Private Implementation
    
    private func createSegmentForTrackItem(
        _ item: RenderPlan.TrackItem,
        progressCallback: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        
        switch item.kind {
        case .still(let image):
            return try await stillWriter.createVideoFromImage(
                image,
                duration: item.timeRange.duration,
                transform: item.transform,
                filters: item.filters,
                progressCallback: progressCallback
            )
            
        case .video(let url):
            // For video clips, we need to extract the segment and apply transforms/filters
            return try await processVideoSegment(
                url: url,
                timeRange: item.timeRange,
                transform: item.transform,
                filters: item.filters,
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
        
        let composition = AVMutableVideoComposition()
        composition.renderSize = config.size
        composition.frameDuration = CMTime(value: 1, timescale: config.fps)
        
        // Get video tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw RendererError.cannotLoadVideoTrack
        }
        
        // Create instruction for the entire duration
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: plan.outputDuration)
        
        // Create layer instruction
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        
        // Apply any transforms or effects here
        let trackTransform = try await videoTrack.load(.preferredTransform)
        layerInstruction.setTransform(trackTransform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]
        
        return composition
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
        
        // Loop audio if needed
        var currentTime = CMTime.zero
        while currentTime < duration {
            let remainingTime = CMTimeSubtract(duration, currentTime)
            let insertDuration = CMTimeMinimum(audioDuration, remainingTime)
            
            do {
                try audioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: insertDuration),
                    of: audioAssetTrack,
                    at: currentTime
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
        progressCallback: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: ExportSettings.videoPreset
        ) else {
            throw RendererError.cannotCreateExportSession
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
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
    
    private func createTempOutputURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "rendered_segment_\(Date().timeIntervalSince1970).mp4"
        return tempDir.appendingPathComponent(filename)
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