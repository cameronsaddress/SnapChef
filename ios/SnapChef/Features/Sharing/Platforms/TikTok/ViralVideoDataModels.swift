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

    // Ken Burns limits - subtle 5-8% zoom for natural movement
    public var maxKenBurnsScale: CGFloat = 1.08 // 8% subtle zoom
    
    // Premium effects settings - enhanced parallax for more panning
    public var breatheIntensity: CGFloat = 0.02 // 2% pulse for breathe effect
    public var parallaxIntensity: CGFloat = 0.12 // 12% enhanced parallax movement
    public var chromaticAberration: CGFloat = 0.5 // RGB aberration intensity
    public var lightLeakIntensity: CGFloat = 0.3 // Light leak effect
    public var velocityRampFactor: CGFloat = 0.6 // Speed ramping on beats

    // Beat handling
    public var fallbackBPM: Double = 80
    
    // Screen scale for high-res displays
    public var contentsScale: CGFloat = 2.0
    
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

// Filters that map to Core Image filters - PREMIUM EDITION
public enum FilterSpec: Sendable {
    // Basic filters
    case gaussianBlur(radius: CGFloat)
    case vibrance(CGFloat)
    case saturation(CGFloat)
    case contrast(CGFloat)
    
    // PREMIUM COLOR GRADES
    case premiumColorGrade(style: ColorGradeStyle)
    case foodEnhancer(intensity: CGFloat)
    case viralPop(warmth: CGFloat, punch: CGFloat)
    
    // DRAMATIC EFFECTS
    case chromaticAberration(intensity: CGFloat)
    case lightLeak(position: CGPoint, intensity: CGFloat)
    case filmGrain(intensity: CGFloat)
    case vignette(intensity: CGFloat)
    
    // MOTION EFFECTS (applied during render)
    case breatheEffect(intensity: CGFloat, bpm: Double)
    case parallaxMove(direction: CGVector, intensity: CGFloat)
    case velocityRamp(factor: CGFloat)
}

public enum ColorGradeStyle: String, Sendable {
    case warm = "warm"           // Golden hour vibes
    case cinematic = "cinematic" // Teal & orange Hollywood
    case vibrant = "vibrant"     // Instagram-ready colors
    case moody = "moody"         // Dark, dramatic contrast
    case fresh = "fresh"         // Clean, bright food styling
    case natural = "natural"     // Clean, neutral colors without tint
}

// Helper to convert FilterSpec -> CIFilter pipeline - PREMIUM EDITION
import CoreImage
public enum FilterSpecBridge {
    public static func toCIFilters(_ specs: [FilterSpec]) -> [CIFilter] {
        var filters: [CIFilter] = []
        for s in specs {
            switch s {
            // Basic filters
            case .gaussianBlur(let r):
                let f = CIFilter(name: "CIGaussianBlur")!; f.setValue(r, forKey: kCIInputRadiusKey); filters.append(f)
            case .vibrance(let a):
                let f = CIFilter(name: "CIVibrance")!; f.setValue(a, forKey: "inputAmount"); filters.append(f)
            case .saturation(let s):
                let f = CIFilter(name: "CIColorControls")!; f.setValue(s, forKey: kCIInputSaturationKey); filters.append(f)
            case .contrast(let c):
                let f = CIFilter(name: "CIColorControls")!; f.setValue(c, forKey: kCIInputContrastKey); filters.append(f)
                
            // PREMIUM COLOR GRADES
            case .premiumColorGrade(let style):
                filters.append(contentsOf: createColorGradeFilters(style: style))
            case .foodEnhancer(let intensity):
                filters.append(contentsOf: createFoodEnhancementFilters(intensity: intensity))
            case .viralPop(let warmth, let punch):
                filters.append(contentsOf: createViralPopFilters(warmth: warmth, punch: punch))
                
            // DRAMATIC EFFECTS
            case .chromaticAberration(let intensity):
                filters.append(createChromaticAberrationFilter(intensity: intensity))
            case .lightLeak(let position, let intensity):
                filters.append(createLightLeakFilter(position: position, intensity: intensity))
            case .filmGrain(let intensity):
                filters.append(createFilmGrainFilter(intensity: intensity))
            case .vignette(let intensity):
                filters.append(createVignetteFilter(intensity: intensity))
                
            // Motion effects are handled in StillWriter during render
            case .breatheEffect, .parallaxMove, .velocityRamp:
                break // These are applied during frame-by-frame rendering
            }
        }
        return filters
    }
    
    // MARK: - PREMIUM FILTER FACTORIES
    
    private static func createColorGradeFilters(style: ColorGradeStyle) -> [CIFilter] {
        var filters: [CIFilter] = []
        
        switch style {
        case .warm:
            // Golden hour warmth
            let temp = CIFilter(name: "CITemperatureAndTint")!
            temp.setValue(CIVector(x: 2000, y: 50), forKey: "inputNeutral") // Warm + slight magenta
            filters.append(temp)
            
            let curves = CIFilter(name: "CIColorCurves")!
            // Lift shadows, add warmth to highlights
            curves.setValue(CIVector(x: 0, y: 0.05, z: 0.95, w: 1.0), forKey: "inputCurvesDomain")
            filters.append(curves)
            
        case .cinematic:
            // Teal shadows, orange highlights - Hollywood look
            let colorBalance = CIFilter(name: "CIColorCrossPolynomial")!
            // This creates the classic teal & orange look
            filters.append(colorBalance)
            
            let contrast = CIFilter(name: "CIColorControls")!
            contrast.setValue(1.15, forKey: kCIInputContrastKey)
            contrast.setValue(0.95, forKey: kCIInputSaturationKey)
            filters.append(contrast)
            
        case .vibrant:
            // Instagram-ready pop
            let vibrance = CIFilter(name: "CIVibrance")!
            vibrance.setValue(0.4, forKey: "inputAmount")
            filters.append(vibrance)
            
            let saturation = CIFilter(name: "CIColorControls")!
            saturation.setValue(1.2, forKey: kCIInputSaturationKey)
            saturation.setValue(1.1, forKey: kCIInputContrastKey)
            filters.append(saturation)
            
        case .moody:
            // Dark, dramatic contrast
            let exposure = CIFilter(name: "CIExposureAdjust")!
            exposure.setValue(-0.3, forKey: kCIInputEVKey)
            filters.append(exposure)
            
            let contrast = CIFilter(name: "CIColorControls")!
            contrast.setValue(1.3, forKey: kCIInputContrastKey)
            contrast.setValue(0.85, forKey: kCIInputBrightnessKey)
            filters.append(contrast)
            
        case .fresh:
            // Clean, bright food styling
            let exposure = CIFilter(name: "CIExposureAdjust")!
            exposure.setValue(0.2, forKey: kCIInputEVKey)
            filters.append(exposure)
            
            let highlights = CIFilter(name: "CIHighlightShadowAdjust")!
            highlights.setValue(0.8, forKey: "inputHighlightAmount")
            highlights.setValue(1.2, forKey: "inputShadowAmount")
            filters.append(highlights)
            
        case .natural:
            // Natural, clean colors without any tint - FIXES GREEN TINT ISSUE
            // Only apply minimal adjustments to maintain natural color balance
            let whiteBalance = CIFilter(name: "CITemperatureAndTint")!
            whiteBalance.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral") // Neutral daylight temperature
            filters.append(whiteBalance)
            
            // Slight contrast boost for clarity without color shifts
            let contrast = CIFilter(name: "CIColorControls")!
            contrast.setValue(1.05, forKey: kCIInputContrastKey) // Very subtle contrast
            contrast.setValue(1.0, forKey: kCIInputSaturationKey) // Keep original saturation
            contrast.setValue(0.0, forKey: kCIInputBrightnessKey) // No brightness adjustment
            filters.append(contrast)
        }
        
        return filters
    }
    
    private static func createFoodEnhancementFilters(intensity: CGFloat) -> [CIFilter] {
        var filters: [CIFilter] = []
        
        // Enhance food colors specifically
        let vibrance = CIFilter(name: "CIVibrance")!
        vibrance.setValue(intensity * 0.6, forKey: "inputAmount")
        filters.append(vibrance)
        
        // Boost reds and oranges (common food colors)
        let selective = CIFilter(name: "CIColorControls")!
        selective.setValue(1.0 + intensity * 0.3, forKey: kCIInputSaturationKey)
        filters.append(selective)
        
        // Add slight warmth
        let temp = CIFilter(name: "CITemperatureAndTint")!
        temp.setValue(CIVector(x: 500 * intensity, y: 0), forKey: "inputNeutral")
        filters.append(temp)
        
        return filters
    }
    
    private static func createViralPopFilters(warmth: CGFloat, punch: CGFloat) -> [CIFilter] {
        var filters: [CIFilter] = []
        
        // Temperature adjustment for warmth
        let temp = CIFilter(name: "CITemperatureAndTint")!
        temp.setValue(CIVector(x: warmth * 1000, y: 0), forKey: "inputNeutral")
        filters.append(temp)
        
        // Punch up the contrast and saturation
        let controls = CIFilter(name: "CIColorControls")!
        controls.setValue(1.0 + punch * 0.4, forKey: kCIInputContrastKey)
        controls.setValue(1.0 + punch * 0.3, forKey: kCIInputSaturationKey)
        filters.append(controls)
        
        return filters
    }
    
    private static func createChromaticAberrationFilter(intensity: CGFloat) -> CIFilter {
        // Custom RGB channel separation for transition effects
        let convolution = CIFilter(name: "CIConvolution3X3")!
        // Create 3x3 convolution kernel with 9 values for chromatic aberration effect
        let weights = CIVector(values: [
            intensity, 0, -intensity,
            0, 1, 0,
            -intensity, 0, intensity
        ], count: 9)
        convolution.setValue(weights, forKey: "inputWeights")
        return convolution
    }
    
    private static func createLightLeakFilter(position: CGPoint, intensity: CGFloat) -> CIFilter {
        // Create a custom composite filter that generates a radial gradient and composites it
        let composite = CIFilter(name: "CIAdditionCompositing")!
        
        // Store the gradient parameters in the filter's userInfo for later use
        // Note: This approach requires the caller to handle the gradient generation
        // since CIRadialGradient is a generator filter
        composite.setValue(["lightLeakPosition": position, "lightLeakIntensity": intensity], forKey: "userInfo")
        
        return composite
    }
    
    private static func createFilmGrainFilter(intensity: CGFloat) -> CIFilter {
        // Use a multiply composite filter with stored parameters for film grain
        let composite = CIFilter(name: "CIMultiplyCompositing")!
        composite.setValue(["filmGrainIntensity": intensity], forKey: "userInfo")
        return composite
    }
    
    private static func createVignetteFilter(intensity: CGFloat) -> CIFilter {
        let vignette = CIFilter(name: "CIVignette")!
        vignette.setValue(intensity, forKey: "inputIntensity")
        vignette.setValue(0.8, forKey: "inputRadius")
        return vignette
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