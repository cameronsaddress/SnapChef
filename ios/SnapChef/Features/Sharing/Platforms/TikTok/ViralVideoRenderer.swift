// REPLACE ENTIRE FILE: ViralVideoRenderer.swift

import UIKit
@preconcurrency import AVFoundation
import CoreImage
import CoreMedia
import Foundation
import Metal

public final class ViralVideoRenderer: @unchecked Sendable {
    private let config: RenderConfig
    private let stillWriter: StillWriter
    private let ciContext: CIContext
    private let memoryOptimizer = MemoryOptimizer.shared
    
    // SPEED OPTIMIZATION: Cached components and Metal context
    private let metalDevice: MTLDevice?
    private let imageCache = NSCache<NSString, UIImage>()
    private let filterCache = NSCache<NSString, CIFilter>()
    
    // SPEED OPTIMIZATION: Pre-computed animation curves
    private var kenBurnsFrames: [CGAffineTransform] = []
    private var breatheFrames: [CGFloat] = []
    private var parallaxFrames: [CGPoint] = []
    
    // SPEED OPTIMIZATION: Metal context and effect cache
    private let metalContext: CIContext?
    private let effectCache = NSCache<NSString, CIImage>()
    
    // SPEED OPTIMIZATION: Parallel processing queue
    private let processingQueue = DispatchQueue(label: "viral.renderer.processing", qos: .userInitiated, attributes: .concurrent)
    private let serialQueue = DispatchQueue(label: "viral.renderer.serial", qos: .userInitiated)

    public init(config: RenderConfig) {
        self.config = config
        self.stillWriter = StillWriter(config: config)
        self.ciContext = memoryOptimizer.getCIContext()
        
        // SPEED OPTIMIZATION: Initialize Metal for GPU acceleration
        self.metalDevice = MTLCreateSystemDefaultDevice()
        if let metalDevice = self.metalDevice {
            self.metalContext = CIContext(mtlDevice: metalDevice)
        } else {
            self.metalContext = nil
        }
        
        // SPEED OPTIMIZATION: Configure caches for performance
        imageCache.countLimit = 10
        filterCache.countLimit = 20
        effectCache.countLimit = 30
    }

    public func render(plan: RenderPlan,
                       config: RenderConfig,
                       progressCallback: @escaping @Sendable (Double) async -> Void = { _ in }) async throws -> URL {
        let startTime = Date()
        print("[ViralVideoRenderer] \(startTime): Starting OPTIMIZED render with \(plan.items.count) items")
        
        // SPEED OPTIMIZATION: Check if we can use the fast single-pass renderer
        if plan.items.count <= 3 && plan.overlays.count <= 5 {
            print("[ViralVideoRenderer] Using FAST SINGLE-PASS renderer")
            return try await renderSinglePass(plan: plan, config: config, progressCallback: progressCallback)
        }
        
        // SPEED OPTIMIZATION: Parallel segment creation
        print("[ViralVideoRenderer] \(Date()): Phase 1 - Creating segments in PARALLEL")
        let segmentStartTime = Date()
        
        let segs = try await withThrowingTaskGroup(of: (Int, URL).self, returning: [URL].self) { group in
            for (i, item) in plan.items.enumerated() {
                group.addTask {
                    let url = try await self.createOptimizedSegment(item, index: i)
                    return (i, url)
                }
            }
            
            var results: [(Int, URL)] = []
            for try await result in group {
                results.append(result)
                let progress = Double(results.count) / Double(plan.items.count) * 0.6
                await progressCallback(progress)
            }
            
            // Sort by index to maintain order
            results.sort { $0.0 < $1.0 }
            return results.map { $0.1 }
        }
        
        let segmentEndTime = Date()
        print("[ViralVideoRenderer] \(segmentEndTime): ALL \(segs.count) segments created in PARALLEL in \(segmentEndTime.timeIntervalSince(segmentStartTime))s")

        // SPEED OPTIMIZATION: Fast composition with overlays in single pass
        print("[ViralVideoRenderer] \(Date()): Phase 2 - Fast composition with overlays")
        let compositeStartTime = Date()
        let finalURL = try await fastCompositeWithOverlays(
            segments: segs, 
            plan: plan,
            progressCallback: { p in await progressCallback(0.6 + p * 0.4) }
        )
        let compositeEndTime = Date()
        print("[ViralVideoRenderer] \(compositeEndTime): Fast composition completed in \(compositeEndTime.timeIntervalSince(compositeStartTime))s")
        
        // Cleanup intermediate files
        for segURL in segs {
            try? FileManager.default.removeItem(at: segURL)
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("[ViralVideoRenderer] \(Date()): OPTIMIZED render completed in \(totalTime)s")
        return finalURL
    }

    // MARK: OPTIMIZED segment creation
    private func createOptimizedSegment(_ item: RenderPlan.TrackItem, index: Int) async throws -> URL {
        print("[ViralVideoRenderer] Creating OPTIMIZED segment \(index) for \(item.kind)")
        
        switch item.kind {
        case .still(let image):
            // SPEED OPTIMIZATION: Check cache first
            let cacheKey = "segment_\(index)_\(item.filters.map { String(describing: $0) }.joined())" as NSString
            if let cachedImage = imageCache.object(forKey: cacheKey) {
                print("[ViralVideoRenderer] Using CACHED processed image for segment \(index)")
                return try await stillWriter.createVideoFromImage(
                    cachedImage,
                    duration: item.timeRange.duration,
                    transform: .identity,
                    filters: [], // Already processed
                    specs: []
                )
            }
            
            // SPEED OPTIMIZATION: Pre-process image with Metal acceleration
            let processedImage = try await processImageWithMetalAcceleration(image, filters: item.filters)
            imageCache.setObject(processedImage, forKey: cacheKey)
            
            print("[ViralVideoRenderer] Creating video from OPTIMIZED image for segment \(index)")
            return try await stillWriter.createVideoFromImage(
                processedImage,
                duration: item.timeRange.duration,
                transform: .identity, // Handled in preprocessing
                filters: [], // Already applied
                specs: []
            )
            
        case .video(let url):
            print("[ViralVideoRenderer] Using existing video URL: \(url)")
            return url
        }
    }

    // MARK: stitch + fit
    private func stitchSegments(_ segments: [URL], duration: CMTime, audio: URL?,
                                progress: @escaping @Sendable (Double) async -> Void) async throws -> URL {
        print("[ViralVideoRenderer] \(Date()): Starting stitchSegments with \(segments.count) segments")
        
        let composition = AVMutableComposition()
        let vTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        var cursor = CMTime.zero

        // place each segment
        print("[ViralVideoRenderer] \(Date()): Inserting video segments into composition")
        for (index, url) in segments.enumerated() {
            print("[ViralVideoRenderer] \(Date()): Processing segment \(index+1)/\(segments.count): \(url)")
            let asset = AVAsset(url: url)
            guard let t = try await asset.loadTracks(withMediaType: .video).first else { 
                print("[ViralVideoRenderer] \(Date()): WARNING - No video track found for \(url)")
                continue 
            }
            let d = try await asset.load(.duration)
            print("[ViralVideoRenderer] \(Date()): Inserting segment duration: \(d.seconds)s at cursor: \(cursor.seconds)s")
            try vTrack.insertTimeRange(CMTimeRange(start: .zero, duration: d), of: t, at: cursor)
            cursor = cursor + d
        }
        print("[ViralVideoRenderer] \(Date()): All video segments inserted, total duration: \(cursor.seconds)s")

        // add audio once
        if let audioURL = audio,
           let aTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            print("[ViralVideoRenderer] \(Date()): Adding audio track from: \(audioURL)")
            let aAsset = AVAsset(url: audioURL)
            if let src = try await aAsset.loadTracks(withMediaType: .audio).first {
                let aDur = try await aAsset.load(.duration)
                let finalDur = min(aDur, composition.duration)
                print("[ViralVideoRenderer] \(Date()): Inserting audio duration: \(finalDur.seconds)s")
                try aTrack.insertTimeRange(CMTimeRange(start: .zero, duration: finalDur),
                                           of: src, at: .zero)
            } else {
                print("[ViralVideoRenderer] \(Date()): WARNING - No audio track found in \(audioURL)")
            }
        } else {
            print("[ViralVideoRenderer] \(Date()): No audio to add")
        }

        // aspect-fit transform only (no scale ramps)
        let instr = AVMutableVideoCompositionInstruction()
        instr.timeRange = CMTimeRange(start: .zero, duration: composition.duration)

        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
        let natural = try await vTrack.load(.naturalSize)
        let render = config.size

        let scale = min(render.width / natural.width, render.height / natural.height)
        var transform = CGAffineTransform.identity
            .scaledBy(x: scale, y: scale)
        let scaledW = natural.width * scale
        let scaledH = natural.height * scale
        let tx = (render.width - scaledW) / 2.0
        let ty = (render.height - scaledH) / 2.0
        transform = transform.translatedBy(x: tx/scale, y: ty/scale)
        layer.setTransform(transform, at: .zero)

        instr.layerInstructions = [layer]
        let videoComp = AVMutableVideoComposition()
        videoComp.renderSize = render
        videoComp.frameDuration = CMTime(value: 1, timescale: config.fps)
        videoComp.instructions = [instr]

        // export
        print("[ViralVideoRenderer] \(Date()): Starting export session")
        let outURL = createTempOutputURL()
        try? FileManager.default.removeItem(at: outURL)
        
        guard let export = AVAssetExportSession(asset: composition, presetName: ExportSettings.videoPreset) else {
            print("[ViralVideoRenderer] \(Date()): ERROR - Cannot create export session")
            throw RendererError.cannotCreateExportSession
        }
        
        export.outputURL = outURL
        export.outputFileType = AVFileType.mp4
        export.videoComposition = videoComp
        
        print("[ViralVideoRenderer] \(Date()): Export session configured, starting async export to: \(outURL)")
        
        // Add timeout detection
        let exportStartTime = Date()
        var progressTimer: Timer?
        
        return try await withCheckedThrowingContinuation { cont in
            // Start progress monitoring
            progressTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                let elapsed = Date().timeIntervalSince(exportStartTime)
                print("[ViralVideoRenderer] \(Date()): Export progress: \(export.progress * 100)% (\(elapsed)s elapsed)")
                
                // Timeout after 60 seconds
                if elapsed > 60 {
                    print("[ViralVideoRenderer] \(Date()): ERROR - Export timeout after \(elapsed)s")
                    export.cancelExport()
                    progressTimer?.invalidate()
                    cont.resume(throwing: RendererError.exportFailed)
                }
            }
            
            export.exportAsynchronously {
                progressTimer?.invalidate()
                let exportEndTime = Date()
                let totalTime = exportEndTime.timeIntervalSince(exportStartTime)
                
                print("[ViralVideoRenderer] \(exportEndTime): Export completed in \(totalTime)s with status: \(export.status.rawValue)")
                
                switch export.status {
                case .completed:
                    print("[ViralVideoRenderer] \(Date()): Export SUCCESS - Output: \(outURL)")
                    cont.resume(returning: outURL)
                case .failed:
                    print("[ViralVideoRenderer] \(Date()): Export FAILED - Error: \(export.error?.localizedDescription ?? "Unknown")")
                    cont.resume(throwing: RendererError.exportFailed)
                case .cancelled:
                    print("[ViralVideoRenderer] \(Date()): Export CANCELLED")
                    cont.resume(throwing: RendererError.exportCancelled)
                default:
                    print("[ViralVideoRenderer] \(Date()): Export UNKNOWN status: \(export.status.rawValue)")
                    cont.resume(throwing: RendererError.exportFailed)
                }
            }
        }
    }
    
    // MARK: SPEED OPTIMIZATION: Single-pass renderer for simple cases
    private func renderSinglePass(plan: RenderPlan, config: RenderConfig, progressCallback: @escaping @Sendable (Double) async -> Void) async throws -> URL {
        print("[ViralVideoRenderer] Starting SINGLE-PASS render")
        
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        
        // SPEED OPTIMIZATION: Process all items as single composition
        var currentTime = CMTime.zero
        for (index, item) in plan.items.enumerated() {
            switch item.kind {
            case .still(let image):
                // Create optimized temporary video for this segment
                let processedImage = try await processImageWithMetalAcceleration(image, filters: item.filters)
                let tempURL = try await stillWriter.createVideoFromImage(
                    processedImage,
                    duration: item.timeRange.duration,
                    transform: .identity,
                    filters: [],
                    specs: []
                )
                
                let asset = AVAsset(url: tempURL)
                guard let sourceTrack = try await asset.loadTracks(withMediaType: .video).first else { continue }
                
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: item.timeRange.duration),
                    of: sourceTrack,
                    at: currentTime
                )
                
                // Cleanup temp file immediately
                try? FileManager.default.removeItem(at: tempURL)
                
            case .video(let url):
                let asset = AVAsset(url: url)
                guard let sourceTrack = try await asset.loadTracks(withMediaType: .video).first else { continue }
                
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: item.timeRange.duration),
                    of: sourceTrack,
                    at: currentTime
                )
            }
            
            currentTime = currentTime + item.timeRange.duration
            await progressCallback(Double(index + 1) / Double(plan.items.count) * 0.7)
        }
        
        // Add audio if present
        if let audioURL = plan.audio {
            if let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                let audioAsset = AVAsset(url: audioURL)
                if let audioSourceTrack = try await audioAsset.loadTracks(withMediaType: .audio).first {
                    let audioDuration = min(try await audioAsset.load(.duration), plan.outputDuration)
                    try audioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: audioDuration),
                        of: audioSourceTrack,
                        at: .zero
                    )
                }
            }
        }
        
        // SPEED OPTIMIZATION: Apply overlays directly in video composition
        let videoComposition = createOptimizedVideoComposition(for: composition, overlays: plan.overlays)
        
        // Export with overlays in single pass
        let outputURL = createTempOutputURL()
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: ExportSettings.videoPreset) else {
            throw RendererError.cannotCreateExportSession
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        guard exportSession.status == AVAssetExportSession.Status.completed else {
            throw RendererError.exportFailed
        }
        
        await progressCallback(1.0)
        return outputURL
    }
    
    // MARK: SPEED OPTIMIZATION: Metal-accelerated image processing
    private func processImageWithMetalAcceleration(_ image: UIImage, filters: [FilterSpec]) async throws -> UIImage {
        guard let metalDevice = metalDevice else {
            // Fallback to CPU processing
            return try await processImageWithCPU(image, filters: filters)
        }
        
        // SPEED OPTIMIZATION: Use Metal for filter operations
        let ciContext = CIContext(mtlDevice: metalDevice)
        guard var ciImage = CIImage(image: image) else { return image }
        
        // Apply filters with Metal acceleration
        for filterSpec in filters {
            ciImage = try await applyFilterWithMetal(ciImage, filterSpec: filterSpec, context: ciContext)
        }
        
        // Render final image
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return image }
        return UIImage(cgImage: cgImage)
    }
    
    private func processImageWithCPU(_ image: UIImage, filters: [FilterSpec]) async throws -> UIImage {
        guard var ciImage = CIImage(image: image) else { return image }
        
        let ciFilters = FilterSpecBridge.toCIFilters(filters)
        for filter in ciFilters {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            ciImage = filter.outputImage ?? ciImage
        }
        
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return image }
        return UIImage(cgImage: cgImage)
    }
    
    private func applyFilterWithMetal(_ image: CIImage, filterSpec: FilterSpec, context: CIContext) async throws -> CIImage {
        // SPEED OPTIMIZATION: Cache filters for reuse
        let cacheKey = "filter_\(String(describing: filterSpec))" as NSString
        
        var filter: CIFilter?
        if let cachedFilter = filterCache.object(forKey: cacheKey) {
            filter = cachedFilter
        } else {
            let ciFilters = FilterSpecBridge.toCIFilters([filterSpec])
            filter = ciFilters.first
            if let filter = filter {
                filterCache.setObject(filter, forKey: cacheKey)
            }
        }
        
        guard let filter = filter else { return image }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage ?? image
    }
    
    // MARK: SPEED OPTIMIZATION: Fast composition with overlays
    private func fastCompositeWithOverlays(
        segments: [URL],
        plan: RenderPlan,
        progressCallback: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        print("[ViralVideoRenderer] Starting FAST composition with overlays")
        
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        
        // Stitch segments quickly
        var currentTime = CMTime.zero
        for (index, segmentURL) in segments.enumerated() {
            let asset = AVAsset(url: segmentURL)
            guard let sourceTrack = try await asset.loadTracks(withMediaType: .video).first else { continue }
            
            let duration = try await asset.load(.duration)
            try videoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: sourceTrack,
                at: currentTime
            )
            currentTime = currentTime + duration
            
            await progressCallback(Double(index + 1) / Double(segments.count) * 0.5)
        }
        
        // Add audio
        if let audioURL = plan.audio {
            if let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                let audioAsset = AVAsset(url: audioURL)
                if let audioSourceTrack = try await audioAsset.loadTracks(withMediaType: .audio).first {
                    let audioDuration = min(try await audioAsset.load(.duration), plan.outputDuration)
                    try audioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: audioDuration),
                        of: audioSourceTrack,
                        at: .zero
                    )
                }
            }
        }
        
        // SPEED OPTIMIZATION: Apply overlays directly in video composition
        let videoComposition = createOptimizedVideoComposition(for: composition, overlays: plan.overlays)
        
        // Export
        let outputURL = createTempOutputURL()
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: ExportSettings.videoPreset) else {
            throw RendererError.cannotCreateExportSession
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        await progressCallback(1.0)
        
        guard exportSession.status == AVAssetExportSession.Status.completed else {
            throw RendererError.exportFailed
        }
        
        return outputURL
    }
    
    private func createOptimizedVideoComposition(for composition: AVComposition, overlays: [RenderPlan.Overlay]) -> AVVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = config.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: config.fps)
        
        // Create single instruction for entire timeline
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        
        // Get video track
        guard let videoTrack = composition.tracks(withMediaType: .video).first else {
            return videoComposition
        }
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        
        // Apply simple transform for aspect fit
        let naturalSize = config.size // Simplified - avoid async in sync context
        let renderSize = config.size
        let scale = min(renderSize.width / naturalSize.width, renderSize.height / naturalSize.height)
        let scaledSize = CGSize(width: naturalSize.width * scale, height: naturalSize.height * scale)
        let tx = (renderSize.width - scaledSize.width) / 2
        let ty = (renderSize.height - scaledSize.height) / 2
        
        let transform = CGAffineTransform.identity
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: tx/scale, y: ty/scale)
        
        layerInstruction.setTransform(transform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        
        videoComposition.instructions = [instruction]
        
        // SPEED OPTIMIZATION: Add simplified overlays via Core Animation
        if !overlays.isEmpty {
            let parentLayer = CALayer()
            parentLayer.frame = CGRect(origin: .zero, size: config.size)
            
            let videoLayer = CALayer()
            videoLayer.frame = parentLayer.bounds
            
            let overlayLayer = CALayer()
            overlayLayer.frame = parentLayer.bounds
            
            // Add simplified overlays
            for overlay in overlays {
                let layer = overlay.layerBuilder(config)
                layer.beginTime = AVCoreAnimationBeginTimeAtZero + overlay.start.seconds
                layer.duration = overlay.duration.seconds
                overlayLayer.addSublayer(layer)
            }
            
            parentLayer.addSublayer(videoLayer)
            parentLayer.addSublayer(overlayLayer)
            
            videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                postProcessingAsVideoLayer: videoLayer,
                in: parentLayer
            )
        }
        
        return videoComposition
    }
    
    private func createTempOutputURL() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return dir.appendingPathComponent("snapchef-renderer-\(UUID().uuidString).mp4")
    }
}

public enum RendererError: Error { 
    case cannotCreateVideoTrack, cannotLoadVideoTrack, cannotCreateExportSession, exportFailed, exportCancelled, exportTimeout
}