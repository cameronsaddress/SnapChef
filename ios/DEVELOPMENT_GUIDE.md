# SnapChef iOS Development Guide

## Getting Started

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later
- iOS 15.0+ SDK
- Git
- CocoaPods (optional, not currently used)

### Initial Setup

1. **Clone the repository**
```bash
git clone https://github.com/cameronsaddress/snapchef.git
cd snapchef/ios
```

2. **Open in Xcode**
```bash
open SnapChef.xcodeproj
```

3. **Configure signing**
- Select the SnapChef target
- Go to Signing & Capabilities
- Select your development team
- Xcode will auto-generate provisioning profiles

4. **Build and run**
- Select target device/simulator
- Press Cmd+R or click the Run button

## Project Configuration

### Build Settings
- **Deployment Target**: iOS 15.0
- **Swift Language Version**: 5.9
- **Build Configuration**: Debug/Release
- **Code Signing**: Automatic

### Info.plist Keys
```xml
<!-- Camera permissions -->
<key>NSCameraUsageDescription</key>
<string>SnapChef needs camera access to take photos of your fridge and pantry for recipe generation.</string>

<!-- Photo library permissions -->
<key>NSPhotoLibraryUsageDescription</key>
<string>SnapChef needs photo library access to save your recipe photos.</string>

<!-- Social media URL schemes -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tiktok</string>
    <string>instagram</string>
    <string>instagram-stories</string>
    <string>twitter</string>
    <string>x</string>
</array>
```

## Development Workflow

### Branch Strategy
```
main (production)
  ├── develop (staging)
  │   ├── feature/camera-improvements
  │   ├── feature/new-chef-persona
  │   └── bugfix/api-timeout
  └── hotfix/critical-crash
```

### Commit Guidelines
Use conventional commits:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `style:` Code style changes
- `refactor:` Code refactoring
- `test:` Test additions/changes
- `chore:` Maintenance tasks

Example:
```bash
git commit -m "feat: add barcode scanning to camera view"
```

### Code Review Process
1. Create feature branch from `develop`
2. Make changes and commit
3. Push branch and create PR
4. Request review from team
5. Address feedback
6. Merge to `develop` after approval

## Debugging

### Common Issues

#### API Connection Failed
```swift
// Check these in order:
1. Verify API key in Keychain
2. Check network connectivity
3. Verify server URL is correct
4. Check SSL certificate (production only)
5. Review server logs
```

#### Camera Permission Denied
```swift
// Handle in CameraModel.swift
AVCaptureDevice.requestAccess(for: .video) { granted in
    if !granted {
        // Show permission explanation
    }
}
```

#### Memory Warnings
- Profile with Instruments
- Check image sizes
- Clear caches on memory warning
- Use autoreleasepool for loops

### Debug Tools

#### Xcode Debugger
- Breakpoints (Cmd+\)
- View hierarchy debugger
- Memory graph debugger
- Network traffic inspector

#### Console Logging
```swift
// Development logging
#if DEBUG
print("🎯 API Response: \(response)")
#endif

// Structured logging
Logger.shared.log(.debug, "Camera session started")
```

#### SwiftUI Preview
```swift
#Preview {
    RecipeDetailView(recipe: MockDataProvider.sampleRecipe)
        .environmentObject(AppState())
}
```

## Testing

### Unit Tests
Location: `SnapChefTests/`

```swift
func testRecipeDecoding() throws {
    let json = """
    {"id": "123", "name": "Test Recipe", ...}
    """
    let data = json.data(using: .utf8)!
    let recipe = try JSONDecoder().decode(Recipe.self, from: data)
    XCTAssertEqual(recipe.name, "Test Recipe")
}
```

### UI Tests
Location: `SnapChefUITests/`

```swift
func testCameraFlow() {
    let app = XCUIApplication()
    app.launch()
    
    app.buttons["Snap Your Fridge"].tap()
    XCTAssert(app.otherElements["CameraView"].exists)
    
    app.buttons["CaptureButton"].tap()
    XCTAssert(app.otherElements["RecipeResults"].waitForExistence(timeout: 10))
}
```

### Performance Tests
```swift
func testImageCompression() {
    measure {
        let compressed = testImage.jpegData(compressionQuality: 0.8)
        XCTAssertNotNil(compressed)
    }
}
```

## API Development

### Mock Mode
Enable in `AppState.swift`:
```swift
#if DEBUG
static let useMockData = true
#endif
```

### Network Logging
```swift
// In SnapChefAPIManager
private func logRequest(_ request: URLRequest) {
    #if DEBUG
    print("📡 Request: \(request.url?.absoluteString ?? "")")
    print("📡 Headers: \(request.allHTTPHeaderFields ?? [:])")
    #endif
}
```

### Testing with Charles Proxy
1. Install Charles Proxy
2. Configure SSL certificate
3. Set proxy in iOS Simulator
4. Monitor API traffic

## Performance Optimization

### Image Handling
```swift
// Compress before upload
let compressedData = image.jpegData(compressionQuality: 0.8)

// Resize if needed
let resized = image.resized(to: CGSize(width: 2048, height: 2048))
```

### Animation Performance
```swift
// Use drawing group for complex animations
ParticleView()
    .drawingGroup() // Renders offscreen

// Limit animation updates
.animation(.default, value: animationTrigger)
```

### Memory Management
```swift
// Clear caches
NotificationCenter.default.addObserver(
    self,
    selector: #selector(clearCaches),
    name: UIApplication.didReceiveMemoryWarningNotification,
    object: nil
)
```

## Release Process

### Pre-release Checklist
- [ ] Update version number
- [ ] Update build number
- [ ] Test on all supported devices
- [ ] Run full test suite
- [ ] Check analytics integration
- [ ] Verify API endpoints
- [ ] Update App Store screenshots
- [ ] Prepare release notes

### Build for Release
1. Select "Any iOS Device" as target
2. Product → Archive
3. Validate archive
4. Upload to App Store Connect
5. Submit for review

### Beta Testing
1. Upload to TestFlight
2. Add external testers
3. Monitor crash reports
4. Gather feedback
5. Iterate based on feedback

## Troubleshooting

### Build Failures
```bash
# Clean build folder
cmd+shift+K

# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset package caches
File → Packages → Reset Package Caches
```

### Simulator Issues
```bash
# Reset simulator
Device → Erase All Content and Settings

# Clean simulator build
xcrun simctl delete all
```

### Code Signing Issues
1. Check Apple Developer account
2. Refresh provisioning profiles
3. Clean build folder
4. Restart Xcode
5. Check certificate expiration

## Resources

### Documentation
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [AVFoundation Guide](https://developer.apple.com/av-foundation/)
- [App Store Guidelines](https://developer.apple.com/app-store/guidelines/)

### Tools
- [SwiftLint](https://github.com/realm/SwiftLint) - Code style
- [Instruments](https://developer.apple.com/instruments/) - Performance
- [SF Symbols](https://developer.apple.com/sf-symbols/) - Icons
- [Create ML](https://developer.apple.com/createml/) - Future ML features

### Community
- SnapChef Slack (internal)
- iOS Developers Slack
- Swift Forums
- Stack Overflow

## Best Practices

### Code Quality
- Keep functions under 30 lines
- Extract complex views
- Use meaningful names
- Add documentation comments
- Handle all error cases

### SwiftUI Specific
- Use @StateObject for ownership
- Prefer @EnvironmentObject for shared state
- Extract subviews for performance
- Use ViewModifiers for reusability
- Profile with Instruments

### Security
- Never commit API keys
- Use Keychain for sensitive data
- Validate all inputs
- Handle authentication properly
- Keep dependencies updated