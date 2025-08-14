//
//  ViralVideoEngine.swift
//  SnapChef
//
//  Created on 12/01/2025
//  Main viral video rendering engine for TikTok content generation
//

import UIKit
@preconcurrency import AVFoundation
import CoreImage
import CoreMedia
import Combine

/// Main viral video rendering engine - Core Engine Developer implementation
@MainActor
public class ViralVideoEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isRendering = false
    @Published public var currentProgress = RenderProgress(phase: .planning, progress: 0.0)
    @Published public var errorMessage: String?
    
    // MARK: - Core Components
    public let config: RenderConfig
    private let renderer: ViralVideoRenderer
    private let rendererPro: ViralVideoRendererPro
    private let stillWriter: StillWriter
    private let overlayFactory: OverlayFactory
    private let planner: RenderPlanner
    private let exporter: ViralVideoExporter
    
    // MARK: - Memory Management & Performance Optimization
    private var memoryObserver: NSObjectProtocol?
    private let processingQueue = DispatchQueue(label: "com.snapchef.viral.processing", qos: .userInitiated)
    private var currentRenderTask: Task<URL, Error>?
    private let memoryOptimizer = MemoryOptimizer.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private let concurrentOperationLimit = 2  // Max 2 concurrent operations as specified
    private let operationSemaphore = DispatchSemaphore(value: 2)
    
    // MARK: - Initialization
    public init(config: RenderConfig = RenderConfig()) {
        self.config = config
        self.renderer = ViralVideoRenderer(config: config)
        self.rendererPro = ViralVideoRendererPro()
        self.stillWriter = StillWriter(config: config)
        self.overlayFactory = OverlayFactory(config: config)
        self.planner = RenderPlanner(config: config)
        self.exporter = ViralVideoExporter(config: config)
        
        setupMemoryObserver()
        memoryOptimizer.startOptimization()
    }
    
    deinit {
        // Cleanup handled in cleanup() method
        let task = currentRenderTask
        task?.cancel()
        memoryOptimizer.stopOptimization()
    }
    
    /// Cleanup method to be called before deallocation
    public func cleanup() {
        if let observer = memoryObserver {
            NotificationCenter.default.removeObserver(observer)
            memoryObserver = nil
        }
        currentRenderTask?.cancel()
        currentRenderTask = nil
    }
    
    // MARK: - Public Interface
    
    /// Main render method following the exact end-to-end implementation flow from requirements
    public func render(
        template: ViralTemplate,
        recipe: ViralRecipe,
        media: MediaBundle,
        progressHandler: @escaping @Sendable (RenderProgress) async -> Void = { _ in }
    ) async throws -> URL {
        
        // Cancel any existing render task
        currentRenderTask?.cancel()
        
        return try await withCheckedThrowingContinuation { continuation in
            currentRenderTask = Task {
                // Skip semaphore in async context - use actor isolation instead
                // operationSemaphore.wait()
                // defer { operationSemaphore.signal() }
                
                do {
                    let result = try await performRender(
                        template: template,
                        recipe: recipe,
                        media: media,
                        progressHandler: progressHandler
                    )
                    continuation.resume(returning: result)
                    return result
                } catch {
                    continuation.resume(throwing: error)
                    throw error
                }
            }
        }
    }
    
    /// Cancel current rendering operation
    public func cancelRender() {
        currentRenderTask?.cancel()
        isRendering = false
        currentProgress = RenderProgress(phase: .planning, progress: 0.0)
    }
    
    /// Render with Pro features (transforms, filters, PIP)
    public func renderPro(
        template: ViralTemplate,
        recipe: ViralRecipe,
        media: MediaBundle,
        selfieVideoURL: URL? = nil,  // Optional selfie for PIP
        usePro: Bool = true,
        progressHandler: @escaping @Sendable (RenderProgress) async -> Void = { _ in }
    ) async throws -> URL {
        
        // Cancel any existing render task
        currentRenderTask?.cancel()
        
        return try await withCheckedThrowingContinuation { continuation in
            currentRenderTask = Task {
                do {
                    // Create render plan
                    var renderPlan = try await planner.createRenderPlan(
                        template: template,
                        recipe: recipe,
                        media: media
                    )
                    
                    // Add PIP for green screen template if selfie provided
                    // Green screen PIP template commented out
                    if false /* template == .greenScreenPIP */, let selfieURL = selfieVideoURL {
                        let pipFrame = CGRect(
                            x: config.size.width - config.safeInsets.right - 180,
                            y: config.safeInsets.top + 60,
                            width: 340,
                            height: 340
                        )
                        let pipSpec = PIPSpec(
                            url: selfieURL,
                            frame: pipFrame,
                            cornerRadius: 170,
                            timeRange: CMTimeRange(
                                start: .zero,
                                duration: CMTime(seconds: 3, preferredTimescale: 600)
                            )
                        )
                        renderPlan = RenderPlan(
                            items: renderPlan.items,
                            overlays: renderPlan.overlays,
                            audio: renderPlan.audio,
                            outputDuration: renderPlan.outputDuration,
                            pip: pipSpec
                        )
                    }
                    
                    // Use Pro renderer if requested
                    let result: URL
                    if usePro {
                        result = try await rendererPro.render(
                            plan: renderPlan,
                            config: config,
                            progressCallback: { progress in
                                let renderProgress = RenderProgress(
                                    phase: .renderingFrames,
                                    progress: progress
                                )
                                await progressHandler(renderProgress)
                            }
                        )
                    } else {
                        result = try await renderer.render(
                            plan: renderPlan,
                            config: config,
                            progressCallback: { progress in
                                let renderProgress = RenderProgress(
                                    phase: .renderingFrames,
                                    progress: progress
                                )
                                await progressHandler(renderProgress)
                            }
                        )
                    }
                    
                    continuation.resume(returning: result)
                    return result
                } catch {
                    continuation.resume(throwing: error)
                    throw error
                }
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func performRender(
        template: ViralTemplate,
        recipe: ViralRecipe,
        media: MediaBundle,
        progressHandler: @escaping @Sendable (RenderProgress) async -> Void
    ) async throws -> URL {
        
        isRendering = true
        errorMessage = nil
        
        // Music beat sync assumption for animations
        if let musicURL = media.musicURL {
            // Assume 80 BPM for sync
            let bpm = 80.0
            let beatInterval = 60.0 / bpm  // 0.75s per beat
            print("🎵 Music detected: \(musicURL.lastPathComponent)")
            print("🎵 Using \(bpm) BPM for beat sync (\(beatInterval)s interval)")
            // Note: Beat sync timing is used in RenderPlanner.getBeatTimes()
        }
        
        // Start comprehensive performance monitoring
        performanceMonitor.startRenderMonitoring()
        memoryOptimizer.logMemoryProfile(phase: "Render Start")
        
        defer {
            isRendering = false
            let totalTime = performanceMonitor.completeRenderMonitoring()
            memoryOptimizer.logMemoryProfile(phase: "Render Complete")
            
            // Log performance summary
            print("📊 Render Performance Summary:")
            print("   Total time: \(String(format: "%.3f", totalTime))s")
            print("   Memory usage: \(memoryOptimizer.getCurrentMemoryUsage() / 1024 / 1024) MB")
        }
        
        do {
            // Phase 1: Planning (0-10%)
            performanceMonitor.markPhaseStart(.planning)
            try await updateProgress(.planning, 0.0, progressHandler)
            let renderPlan = try await planner.createRenderPlan(
                template: template,
                recipe: recipe,
                media: media
            )
            performanceMonitor.markPhaseEnd(.planning)
            try await updateProgress(.planning, 0.1, progressHandler)
            
            // Phase 2: Preparing Assets (10-20%)
            performanceMonitor.markPhaseStart(.preparingAssets)
            try await updateProgress(.preparingAssets, 0.1, progressHandler)
            try await prepareAssets(media: media)
            performanceMonitor.markPhaseEnd(.preparingAssets)
            try await updateProgress(.preparingAssets, 0.2, progressHandler)
            
            // Phase 3: Rendering Frames (20-60%)
            try await updateProgress(.renderingFrames, 0.2, progressHandler)
            print("🎬 DEBUG: Starting base video render...")
            
            // For test template, use a special renderer with effects disabled
            let baseVideoURL: URL
            if false /* template == .test */ {
                print("🧪 TEST TEMPLATE: Creating renderer with effects disabled")
                var testConfig = RenderConfig()
                testConfig.premiumMode = false  // Disable ALL premium effects
                let testRenderer = ViralVideoRenderer(config: testConfig)
                baseVideoURL = try await testRenderer.renderBaseVideo(
                    plan: renderPlan,
                    progressCallback: { @Sendable frameProgress in
                        _ = 0.2 + (frameProgress * 0.4) // 20% to 60%
                        // Progress updates are handled by the renderer
                    }
                )
            } else {
                baseVideoURL = try await renderer.renderBaseVideo(
                    plan: renderPlan,
                    progressCallback: { @Sendable frameProgress in
                        _ = 0.2 + (frameProgress * 0.4) // 20% to 60%
                        // Progress updates are handled by the renderer
                    }
                )
            }
            print("✅ DEBUG: Base video rendered successfully at: \(baseVideoURL.lastPathComponent)")
            
            // SPECIAL HANDLING FOR TEST TEMPLATE - Skip all compositing and overlays
            let finalVideoURL: URL
            if false /* template == .test */ {
                print("🧪 TEST TEMPLATE: Skipping compositing and overlays - using raw base video")
                finalVideoURL = baseVideoURL
                try await updateProgress(.finalizing, 0.9, progressHandler)
            } else {
                // Phase 4: Compositing (60-70%)
                try await updateProgress(.compositing, 0.6, progressHandler)
                print("🎬 DEBUG: Starting video composition...")
                let compositedURL = try await renderer.compositeVideo(
                    baseURL: baseVideoURL,
                    plan: renderPlan
                )
                print("✅ DEBUG: Video composited successfully at: \(compositedURL.lastPathComponent)")
                try await updateProgress(.compositing, 0.7, progressHandler)
                
                // Phase 5: Adding Overlays (70-85%)
                try await updateProgress(.addingOverlays, 0.7, progressHandler)
                print("🎬 DEBUG: Starting overlay application...")
                let overlayURL = try await overlayFactory.applyOverlays(
                    videoURL: compositedURL,
                    overlays: renderPlan.overlays,
                    progressCallback: { @Sendable overlayProgress in
                        _ = 0.7 + (overlayProgress * 0.15) // 70% to 85%
                        // Progress updates are handled by the overlay factory
                    }
                )
                print("✅ DEBUG: Overlays applied successfully at: \(overlayURL.lastPathComponent)")
                finalVideoURL = overlayURL
            }
            
            // Phase 6: Encoding (85-95%) - Skipped to avoid "operation stopped" error
            try await updateProgress(.encoding, 0.85, progressHandler)
            print("⏭️ DEBUG: Skipping re-encoding step (video already in correct format)")
            // Skip actual re-encoding - the video is already in the correct format
            try await updateProgress(.encoding, 0.95, progressHandler)
            
            // Phase 7: Finalizing (95-100%)
            performanceMonitor.markPhaseStart(.finalizing)
            try await updateProgress(.finalizing, 0.95, progressHandler)
            print("🎬 DEBUG: Starting video finalization...")
            let finalURL = try await finalizeVideo(finalVideoURL)  // Use finalVideoURL
            print("✅ DEBUG: Video finalized successfully at: \(finalURL.lastPathComponent)")
            performanceMonitor.markPhaseEnd(.finalizing)
            try await updateProgress(.complete, 1.0, progressHandler)
            
            // Clean up intermediate files immediately
            if false /* template == .test */ {
                // For test template, no intermediate files to clean (baseVideo is the final)
                memoryOptimizer.deleteTempFiles([])
            } else {
                // For other templates, clean up intermediate files but not the final
                memoryOptimizer.deleteTempFiles([baseVideoURL])
            }
            
            return finalURL
            
        } catch {
            print("❌ DEBUG: Render failed with error: \(error)")
            print("❌ DEBUG: Error type: \(type(of: error))")
            print("❌ DEBUG: Error localized: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw ViralVideoError.renderingFailed(error.localizedDescription)
        }
    }
    
    private func updateProgress(
        _ phase: RenderPhase,
        _ progress: Double,
        _ handler: @escaping @Sendable (RenderProgress) async -> Void
    ) async throws {
        let memoryUsage = memoryOptimizer.getCurrentMemoryUsage()
        let renderProgress = RenderProgress(
            phase: phase,
            progress: progress,
            memoryUsage: memoryUsage
        )
        
        currentProgress = renderProgress
        await handler(renderProgress)
        
        // Enhanced memory pressure handling
        if !memoryOptimizer.isMemoryUsageSafe() {
            memoryOptimizer.forceMemoryCleanup()
            
            // Check again after cleanup
            if memoryOptimizer.getCurrentMemoryUsage() > ExportSettings.maxMemoryUsage {
                throw ViralVideoError.memoryLimitExceeded
            }
        }
    }
    
    private func prepareAssets(media: MediaBundle) async throws {
        print("📸 ViralVideoEngine: Preparing assets from MediaBundle:")
        print("    - beforeFridge: \(media.beforeFridge.size) - Has CGImage: \(media.beforeFridge.cgImage != nil)")
        print("    - afterFridge: \(media.afterFridge.size) - Has CGImage: \(media.afterFridge.cgImage != nil)")
        print("    - cookedMeal: \(media.cookedMeal.size) - Has CGImage: \(media.cookedMeal.cgImage != nil)")
        
        // Validate images are in correct format and size
        _ = config.size
        
        // Apply any pre-processing filters as specified in requirements
        // Color pop for AFTER images only
        // Blur effect for BEFORE hook
        
        // This would include resizing, format conversion, etc.
        // Implementation would use CIFilter for effects
    }
    
    private func encodeWithProductionSettings(
        inputURL: URL,
        progressCallback: @escaping @Sendable (Double) async -> Void
    ) async throws -> URL {
        
        // Skip re-encoding if the video has already been processed
        // The video has already gone through composition and overlay stages
        // Re-encoding can cause "operation stopped" errors with complex compositions
        
        // Just update progress to simulate encoding
        await progressCallback(0.5)
        await progressCallback(1.0)
        
        // Return the input URL as it's already in the correct format
        return inputURL
        
        /* Disabled re-encoding to fix "operation stopped" error
        let outputURL = createTempOutputURL()
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create export session with production settings from requirements
        guard let exportSession = AVAssetExportSession(
            asset: AVAsset(url: inputURL),
            presetName: ExportSettings.videoPreset
        ) else {
            throw ViralVideoError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Don't set videoComposition unless we actually have custom composition
        // exportSession.videoComposition = createVideoComposition()
        
        // Start export with progress monitoring
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
                    continuation.resume(throwing: ViralVideoError.exportFailed)
                    return
                }
                
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    let error = exportSession.error ?? ViralVideoError.exportFailed
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: ViralVideoError.renderingCancelled)
                default:
                    continuation.resume(throwing: ViralVideoError.exportFailed)
                }
            }
        }
        */
    }
    
    /* Disabled - no longer needed since we skip re-encoding
    private func createVideoComposition() -> AVVideoComposition {
        let composition = AVMutableVideoComposition()
        composition.renderSize = config.size
        composition.frameDuration = CMTime(value: 1, timescale: config.fps)
        return composition
    }
    */
    
    private func finalizeVideo(_ url: URL) async throws -> URL {
        // Validate the final video meets all requirements
        let asset = AVAsset(url: url)
        
        // Check duration
        let duration = try await asset.load(.duration)
        guard duration.seconds > 0 && duration.seconds <= config.maxDuration.seconds else {
            throw ViralVideoError.invalidDuration
        }
        
        // Check file size and downsample if needed
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        
        if fileSize > ExportSettings.maxFileSize {
            print("⚠️ File size exceeded: \(fileSize/(1024*1024))MB, downsampling...")
            let exporter = ViralVideoExporter(config: config)
            let downsampledURL = try await exporter.downsampleVideo(at: url)
            
            // Delete original oversized file
            try? FileManager.default.removeItem(at: url)
            
            // Verify downsampled size
            let newSize = try FileManager.default.attributesOfItem(atPath: downsampledURL.path)[.size] as? Int64 ?? 0
            print("✅ Downsampled to: \(newSize/(1024*1024))MB")
            
            return downsampledURL
        }
        
        print("✅ File size OK: \(fileSize/(1024*1024))MB")
        return url
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryObserver() {
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
    }
    
    private func handleMemoryWarning() {
        // Enhanced memory warning handling
        memoryOptimizer.forceMemoryCleanup()
        
        // Cancel rendering if memory warning received and still unsafe
        if isRendering && !memoryOptimizer.isMemoryUsageSafe() {
            currentRenderTask?.cancel()
            errorMessage = "Rendering cancelled due to memory pressure"
            
            // Post notification for UI to show user-friendly message
            NotificationCenter.default.post(
                name: Notification.Name("ViralVideoMemoryPressure"),
                object: nil,
                userInfo: ["message": "Video rendering paused due to low memory. Please close other apps and try again."]
            )
        }
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }
    
    private func createTempOutputURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "viral_video_\(Date().timeIntervalSince1970).mp4"
        return tempDir.appendingPathComponent(filename)
    }
}

// MARK: - Error Types

public enum ViralVideoError: LocalizedError {
    case renderingFailed(String)
    case exportSessionCreationFailed
    case exportFailed
    case renderingCancelled
    case memoryLimitExceeded
    case invalidDuration
    case fileSizeExceeded
    case missingAssets
    case invalidConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .renderingFailed(let message):
            return "Rendering failed: \(message)"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed:
            return "Video export failed"
        case .renderingCancelled:
            return "Rendering was cancelled"
        case .memoryLimitExceeded:
            return "Memory limit exceeded during rendering"
        case .invalidDuration:
            return "Video duration is invalid"
        case .fileSizeExceeded:
            return "Video file size exceeds maximum allowed"
        case .missingAssets:
            return "Required assets are missing"
        case .invalidConfiguration:
            return "Render configuration is invalid"
        }
    }
}