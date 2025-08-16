# SnapChef Logo Asset

This image set contains the official SnapChef logo with the following specifications:

## Brand Guidelines

- **Text**: "SNAPCHEF!" (uppercase with exclamation point)
- **Font**: Heavy/Black weight, rounded design
- **Colors**: Gradient from Pink (#FF1493) → Purple (#9932CC) → Cyan (#00FFFF)
- **Effects**: Sparkles and dynamic elements

## File Structure

```
SnapChefLogo.imageset/
├── Contents.json          # Asset catalog configuration
├── SnapChefLogo@3x.png   # High-resolution PNG (1200×300px @3x)
├── SnapChefLogo.svg      # Vector version for reference
└── README.md             # This documentation
```

## Usage in SwiftUI

### Using the Image Asset
```swift
Image("SnapChefLogo")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 200, height: 50)
```

### Using the SwiftUI Component
```swift
// Different sizes with animations
SnapchefLogo.large(useImageAsset: true)
SnapchefLogo.medium(useImageAsset: true)
SnapchefLogo.small(useImageAsset: false) // Uses text fallback
SnapchefLogo.mini(useImageAsset: false)

// Custom configuration
SnapchefLogo(
    size: CGSize(width: 250, height: 60),
    animated: true,
    useImageAsset: true,
    showSparkles: false
)
```

## Regenerating the Logo

If you need to regenerate the PNG file:

1. Navigate to the iOS project directory
2. Run the logo generator script:
   ```bash
   swift GenerateLogo.swift
   ```

Or use the built-in Swift utilities:
```swift
LogoImageGenerator.generateAndSaveLogo()
```

## Technical Specifications

- **Resolution**: @3x (1200×300 pixels)
- **Format**: PNG with transparency
- **Color Space**: sRGB
- **File Size**: ~50-100KB
- **Aspect Ratio**: 4:1

## Brand Colors

| Color | Hex Code | RGB Values |
|-------|----------|------------|
| Pink | #FF1493 | (255, 20, 147) |
| Purple | #9932CC | (153, 50, 204) |
| Cyan | #00FFFF | (0, 255, 255) |

## Usage Guidelines

- ✅ Use on dark or light backgrounds
- ✅ Maintain aspect ratio when scaling
- ✅ Include sparkles for large displays
- ❌ Don't modify colors or typography
- ❌ Don't add additional effects
- ❌ Don't use stretched or distorted versions