# TikTok Viral Content Generation Requirements
*Created: January 12, 2025*

## Executive Summary
Complete revamp of TikTok content generation to create extremely beautiful and viral videos following production-grade specifications.

## Core Requirements

### Video Specifications
- **Resolution**: 1080×1920 (9:16 aspect ratio)
- **Frame Rate**: 30 FPS
- **Format**: H.264 + AAC
- **Duration**: 7-15 seconds depending on template
- **Safe Zones**: Top/bottom 10-12% reserved for TikTok UI

### 5 Viral Video Templates

#### 1. Beat-Synced Photo Carousel "Snap Reveal"
- Duration: 10-12 seconds
- Hook on blurred BEFORE (2s)
- Ingredient/meal snaps with Ken Burns effect
- Beat-aligned transitions
- Final CTA overlay

#### 2. Split-Screen "Swipe" Before/After + Counters
- Duration: 9 seconds
- BEFORE full screen (1.5s)
- AFTER masked reveal with circular wipe (1.5s)
- Ingredient counters animation (4s)
- End card with CTA (2s)

#### 3. Kinetic-Text "Recipe in 5 Steps"
- Duration: 15 seconds
- Hook overlay on BEFORE (2s)
- Animated step text overlays
- Background: looping motion between images
- Auto-captioned for accessibility

#### 4. "Price & Time Challenge" Sticker Pack
- Duration: 12 seconds
- BEFORE with sticker stack (1s)
- Progress bar with b-roll or still (8s)
- AFTER with CTA (3s)
- Animated stickers for cost/time/calories

#### 5. Green-Screen "My Fridge → My Plate" (PIP)
- Duration: 15 seconds
- Picture-in-picture face overlay
- Base: BEFORE → B-ROLL → AFTER
- Dynamic callouts for ingredients
- Face placeholder for future selfie integration

## Technical Architecture

### Core Components
1. **ViralVideoEngine**: Main entry point for rendering
2. **ViralTemplate**: Enum of 5 formats
3. **RenderPlan**: Timeline of clips, overlays, animations
4. **Renderer**: AVFoundation + Core Animation compositor
5. **OverlayFactory**: Text, stickers, counters, progress bars
6. **FX**: Ken Burns, split-wipe, color pop effects
7. **AudioService**: Beat detection for rhythm cuts
8. **ShareService**: Save to Photos → PHAsset → TikTok SDK

### Data Models
```swift
Recipe {
    title: String
    hook: String?
    steps: [Step]
    timeMinutes: Int?
    costDollars: Int?
    calories: Int?
    ingredients: [String]
}

MediaBundle {
    beforeFridge: UIImage
    afterFridge: UIImage
    cookedMeal: UIImage
    brollClips: [URL]
    musicURL: URL?
}

RenderConfig {
    size: CGSize(1080×1920)
    fps: 30
    safeInsets: UIEdgeInsets
    maxDuration: 15s
    fontNameBold: String
    fontNameRegular: String
    textStrokeEnabled: Bool
    brandTint: UIColor
    brandShadow: UIColor
}
```

## Typography & Safe Zones

### Text Hierarchy
- **Hooks**: 60-72pt bold
- **Steps**: 44-52pt bold
- **Counters**: 36-48pt regular
- **CTAs**: 40pt bold in rounded stickers

### Safe Zone Requirements
- **Top**: 192px (10% of height)
- **Bottom**: 192px (10% of height)
- **Sides**: 72px each
- Never place critical text in these zones

## Animation Guidelines

### Motion Principles
- **Duration**: 200-300ms for transitions
- **Easing**: Spring animations with damping 12-14
- **Concurrent**: Max 2 animations at once
- **Entrance**: Fade + scale or slide
- **Exit**: Fade out only

### Effects
- **Ken Burns**: 1.08x scale with alternating pan
- **Split Wipe**: Circular reveal from center
- **Color Pop**: +0.1 contrast, +0.08 saturation on AFTER
- **Shadows**: 4px radius for text stroke

## Dynamic Text Mapping

### Hook Generation
- Primary: `recipe.hook`
- Fallback: "Fridge chaos → dinner in {time} min (${cost})"

### Ingredient Display
- Show first 3 ingredients
- Capitalize first letter
- Max 20 characters per ingredient

### Step Text
- Max 5-7 words per step
- Abbreviate if longer
- Number each step (1., 2., etc.)

### CTA Rotation
- "Comment 'RECIPE' for details"
- "Save for grocery day 🛒"
- "Try this tonight? 👇"
- "Save & try this tonight ✨"
- "From fridge → plate 😎"

## Audio Integration

### Beat Detection (Optional)
- Energy-based onset detection
- Align photo transitions to beats
- Debounce with 200ms minimum gap
- Fallback to fixed 1s intervals

### Background Music
- Support for optional music URL
- AAC 128-192 kbps
- Fade in/out at start/end

## Export Settings

### Video Compression
- **Codec**: H.264 High Profile
- **Bitrate**: 8-12 Mbps
- **Preset**: AVAssetExportPresetHighestQuality

### Audio Compression
- **Codec**: AAC
- **Bitrate**: 128-192 kbps
- **Sample Rate**: 44.1 kHz

## TikTok SDK Integration

### Setup Requirements
1. Install TikTok OpenSDK via SPM
2. Configure Info.plist with sandbox credentials
3. Handle URL callbacks in AppDelegate
4. Implement PHPhotoLibrary permissions

### Share Flow
1. Render video with ViralVideoEngine
2. Save to Photos with PHPhotoLibrary
3. Get PHAsset localIdentifier
4. Create TikTokShareRequest
5. Send to TikTok app

### Sandbox Credentials
- **Client Key**: sbawj0946ft24i4wjv
- **Client Secret**: 1BsqJsVa6bKjzlt2BvJgrapjgfNw7Ewk
- **Redirect URI**: https://example.dev/auth

## Quality Checklist

### Pre-Export
- [ ] Duration within limits (7-15s)
- [ ] Text in safe zones only
- [ ] Minimum 2 visual changes per second
- [ ] Hook appears in first 2 seconds
- [ ] CTA appears in last 3 seconds

### Post-Export
- [ ] File size under 50MB
- [ ] Plays smoothly at 30fps
- [ ] Audio synced properly
- [ ] No black frames
- [ ] Text readable on small screens

## Implementation Priority

### Phase 1: Core Engine
1. ViralVideoEngine setup
2. Basic Renderer with AVFoundation
3. OverlayFactory for text/stickers
4. Template 1 (Beat-Synced Carousel)

### Phase 2: All Templates
5. Template 2 (Split-Screen)
6. Template 3 (Kinetic Steps)
7. Template 4 (Price/Time)
8. Template 5 (Green Screen)

### Phase 3: Polish
9. Beat detection
10. Advanced effects
11. Performance optimization
12. A/B testing framework

## Success Metrics

### Engagement Targets
- **View Duration**: >80% completion rate
- **Engagement**: >10% like rate
- **Shares**: >2% share rate
- **Comments**: >1% comment rate

### Technical Targets
- **Render Time**: <5 seconds
- **Export Success**: >99% success rate
- **File Size**: <20MB average
- **Memory Usage**: <150MB peak

## Notes for Implementation

1. Always test on real devices (iPhone 12+)
2. Profile memory usage during rendering
3. Cache rendered frames for performance
4. Use background queues for export
5. Provide progress callbacks
6. Handle all error cases gracefully
7. Log analytics for each template usage
8. A/B test different CTAs
9. Monitor TikTok algorithm changes
10. Update templates based on trends