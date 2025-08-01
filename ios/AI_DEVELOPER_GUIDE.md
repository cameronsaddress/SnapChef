# SnapChef AI Developer Guide

This guide provides everything an AI assistant needs to understand and work with the SnapChef iOS codebase.

## Quick Start for AI Assistants

### Project Location
```
Working Directory: /Users/cameronanderson/SnapChef/snapchef/ios/
GitHub: https://github.com/cameronsaddress/snapchef
```

### Key Files to Read First
1. `CLAUDE.md` - Recent updates and guidelines
2. `SnapChef/App/ContentView.swift` - Navigation structure
3. `SnapChef/Core/ViewModels/AppState.swift` - Global state
4. `SnapChef/Core/Networking/SnapChefAPIManager.swift` - API integration

## Architecture Overview

### App Structure
```
Entry Point: SnapChefApp.swift
    └── ContentView
        ├── LaunchAnimationView (first run)
        └── MainTabView
            ├── Tab 0: HomeView
            ├── Tab 1: CameraView
            ├── Tab 2: RecipesView
            ├── Tab 3: ChallengeHubView
            └── Tab 4: ProfileView
```

### State Management
- **Global State**: `AppState` (recipes, user data, chef personas)
- **Auth State**: `AuthenticationManager` (user auth)
- **Device State**: `DeviceManager` (device fingerprinting)
- **Game State**: `GamificationManager` (points, badges, challenges)

### Data Flow Pattern
```
User Action → View → ViewModel/Manager → API/Storage → State Update → View Update
```

## Common Development Tasks

### 1. Adding a New Feature
```swift
// 1. Create feature folder
Features/YourFeature/

// 2. Create main view
struct YourFeatureView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            MagicalBackground() // Always use this background
            
            // Your content here
        }
    }
}

// 3. Add navigation
// In appropriate parent view, add NavigationLink or sheet
```

### 2. Working with API
```swift
// Always use SnapChefAPIManager
SnapChefAPIManager.shared.sendImageForRecipeGeneration(
    image: uiImage,
    sessionId: UUID().uuidString,
    // ... other params
) { result in
    switch result {
    case .success(let response):
        // Handle success
    case .failure(let error):
        // Handle error
    }
}
```

### 3. Using Design System
```swift
// Glass card container
GlassmorphicCard(content: {
    // Your content
}, glowColor: Color(hex: "#667eea"))

// Primary button
MagneticButton(
    title: "Action",
    icon: "icon.name"
) {
    // Action
}

// Colors - always use hex
Color(hex: "#667eea") // Primary purple
Color(hex: "#4facfe") // Primary blue
```

### 4. Managing Challenges
```swift
// Track progress
ChallengeProgressTracker.shared.trackAction(.recipeCreated, metadata: [:])

// Complete challenge
GamificationManager.shared.completeChallenge(challengeId: "id")

// Award coins
ChefCoinsManager.shared.awardCoins(amount: 100, reason: "Challenge completed")
```

## File Organization Rules

### Where to Put New Files
```
Features/
├── YourFeature/
│   ├── YourFeatureView.swift      # Main view
│   ├── YourFeatureViewModel.swift # Business logic
│   └── Components/                # Feature-specific components

Core/
├── Models/         # Data models (Codable structs)
├── Services/       # Business logic, API calls
├── Utilities/      # Helper functions
└── ViewModels/     # Shared view models

Design/
└── YourComponent.swift  # Reusable UI components
```

### Naming Conventions
- **Views**: `SomethingView.swift`
- **Models**: `Something.swift` (no suffix)
- **Managers**: `SomethingManager.swift`
- **Services**: `SomethingService.swift`

## Critical Implementation Details

### 1. Camera Implementation
- Uses AVFoundation with `CameraModel` wrapper
- Always check permissions before use
- Processing shows `EmojiFlickGame` mini-game
- Results displayed in `RecipeResultsView`

### 2. Recipe Model Structure
```swift
struct Recipe {
    let id: UUID
    let name: String
    let ingredients: [Ingredient]
    let instructions: [String]
    let nutrition: Nutrition
    let tags: [String]          // Required!
    let dietaryInfo: DietaryInfo // Required!
    // ... other fields
}
```

### 3. Challenge System
- Uses Core Data for persistence
- CloudKit integration pending
- Real-time tracking via `ChallengeProgressTracker`
- Premium users get 2x rewards

### 4. Navigation Patterns
- Single `NavigationStack` at root
- Use `NavigationLink` for push
- Use `.sheet()` for modals
- Use `.fullScreenCover()` for full screen

## Common Pitfalls & Solutions

### 1. Division by Zero in Achievement Gallery
```swift
// WRONG
let percentage = count / total * 100

// CORRECT
let percentage = total == 0 ? 0 : Int(Double(count) / Double(total) * 100)
```

### 2. Missing Recipe Properties
```swift
// Always include tags and dietaryInfo when creating recipes
Recipe(
    // ... other properties
    tags: [],
    dietaryInfo: DietaryInfo(
        isVegetarian: false,
        isVegan: false,
        isGlutenFree: false,
        isDairyFree: false
    )
)
```

### 3. GlassmorphicCard Parameters
```swift
// CORRECT parameter order
GlassmorphicCard(content: {
    // Content closure first
}, glowColor: .blue) // Color parameter second
```

### 4. Background Usage
```swift
// ALWAYS use MagicalBackground as base layer
ZStack {
    MagicalBackground()
        .ignoresSafeArea()
    
    // Your content on top
}
```

## Testing Checklist

### Before Committing
1. Build succeeds without errors
2. No crashes on main user flows
3. API calls handle errors gracefully
4. UI works on iPhone 12-16 Pro
5. Dark mode only (no light mode)

### Key User Flows to Test
1. **Camera Flow**: Launch → Camera → Capture → Results → Save
2. **Challenge Flow**: Hub → Join → Complete → Rewards
3. **Share Flow**: Recipe → Share → Style → Post
4. **Profile Flow**: Profile → Settings → Save

## Build & Run Commands

```bash
# Build
xcodebuild -project SnapChef.xcodeproj -scheme SnapChef -configuration Debug

# Clean
xcodebuild clean -project SnapChef.xcodeproj -scheme SnapChef

# Run tests (when implemented)
xcodebuild test -project SnapChef.xcodeproj -scheme SnapChef
```

## Current Status (v1.1.0-stable)

### ✅ Working Features
- Complete camera flow with AI recipe generation
- Challenge system with gamification
- Recipe browsing and details
- Social sharing with styles
- Profile and preferences
- Daily check-ins and streaks

### 🚧 Pending Implementation
- CloudKit sync configuration
- Push notifications setup
- Analytics integration
- Subscription receipt validation
- App Store icons

### ⚠️ Known Issues
- Core Data build warnings (cosmetic)
- Some unused variables
- No app icons configured

## API Integration

### Endpoint
```
POST https://snapchef-server.onrender.com/analyze_fridge_image
Headers: X-App-API-Key: [from keychain]
```

### Request Fields
- `image_file`: JPEG data
- `session_id`: UUID string
- `dietary_restrictions`: JSON array
- `number_of_recipes`: String (default "5")

### Response Format
```json
{
  "data": {
    "ingredients": [...],
    "recipes": [...]
  }
}
```

## Questions to Ask Before Making Changes

1. Does this follow the existing navigation pattern?
2. Am I using MagicalBackground as the base?
3. Did I handle loading and error states?
4. Will this work without light mode?
5. Have I updated the relevant documentation?

---
Last Updated: January 31, 2025
For: AI Assistants working on SnapChef