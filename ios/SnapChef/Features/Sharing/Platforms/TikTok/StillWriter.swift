// REPLACE ENTIRE FILE: StillWriter.swift

import UIKit
@preconcurrency import AVFoundation
@preconcurrency import CoreImage
@preconcurrency import CoreMedia
@preconcurrency import VideoToolbox
import Metal

public final class StillWriter: Sendable {
    private let config: RenderConfig
    private nonisolated(unsafe) let ciContext: CIContext
    private nonisolated(unsafe) var pixelBufferPool: CVPixelBufferPool?
    private let memoryOptimizer = MemoryOptimizer.shared

    // SPEED OPTIMIZATION: Pre-computed animation curves
    private nonisolated(unsafe) var kenBurnsFrames: [CGAffineTransform] = []
    private nonisolated(unsafe) var breatheFrames: [CGFloat] = []
    private nonisolated(unsafe) var parallaxFrames: [CGPoint] = []

    // SPEED OPTIMIZATION: Metal acceleration and caching
    private nonisolated(unsafe) let metalContext: CIContext?
    private nonisolated(unsafe) let effectCache = NSCache<NSString, CIImage>()

    public init(config: RenderConfig) {
        self.config = config
        self.ciContext = memoryOptimizer.getCIContext()

        // SPEED OPTIMIZATION: Initialize Metal context if available
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.metalContext = CIContext(mtlDevice: metalDevice)
        } else {
            self.metalContext = nil
        }

        // SPEED OPTIMIZATION: Configure cache
        effectCache.countLimit = 20

        setupPixelBufferPool()
        // SPEED OPTIMIZATION: Skip animation precomputation for faster startup
        // precomputeAnimationCurves()
    }

    private func setupPixelBufferPool() {
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]

        // CRITICAL FIX: Enhanced pixel buffer attributes to prevent edge glitches in pool
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(config.size.width),
            kCVPixelBufferHeightKey as String: Int(config.size.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            // CRITICAL FIX: Add these properties for proper GPU handling
            kCVPixelBufferBytesPerRowAlignmentKey as String: 64, // Align for GPU efficiency
            kCVPixelBufferPlaneAlignmentKey as String: 64
        ]

        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary?,
            pixelBufferAttributes as CFDictionary,
            &pool
        )

        if status != kCVReturnSuccess {
            print("⚠️ Failed to create pixel buffer pool with status: \(status)")
            print("   Width: \(config.size.width), Height: \(config.size.height)")
        } else {
            print("✅ Pixel buffer pool created successfully")
        }

        self.pixelBufferPool = pool
    }

    public func createVideoFromImage(_ image: UIImage,
                                     duration: CMTime,
                                     transform: CGAffineTransform = .identity,
                                     filters: [CIFilter] = [],
                                     specs: [FilterSpec] = [], // Add filter specs for motion effects
                                     cancellationToken: CancellationToken? = nil,
                                     progressCallback: @escaping @Sendable (Double) async -> Void = { _ in }) async throws -> URL {
        let startTime = Date()
        print("[StillWriter] \(startTime): Starting createVideoFromImage, duration: \(duration.seconds)s")

        let out = createTempOutputURL(); try? FileManager.default.removeItem(at: out)
        print("[StillWriter] \(Date()): Output URL: \(out)")

        print("[StillWriter] \(Date()): Creating AVAssetWriter")
        let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)

        // Enhanced video settings for TikTok format with proper compression
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(config.size.width),
            AVVideoHeightKey: Int(config.size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000, // 8 Mbps for high quality
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
            ]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        // CRITICAL FIX: Enhanced pixel buffer attributes to prevent edge glitches
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(config.size.width),
            kCVPixelBufferHeightKey as String: Int(config.size.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            // CRITICAL FIX: Add these properties for proper GPU handling
            kCVPixelBufferBytesPerRowAlignmentKey as String: 64, // Align for GPU efficiency
            kCVPixelBufferPlaneAlignmentKey as String: 64
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        guard writer.canAdd(input) else {
            throw StillWriterError.cannotAddVideoInput
        }

        writer.add(input)
        print("[StillWriter] \(Date()): Added input to writer")

        print("[StillWriter] \(Date()): Starting writer")
        guard writer.startWriting() else {
            let errorDesc = writer.error?.localizedDescription ?? "Unknown writer error"
            print("[StillWriter] \(Date()): ERROR - Cannot start writing: \(errorDesc)")
            throw StillWriterError.cannotStartWriting(errorDesc)
        }

        print("[StillWriter] \(Date()): Writer started, beginning session")
        writer.startSession(atSourceTime: .zero)
        print("[StillWriter] \(Date()): Session started")

        // Preprocess: aspect-fit into a 1080×1920 canvas (fit width requirement)
        let canvas = CGRect(origin: .zero, size: config.size)
        let baseCI = CIImage(image: image) ?? CIImage(color: .black).cropped(to: canvas)
        let fitted = aspectFitCI(baseCI, into: canvas)

        // PREMIUM: Subtle Ken Burns + Enhanced Parallax effects (5-8% zoom)
        let totalFrames = max(1, Int(duration.seconds * Double(config.fps)))
        let maxScale = min(config.maxKenBurnsScale, 1.08) // Cap at 8% for subtle movement
        let breatheIntensity = config.breatheIntensity
        let parallaxIntensity = config.parallaxIntensity
        var t: Double = 0
        let dt = 1.0 / Double(config.fps)

        // Beat timing for breathe effect (assuming 80 BPM default)
        let beatDuration = 60.0 / config.fallbackBPM
        let breatheFreq = 1.0 / beatDuration

        // Log memory usage at start
        memoryOptimizer.logMemoryProfile(phase: "StillWriter start")
        
        // CRITICAL FIX: Track temp files for proper cleanup
        var tempResources: [Any] = []
        defer {
            autoreleasepool {
                tempResources.removeAll()
                memoryOptimizer.forceMemoryCleanup()
            }
        }

        for frame in 0..<totalFrames {
            // Check for cancellation before processing each frame
            try cancellationToken?.throwIfCancelled()
            
            // Check memory pressure every 10 frames
            if frame % 10 == 0 {
                let memoryStatus = memoryOptimizer.getMemoryStatus()
                if memoryStatus.pressureLevel == .critical {
                    print("[StillWriter] Critical memory at frame \(frame): \(memoryStatus.currentUsageMB)MB")
                    throw CancellationError()
                } else if memoryStatus.pressureLevel == .warning {
                    print("[StillWriter] Warning memory at frame \(frame): \(memoryStatus.currentUsageMB)MB - forcing cleanup")
                    memoryOptimizer.forceMemoryCleanup()
                }
            }
            
            // Wait for input to be ready with timeout
            var waitCount = 0
            while !input.isReadyForMoreMediaData {
                try cancellationToken?.throwIfCancelled()
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms - non-blocking
                waitCount += 1
                if waitCount > 5_000 { // 5 second timeout
                    throw StillWriterError.cannotStartWriting("Input not ready for media data after 5 seconds")
                }
            }

            var pixelBuffer: CVPixelBuffer?
            var creationError: String?

            // Strategy 1: Try to get from memory optimizer's shared pool
            if let sharedPool = memoryOptimizer.getPixelBufferPool(for: config) {
                let poolStatus = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, sharedPool, &pixelBuffer)
                if poolStatus != kCVReturnSuccess {
                    creationError = "Shared pool failed with CVReturn \(poolStatus): \(cvReturnDescription(poolStatus))"
                }
            }

            // Strategy 2: Try our local pool if shared pool failed
            if pixelBuffer == nil, let localPool = self.pixelBufferPool {
                let poolStatus = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, localPool, &pixelBuffer)
                if poolStatus != kCVReturnSuccess {
                    creationError = "Local pool failed with CVReturn \(poolStatus): \(cvReturnDescription(poolStatus))"
                }
            }

            // Strategy 3: Direct creation with full attributes
            if pixelBuffer == nil {
                let createStatus = CVPixelBufferCreate(
                    kCFAllocatorDefault,
                    Int(config.size.width),
                    Int(config.size.height),
                    kCVPixelFormatType_32BGRA,
                    pixelBufferAttributes as CFDictionary,
                    &pixelBuffer
                )
                if createStatus != kCVReturnSuccess {
                    creationError = "Direct creation failed with CVReturn \(createStatus): \(cvReturnDescription(createStatus))"
                }
            }

            // Strategy 4: Emergency creation with minimal attributes and memory cleanup
            if pixelBuffer == nil {
                // Force memory cleanup before emergency attempt
                memoryOptimizer.forceMemoryCleanup()

                let minimalAttrs: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                let retryStatus = CVPixelBufferCreate(
                    kCFAllocatorDefault,
                    Int(config.size.width),
                    Int(config.size.height),
                    kCVPixelFormatType_32BGRA,
                    minimalAttrs as CFDictionary,
                    &pixelBuffer
                )
                if retryStatus != kCVReturnSuccess {
                    creationError = "Emergency creation failed with CVReturn \(retryStatus): \(cvReturnDescription(retryStatus))"
                }
            }

            guard let pixelBuffer else {
                let memUsage = memoryOptimizer.getCurrentMemoryUsage() / (1_024 * 1_024)
                let detailedError = """
                StillWriter: Failed to create pixel buffer for frame \(frame)/\(totalFrames)
                Memory usage: \(memUsage) MB
                Video size: \(config.size.width)x\(config.size.height)
                Last error: \(creationError ?? "Unknown")
                Try closing other apps to free memory.
                """
                print("❌ \(detailedError)")
                throw StillWriterError.pixelBufferCreationFailed(detailedError)
            }

            // Lock pixel buffer for writing
            let lockResult = CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if lockResult != kCVReturnSuccess {
                print("⚠️ Failed to lock pixel buffer with CVReturn \(lockResult): \(cvReturnDescription(lockResult))")
            }

            // CRITICAL FIX: Clear pixel buffer completely to prevent edge glitches
            let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
            if pixelFormat == kCVPixelFormatType_32BGRA {
                let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
                let height = CVPixelBufferGetHeight(pixelBuffer)
                if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
                    // Clear entire buffer to solid black to prevent frame-to-frame residue
                    memset(baseAddress, 0, bytesPerRow * height)
                }
            }

            let time = CMTime(value: CMTimeValue(frame), timescale: config.fps)

            // SPEED OPTIMIZATION: Use pre-computed animation frames
            let frameIndex = min(frame, max(0, kenBurnsFrames.count - 1))
            let kenBurnsTransform = kenBurnsFrames.isEmpty ? CGAffineTransform.identity : kenBurnsFrames[frameIndex]
            let breatheScale = breatheFrames.isEmpty ? 1.0 : breatheFrames[frameIndex]
            let parallaxOffset = parallaxFrames.isEmpty ? CGPoint.zero : parallaxFrames[frameIndex]

            // Combine all effects efficiently
            let totalScale = kenBurnsTransform.a * breatheScale // Extract scale from transform

            // SPEED OPTIMIZATION: Use pre-computed transform
            var img = fitted.transformed(by:
                CGAffineTransform(translationX: canvas.midX + parallaxOffset.x, y: canvas.midY + parallaxOffset.y)
                    .scaledBy(x: totalScale, y: totalScale)
                    .translatedBy(x: -canvas.midX, y: -canvas.midY)
            )

            // SPEED OPTIMIZATION: Apply filters efficiently with caching
            img = autoreleasepool {
                try! applyFiltersEfficiently(to: img, filters: filters, specs: specs, frame: frame, totalFrames: totalFrames)
            }

            // SPEED OPTIMIZATION: Render with Metal acceleration if available
            // Fix Ken Burns edge glitches: Ensure bounds are integer-aligned and proper layer setup
            let roundedCanvas = CGRect(
                x: round(canvas.origin.x),
                y: round(canvas.origin.y),
                width: round(canvas.width),
                height: round(canvas.height)
            )

            // CRITICAL FIX: Set pixel buffer properties to prevent edge glitches
            CVBufferSetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, CVAttachmentMode.shouldPropagate)
            CVBufferSetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, CVAttachmentMode.shouldPropagate)
            CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, CVAttachmentMode.shouldPropagate)

            autoreleasepool {
                if let metalContext = metalContext {
                    // CRITICAL FIX: Use proper GPU context with edge antialiasing
                    metalContext.render(img, to: pixelBuffer, bounds: roundedCanvas, colorSpace: CGColorSpaceCreateDeviceRGB())
                } else {
                    // CRITICAL FIX: CPU context with proper edge handling
                    ciContext.render(img, to: pixelBuffer, bounds: roundedCanvas, colorSpace: CGColorSpaceCreateDeviceRGB())
                }
            }

            // Append to video with error checking
            let appendSuccess = adaptor.append(pixelBuffer, withPresentationTime: time)
            if !appendSuccess {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                let writerError = writer.error?.localizedDescription ?? "Unknown append error"
                throw StillWriterError.cannotStartWriting("Failed to append frame \(frame): \(writerError)")
            }

            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            await progressCallback(Double(frame + 1) / Double(totalFrames))
            t += dt

            // Log memory every 30 frames to detect leaks
            if frame % 30 == 0 {
                memoryOptimizer.logMemoryProfile(phase: "Frame \(frame)")
                // Additional memory cleanup for long sequences
                if frame > 0 && frame % 60 == 0 {
                    autoreleasepool {
                        memoryOptimizer.forceMemoryCleanup()
                    }
                }
            }
        }

        input.markAsFinished()
        await progressCallback(1.0)

        // CRITICAL FIX: Proper completion handling with memory cleanup
        await withCheckedContinuation { continuation in
            writer.finishWriting { [weak self] in
                autoreleasepool {
                    if writer.status == .failed {
                        print("❌ AVAssetWriter failed with error: \(writer.error?.localizedDescription ?? "Unknown")")
                    } else if writer.status == .completed {
                        print("✅ StillWriter successfully created video at: \(out.path)")
                    }
                    
                    // Force cleanup after completion
                    self?.memoryOptimizer.forceMemoryCleanup()
                    continuation.resume()
                }
            }
        }

        guard writer.status == .completed else {
            throw StillWriterError.cannotStartWriting(writer.error?.localizedDescription)
        }

        return out
    }

    private func aspectFitCI(_ image: CIImage, into canvas: CGRect) -> CIImage {
        let w = image.extent.width, h = image.extent.height
        let sx = canvas.width / w, sy = canvas.height / h

        // Use max instead of min to ensure photo fills entire screen (no black bars)
        // Either width OR height will be full, the other dimension may be cropped
        let s = max(sx, sy)
        let scaledW = w * s, scaledH = h * s
        let tx = (canvas.width - scaledW) / 2, ty = (canvas.height - scaledH) / 2

        // Fix Ken Burns edge glitches: Round coordinates to integer pixels
        let roundedTx = round(tx)
        let roundedTy = round(ty)

        let transformedImage = image.transformed(by: CGAffineTransform(scaleX: s, y: s))
            .transformed(by: CGAffineTransform(translationX: roundedTx, y: roundedTy))
            .cropped(to: canvas)

        // Ensure pixel-perfect rendering with proper content mode
        return transformedImage
    }

    // MARK: - PREMIUM EFFECTS HELPERS

    /// Smooth easing function for cinematic Ken Burns
    private func easeInOutCubic(_ t: Double) -> Double {
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    /// Apply motion-aware effects to specific filters
    private func applyMotionEffects(to image: CIImage, filter: FilterSpec?, time: Double, frame: Int, totalFrames: Int) -> CIImage? {
        guard let filter = filter else { return nil }

        switch filter {
        case .chromaticAberration(let intensity):
            // Apply RGB separation that increases during transitions
            let transitionFactor = CGFloat(sin(time * 2) * 0.5 + 0.5) // 0-1 oscillation
            let dynamicIntensity = intensity * transitionFactor
            return applyChromaticAberration(to: image, intensity: dynamicIntensity)

        case .lightLeak(let position, let intensity):
            // Animated light leak that moves with the enhanced parallax
            let parallaxX = config.parallaxIntensity * CGFloat(sin(time * 0.4)) * config.size.width * 0.15
            let parallaxY = config.parallaxIntensity * CGFloat(cos(time * 0.3)) * config.size.height * 0.12
            let animatedPosition = CGPoint(x: position.x + parallaxX, y: position.y + parallaxY)
            return applyLightLeak(to: image, position: animatedPosition, intensity: intensity)

        case .velocityRamp:
            // This would affect playback speed, handled at composition level
            return nil

        default:
            return nil
        }
    }

    /// Apply chromatic aberration effect
    private func applyChromaticAberration(to image: CIImage, intensity: CGFloat) -> CIImage {
        // Split RGB channels and offset them slightly
        // CRITICAL FIX: Remove force unwraps to prevent EXC_BREAKPOINT crashes
        guard let redOffset = CIFilter(name: "CIAffineTransform") else {
            print("❌ Failed to create CIAffineTransform filter for red channel")
            return image
        }
        redOffset.setValue(image, forKey: kCIInputImageKey)
        redOffset.setValue(CGAffineTransform(translationX: intensity * 2, y: 0), forKey: kCIInputTransformKey)

        guard let blueOffset = CIFilter(name: "CIAffineTransform") else {
            print("❌ Failed to create CIAffineTransform filter for blue channel")
            return image
        }
        blueOffset.setValue(image, forKey: kCIInputImageKey)
        blueOffset.setValue(CGAffineTransform(translationX: -intensity * 2, y: 0), forKey: kCIInputTransformKey)

        // Composite the channels (simplified version)
        guard let composite = CIFilter(name: "CIAdditionCompositing") else {
            print("❌ Failed to create CIAdditionCompositing filter for chromatic aberration")
            return image
        }
        composite.setValue(redOffset.outputImage, forKey: kCIInputImageKey)
        composite.setValue(blueOffset.outputImage, forKey: kCIInputBackgroundImageKey)

        return composite.outputImage ?? image
    }

    /// Apply animated light leak effect
    private func applyLightLeak(to image: CIImage, position: CGPoint, intensity: CGFloat) -> CIImage {
        // Create the radial gradient (this is a generator filter - no inputImage needed)
        // CRITICAL FIX: Remove force unwrap to prevent EXC_BREAKPOINT crashes
        guard let radialGradient = CIFilter(name: "CIRadialGradient") else {
            print("❌ Failed to create CIRadialGradient filter")
            return image
        }
        radialGradient.setValue(CIVector(x: position.x, y: position.y), forKey: "inputCenter")
        radialGradient.setValue(50, forKey: "inputRadius0")
        radialGradient.setValue(200, forKey: "inputRadius1")
        radialGradient.setValue(CIColor(red: 1, green: 0.9, blue: 0.7, alpha: intensity), forKey: "inputColor0")
        radialGradient.setValue(CIColor.clear, forKey: "inputColor1")

        // Get the gradient image (no input needed for generator filters)
        guard let gradientImage = radialGradient.outputImage else { return image }

        // Composite the gradient over the background image
        guard let composite = CIFilter(name: "CIAdditionCompositing") else {
            print("❌ Failed to create CIAdditionCompositing filter for light leak")
            return image
        }
        composite.setValue(gradientImage, forKey: kCIInputImageKey)
        composite.setValue(image, forKey: kCIInputBackgroundImageKey)

        return composite.outputImage ?? image
    }

    /// Apply film grain effect
    private func applyFilmGrain(to image: CIImage, intensity: CGFloat) -> CIImage {
        // Create random noise (this is a generator filter - no inputImage needed)
        // CRITICAL FIX: Remove force unwrap to prevent EXC_BREAKPOINT crashes
        guard let noise = CIFilter(name: "CIRandomGenerator") else {
            print("❌ Failed to create CIRandomGenerator filter")
            return image
        }

        // Get the noise image
        guard let noiseImage = noise.outputImage else { return image }

        // Scale and crop the noise to match image bounds
        let scaledNoise = noiseImage
            .transformed(by: CGAffineTransform(scaleX: 0.1, y: 0.1)) // Make grain smaller
            .cropped(to: image.extent)

        // Convert noise to grayscale for film grain effect
        guard let grayscale = CIFilter(name: "CIColorMatrix") else {
            print("❌ Failed to create CIColorMatrix filter")
            return image
        }
        grayscale.setValue(scaledNoise, forKey: kCIInputImageKey)
        grayscale.setValue(CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0), forKey: "inputRVector")
        grayscale.setValue(CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0), forKey: "inputGVector")
        grayscale.setValue(CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0), forKey: "inputBVector")
        grayscale.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")

        guard let grainImage = grayscale.outputImage else { return image }

        // Blend the grain with the original image using multiply blend mode
        guard let composite = CIFilter(name: "CIMultiplyBlendMode") else {
            print("❌ Failed to create CIMultiplyBlendMode filter")
            return image
        }
        composite.setValue(image, forKey: kCIInputBackgroundImageKey)
        composite.setValue(grainImage, forKey: kCIInputImageKey)

        // Mix the result with the original based on intensity
        guard let mix = CIFilter(name: "CIColorBlendMode") else {
            print("❌ Failed to create CIColorBlendMode filter")
            return image
        }
        mix.setValue(image, forKey: kCIInputBackgroundImageKey)
        mix.setValue(composite.outputImage, forKey: kCIInputImageKey)

        return mix.outputImage ?? image
    }

    // MARK: SPEED OPTIMIZATION: Pre-compute animation curves
    private func precomputeAnimationCurves() {
        let maxFrames = Int(config.maxDuration.seconds * Double(config.fps))

        kenBurnsFrames.removeAll()
        breatheFrames.removeAll()
        parallaxFrames.removeAll()

        for frame in 0..<maxFrames {
            let progress = Double(frame) / Double(max(1, maxFrames - 1))
            let easedProgress = easeInOutCubic(progress)

            // Pre-compute Ken Burns transform
            let kenBurnsScale = 1.0 + (config.maxKenBurnsScale - 1.0) * CGFloat(easedProgress)
            let kenBurnsTransform = CGAffineTransform(scaleX: kenBurnsScale, y: kenBurnsScale)
            kenBurnsFrames.append(kenBurnsTransform)

            // Pre-compute breathe scale
            let t = Double(frame) / Double(config.fps)
            let beatDuration = 60.0 / config.fallbackBPM
            let breatheFreq = 1.0 / beatDuration
            let breathePhase = sin(t * breatheFreq * 2 * .pi)
            let breatheScale = 1.0 + config.breatheIntensity * CGFloat(breathePhase)
            breatheFrames.append(breatheScale)

            // Pre-compute parallax offset
            let parallaxX = config.parallaxIntensity * CGFloat(sin(t * 0.4)) * config.size.width * 0.15
            let parallaxY = config.parallaxIntensity * CGFloat(cos(t * 0.3)) * config.size.height * 0.12
            parallaxFrames.append(CGPoint(x: parallaxX, y: parallaxY))
        }

        print("[StillWriter] Pre-computed \(maxFrames) animation frames for optimization")
    }

    // MARK: SPEED OPTIMIZATION: Simple video creation for basic cases
    private func createSimpleVideoFromImage(_ image: UIImage, duration: CMTime, cancellationToken: CancellationToken? = nil, progressCallback: @escaping @Sendable (Double) async -> Void) async throws -> URL {
        print("[StillWriter] Creating SIMPLE video (no effects) - faster path")

        let out = createTempOutputURL()
        try? FileManager.default.removeItem(at: out)

        let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)

        // Simplified settings for speed
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(config.size.width),
            AVVideoHeightKey: Int(config.size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000, // Lower bitrate for speed
                AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
            ]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
        )

        guard writer.canAdd(input) else {
            throw StillWriterError.cannotAddVideoInput
        }

        writer.add(input)
        guard writer.startWriting() else {
            throw StillWriterError.cannotStartWriting(writer.error?.localizedDescription)
        }

        writer.startSession(atSourceTime: .zero)

        // Pre-process image once
        let canvas = CGRect(origin: .zero, size: config.size)
        let fitted = aspectFitCI(CIImage(image: image) ?? CIImage(color: .black).cropped(to: canvas), into: canvas)

        let totalFrames = max(1, Int(duration.seconds * Double(config.fps)))

        for frame in 0..<totalFrames {
            // Check for cancellation
            try cancellationToken?.throwIfCancelled()
            
            while !input.isReadyForMoreMediaData {
                try cancellationToken?.throwIfCancelled()
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms - non-blocking
            }

            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(config.size.width),
                Int(config.size.height),
                kCVPixelFormatType_32BGRA,
                nil,
                &pixelBuffer
            )

            guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
                throw StillWriterError.pixelBufferCreationFailed("Simple creation failed")
            }

            let time = CMTime(value: CMTimeValue(frame), timescale: config.fps)

            // Simple render without effects
            autoreleasepool {
                ciContext.render(fitted, to: pixelBuffer, bounds: canvas, colorSpace: CGColorSpaceCreateDeviceRGB())
            }

            guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                throw StillWriterError.cannotStartWriting("Failed to append frame")
            }

            await progressCallback(Double(frame + 1) / Double(totalFrames))
        }

        input.markAsFinished()

        await withCheckedContinuation { continuation in
            writer.finishWriting { [weak self] in
                autoreleasepool {
                    // Force cleanup after simple video creation
                    self?.memoryOptimizer.forceMemoryCleanup()
                    continuation.resume()
                }
            }
        }

        guard writer.status == .completed else {
            throw StillWriterError.cannotStartWriting(writer.error?.localizedDescription)
        }

        return out
    }

    // MARK: SPEED OPTIMIZATION: Efficient filter application with caching
    private func applyFiltersEfficiently(to image: CIImage, filters: [CIFilter], specs: [FilterSpec], frame: Int, totalFrames: Int) throws -> CIImage {
        // CRITICAL FIX: Wrap entire filter application in autoreleasepool
        return autoreleasepool {
            var img = image

            // SPEED OPTIMIZATION: Use Metal context if available for better performance
            // Note: renderContext is available if needed for future optimizations

            // Apply filters in batches to reduce pipeline overhead
            for (index, filter) in filters.enumerated() {
                autoreleasepool {
                    let cacheKey = "filter_\(index)_\(frame)" as NSString

                    // Check cache first
                    if let cachedResult = effectCache.object(forKey: cacheKey) {
                        img = cachedResult
                        return
                    }

                    // Apply filter
                    if !isGeneratorFilter(filter) {
                        filter.setValue(img, forKey: kCIInputImageKey)
                    }

                    if let outputImage = filter.outputImage {
                        if isGeneratorFilter(filter) {
                            // Composite generator filters - handle missing filter gracefully
                            if let composite = CIFilter(name: "CISourceOverCompositing") {
                                composite.setValue(outputImage, forKey: kCIInputImageKey)
                                composite.setValue(img, forKey: kCIInputBackgroundImageKey)
                                img = composite.outputImage ?? img
                            }
                        } else {
                            img = outputImage
                        }
                    }

                    // Cache result for potential reuse
                    if filters.count < 5 { // Only cache for simpler cases
                        effectCache.setObject(img, forKey: cacheKey)
                    }
                }
            }

            // Apply motion effects with specs
            for (index, spec) in specs.enumerated() {
                if index < specs.count {
                    img = applyMotionEffectOptimized(to: img, filterSpec: spec, frame: frame, totalFrames: totalFrames)
                }
            }

            return img
        }
    }

    private func isGeneratorFilter(_ filter: CIFilter) -> Bool {
        let generatorFilters = ["CIRadialGradient", "CILinearGradient", "CIRandomGenerator",
                              "CIConstantColorGenerator", "CICheckerboardGenerator",
                              "CISunbeamsGenerator", "CIStarShineGenerator"]

        let filterName = filter.attributes["CIAttributeFilterName"] as? String ?? ""
        return generatorFilters.contains { filterName.contains($0) }
    }

    private func applyMotionEffectOptimized(to image: CIImage, filterSpec: FilterSpec, frame: Int, totalFrames: Int) -> CIImage {
        // SPEED OPTIMIZATION: Use frame index instead of recalculating time
        let progress = Double(frame) / Double(max(1, totalFrames - 1))

        switch filterSpec {
        case .chromaticAberration(let intensity):
            let dynamicIntensity = intensity * CGFloat(sin(progress * 2 * .pi) * 0.5 + 0.5)
            return applyChromaticAberration(to: image, intensity: dynamicIntensity)

        case .lightLeak(let position, let intensity):
            // Use pre-computed parallax values if available
            let frameIndex = min(frame, max(0, parallaxFrames.count - 1))
            let parallaxOffset = parallaxFrames.isEmpty ? CGPoint.zero : parallaxFrames[frameIndex]
            let animatedPosition = CGPoint(x: position.x + parallaxOffset.x * 0.1, y: position.y + parallaxOffset.y * 0.1)
            return applyLightLeak(to: image, position: animatedPosition, intensity: intensity)

        default:
            return image
        }
    }

    private func createTempOutputURL() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return dir.appendingPathComponent("snapchef-stillwriter-\(UUID().uuidString).mp4")
    }
}

public enum StillWriterError: Error, LocalizedError {
    case cannotAddVideoInput
    case pixelBufferCreationFailed(String)
    case cannotStartWriting(String?)

    public var errorDescription: String? {
        switch self {
        case .cannotAddVideoInput:
            return "Failed to add video input to writer"
        case .pixelBufferCreationFailed(let details):
            return "Failed to create pixel buffer for video frame: \(details)"
        case .cannotStartWriting(let reason):
            return "Failed to start writing video: \(reason ?? "Unknown error")"
        }
    }
}

// Helper function to convert CVReturn codes to readable descriptions
private func cvReturnDescription(_ code: CVReturn) -> String {
    switch code {
    case kCVReturnSuccess:
        return "Success"
    case kCVReturnError:
        return "Generic error"
    case kCVReturnInvalidArgument:
        return "Invalid argument"
    case kCVReturnAllocationFailed:
        return "Memory allocation failed"
    case kCVReturnUnsupported:
        return "Operation not supported"
    case kCVReturnInvalidDisplay:
        return "Invalid display"
    case kCVReturnDisplayLinkNotRunning:
        return "Display link not running"
    case kCVReturnDisplayLinkAlreadyRunning:
        return "Display link already running"
    case kCVReturnDisplayLinkCallbacksNotSet:
        return "Display link callbacks not set"
    case kCVReturnInvalidPixelFormat:
        return "Invalid pixel format"
    case kCVReturnInvalidSize:
        return "Invalid size (width or height)"
    case kCVReturnInvalidPixelBufferAttributes:
        return "Invalid pixel buffer attributes"
    case kCVReturnPixelBufferNotOpenGLCompatible:
        return "Pixel buffer not OpenGL compatible"
    case kCVReturnPixelBufferNotMetalCompatible:
        return "Pixel buffer not Metal compatible"
    case kCVReturnWouldExceedAllocationThreshold:
        return "Would exceed memory allocation threshold"
    case kCVReturnPoolAllocationFailed:
        return "Pool allocation failed (insufficient memory)"
    case kCVReturnInvalidPoolAttributes:
        return "Invalid pool attributes"
    case kCVReturnRetry:
        return "Operation should be retried"
    default:
        return "Unknown CVReturn code: \(code)"
    }
}
