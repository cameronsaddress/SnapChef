# SnapChef Component Reference Guide

## Table of Contents
1. [Camera Components](#camera-components)
2. [Recipe Components](#recipe-components)
3. [Sharing Components](#sharing-components)
4. [Gamification Components](#gamification-components)
5. [Design System Components](#design-system-components)
6. [Navigation Components](#navigation-components)
7. [Utility Components](#utility-components)

## Camera Components

### CameraView
**Location**: `Features/Camera/CameraView.swift`
**Purpose**: Main camera interface for capturing ingredient photos

**Key Properties**:
```swift
@StateObject private var cameraModel = CameraModel()
@State private var isProcessing = false
@State private var capturedImage: UIImage?
@State private var showingResults = false
```

**Features**:
- Real-time camera preview
- Capture button with animation
- Processing overlay with mini-game
- Flash control
- Test button for development

**Usage**:
```swift
CameraView()
    .environmentObject(appState)
    .environmentObject(deviceManager)
```

### EmojiFlickGame
**Location**: `Features/Camera/EmojiFlickGame.swift`
**Purpose**: Mini-game during AI processing

**Key Components**:
- `FlickableEmoji`: Individual emoji with physics
- `FallingIngredient`: Target ingredients to hit
- `GameState`: Score and time tracking

**Game Mechanics**:
- Flick emojis upward to hit falling ingredients
- Score points for successful hits
- 60-second game duration
- Background: Fridge image at 0.375 opacity

### PhysicsLoadingOverlay
**Location**: `Features/Camera/PhysicsLoadingOverlay.swift`
**Purpose**: Loading animation with physics-based effects

**Components**:
- `PhysicsFallingEmoji`: Falling food emojis
- `LetterBounds`: Collision detection for text
- `EmojiFlickGameOverlay`: Game integration

**Features**:
- Falling emojis bounce off "SNAPCHEF" text
- Progress bar (60 seconds)
- AI analyzing indicator
- Smooth transitions

## Recipe Components

### RecipeResultsView
**Location**: `Features/Recipes/RecipeResultsView.swift`
**Purpose**: Display AI-generated recipes

**Main Sections**:
1. **SuccessHeaderView**: "Recipe Magic Complete!" header
2. **FridgeInventoryCard**: Shows detected ingredients
3. **MagicalRecipeCard**: Individual recipe display
4. **ViralSharePrompt**: Encourage sharing

**Key Features**:
- Staggered fade-in animations
- Confetti celebration effect
- Sheet presentations for details
- Swipe gestures for navigation

### MagicalRecipeCard
**Location**: `Features/Recipes/RecipeResultsView.swift`
**Purpose**: Display individual recipe with actions

**Structure**:
```swift
VStack {
    Text(recipe.name)          // Title at top (2 lines max)
    HStack {
        RecipeImage()          // 100x100 gradient placeholder
        VStack {
            TimeIndicator()    // Cook time
            CalorieIndicator() // Calories (min width: 40)
            DifficultyBadge()  // Difficulty level
        }
    }
    Text(recipe.description)   // 2 lines max
    ActionButtons()            // Cook Now, Share
}
```

### RecipeDetailView
**Location**: `Features/Recipes/RecipeDetailView.swift`
**Purpose**: Full recipe with instructions

**Sections**:
- Hero image with gradient overlay
- Ingredients list with checkboxes
- Step-by-step instructions
- Nutrition information
- Chef tips and variations

## Sharing Components

### ShareGeneratorView
**Location**: `Features/Sharing/ShareGeneratorView.swift`
**Purpose**: Create social media share images

**Main Components**:
1. **SharePreviewSection**: Live preview of share image
2. **StyleSelectorView**: Choose visual theme
3. **ShareImageContent**: Actual shareable content
4. **Take Photo Button**: Capture "after" photo

**Recent Changes**:
- Animation: Single 15° rotation (not continuous)
- Clickable after photo area
- Removed challenge text editor
- "Share for Credits" below style selector

### ShareImageContent
**Location**: `Features/Sharing/ShareGeneratorView.swift`
**Purpose**: Rendered share image content

**Layout**:
```swift
ZStack {
    BackgroundGradient()      // Based on selected style
    VStack {
        "MY FRIDGE CHALLENGE" // Header
        BeforeAfterPhotos()   // Side-by-side comparison
        RecipeName()          // Large, bold text
        StatsRow()            // Time, calories, difficulty
        AppBranding()         // SnapChef + chef info
    }
}
```

**Styles**:
- Home Cook: Warm orange gradient
- Chef Mode: Professional dark theme
- Foodie Fun: Bold pink/blue
- Rustic Charm: Natural earth tones

## Gamification Components

### EnhancedGamificationManager
**Location**: `Features/Gamification/EnhancedGamificationManager.swift`
**Purpose**: Central gamification logic

**Core Systems**:
1. **Points**: Actions earn XP
2. **Levels**: 50 levels with scaling XP
3. **Badges**: 30+ achievements
4. **Quests**: Daily/weekly challenges
5. **Streaks**: Consecutive day bonuses

**Point Values**:
```swift
snapPhoto: 10
completeRecipe: 50
shareRecipe: 25
dailyStreak: 20
perfectWeek: 100
```

### GamificationCenterView
**Location**: `Features/Gamification/GamificationCenterView.swift`
**Purpose**: Hub for all gamification features

**Tabs**:
1. **Overview**: Level, XP, stats
2. **Badges**: Achievement gallery
3. **Quests**: Active challenges
4. **Leaderboard**: Global rankings

### BadgeCard
**Location**: `Features/Gamification/Views/BadgeCard.swift`
**Purpose**: Individual achievement display

**States**:
- Locked: Grayscale with lock icon
- Unlocked: Full color with glow
- Featured: 3D rotation animation

## Design System Components

### GlassmorphicCard
**Location**: `Design/GlassmorphicComponents.swift`
**Purpose**: Frosted glass effect container

**Usage**:
```swift
GlassmorphicCard(
    content: { 
        // Your content here
    },
    glowColor: Color(hex: "#667eea")
)
```

**Properties**:
- Background blur
- Border gradient
- Optional glow effect
- Custom corner radius

### MagneticButton
**Location**: `Design/GlassmorphicComponents.swift`
**Purpose**: Primary action button

**Features**:
- Magnetic hover effect
- Gradient background
- Icon + text layout
- Haptic feedback

### WhimsicalLoadingDots
**Location**: `Design/WhimsicalAnimations.swift`
**Purpose**: Playful loading indicator

**Animation**:
- 3 bouncing dots
- Staggered timing
- Color shifts
- Scale effects

### ParticleExplosion
**Location**: `Design/WhimsicalAnimations.swift`
**Purpose**: Celebration effects

**Types**:
- Confetti burst
- Star shower
- Heart explosion
- Custom shapes

## Navigation Components

### SocialMorphingTabBar
**Location**: `Design/SocialMorphingTabBar.swift`
**Purpose**: Custom animated tab bar

**Features**:
- Morphing background
- Icon animations
- Haptic feedback
- Accessibility support

### FloatingActionButton
**Location**: `Design/InteractiveElements.swift`
**Purpose**: Quick action triggers

**Variants**:
- Camera capture
- Recipe browse
- Share creation
- Help/support

## Utility Components

### AIAnalyzingIndicator
**Location**: `Features/Camera/CameraView.swift`
**Purpose**: Show AI processing status

**States**:
- Ready: Static dots
- Processing: Animated dots
- Complete: Checkmark

### SuccessToast
**Location**: `Design/InteractiveElements.swift`
**Purpose**: Temporary success messages

**Features**:
- Slide-in animation
- Auto-dismiss (3s)
- Tap to dismiss
- Custom messages

### ErrorAlert
**Location**: `Core/Utilities/ErrorHandling.swift`
**Purpose**: User-friendly error display

**Types**:
- Network errors
- API errors
- Permission errors
- Generic errors

### ImagePicker
**Location**: `Core/Utilities/ImagePicker.swift`
**Purpose**: Native photo selection

**Modes**:
- Camera capture
- Photo library
- Limited selection

## Component Best Practices

### Performance
1. Use `@StateObject` for owned objects
2. Extract complex views into components
3. Implement `Equatable` for efficient updates
4. Use `drawingGroup()` for heavy animations

### Accessibility
1. Add `.accessibilityLabel()` to all interactive elements
2. Support Dynamic Type
3. Ensure sufficient color contrast
4. Test with VoiceOver

### Reusability
1. Accept bindings for state
2. Use generic types where applicable
3. Provide sensible defaults
4. Document public APIs

### Testing
1. Preview providers for all components
2. Unit tests for logic
3. Snapshot tests for UI
4. Integration tests for flows

---

Last Updated: January 31, 2025
Version: 1.0.0