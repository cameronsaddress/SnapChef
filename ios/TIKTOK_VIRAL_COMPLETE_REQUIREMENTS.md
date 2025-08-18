# TikTok Viral Content Generation - Complete Requirements
*Created: January 12, 2025*

## CRITICAL: DO NOT FORGET THESE REQUIREMENTS

### Executive Summary
Complete revamp of TikTok content generation to create extremely beautiful and viral videos following production-grade specifications with full ShareService integration.

## Core Requirements

### Video Specifications
- **Resolution**: 1080×1920 (9:16 aspect ratio)
- **Frame Rate**: 30 FPS
- **Format**: H.264 + AAC
- **Duration**: 7-15 seconds depending on template
- **Safe Zones**: Top/bottom 10-12% reserved for TikTok UI
- **File Size**: Target <20MB, max 50MB

### 5 Viral Video Templates

#### 1. Beat-Synced Photo Carousel "Snap Reveal"
- Duration: 10-12 seconds
- Hook on blurred BEFORE (2s)
- Ingredient/meal snaps with Ken Burns effect (1.08x scale, alternating pan)
- Beat-aligned transitions (if music provided)
- Final CTA overlay
- Timeline: BEFORE (blurred) → ingredient snaps → cooked meal → AFTER

#### 2. Split-Screen "Swipe" Before/After + Counters
- Duration: 9 seconds
- BEFORE full screen (1.5s)
- AFTER masked reveal with circular wipe from center (1.5s)
- Ingredient counters animation (4s) - staggered appearance
- End card with CTA (2s)
- Visual: Split-wipe mask for dramatic reveal

#### 3. Kinetic-Text "Recipe in 5 Steps"
- Duration: 15 seconds
- Hook overlay on BEFORE (2s)
- Animated step text overlays (max 6 steps, 1.6s each minimum)
- Background: looping motion between images or b-roll
- Auto-captioned for accessibility
- Steps shortened to 5-7 words max

#### 4. "Price & Time Challenge" Sticker Pack
- Duration: 12 seconds
- BEFORE with sticker stack animation (1s + 2s overlap)
- Progress bar with b-roll or still (8s)
- AFTER with CTA (3s)
- Animated stickers for cost/time/calories
- Gradient progress bar animation

#### 5. Green-Screen "My Fridge → My Plate" (PIP)
- Duration: 15 seconds
- Picture-in-picture face overlay (340x340 circle)
- Base: BEFORE (3s) → B-ROLL/MEAL (6s) → AFTER (6s)
- Dynamic callouts for salvaged ingredients
- Face placeholder for future selfie integration
- PIP positioned top-right with shadow

## Data Models (Required Implementation)

```swift
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
}

public struct RenderConfig {
    public var size = CGSize(width: 1080, height: 1920)
    public var fps: Int32 = 30
    public var safeInsets = UIEdgeInsets(top: 192, left: 72, bottom: 192, right: 72)
    public var maxDuration: CMTime = CMTime(seconds: 15, preferredTimescale: 600)
    public var fontNameBold: String = "SF-Pro-Display-Bold"
    public var fontNameRegular: String = "SF-Pro-Display-Regular"
    public var textStrokeEnabled: Bool = true
    public var brandTint: UIColor = .white
    public var brandShadow: UIColor = .black
}
```

## ShareService Implementation (MANDATORY)

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
    static func requestPhotoPermission(_ completion: @escaping (Bool) -> Void)
    static func saveToPhotos(videoURL: URL, completion: @escaping (Result<String, ShareError>) -> Void)
    static func fetchAssets(localIdentifiers: [String]) -> [PHAsset]
    static func shareToTikTok(localIdentifiers: [String], caption: String?, completion: @escaping (Result<Void, ShareError>) -> Void)
}
```

### Share Flow Requirements
1. **Photo Library Permission**: Request and handle authorization
2. **Save to Photos**: Use PHPhotoLibrary.shared().performChanges
3. **Get localIdentifier**: From PHObjectPlaceholder
4. **Caption Handling**: Copy to UIPasteboard for user to paste
5. **TikTok Detection**: Check URL schemes (snssdk1180://, snssdk1233://)
6. **Share Request**: TikTokShareRequest with localIdentifiers
7. **Error Handling**: All failure cases must be handled

## End-to-End Implementation Flow

```swift
func shareRecipeToTikTok(template: ViralTemplate, recipe: Recipe, media: MediaBundle) {
    // 1. Render video
    engine.render(template: template, recipe: recipe, media: media) { result in
        // 2. Save to Photos
        ShareService.saveToPhotos(videoURL: url) { saveResult in
            // 3. Share to TikTok with localIdentifier
            ShareService.shareToTikTok(localIdentifiers: [localId], caption: caption) { shareResult in
                // 4. Handle completion
            }
        }
    }
}
```

## Caption Generation (Required)

```swift
private func defaultCaption(from recipe: Recipe) -> String {
    let title = recipe.title
    let mins = recipe.timeMinutes.map { "\($0) min" } ?? "quick"
    let cost = recipe.costDollars.map { "$\($0)" } ?? ""
    let tags = ["#FridgeGlowUp", "#BeforeAfter", "#DinnerHack", "#HomeCooking"].joined(separator: " ")
    return "\(title) — \(mins) \(cost)\nComment "RECIPE" for details 👇\n\(tags)"
}
```

## Typography & Safe Zones (EXACT SPECIFICATIONS)

### Text Hierarchy
- **Hooks**: 60-72pt bold (64pt default)
- **Steps**: 44-52pt bold (48pt default)
- **Counters**: 36-48pt regular (42pt default)
- **CTAs**: 40pt bold in rounded stickers
- **Ingredient callouts**: 42pt bold

### Safe Zone Requirements (MANDATORY)
- **Top**: 192px (10% of 1920px height)
- **Bottom**: 192px (10% of 1920px height)
- **Left**: 72px
- **Right**: 72px
- Never place critical text in these zones

### Text Styling
- **Stroke**: 4px shadow as fake stroke
- **Shadow Color**: Black with opacity 1.0
- **Max Width**: size.width - (safeInsets.left + safeInsets.right)
- **Line Limit**: 28-32 characters per line for readability

## Animation Specifications (EXACT TIMING)

### Motion Principles
- **Fade Duration**: 200-300ms
- **Spring Damping**: 12-14 for pop animations
- **Scale Range**: 0.6 to 1.0 for entrance
- **Concurrent Limit**: Max 2 animations at once
- **Stagger Delay**: 120-150ms between sequential elements

### Specific Animations
1. **Hero Hook**: Fade in 0.3s
2. **CTA Pop**: Spring 0.6s with scale 0.6→1.0
3. **Ingredient Callout**: Drop animation 0.5s with Y+50 offset
4. **Split Wipe**: Circular reveal over duration
5. **Kinetic Steps**: Slide up with 0.35s group animation
6. **Sticker Stack**: Staggered pop with 0.12s delay per item
7. **Progress Bar**: Linear animation matching duration

## Effects & Filters

### Ken Burns Effect
- **Scale**: 1.08x
- **Direction**: Alternating (index % 2)
- **Translation**: ±2% of size

### Color Pop (AFTER images only)
- **Contrast**: +0.1
- **Saturation**: +0.08
- **Apply via**: CIColorControls filter

### Blur Effect (BEFORE hook)
- **Filter**: CIGaussianBlur
- **Radius**: 10

## Technical Architecture (REQUIRED COMPONENTS)

### Core Classes
1. **ViralVideoEngine**: Main entry point
2. **Planner**: Creates RenderPlan for each template
3. **Renderer**: AVFoundation compositor
4. **OverlayFactory**: Text and sticker generation
5. **StillWriter**: Image to video conversion
6. **AudioBeatDetector**: Optional beat detection

### RenderPlan Structure
```swift
public struct RenderPlan {
    public struct TrackItem {
        public enum Kind { case still(UIImage), video(URL) }
        public let kind: Kind
        public let timeRange: CMTimeRange
        public let transform: CGAffineTransform
        public let filters: [CIFilter]
    }
    public struct Overlay {
        public let start: CMTime
        public let duration: CMTime
        public let layerBuilder: (_ config: RenderConfig) -> CALayer
    }
    public let items: [TrackItem]
    public let overlays: [Overlay]
    public let audio: URL?
    public let outputDuration: CMTime
}
```

## Export Settings (PRODUCTION QUALITY)

### Video Compression
- **Codec**: AVVideoCodecType.h264
- **Profile**: High Profile (kVTProfileLevel_H264_High_AutoLevel)
- **Bitrate**: 8-12 Mbps (10 Mbps target)
- **Preset**: AVAssetExportPresetHighestQuality

### Audio Compression
- **Codec**: AAC
- **Bitrate**: 128-192 kbps
- **Sample Rate**: 44.1 kHz

### Frame Writing (StillWriter)
- **Pixel Format**: kCVPixelFormatType_32ARGB
- **Frame Duration**: CMTime(value: 1, timescale: fps)
- **Context**: Reuse CIContext for performance

## TikTok SDK Integration (EXACT SETUP)

### Info.plist Configuration
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tiktokopensdk</string>
    <string>tiktoksharesdk</string>
    <string>snssdk1180</string>
    <string>snssdk1233</string>
</array>
<key>TikTokClientKey</key>
<string>sbawj0946ft24i4wjv</string>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>sbawj0946ft24i4wjv</string>
    </array>
  </dict>
</array>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>SnapChef needs access to save your recipe videos for sharing</string>
```

### AppDelegate/SceneDelegate Handlers
```swift
import TikTokOpenSDKCore

// AppDelegate
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if TikTokURLHandler.handleOpenURL(url) { return true }
    return false
}

// SceneDelegate
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url, TikTokURLHandler.handleOpenURL(url) { return }
}
```

### Sandbox Credentials
- **Client Key**: sbawj0946ft24i4wjv
- **Client Secret**: [REDACTED - Use KeychainManager]
- **Redirect URI**: https://example.dev/share

## Dynamic Text Mapping Rules

### Hook Generation
```swift
// Primary: recipe.hook
// Fallback: "Fridge chaos → dinner in \(recipe.timeMinutes ?? 15) min (\(recipe.costDollars.map{"$\($0)"} ?? "$"))"
```

### Ingredient Display
- Show first 3 ingredients
- Capitalize first letter
- Max 20 characters, truncate with "..."

### Step Text Processing
- Max 5-7 words per step
- Remove punctuation
- Number format: "1. Step text"

### CTA Rotation Pool
1. "Comment 'RECIPE' for details"
2. "Save for grocery day 🛒"
3. "Try this tonight? 👇"
4. "Save & try this tonight ✨"
5. "From fridge → plate 😎"

## Performance Requirements

### Rendering
- **Export Time**: <5 seconds for 15s video
- **Memory Peak**: <150MB during render
- **Frame Drop**: 0 frames
- **Success Rate**: >99%

### Optimization Techniques
1. Reuse CVPixelBuffer pools
2. Cache CIContext
3. Background queue for export
4. Delete temp files immediately
5. Profile with Instruments

## Quality Checklist (MANDATORY CHECKS)

### Pre-Export
- [ ] Duration within template limits
- [ ] All text in safe zones
- [ ] Hook appears in first 2 seconds
- [ ] Minimum 2 visual changes per second
- [ ] CTA appears in last 3 seconds
- [ ] Fonts fallback if custom unavailable

### Post-Export
- [ ] File size under 50MB
- [ ] Plays at exactly 30fps
- [ ] Audio perfectly synced
- [ ] No black frames
- [ ] Text readable at 50% zoom
- [ ] Safe zones respected

### Share Flow
- [ ] Photo permission requested
- [ ] Video saved to Photos
- [ ] LocalIdentifier retrieved
- [ ] Caption copied to clipboard
- [ ] TikTok app opens
- [ ] Video appears in TikTok

## Error Handling Requirements

### Required Error Cases
1. **Photo Permission Denied**: Show settings deep link
2. **Save Failed**: Retry with exponential backoff
3. **TikTok Not Installed**: App Store redirect
4. **Share Failed**: Show error with retry
5. **Render Failed**: Log and show user message
6. **Memory Warning**: Cancel and show message

## Testing Requirements

### Device Matrix
- iPhone 11, 12, 13, 14, 15, 16
- iPhone SE 2nd/3rd gen
- iOS 15, 16, 17, 18

### Test Scenarios
1. All 5 templates with minimal recipe
2. All 5 templates with full recipe
3. No b-roll (stills only)
4. No music (silent)
5. Missing hook (default generation)
6. 0-1 ingredients
7. Long step text (>60 chars)
8. Permission denied flows
9. TikTok not installed
10. Share completion callback

## Implementation Priority (EXACT ORDER)

### Phase 1: Core Engine (Day 1-2)
1. Data models (Recipe, MediaBundle, RenderConfig)
2. ViralVideoEngine setup
3. Basic Renderer with AVFoundation
4. StillWriter implementation
5. ShareService with Photos integration

### Phase 2: Template 1 & Overlays (Day 2-3)
6. OverlayFactory with all text styles
7. Planner base class
8. Template 1 (Beat-Synced Carousel)
9. Ken Burns effect
10. CTA overlays

### Phase 3: All Templates (Day 3-5)
11. Template 2 (Split-Screen with mask)
12. Template 3 (Kinetic Steps)
13. Template 4 (Price/Time stickers)
14. Template 5 (Green Screen PIP)
15. All overlay animations

### Phase 4: Polish & Integration (Day 5-6)
16. Color pop effects
17. Progress indicators
18. TikTok SDK full integration
19. Caption generation
20. Error handling

### Phase 5: Testing & Optimization (Day 6-7)
21. Performance profiling
22. Memory optimization
23. Device testing
24. A/B test framework
25. Analytics integration

## Success Metrics

### Engagement Targets
- **View Duration**: >80% completion
- **Engagement Rate**: >10% likes
- **Share Rate**: >2%
- **Comment Rate**: >1%
- **Save Rate**: >3%

### Technical Targets
- **Render Success**: >99%
- **Average File Size**: <20MB
- **Render Time**: <5 seconds
- **Memory Usage**: <150MB peak
- **Crash Rate**: <0.1%

## CRITICAL REMINDERS

1. **NEVER place text outside safe zones**
2. **ALWAYS test on real devices**
3. **ALWAYS handle all error cases**
4. **ALWAYS delete temp files**
5. **ALWAYS respect photo permissions**
6. **ALWAYS copy caption to clipboard**
7. **ALWAYS maintain strong references to TikTok requests**
8. **ALWAYS use sandbox credentials for development**
9. **ALWAYS profile memory during rendering**
10. **ALWAYS validate export before sharing**

## Additional Notes

- Font fallback: If SF-Pro-Display unavailable, use system bold
- Beat detection: Stub implementation, can enhance later
- PIP face: Placeholder for v1, add selfie recording in v2
- A/B testing: Track which templates get most engagement
- Analytics: Log template usage, render time, share success
- Localization: Prepare strings for translation
- RTL support: Consider for Arabic/Hebrew markets

This document contains ALL requirements. DO NOT FORGET any of these specifications during implementation.