//
//  StillWriter.swift
//  SnapChef
//
//  Created on 12/01/2025
//  Image to video conversion with AVFoundation as specified in requirements
//

import UIKit
@preconcurrency import AVFoundation
@preconcurrency import CoreImage
@preconcurrency import CoreMedia
@preconcurrency import VideoToolbox

// Helper class for mutable capture in closures
private final class Box<T>: @unchecked Sendable {
    var value: T
    init(value: T) {
        self.value = value
    }
}


/// StillWriter for image→video conversion with performance optimization
public final class StillWriter: @unchecked Sendable {
    
    private let config: RenderConfig
    private let ciContext: CIContext
    private var pixelBufferPool: CVPixelBufferPool?
    private let memoryOptimizer = MemoryOptimizer.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private let frameDropMonitor = FrameDropMonitor.shared
    
    // MARK: - Initialization
    
    public init(config: RenderConfig) {
        self.config = config
        
        // Use shared CIContext from MemoryOptimizer for better performance
        self.ciContext = memoryOptimizer.getCIContext()
        
        setupPixelBufferPool()
    }
    
    // MARK: - Public Interface
    
    /// Convert image to video segment with specified duration and transforms
    public func createVideoFromImage(
        _ image: UIImage,
        duration: CMTime,
        transform: CGAffineTransform = .identity,
        filters: [CIFilter] = [],
        progressCallback: @escaping @Sendable (Double) async -> Void = { _ in }
    ) async throws -> URL {
        
        // Start performance monitoring
        let totalFrames = Int(duration.seconds * Double(config.fps))
        performanceMonitor.markPhaseStart(.renderingFrames)
        frameDropMonitor.startMonitoring(expectedFrames: totalFrames)
        memoryOptimizer.logMemoryProfile(phase: "StillWriter Start")
        
        let outputURL = createTempOutputURL()
        print("📝 DEBUG StillWriter[createVideoFromImage]: Starting for output: \(outputURL.lastPathComponent)")
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create video writer
        let videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // Configure video settings with exact specifications from requirements
        let videoSettings = createVideoSettings()
        print("📝 DEBUG StillWriter: Video settings: \(videoSettings)")
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        // Don't apply transform here - let the video composition handle it
        // videoInput.transform = transform
        print("📝 DEBUG StillWriter: Transform will be handled by video composition, not applying to input")
        
        // Create pixel buffer adaptor
        let bufferAttributes = createPixelBufferAttributes()
        print("📝 DEBUG StillWriter: Pixel buffer attributes: \(bufferAttributes)")
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: bufferAttributes
        )
        
        guard videoWriter.canAdd(videoInput) else {
            print("❌ DEBUG StillWriter: Cannot add video input to writer")
            throw StillWriterError.cannotAddVideoInput
        }
        
        videoWriter.add(videoInput)
        
        // Start writing session
        guard videoWriter.startWriting() else {
            let error = videoWriter.error
            print("❌ DEBUG StillWriter: Failed to start writing")
            print("❌ DEBUG StillWriter: Error: \(String(describing: error))")
            if let error = error as NSError? {
                print("❌ DEBUG StillWriter: Error domain: \(error.domain)")
                print("❌ DEBUG StillWriter: Error code: \(error.code)")
                print("❌ DEBUG StillWriter: Error userInfo: \(error.userInfo)")
            }
            throw StillWriterError.cannotStartWriting(videoWriter.error?.localizedDescription)
        }
        
        videoWriter.startSession(atSourceTime: .zero)
        print("✅ DEBUG StillWriter: Writing session started")
        
        // Calculate frame parameters
        _ = CMTime(value: 1, timescale: config.fps)  // Frame duration for reference
        
        // Log the input image details
        print("📸 StillWriter: Processing image:")
        print("    - Original size: \(image.size)")
        print("    - Has CGImage: \(image.cgImage != nil)")
        print("    - Has CIImage: \(image.ciImage != nil)")
        print("    - Image object: \(image)")
        
        // Optimize image for processing to reduce memory usage
        let optimizedUIImage = memoryOptimizer.optimizeImageForProcessing(image, targetSize: config.size)
        
        print("📸 StillWriter: After optimization:")
        print("    - Optimized size: \(optimizedUIImage.size)")
        print("    - Target size: \(config.size)")
        
        // Prepare CIImage with filters applied
        // IMPORTANT: CIImage(image:) can fail to preserve pixel data. 
        // We must create CIImage from CGImage to ensure pixels are preserved
        let ciImage: CIImage
        if let cgImage = optimizedUIImage.cgImage {
            // Create CIImage directly from CGImage for reliable pixel data
            ciImage = CIImage(cgImage: cgImage)
        } else if let existingCIImage = optimizedUIImage.ciImage {
            // Use existing CIImage if available
            ciImage = existingCIImage
        } else {
            // Last resort: try the standard initializer
            guard let fallbackCIImage = CIImage(image: optimizedUIImage) else {
                throw StillWriterError.imageConversionFailed
            }
            ciImage = fallbackCIImage
        }
        
        // Debug: Verify CIImage extent is valid
        print("📝 DEBUG StillWriter: CIImage extent: \(ciImage.extent), size: \(ciImage.extent.size)")
        
        var processedImage = try memoryOptimizer.processCIImageWithOptimization(
            ciImage,
            filters: filters,  // Note: filters are already CIFilter type, not FilterSpec
            context: ciContext
        )
        
        // Debug: Check if CIImage is valid
        if processedImage.extent.isEmpty {
            print("❌ DEBUG StillWriter: CIImage extent is empty - image may be invalid")
        }
        
        // Premium effects - apply Ken Burns and particles per frame
        if config.premiumMode {
            // Note: Ken Burns and particles will be applied per frame during rendering
            // This is handled in the frame writing loop below
        }
        
        // Store the processed image for on-demand buffer creation
        // This avoids pre-allocating all buffers which can cause memory issues
        let finalProcessedImage = processedImage
        
        // Write frames
        print("📝 DEBUG StillWriter: Starting to write \(totalFrames) frames")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let frameCountBox = Box(value: 0)
            // Store the processed image in a Box for thread safety
            let imageBox = Box(value: finalProcessedImage)
            let adaptor = pixelBufferAdaptor
            // Track if continuation has been resumed to prevent double resume
            let hasResumedBox = Box(value: false)
            
            // Track last presentation time to ensure monotonic increase - use Box for thread safety
            let lastPresentationTimeBox = Box(value: CMTime.zero)
            
            videoInput.requestMediaDataWhenReady(on: DispatchQueue.global(qos: .userInitiated)) { [weak self] in
                guard let self = self else { return }
                
                // Check if we're already done to avoid processing after completion
                guard frameCountBox.value < totalFrames && !hasResumedBox.value else {
                    return
                }
                
                while frameCountBox.value < totalFrames && !hasResumedBox.value && videoInput.isReadyForMoreMediaData {
                    // Use much higher precision timescale (600) to avoid rounding errors
                    // This ensures each frame has a unique presentation time
                    let highPrecisionTimescale: Int32 = 600  // 600 ticks per second allows precise 30fps timing
                    let ticksPerFrame = Int64(highPrecisionTimescale / self.config.fps)  // 600/30 = 20 ticks per frame
                    let presentationTime = CMTime(value: Int64(frameCountBox.value) * ticksPerFrame, timescale: highPrecisionTimescale)
                    
                    // Ensure strictly monotonic increase
                    if presentationTime <= lastPresentationTimeBox.value && frameCountBox.value > 0 {
                        print("⚠️ WARNING: Non-monotonic time detected at frame \(frameCountBox.value)")
                        print("   - Current time: \(presentationTime.seconds)s (value: \(presentationTime.value), timescale: \(presentationTime.timescale))")
                        print("   - Last time: \(lastPresentationTimeBox.value.seconds)s (value: \(lastPresentationTimeBox.value.value), timescale: \(lastPresentationTimeBox.value.timescale))")
                        // Skip this frame if time is not monotonic
                        frameCountBox.value += 1
                        continue
                    }
                    lastPresentationTimeBox.value = presentationTime
                    
                    autoreleasepool {
                        
                        do {
                            // Add a small delay every 10 frames to avoid overwhelming the system
                            // Also add longer pause every 50 frames to prevent buffer exhaustion
                            if frameCountBox.value > 0 && frameCountBox.value % 10 == 0 {
                                Thread.sleep(forTimeInterval: 0.001) // 1ms pause
                                
                                // Every 50 frames, do a longer pause and let system recover
                                if frameCountBox.value % 50 == 0 {
                                    print("🔄 DEBUG StillWriter: Frame \(frameCountBox.value) - pausing 5ms for system recovery")
                                    Thread.sleep(forTimeInterval: 0.005) // 5ms pause
                                    // Force memory cleanup to free any lingering buffers
                                    self.memoryOptimizer.forceMemoryCleanup()
                                }
                            }
                            
                            // Apply per-frame effects if premium mode
                            var frameImage = imageBox.value
                            if self.config.premiumMode {
                                let progress = Double(frameCountBox.value) / Double(totalFrames)
                                
                                // COMMENTED OUT: Ken Burns effect - causing text visibility issues
                                // frameImage = self.applyKenBurns(to: frameImage, at: progress)
                                
                                // Apply particle effects for meal reveal (last 30% of duration)
                                if progress > 0.7 {
                                    let particleProgress = (progress - 0.7) / 0.3
                                    frameImage = self.addMealRevealParticles(to: frameImage, progress: particleProgress)
                                }
                            }
                            
                            // Create a fresh buffer for each frame on-demand
                            if let pixelBuffer = try self.createOptimizedPixelBuffer(from: frameImage) {
                                
                                // Final check right before appending
                                if videoInput.isReadyForMoreMediaData {
                                    let success = adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                                    
                                    if !success {
                                        print("❌ DEBUG StillWriter: Failed to append frame \(frameCountBox.value) at time \(presentationTime.seconds)s")
                                        print("❌ DEBUG StillWriter: AVAssetWriter status: \(videoWriter.status.rawValue)")
                                        if let error = videoWriter.error {
                                            print("❌ DEBUG StillWriter: AVAssetWriter error: \(error)")
                                            // Decode the error further
                                            if let nsError = error as NSError? {
                                                print("❌ DEBUG StillWriter: Error domain: \(nsError.domain)")
                                                print("❌ DEBUG StillWriter: Error code: \(nsError.code)")
                                                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                                                    print("❌ DEBUG StillWriter: Underlying error: \(underlyingError)")
                                                    print("❌ DEBUG StillWriter: Underlying domain: \(underlyingError.domain)")
                                                    print("❌ DEBUG StillWriter: Underlying code: \(underlyingError.code)")
                                                }
                                            }
                                        }
                                        if !hasResumedBox.value {
                                            hasResumedBox.value = true
                                            videoInput.markAsFinished()
                                            continuation.resume(throwing: StillWriterError.frameWriteFailed)
                                        }
                                        return
                                    } else {
                                        // Record successful frame for monitoring
                                        self.frameDropMonitor.recordFrame()
                                        if frameCountBox.value == 0 || frameCountBox.value % 30 == 0 || frameCountBox.value == totalFrames - 1 {
                                            print("✅ DEBUG StillWriter: Successfully wrote frame \(frameCountBox.value)/\(totalFrames) at \(presentationTime.seconds)s")
                                        }
                                    }
                                }
                            } else {
                                // Pixel buffer creation returned nil
                                throw StillWriterError.pixelBufferCreationFailed
                            }
                        } catch {
                            if !hasResumedBox.value {
                                hasResumedBox.value = true
                                videoInput.markAsFinished()
                                continuation.resume(throwing: error)
                            }
                            return
                        }
                        
                        frameCountBox.value += 1
                        
                        // Update progress and check memory usage
                        let progress = Double(frameCountBox.value) / Double(totalFrames)
                        Task { @MainActor in
                            await progressCallback(progress)
                        }
                        
                        // Check memory usage every 30 frames
                        if frameCountBox.value % 30 == 0 {
                            if !self.memoryOptimizer.isMemoryUsageSafe() {
                                self.memoryOptimizer.forceMemoryCleanup()
                            }
                        }
                    }
                }
                
                if frameCountBox.value >= totalFrames && !hasResumedBox.value {
                    videoInput.markAsFinished()
                    
                    Task { [weak videoWriter] in
                        guard let videoWriter = videoWriter else {
                            if !hasResumedBox.value {
                                hasResumedBox.value = true
                                continuation.resume(throwing: StillWriterError.writingFailed("Writer deallocated"))
                            }
                            return
                        }
                        await videoWriter.finishWriting()
                        
                        if !hasResumedBox.value {
                            hasResumedBox.value = true
                            if videoWriter.status == .completed {
                                continuation.resume()
                            } else {
                                continuation.resume(throwing: StillWriterError.writingFailed(videoWriter.error?.localizedDescription))
                            }
                        }
                    }
                }
            }
        }
        
        return outputURL
    }
    
    /// Create video from multiple images with crossfade transitions
    public func createVideoFromImages(
        _ images: [(image: UIImage, duration: CMTime, transform: CGAffineTransform)],
        crossfadeDuration: CMTime = CMTime(seconds: 0.3, preferredTimescale: 600),
        progressCallback: @escaping @Sendable (Double) async -> Void = { _ in }
    ) async throws -> URL {
        
        let outputURL = createTempOutputURL()
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create video writer
        let videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // Configure video settings
        let videoSettings = createVideoSettings()
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        
        // Create pixel buffer adaptor
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: createPixelBufferAttributes()
        )
        
        guard videoWriter.canAdd(videoInput) else {
            throw StillWriterError.cannotAddVideoInput
        }
        
        videoWriter.add(videoInput)
        
        // Start writing session
        guard videoWriter.startWriting() else {
            throw StillWriterError.cannotStartWriting(videoWriter.error?.localizedDescription)
        }
        
        videoWriter.startSession(atSourceTime: .zero)
        
        // Calculate total duration and frame parameters
        let totalDuration = images.reduce(CMTime.zero) { $0 + $1.duration }
        _ = CMTime(value: 1, timescale: config.fps)
        let totalFrames = Int(totalDuration.seconds * Double(config.fps))
        
        // Prepare CIImages
        let ciImages = try images.map { imageData in
            guard let ciImage = CIImage(image: imageData.image) else {
                throw StillWriterError.imageConversionFailed
            }
            return (ciImage: ciImage, duration: imageData.duration, transform: imageData.transform)
        }
        
        // Write frames with crossfade
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let frameCountBox = Box(value: 0)
            // Make a local copy to avoid capture issues
            let imagesToProcess = ciImages
            let adaptor = pixelBufferAdaptor
            
            videoInput.requestMediaDataWhenReady(on: DispatchQueue.global(qos: .userInitiated)) { [weak self] in
                guard let self = self else { return }
                
                // Check if we're already done to avoid processing after completion
                guard frameCountBox.value < totalFrames else {
                    return
                }
                
                while frameCountBox.value < totalFrames && videoInput.isReadyForMoreMediaData {
                    autoreleasepool {
                        let presentationTime = CMTime(value: Int64(frameCountBox.value), timescale: self.config.fps)
                        
                        do {
                            let pixelBuffer = try self.createCrossfadeFrame(
                                from: imagesToProcess,
                                atTime: presentationTime,
                                crossfadeDuration: crossfadeDuration
                            )
                            
                            // Final check right before appending
                            if videoInput.isReadyForMoreMediaData {
                                let success = adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                                if !success {
                                    continuation.resume(throwing: StillWriterError.frameWriteFailed)
                                    return
                                }
                            }
                        } catch {
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        frameCountBox.value += 1
                        
                        // Update progress
                        let progress = Double(frameCountBox.value) / Double(totalFrames)
                        Task {
                            await progressCallback(progress)
                        }
                    }
                }
                
                if frameCountBox.value >= totalFrames {
                    videoInput.markAsFinished()
                    
                    Task { [weak videoWriter] in
                        guard let videoWriter = videoWriter else {
                            continuation.resume(throwing: StillWriterError.writingFailed("Writer deallocated"))
                            return
                        }
                        await videoWriter.finishWriting()
                        
                        if videoWriter.status == .completed {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: StillWriterError.writingFailed(videoWriter.error?.localizedDescription))
                        }
                    }
                }
            }
        }
        
        return outputURL
    }
    
    // MARK: - Private Implementation
    
    private func setupPixelBufferPool() {
        // Use optimized pixel buffer pool from MemoryOptimizer for better reuse
        pixelBufferPool = memoryOptimizer.getPixelBufferPool(for: config)
    }
    
    private func createVideoSettings() -> [String: Any] {
        // Use optimized settings for target file size
        return ExportSettings.optimizedVideoSettings(
            for: config.size,
            targetFileSize: ExportSettings.targetFileSize,
            duration: 15.0 // Assume max duration for conservative bitrate
        )
    }
    
    private func createPixelBufferAttributes() -> [String: Any] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: ExportSettings.pixelFormat,
            kCVPixelBufferWidthKey as String: config.size.width,
            kCVPixelBufferHeightKey as String: config.size.height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
    }
    
    private func applyFiltersToImage(_ image: CIImage, filters: [CIFilter]) throws -> CIImage {
        var processedImage = image
        
        // Chain multiple filters properly
        for filter in filters {
            filter.setValue(processedImage, forKey: kCIInputImageKey)
            
            guard let output = filter.outputImage else {
                // Log which filter failed for debugging
                print("⚠️ StillWriter: Filter \(filter.name) failed to produce output")
                throw StillWriterError.filterApplicationFailed
            }
            
            // Critical: Clamp to prevent blank frames
            processedImage = output.clampedToExtent()
        }
        
        // REMOVED: Premium filters that were darkening images
        
        return processedImage
    }
    
    /// Optimized pixel buffer creation using shared pool
    private func createOptimizedPixelBuffer(from ciImage: CIImage) throws -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        
        // IMPORTANT: For pre-rendering multiple frames, we must NOT use the pool
        // as it will reuse buffers which causes AVAssetWriter errors when appending
        // Always create unique buffers for each frame
        
        // Create buffer directly - do not use pool for pre-rendered frames
        let attributes = createPixelBufferAttributes()
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(config.size.width),
            Int(config.size.height),
            ExportSettings.pixelFormat,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess else {
            throw StillWriterError.pixelBufferCreationFailed
        }
        
        guard let buffer = pixelBuffer else {
            throw StillWriterError.pixelBufferCreationFailed
        }
        
        // Lock the pixel buffer before rendering
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        // Ensure the CIImage is within bounds
        let renderRect = CGRect(origin: .zero, size: config.size)
        let boundedImage = ciImage.clampedToExtent().cropped(to: renderRect)
        
        // Create sRGB color space for proper color conversion
        // This ensures photos from CloudKit/Camera render correctly without white backgrounds
        let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        
        // Render CIImage to pixel buffer using shared context
        ciContext.render(boundedImage, to: buffer, bounds: renderRect, colorSpace: sRGBColorSpace)
        
        // Debug: Log color space being used
        print("✅ DEBUG StillWriter: Rendering with sRGB color space")
        
        return buffer
    }
    
    /// Legacy method for backward compatibility
    private func createPixelBuffer(from ciImage: CIImage) throws -> CVPixelBuffer? {
        return try createOptimizedPixelBuffer(from: ciImage)
    }
    
    // MARK: - Premium Effects
    
    /// Easing function for smooth animations
    private func easeInOut(t: Double) -> Double {
        return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }
    
    /// Add Ken Burns effect with EXACTLY 5% max zoom (no additional pulsing)
    private func applyKenBurns(to image: CIImage, at progress: Double) -> CIImage {
        // FIXED: EXACTLY 5% max zoom, no pulsing that would exceed this
        // Photos should appear nearly full-frame with minimal zoom
        
        // Clamp progress to 0-1 range for safety
        let clampedProgress = max(0, min(1, progress))
        
        // Apply easing for smooth motion
        let easedProgress = easeInOut(t: clampedProgress)
        
        // First apply fit-height transform (changed from fit-width)
        let imageSize = image.extent.size
        let videoSize = config.size
        
        // Calculate scale to fit height (so entire height of photo fills the frame)
        let fitHeightScale = videoSize.height / imageSize.height
        
        // FIXED: Start at fitHeightScale, add up to 5% zoom on top
        let zoomFactor = 1.0 + 0.05 * easedProgress
        let finalScale = fitHeightScale * zoomFactor
        
        // Calculate centering offsets (center horizontally if needed)
        let scaledWidth = imageSize.width * finalScale
        let xOffset = (videoSize.width - scaledWidth) / 2.0
        
        // Create transform that fits height and centers horizontally
        // Note: No translation, let the transform handle positioning naturally
        let transform = CGAffineTransform(scaleX: finalScale, y: finalScale)
        
        // Apply transform
        let transformedImage = image.transformed(by: transform)
        
        // Center the image properly within the output rect
        let outputRect = CGRect(origin: .zero, size: config.size)
        
        // Calculate the actual crop rect to center the scaled image
        let scaledExtent = transformedImage.extent
        let cropX = max(0, (scaledExtent.width - videoSize.width) / 2.0)
        let cropY = max(0, (scaledExtent.height - videoSize.height) / 2.0)
        let cropRect = CGRect(x: cropX, y: cropY, width: videoSize.width, height: videoSize.height)
        
        return transformedImage.cropped(to: cropRect)
    }
    
    /// Add particle effects for meal reveal
    private func addMealRevealParticles(to image: CIImage, progress: Double) -> CIImage {
        guard config.premiumMode else { return image }
        
        // Create star shine effect that grows with progress
        if let starShine = CIFilter(name: "CIStarShineGenerator") {
            let extent = image.extent
            starShine.setValue(CIVector(x: extent.midX, y: extent.midY), forKey: "inputCenter")
            starShine.setValue(5 + progress * 20, forKey: "inputRadius")  // Grow with progress
            starShine.setValue(progress * 2.0, forKey: "inputCrossScale")
            starShine.setValue(50.0, forKey: "inputCrossAngle")
            starShine.setValue(CIColor(red: 1.0, green: 0.8, blue: 0.0), forKey: "inputColor")  // Golden color
            
            if let particleImage = starShine.outputImage?.cropped(to: extent) {
                // Composite over image
                if let compositeFilter = CIFilter(name: "CISourceOverCompositing") {
                    compositeFilter.setValue(particleImage, forKey: kCIInputImageKey)
                    compositeFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
                    return compositeFilter.outputImage ?? image
                }
            }
        }
        
        return image
    }
    
    private func createCrossfadeFrame(
        from images: [(ciImage: CIImage, duration: CMTime, transform: CGAffineTransform)],
        atTime time: CMTime,
        crossfadeDuration: CMTime
    ) throws -> CVPixelBuffer {
        
        // Find current image and next image for crossfade
        var currentTime = CMTime.zero
        var currentImageIndex = 0
        
        for (index, imageData) in images.enumerated() {
            if time < currentTime + imageData.duration {
                currentImageIndex = index
                break
            }
            currentTime = currentTime + imageData.duration
        }
        
        let currentImage = images[currentImageIndex]
        let timeInCurrentSegment = time - currentTime
        
        // Check if we need crossfade
        let shouldCrossfade = timeInCurrentSegment > (currentImage.duration - crossfadeDuration) &&
                             currentImageIndex < images.count - 1
        
        var finalImage: CIImage
        
        if shouldCrossfade {
            let nextImage = images[currentImageIndex + 1]
            let crossfadeProgress = (timeInCurrentSegment - (currentImage.duration - crossfadeDuration)).seconds / crossfadeDuration.seconds
            
            // Premium: Use eased progress for smoother, natural fade (sine curve)
            let easedProgress = sin(crossfadeProgress * .pi / 2)  // Ease-in-out using sine
            
            // Create crossfade blend
            let blendFilter = CIFilter(name: "CISourceOverCompositing")!
            blendFilter.setValue(nextImage.ciImage, forKey: kCIInputImageKey)
            blendFilter.setValue(currentImage.ciImage, forKey: kCIInputBackgroundImageKey)
            
            // Apply alpha based on eased crossfade progress
            let alphaFilter = CIFilter(name: "CIColorMatrix")!
            alphaFilter.setValue(nextImage.ciImage, forKey: kCIInputImageKey)
            alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(easedProgress)), forKey: "inputAVector")
            
            if let alphaOutput = alphaFilter.outputImage {
                blendFilter.setValue(alphaOutput, forKey: kCIInputImageKey)
            }
            
            // Add bloom effect to the crossfade for glow transition
            if let blendOutput = blendFilter.outputImage {
                let bloomFilter = CIFilter(name: "CIBloom")
                bloomFilter?.setValue(blendOutput, forKey: kCIInputImageKey)
                bloomFilter?.setValue(10.0, forKey: "inputRadius")
                bloomFilter?.setValue(0.5 * easedProgress, forKey: "inputIntensity")  // Fade bloom with progress
                finalImage = bloomFilter?.outputImage ?? blendOutput
            } else {
                finalImage = currentImage.ciImage
            }
        } else {
            finalImage = currentImage.ciImage
        }
        
        // COMMENTED OUT: Ken Burns effect - causing text visibility issues
        let totalDuration = images.reduce(CMTime.zero) { $0 + $1.duration }
        let frameProgress = time.seconds / totalDuration.seconds
        // finalImage = applyKenBurns(to: finalImage, at: frameProgress)
        
        // Add particles for meal reveal (last segment)
        if config.premiumMode && currentImageIndex == images.count - 1 && frameProgress > 0.7 {
            let particleProgress = (frameProgress - 0.7) / 0.3  // 0-1 for last 30%
            finalImage = addMealRevealParticles(to: finalImage, progress: particleProgress)
        }
        
        // Apply transform if needed
        if !currentImage.transform.isIdentity {
            finalImage = finalImage.transformed(by: currentImage.transform)
        }
        
        guard let pixelBuffer = try createPixelBuffer(from: finalImage) else {
            throw StillWriterError.pixelBufferCreationFailed
        }
        
        return pixelBuffer
    }
    
    private func createTempOutputURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "still_video_\(Date().timeIntervalSince1970).mp4"
        return tempDir.appendingPathComponent(filename)
    }
    
    private func convertFilterSpecsToCIFilters(_ specs: [FilterSpec]) -> [CIFilter] {
        return specs.compactMap { spec in
            guard let filter = CIFilter(name: spec.name) else { return nil }
            for (key, value) in spec.params {
                filter.setValue(value.value, forKey: key)
            }
            return filter
        }
    }
}

// MARK: - Error Types

public enum StillWriterError: LocalizedError {
    case cannotAddVideoInput
    case cannotStartWriting(String?)
    case imageConversionFailed
    case filterApplicationFailed
    case pixelBufferCreationFailed
    case frameWriteFailed
    case writingFailed(String?)
    
    public var errorDescription: String? {
        switch self {
        case .cannotAddVideoInput:
            return "Cannot add video input to writer"
        case .cannotStartWriting(let message):
            return "Cannot start writing: \(message ?? "Unknown error")"
        case .imageConversionFailed:
            return "Failed to convert image to CIImage"
        case .filterApplicationFailed:
            return "Failed to apply filters to image"
        case .pixelBufferCreationFailed:
            return "Failed to create pixel buffer"
        case .frameWriteFailed:
            return "Failed to write frame to video"
        case .writingFailed(let message):
            return "Video writing failed: \(message ?? "Unknown error")"
        }
    }
}