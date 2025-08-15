// REPLACE ENTIRE FILE: ViralVideoRenderer.swift

import UIKit
@preconcurrency import AVFoundation
import CoreImage
import CoreMedia
import Foundation

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
        let startTime = Date()
        print("[ViralVideoRenderer] \(startTime): Starting render with \(plan.items.count) items")
        
        // 1) render each TrackItem to a segment
        print("[ViralVideoRenderer] \(Date()): Phase 1 - Creating segments")
        var segs: [URL] = []
        for (i, item) in plan.items.enumerated() {
            let segmentStartTime = Date()
            print("[ViralVideoRenderer] \(segmentStartTime): Creating segment \(i+1)/\(plan.items.count)")
            
            let url = try await createSegmentForTrackItem(item) { segP in
                await progressCallback((Double(i) + segP) / Double(plan.items.count) * 0.7)
            }
            
            let segmentEndTime = Date()
            print("[ViralVideoRenderer] \(segmentEndTime): Segment \(i+1) completed in \(segmentEndTime.timeIntervalSince(segmentStartTime))s, URL: \(url)")
            
            segs.append(url)
            memoryOptimizer.forceMemoryCleanup()
        }
        
        print("[ViralVideoRenderer] \(Date()): All \(segs.count) segments created")

        // 2) stitch segments and add audio (no global zoom ramps!)
        print("[ViralVideoRenderer] \(Date()): Phase 2 - Stitching segments")
        let stitchStartTime = Date()
        let baseURL = try await stitchSegments(segs, duration: plan.outputDuration, audio: plan.audio) { p in
            await progressCallback(0.7 + p * 0.2)
        }
        let stitchEndTime = Date()
        print("[ViralVideoRenderer] \(stitchEndTime): Stitching completed in \(stitchEndTime.timeIntervalSince(stitchStartTime))s, URL: \(baseURL)")

        // 3) overlays
        print("[ViralVideoRenderer] \(Date()): Phase 3 - Applying overlays")
        let overlayStartTime = Date()
        let composited = try await OverlayFactory(config: config).applyOverlays(
            videoURL: baseURL, overlays: plan.overlays) { p in
                await progressCallback(0.9 + p * 0.1)
            }
        let overlayEndTime = Date()
        print("[ViralVideoRenderer] \(overlayEndTime): Overlays completed in \(overlayEndTime.timeIntervalSince(overlayStartTime))s, final URL: \(composited)")
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("[ViralVideoRenderer] \(Date()): Render completed in \(totalTime)s")
        return composited
    }

    // MARK: segment writing
    private func createSegmentForTrackItem(_ item: RenderPlan.TrackItem,
                                           progressCallback: @escaping @Sendable (Double) async -> Void) async throws -> URL {
        print("[ViralVideoRenderer] \(Date()): Creating segment for \(item.kind)")
        
        switch item.kind {
        case .still(let image):
            print("[ViralVideoRenderer] \(Date()): Processing still image with \(item.filters.count) filters")
            let filters = FilterSpecBridge.toCIFilters(item.filters)
            let stillStartTime = Date()
            let url = try await stillWriter.createVideoFromImage(
                image,
                duration: item.timeRange.duration,
                transform: .identity, // we handle fit at stitch time
                filters: filters,
                progressCallback: progressCallback
            )
            let stillEndTime = Date()
            print("[ViralVideoRenderer] \(stillEndTime): Still image processed in \(stillEndTime.timeIntervalSince(stillStartTime))s")
            return url
        case .video(let url):
            print("[ViralVideoRenderer] \(Date()): Using existing video URL: \(url)")
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
        export.outputFileType = .mp4
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
    
    private func createTempOutputURL() -> URL {
        return SnapChef.createTempOutputURL(ext: "mp4")
    }
}

public enum RendererError: Error { 
    case cannotCreateVideoTrack, cannotLoadVideoTrack, cannotCreateExportSession, exportFailed, exportCancelled, exportTimeout
}