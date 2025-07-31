# SnapChef Developer Quick Reference

## Quick Links
- [Common Tasks](#common-tasks)
- [File Locations](#file-locations)
- [API Endpoints](#api-endpoints)
- [Key Constants](#key-constants)
- [Testing Commands](#testing-commands)
- [Debugging Tips](#debugging-tips)

## Common Tasks

### 🚀 Run the App
```bash
# Open in Xcode
open SnapChef.xcodeproj

# Build from command line
xcodebuild -project SnapChef.xcodeproj -scheme SnapChef -configuration Debug

# Run on specific simulator
xcodebuild -project SnapChef.xcodeproj -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

### 📸 Test Camera Flow
1. Use "Test with Fridge Image" button in CameraView
2. Test image: `fridge.jpg` in bundle
3. Skips camera permissions

### 🎮 Test Gamification
```swift
// In any view
@EnvironmentObject var gamificationManager: EnhancedGamificationManager

// Award points
gamificationManager.awardPoints(50, for: .recipeCompleted)

// Unlock badge
gamificationManager.checkAndUnlockBadges()
```

### 🎨 Add New Recipe Style
1. Edit `ShareGeneratorView.ShareStyle` enum
2. Add gradient in `ShareImageContent.backgroundGradient`
3. Update style selector UI

## File Locations

### Core Files
```
Features/Camera/CameraView.swift          # Main camera interface
Features/Camera/EmojiFlickGame.swift      # Mini-game during processing
Features/Recipes/RecipeResultsView.swift  # Recipe display
Features/Sharing/ShareGeneratorView.swift # Share creation
Core/Networking/SnapChefAPIManager.swift  # API integration
Core/ViewModels/AppState.swift           # Global state
```

### UI Components
```
Design/GlassmorphicComponents.swift      # Glass effect cards
Design/WhimsicalAnimations.swift         # Animation effects
Design/PremiumGamificationVisuals.swift  # Badge animations
Design/InteractiveElements.swift         # Buttons, toasts
```

### Models
```
Core/Models/Recipe.swift                 # Recipe data model
Core/Models/Chef.swift                   # Chef personas
Features/Gamification/Models/Badge.swift # Achievement models
Features/Gamification/Models/Quest.swift # Challenge models
```

## API Endpoints

### Production Server
```swift
let baseURL = "https://snapchef-server.onrender.com"
let analyzeEndpoint = "/analyze_fridge_image"
```

### Request Headers
```swift
"X-App-API-Key": "your-api-key"
"Content-Type": "multipart/form-data"
```

### Request Parameters
```swift
// Required
image_file: Data      // JPEG 80% quality
session_id: String    // UUID

// Optional
dietary_restrictions: String  // JSON array
food_type: String
difficulty_preference: String
health_preference: String
meal_type: String
cooking_time_preference: String
number_of_recipes: String
```

## Key Constants

### Colors
```swift
// Primary gradient
Color(hex: "#667eea")  // Purple
Color(hex: "#764ba2")  // Deep purple

// Accent colors
Color(hex: "#43e97b")  // Success green
Color(hex: "#38f9d7")  // Cyan
Color(hex: "#f093fb")  // Pink
Color(hex: "#4facfe")  // Blue
```

### Animation Durations
```swift
// Standard animations
.spring(response: 0.5, dampingFraction: 0.8)
.easeInOut(duration: 0.5)

// Progress bars
.linear(duration: 60)  // 60 seconds

// Mini-game
gameTime: 60.0        // seconds
emojiSpawnRate: 1.5   // seconds
```

### Gamification Points
```swift
snapPhoto: 10
completeRecipe: 50
shareRecipe: 25
dailyStreak: 20
perfectWeek: 100
firstRecipe: 30
```

## Testing Commands

### Unit Tests
```bash
xcodebuild test -project SnapChef.xcodeproj -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### UI Tests
```bash
# Run specific test
xcodebuild test -project SnapChef.xcodeproj -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:SnapChefUITests/CameraFlowTests
```

### Performance Tests
```bash
# Use Instruments
instruments -t "Time Profiler" -D trace.trace SnapChef.app
```

## Debugging Tips

### 🐛 Common Issues

#### Camera Black Screen
```swift
// Check permissions
AVCaptureDevice.authorizationStatus(for: .video)

// Reset permissions
Settings > Privacy > Camera > SnapChef
```

#### API Timeout
```swift
// Increase timeout in SnapChefAPIManager
request.timeoutInterval = 60 // seconds
```

#### Animation Lag
```swift
// Add to complex views
.drawingGroup()

// Reduce particle count
maxParticles = 50 // instead of 100
```

### 📱 Console Logs
```bash
# View simulator logs
xcrun simctl spawn booted log stream --level debug --predicate 'subsystem == "com.snapchefapp.app"'

# Filter by process
xcrun simctl spawn booted log stream --process SnapChef
```

### 🔍 Debug Views
```swift
// Add debug overlay
.overlay(
    Text("FPS: \(fps)")
        .font(.caption)
        .padding(4)
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
)

// Memory usage
.onReceive(timer) { _ in
    let memory = getMemoryUsage()
    print("Memory: \(memory)MB")
}
```

### 🎯 Breakpoints
```swift
// Symbolic breakpoints
UIViewAlertForUnsatisfiableConstraints
-[UIViewController viewDidLoad]

// Exception breakpoints
Swift Error
Objective-C Exception
```

## Quick Fixes

### Reset App State
```swift
// In AppState.swift
func resetAllData() {
    UserDefaults.standard.removePersistentDomain(
        forName: Bundle.main.bundleIdentifier!
    )
    // Clear keychain
    KeychainManager.shared.clearAll()
}
```

### Force Refresh UI
```swift
// Add to any view
.id(UUID()) // Forces view recreation
```

### Clear Image Cache
```swift
// In appropriate manager
URLCache.shared.removeAllCachedResponses()
```

## Useful Snippets

### Add New Badge
```swift
let newBadge = Badge(
    id: "unique_id",
    name: "Badge Name",
    description: "What it's for",
    icon: "systemName",
    category: .cooking,
    requiredCount: 5,
    tier: .bronze
)
```

### Custom Animation
```swift
withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
    // Your state changes
}
```

### Haptic Feedback
```swift
let impact = UIImpactFeedbackGenerator(style: .medium)
impact.impactOccurred()
```

### Share Image
```swift
let renderer = ImageRenderer(content: YourView())
renderer.scale = 3.0
if let image = renderer.uiImage {
    // Use image
}
```

---

Last Updated: January 31, 2025
Quick Reference v1.0