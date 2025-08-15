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

        // Optional gentle Ken Burns baked per-frame (≤5%)
        let totalFrames = max(1, Int(duration.seconds * Double(config.fps)))
        let maxScale = config.maxKenBurnsScale
        var t: Double = 0
        let dt = 1.0 / Double(config.fps)

        // Log memory usage at start
        memoryOptimizer.logMemoryProfile("StillWriter start")

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

            // subtle scale from 1.0 → maxScale
            let lerp = CGFloat(Double(frame) / Double(max(1,totalFrames-1)))
            let s = 1.0 + (maxScale - 1.0) * lerp

            var img = fitted.transformed(by:
                CGAffineTransform(translationX: canvas.midX, y: canvas.midY)
                    .scaledBy(x: s, y: s)
                    .translatedBy(x: -canvas.midX, y: -canvas.midY)
            )

            // Apply filters with autoreleasepool for memory management
            for f in filters { 
                autoreleasepool {
                    f.setValue(img, forKey: kCIInputImageKey)
                    img = f.outputImage ?? img
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
                memoryOptimizer.logMemoryProfile("Frame \(frame)")
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
        let s = min(sx, sy) // full image visible (prevents "way too zoomed in")
        let scaledW = w * s, scaledH = h * s
        let tx = (canvas.width - scaledW)/2, ty = (canvas.height - scaledH)/2
        return image.transformed(by: CGAffineTransform(scaleX: s, y: s))
            .transformed(by: CGAffineTransform(translationX: tx, y: ty))
            .cropped(to: canvas)
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