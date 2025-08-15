// REPLACE ENTIRE FILE: ViralVideoRenderer.swift

import UIKit
@preconcurrency import AVFoundation
import CoreImage
import CoreMedia

public final class ViralVideoRenderer: @unchecked Sendable {
    private let config: RenderConfig
    private let stillWriter: StillWriter
    private let ciContext: CIContext
    private let memoryOptimizer = MemoryOptimizer.shared

    public init(config: RenderConfig) {
        self.config = config
        self.stillWriter = StillWriter(config: config)
        self.ciContext = memoryOptimizer.getCIContext()
    }

    public func render(plan: RenderPlan,
                       config: RenderConfig,
                       progressCallback: @escaping @Sendable (Double) async -> Void = { _ in }) async throws -> URL {
        // 1) render each TrackItem to a segment
        var segs: [URL] = []
        for (i, item) in plan.items.enumerated() {
            let url = try await createSegmentForTrackItem(item) { segP in
                await progressCallback((Double(i) + segP) / Double(plan.items.count) * 0.7)
            }
            segs.append(url)
            memoryOptimizer.forceMemoryCleanup()
        }

        // 2) stitch segments and add audio (no global zoom ramps!)
        let baseURL = try await stitchSegments(segs, duration: plan.outputDuration, audio: plan.audio) { p in
            await progressCallback(0.7 + p * 0.2)
        }

        // 3) overlays
        let composited = try await OverlayFactory(config: config).applyOverlays(
            videoURL: baseURL, overlays: plan.overlays) { p in
                await progressCallback(0.9 + p * 0.1)
            }

        return composited
    }

    // MARK: segment writing
    private func createSegmentForTrackItem(_ item: RenderPlan.TrackItem,
                                           progressCallback: @escaping @Sendable (Double) async -> Void) async throws -> URL {
        switch item.kind {
        case .still(let image):
            let filters = FilterSpecBridge.toCIFilters(item.filters)
            return try await stillWriter.createVideoFromImage(
                image,
                duration: item.timeRange.duration,
                transform: .identity, // we handle fit at stitch time
                filters: filters,
                progressCallback: progressCallback
            )
        case .video(let url):
            return url
        }
    }

    // MARK: stitch + fit
    private func stitchSegments(_ segments: [URL], duration: CMTime, audio: URL?,
                                progress: @escaping @Sendable (Double) async -> Void) async throws -> URL {
        let composition = AVMutableComposition()
        let vTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        var cursor = CMTime.zero

        // place each segment
        for url in segments {
            let asset = AVAsset(url: url)
            guard let t = try await asset.loadTracks(withMediaType: .video).first else { continue }
            let d = try await asset.load(.duration)
            try vTrack.insertTimeRange(CMTimeRange(start: .zero, duration: d), of: t, at: cursor)
            cursor = cursor + d
        }

        // add audio once
        if let audioURL = audio,
           let aTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let aAsset = AVAsset(url: audioURL)
            if let src = try await aAsset.loadTracks(withMediaType: .audio).first {
                let aDur = try await aAsset.load(.duration)
                try aTrack.insertTimeRange(CMTimeRange(start: .zero, duration: min(aDur, composition.duration)),
                                           of: src, at: .zero)
            }
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
        let outURL = createTempOutputURL()
        try? FileManager.default.removeItem(at: outURL)
        guard let export = AVAssetExportSession(asset: composition, presetName: ExportSettings.videoPreset) else {
            throw RendererError.cannotCreateExportSession
        }
        export.outputURL = outURL
        export.outputFileType = .mp4
        export.videoComposition = videoComp
        return try await withCheckedThrowingContinuation { cont in
            export.exportAsynchronously {
                switch export.status {
                case .completed: cont.resume(returning: outURL)
                case .failed: cont.resume(throwing: RendererError.exportFailed)
                case .cancelled: cont.resume(throwing: RendererError.exportCancelled)
                default: cont.resume(throwing: RendererError.exportFailed)
                }
            }
        }
    }
    
    private func createTempOutputURL() -> URL {
        return SnapChef.createTempOutputURL(ext: "mp4")
    }
}

public enum RendererError: Error { case cannotCreateVideoTrack, cannotLoadVideoTrack, cannotCreateExportSession, exportFailed, exportCancelled }