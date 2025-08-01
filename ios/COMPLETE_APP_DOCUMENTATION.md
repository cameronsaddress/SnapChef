# SnapChef Complete App Documentation
*Last Updated: February 1, 2025*

## 📱 App Overview

SnapChef is an AI-powered iOS app that transforms photos of fridges and pantries into personalized recipes using advanced vision AI. The app features gamification, social sharing, and comprehensive CloudKit integration.

## 🏗 Architecture

### Core Technologies
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Minimum iOS**: 16.0
- **Backend**: CloudKit (Apple iCloud)
- **AI Service**: Grok Vision API (via FastAPI server)
- **Storage**: CloudKit + Core Data (local cache)

### Project Structure
```
SnapChef/
├── App/
│   ├── SnapChefApp.swift          # App entry point, CloudKit initialization
│   ├── ContentView.swift          # Main tab navigation
│   └── LaunchAnimationView.swift  # Splash screen animation
├── Core/
│   ├── Models/
│   │   ├── Recipe.swift           # Recipe data model
│   │   ├── Ingredient.swift       # Ingredient model
│   │   ├── CloudKitRecipe.swift   # CloudKit recipe wrapper
│   │   └── User.swift             # User profile model
│   ├── Services/
│   │   ├── CloudKitManager.swift  # Main CloudKit service
│   │   ├── CloudKitDataManager.swift     # Analytics & tracking
│   │   ├── CloudKitRecipeManager.swift   # Recipe sync (single instance)
│   │   ├── CloudKitChallengeManager.swift # Challenge & team sync
│   │   ├── CloudKitAuthManager.swift     # Authentication
│   │   ├── CloudKitSyncService.swift     # Multi-device sync
│   │   └── ChallengeDatabase.swift       # 365-day challenge database
│   ├── Networking/
│   │   └── SnapChefAPIManager.swift # Grok API integration
│   └── ViewModels/
│       ├── AppState.swift         # Global app state
│       └── DeviceManager.swift    # Device & subscription management
├── Features/
│   ├── Camera/
│   │   ├── CameraView.swift       # Main camera interface
│   │   ├── CameraModel.swift      # AVFoundation wrapper
│   │   └── CameraPreview.swift    # Camera preview layer
│   ├── Recipes/
│   │   ├── RecipeResultsView.swift     # Recipe display cards
│   │   ├── RecipeDetailView.swift      # Full recipe view
│   │   └── SavedRecipesView.swift      # User's saved recipes
│   ├── Gamification/
│   │   ├── GamificationManager.swift   # Points, badges, levels
│   │   ├── ChallengeGenerator.swift    # Dynamic challenge creation
│   │   ├── ChallengeProgressTracker.swift # Progress monitoring
│   │   ├── ChefCoinsManager.swift      # Virtual currency
│   │   ├── TeamChallengeManager.swift  # Team features
│   │   └── Views/
│   │       ├── ChallengeHubView.swift  # Challenge dashboard
│   │       ├── LeaderboardView.swift   # Rankings
│   │       └── AchievementGalleryView.swift # Badges
│   ├── Sharing/
│   │   ├── ShareGeneratorView.swift    # Social media cards
│   │   └── ActivityFeedView.swift      # Social timeline
│   ├── Profile/
│   │   └── ProfileView.swift           # User profile & settings
│   └── Subscription/
│       └── SubscriptionView.swift      # Premium upgrade
└── HomeView.swift                      # Main dashboard

```

## 🔄 Data Flow

### Recipe Generation Flow
1. **Photo Capture** → CameraView captures/selects image
2. **API Request** → SnapChefAPIManager sends to Grok Vision API
3. **Processing** → Server analyzes image, generates recipes
4. **Response** → Recipes returned in RecipeAPI format
5. **Conversion** → Convert to app Recipe model
6. **CloudKit Save** → CloudKitRecipeManager stores (single instance)
7. **Display** → RecipeResultsView shows results
8. **User Action** → Save/share/cook recipe

### CloudKit Integration
- **Public Database**: Recipes, challenges, teams, leaderboards
- **Private Database**: User profiles, saved recipes, progress
- **Sync Strategy**: Real-time for critical, batch for analytics

## 🎮 Gamification System

### Current Features
- **Points System**: XP for actions (create, share, complete)
- **Levels**: Progressive advancement (level * 1000 XP)
- **Chef Coins**: Virtual currency for purchases
- **Badges**: Achievement system with rarity tiers
- **Challenges**: 365-day rotating challenge system
  - Daily challenges (24-hour duration)
  - Weekly challenges (72-hour duration)
  - Special events (holidays, seasons)
  - Viral TikTok-style challenges
- **Teams**: Create/join teams for group challenges
- **Leaderboards**: Global, regional, friends
- **Streak System**: 5 different streak types with rewards
  - Daily Snap (take photo)
  - Recipe Creation (generate recipe)
  - Challenge Completion (complete any challenge)
  - Social Share (share recipe)
  - Healthy Eating (recipes under 500 calories)

### Streak System (NEW - Feb 2025)
- **5 Streak Types**: Each with independent tracking
- **Milestone Rewards**: 3, 7, 14, 30, 50, 100, 365 days
- **Protection Systems**:
  - Freezes: Pause streak for 24 hours (1 free/month)
  - Insurance: Auto-restore if broken (200 coins, 7 days)
- **Power-Ups**: 5 types (Double Day, Shield, Time Machine, etc.)
- **Multipliers**: Up to 3x based on active streaks
- **Team Streaks**: Group streak challenges
- **CloudKit Sync**: Cross-device persistence

### Challenge Database
- **Total Challenges**: 365 unique challenges
- **Timing**: Staggered start times (0-33 hour offsets)
- **Duration by Difficulty**:
  - Easy: 24 hours
  - Medium: 48 hours
  - Hard: 72 hours
  - Expert: 7 days
  - Master: 14 days
- **Countdown Display**: HH:MM:SS format
- **Join Mechanism**: Opt-in (not auto-joined)

## 📡 API Integration

### Grok Vision API
**Endpoint**: `https://snapchef-server.onrender.com/analyze_fridge_image`

**Request Format**:
```json
{
  "image_file": "base64_jpeg",
  "session_id": "uuid",
  "dietary_restrictions": ["vegetarian"],
  "food_type": "Italian",
  "difficulty_preference": "easy",
  "number_of_recipes": 5
}
```

**Response Format**:
```json
{
  "data": {
    "ingredients": [...],
    "recipes": [
      {
        "id": "uuid",
        "name": "Recipe Name",
        "description": "...",
        "instructions": [...],
        "nutrition": {...}
      }
    ]
  }
}
```

## ☁️ CloudKit Schema

### Record Types (34 total - Updated Feb 2025)
1. **User** - User profiles and stats
2. **Recipe** - Recipe data (single instance)
3. **Challenge** - Challenge definitions
4. **UserChallenge** - User progress in challenges
5. **Team** - Team information
6. **TeamMessage** - Team chat
7. **Leaderboard** - Rankings
8. **Achievement** - Earned badges
9. **CoinTransaction** - Currency ledger
10. **Follow** - Social connections
11. **RecipeLike** - Recipe engagement
12. **RecipeView** - View analytics
13. **RecipeComment** - User comments
14. **Activity** - Activity feed
15. **UserPreferences** - Settings
16. **AnalyticsEvent** - Event tracking
17. **RecipeRating** - User ratings
18. **SocialShare** - Share tracking
19. **CameraSession** - Photo sessions
20. **RecipeGeneration** - AI generation logs
21. **AppSession** - App usage
22. **FeatureUsage** - Feature analytics
23. **ErrorLog** - Error tracking
24. **FoodPreference** - Dietary preferences
25. **SearchHistory** - Search logs
26. **NotificationPreference** - Push settings
27. **DeviceSync** - Multi-device sync
28. **UserStreak** - Individual streak tracking (NEW)
29. **StreakHistory** - Past streak records (NEW)
30. **StreakAchievement** - Milestone rewards (NEW)
31. **StreakFreeze** - Freeze records (NEW)
32. **TeamStreak** - Group streaks (NEW)
33. **StreakPowerUp** - Active power-ups (NEW)
34. **StreakLeaderboard** - Streak rankings (NEW)

## 🎨 UI Components

### Custom Views
- **MagicalBackground** - Animated gradient background
- **GlassmorphicCard** - Frosted glass effect cards
- **MagneticButton** - Interactive 3D buttons
- **ParticleExplosion** - Celebration animations
- **FloatingActionButton** - Material Design FAB
- **EnhancedChallengeCard** - Challenge display with countdown
- **SnapchefLogo** - Animated app logo

### Navigation
- **Tab-based**: Home, Recipes, Camera, Challenges, Profile
- **Modal presentations**: Camera, share, subscription
- **Navigation stacks**: Within each tab

## 🔐 Security & Privacy

### Data Protection
- **API Key**: Stored in iOS Keychain
- **User Data**: CloudKit handles authentication
- **Photos**: Not stored in CloudKit (pending moderation)
- **Sensitive Info**: Private CloudKit database

### Permissions
- **Camera**: For food photos
- **Photo Library**: For selecting images
- **Notifications**: For challenges/reminders
- **CloudKit**: For sync/storage

## 📱 Device Support

### Requirements
- **iOS Version**: 16.0+
- **Devices**: iPhone only
- **Orientation**: Portrait only
- **Storage**: ~100MB app + cache
- **Network**: Required for AI features

### Performance
- **Target FPS**: 60fps animations
- **Image Size**: Max 10MB upload
- **Compression**: 80% JPEG quality
- **Timeout**: 30s API calls

## 🚀 Key Features

### Free Tier
- 5 recipes per day
- Basic challenges
- Standard badges
- Public leaderboards
- Single device

### Premium ($4.99/month)
- Unlimited recipes
- Premium challenges
- Exclusive badges
- 2x coin rewards
- Multi-device sync
- Streak insurance
- Priority support

## 🔄 Update Frequency

### Real-time Updates
- Challenge countdowns (every second)
- Active challenge list (every minute)
- Leaderboards (on change)
- Team updates (instant)

### Batch Updates
- Analytics (5 minutes)
- User stats (on action)
- CloudKit sync (automatic)

## 🐛 Known Limitations

1. **Photos not stored** - Awaiting moderation implementation
2. **Offline mode** - Limited functionality
3. **iPad support** - Not yet implemented
4. **Landscape mode** - Not supported
5. **Share links** - Deep linking pending

## 📊 Analytics Tracking

### Events Tracked
- Screen views
- Recipe generation
- Challenge participation
- Social interactions
- Error occurrences
- Feature usage
- Session duration

### Metrics
- Daily active users
- Recipes per user
- Challenge completion rate
- Retention rate
- Premium conversion
- Social shares

## 🔧 Development Setup

### Prerequisites
- Xcode 15.0+
- iOS 16.0+ Simulator
- CloudKit container configured
- Grok API key

### Build Commands
```bash
# Build
xcodebuild -project SnapChef.xcodeproj -scheme SnapChef -configuration Debug

# Test
xcodebuild test -project SnapChef.xcodeproj -scheme SnapChef

# Clean
xcodebuild clean -project SnapChef.xcodeproj -scheme SnapChef
```

## 📝 Recent Updates

### February 1, 2025
- Implemented 365-day challenge database
- Fixed countdown timers (HH:MM:SS format)
- Made challenges opt-in
- Removed cultural/political content
- Added CloudKit managers for all features
- Staggered challenge start times

## 🎯 Upcoming Features

### Planned
- Streak system (detailed plan created)
- Recipe sharing via deep links
- Photo moderation
- iPad support
- Offline mode enhancements
- Push notifications
- CloudKit subscriptions
- Social features expansion

---

*This documentation reflects the current production state of SnapChef iOS app.*