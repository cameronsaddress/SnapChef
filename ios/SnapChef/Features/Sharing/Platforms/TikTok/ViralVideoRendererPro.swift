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

@objc final class CIFilterCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    
    nonisolated(unsafe) private let ciContext = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        .useSoftwareRenderer: false
    ])
    
    // Use os_unfair_lock for thread safety
    nonisolated(unsafe) private var renderContextLock = os_unfair_lock()
    nonisolated(unsafe) private var _renderContext: AVVideoCompositionRenderContext?
    
    // Required by AVVideoCompositing protocol
    nonisolated var sourcePixelBufferAttributes: [String : any Sendable]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }
    
    // Required by AVVideoCompositing protocol
    nonisolated var requiredPixelBufferAttributesForRenderContext: [String : any Sendable] {
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
        
        for videoInstruction in activeInstructions {
            guard let sourceBuffer = request.sourceFrame(byTrackID: videoInstruction.trackID) else { 
                continue 
            }
            
            var image = CIImage(cvPixelBuffer: sourceBuffer)
            
            // Apply transform
            if !videoInstruction.transform.isIdentity {
                image = image.transformed(by: videoInstruction.transform)
            }
            
            // Apply filters
            for filterSpec in videoInstruction.filters {
                image = applyFilter(filterSpec, to: image)
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
        guard let filter = CIFilter(name: filterSpec.name) else { 
            return image 
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        
        // Apply parameters
        for (key, value) in filterSpec.params {
            filter.setValue(value.value, forKey: key)
        }
        
        return filter.outputImage ?? image
    }
    
    nonisolated private func compositePIP(pipBuffer: CVPixelBuffer, 
                              pip: PIPInstruction, 
                              over background: CIImage,
                              canvasSize: CGSize) -> CIImage {
        var pipImage = CIImage(cvPixelBuffer: pipBuffer)
        
        // Scale PIP to target frame size
        let pipExtent = pipImage.extent
        let scaleX = pip.frame.width / pipExtent.width
        let scaleY = pip.frame.height / pipExtent.height
        
        pipImage = pipImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        pipImage = pipImage.transformed(by: CGAffineTransform(translationX: pip.frame.minX, y: pip.frame.minY))
        
        // Create circular mask
        let maskImage = createCircularMask(
            size: canvasSize,
            rect: pip.frame,
            cornerRadius: pip.cornerRadius
        )
        
        // Apply mask and composite
        pipImage = applyMask(pipImage, mask: maskImage)
        return pipImage.composited(over: background)
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

public final class ViralVideoRendererPro: @unchecked Sendable {
    
    private let memoryOptimizer = MemoryOptimizer.shared
    
    public init() {}
    
    public func render(
        plan: RenderPlan,
        config: RenderConfig,
        progressCallback: @escaping @Sendable (Double) async -> Void = { _ in }
    ) async throws -> URL {
        
        memoryOptimizer.logMemoryProfile(phase: "RendererPro Start")
        
        let composition = AVMutableComposition()
        var videoTracks: [AVMutableCompositionTrack] = []
        
        // Create video tracks
        let trackCount = max(2, plan.items.count)
        for _ in 0..<trackCount {
            if let track = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                videoTracks.append(track)
            }
        }
        
        // Process items and create instructions
        var instructions: [VideoInstruction] = []
        let stillURLs = try await preloadStills(plan: plan, config: config)
        var trackIndex = 0
        
        for (index, item) in plan.items.enumerated() {
            let assetURL: URL
            
            switch item.kind {
            case .video(let url):
                assetURL = url
            case .still:
                guard let url = stillURLs[index] else { continue }
                assetURL = url
            }
            
            let asset = AVAsset(url: assetURL)
            guard let sourceTrack = try await asset.loadTracks(withMediaType: .video).first else {
                continue
            }
            
            let destinationTrack = videoTracks[trackIndex % videoTracks.count]
            trackIndex += 1
            
            // Insert time range
            try destinationTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: item.timeRange.duration),
                of: sourceTrack,
                at: item.timeRange.start
            )
            
            // Create instruction
            let instruction = VideoInstruction(
                timeRange: item.timeRange,
                trackID: destinationTrack.trackID,
                transform: item.transform,
                filters: item.filters,
                pip: nil
            )
            instructions.append(instruction)
            
            // Update progress
            let progress = Double(index + 1) / Double(plan.items.count) * 0.5
            await progressCallback(progress)
        }
        
        // Handle PIP track if present
        var pipTrackID: CMPersistentTrackID?
        if let pip = plan.pip {
            let pipAsset = AVAsset(url: pip.url)
            if let pipSourceTrack = try await pipAsset.loadTracks(withMediaType: .video).first,
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
        
        // Add audio if present
        if let audioURL = plan.audio {
            try await addAudioTrack(to: composition, audioURL: audioURL, duration: plan.outputDuration)
        }
        
        // Create video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = config.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: config.fps)
        videoComposition.customVideoCompositorClass = CIFilterCompositor.self
        
        // Build AV instructions
        let fullTimeRange = CMTimeRange(start: .zero, duration: plan.outputDuration)
        let metaInstruction = MetaContainerInstruction(
            timeRange: fullTimeRange,
            videoInstructions: instructions,
            trackIDs: videoTracks.map { $0.trackID },
            pipTrackID: pipTrackID
        )
        videoComposition.instructions = [metaInstruction]
        
        // Export
        let outputURL = createTempOutputURL()
        await progressCallback(0.7)
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ViralVideoError.exportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Configure export settings
        exportSession.audioMix = createAudioMix(for: composition)
        
        await exportSession.export()
        await progressCallback(1.0)
        
        guard exportSession.status == .completed else {
            throw ViralVideoError.exportFailed
        }
        
        memoryOptimizer.logMemoryProfile(phase: "RendererPro Complete")
        return outputURL
    }
    
    private func preloadStills(plan: RenderPlan, config: RenderConfig) async throws -> [Int: URL] {
        var urlMap: [Int: URL] = [:]
        
        for (index, item) in plan.items.enumerated() {
            if case .still(let image) = item.kind {
                // Apply filters to still image
                var processedImage = image
                
                if !item.filters.isEmpty {
                    guard var ciImage = CIImage(image: image) else { continue }
                    
                    for filterSpec in item.filters {
                        if let filter = CIFilter(name: filterSpec.name) {
                            filter.setValue(ciImage, forKey: kCIInputImageKey)
                            for (key, value) in filterSpec.params {
                                filter.setValue(value.value, forKey: key)
                            }
                            ciImage = filter.outputImage ?? ciImage
                        }
                    }
                    
                    let context = CIContext()
                    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                        processedImage = UIImage(cgImage: cgImage)
                    }
                }
                
                // Create video from still
                let stillWriter = StillWriter(config: config)
                let url = try await stillWriter.createVideoFromImage(
                    processedImage,
                    duration: item.timeRange.duration
                )
                urlMap[index] = url
            }
        }
        
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