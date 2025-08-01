# SnapChef iOS App - Complete Architecture Documentation

## Table of Contents
1. [Overview](#overview)
2. [App Architecture](#app-architecture)
3. [Core Components](#core-components)
4. [Feature Modules](#feature-modules)
5. [Data Flow](#data-flow)
6. [User Journey](#user-journey)
7. [API Integration](#api-integration)
8. [UI/UX Design System](#uiux-design-system)
9. [State Management](#state-management)
10. [Security & Privacy](#security--privacy)

## Overview

SnapChef is an AI-powered iOS app that transforms photos of ingredients into personalized recipes. The app uses computer vision to identify ingredients in fridge/pantry photos and generates culturally diverse, dietary-conscious recipes through the Grok Vision API.

### Key Features
- 📸 **Smart Camera**: Captures and analyzes fridge/pantry contents
- 🎮 **Gamification**: Points, badges, challenges, and leaderboards
- 🎨 **Share Generator**: Create stunning social media posts
- 👨‍🍳 **AI Chef Personas**: 8 unique chef personalities
- 🌍 **Cultural Diversity**: Recipes from around the world
- 🥗 **Dietary Support**: Handles various dietary restrictions
- 🏆 **Social Features**: Share achievements and compete with friends

## App Architecture

### Directory Structure
```
ios/
├── SnapChef/
│   ├── App/                      # App entry point and main views
│   │   ├── SnapChefApp.swift    # App configuration
│   │   ├── ContentView.swift    # Main tab navigation
│   │   └── HomeView.swift       # Enhanced home screen
│   │
│   ├── Core/                     # Shared functionality
│   │   ├── Models/              # Data models
│   │   ├── Networking/          # API integration
│   │   ├── Services/            # Business logic
│   │   ├── Utilities/           # Helper functions
│   │   └── ViewModels/          # Global state management
│   │
│   ├── Design/                   # UI components and styling
│   │   ├── AnimationConstants.swift
│   │   ├── GlassmorphicComponents.swift
│   │   ├── PremiumGamificationVisuals.swift
│   │   └── WhimsicalAnimations.swift
│   │
│   └── Features/                 # Feature modules
│       ├── Camera/              # Photo capture and processing
│       ├── Gamification/        # Points, badges, challenges
│       ├── Profile/             # User settings and preferences
│       ├── Recipes/             # Recipe display and interaction
│       └── Sharing/             # Social media integration
```

## Core Components

### 1. App Entry Point (`SnapChefApp.swift`)
```swift
@main
struct SnapChefApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var gamificationManager = EnhancedGamificationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(deviceManager)
                .environmentObject(gamificationManager)
        }
    }
}
```
- Initializes global state objects
- Sets up environment for dependency injection
- Configures app lifecycle

### 2. Navigation (`ContentView.swift`)
```swift
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            EnhancedHomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            
            Text("Recipes")
                .tabItem { Label("Recipes", systemImage: "book.fill") }
                .tag(1)
            
            // Camera is accessed via modal from home
            
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(2)
        }
    }
}
```
- Tab-based navigation with custom morphing tab bar
- Camera presented as full-screen modal
- Gamification center accessible from home

### 3. State Management (`AppState.swift`)
```swift
class AppState: ObservableObject {
    @Published var currentChef: ChefPersona
    @Published var snapsTaken: Int
    @Published var allRecipes: [Recipe]
    @Published var savedRecipes: [Recipe]
    @Published var recentRecipes: [Recipe]
    
    // Methods for state updates
    func incrementSnapsTaken()
    func addRecentRecipe(_ recipe: Recipe)
    func saveRecipeWithPhotos(_ recipe: Recipe, beforePhoto: UIImage?, afterPhoto: UIImage?)
}
```
- Central source of truth for app data
- Persists data using UserDefaults/Core Data
- Publishes changes to update UI

## Feature Modules

### Camera Module (`Features/Camera/`)

#### CameraView.swift
Main camera interface with real-time preview and capture functionality:
- **Camera Setup**: Configures AVCaptureSession for photo capture
- **UI Overlay**: Scanning animation, AI status indicator
- **Photo Processing**: Captures image and sends to API
- **Game Integration**: Shows emoji flick game during processing

#### Key Components:
1. **CameraModel**: Manages AVFoundation camera session
2. **CameraPreview**: SwiftUI UIViewRepresentable for camera feed
3. **ScanningOverlay**: Animated corner brackets and scan line
4. **CaptureButton**: Custom button with haptic feedback

#### EmojiFlickGame.swift
Mini-game played during AI processing:
- **Physics Engine**: Custom physics for falling emojis
- **Touch Handling**: Flick gestures to launch emojis
- **Score System**: Points for successful hits
- **Background**: Semi-transparent fridge image (opacity: 0.375)

### Recipe Module (`Features/Recipes/`)

#### RecipeResultsView.swift
Displays AI-generated recipes:
```swift
struct RecipeResultsView: View {
    let recipes: [Recipe]
    let ingredients: [IngredientAPI]
    let capturedImage: UIImage?
    
    // Features:
    // - Magical recipe cards with animations
    // - Fridge inventory display
    // - Share functionality
    // - Confetti celebrations
}
```

#### MagicalRecipeCard
Custom card component:
- **Title**: Positioned at top to prevent cutoff (2 lines max)
- **Metrics**: Time indicator, calorie display (min width: 40)
- **Actions**: "Cook Now" and "Share" buttons
- **Animations**: Hover effects, shimmer animation

### Sharing Module (`Features/Sharing/`)

#### ShareGeneratorView.swift
Creates social media-ready images:
```swift
struct ShareGeneratorView: View {
    let recipe: Recipe
    let ingredientsPhoto: UIImage?
    @State private var afterPhoto: UIImage?
    @State private var selectedStyle: ShareStyle
    
    // Features:
    // - Style selector (4 themes)
    // - Before/after photo comparison
    // - Custom branding
    // - One-tap sharing
}
```

#### Key Changes:
- **Animation**: Single 15° rotation instead of continuous spin
- **Photo Capture**: Clickable after photo area
- **Layout**: "Share for Credits" below style selector
- **Removed**: Challenge text editor section

### Gamification Module (`Features/Gamification/`)

#### GamificationManager.swift
Central hub for all gamification features:
```swift
@MainActor
class GamificationManager: ObservableObject {
    @Published var userStats: UserGameStats
    @Published var activeChallenges: [Challenge]
    @Published var completedChallenges: [Challenge]
    @Published var weeklyLeaderboard: [LeaderboardEntry]
    @Published var globalLeaderboard: [LeaderboardEntry]
    @Published var unlockedBadges: [GameBadge]
    @Published var hasCheckedInToday: Bool
    
    // Point System:
    // - Recipe created: 10 points + quality bonus
    // - Challenge completed: Variable (100-2000 points)
    // - Daily check-in: 50 points
    // - Streak bonuses: 50-500 points
    // - Perfect recipe: 50 points
}
```

#### Challenge System Components

##### Core Services
1. **ChallengeGenerator** - Creates dynamic challenges based on user behavior
2. **ChallengeProgressTracker** - Real-time progress monitoring
3. **ChallengeService** - Core Data persistence and CloudKit sync
4. **ChefCoinsManager** - Virtual currency system
5. **ChallengeAnalytics** - Engagement tracking

##### Challenge Types
```swift
enum ChallengeType {
    case daily      // 24-hour challenges
    case weekly     // 7-day challenges  
    case special    // Event-based (Halloween, holidays)
    case community  // Global collaborative goals
}
```

##### UI Components
1. **ChallengeHubView** - Main dashboard for all challenges
2. **ChallengeCardView** - Individual challenge display with progress
3. **LeaderboardView** - Global and regional rankings
4. **AchievementGalleryView** - Badge collection display
5. **DailyCheckInView** - Streak maintenance interface

#### Badge System
```swift
struct GameBadge {
    let name: String
    let icon: String
    let description: String
    let rarity: BadgeRarity  // common, rare, epic, legendary
    let unlockedDate: Date
}
```

#### Reward System
- **Chef Coins**: Virtual currency for unlockables
- **XP Points**: Level progression system
- **Badges**: Achievement recognition
- **Titles**: Special designations
- **Themes**: Unlockable UI themes
- **Recipe Packs**: Exclusive content

#### Premium Features
- Exclusive premium-only challenges
- 2x coin rewards multiplier
- Special badges and titles
- Advanced analytics access
- Priority leaderboard placement

## Data Flow

### 1. Photo Capture Flow
```
User → CameraView → CapturePhoto → CameraModel
                                        ↓
                                   Process Image
                                        ↓
API ← SnapChefAPIManager ← Format Request
 ↓
Response → Parse → Convert Models → Update State
                    ↓                    ↓
         ChallengeProgressTracker   RecipeResultsView
                    ↓
         Update Challenge Progress
```

### 2. Challenge System Flow
```
User Action → ChallengeProgressTracker → Track Progress
                                              ↓
                                    Check Challenge Rules
                                              ↓
                            Update Progress → Notify Manager
                                              ↓
                                    Complete Challenge?
                                         ↓         ↓
                                       Yes        No
                                        ↓         ↓
                                Award Rewards  Continue
                                        ↓
                                Update Stats/Badges
```

### 2. API Request Structure
```swift
// Request Parameters
struct RecipeGenerationRequest {
    image: UIImage              // JPEG compressed to 80%
    sessionId: String          // UUID for tracking
    dietaryRestrictions: [String]
    foodType: String?          // Cuisine preference
    difficultyPreference: String?
    healthPreference: String?
    mealType: String?
    cookingTimePreference: String?
    numberOfRecipes: Int       // Default: 5
    existingRecipeNames: [String] // Avoid duplicates
}
```

### 3. Response Handling
```swift
// API Response Structure
struct APIResponse {
    let data: GrokParsedResponse {
        image_analysis: ImageAnalysis
        ingredients: [IngredientAPI]
        recipes: [RecipeAPI]
    }
}

// Conversion to App Models
RecipeAPI → Recipe (with generated ID)
IngredientAPI → Used directly for display
```

## User Journey

### First-Time User
1. **Launch**: Welcome animation with confetti
2. **Home**: See "Yay! This will be fun!" message
3. **Camera**: Permission request → Tutorial overlay
4. **Capture**: Take photo → Play emoji game
5. **Results**: View recipes → Earn first badge
6. **Share**: Create first post → Unlock achievement

### Returning User
1. **Home**: See snap count, recent recipes
2. **Quick Actions**: One-tap camera access
3. **Gamification**: Check daily quests
4. **Profile**: Adjust preferences
5. **Social**: View leaderboard position

## API Integration

### Endpoint Configuration
```swift
class SnapChefAPIManager {
    static let baseURL = "https://snapchef-server.onrender.com"
    static let analyzeEndpoint = "/analyze_fridge_image"
    
    // Headers
    "X-App-API-Key": KeychainManager.shared.getAPIKey()
    "Content-Type": "multipart/form-data"
}
```

### Error Handling
```swift
enum SnapChefError: LocalizedError {
    case networkError(String)
    case authenticationError(String)
    case apiError(String)
    case parsingError(String)
    case unknown(String)
}
```

## UI/UX Design System

### Color Palette
```swift
// Primary Gradients
LinearGradient(colors: [
    Color(hex: "#667eea"),  // Purple
    Color(hex: "#764ba2")   // Deep Purple
])

// Accent Colors
Color(hex: "#43e97b")  // Success Green
Color(hex: "#38f9d7")  // Cyan
Color(hex: "#f093fb")  // Pink
Color(hex: "#4facfe")  // Blue

// Semantic Colors
Background: MagicalBackground() // Animated gradient
Surface: Color.white.opacity(0.1)
Text: .white
Secondary: .white.opacity(0.8)
```

### Animation Standards
```swift
// Spring Animations
.spring(response: 0.5, dampingFraction: 0.8)

// Timing Functions
.easeInOut(duration: 0.5)
.linear(duration: 60) // Progress bars

// Performance
.drawingGroup() // For complex animations
60 FPS target
```

### Component Library
1. **GlassmorphicCard**: Frosted glass effect
2. **MagneticButton**: Animated action buttons
3. **ParticleExplosion**: Celebration effects
4. **FloatingActionButton**: Quick actions
5. **SuccessToast**: Feedback messages

## State Management

### Local Storage
```swift
// UserDefaults Keys
"CustomChefName"
"CustomChefPhoto"
"SelectedFoodPreferences"
"HasSeenCameraView"
"SnapsTakenCount"

// Keychain
API Key (secure storage)

// File System
Recipe photos: Documents/RecipePhotos/
```

### State Updates
```swift
// Reactive Updates
@Published properties → SwiftUI views
@EnvironmentObject → Global access
@StateObject → Owner lifecycle
@ObservedObject → Non-owner lifecycle
```

## Security & Privacy

### API Security
- **Authentication**: X-App-API-Key header
- **Key Storage**: iOS Keychain (encrypted)
- **HTTPS**: All requests use TLS
- **Rate Limiting**: Server-side protection

### User Privacy
- **Camera**: Permission required
- **Photos**: Stored locally only
- **Data**: No personal info sent to API
- **Analytics**: Opt-in only

### Data Protection
```swift
// Image Compression
UIImage → JPEG (80% quality) → Max 10MB

// Session Tracking
UUID per session (anonymous)

// Local Storage
FileManager with data protection
```

## Performance Optimizations

### Image Processing
- Compress before upload (80% JPEG)
- Lazy loading for recipe images
- Cache API responses
- Background queue for heavy operations

### Animation Performance
- Use `drawingGroup()` for complex views
- Limit particle counts (100 max)
- Profile with Instruments
- Test on iPhone 12 minimum

### Memory Management
- Clear image cache periodically
- Release camera session when not in use
- Use weak references for delegates
- Monitor memory warnings

## Testing Strategy

### Unit Tests
- Model conversion logic
- API response parsing
- Gamification calculations
- Date/time utilities

### UI Tests
- Camera flow
- Recipe generation
- Share creation
- Navigation paths

### Integration Tests
- Full user journey
- API error handling
- State persistence
- Performance benchmarks

## Future Enhancements

### Planned Features
1. **AI Voice Assistant**: Cooking guidance
2. **AR Recipe Overlay**: Step-by-step AR
3. **Social Feed**: Community recipes
4. **Meal Planning**: Weekly planners
5. **Grocery Lists**: Auto-generated lists
6. **Nutrition Tracking**: Health insights

### Technical Improvements
1. **SwiftData**: Replace Core Data
2. **Async/Await**: Throughout codebase
3. **Widget Support**: Home screen widgets
4. **Siri Shortcuts**: Voice commands
5. **CloudKit**: Sync across devices

## Troubleshooting

### Common Issues
1. **Camera Black Screen**: Check permissions
2. **API Timeout**: Increase to 60s
3. **Animation Lag**: Reduce particle count
4. **Build Errors**: Clean derived data

### Debug Tools
```bash
# View logs
xcrun simctl spawn booted log stream --level debug

# Reset simulator
xcrun simctl erase all

# Clean build
rm -rf ~/Library/Developer/Xcode/DerivedData
```

## Contributing

### Code Style
- SwiftUI declarative syntax
- MVVM architecture
- Meaningful variable names
- MARK comments for organization
- Keep views under 200 lines

### Git Workflow
1. Feature branches
2. Descriptive commits
3. PR with screenshots
4. Code review required
5. Squash and merge

## Recent Updates (January 2025)

### Challenge System Implementation (Completed)
- **Phase 1**: Database foundation with Core Data and CloudKit
- **Phase 2**: Complete UI with Challenge Hub and leaderboards
- **Phase 3**: Full integration with recipe creation and social features
- **Multi-Agent**: Orchestrated development using multiple AI agents

### Build Status
- ✅ All compilation errors fixed
- ✅ Challenge system fully integrated
- ⚠️ Minor warnings remain (unused variables, Core Data resources)

### Known Issues
1. **Build Warnings**:
   - Core Data generated files in Copy Bundle Resources
   - Unused variables: statusCode, transaction, feature

2. **Pending Tasks**:
   - Test subscription flow in iOS Simulator
   - Add server-side receipt validation
   - Complete App Store Connect agreements
   - Add localizations to subscription products

---

Last Updated: January 31, 2025
Version: 1.1.0