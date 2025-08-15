// REPLACE ENTIRE FILE: StillWriter.swift

import UIKit
@preconcurrency import AVFoundation
@preconcurrency import CoreImage
@preconcurrency import CoreMedia
@preconcurrency import VideoToolbox

public final class StillWriter: @unchecked Sendable {
    private let config: RenderConfig
    private let ciContext: CIContext
    private var pixelBufferPool: CVPixelBufferPool?
    private let memoryOptimizer = MemoryOptimizer.shared

    public init(config: RenderConfig) {
        self.config = config
        self.ciContext = memoryOptimizer.getCIContext()
        setupPixelBufferPool()
    }
    
    private func setupPixelBufferPool() {
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(config.size.width),
            kCVPixelBufferHeightKey as String: Int(config.size.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true
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
                                     progressCallback: @escaping @Sendable (Double) async -> Void = { _ in }) async throws -> URL {
        let out = createTempOutputURL(); try? FileManager.default.removeItem(at: out)
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
        
        // Ensure pixel buffer attributes exactly match what we'll create
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(config.size.width),
            kCVPixelBufferHeightKey as String: Int(config.size.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        guard writer.canAdd(input) else { 
            throw StillWriterError.cannotAddVideoInput 
        }
        
        writer.add(input)
        
        guard writer.startWriting() else {
            let errorDesc = writer.error?.localizedDescription ?? "Unknown writer error"
            throw StillWriterError.cannotStartWriting(errorDesc)
        }
        
        writer.startSession(atSourceTime: .zero)

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

        for frame in 0..<totalFrames {
            // Wait for input to be ready with timeout
            var waitCount = 0
            while !input.isReadyForMoreMediaData {
                usleep(1_000) // 1ms
                waitCount += 1
                if waitCount > 5000 { // 5 second timeout
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
                let memUsage = memoryOptimizer.getCurrentMemoryUsage() / (1024 * 1024)
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
            
            let time = CMTime(value: CMTimeValue(frame), timescale: config.fps)

            // PREMIUM EFFECTS CALCULATION
            
            // 1. Cinematic Ken Burns with easing curve (15% zoom)
            let progress = Double(frame) / Double(max(1, totalFrames - 1))
            let easedProgress = easeInOutCubic(progress) // Smooth cinematic easing
            let kenBurnsScale = 1.0 + (maxScale - 1.0) * CGFloat(easedProgress)
            
            // 2. Breathe effect (2% pulse synced to beat)
            let breathePhase = sin(t * breatheFreq * 2 * .pi)
            let breatheScale = 1.0 + breatheIntensity * CGFloat(breathePhase)
            
            // 3. Enhanced Parallax movement (more prominent panning)
            let parallaxX = parallaxIntensity * CGFloat(sin(t * 0.4)) * canvas.width * 0.15
            let parallaxY = parallaxIntensity * CGFloat(cos(t * 0.3)) * canvas.height * 0.12
            
            // Combine all effects
            let totalScale = kenBurnsScale * breatheScale
            
            var img = fitted.transformed(by:
                CGAffineTransform(translationX: canvas.midX + parallaxX, y: canvas.midY + parallaxY)
                    .scaledBy(x: totalScale, y: totalScale)
                    .translatedBy(x: -canvas.midX, y: -canvas.midY)
            )

            // Apply premium filters with motion-aware processing
            for (index, f) in filters.enumerated() { 
                autoreleasepool {
                    // Check if filter is a generator filter (doesn't accept inputImage)
                    let generatorFilters = ["CIRadialGradient", "CILinearGradient", "CIRandomGenerator", 
                                          "CIConstantColorGenerator", "CICheckerboardGenerator", 
                                          "CISunbeamsGenerator", "CIStarShineGenerator"]
                    
                    let filterName = f.attributes["CIAttributeFilterName"] as? String ?? ""
                    let isGeneratorFilter = generatorFilters.contains { filterName.contains($0) }
                    
                    // Only set inputImage for non-generator filters
                    if !isGeneratorFilter {
                        f.setValue(img, forKey: kCIInputImageKey)
                    }
                    
                    // Apply motion effects for dynamic filters
                    if let motionAwareImage = applyMotionEffects(to: img, filter: specs.count > index ? specs[index] : nil, time: t, frame: frame, totalFrames: totalFrames) {
                        img = motionAwareImage
                    } else {
                        // Handle special composite filters with userInfo
                        if let userInfo = f.value(forKey: "userInfo") as? [String: Any] {
                            if let lightLeakData = userInfo["lightLeakPosition"] as? CGPoint,
                               let intensity = userInfo["lightLeakIntensity"] as? CGFloat {
                                // Apply light leak effect
                                img = applyLightLeak(to: img, position: lightLeakData, intensity: intensity)
                            } else if let filmGrainIntensity = userInfo["filmGrainIntensity"] as? CGFloat {
                                // Apply film grain effect
                                img = applyFilmGrain(to: img, intensity: filmGrainIntensity)
                            }
                        } else {
                            // Handle regular filters
                            if let outputImage = f.outputImage {
                                if isGeneratorFilter {
                                    // Composite the generated image with the existing image
                                    let composite = CIFilter(name: "CISourceOverCompositing")!
                                    composite.setValue(outputImage, forKey: kCIInputImageKey)
                                    composite.setValue(img, forKey: kCIInputBackgroundImageKey)
                                    img = composite.outputImage ?? img
                                } else {
                                    img = outputImage
                                }
                            }
                        }
                    }
                }
            }

            // Render to pixel buffer with error handling
            autoreleasepool {
                ciContext.render(img, to: pixelBuffer, bounds: canvas, colorSpace: CGColorSpaceCreateDeviceRGB())
            }
            
            // Append to video with error checking
            let appendSuccess = adaptor.append(pixelBuffer, withPresentationTime: time)
            if !appendSuccess {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                let writerError = writer.error?.localizedDescription ?? "Unknown append error"
                throw StillWriterError.cannotStartWriting("Failed to append frame \(frame): \(writerError)")
            }
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            await progressCallback(Double(frame+1)/Double(totalFrames))
            t += dt
            
            // Log memory every 30 frames to detect leaks
            if frame % 30 == 0 {
                memoryOptimizer.logMemoryProfile(phase: "Frame \(frame)")
            }
        }

        input.markAsFinished()
        await progressCallback(1.0)
        
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                if writer.status == .failed {
                    print("❌ AVAssetWriter failed with error: \(writer.error?.localizedDescription ?? "Unknown")")
                } else if writer.status == .completed {
                    print("✅ StillWriter successfully created video at: \(out.path)")
                }
                continuation.resume()
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
        let tx = (canvas.width - scaledW)/2, ty = (canvas.height - scaledH)/2
        
        return image.transformed(by: CGAffineTransform(scaleX: s, y: s))
            .transformed(by: CGAffineTransform(translationX: tx, y: ty))
            .cropped(to: canvas)
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
            
        case .velocityRamp(_):
            // This would affect playback speed, handled at composition level
            return nil
            
        default:
            return nil
        }
    }
    
    /// Apply chromatic aberration effect
    private func applyChromaticAberration(to image: CIImage, intensity: CGFloat) -> CIImage {
        // Split RGB channels and offset them slightly
        let redOffset = CIFilter(name: "CIAffineTransform")!
        redOffset.setValue(image, forKey: kCIInputImageKey)
        redOffset.setValue(CGAffineTransform(translationX: intensity * 2, y: 0), forKey: kCIInputTransformKey)
        
        let blueOffset = CIFilter(name: "CIAffineTransform")!
        blueOffset.setValue(image, forKey: kCIInputImageKey)
        blueOffset.setValue(CGAffineTransform(translationX: -intensity * 2, y: 0), forKey: kCIInputTransformKey)
        
        // Composite the channels (simplified version)
        let composite = CIFilter(name: "CIAdditionCompositing")!
        composite.setValue(redOffset.outputImage, forKey: kCIInputImageKey)
        composite.setValue(blueOffset.outputImage, forKey: kCIInputBackgroundImageKey)
        
        return composite.outputImage ?? image
    }
    
    /// Apply animated light leak effect
    private func applyLightLeak(to image: CIImage, position: CGPoint, intensity: CGFloat) -> CIImage {
        // Create the radial gradient (this is a generator filter - no inputImage needed)
        let radialGradient = CIFilter(name: "CIRadialGradient")!
        radialGradient.setValue(CIVector(x: position.x, y: position.y), forKey: "inputCenter")
        radialGradient.setValue(50, forKey: "inputRadius0")
        radialGradient.setValue(200, forKey: "inputRadius1")
        radialGradient.setValue(CIColor(red: 1, green: 0.9, blue: 0.7, alpha: intensity), forKey: "inputColor0")
        radialGradient.setValue(CIColor.clear, forKey: "inputColor1")
        
        // Get the gradient image (no input needed for generator filters)
        guard let gradientImage = radialGradient.outputImage else { return image }
        
        // Composite the gradient over the background image
        let composite = CIFilter(name: "CIAdditionCompositing")!
        composite.setValue(gradientImage, forKey: kCIInputImageKey)
        composite.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        return composite.outputImage ?? image
    }
    
    /// Apply film grain effect
    private func applyFilmGrain(to image: CIImage, intensity: CGFloat) -> CIImage {
        // Create random noise (this is a generator filter - no inputImage needed)
        let noise = CIFilter(name: "CIRandomGenerator")!
        
        // Get the noise image
        guard let noiseImage = noise.outputImage else { return image }
        
        // Scale and crop the noise to match image bounds
        let scaledNoise = noiseImage
            .transformed(by: CGAffineTransform(scaleX: 0.1, y: 0.1)) // Make grain smaller
            .cropped(to: image.extent)
        
        // Convert noise to grayscale for film grain effect
        let grayscale = CIFilter(name: "CIColorMatrix")!
        grayscale.setValue(scaledNoise, forKey: kCIInputImageKey)
        grayscale.setValue(CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0), forKey: "inputRVector")
        grayscale.setValue(CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0), forKey: "inputGVector")
        grayscale.setValue(CIVector(x: 0.299, y: 0.587, z: 0.114, w: 0), forKey: "inputBVector")
        grayscale.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        
        guard let grainImage = grayscale.outputImage else { return image }
        
        // Blend the grain with the original image using multiply blend mode
        let composite = CIFilter(name: "CIMultiplyBlendMode")!
        composite.setValue(image, forKey: kCIInputBackgroundImageKey)
        composite.setValue(grainImage, forKey: kCIInputImageKey)
        
        // Mix the result with the original based on intensity
        let mix = CIFilter(name: "CIColorBlendMode")!
        mix.setValue(image, forKey: kCIInputBackgroundImageKey)
        mix.setValue(composite.outputImage, forKey: kCIInputImageKey)
        
        return mix.outputImage ?? image
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