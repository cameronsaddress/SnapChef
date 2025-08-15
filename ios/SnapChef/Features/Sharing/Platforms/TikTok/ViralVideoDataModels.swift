// REPLACE ENTIRE FILE: ViralVideoDataModels.swift

import UIKit
import AVFoundation
import CoreMedia

public struct ViralRecipe: Codable, Sendable {
    public struct Step: Codable, Sendable {
        public let title: String
        public let secondsHint: Double?
        public init(_ title: String, secondsHint: Double? = nil) {
            self.title = title; self.secondsHint = secondsHint
        }
    }
    public let title: String
    public let hook: String?
    public let steps: [Step]
    public let timeMinutes: Int?
    public let costDollars: Int?
    public let calories: Int?
    public let ingredients: [String]
    public init(title: String, hook: String? = nil, steps: [Step],
                timeMinutes: Int? = nil, costDollars: Int? = nil,
                calories: Int? = nil, ingredients: [String]) {
        self.title = title; self.hook = hook; self.steps = steps
        self.timeMinutes = timeMinutes; self.costDollars = costDollars
        self.calories = calories; self.ingredients = ingredients
    }
}

public struct MediaBundle: Sendable {
    public let beforeFridge: UIImage
    public let afterFridge: UIImage
    public let cookedMeal: UIImage
    public let brollClips: [URL]
    public let musicURL: URL?
    public init(beforeFridge: UIImage, afterFridge: UIImage, cookedMeal: UIImage,
                brollClips: [URL] = [], musicURL: URL? = nil) {
        self.beforeFridge = beforeFridge
        self.afterFridge = afterFridge
        self.cookedMeal = cookedMeal
        self.brollClips = brollClips
        self.musicURL = musicURL
    }
}

// New: beat map produced from audio analysis
public struct BeatMap: Sendable {
    public let bpm: Double
    public let cueTimes: [CMTime]  // ascending
    public init(bpm: Double, cueTimes: [CMTime]) { self.bpm = bpm; self.cueTimes = cueTimes }
}

public enum ViralTemplate: String, Sendable {
    case kineticTextSteps   // our default "premium"
}

// Rendering + brand config
public struct RenderConfig: Sendable {
    public var size = CGSize(width: 1080, height: 1920)
    public var fps: Int32 = 30
    public var safeInsets = UIEdgeInsets(top: 180, left: 72, bottom: 220, right: 72)
    public var maxDuration = CMTime(seconds: 15, preferredTimescale: 600)
    public var brandTint = UIColor.white
    public var brandShadow = UIColor.black

    public var premiumMode = true
    public var hookFontSize: CGFloat = 64
    public var stepsFontSize: CGFloat = 52
    public var ctaFontSize: CGFloat = 40
    public var fadeDuration: TimeInterval = 0.25
    public var textStrokeEnabled = true

    // Ken Burns limits (fix your zoom complaint)
    public var maxKenBurnsScale: CGFloat = 1.05 // 5% only

    // Beat handling
    public var fallbackBPM: Double = 80
    
    public init() { /* uses the default property values above */ }
}

public enum RenderPhase: String, Sendable { case preparingAssets, planning, renderingFrames, compositing, addingOverlays, encoding, finalizing, complete }
public struct RenderProgress: Sendable {
    public var phase: RenderPhase
    public var progress: Double
    public var memoryUsage: UInt64?
    public init(phase: RenderPhase, progress: Double, memoryUsage: UInt64? = nil) {
        self.phase = phase; self.progress = progress; self.memoryUsage = memoryUsage
    }
}

// Export controls
public enum ExportSettings {
    public static let videoPreset = AVAssetExportPresetHighestQuality
    public static let maxMemoryUsage: UInt64 = 800 * 1024 * 1024
    public static let maxRenderTime: Double = 8.0
    public static let pixelFormat = kCVPixelFormatType_32BGRA
    public static let maxFileSize: Int64 = 50 * 1024 * 1024  // 50MB
    public static let targetFileSize: Int64 = 50 * 1024 * 1024  // 50MB
}

// MARK: - RenderPlan + specs shared across renderer/planner/overlays

public struct RenderPlan: Sendable {
    public struct TrackItem: Sendable {
        public enum Kind: Sendable { case still(UIImage), video(URL) }
        public let kind: Kind
        public let timeRange: CMTimeRange
        public let transform: TransformSpec
        public let filters: [FilterSpec]
        public init(kind: Kind, timeRange: CMTimeRange,
                    transform: TransformSpec = .identity,
                    filters: [FilterSpec] = []) {
            self.kind = kind; self.timeRange = timeRange
            self.transform = transform; self.filters = filters
        }
    }

    public struct Overlay: Sendable {
        public let start: CMTime
        public let duration: CMTime
        public let layerBuilder: @Sendable (RenderConfig) -> CALayer
        public init(start: CMTime, duration: CMTime,
                    layerBuilder: @escaping @Sendable (RenderConfig) -> CALayer) {
            self.start = start; self.duration = duration; self.layerBuilder = layerBuilder
        }
    }

    public let items: [TrackItem]
    public let overlays: [Overlay]
    public let audio: URL?
    public let outputDuration: CMTime

    public init(items: [TrackItem], overlays: [Overlay], audio: URL?, outputDuration: CMTime) {
        self.items = items; self.overlays = overlays; self.audio = audio; self.outputDuration = outputDuration
    }
}

// Video/image transforms applied per item (we only use .identity and .kenBurns right now)
public enum TransformSpec: Sendable {
    case identity
    case kenBurns(maxScale: CGFloat, seed: Int)
}

// Filters that map to Core Image filters (kept tiny on purpose)
public enum FilterSpec: Sendable {
    case gaussianBlur(radius: CGFloat)
    case vibrance(CGFloat)
    case saturation(CGFloat)
    case contrast(CGFloat)
}

// Helper to convert FilterSpec -> CIFilter pipeline
import CoreImage
public enum FilterSpecBridge {
    public static func toCIFilters(_ specs: [FilterSpec]) -> [CIFilter] {
        var filters: [CIFilter] = []
        for s in specs {
            switch s {
            case .gaussianBlur(let r):
                let f = CIFilter(name: "CIGaussianBlur")!; f.setValue(r, forKey: kCIInputRadiusKey); filters.append(f)
            case .vibrance(let a):
                let f = CIFilter(name: "CIVibrance")!; f.setValue(a, forKey: "inputAmount"); filters.append(f)
            case .saturation(let s):
                let f = CIFilter(name: "CIColorControls")!; f.setValue(s, forKey: kCIInputSaturationKey); filters.append(f)
            case .contrast(let c):
                let f = CIFilter(name: "CIColorControls")!; f.setValue(c, forKey: kCIInputContrastKey); filters.append(f)
            }
        }
        return filters
    }
}

// Temp file helper used by renderer/writer/overlays
public func createTempOutputURL(ext: String = "mp4") -> URL {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    return dir.appendingPathComponent("snapchef-\(UUID().uuidString).\(ext)")
}

// Error types for video generation
public enum ViralVideoError: Error {
    case exportFailed
    case renderFailed
    case assetLoadFailed
}