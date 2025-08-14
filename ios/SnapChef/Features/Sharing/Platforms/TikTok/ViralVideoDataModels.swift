//
//  ViralVideoDataModels.swift
//  SnapChef
//
//  Created on 12/01/2025
//  Core data models for TikTok viral video generation as specified in requirements
//

import UIKit
import AVFoundation
import CoreMedia

// MARK: - Recipe Data Model
/// Recipe data model exactly as specified in requirements
public struct ViralRecipe: Codable, Sendable {
    public struct Step: Codable, Sendable { 
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
    
    public init(
        title: String,
        hook: String? = nil,
        steps: [Step],
        timeMinutes: Int? = nil,
        costDollars: Int? = nil,
        calories: Int? = nil,
        ingredients: [String]
    ) {
        self.title = title
        self.hook = hook
        self.steps = steps
        self.timeMinutes = timeMinutes
        self.costDollars = costDollars
        self.calories = calories
        self.ingredients = ingredients
    }
}

// MARK: - Media Bundle
/// Media bundle containing all visual assets for video generation
public struct MediaBundle: Sendable {
    public let beforeFridge: UIImage
    public let afterFridge: UIImage
    public let cookedMeal: UIImage            // plated beauty
    public let brollClips: [URL]              // optional cooking clips (vertical)
    public let musicURL: URL?                 // optional; otherwise silent
    
    public init(
        beforeFridge: UIImage,
        afterFridge: UIImage,
        cookedMeal: UIImage,
        brollClips: [URL] = [],
        musicURL: URL? = nil
    ) {
        self.beforeFridge = beforeFridge
        self.afterFridge = afterFridge
        self.cookedMeal = cookedMeal
        self.brollClips = brollClips
        self.musicURL = musicURL
    }
}

// MARK: - Render Configuration
/// Configuration settings for video rendering with exact specifications
public struct RenderConfig: Sendable {
    public var size = CGSize(width: 1080, height: 1920)
    public var fps: Int32 = 30
    public var safeInsets = UIEdgeInsets(top: 192, left: 72, bottom: 192, right: 72)
    public var maxDuration: CMTime = CMTime(seconds: 15, preferredTimescale: 600)
    public var fontNameBold: String = "SF-Pro-Display-Bold"
    public var fontNameRegular: String = "SF-Pro-Display-Regular"
    public var textStrokeEnabled: Bool = true
    public var brandTint: UIColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)  // Golden for premium food vibe
    public var brandShadow: UIColor = .black
    
    // Premium mode toggle
    public var premiumMode: Bool = true  // Enable premium enhancements
    
    // Typography hierarchy - Enhanced for premium impact
    public var hookFontSize: CGFloat = 144       // DOUBLED: Increased for viral hook impact
    public var stepsFontSize: CGFloat = 104      // DOUBLED: Slightly larger for readability
    public var countersFontSize: CGFloat = 88    // DOUBLED: More prominent counters
    public var ctaFontSize: CGFloat = 84         // DOUBLED: Bigger CTA for engagement
    public var ingredientFontSize: CGFloat = 88  // DOUBLED: Enhanced ingredient text
    
    // Animation timing - More dynamic for premium
    public var fadeDuration: TimeInterval = 0.25      // 200-300ms
    public var springDamping: CGFloat = 13            // 12-14 for pop animations
    public var scaleRange: ClosedRange<CGFloat> = 0.8...1.2  // More dramatic pop effect
    public var staggerDelay: TimeInterval = 0.15     // 150ms between elements (Template 2 requirement)
    
    // Premium visual enhancements
    // Template-specific: For beatSyncedCarousel
    public var carouselSnapDelay: TimeInterval = 0.5  // Assumed beat interval (120 BPM)
    public var carouselSnapScale: CGFloat = 1.15      // Enhanced zoom for snap effect
    public var carouselGlowIntensity: Float = 1.2     // Stronger glow for premium reveals
    public var carouselParticleCount: Int = 30        // More particles for meal reveal
    public var beatBPM: Int = 120                     // Common TikTok BPM
    public var snapEasing: String = "cubic-bezier"    // Premium easing type
    public var carouselBounceScale: CGFloat = 1.08   // Bounce-back scale for snap
    public var particleSpread: Float = 100.0          // Particle spread radius
    
    public var vibranceAmount: Float = 1.2       // Vibrant colors
    public var contrastAmount: Float = 1.1       // Higher contrast
    public var saturationAmount: Float = 1.2     // Rich saturation
    public var sharpnessAmount: Float = 0.8      // Crisp edges
    public var glowRadius: Float = 5.0           // Glow effect for PIP
    
    // Premium text effects
    public var textShadowRadius: CGFloat = 4.0   // Shadow blur
    public var textShadowOffset: CGSize = CGSize(width: 0, height: 2)
    public var textGradientColors: [UIColor] = [
        UIColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0),  // Golden yellow
        UIColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 1.0)   // Orange gradient
    ]
    
    public init() {}
}

// MARK: - Viral Template Enum
/// Five viral video templates as specified in requirements
public enum ViralTemplate: String, CaseIterable, Sendable {
    // Commented out templates - focusing on kinetic text only
    // case beatSyncedCarousel = "Beat-Synced Photo Carousel"
    // case splitScreenSwipe = "Split-Screen Swipe Before/After"
    case kineticTextSteps = "Kinetic-Text Recipe Steps"
    // case priceTimeChallenge = "Price & Time Challenge"
    // case greenScreenPIP = "Green-Screen My Fridge → My Plate"
    // case test = "Test (Photos Only)"
    
    public var duration: CMTime {
        switch self {
        // case .beatSyncedCarousel:
        //     return CMTime(seconds: 11, preferredTimescale: 600)  // 10-12 seconds
        // case .splitScreenSwipe:
        //     return CMTime(seconds: 9, preferredTimescale: 600)   // 9 seconds
        case .kineticTextSteps:
            return CMTime(seconds: 15, preferredTimescale: 600)  // 15 seconds
        // case .priceTimeChallenge:
        //     return CMTime(seconds: 12, preferredTimescale: 600)  // 12 seconds
        // case .greenScreenPIP:
        //     return CMTime(seconds: 15, preferredTimescale: 600)  // 15 seconds
        // case .test:
        //     return CMTime(seconds: 2, preferredTimescale: 600)   // 2 seconds (1 sec per photo)
        }
    }
    
    public var description: String {
        switch self {
        // case .beatSyncedCarousel:
        //     return "Hook on blurred BEFORE → ingredient snaps → cooked meal → AFTER"
        // case .splitScreenSwipe:
        //     return "BEFORE full screen → AFTER masked reveal → ingredient counters → CTA"
        case .kineticTextSteps:
            return "Hook overlay → animated step text → background motion → auto-captioned"
        // case .priceTimeChallenge:
        //     return "BEFORE with stickers → progress bar → AFTER with CTA"
        // case .greenScreenPIP:
        //     return "Picture-in-picture face overlay → BEFORE → B-ROLL → AFTER"
        // case .test:
        //     return "Simple test: 1 second before photo, 1 second after photo, no effects"
        }
    }
}

// MARK: - Filter and PIP Specifications

/// Codable wrapper for heterogeneous values
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any
    
    public init(_ value: Any) { 
        self.value = value 
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { 
            value = int
        } else if let double = try? container.decode(Double.self) { 
            value = double
        } else if let bool = try? container.decode(Bool.self) { 
            value = bool
        } else if let string = try? container.decode(String.self) { 
            value = string
        } else {
            value = ""
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int: 
            try container.encode(int)
        case let double as Double: 
            try container.encode(double)
        case let bool as Bool: 
            try container.encode(bool)
        case let string as String: 
            try container.encode(string)
        default: 
            try container.encode(String(describing: value))
        }
    }
}

/// Filter specification for CI filters
public struct FilterSpec: Codable, Sendable {
    public let name: String
    public let params: [String: AnyCodable]
    
    public init(name: String, params: [String: AnyCodable] = [:]) {
        self.name = name
        self.params = params
    }
}

/// Picture-in-Picture specification
public struct PIPSpec: @unchecked Sendable {
    public let url: URL
    public let frame: CGRect
    public let cornerRadius: CGFloat
    public let timeRange: CMTimeRange
    
    public init(url: URL, frame: CGRect, cornerRadius: CGFloat, timeRange: CMTimeRange) {
        self.url = url
        self.frame = frame
        self.cornerRadius = cornerRadius
        self.timeRange = timeRange
    }
}

// MARK: - Render Plan Structure
/// Render plan structure exactly as specified in requirements
public struct RenderPlan: @unchecked Sendable {
    public struct TrackItem: @unchecked Sendable {
        public enum Kind: Sendable { 
            case still(UIImage)
            case video(URL) 
        }
        public let kind: Kind
        public let timeRange: CMTimeRange
        public let transform: CGAffineTransform
        public let filters: [FilterSpec]  // Changed to FilterSpec for Pro renderer
        
        public init(
            kind: Kind,
            timeRange: CMTimeRange,
            transform: CGAffineTransform = .identity,
            filters: [FilterSpec] = []
        ) {
            self.kind = kind
            self.timeRange = timeRange
            self.transform = transform
            self.filters = filters
        }
    }
    
    public struct Overlay: @unchecked Sendable {
        public let start: CMTime
        public let duration: CMTime
        public let layerBuilder: (_ config: RenderConfig) -> CALayer
        
        public init(
            start: CMTime,
            duration: CMTime,
            layerBuilder: @escaping (_ config: RenderConfig) -> CALayer
        ) {
            self.start = start
            self.duration = duration
            self.layerBuilder = layerBuilder
        }
    }
    
    public let items: [TrackItem]
    public let overlays: [Overlay]
    public let audio: URL?
    public let outputDuration: CMTime
    public let pip: PIPSpec?  // Optional PIP for green screen effect
    
    public init(
        items: [TrackItem],
        overlays: [Overlay],
        audio: URL? = nil,
        outputDuration: CMTime,
        pip: PIPSpec? = nil
    ) {
        self.items = items
        self.overlays = overlays
        self.audio = audio
        self.outputDuration = outputDuration
        self.pip = pip
    }
}

// MARK: - Render Progress
/// Progress tracking for video rendering
public struct RenderProgress: Sendable {
    public let phase: RenderPhase
    public let progress: Double  // 0.0 to 1.0
    public let currentFrame: Int?
    public let totalFrames: Int?
    public let memoryUsage: UInt64?  // bytes
    
    public init(
        phase: RenderPhase,
        progress: Double,
        currentFrame: Int? = nil,
        totalFrames: Int? = nil,
        memoryUsage: UInt64? = nil
    ) {
        self.phase = phase
        self.progress = progress
        self.currentFrame = currentFrame
        self.totalFrames = totalFrames
        self.memoryUsage = memoryUsage
    }
}

public enum RenderPhase: String, CaseIterable, Sendable {
    case planning = "Planning"
    case preparingAssets = "Preparing Assets"
    case renderingFrames = "Rendering Frames"
    case compositing = "Compositing"
    case addingOverlays = "Adding Overlays"
    case encoding = "Encoding"
    case finalizing = "Finalizing"
    case complete = "Complete"
}

// MARK: - Export Settings
/// Export settings for production quality as specified in requirements
public struct ExportSettings {
    // Video compression settings
    public static let videoCodec = AVVideoCodecType.h264
    public static let videoProfile = AVVideoProfileLevelH264HighAutoLevel
    public static let videoBitrate: Int = 8_000_000  // Optimized 8 Mbps for better compression
    public static let videoPreset = AVAssetExportPresetHighestQuality
    
    // Adaptive bitrate settings for file size optimization
    public static let adaptiveBitrateThresholds: [Int64: Int] = [
        20_000_000: 8_000_000,   // <20MB: 8 Mbps
        15_000_000: 6_000_000,   // <15MB: 6 Mbps
        10_000_000: 4_000_000    // <10MB: 4 Mbps
    ]
    
    // Audio compression settings
    public static let audioCodec = kAudioFormatMPEG4AAC
    public static let audioBitrate: Int = 128_000    // Optimized 128 kbps
    public static let audioSampleRate: Double = 44100.0
    
    // Frame writing settings
    // Use 32BGRA which is the most compatible format for H.264 encoding
    // kCVPixelFormatType_32BGRA = 1111970369 ('BGRA')
    public static let pixelFormat = kCVPixelFormatType_32BGRA
    public static let maxFileSize: Int64 = 50_000_000  // 50MB max
    public static let targetFileSize: Int64 = 20_000_000  // 20MB target
    
    // Performance requirements
    public static let maxMemoryUsage: UInt64 = 600_000_000  // 600MB (increased from 150MB to handle video rendering)
    public static let maxRenderTime: TimeInterval = 5.0     // 5 seconds
    
    // Compression optimization settings
    public static func optimizedVideoSettings(
        for size: CGSize,
        targetFileSize: Int64,
        duration: TimeInterval
    ) -> [String: Any] {
        let targetBitrate = calculateOptimalBitrate(
            targetFileSize: targetFileSize,
            duration: duration
        )
        
        return [
            AVVideoCodecKey: videoCodec,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: targetBitrate,
                AVVideoProfileLevelKey: videoProfile,
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoMaxKeyFrameIntervalKey: 30
                // Removed AVVideoH264EntropyModeKey - can cause compatibility issues
                // Removed AVVideoAllowFrameReorderingKey - can cause "Operation Stopped" errors
                // Removed AVVideoQualityKey - not valid for H.264 codec
            ]
        ]
    }
    
    public static func optimizedAudioSettings() -> [String: Any] {
        return [
            AVFormatIDKey: audioCodec,
            AVSampleRateKey: audioSampleRate,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: audioBitrate,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }
    
    private static func calculateOptimalBitrate(targetFileSize: Int64, duration: TimeInterval) -> Int {
        // Calculate bitrate needed to achieve target file size
        // File size (bytes) = (video bitrate + audio bitrate) * duration / 8
        let targetBitsPerSecond = (Double(targetFileSize * 8) / duration) * 0.9 // 90% for video, 10% for audio
        let calculatedBitrate = Int(targetBitsPerSecond)
        
        // Clamp to reasonable range
        return max(2_000_000, min(calculatedBitrate, videoBitrate))
    }
}

// MARK: - Caption Generation
/// Caption generation utilities as specified in requirements
public struct CaptionGenerator {
    /// Generate default caption from recipe with premium emojis
    public static func defaultCaption(from recipe: ViralRecipe) -> String {
        let title = recipe.title
        let mins = recipe.timeMinutes.map { "\($0) min ⏱️" } ?? "quick 🎯"
        let cost = recipe.costDollars.map { "$\($0) 💰" } ?? ""
        let tags = ["#FridgeGlowUp", "#BeforeAfter", "#DinnerHack", "#HomeCooking", "#FoodTok"].joined(separator: " ")
        return "✨ \(title) ✨\n⏰ \(mins) \(cost)\n💬 Comment \"RECIPE\" for details 👇\n\(tags) 🔥"
    }
    
    /// CTA rotation pool as specified in requirements with premium emojis
    public static let ctaPool = [
        "Comment 'RECIPE' for details",
        "Save for grocery day 🛒",
        "Try this tonight? 👨‍🍳",
        "Save & try this tonight ✨",
        "From fridge → plate 😎"
    ]
    
    /// Get random CTA from pool
    public static func randomCTA() -> String {
        return ctaPool.randomElement() ?? ctaPool[0]
    }
    
    /// Generate hook text with premium emojis for virality
    // PREMIUM FIX: Enhanced with more emojis and dynamic text for viral appeal
    public static func generateHook(from recipe: ViralRecipe, template: ViralTemplate? = nil) -> String {
        // Premium: Carousel-specific hook for dynamic feel - commented out
        // if template == .beatSyncedCarousel {
        //     let baseHook = "Fridge mess to meal magic! 🍲✨"
        //     if let time = recipe.timeMinutes {
        //         return "\(baseHook) in \(time) min 🔥⚡"
        //     }
        //     return "\(baseHook) quick & easy 🔥✨"
        // }
        
        if let hook = recipe.hook {
            // Add emojis to existing hook
            return "\(hook) 🍳✨🔥"
        }
        
        let time = recipe.timeMinutes ?? 15
        let cost = recipe.costDollars.map { "$\($0)" } ?? ""
        return "Fridge chaos → dinner in \(time) min \(cost) 🍳✨⚡"
    }
    
    /// Process step text for display with timing icons and chef emoji
    // PREMIUM FIX: Removed step numbers, just show instructions
    public static func processStepText(_ step: ViralRecipe.Step, index: Int) -> String {
        // Remove any leading step numbers from the text itself
        var cleanedTitle = step.title
        // Remove patterns like "Step 1:" or "1." or "1:" from the beginning
        let patterns = ["Step \\d+[:.]", "\\d+[:.]", "Step \\d+"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: "^\(pattern)\\s*", options: .caseInsensitive) {
                let range = NSRange(location: 0, length: cleanedTitle.count)
                cleanedTitle = regex.stringByReplacingMatches(in: cleanedTitle, options: [], range: range, withTemplate: "")
            }
        }
        // Add timing icon if step has duration hint
        let timeIcon = step.secondsHint != nil ? " ⏱️" : ""
        return "\(cleanedTitle)\(timeIcon)"
    }
    
    /// Overloaded method for string steps
    public static func processStepText(_ step: String, index: Int) -> String {
        // Remove any leading step numbers from the text itself
        var cleanedStep = step
        // Remove patterns like "Step 1:" or "1." or "1:" from the beginning
        let patterns = ["Step \\d+[:.]", "\\d+[:.]", "Step \\d+"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: "^\(pattern)\\s*", options: .caseInsensitive) {
                let range = NSRange(location: 0, length: cleanedStep.count)
                cleanedStep = regex.stringByReplacingMatches(in: cleanedStep, options: [], range: range, withTemplate: "")
            }
        }
        return cleanedStep
    }
    
    /// Process ingredient text for display with shopping cart emoji
    // PREMIUM FIX: Added 🛒 emoji and capitalization for better readability
    public static func processIngredientText(_ ingredients: [String]) -> [String] {
        return ingredients.prefix(3).map { ingredient in
            let capitalized = ingredient.prefix(1).capitalized + ingredient.dropFirst()
            let truncated = String(capitalized.prefix(20)) + (capitalized.count > 20 ? "..." : "")
            return "🛒 \(truncated)"
        }
    }
}