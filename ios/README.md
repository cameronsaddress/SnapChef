# SnapChef iOS App

SnapChef is a magical iOS app that transforms photos of your fridge and pantry into personalized recipe suggestions using AI. With its whimsical design, gamification elements, and social sharing features, SnapChef makes cooking fun and accessible.

## 🚀 Latest Updates (January 14, 2025)

### Major Codebase Cleanup
- ✅ **17% Code Reduction**: Removed ~2,600 lines of unused/deprecated code
- ✅ **Team Features Removed**: All team challenge functionality eliminated
- ✅ **Files Deleted**: 6 unused files (old backups, fake data services, unused views)
- ✅ **Cleaner Architecture**: 83% of codebase actively used, improved maintainability

### Current Features
- ✅ **Share Functionality**: Branded share popup with platform-specific views
  - TikTok video generator with viral templates
  - Before/After reveals with beat-synced animations
  - Direct export to all major social platforms
- ✅ **CloudKit Sync**: Complete bidirectional sync for recipes and challenges
- ✅ **Social Features**: Real-time follower/following counts
- ✅ **Challenge System**: 365 days of embedded challenges
- ✅ **Premium TikTok Videos**: Beat-synced animations, Ken Burns effects, particle overlays
- ✅ **Swift 6 Compliant**: Full concurrency safety with actor isolation

## 📚 Documentation

### Core Documentation
- **[APP_ARCHITECTURE_DOCUMENTATION.md](APP_ARCHITECTURE_DOCUMENTATION.md)** - Complete system architecture and data flow
- **[COMPONENT_REFERENCE.md](COMPONENT_REFERENCE.md)** - Detailed component documentation
- **[CLAUDE.md](CLAUDE.md)** - AI assistant guidance and recent updates

### Development Guides
- **[AI_DEVELOPER_GUIDE.md](AI_DEVELOPER_GUIDE.md)** - Comprehensive guide for AI assistants
- **[COMPLETE_CODE_TRACE.md](COMPLETE_CODE_TRACE.md)** - Full app flow analysis
- **[FILE_USAGE_ANALYSIS.md](FILE_USAGE_ANALYSIS.md)** - Active/unused file audit
- **[DEVELOPER_QUICK_REFERENCE.md](DEVELOPER_QUICK_REFERENCE.md)** - Quick commands and tips

### Implementation Details
- **[CHALLENGE_SYSTEM_ORCHESTRATION.md](CHALLENGE_SYSTEM_ORCHESTRATION.md)** - Challenge system design
- **[CHALLENGE_SYSTEM_SUMMARY.md](CHALLENGE_SYSTEM_SUMMARY.md)** - Implementation summary
- **[WORKSPACE_STRUCTURE.md](WORKSPACE_STRUCTURE.md)** - Multi-repository workflow

### Cleanup & Audit Reports
- **[APP_AUDIT_REPORT.md](APP_AUDIT_REPORT.md)** - Comprehensive codebase audit (Jan 2025)
- **[CLEANUP_SUMMARY.md](CLEANUP_SUMMARY.md)** - Cleanup actions and results

## 📱 App Overview

- **Bundle ID**: com.snapchef.app
- **Minimum iOS Version**: iOS 15.0+
- **Supported Devices**: iPhone (Portrait only), iPad (All orientations)
- **Architecture**: SwiftUI + MVVM
- **Backend**: FastAPI server with Grok Vision API integration

## 🏗️ Multi-Repository Structure

SnapChef is split into two repositories:
- **iOS App**: https://github.com/cameronsaddress/snapchef (this repo)
- **FastAPI Server**: https://github.com/cameronsaddress/snapchef-server

See [WORKSPACE_STRUCTURE.md](WORKSPACE_STRUCTURE.md) for detailed multi-repo workflow.

## 📱 iOS Project Structure

```
SnapChef/
├── App/
│   ├── SnapChefApp.swift         # Main app entry point
│   ├── ContentView.swift         # Root view with navigation
│   └── LaunchAnimationView.swift # Animated launch screen
├── Core/
│   ├── Models/
│   │   ├── Recipe.swift          # Recipe data model
│   │   ├── SavedRecipe.swift    # Saved recipe model
│   │   └── User.swift           # User profile model
│   ├── Networking/
│   │   ├── NetworkManager.swift  # Generic networking layer
│   │   └── SnapChefAPIManager.swift # API integration
│   ├── Services/
│   │   ├── AnalyticsManager.swift    # Analytics tracking
│   │   ├── AuthenticationManager.swift # Auth & user management
│   │   └── DeviceManager.swift       # Device fingerprinting
│   ├── Utilities/
│   │   ├── HapticManager.swift      # Haptic feedback
│   │   ├── KeychainManager.swift    # Secure storage
│   │   └── MockDataProvider.swift   # Mock data for testing
│   └── ViewModels/
│       └── AppState.swift           # Global app state
├── Design/
│   ├── Assets.xcassets             # Image and color assets
│   ├── ColorExtensions.swift       # Color utilities
│   ├── GlassmorphicComponents.swift # Glass-style UI components
│   ├── MagicalBackground.swift     # Animated backgrounds
│   ├── MagicalTransitions.swift    # Custom transitions
│   └── MorphingTabBar.swift        # Animated tab bar
├── Features/
│   ├── AIPersonality/
│   │   ├── AIPersonalityManager.swift  # AI chef personas
│   │   ├── LocalRecipeDatabase.swift   # Offline recipes
│   │   └── MysteryMealView.swift       # Mystery meal feature
│   ├── Authentication/
│   │   ├── OnboardingView.swift        # First-launch flow
│   │   └── SubscriptionView.swift      # Premium features
│   ├── Camera/
│   │   ├── CameraModel.swift          # AVFoundation wrapper
│   │   ├── CameraView.swift           # Main camera interface
│   │   ├── CapturedImageView.swift    # Photo preview
│   │   ├── EmojiFlickGame.swift       # Mini-game while loading
│   │   └── PhysicsLoadingOverlay.swift # Physics-based loader
│   ├── Gamification/
│   │   ├── GamificationManager.swift      # Central game state
│   │   ├── ChallengeGenerator.swift       # Dynamic challenge creation
│   │   ├── ChallengeProgressTracker.swift # Real-time tracking
│   │   ├── ChallengeService.swift         # Core Data persistence
│   │   ├── ChefCoinsManager.swift         # Virtual currency
│   │   ├── RewardSystem.swift             # Reward distribution
│   │   └── Views/
│   │       ├── ChallengeHubView.swift     # Main challenge UI
│   │       ├── ChallengeCardView.swift    # Challenge cards
│   │       ├── LeaderboardView.swift      # Rankings
│   │       ├── AchievementGalleryView.swift # Badge display
│   │       └── DailyCheckInView.swift     # Streak maintenance
│   ├── Profile/
│   │   ├── ProfileView.swift          # User profile
│   │   └── FoodPreferencesView.swift  # Dietary preferences
│   ├── Recipes/
│   │   ├── RecipesView.swift          # Recipe list
│   │   ├── RecipeDetailView.swift     # Recipe details
│   │   └── RecipeResultsView.swift    # AI results display
│   └── Sharing/
│       ├── ShareGeneratorView.swift    # Share image creator
│       ├── ShareSheet.swift           # Native share sheet
│       ├── SocialShareManager.swift   # Social integrations
│       └── PrintView.swift            # Print recipes
└── HomeView.swift                     # Home screen
```

## 🎯 Key Features

### 1. **AI-Powered Recipe Generation**
- Takes photos of fridge/pantry contents
- Sends to backend API with Grok Vision integration
- Returns personalized recipes based on available ingredients
- Supports dietary restrictions and preferences
- Smart tagging system for recipe categorization

### 2. **Magical UI/UX**
- Animated gradient backgrounds
- Glassmorphic design elements
- Physics-based animations and transitions
- Morphing tab bar with fluid animations
- Particle effects and whimsical interactions

### 3. **Complete Challenge System** ⭐ NEW
- **Daily Challenges**: 24-hour recipe creation goals
- **Weekly Challenges**: Extended cooking achievements
- **Special Events**: Holiday and seasonal challenges
- **Community Goals**: Collaborative global challenges
- **Real-time Progress**: Live tracking of challenge completion
- **Leaderboards**: Weekly and all-time rankings
- **Streak System**: Daily check-in with rewards

### 4. **Gamification & Rewards**
- **Chef Coins**: Virtual currency for unlockables
- **XP System**: Level progression (1-50)
- **Badges**: 30+ unique achievements
- **Daily Check-in**: Maintain streaks for bonuses
- **Premium Rewards**: 2x multiplier for subscribers
- **Unlockable Themes**: Earn new UI themes
- **Titles**: Special designations for achievements

### 5. **AI Chef Personalities**
- 8 unique chef personas (Gordon, Julia, Salt Master, etc.)
- Each with unique voice styles and catchphrases
- Unlockable through achievements
- Personalized recipe commentary

### 6. **Social Sharing**
- Instagram story templates
- TikTok integration
- Twitter/X sharing
- Custom recipe cards with branding
- Print-friendly layouts
- Share for credits system
- Challenge completion sharing

### 7. **User Features**
- Profile management
- Dietary restrictions settings
- Recipe history with photos
- Favorites system
- Offline recipe access
- Achievement gallery
- Personal statistics dashboard

## 🧭 Navigation Flow

```
LaunchAnimation
    ↓
ContentView
    ↓
[First Launch] → OnboardingView
    ↓
MainTabView
    ├── HomeView (Tab 0)
    │   ├── CameraView (modal)
    │   └── MysteryMealView (modal)
    ├── CameraView (Tab 1)
    │   ├── CapturedImageView
    │   ├── EmojiFlickGame (loading)
    │   └── RecipeResultsView
    ├── RecipesView (Tab 2)
    │   └── RecipeDetailView
    ├── ChallengeHubView (Tab 3)
    │   └── ChallengeDetailView
    └── ProfileView (Tab 4)
        ├── FoodPreferencesView
        └── SubscriptionView (modal)
```

## 🔌 API Integration

### Server Details
- **Base URL**: https://snapchef-server.onrender.com
- **Authentication**: X-App-API-Key header
- **Main Endpoint**: `/analyze_fridge_image`
- **Server Repository**: https://github.com/cameronsaddress/snapchef-server

### Request Format
```swift
POST /analyze_fridge_image
Content-Type: multipart/form-data

Required:
- image_file: JPEG image data
- session_id: UUID string

Optional:
- dietary_restrictions: JSON array
- food_type: String
- difficulty_preference: String
- health_preference: String
- meal_type: String
- cooking_time_preference: String
- number_of_recipes: String
```

### Response Format
```swift
{
  "data": {
    "image_analysis": {...},
    "ingredients": [...],
    "recipes": [
      {
        "id": "uuid",
        "name": "Recipe Name",
        "description": "...",
        "difficulty": "easy|medium|hard",
        "instructions": ["step1", "step2"],
        "nutrition": {...}
      }
    ]
  },
  "message": "Success"
}
```

## 🎨 Design System

### Colors
- **Primary Gradient**: #4facfe → #00f2fe (Magical Aurora)
- **Secondary**: #667eea → #764ba2 (Purple Dream)
- **Background**: Dark with animated gradients
- **Glass Effect**: White @ 10-20% opacity

### Typography
- **Headlines**: SF Pro Display Bold
- **Body**: SF Pro Text Regular
- **UI Elements**: SF Pro Rounded Medium

### Animations
- Spring animations for interactions
- Particle effects for achievements
- Morphing shapes for tab transitions
- Parallax effects on scroll
- Magnetic button behaviors

## 🔐 Security

- API key stored in iOS Keychain
- Device fingerprinting for user tracking
- No sensitive data in UserDefaults
- HTTPS only for API communication
- Photo data compressed before upload

## 🛠️ Development

### Requirements
- Xcode 15.0+
- iOS 15.0+ deployment target
- Swift 5.9+

### Build & Run
```bash
# Clone the iOS repository
git clone https://github.com/cameronsaddress/snapchef.git

# Navigate to iOS directory
cd snapchef/ios

# Open in Xcode
open SnapChef.xcodeproj

# Build and run (Cmd+R)
```

### Working with Server Code
```bash
# Clone the server repository (separate)
git clone https://github.com/cameronsaddress/snapchef-server.git

# See server repository README for setup instructions
```

### Environment Variables
The app uses `CLAUDE.md` for API configuration. Update the API key in KeychainManager if needed.

## 📱 Permissions

The app requests:
- **Camera**: For taking photos of ingredients
- **Photo Library**: For saving recipe images

## 🚀 Future Features

- Recipe video tutorials
- Meal planning calendar
- Shopping list generation
- Barcode scanning
- Voice commands
- AR ingredient recognition
- Community recipe sharing

## 🔄 Recent Updates (January 31, 2025)

### ⭐ Challenge System Implementation (COMPLETED)
- **Phase 1**: Database foundation with Core Data and CloudKit sync
- **Phase 2**: Complete UI with Challenge Hub, cards, and leaderboards  
- **Phase 3**: Full integration with recipe creation and social features
- **Multi-Agent Development**: Orchestrated using AI agents for parallel development

### Challenge System Features
- **20+ New Components**: Complete gamification overhaul
- **Real-time Tracking**: Live progress updates for all challenges
- **Core Data Integration**: Persistent storage with CloudKit sync
- **Premium Features**: 2x rewards for subscribers
- **Social Integration**: Share challenge completions
- **Analytics**: Comprehensive engagement tracking

### Build Status
- ✅ **All compilation errors fixed**
- ✅ **Challenge system fully integrated**
- ✅ **Recipe model updated** (added tags and dietaryInfo)
- ⚠️ **Minor warnings remain** (unused variables, Core Data resources)

### UI/UX Improvements
- **Emoji Flick Game**: Enhanced visibility with 25% less transparent background
- **Recipe Results**: Cleaner layout with better text positioning
- **Share Generator**: Simplified workflow with one-click photo capture
- **Performance**: Optimized animations for smoother 60fps experience
- **AI Processing View**: Moved scanning circle to top with larger text

### Documentation & Structure
- Added comprehensive architecture documentation
- Created detailed component reference guide
- Updated developer quick reference
- Enhanced inline code comments
- **NEW**: Separated server code into dedicated repository
- **NEW**: Added multi-repository workspace documentation
- **NEW**: Complete challenge system documentation

## 🐛 Known Issues & TODOs

### Build Warnings
1. **Core Data Resources**: Generated files appearing in Copy Bundle Resources
2. **Unused Variables**: `statusCode`, `transaction`, `feature` need cleanup

### Pending Tasks
1. **Subscription Testing**: Test subscription flow in iOS Simulator
2. **Receipt Validation**: Add server-side validation for production
3. **App Store Connect**: Complete pending agreements for IAP
4. **Localizations**: Add after App Store agreements are signed
5. **Core Data**: Fix model warnings in build settings

### Testing Required
- Challenge system end-to-end flow
- Gamification points calculation
- CloudKit sync functionality
- Premium subscription features
- Leaderboard updates

## 👥 Contributing

See the main repository README for contribution guidelines.

## 📄 License

Copyright © 2024-2025 SnapChef. All rights reserved.