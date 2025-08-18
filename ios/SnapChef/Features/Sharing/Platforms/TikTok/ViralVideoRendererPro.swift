//
//  ViralVideoRendererPro.swift
//  SnapChef
//
//  Advanced renderer with per-clip transforms, CI filters, and PIP compositor
//

@preconcurrency import AVFoundation
import CoreImage
import CoreMedia
import CoreGraphics
import UIKit

// MARK: - Video Instruction

struct VideoInstruction {
    let timeRange: CMTimeRange
    let trackID: CMPersistentTrackID
    let transform: CGAffineTransform
    let filters: [FilterSpec]
    let pip: PIPInstruction?
}

struct PIPInstruction {
    let frame: CGRect
    let cornerRadius: CGFloat
}

// MARK: - Meta Container Instruction

final class MetaContainerInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    var timeRange: CMTimeRange
    var enablePostProcessing: Bool = false
    var containsTweening: Bool = true
    var requiredSourceTrackIDs: [NSValue]?
    var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    let videoInstructions: [VideoInstruction]
    let pipTrackID: CMPersistentTrackID?

    init(timeRange: CMTimeRange,
         videoInstructions: [VideoInstruction],
         trackIDs: [CMPersistentTrackID],
         pipTrackID: CMPersistentTrackID?) {
        self.timeRange = timeRange
        self.videoInstructions = videoInstructions
        self.pipTrackID = pipTrackID
        self.requiredSourceTrackIDs = trackIDs.map { NSValue(nonretainedObject: NSNumber(value: $0)) }
        super.init()
    }
}

// MARK: - CI Filter Compositor

@objc final class CIFilterCompositor: NSObject, AVVideoCompositing, Sendable {
    // CRITICAL FIX: Remove force unwraps to prevent EXC_BREAKPOINT crashes
    nonisolated(unsafe) private let ciContext: CIContext = {
        let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return CIContext(options: [
            .workingColorSpace: sRGBColorSpace,
            .outputColorSpace: sRGBColorSpace,
            .useSoftwareRenderer: false
        ])
    }()

    // Use os_unfair_lock for thread safety
    nonisolated(unsafe) private var renderContextLock = os_unfair_lock()
    nonisolated(unsafe) private var _renderContext: AVVideoCompositionRenderContext?

    // Required by AVVideoCompositing protocol
    nonisolated var sourcePixelBufferAttributes: [String: any Sendable]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }

    // Required by AVVideoCompositing protocol
    nonisolated var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }

    // Thread-safe render context access
    private var renderContext: AVVideoCompositionRenderContext? {
        get {
            os_unfair_lock_lock(&renderContextLock)
            defer { os_unfair_lock_unlock(&renderContextLock) }
            return _renderContext
        }
        set {
            os_unfair_lock_lock(&renderContextLock)
            defer { os_unfair_lock_unlock(&renderContextLock) }
            _renderContext = newValue
        }
    }

    // Required by AVVideoCompositing protocol
    nonisolated func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        os_unfair_lock_lock(&renderContextLock)
        defer { os_unfair_lock_unlock(&renderContextLock) }
        _renderContext = newRenderContext
    }

    // Optional protocol methods for better performance
    nonisolated var supportsWideColorSourceFrames: Bool { return true }
    nonisolated var supportsHDRSourceFrames: Bool { return false }

    nonisolated func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? MetaContainerInstruction,
              let destinationBuffer = request.renderContext.newPixelBuffer() else {
            request.finish(with: NSError(domain: "CIFilterCompositor", code: -1, userInfo: nil))
            return
        }

        let destinationSize = request.renderContext.size
        var background = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: destinationSize))

        // 1) Composite all non-PIP tracks that overlap this frame time
        let compositionTime = request.compositionTime
        let activeInstructions = instruction.videoInstructions.filter {
            $0.timeRange.containsTime(compositionTime) && $0.pip == nil
        }

        for (index, videoInstruction) in activeInstructions.enumerated() {
            guard let sourceBuffer = request.sourceFrame(byTrackID: videoInstruction.trackID) else {
                continue
            }

            var image = CIImage(cvPixelBuffer: sourceBuffer)

            // REMOVED: Vignette filter that was darkening images

            // Apply transform
            if !videoInstruction.transform.isIdentity {
                image = image.transformed(by: videoInstruction.transform)
            }

            // Apply custom filters
            for filterSpec in videoInstruction.filters {
                image = applyFilter(filterSpec, to: image)
            }

            // PREMIUM FIX: Add crossfade with glow between segments
            if index > 0 {
                // Calculate crossfade alpha based on time position
                let timeInRange = compositionTime.seconds - videoInstruction.timeRange.start.seconds
                let crossfadeDuration = 0.3 // 300ms crossfade

                if timeInRange < crossfadeDuration {
                    let alpha = timeInRange / crossfadeDuration

                    // Add glow during crossfade
                    if let bloom = CIFilter(name: "CIBloom") {
                        bloom.setValue(image, forKey: kCIInputImageKey)
                        bloom.setValue(15.0, forKey: "inputRadius")
                        bloom.setValue(0.8 * (1.0 - alpha), forKey: "inputIntensity") // Fade out glow
                        image = bloom.outputImage ?? image
                    }

                    // Apply alpha fade
                    if let colorMatrix = CIFilter(name: "CIColorMatrix") {
                        colorMatrix.setValue(image, forKey: kCIInputImageKey)
                        let alphaVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(alpha))
                        colorMatrix.setValue(alphaVector, forKey: "inputAVector")
                        image = colorMatrix.outputImage ?? image
                    }
                }
            }

            // Composite over background
            background = image.composited(over: background)
        }

        // 2) Apply PIP if present
        if let pipTrackID = instruction.pipTrackID,
           let pipInstruction = instruction.videoInstructions.first(where: {
               $0.pip != nil && $0.timeRange.containsTime(compositionTime)
           }),
           let pipBuffer = request.sourceFrame(byTrackID: pipTrackID),
           let pip = pipInstruction.pip {
            background = compositePIP(
                pipBuffer: pipBuffer,
                pip: pip,
                over: background,
                canvasSize: destinationSize
            )
        }

        // Render to output buffer
        ciContext.render(background, to: destinationBuffer)
        request.finish(withComposedVideoFrame: destinationBuffer)
    }

    nonisolated private func applyFilter(_ filterSpec: FilterSpec, to image: CIImage) -> CIImage {
        let ciFilters = FilterSpecBridge.toCIFilters([filterSpec])
        guard let filter = ciFilters.first else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)

        return filter.outputImage ?? image
    }

    nonisolated private func compositePIP(pipBuffer: CVPixelBuffer,
                              pip: PIPInstruction,
                              over background: CIImage,
                              canvasSize: CGSize) -> CIImage {
        var pipImage = CIImage(cvPixelBuffer: pipBuffer)

        // PREMIUM FIX: Add glow to PIP for enhanced visual effect
        // CRITICAL FIX: Remove force unwrap to prevent EXC_BREAKPOINT crashes
        if let bloom = CIFilter(name: "CIBloom") {
            bloom.setValue(pipImage, forKey: kCIInputImageKey)
            bloom.setValue(10.0, forKey: "inputRadius")
            bloom.setValue(0.5, forKey: "inputIntensity")
            pipImage = bloom.outputImage ?? pipImage
        } else {
            print("❌ Failed to create CIBloom filter, using original PIP image")
        }

        // Scale PIP to target frame size
        let pipExtent = pipImage.extent
        let scaleX = pip.frame.width / pipExtent.width
        let scaleY = pip.frame.height / pipExtent.height

        pipImage = pipImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        pipImage = pipImage.transformed(by: CGAffineTransform(translationX: pip.frame.minX, y: pip.frame.minY))

        // Create circular mask with shadow effect
        let maskImage = createCircularMask(
            size: canvasSize,
            rect: pip.frame,
            cornerRadius: pip.cornerRadius
        )

        // Apply mask
        pipImage = applyMask(pipImage, mask: maskImage)

        // PREMIUM FIX: Add drop shadow for depth
        var finalBackground = background
        if let shadowFilter = CIFilter(name: "CIGaussianBlur") {
            var shadowImage = pipImage
            shadowFilter.setValue(shadowImage, forKey: kCIInputImageKey)
            shadowFilter.setValue(8.0, forKey: "inputRadius")
            shadowImage = shadowFilter.outputImage ?? shadowImage

            // Offset shadow
            shadowImage = shadowImage.transformed(by: CGAffineTransform(translationX: 2, y: -2))

            // Darken shadow
            if let colorMatrix = CIFilter(name: "CIColorMatrix") {
                colorMatrix.setValue(shadowImage, forKey: kCIInputImageKey)
                colorMatrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0.5), forKey: "inputAVector")
                shadowImage = colorMatrix.outputImage ?? shadowImage

                // Composite shadow first, then PIP
                finalBackground = shadowImage.composited(over: finalBackground)
            }
        }

        return pipImage.composited(over: finalBackground)
    }

    nonisolated private func createCircularMask(size: CGSize, rect: CGRect, cornerRadius: CGFloat) -> CIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else {
            return CIImage()
        }

        // Fill with black (transparent)
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Draw white circle/rounded rect (opaque)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.setFillColor(UIColor.white.cgColor)
        context.addPath(path.cgPath)
        context.fillPath()

        guard let maskImage = UIGraphicsGetImageFromCurrentImageContext(),
              let ciMask = CIImage(image: maskImage) else {
            return CIImage()
        }

        return ciMask
    }

    nonisolated private func applyMask(_ image: CIImage, mask: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIImage(color: .clear).cropped(to: image.extent), forKey: kCIInputBackgroundImageKey)
        filter.setValue(mask, forKey: kCIInputMaskImageKey)

        return filter.outputImage ?? image
    }
}

// MARK: - Renderer Pro

public final class ViralVideoRendererPro: Sendable {
    private let memoryOptimizer = MemoryOptimizer.shared

    public init() {}

    public func render(
        plan: RenderPlan,
        config: RenderConfig,
        progressCallback: @escaping @Sendable (Double) async -> Void = { _ in }
    ) async throws -> URL {
        let startTime = Date()
        print("[ViralVideoRendererPro] \(startTime): Starting render with \(plan.items.count) items")

        memoryOptimizer.logMemoryProfile(phase: "RendererPro Start")

        print("[ViralVideoRendererPro] \(Date()): Creating composition and video tracks")
        let composition = AVMutableComposition()
        var videoTracks: [AVMutableCompositionTrack] = []

        // Create video tracks
        let trackCount = max(2, plan.items.count)
        print("[ViralVideoRendererPro] \(Date()): Creating \(trackCount) video tracks")
        for i in 0..<trackCount {
            if let track = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                videoTracks.append(track)
                print("[ViralVideoRendererPro] \(Date()): Created video track \(i + 1) with ID: \(track.trackID)")
            }
        }
        print("[ViralVideoRendererPro] \(Date()): Created \(videoTracks.count) video tracks total")

        // Process items and create instructions
        print("[ViralVideoRendererPro] \(Date()): Starting to process items and create instructions")
        var instructions: [VideoInstruction] = []

        print("[ViralVideoRendererPro] \(Date()): Preloading still images")
        let preloadStartTime = Date()
        let stillURLs = try await preloadStills(plan: plan, config: config)
        let preloadEndTime = Date()
        print("[ViralVideoRendererPro] \(preloadEndTime): Preloaded \(stillURLs.count) stills in \(preloadEndTime.timeIntervalSince(preloadStartTime))s")

        var trackIndex = 0

        print("[ViralVideoRendererPro] \(Date()): Processing \(plan.items.count) items")
        for (index, item) in plan.items.enumerated() {
            let itemStartTime = Date()
            print("[ViralVideoRendererPro] \(itemStartTime): Processing item \(index + 1)/\(plan.items.count): \(item.kind)")

            let assetURL: URL

            switch item.kind {
            case .video(let url):
                print("[ViralVideoRendererPro] \(Date()): Using video URL: \(url)")
                assetURL = url
            case .still:
                guard let url = stillURLs[index] else {
                    print("[ViralVideoRendererPro] \(Date()): ERROR - No preloaded still URL for index \(index)")
                    continue
                }
                print("[ViralVideoRendererPro] \(Date()): Using preloaded still URL: \(url)")
                assetURL = url
            }

            print("[ViralVideoRendererPro] \(Date()): Loading asset from \(assetURL)")
            let asset = AVAsset(url: assetURL)
            guard let sourceTrack = try await asset.loadTracks(withMediaType: .video).first else {
                print("[ViralVideoRendererPro] \(Date()): ERROR - No video track found in asset \(assetURL)")
                continue
            }

            let destinationTrack = videoTracks[trackIndex % videoTracks.count]
            trackIndex += 1

            print("[ViralVideoRendererPro] \(Date()): Inserting time range into track \(destinationTrack.trackID)")
            // Insert time range
            try destinationTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: item.timeRange.duration),
                of: sourceTrack,
                at: item.timeRange.start
            )
            print("[ViralVideoRendererPro] \(Date()): Inserted range: start=\(item.timeRange.start.seconds)s, duration=\(item.timeRange.duration.seconds)s")

            // REMOVED: Premium filters that were darkening images
            let enhancedFilters = item.filters  // Use original filters only

            // Create instruction with enhanced filters
            let instruction = VideoInstruction(
                timeRange: item.timeRange,
                trackID: destinationTrack.trackID,
                transform: .identity,  // TransformSpec needs conversion to CGAffineTransform
                filters: enhancedFilters,
                pip: nil
            )
            instructions.append(instruction)

            // Update progress
            let progress = Double(index + 1) / Double(plan.items.count) * 0.5
            let itemEndTime = Date()
            print("[ViralVideoRendererPro] \(itemEndTime): Item \(index + 1) completed in \(itemEndTime.timeIntervalSince(itemStartTime))s, progress: \(progress * 100)%")
            await progressCallback(progress)
        }
        print("[ViralVideoRendererPro] \(Date()): All items processed, created \(instructions.count) instructions")

        // Handle PIP track if present - NOT IMPLEMENTED YET
        let pipTrackID: CMPersistentTrackID? = nil
        /*
        if let pip = plan.pip {
            let pipAsset = AVAsset(url: pip.url)
            if let pipSourceTrack = try await pipAsset.loadTracks(withMediaType: AVMediaType.video).first,
               let pipTrack = composition.addMutableTrack(
                   withMediaType: .video,
                   preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                
                try pipTrack.insertTimeRange(
                    pip.timeRange,
                    of: pipSourceTrack,
                    at: pip.timeRange.start
                )
                pipTrackID = pipTrack.trackID
                
                // Add PIP instruction
                let pipInstruction = VideoInstruction(
                    timeRange: pip.timeRange,
                    trackID: pipTrack.trackID,
                    transform: .identity,
                    filters: [],
                    pip: PIPInstruction(frame: pip.frame, cornerRadius: pip.cornerRadius)
                )
                instructions.append(pipInstruction)
            }
        }
        */

        // Add audio if present
        if let audioURL = plan.audio {
            print("[ViralVideoRendererPro] \(Date()): Adding audio track from: \(audioURL)")
            let audioStartTime = Date()
            try await addAudioTrack(to: composition, audioURL: audioURL, duration: plan.outputDuration)
            let audioEndTime = Date()
            print("[ViralVideoRendererPro] \(audioEndTime): Audio track added in \(audioEndTime.timeIntervalSince(audioStartTime))s")
        } else {
            print("[ViralVideoRendererPro] \(Date()): No audio track to add")
        }

        // Create video composition
        print("[ViralVideoRendererPro] \(Date()): Creating video composition")
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = config.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: config.fps)
        videoComposition.customVideoCompositorClass = CIFilterCompositor.self
        print("[ViralVideoRendererPro] \(Date()): Video composition configured - size: \(config.size), fps: \(config.fps)")

        // Build AV instructions
        print("[ViralVideoRendererPro] \(Date()): Building AV instructions")
        let fullTimeRange = CMTimeRange(start: .zero, duration: plan.outputDuration)
        let metaInstruction = MetaContainerInstruction(
            timeRange: fullTimeRange,
            videoInstructions: instructions,
            trackIDs: videoTracks.map { $0.trackID },
            pipTrackID: pipTrackID
        )
        videoComposition.instructions = [metaInstruction]
        print("[ViralVideoRendererPro] \(Date()): Meta instruction created with \(instructions.count) video instructions")

        // Export
        print("[ViralVideoRendererPro] \(Date()): Starting export process")
        let outputURL = createTempOutputURL()
        print("[ViralVideoRendererPro] \(Date()): Export output URL: \(outputURL)")
        await progressCallback(0.7)

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            print("[ViralVideoRendererPro] \(Date()): ERROR - Failed to create export session")
            throw ViralVideoError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        // Configure export settings
        print("[ViralVideoRendererPro] \(Date()): Configuring audio mix")
        exportSession.audioMix = createAudioMix(for: composition)

        print("[ViralVideoRendererPro] \(Date()): Starting export session...")
        let exportStartTime = Date()

        // Add progress monitoring
        let progressTask = Task { @Sendable in
            while exportSession.status == .exporting {
                let progress = exportSession.progress
                let elapsed = Date().timeIntervalSince(exportStartTime)
                print("[ViralVideoRendererPro] \(Date()): Export progress: \(progress * 100)% (\(elapsed)s elapsed)")

                if elapsed > 120 { // 2 minute timeout
                    print("[ViralVideoRendererPro] \(Date()): ERROR - Export timeout after \(elapsed)s")
                    exportSession.cancelExport()
                    break
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }

        await exportSession.export()
        progressTask.cancel()

        let exportEndTime = Date()
        let exportDuration = exportEndTime.timeIntervalSince(exportStartTime)
        print("[ViralVideoRendererPro] \(exportEndTime): Export completed in \(exportDuration)s with status: \(exportSession.status.rawValue)")

        await progressCallback(1.0)

        guard exportSession.status == .completed else {
            print("[ViralVideoRendererPro] \(Date()): ERROR - Export failed with error: \(exportSession.error?.localizedDescription ?? "Unknown")")
            throw ViralVideoError.exportFailed
        }

        print("[ViralVideoRendererPro] \(Date()): Export SUCCESS - Final output: \(outputURL)")
        memoryOptimizer.logMemoryProfile(phase: "RendererPro Complete")

        let totalTime = Date().timeIntervalSince(startTime)
        print("[ViralVideoRendererPro] \(Date()): Total render time: \(totalTime)s")
        return outputURL
    }

    private func preloadStills(plan: RenderPlan, config: RenderConfig) async throws -> [Int: URL] {
        print("[ViralVideoRendererPro] \(Date()): Starting preloadStills")
        var urlMap: [Int: URL] = [:]
        var stillCount = 0

        for (index, item) in plan.items.enumerated() {
            if case .still(let image) = item.kind {
                stillCount += 1
                let stillStartTime = Date()
                print("[ViralVideoRendererPro] \(stillStartTime): Processing still \(stillCount) at index \(index) with \(item.filters.count) filters")

                // Apply filters to still image
                var processedImage = image

                if !item.filters.isEmpty {
                    print("[ViralVideoRendererPro] \(Date()): Applying \(item.filters.count) filters to still image")
                    guard var ciImage = CIImage(image: image) else {
                        print("[ViralVideoRendererPro] \(Date()): ERROR - Cannot create CIImage from UIImage")
                        continue
                    }

                    let ciFilters = FilterSpecBridge.toCIFilters(item.filters)
                    for (filterIndex, filter) in ciFilters.enumerated() {
                        print("[ViralVideoRendererPro] \(Date()): Applying filter \(filterIndex + 1)/\(ciFilters.count)")
                        filter.setValue(ciImage, forKey: kCIInputImageKey)
                        ciImage = filter.outputImage ?? ciImage
                    }

                    print("[ViralVideoRendererPro] \(Date()): Rendering filtered image to CGImage")
                    let context = CIContext()
                    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                        processedImage = UIImage(cgImage: cgImage)
                        print("[ViralVideoRendererPro] \(Date()): Filtered image rendered successfully")
                    } else {
                        print("[ViralVideoRendererPro] \(Date()): WARNING - Failed to render filtered image, using original")
                    }
                }

                // Create video from still
                print("[ViralVideoRendererPro] \(Date()): Creating video from still image")
                let stillWriter = StillWriter(config: config)
                let url = try await stillWriter.createVideoFromImage(
                    processedImage,
                    duration: item.timeRange.duration
                )
                urlMap[index] = url

                let stillEndTime = Date()
                print("[ViralVideoRendererPro] \(stillEndTime): Still \(stillCount) processed in \(stillEndTime.timeIntervalSince(stillStartTime))s, URL: \(url)")
            }
        }

        print("[ViralVideoRendererPro] \(Date()): Preloaded \(stillCount) stills, returning \(urlMap.count) URLs")
        return urlMap
    }

    private func addAudioTrack(to composition: AVMutableComposition, audioURL: URL, duration: CMTime) async throws {
        let audioAsset = AVAsset(url: audioURL)
        guard let audioSourceTrack = try await audioAsset.loadTracks(withMediaType: .audio).first,
              let audioTrack = composition.addMutableTrack(
                  withMediaType: .audio,
                  preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            return
        }

        let audioDuration = min(try await audioAsset.load(.duration), duration)
        try audioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: audioDuration),
            of: audioSourceTrack,
            at: .zero
        )
    }

    private func createAudioMix(for composition: AVComposition) -> AVAudioMix {
        let audioMix = AVMutableAudioMix()
        var audioParameters: [AVMutableAudioMixInputParameters] = []

        for track in composition.tracks(withMediaType: .audio) {
            let parameters = AVMutableAudioMixInputParameters(track: track)
            parameters.setVolume(1.0, at: .zero)
            audioParameters.append(parameters)
        }

        audioMix.inputParameters = audioParameters
        return audioMix
    }

    private func createTempOutputURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "viral_pro_\(Date().timeIntervalSince1970).mp4"
        return tempDir.appendingPathComponent(filename)
    }
}
