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
        ├── OnboardingView (first launch)
        └── MainTabView (5-tab structure)
            ├── Tab 0: HomeView
            ├── Tab 1: CameraView (no tab bar when active)
            ├── Tab 2: RecipesView
            ├── Tab 3: SocialFeedView (with activity feed)
            └── Tab 4: ProfileView
```

### State Management
- **Global State**: `AppState` (delegates to focused ViewModels)
  - `RecipesViewModel` (recipe management, Core Data + CloudKit)
  - `AuthViewModel` (dual auth system, progressive premium)
  - `GamificationViewModel` (challenges, subscriptions)
- **Auth State**: `CloudKitAuthManager` (unified auth system)
- **Device State**: `DeviceManager` (device management, preferences)
- **Progressive Premium**: `UserLifecycleManager` (3-phase lifecycle)

### Data Architecture
- **Hybrid Storage**: CloudKit for sync + Core Data for offline
- **Progressive Premium**: 3-phase user lifecycle (Honeymoon → Trial → Standard)
- **Dual Authentication**: Anonymous users + optional CloudKit auth
- **API Integration**: Gemini as default LLM provider

### Data Flow Pattern
```
User Action → View → ViewModel → Manager/Service → API/CloudKit/Core Data → State Update → View Update
```

## App Overview

### Current Features (v1.1.0-stable)
- **Camera Flow**: Snap fridge → AI analysis → Recipe generation
- **Recipe Management**: Save, favorite, view history (CloudKit + Core Data)
- **Social Features**: Activity feed, follow/unfollow, recipe sharing
- **Challenge System**: Daily/Weekly/Community challenges with rewards
- **Progressive Premium**: 3-phase lifecycle with usage limits
- **Video Generation**: TikTok-style recipe videos with custom overlays
- **Dual Authentication**: Start anonymous, optionally upgrade to CloudKit
- **Subscription System**: Premium plans with StoreKit integration

### Navigation Flow
1. **Home Tab**: Main CTA, challenges, recent recipes, mystery meal
2. **Camera Tab**: Full-screen capture experience (hides tab bar)
3. **Recipes Tab**: Browse saved/recent recipes with filters
4. **Social Tab**: Activity feed, discover users, social stats
5. **Profile Tab**: User settings, subscription, achievements

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
// Always use SnapChefAPIManager with Gemini as default
SnapChefAPIManager.shared.sendImageForRecipeGeneration(
    image: uiImage,
    sessionId: UUID().uuidString,
    dietaryRestrictions: [],
    llmProvider: "gemini", // Default provider
    // ... other preferences
) { result in
    switch result {
    case .success(let response):
        // Convert and save recipes
        let recipes = response.data.recipes.map { 
            SnapChefAPIManager.shared.convertAPIRecipeToAppRecipe($0)
        }
    case .failure(let error):
        // Use comprehensive error handling
        appState.handleError(SnapChefError.from(error))
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

### 4. Managing Challenges & Progressive Premium
```swift
// Track recipe creation with progressive features
appState.trackRecipeCreated(recipe)

// Check usage limits based on lifecycle phase
if appState.canCreateRecipe() {
    // Proceed with recipe creation
} else {
    // Show upgrade prompt based on user phase
}

// Track challenge progress
ChallengeProgressTracker.shared.handleRecipeCreated(recipe)

// Complete challenge
GamificationManager.shared.completeChallenge(challengeId: "id")
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

### 2. Authentication Flow (Dual System)
- **Phase 1**: Anonymous users with `AnonymousUserProfile` in Keychain
- **Phase 2**: Progressive auth prompts based on usage (7+ recipes)
- **Phase 3**: Optional CloudKit authentication for sync
- **Data**: Local persistence works independently of auth state

### 3. Challenge System
- Uses CloudKit for real-time sync + Core Data for offline
- Dynamic challenge generation via `ChallengeGenerator`
- Real-time tracking via `ChallengeProgressTracker`
- Premium users get enhanced rewards

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

## Premium Features (3-Phase Lifecycle)

### Phase System
1. **Honeymoon (Days 0-7)**: High limits, gentle introduction
2. **Trial (Days 8-30)**: Reduced limits, upgrade prompts
3. **Standard (Day 31+)**: Base limits, strong upgrade incentives

### Daily Limits by Phase
- **Honeymoon**: 10 recipes, 3 videos, basic features
- **Trial**: 5 recipes, 2 videos, limited premium effects
- **Standard**: 3 recipes, 1 video, minimal features
- **Premium**: Unlimited everything

## API Integration

### Endpoint
```
POST https://snapchef-server.onrender.com/analyze_fridge_image
Headers: X-App-API-Key: [from keychain]
```

### Key Request Fields
- `image_file`: JPEG data (resized to 2048px max)
- `session_id`: UUID string
- `dietary_restrictions`: JSON array
- `llm_provider`: "gemini" (default), "openai", etc.
- `food_preferences`: JSON array
- `existing_recipe_names`: Avoid duplicates

### Response Format
```json
{
  "data": {
    "image_analysis": { "is_food_image": true },
    "ingredients": [...],
    "recipes": [...]
  },
  "message": "Success"
}
```

## Current Status (v1.1.0-stable)

### ✅ Working Features
- Complete camera flow with Gemini AI integration
- Hybrid CloudKit + Core Data storage
- Dual authentication system (anonymous → CloudKit)
- 3-phase progressive premium lifecycle
- Challenge system with real-time CloudKit sync
- Social features: follow/unfollow, activity feed
- TikTok video generation with custom overlays
- StoreKit subscription integration
- Comprehensive error handling system

### 🚧 In Development
- Enhanced CloudKit conflict resolution
- Advanced analytics integration
- Push notification system
- AI-powered challenge recommendations

### ⚠️ Known Issues
- Core Data bundle resource warnings (cosmetic)
- Some Swift 6 concurrency warnings
- Package.resolved file needs cleanup

## Questions to Ask Before Making Changes

1. Does this follow the existing navigation pattern?
2. Am I using MagicalBackground as the base?
3. Did I handle loading and error states?
4. Will this work without light mode?
5. Have I updated the relevant documentation?

---
Last Updated: January 31, 2025
For: AI Assistants working on SnapChef