# SnapChef iOS App

SnapChef is a magical iOS app that transforms photos of your fridge and pantry into personalized recipe suggestions using AI. With its whimsical design, gamification elements, and social sharing features, SnapChef makes cooking fun and accessible.

## 📱 App Overview

- **Bundle ID**: com.snapchef.app
- **Minimum iOS Version**: iOS 15.0+
- **Supported Devices**: iPhone (Portrait only), iPad (All orientations)
- **Architecture**: SwiftUI + MVVM
- **Backend**: FastAPI server with Grok Vision API integration

## 🏗️ Project Structure

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
│   │   ├── CameraTabView.swift        # Camera tab container
│   │   ├── CameraView.swift           # Main camera interface
│   │   ├── CapturedImageView.swift    # Photo preview
│   │   ├── EmojiFlickGame.swift       # Mini-game while loading
│   │   └── PhysicsLoadingOverlay.swift # Physics-based loader
│   ├── Gamification/
│   │   ├── ChallengeDetailView.swift   # Challenge details
│   │   └── GamificationManager.swift   # Points & achievements
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

### 2. **Magical UI/UX**
- Animated gradient backgrounds
- Glassmorphic design elements
- Physics-based animations and transitions
- Morphing tab bar with fluid animations
- Particle effects and whimsical interactions

### 3. **Gamification System**
- Points for scanning ingredients
- Achievements and badges
- Daily/weekly challenges
- Leaderboard (coming soon)
- Streak tracking

### 4. **AI Chef Personalities**
- 8 unique chef personas (Gordon, Julia, Salt Master, etc.)
- Each with unique voice styles and catchphrases
- Unlockable through achievements
- Personalized recipe commentary

### 5. **Social Sharing**
- Instagram story templates
- TikTok integration
- Twitter/X sharing
- Custom recipe cards with branding
- Print-friendly layouts

### 6. **User Features**
- Profile management
- Dietary restrictions settings
- Recipe history
- Favorites system
- Offline recipe access

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
    ├── CameraTabView (Tab 1)
    │   ├── CameraView
    │   ├── CapturedImageView
    │   ├── EmojiFlickGame (loading)
    │   └── RecipeResultsView
    ├── RecipesView (Tab 2)
    │   └── RecipeDetailView
    └── ProfileView (Tab 3)
        ├── FoodPreferencesView
        └── SubscriptionView (modal)
```

## 🔌 API Integration

### Server Details
- **Base URL**: https://snapchef-server.onrender.com
- **Authentication**: X-App-API-Key header
- **Main Endpoint**: `/analyze_fridge_image`

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
# Clone the repository
git clone https://github.com/cameronsaddress/snapchef.git

# Navigate to iOS directory
cd snapchef/ios

# Open in Xcode
open SnapChef.xcodeproj

# Build and run (Cmd+R)
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

## 👥 Contributing

See the main repository README for contribution guidelines.

## 📄 License

Copyright © 2024 SnapChef. All rights reserved.