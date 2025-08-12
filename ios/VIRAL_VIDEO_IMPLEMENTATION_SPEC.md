# TikTok Viral Video Implementation Specification

## Production-Grade Scaffold for Swift 6 / iOS

This document contains the EXACT implementation for 5 viral video formats with super-detailed build notes. Everything is designed to pull dynamic text from the Recipe, keep copy inside TikTok-safe UI zones, and export gorgeous 1080×1920 H.264 + AAC videos for TikTok OpenSDK sharing.

## High-Level Architecture

- **ViralVideoEngine**: One entry point to render any template
- **ViralTemplate**: Enum of 5 formats
- **RenderPlan**: Timeline of clips, overlays, and animations (template-specific)
- **Renderer**: AVFoundation + Core Animation compositor
- **OverlayFactory**: Text, stickers, counters, progress bar, captions
- **FX**: Ken Burns, split-wipe, color pop, beat-snapped photo durations
- **AudioService**: (optional) beat peak detection for better cuts
- **ShareService**: Save to Photos → get PHAsset localIdentifier → send to TikTok

## Data Models (Drop-In)

```swift
import Foundation
import UIKit
import AVFoundation
import CoreMedia
import CoreGraphics

public struct Recipe: Codable {
    public struct Step: Codable { 
        public let title: String
        public let secondsHint: Double? 
    }
    
    public let title: String
    public let hook: String?                 // e.g., "Fridge chaos → dinner in 15"
    public let steps: [Step]                  // 3–7 steps works best
    public let timeMinutes: Int?              // e.g., 15
    public let costDollars: Int?              // e.g., 7
    public let calories: Int?                 // optional
    public let ingredients: [String]          // ["eggs", "spinach", "garlic", ...]
}

public struct MediaBundle {
    public let beforeFridge: UIImage
    public let afterFridge: UIImage
    public let cookedMeal: UIImage            // plated beauty
    public let brollClips: [URL]              // optional cooking clips (vertical)
    public let musicURL: URL?                 // optional; otherwise silent
    
    public init(beforeFridge: UIImage, afterFridge: UIImage, cookedMeal: UIImage,
                brollClips: [URL] = [], musicURL: URL? = nil) {
        self.beforeFridge = beforeFridge
        self.afterFridge = afterFridge
        self.cookedMeal = cookedMeal
        self.brollClips = brollClips
        self.musicURL = musicURL
    }
}

// Global render knobs
public struct RenderConfig {
    public var size = CGSize(width: 1080, height: 1920) // 9:16
    public var fps: Int32 = 30
    public var safeInsets = UIEdgeInsets(top: 192, left: 72, bottom: 192, right: 72) // ~10% top/btm, 72px sides
    public var maxDuration: CMTime = CMTime(seconds: 15, preferredTimescale: 600)
    public var fontNameBold: String = "SF-Pro-Display-Bold" // fallback to system if missing
    public var fontNameRegular: String = "SF-Pro-Display-Regular"
    public var textStrokeEnabled: Bool = true
    public var brandTint: UIColor = .white
    public var brandShadow: UIColor = .black
    public init() {}
}
```

## Engine + Templates

```swift
public enum ViralTemplate {
    case beatSyncedCarousel        // 1
    case splitSwipe                // 2
    case kineticSteps              // 3
    case priceTimeChallenge        // 4
    case greenScreenPIP            // 5
}

// Primary entry
public final class ViralVideoEngine {
    private let renderer = Renderer()
    private let planner = Planner()
    
    public init() {}
    
    public func render(template: ViralTemplate,
                       recipe: Recipe,
                       media: MediaBundle,
                       config: RenderConfig = RenderConfig(),
                       completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            let plan = try planner.makePlan(for: template, recipe: recipe, media: media, config: config)
            renderer.render(plan: plan, config: config, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
}
```

## The Planning Layer (Timelines per Template)

```swift
import QuartzCore
import Photos

// === RenderPlan ===

public struct RenderPlan {
    public struct TrackItem {
        public enum Kind { case still(UIImage), video(URL) }
        public let kind: Kind
        public let timeRange: CMTimeRange
        public let transform: CGAffineTransform // scaling/panning for Ken Burns/PIP
        public let filters: [CIFilter]          // color pop, etc.
        public init(kind: Kind, timeRange: CMTimeRange,
                    transform: CGAffineTransform = .identity, filters: [CIFilter] = []) {
            self.kind = kind; self.timeRange = timeRange; self.transform = transform; self.filters = filters
        }
    }
    public struct Overlay {
        public let start: CMTime
        public let duration: CMTime
        public let layerBuilder: (_ config: RenderConfig) -> CALayer
    }
    public let items: [TrackItem]
    public let overlays: [Overlay]
    public let audio: URL?             // bgm
    public let outputDuration: CMTime
}

// === Planner ===

final class Planner {
    enum PlanError: Error { case notEnoughMedia, badSteps }
    
    func makePlan(for template: ViralTemplate,
                  recipe: Recipe,
                  media: MediaBundle,
                  config: RenderConfig) throws -> RenderPlan {
        switch template {
        case .beatSyncedCarousel:   return try planBeatSynced(recipe, media, config)
        case .splitSwipe:           return try planSplitSwipe(recipe, media, config)
        case .kineticSteps:         return try planKinetic(recipe, media, config)
        case .priceTimeChallenge:   return try planPriceTime(recipe, media, config)
        case .greenScreenPIP:       return try planGreenScreen(recipe, media, config)
        }
    }
}
```

## Template 1: Beat-Synced Photo Carousel "Snap Reveal"

```swift
private extension Planner {
    func planBeatSynced(_ recipe: Recipe, _ media: MediaBundle, _ cfg: RenderConfig) throws -> RenderPlan {
        // Durations (snap to 10–12s)
        let total = min(CMTime(seconds: 12, preferredTimescale: 600), cfg.maxDuration)
        let hookDur = CMTime(seconds: 2.0, preferredTimescale: 600)
        let snapDur = CMTime(seconds: 1.0, preferredTimescale: 600) // per image, will be beat-snapped later
        
        // Build timeline: BEFORE (blurred), ingredient/meal snaps, AFTER
        var timeCursor = CMTime.zero
        var items: [RenderPlan.TrackItem] = []
        var overlays: [RenderPlan.Overlay] = []
        
        // 0–2s hook on blurred BEFORE
        let blurFilter = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 10])!
        items.append(.init(kind: .still(media.beforeFridge),
                           timeRange: CMTimeRange(start: timeCursor, duration: hookDur),
                           transform: .identity, filters: [blurFilter]))
        
        overlays.append(heroHookOverlay(text: recipe.hook ?? defaultHook(from: recipe),
                                        start: timeCursor, dur: hookDur))
        timeCursor = timeCursor + hookDur
        
        // snaps (ingredients → cooked meal)
        let snapImages: [UIImage] = buildSnapSequence(from: media, recipe: recipe)
        for (idx, img) in snapImages.enumerated() {
            let dur = snapDur
            let tRange = CMTimeRange(start: timeCursor, duration: dur)
            let kb = kenBurnsTransform(index: idx, total: snapImages.count, in: cfg.size)
            items.append(.init(kind: .still(img), timeRange: tRange, transform: kb))
            if idx < min(3, recipe.ingredients.count) {
                overlays.append(ingredientCallout(text: recipe.ingredients[idx].capitalized,
                                                  start: timeCursor, dur: dur))
            }
            timeCursor = timeCursor + dur
        }
        
        // Final AFTER + CTA
        let tail = total - timeCursor
        if tail.seconds > 0.2 {
            items.append(.init(kind: .still(media.afterFridge),
                               timeRange: CMTimeRange(start: timeCursor, duration: tail)))
            overlays.append(ctaOverlay(text: "Try this tonight? 👇", start: timeCursor, dur: tail))
        }
        
        // (Optional) beat-align: your AudioService would adjust each snap's duration to nearest beat
        // For scaffold simplicity we keep fixed 1s snaps.
        
        return RenderPlan(items: items, overlays: overlays, audio: media.musicURL, outputDuration: total)
    }
    
    // helpers
    func defaultHook(from recipe: Recipe) -> String {
        let t = recipe.timeMinutes.map { "\($0) min" } ?? "quick"
        let c = recipe.costDollars.map { "$\($0)" } ?? "$"
        return "Fridge chaos → dinner in \(t) (\(c))"
    }
    
    func buildSnapSequence(from media: MediaBundle, recipe: Recipe) -> [UIImage] {
        // BEFORE (already used) → focus on cooked meal + close crop → AFTER fridge
        // you can add additional crops later—scaffold keeps it simple.
        return [media.cookedMeal, media.afterFridge]
    }
    
    func kenBurnsTransform(index: Int, total: Int, in size: CGSize) -> CGAffineTransform {
        // gentle 1.08x pan/zoom alternating direction
        let scale: CGFloat = 1.08
        let dir: CGFloat = (index % 2 == 0) ? 1 : -1
        return CGAffineTransform(translationX: dir * size.width * 0.02, y: dir * size.height * 0.02)
            .scaledBy(x: scale, y: scale)
    }
}
```

## Template 2: Split-Screen "Swipe" Before/After + Counters

```swift
private extension Planner {
    func planSplitSwipe(_ recipe: Recipe, _ media: MediaBundle, _ cfg: RenderConfig) throws -> RenderPlan {
        let total = CMTime(seconds: 9, preferredTimescale: 600)
        var items: [RenderPlan.TrackItem] = []
        var overlays: [RenderPlan.Overlay] = []
        
        // 0–1.5s BEFORE full
        let p0 = CMTime(seconds: 1.5, preferredTimescale: 600)
        items.append(.init(kind: .still(media.beforeFridge), timeRange: CMTimeRange(start: .zero, duration: p0)))
        overlays.append(heroHookOverlay(text: recipe.hook ?? "From this…", start: .zero, dur: p0))
        
        // 1.5–3s AFTER masked reveal (we build mask in overlays)
        let p1Start = p0
        let p1Dur = CMTime(seconds: 1.5, preferredTimescale: 600)
        items.append(.init(kind: .still(media.afterFridge), timeRange: CMTimeRange(start: p1Start, duration: p1Dur)))
        overlays.append(splitWipeMaskOverlay(start: p1Start, dur: p1Dur))
        
        // 3–7s ingredient counters
        let p2Start = p1Start + p1Dur
        let p2Dur = CMTime(seconds: 4.0, preferredTimescale: 600)
        items.append(.init(kind: .still(media.cookedMeal), timeRange: CMTimeRange(start: p2Start, duration: p2Dur),
                           transform: CGAffineTransform(scaleX: 1.03, y: 1.03)))
        overlays.append(ingredientCountersOverlay(recipe: recipe, start: p2Start, dur: p2Dur))
        
        // 7–9s endcard
        let endStart = p2Start + p2Dur
        let endDur = CMTime(seconds: 2.0, preferredTimescale: 600)
        items.append(.init(kind: .still(media.afterFridge), timeRange: CMTimeRange(start: endStart, duration: endDur)))
        overlays.append(ctaOverlay(text: "Save for grocery day 🛒", start: endStart, dur: endDur))
        
        return RenderPlan(items: items, overlays: overlays, audio: media.musicURL, outputDuration: total)
    }
}
```

## Template 3: Kinetic-Text "Recipe in 5 Steps" (Auto-Captioned)

```swift
private extension Planner {
    func planKinetic(_ recipe: Recipe, _ media: MediaBundle, _ cfg: RenderConfig) throws -> RenderPlan {
        guard !recipe.steps.isEmpty else { throw PlanError.badSteps }
        let total = CMTime(seconds: 15, preferredTimescale: 600)
        var items: [RenderPlan.TrackItem] = []
        var overlays: [RenderPlan.Overlay] = []
        
        // background: looping gentle motion between BEFORE → BROLL → AFTER if available
        let stepDur = CMTime(seconds: max(1.6, 12.0 / Double(max(1, min(recipe.steps.count, 6)))) , preferredTimescale: 600)
        var cursor = CMTime.zero
        
        // hook 0–2s on BEFORE
        let hookDur = CMTime(seconds: 2, preferredTimescale: 600)
        items.append(.init(kind: .still(media.beforeFridge),
                           timeRange: CMTimeRange(start: .zero, duration: hookDur),
                           transform: CGAffineTransform(scaleX: 1.02, y: 1.02)))
        overlays.append(heroHookOverlay(text: recipe.hook ?? "What I made with this fridge ↓", start: .zero, dur: hookDur))
        cursor = hookDur
        
        // steps
        for (i, step) in recipe.steps.prefix(6).enumerated() {
            let t = CMTimeRange(start: cursor, duration: stepDur)
            let bg: RenderPlan.TrackItem = if let clip = media.brollClips.first {
                .init(kind: .video(clip), timeRange: t)
            } else {
                .init(kind: .still(media.cookedMeal), timeRange: t, transform: CGAffineTransform(scaleX: 1.03, y: 1.03))
            }
            items.append(bg)
            overlays.append(kineticStepOverlay(index: i+1, text: step.title, start: cursor, dur: stepDur))
            cursor = cursor + stepDur
        }
        
        // end on AFTER + plate
        let tail = total - cursor
        if tail.seconds > 0.5 {
            items.append(.init(kind: .still(media.afterFridge),
                               timeRange: CMTimeRange(start: cursor, duration: tail)))
            overlays.append(ctaOverlay(text: "Comment "RECIPE" for details", start: cursor, dur: tail))
        }
        return RenderPlan(items: items, overlays: overlays, audio: media.musicURL, outputDuration: total)
    }
}
```

## Template 4: "Price & Time Challenge" Sticker Pack

```swift
private extension Planner {
    func planPriceTime(_ recipe: Recipe, _ media: MediaBundle, _ cfg: RenderConfig) throws -> RenderPlan {
        let total = CMTime(seconds: 12, preferredTimescale: 600)
        var items: [RenderPlan.TrackItem] = []
        var overlays: [RenderPlan.Overlay] = []
        
        // 0–1s BEFORE
        let p0 = CMTime(seconds: 1, preferredTimescale: 600)
        items.append(.init(kind: .still(media.beforeFridge), timeRange: CMTimeRange(start: .zero, duration: p0)))
        overlays.append(stickerStackOverlay(recipe: recipe, start: .zero, dur: p0 + CMTime(seconds: 2, preferredTimescale: 600)))
        
        // 1–9s progress bar with b-roll or still
        let p1Start = p0
        let p1Dur = CMTime(seconds: 8, preferredTimescale: 600)
        if let clip = media.brollClips.first {
            items.append(.init(kind: .video(clip), timeRange: CMTimeRange(start: p1Start, duration: p1Dur)))
        } else {
            items.append(.init(kind: .still(media.cookedMeal),
                               timeRange: CMTimeRange(start: p1Start, duration: p1Dur),
                               transform: CGAffineTransform(scaleX: 1.02, y: 1.02)))
        }
        overlays.append(progressOverlay(start: p1Start, dur: p1Dur))
        
        // 9–12s AFTER + CTA
        let endStart = p1Start + p1Dur
        let endDur = CMTime(seconds: 3, preferredTimescale: 600)
        items.append(.init(kind: .still(media.afterFridge), timeRange: CMTimeRange(start: endStart, duration: endDur)))
        overlays.append(ctaOverlay(text: "Save & try this tonight ✨", start: endStart, dur: endDur))
        
        return RenderPlan(items: items, overlays: overlays, audio: media.musicURL, outputDuration: total)
    }
}
```

## Template 5: Green-Screen "My Fridge → My Plate" (PIP Face + B-Roll)

```swift
private extension Planner {
    func planGreenScreen(_ recipe: Recipe, _ media: MediaBundle, _ cfg: RenderConfig) throws -> RenderPlan {
        let total = CMTime(seconds: 15, preferredTimescale: 600)
        var items: [RenderPlan.TrackItem] = []
        var overlays: [RenderPlan.Overlay] = []
        
        // base: BEFORE → BROLL → AFTER
        let p0 = CMTime(seconds: 3, preferredTimescale: 600)
        items.append(.init(kind: .still(media.beforeFridge), timeRange: CMTimeRange(start: .zero, duration: p0)))
        overlays.append(pipFaceOverlay(start: .zero, dur: p0)) // placeholder PIP (face) slot
        
        let p1Start = p0
        let p1Dur = CMTime(seconds: 6, preferredTimescale: 600)
        if let clip = media.brollClips.first {
            items.append(.init(kind: .video(clip), timeRange: CMTimeRange(start: p1Start, duration: p1Dur)))
        } else {
            items.append(.init(kind: .still(media.cookedMeal), timeRange: CMTimeRange(start: p1Start, duration: p1Dur)))
        }
        
        // dynamic callouts for salvaged items
        overlays.append(calloutsOverlay(strings: Array(recipe.ingredients.prefix(3)).map { $0.capitalized },
                                        start: p1Start, dur: p1Dur))
        
        let endStart = p1Start + p1Dur
        let endDur = CMTime(seconds: 6, preferredTimescale: 600)
        items.append(.init(kind: .still(media.afterFridge), timeRange: CMTimeRange(start: endStart, duration: endDur)))
        overlays.append(ctaOverlay(text: "From fridge → plate 😎", start: endStart, dur: endDur))
        
        return RenderPlan(items: items, overlays: overlays, audio: media.musicURL, outputDuration: total)
    }
}
```

## Overlay + Animation Factories (Styled, Safe-Zone Aware)

```swift
final class OverlayFactory {
    static func textLayer(_ string: String, fontName: String, size: CGFloat, color: UIColor,
                          stroke: Bool, shadow: UIColor, maxWidth: CGFloat) -> CATextLayer {
        let l = CATextLayer()
        l.contentsScale = UIScreen.main.scale
        l.alignmentMode = .center
        let fName = UIFont(name: fontName, size: size)?.fontName ?? UIFont.boldSystemFont(ofSize: size).fontName
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: fName, size: size) as Any,
            .foregroundColor: color
        ]
        let s = NSAttributedString(string: string, attributes: attr)
        l.string = s
        // size to fit
        let framesetter = CTFramesetterCreateWithAttributedString(s)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: s.length),
                                                                     nil, CGSize(width: maxWidth, height: .greatestFiniteMagnitude), nil)
        l.bounds = CGRect(x: 0, y: 0, width: ceil(suggested.width), height: ceil(suggested.height))
        if stroke {
            // simple fake stroke by shadow
            l.shadowColor = shadow.cgColor
            l.shadowRadius = 4
            l.shadowOpacity = 1
            l.shadowOffset = .zero
        }
        return l
    }
    
    static func roundedSticker(text: String, fontName: String, size: CGFloat, bg: UIColor, fg: UIColor, padding: UIEdgeInsets) -> CALayer {
        let container = CALayer()
        let textLayer = textLayer(text, fontName: fontName, size: size, color: fg, stroke: false, shadow: .clear, maxWidth: 800)
        textLayer.position = .zero
        let w = textLayer.bounds.width + padding.left + padding.right
        let h = textLayer.bounds.height + padding.top + padding.bottom
        let pill = CAShapeLayer()
        pill.path = UIBezierPath(roundedRect: CGRect(x: -w/2, y: -h/2, width: w, height: h), cornerRadius: h/2).cgPath
        pill.fillColor = bg.cgColor
        container.addSublayer(pill)
        textLayer.position = .zero
        container.addSublayer(textLayer)
        container.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        container.shadowOpacity = 0.25
        container.shadowRadius = 8
        container.shadowOffset = .zero
        return container
    }
}

// MARK: Overlay Builders (Planner uses these closures)

extension Planner {
    func heroHookOverlay(text: String, start: CMTime, dur: CMTime) -> RenderPlan.Overlay {
        .init(start: start, duration: dur) { cfg in
            let l = OverlayFactory.textLayer(text, fontName: cfg.fontNameBold, size: 64, color: .white,
                                             stroke: cfg.textStrokeEnabled, shadow: .black,
                                             maxWidth: cfg.size.width - (cfg.safeInsets.left + cfg.safeInsets.right))
            l.position = CGPoint(x: cfg.size.width/2, y: cfg.size.height - cfg.safeInsets.top - l.bounds.height/2 - 24)
            l.opacity = 0
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0; fade.toValue = 1; fade.beginTime = 0; fade.duration = 0.3; fade.fillMode = .forwards; fade.isRemovedOnCompletion = false
            l.add(fade, forKey: "fadeIn")
            return l
        }
    }
    
    func ctaOverlay(text: String, start: CMTime, dur: CMTime) -> RenderPlan.Overlay {
        .init(start: start, duration: dur) { cfg in
            let sticker = OverlayFactory.roundedSticker(text: text, fontName: cfg.fontNameBold, size: 40,
                                                        bg: UIColor(white: 0, alpha: 0.5), fg: .white,
                                                        padding: UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20))
            sticker.position = CGPoint(x: cfg.size.width/2, y: cfg.safeInsets.bottom + sticker.bounds.height/2 + 24)
            sticker.opacity = 0
            let pop = CASpringAnimation(keyPath: "transform.scale")
            pop.fromValue = 0.6; pop.toValue = 1.0; pop.damping = 12; pop.initialVelocity = 0.8; pop.duration = 0.6
            let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = 0; fade.toValue = 1; fade.duration = 0.2
            let grp = CAAnimationGroup(); grp.animations = [pop, fade]; grp.duration = 0.6
            sticker.add(grp, forKey: "pop")
            return sticker
        }
    }
    
    func ingredientCallout(text: String, start: CMTime, dur: CMTime) -> RenderPlan.Overlay {
        .init(start: start, duration: dur) { cfg in
            let sticker = OverlayFactory.roundedSticker(text: text, fontName: cfg.fontNameBold, size: 42,
                                                        bg: UIColor.systemYellow, fg: .black,
                                                        padding: UIEdgeInsets(top: 12, left: 18, bottom: 12, right: 18))
            sticker.position = CGPoint(x: cfg.size.width * 0.25, y: cfg.size.height * 0.75)
            let drop = CASpringAnimation(keyPath: "position.y")
            drop.fromValue = sticker.position.y + 50; drop.toValue = sticker.position.y; drop.damping = 14; drop.duration = 0.5
            sticker.add(drop, forKey: "drop")
            return sticker
        }
    }
    
    // Additional overlay functions continue...
}
```

## Renderer (AVFoundation + Core Animation)

```swift
final class Renderer {
    private let overlayFactory = OverlayFactory()
    
    func render(plan: RenderPlan, config: RenderConfig, completion: @escaping (Result<URL, Error>) -> Void) {
        // 1) Composition
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        // Insert items
        for item in plan.items {
            let asset: AVAsset
            let track: AVAssetTrack
            switch item.kind {
            case .still(let image):
                // turn still into a timed video segment
                guard let url = StillWriter.write(image: image, duration: item.timeRange.duration, size: config.size, fps: config.fps) else { continue }
                asset = AVAsset(url: url)
            case .video(let url):
                asset = AVAsset(url: url)
            }
            guard let srcTrack = asset.tracks(withMediaType: .video).first else { continue }
            try? videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: item.timeRange.duration),
                                            of: srcTrack, at: item.timeRange.start)
        }
        
        // background audio
        if let audioURL = plan.audio {
            let a = AVAsset(url: audioURL)
            if let atrack = a.tracks(withMediaType: .audio).first {
                try? audioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: min(a.duration, plan.outputDuration)),
                                                 of: atrack, at: .zero)
            }
        }
        
        // 2) VideoComposition & CoreAnimationTool
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = config.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: config.fps)
        
        // Basic pass-through instruction
        let instr = AVMutableVideoCompositionInstruction()
        instr.timeRange = CMTimeRange(start: .zero, duration: plan.outputDuration)
        let layerInstr = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        instr.layerInstructions = [layerInstr]
        videoComposition.instructions = [instr]
        
        // 3) Animation layer tree
        let parent = CALayer(); parent.frame = CGRect(origin: .zero, size: config.size)
        let videoLayer = CALayer(); videoLayer.frame = parent.frame
        let overlayLayer = CALayer(); overlayLayer.frame = parent.frame
        
        // add overlays
        for ov in plan.overlays {
            let l = ov.layerBuilder(config)
            overlayLayer.addSublayer(l)
        }
        parent.addSublayer(videoLayer)
        parent.addSublayer(overlayLayer)
        
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
        
        // 4) Export
        let outURL = FileManager.default.temporaryDirectory.appendingPathComponent("fridge_\(UUID().uuidString).mp4")
        if FileManager.default.fileExists(atPath: outURL.path) { try? FileManager.default.removeItem(at: outURL) }
        
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(NSError(domain: "Exporter", code: -1)))
            return
        }
        exporter.videoComposition = videoComposition
        exporter.outputURL = outURL
        exporter.outputFileType = .mp4
        exporter.exportAsynchronously {
            if exporter.status == .completed { completion(.success(outURL)) }
            else { completion(.failure(exporter.error ?? NSError(domain: "ExportFailed", code: -2))) }
        }
    }
}
```

## Still → Video Helper

```swift
enum StillWriter {
    static func write(image: UIImage, duration: CMTime, size: CGSize, fps: Int32) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("still_\(UUID().uuidString).mp4")
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width, AVVideoHeightKey: size.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        let frameCount = Int(duration.seconds * Double(fps))
        let frameDuration = CMTime(value: 1, timescale: fps)
        let ci = CIImage(image: image) ?? CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
        let ctx = CIContext()
        
        for i in 0..<frameCount {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
            var pixelBuffer: CVPixelBuffer?
            let attrs = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
            CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
            guard let pb = pixelBuffer else { continue }
            CVPixelBufferLockBaseAddress(pb, [])
            ctx.render(ci, to: pb)
            adaptor.append(pb, withPresentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(i)))
            CVPixelBufferUnlockBaseAddress(pb, [])
        }
        input.markAsFinished()
        writer.finishWriting {
            // no-op
        }
        while writer.status == .writing { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
        return writer.status == .completed ? url : nil
    }
}
```

## ShareService (Save to Photos → TikTok Share)

```swift
import Photos
import TikTokOpenShareSDK

enum ShareError: Error {
    case photoAccessDenied
    case saveFailed
    case fetchFailed
    case tiktokNotInstalled
    case shareFailed(String)
}

enum ShareService {
    static func requestPhotoPermission(_ completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            completion(status == .authorized || status == .limited)
        }
    }

    /// Saves the exported video to Photos and returns its PHAsset.localIdentifier
    static func saveToPhotos(videoURL: URL, completion: @escaping (Result<String, ShareError>) -> Void) {
        // Ensure permissions
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(.photoAccessDenied))
                return
            }
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                placeholder = req?.placeholderForCreatedAsset
            }) { success, error in
                if success, let id = placeholder?.localIdentifier {
                    completion(.success(id))
                } else {
                    completion(.failure(.saveFailed))
                }
            }
        }
    }

    /// Sends to TikTok via OpenShareSDK (video)
    static func shareToTikTok(localIdentifiers: [String],
                               caption: String? = nil,
                               completion: @escaping (Result<Void, ShareError>) -> Void) {
        // Optional: ensure TikTok app exists (SDK often checks via URL schemes)
        guard UIApplication.shared.canOpenURL(URL(string: "snssdk1180://")!) ||
              UIApplication.shared.canOpenURL(URL(string: "snssdk1233://")!) else {
            completion(.failure(.tiktokNotInstalled))
            return
        }

        let request = TikTokShareRequest(localIdentifiers: localIdentifiers,
                                         mediaType: .video,
                                         redirectURI: "https://example.dev/share")
        // Caption: There isn't a separate caption field in request; pass text via pasteboard or guide users.
        if let caption = caption {
            UIPasteboard.general.string = caption // user can paste in TikTok compose
        }

        request.send { resp in
            guard let r = resp as? TikTokShareResponse else {
                completion(.failure(.shareFailed("No response"))) ; return
            }
            if r.errorCode == .noError {
                completion(.success(()))
            } else {
                let msg = r.errorMessage ?? "Unknown error (\(r.errorCode.rawValue))"
                completion(.failure(.shareFailed(msg)))
            }
        }
    }
}
```

## End-to-End: Render → Photos → TikTok

```swift
func shareRecipeToTikTok(template: ViralTemplate, recipe: Recipe, media: MediaBundle) {
    let engine = ViralVideoEngine()
    engine.render(template: template, recipe: recipe, media: media) { result in
        switch result {
        case .failure(let e):
            print("Render failed:", e)
        case .success(let url):
            ShareService.saveToPhotos(videoURL: url) { saveResult in
                switch saveResult {
                case .failure(let err):
                    print("Save failed:", err)
                case .success(let localId):
                    // Compose a default viral caption from the recipe
                    let caption = defaultCaption(from: recipe)
                    ShareService.shareToTikTok(localIdentifiers: [localId], caption: caption) { shareResult in
                        switch shareResult {
                        case .success:
                            print("Shared to TikTok successfully.")
                        case .failure(let err):
                            print("TikTok share failed:", err)
                        }
                    }
                }
            }
        }
    }
}

private func defaultCaption(from recipe: Recipe) -> String {
    let title = recipe.title
    let mins = recipe.timeMinutes.map { "\($0) min" } ?? "quick"
    let cost = recipe.costDollars.map { "$\($0)" } ?? ""
    let tags = ["#FridgeGlowUp", "#BeforeAfter", "#DinnerHack", "#HomeCooking"].joined(separator: " ")
    return "\(title) — \(mins) \(cost)\nComment "RECIPE" for details 👇\n\(tags)"
}
```

## Production Polish Checklist

- **Duration discipline**: keep 7–12 s for 1,2,4; 10–15 s for 3,5. Trim dead air.
- **Safe zone**: never place text in top/bottom 10–12% (status/caption UI land).
- **Type scale**: Hooks 60–72 pt; steps 44–52 pt; counters 36–48 pt.
- **Motion**: 200–300 ms ease, avoid more than 2 concurrent anims.
- **Color pop**: mild CIColorControls (contrast +0.1, saturation +0.08) on AFTER only.
- **Compression**: H.264 high profile, 8–12 Mbps target, AAC 128–192 kbps.

## TikTok OpenSDK Integration

### Info.plist Keys (Dev Client Key)

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tiktokopensdk</string>
    <string>tiktoksharesdk</string>
    <string>snssdk1180</string>
    <string>snssdk1233</string>
</array>
<key>TikTokClientKey</key>
<string>YOUR_DEV_CLIENT_KEY</string>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>YOUR_DEV_CLIENT_KEY</string>
    </array>
  </dict>
</array>
```

### URL Handling (AppDelegate + SceneDelegate)

```swift
import TikTokOpenSDKCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if TikTokURLHandler.handleOpenURL(url) { return true }
        return false
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           TikTokURLHandler.handleOpenURL(userActivity.webpageURL) {
            return true
        }
        return false
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url, TikTokURLHandler.handleOpenURL(url) { return }
    }
}
```

## Implementation Instructions

### Goal
Integrate the scaffold so any recipe + media bundle produces a viral-ready 1080×1920 MP4, saved to Photos, then shared through TikTok OpenSDK (sandbox creds), with dynamic text pulled from Recipe.

### Project Setup

1. **Targets & frameworks**
   - iOS 15+ recommended (min 12 supported by SDK)
   - Add AVFoundation, CoreGraphics, CoreText, CoreImage, Photos
   - Install TikTok OpenSDK via SPM

2. **Info.plist**
   - Add LSApplicationQueriesSchemes entries
   - Add TikTokClientKey
   - Add CFBundleURLTypes
   - Add NSPhotoLibraryAddUsageDescription

3. **AppDelegate / SceneDelegate**
   - Add URL handlers to forward TikTok callbacks

### Rendering Pipeline

1. Place ViralVideoEngine, Planner, RenderPlan, Renderer, StillWriter, and OverlayFactory into VideoEngine/ group
2. Confirm output: 1080×1920, 30 fps, H.264 .mp4
3. Dynamic text mapping from Recipe model

### Template Specifics

- **Beat-Synced Carousel**: Hook on blurred BEFORE; snaps include cooked meal + AFTER
- **Split Swipe**: Masked reveal stands out
- **Kinetic Steps**: Steps overlay at bottom safe zone
- **Price & Time**: Sticker stack for cost/time/calories; progress bar
- **Green Screen PIP**: Circular face PIP placeholder layer

### Performance & Stability

- Use temporary directory for intermediate files
- Delete files after share completes
- Reuse CIContext and CVPixelBuffer pools
- Vector-draw with CAShapeLayer where possible

### Test Plan

- Devices: iPhone 11, 12/13/14/15, SE (2nd gen)
- OS: iOS 15, 16, 17, 18
- Test all 5 templates with various content
- Verify Photos permission flow
- Confirm TikTok share completion

## Renderer Pro (Advanced Features)

For advanced rendering with per-clip transforms, CIFilters, and selfie PIP compositing, see the RendererPro implementation in the full specification document.