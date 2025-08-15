// REPLACE ENTIRE FILE: OverlayFactory.swift

import UIKit
import AVFoundation
import QuartzCore

public final class OverlayFactory: @unchecked Sendable {
    private let config: RenderConfig
    public init(config: RenderConfig) { self.config = config }

    public func createHookOverlay(text: String, config: RenderConfig) -> CALayer {
        let L = CALayer(); L.frame = CGRect(origin: .zero, size: config.size)
        let t = makeText(text: text, size: config.hookFontSize, weight: .bold, center: true)
        t.opacity = 0
        // fade-in (only opacity here; beat pulse uses scale)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0; fade.toValue = 1; fade.duration = config.fadeDuration
        fade.fillMode = .both; fade.isRemovedOnCompletion = false
        fade.beginTime = AVCoreAnimationBeginTimeAtZero
        t.add(fade, forKey: "fadeIn")
        // scale pulse on beats
        t.add(beatScale(duration: 60.0/config.fallbackBPM), forKey: "beatScale")
        L.addSublayer(t); return L
    }

    public func createKineticStepOverlay(text: String, index: Int, beatBPM: Double, config: RenderConfig) -> CALayer {
        let L = CALayer(); L.frame = CGRect(origin: .zero, size: config.size)
        let t = makeText(text: text, size: config.stepsFontSize, weight: .bold, center: false)
        // slide up + scale pop
        let group = CAAnimationGroup()
        let slide = CABasicAnimation(keyPath: "transform.translation.y")
        slide.fromValue = 40; slide.toValue = 0; slide.duration = 0.35
        let pop = CABasicAnimation(keyPath: "transform.scale")
        pop.fromValue = 0.92; pop.toValue = 1.0; pop.duration = 0.35
        group.animations = [slide, pop]; group.fillMode = .both; group.isRemovedOnCompletion = false
        group.beginTime = AVCoreAnimationBeginTimeAtZero
        t.add(group, forKey: "in")

        t.add(beatScale(duration: 60.0/beatBPM), forKey: "beatScale")
        L.addSublayer(t); return L
    }

    public func createCTAOverlay(text: String, config: RenderConfig) -> CALayer {
        let L = CALayer(); L.frame = CGRect(origin: .zero, size: config.size)
        let sticker = CALayer()
        sticker.backgroundColor = UIColor.black.withAlphaComponent(0.85).cgColor
        sticker.cornerRadius = 40
        let pad: CGFloat = 28
        let t = makeText(text: text, size: config.ctaFontSize, weight: .bold, center: true)
        let w = config.size.width - 120; let h = t.preferredFrameSize().height + pad*2
        sticker.frame = CGRect(x: (config.size.width - w)/2,
                               y: config.size.height - config.safeInsets.bottom - h - 16,
                               width: w, height: h)
        t.frame = sticker.bounds.insetBy(dx: pad, dy: pad)
        sticker.addSublayer(t); L.addSublayer(sticker)
        return L
    }

    private func makeText(text: String, size: CGFloat, weight: UIFont.Weight, center: Bool) -> CATextLayer {
        let tl = CATextLayer()
        tl.string = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: UIColor.white
        ])
        tl.alignmentMode = center ? .center : .left
        tl.contentsScale = 2.0 // Use a fixed scale for consistency
        // stroke + shadow to ensure visibility on any fridge photo
        if config.textStrokeEnabled {
            tl.shadowRadius = 4; tl.shadowOpacity = 1; tl.shadowOffset = CGSize(width: 0, height: 2)
            tl.shadowColor = UIColor.black.cgColor
        }
        let maxW = config.size.width - (config.safeInsets.left + config.safeInsets.right)
        let preferred = tl.preferredFrameSize()
        let x = center ? config.safeInsets.left : config.safeInsets.left
        let y = center ? (config.size.height - preferred.height)/2 : (config.safeInsets.top)
        tl.frame = CGRect(x: x, y: y, width: maxW, height: preferred.height)
        tl.isWrapped = true
        return tl
    }

    private func beatScale(duration: Double) -> CAAnimation {
        let k = CAKeyframeAnimation(keyPath: "transform.scale")
        k.values = [1.0, 1.04, 1.0]  // labels can breathe a bit more than bg
        k.keyTimes = [0, 0.5, 1]
        k.duration = max(0.3, duration)
        k.repeatCount = .greatestFiniteMagnitude
        k.isRemovedOnCompletion = false
        k.fillMode = .both
        k.beginTime = AVCoreAnimationBeginTimeAtZero + 0.2
        return k
    }
}

// MARK: - Video compositor that applies CALayer overlays over the base video
import AVFoundation

public extension OverlayFactory {
    /// Renders overlays into the video using CoreAnimationTool and exports a new file.
    func applyOverlays(videoURL: URL,
                       overlays: [RenderPlan.Overlay],
                       progress: @escaping @Sendable (Double) async -> Void = { _ in }) async throws -> URL {
        let base = AVURLAsset(url: videoURL)
        let comp = AVMutableComposition()
        guard let srcV = try await base.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "OverlayFactory", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track"])
        }
        let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let duration = try await base.load(.duration)
        try vTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: srcV, at: .zero)

        // pass-through audio if present
        if let srcA = try? await base.loadTracks(withMediaType: .audio).first {
            let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
            try aTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: srcA, at: .zero)
        }

        // One instruction covering the whole timeline
        let instr = AVMutableVideoCompositionInstruction()
        instr.timeRange = CMTimeRange(start: .zero, duration: duration)
        let layerInstr = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
        instr.layerInstructions = [layerInstr]

        // Build overlay parent with sublayers inserted at their time windows
        let renderSize = config.size
        let parent = CALayer(); parent.frame = CGRect(origin: .zero, size: renderSize)
        let videoLayer = CALayer(); videoLayer.frame = parent.frame
        let overlayLayer = CALayer(); overlayLayer.frame = parent.frame

        // Time-window each overlay
        for ov in overlays {
            let L = ov.layerBuilder(config)
            L.beginTime = ov.start.seconds
            L.duration = ov.duration.seconds
            overlayLayer.addSublayer(L)
        }

        parent.addSublayer(videoLayer)
        parent.addSublayer(overlayLayer)

        let videoComp = AVMutableVideoComposition()
        videoComp.instructions = [instr]
        videoComp.renderSize = renderSize
        videoComp.frameDuration = CMTime(value: 1, timescale: config.fps)
        videoComp.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)

        // Export
        let out = SnapChef.createTempOutputURL()
        try? FileManager.default.removeItem(at: out)
        guard let export = AVAssetExportSession(asset: comp, presetName: ExportSettings.videoPreset) else {
            throw NSError(domain: "OverlayFactory", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session"])
        }
        export.outputURL = out
        export.outputFileType = .mp4
        export.videoComposition = videoComp

        return try await withCheckedThrowingContinuation { cont in
            export.exportAsynchronously {
                switch export.status {
                case .completed: cont.resume(returning: out)
                case .failed: cont.resume(throwing: export.error ?? NSError(domain: "OverlayFactory", code: -3))
                case .cancelled: cont.resume(throwing: NSError(domain: "OverlayFactory", code: -4))
                default: cont.resume(throwing: NSError(domain: "OverlayFactory", code: -5))
                }
            }
        }
    }
}