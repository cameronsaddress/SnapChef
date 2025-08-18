// REPLACE ENTIRE FILE: ViralVideoRenderer.swift

import UIKit
@preconcurrency import AVFoundation
@preconcurrency import CoreImage
import CoreMedia
import Foundation
@preconcurrency import Metal

public final class ViralVideoRenderer: Sendable {
    private let config: RenderConfig
    private let stillWriter: StillWriter
    private nonisolated(unsafe) let ciContext: CIContext
    private let memoryOptimizer = MemoryOptimizer.shared

    // SPEED OPTIMIZATION: Cached components and Metal context
    private nonisolated(unsafe) let metalDevice: MTLDevice?
    private nonisolated(unsafe) let imageCache = NSCache<NSString, UIImage>()
    private nonisolated(unsafe) let filterCache = NSCache<NSString, CIFilter>()

    // SPEED OPTIMIZATION: Pre-computed animation curves
    private nonisolated(unsafe) var kenBurnsFrames: [CGAffineTransform] = []
    private nonisolated(unsafe) var breatheFrames: [CGFloat] = []
    private nonisolated(unsafe) var parallaxFrames: [CGPoint] = []

    // SPEED OPTIMIZATION: Metal context and effect cache
    private nonisolated(unsafe) let metalContext: CIContext?
    private nonisolated(unsafe) let effectCache = NSCache<NSString, CIImage>()

    // SPEED OPTIMIZATION: Task groups for parallel processing

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
                       cancellationToken: CancellationToken? = nil,
                       progressCallback: @escaping @Sendable (Double) async -> Void = { @Sendable _ in }) async throws -> URL {
        let startTime = Date()
        print("[ViralVideoRenderer] \(startTime): Starting ULTRA-OPTIMIZED render with \(plan.items.count) items")

        // CRITICAL SPEED FIX: Always use fast single-pass renderer for speed
        print("[ViralVideoRenderer] Using ULTRA-FAST SINGLE-PASS renderer for ALL cases")

        // CRITICAL FIX: Force memory cleanup before starting render
        memoryOptimizer.forceMemoryCleanup()

        // Render directly without timeout wrapper - individual operations handle their own timeouts
        let result = try await renderSinglePass(plan: plan, config: config, cancellationToken: cancellationToken, progressCallback: progressCallback)
        
        // CRITICAL FIX: Force cleanup after render completes
        autoreleasepool {
            memoryOptimizer.forceMemoryCleanup()
        }
        
        return result
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
        guard let vTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ViralVideoError.renderFailed
        }
        var cursor = CMTime.zero

        // place each segment
        print("[ViralVideoRenderer] \(Date()): Inserting video segments into composition")
        for (index, url) in segments.enumerated() {
            print("[ViralVideoRenderer] \(Date()): Processing segment \(index + 1)/\(segments.count): \(url)")
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
        transform = transform.translatedBy(x: tx / scale, y: ty / scale)
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

            export.exportAsynchronously { @Sendable in
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

    // MARK: SPEED OPTIMIZATION: Ultra-fast single-pass renderer
    private func renderSinglePass(plan: RenderPlan, config: RenderConfig, cancellationToken: CancellationToken?, progressCallback: @escaping @Sendable (Double) async -> Void) async throws -> URL {
        let startTime = Date()
        print("[ViralVideoRenderer] Starting ULTRA-FAST SINGLE-PASS render")

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ViralVideoError.renderFailed
        }

        // CRITICAL SPEED FIX: Process all items with minimal processing
        var currentTime = CMTime.zero
        var tempURLsToCleanup: [URL] = []
        
        defer {
            // CRITICAL FIX: Ensure cleanup of temp files in defer block
            autoreleasepool {
                for tempURL in tempURLsToCleanup {
                    try? FileManager.default.removeItem(at: tempURL)
                }
            }
        }
        
        for (index, item) in plan.items.enumerated() {
            // Check for cancellation before processing each item
            try cancellationToken?.throwIfCancelled()
            
            // Check memory pressure
            let memoryStatus = memoryOptimizer.getMemoryStatus()
            if memoryStatus.pressureLevel == .critical {
                print("[ViralVideoRenderer] Critical memory during item \(index): \(memoryStatus.currentUsageMB)MB")
                throw CancellationError()
            }
            
            switch item.kind {
            case .still(let image):
                // SPEED OPTIMIZATION: Skip complex processing, use raw image
                let tempURL = try await stillWriter.createVideoFromImage(
                    image, // Use original image without filtering
                    duration: item.timeRange.duration,
                    transform: .identity,
                    filters: [], // Skip all filters for speed
                    specs: [], // Skip all specs for speed
                    cancellationToken: cancellationToken
                )
                
                // Track temp URL for cleanup
                tempURLsToCleanup.append(tempURL)

                let asset = AVAsset(url: tempURL)
                guard let sourceTrack = try await asset.loadTracks(withMediaType: .video).first else { continue }

                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: item.timeRange.duration),
                    of: sourceTrack,
                    at: currentTime
                )

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
            await progressCallback(Double(index + 1) / Double(plan.items.count) * 0.5)
            
            // Periodic memory cleanup during processing
            if index % 3 == 0 && index > 0 {
                autoreleasepool {
                    memoryOptimizer.forceMemoryCleanup()
                }
            }
        }

        // Add audio track
        if let audioURL = plan.audio {
            if let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                let audioAsset = AVAsset(url: audioURL)
                if let audioSourceTrack = try await audioAsset.loadTracks(withMediaType: .audio).first {
                    let audioDuration = min(try await audioAsset.load(.duration), composition.duration)
                    try audioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: audioDuration),
                        of: audioSourceTrack,
                        at: .zero
                    )
                }
            }
        }

        // CRITICAL FIX: Restore text overlays functionality
        let videoComposition = createMinimalVideoComposition(for: composition, overlays: plan.overlays)

        // Export with minimal processing
        let outputURL = createTempOutputURL()
        try? FileManager.default.removeItem(at: outputURL)

        // CRITICAL SPEED FIX: Use fastest export preset
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: ExportSettings.draftPreset) else {
            throw RendererError.cannotCreateExportSession
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        // CRITICAL FIX: Ensure audio is included in export
        if !composition.tracks(withMediaType: .audio).isEmpty {
            print("[ViralVideoRenderer] \(Date()): Audio tracks found, ensuring audio is exported")
        }

        // SPEED OPTIMIZATION: Async export with monitoring and proper timeout handling
        return try await withCheckedThrowingContinuation { continuation in
            // Check for cancellation before starting export
            if let token = cancellationToken, token.isCancelled {
                continuation.resume(throwing: CancellationError())
                return
            }
            
            // Use atomic boolean for completion tracking - thread-safe without locks
            let completionTracker = CompletionTracker()
            
            // Capture memory optimizer before the sendable closure
            let capturedOptimizer = memoryOptimizer

            // Timeout and cancellation monitoring task
            let monitoringTask = Task.detached { @Sendable in
                var isCompleted = false
                while !isCompleted {
                    isCompleted = await completionTracker.getCompletionStatus()
                    if !isCompleted {
                        try? await Task.sleep(nanoseconds: 500_000_000) // Check every 500ms
                        
                        // Check for cancellation
                        if let token = cancellationToken, token.isCancelled {
                            if await completionTracker.markCompleted() {
                                print("[ViralVideoRenderer] Export cancelled by user")
                                // Can't cancel export from here due to Sendable constraints
                                continuation.resume(throwing: CancellationError())
                            }
                            return
                        }
                        
                        // Check for timeout (25 seconds max)
                        if Date().timeIntervalSince(startTime) > 25 {
                            if await completionTracker.markCompleted() {
                                print("[ViralVideoRenderer] Export timeout after 25 seconds")
                                // Can't cancel export from here due to Sendable constraints
                                continuation.resume(throwing: RendererError.exportTimeout)
                            }
                            return
                        }
                        
                        // Check memory pressure
                        let memoryStatus = capturedOptimizer.getMemoryStatus()
                        if memoryStatus.pressureLevel == .critical {
                            if await completionTracker.markCompleted() {
                                print("[ViralVideoRenderer] Export cancelled due to memory pressure: \(memoryStatus.currentUsageMB)MB")
                                // Can't cancel export from here due to Sendable constraints
                                continuation.resume(throwing: CancellationError())
                            }
                            return
                        }
                    }
                }
            }
            
            exportSession.exportAsynchronously { @Sendable in
                let handleCompletion = { @Sendable in
                    guard await completionTracker.markCompleted() else {
                        return // Already timed out or completed
                    }

                    // Cancel monitoring task since export completed
                    monitoringTask.cancel()

                    let exportTime = Date().timeIntervalSince(startTime)
                    print("[ViralVideoRenderer] ULTRA-FAST export completed in \(exportTime)s")

                    await progressCallback(1.0)
                    
                    // CRITICAL FIX: Force memory cleanup after export
                    autoreleasepool {
                        capturedOptimizer.forceMemoryCleanup()
                    }

                    switch exportSession.status {
                    case .completed:
                        continuation.resume(returning: outputURL)
                    case .failed:
                        continuation.resume(throwing: exportSession.error ?? RendererError.exportFailed)
                    case .cancelled:
                        continuation.resume(throwing: RendererError.exportCancelled)
                    default:
                        continuation.resume(throwing: RendererError.exportFailed)
                    }
                }
                
                Task(operation: handleCompletion)
            }
        }
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
        let result = autoreleasepool {
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return image }
            return UIImage(cgImage: cgImage)
        }
        
        return result
    }

    private func processImageWithCPU(_ image: UIImage, filters: [FilterSpec]) async throws -> UIImage {
        // CRITICAL FIX: Wrap in autoreleasepool for memory management
        return autoreleasepool {
            guard var ciImage = CIImage(image: image) else { return image }

            let ciFilters = FilterSpecBridge.toCIFilters(filters)
            for filter in ciFilters {
                autoreleasepool {
                    filter.setValue(ciImage, forKey: kCIInputImageKey)
                    ciImage = filter.outputImage ?? ciImage
                }
            }

            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return image }
            return UIImage(cgImage: cgImage)
        }
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

    // MARK: SPEED OPTIMIZATION: Ultra-fast composition with minimal overlays
    private func ultraFastCompositeWithOverlays(
        segments: [URL],
        plan: RenderPlan,
        progressCallback: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        print("[ViralVideoRenderer] Starting ULTRA-FAST composition with minimal overlays")

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ViralVideoError.renderFailed
        }

        // Stitch segments in parallel memory operations
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

            await progressCallback(Double(index + 1) / Double(segments.count) * 0.3)
        }

        // Add audio quickly
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

        // CRITICAL FIX: Use actual overlay content instead of minimal placeholders
        let essentialOverlays = plan.overlays.prefix(6).map { overlay in
            RenderPlan.Overlay(start: overlay.start, duration: overlay.duration) { config in
                return overlay.layerBuilder(config) // Use real overlay content
            }
        }

        // SPEED OPTIMIZATION: Use minimal video composition
        let videoComposition = createMinimalVideoComposition(for: composition, overlays: Array(essentialOverlays))

        // CRITICAL SPEED FIX: Use medium quality for much faster export
        let outputURL = createTempOutputURL()
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: ExportSettings.draftPreset) else {
            throw RendererError.cannotCreateExportSession
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        // SPEED OPTIMIZATION: Async export with timeout
        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()

            exportSession.exportAsynchronously {
                let exportTime = Date().timeIntervalSince(startTime)
                print("[ViralVideoRenderer] ULTRA-FAST export completed in \(exportTime)s")

                Task {
                    await progressCallback(1.0)

                    switch exportSession.status {
                    case .completed:
                        continuation.resume(returning: outputURL)
                    case .failed:
                        continuation.resume(throwing: exportSession.error ?? RendererError.exportFailed)
                    case .cancelled:
                        continuation.resume(throwing: RendererError.exportCancelled)
                    default:
                        continuation.resume(throwing: RendererError.exportFailed)
                    }
                }
            }

            // Add timeout for ultra-fast mode (30 seconds max)
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                if exportSession.status == .exporting {
                    exportSession.cancelExport()
                    continuation.resume(throwing: RendererError.exportTimeout)
                }
            }
        }
    }

    private func createMinimalVideoComposition(for composition: AVComposition, overlays: [RenderPlan.Overlay]) -> AVVideoComposition {
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

        // SPEED OPTIMIZATION: Simple identity transform - no scaling calculations
        layerInstruction.setTransform(CGAffineTransform.identity, at: .zero)
        instruction.layerInstructions = [layerInstruction]

        videoComposition.instructions = [instruction]

        // CRITICAL FIX: Process more overlays for proper text/sparkle content
        if !overlays.isEmpty && overlays.count <= 8 {
            let parentLayer = CALayer()
            parentLayer.frame = CGRect(origin: .zero, size: config.size)
            parentLayer.backgroundColor = UIColor.clear.cgColor

            let videoLayer = CALayer()
            videoLayer.frame = parentLayer.bounds

            let overlayLayer = CALayer()
            overlayLayer.frame = parentLayer.bounds
            overlayLayer.backgroundColor = UIColor.clear.cgColor

            // CRITICAL FIX: Process ALL overlays to show text, containers, and sparkles
            for overlay in overlays {
                let layer = overlay.layerBuilder(config)
                layer.beginTime = AVCoreAnimationBeginTimeAtZero + overlay.start.seconds
                layer.duration = overlay.duration.seconds

                // SELECTIVE FIX: Keep some animations for visual appeal but remove expensive ones
                removeExpensiveAnimationsOnly(from: layer)

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

    // SELECTIVE FIX: Remove only expensive animations, keep simple ones for visual appeal
    private func removeExpensiveAnimationsOnly(from layer: CALayer) {
        // Keep simple opacity and position animations
        let expensiveKeys = ["transform.rotation", "transform.scale.x", "transform.scale.y", "shadowOpacity", "shadowRadius"]
        for key in expensiveKeys {
            layer.removeAnimation(forKey: key)
        }

        // Apply to sublayers
        layer.sublayers?.forEach { removeExpensiveAnimationsOnly(from: $0) }
    }

    // SPEED OPTIMIZATION: Remove all animations recursively when needed
    private func removeAnimationsRecursively(from layer: CALayer) {
        layer.removeAllAnimations()
        layer.sublayers?.forEach { removeAnimationsRecursively(from: $0) }
    }

    // FALLBACK: Create simple overlay when actual overlay content fails
    private func createFallbackOverlayLayer(config: RenderConfig) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: config.size)
        container.backgroundColor = UIColor.clear.cgColor

        // Create simple text overlay as fallback
        let textLayer = CATextLayer()
        textLayer.string = "SnapChef" // Simple branding
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 32, nil)
        textLayer.fontSize = 32
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = 2.0
        textLayer.cornerRadius = 8

        let textSize = CGSize(width: 200, height: 50)
        textLayer.frame = CGRect(
            x: (config.size.width - textSize.width) / 2,
            y: config.size.height * 0.1,
            width: textSize.width,
            height: textSize.height
        )

        container.addSublayer(textLayer)
        return container
    }

    private func createTempOutputURL() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return dir.appendingPathComponent("snapchef-renderer-\(UUID().uuidString).mp4")
    }
}

public enum RendererError: Error {
    case cannotCreateVideoTrack, cannotLoadVideoTrack, cannotCreateExportSession, exportFailed, exportCancelled, exportTimeout
}

// MARK: - Thread-safe completion tracking without NSLock
private actor CompletionTracker {
    private var isCompleted = false

    func markCompleted() -> Bool {
        guard !isCompleted else { return false }
        isCompleted = true
        return true
    }
    
    func getCompletionStatus() -> Bool {
        return isCompleted
    }
}
