# SnapChef iOS App Blueprint 2025
*Last Updated: January 12, 2025*

## Executive Overview

SnapChef is an AI-powered recipe generation iOS app that transforms photos of fridge contents into personalized recipes. Built with SwiftUI and modern iOS development practices, it features comprehensive gamification, social sharing, and CloudKit integration.

## Core Purpose & Vision

### What SnapChef Does
1. **Analyzes fridge photos** using AI (Grok Vision API) to identify ingredients
2. **Generates personalized recipes** based on available ingredients and preferences
3. **Gamifies cooking** with challenges, rewards, and social features
4. **Enables social sharing** across multiple platforms with optimized content
5. **Syncs data** across devices using CloudKit

### Target Users
- Home cooks looking to reduce food waste
- People seeking cooking inspiration from available ingredients
- Social media enthusiasts who share food content
- Users motivated by gamification and challenges

## Technical Architecture

### Foundation
- **Language**: Swift 6 with SwiftUI
- **Minimum iOS**: 16.0
- **Architecture Pattern**: MVVM with Environment Objects
- **State Management**: Combine + @Published properties
- **Backend**: FastAPI server (separate repository)
- **AI Integration**: Grok Vision API for image analysis
- **Cloud Services**: CloudKit for data sync and storage

### Dependencies
- **TikTok OpenSDK**: Direct social sharing integration
- **GoogleSignIn**: Authentication provider
- **Facebook SDK**: Authentication and sharing
- **Swift Package Manager**: Dependency management

## Application Structure

### Entry Points

#### SnapChefApp.swift
- Main app entry with `@main` annotation
- Initializes all environment objects
- Handles deep linking and URL schemes
- Sets up SDK integrations
- Manages app lifecycle events

#### AppDelegate.swift
- UIKit bridge for SDK requirements
- TikTok SDK initialization point
- Push notification handling (future)

### Navigation Hierarchy

```
ContentView
├── LaunchAnimationView (initial)
├── OnboardingView (first launch)
└── MainTabView
    ├── HomeView (Tab 0)
    │   ├── SnapchefLogo
    │   ├── MagneticButton → CameraView
    │   ├── InfluencerCarousel
    │   ├── StreakSummaryCard
    │   ├── FoodPreferencesCard
    │   ├── ViralChallengeSection
    │   ├── MysteryMealButton → MysteryMealView
    │   └── EnhancedRecipesSection
    ├── CameraView (Tab 1)
    │   ├── Camera preview
    │   ├── Capture controls
    │   ├── AI processing → EmojiFlickGame
    │   └── Results → RecipeResultsView
    ├── RecipesView (Tab 2)
    │   ├── Recipe grid/list
    │   ├── Search functionality
    │   └── Recipe details → RecipeDetailView
    ├── SocialFeedView (Tab 3)
    │   ├── Social stats header
    │   ├── ActivityFeedView
    │   └── DiscoverUsersView (sheet)
    └── ProfileView (Tab 4)
        ├── User info
        ├── Stats dashboard
        ├── Achievements
        └── Settings
```

## Core Features & Implementation

### 1. Recipe Generation Pipeline

#### Flow
1. **Image Capture** (CameraView)
   - AVFoundation camera session
   - Real-time preview
   - Photo capture with compression

2. **AI Processing** (SnapChefAPIManager)
   - Image upload (80% JPEG, max 2048px)
   - Multipart form data with preferences
   - 2-minute timeout for processing

3. **Recipe Display** (RecipeResultsView)
   - Card-based recipe presentation
   - Swipeable interface
   - Save/share functionality

#### API Communication
```swift
Endpoint: https://snapchef-server.onrender.com/analyze_fridge_image
Method: POST
Auth: X-App-API-Key header
Body: multipart/form-data
- image_file: JPEG data
- session_id: UUID
- dietary_restrictions: JSON array
- food_type: String
- difficulty_preference: String
- health_preference: String
- meal_type: String
- cooking_time_preference: String
- number_of_recipes: String
```

### 2. Gamification System

#### Components
- **ChallengeDatabase**: 365 pre-seeded challenges
- **GamificationManager**: Points, XP, and level tracking
- **ChefCoinsManager**: Virtual currency system
- **LeaderboardManager**: Global and regional rankings

#### Challenge Types
- Daily challenges (24-hour duration)
- Weekly challenges (7-day duration)
- Seasonal challenges (themed by time of year)
- Viral challenges (TikTok-inspired)
- Weekend specials (Friday-Sunday)

#### Reward System
- Points for completing challenges
- Chef Coins for premium features
- XP for leveling up
- Badges for achievements
- Multipliers for premium users (2x)

### 3. Social Sharing Infrastructure

#### Supported Platforms
1. **TikTok**
   - Direct SDK integration with PHAsset
   - Fallback to URL schemes
   - Video generation with templates
   - Clipboard caption support

2. **Instagram**
   - Stories and feed posts
   - Image generation with templates
   - Deep linking to library

3. **Twitter/X**
   - Tweet composition
   - Character counting
   - Image attachments

4. **Messages/SMS**
   - MFMessageComposeViewController
   - Rich message cards
   - Animated previews

#### ShareService Architecture
```swift
ShareService (singleton)
├── Platform detection
├── Content formatting
├── Deep link generation
└── Fallback strategies
```

### 4. CloudKit Integration

#### Data Models
- **User profiles** with social stats
- **Recipes** with photos and metadata
- **Challenges** with progress tracking
- **Achievements** and badges
- **Leaderboards** with rankings
- **Activities** for social feed

#### Sync Strategy
- Real-time sync for critical data
- Background sync every 5 minutes
- Pull-to-refresh for manual updates
- Conflict resolution with timestamps

### 5. Authentication System

#### Providers
- Sign in with Apple (primary)
- Google Sign-In
- Facebook Login

#### Flow
1. User triggers auth-required feature
2. CloudKitAuthView presents options
3. Authentication with provider
4. Username setup for new users
5. Profile creation in CloudKit

## State Management

### Global State (AppState)
```swift
- isFirstLaunch: Bool
- currentSessionID: String?
- recentRecipes: [Recipe]
- selectedRecipe: Recipe?
- foodPreferences: FoodPreferences
- currentChef: ChefPersonality
```

### Authentication State (AuthenticationManager)
```swift
- isAuthenticated: Bool
- currentUser: User?
- showUsernameSetup: Bool
- authProvider: AuthProvider?
```

### Device State (DeviceManager)
```swift
- deviceID: String
- hasUnlimitedAccess: Bool
- freeUsesRemaining: Int
- subscriptionStatus: SubscriptionStatus
```

### Gamification State (GamificationManager)
```swift
- currentPoints: Int
- currentLevel: Int
- currentXP: Int
- joinedChallenges: [Challenge]
- achievements: [Achievement]
```

## Data Models

### Recipe
```swift
struct Recipe {
    id: String
    name: String
    description: String
    difficulty: DifficultyLevel
    cookTime: Int
    servings: Int
    ingredients: [Ingredient]
    instructions: [String]
    nutrition: NutritionInfo
    dietaryInfo: [String]
    cuisine: String?
    mealType: MealType?
    imageURL: String?
    tags: [String]
}
```

### Challenge
```swift
struct Challenge {
    id: String
    title: String
    description: String
    type: ChallengeType
    difficulty: DifficultyLevel
    points: Int
    coins: Int
    startDate: Date
    endDate: Date
    requirements: [String]
    currentProgress: Int
    targetProgress: Int
    participants: Int
}
```

### User
```swift
struct User {
    id: String
    username: String?
    displayName: String?
    email: String?
    profileImageURL: String?
    recipesCreated: Int
    recipesShared: Int
    favoriteCount: Int
    followerCount: Int
    followingCount: Int
    challengesCompleted: Int
    totalPoints: Int
    currentStreak: Int
}
```

## UI/UX Components

### Custom Components
- **MagicalBackground**: Animated gradient background
- **GlassmorphicCard**: Frosted glass effect cards
- **MagneticButton**: Interactive button with haptics
- **MorphingTabBar**: Custom animated tab bar
- **ParticleExplosion**: Celebration animations
- **FloatingActionButton**: Material Design FAB
- **EnhancedRecipeCard**: Rich recipe display
- **BrandedSharePopup**: Unified share interface

### Animation System
- Spring animations for natural motion
- Particle effects for celebrations
- Falling food emoji system
- Shake effects for attention
- Pulse animations for highlights
- Transition animations between views

## Security & Privacy

### API Security
- API keys stored in iOS Keychain
- Header-based authentication
- Session tracking with UUIDs
- Secure HTTPS communication

### User Privacy
- CloudKit private database for user data
- Permission-based camera/photo access
- Optional authentication (not required)
- No tracking without consent

### Data Protection
- Image compression before upload
- Secure credential storage
- URL scheme validation
- Input sanitization

## Performance Optimizations

### Image Handling
- Resize to max 2048px before upload
- 80% JPEG compression
- Lazy loading in lists
- Memory-efficient processing

### Network Optimization
- 2-minute timeout for API calls
- Retry mechanisms for failures
- Background processing
- Efficient CloudKit queries

### UI Performance
- Smooth 60fps animations
- Efficient state updates
- Background task handling
- Memory management

## Current Status (January 2025)

### Completed Features ✅
- Core recipe generation from photos
- AI integration with Grok Vision API
- Comprehensive gamification system
- Multi-platform social sharing
- CloudKit data synchronization
- Authentication with multiple providers
- TikTok SDK direct integration
- Rich animations and UI polish
- Challenge system with 365 templates
- Virtual currency (Chef Coins)
- Leaderboards and achievements
- User profiles with social features

### Known Issues 🔧
- Some large files need modularization
- Test coverage needs improvement
- Accessibility features incomplete
- Documentation needs updates

### In Development 🚧
- Push notifications for challenges
- Advanced recipe filtering
- Meal planning features
- Shopping list generation
- Recipe collections/cookbooks

## Development Guidelines

### Code Standards
- Swift 6 with strict concurrency
- SwiftUI for all UI components
- MVVM architecture pattern
- Environment object dependency injection
- Async/await for asynchronous code
- Proper error handling throughout

### Best Practices
- Use `@MainActor` for UI updates
- Implement `[weak self]` in closures
- Follow Apple's Human Interface Guidelines
- Optimize images before network calls
- Handle all error cases gracefully
- Provide user feedback for all actions

### Testing Strategy
- Unit tests for business logic
- Integration tests for API calls
- UI tests for critical flows
- Performance testing for animations
- CloudKit sync testing

## Future Roadmap

### Phase 1 (Q1 2025)
- Complete test coverage
- Accessibility improvements
- Performance monitoring
- Bug fixes and polish

### Phase 2 (Q2 2025)
- Meal planning features
- Shopping list generation
- Advanced filtering/search
- Recipe collections

### Phase 3 (Q3 2025)
- AI recipe improvements
- Nutritionist integration
- Community features
- Video recipes

### Phase 4 (Q4 2025)
- International expansion
- Multi-language support
- Partner integrations
- Premium tier enhancements

## Repository Structure

```
ios/
├── SnapChef/
│   ├── App/
│   │   ├── SnapChefApp.swift (entry point)
│   │   ├── ContentView.swift (navigation)
│   │   └── AppDelegate.swift (UIKit bridge)
│   ├── Core/
│   │   ├── Models/ (data structures)
│   │   ├── ViewModels/ (business logic)
│   │   ├── Services/ (CloudKit, API)
│   │   ├── Networking/ (API managers)
│   │   └── Utilities/ (helpers)
│   ├── Features/
│   │   ├── Camera/ (photo capture)
│   │   ├── Recipes/ (recipe views)
│   │   ├── Gamification/ (challenges)
│   │   ├── Sharing/ (social features)
│   │   └── Authentication/ (login)
│   ├── Design/
│   │   ├── Components/ (reusable UI)
│   │   ├── Animations/ (effects)
│   │   └── Styles/ (themes)
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
├── SnapChef.xcodeproj
└── Documentation/
    ├── APP_BLUEPRINT_2025.md (this file)
    ├── CLAUDE.md (AI assistant guide)
    └── CHANGELOG.md (version history)
```

## Conclusion

SnapChef represents a modern, well-architected iOS application that successfully combines AI technology, gamification, and social features into an engaging cooking companion app. The codebase demonstrates professional development practices with a clear path for future growth and feature expansion.

The app is production-ready with comprehensive features, robust error handling, and a polished user experience. The architecture supports scalability, and the modular design allows for easy feature additions and maintenance.

**Key Success Factors:**
- Modern SwiftUI architecture
- Comprehensive feature set
- Engaging gamification system
- Robust social sharing
- Professional code quality
- Clear growth potential

This blueprint serves as the authoritative reference for understanding SnapChef's current implementation and future direction.