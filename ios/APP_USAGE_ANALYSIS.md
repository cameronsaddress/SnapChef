# SnapChef App Usage Analysis

## App Entry and Navigation Flow

### Entry Point
- **SnapChefApp.swift**: Main app entry
  - Creates 3 StateObjects: AppState, AuthenticationManager, DeviceManager
  - Calls setupApp() which:
    - Configures UI appearance (nav bar, table view, window)
    - Ensures API key exists via KeychainManager
    - Configures NetworkManager
    - Checks device status via DeviceManager
    - Has TODO for AnalyticsManager (not implemented)

### Main Navigation Flow
- **ContentView.swift**: Root view
  - Shows LaunchAnimationView initially
  - Then shows either:
    - OnboardingView (if first launch)
    - MainTabView (normal flow)
  - Uses MagicalBackground throughout

### Tab Navigation (MainTabView)
- 4 tabs controlled by MorphingTabBar:
  1. Tab 0: EnhancedHomeView
  2. Tab 1: CameraTabView
  3. Tab 2: EnhancedRecipesView
  4. Tab 3: EnhancedProfileView

## Core Managers/Services Used

### Actually Used:
1. **AppState** - Global app state
2. **AuthenticationManager** - User auth
3. **DeviceManager** - Device fingerprinting & subscription
4. **NetworkManager** - Network configuration
5. **KeychainManager** - Secure API key storage

### Referenced but not implemented:
- AnalyticsManager (TODO comment)

## Views Analysis

### Primary Views (Actually Used):

#### Tab Views:
1. **EnhancedHomeView** (Tab 0)
   - Navigates to:
     - EnhancedCameraView (fullScreenCover)
     - MysteryMealView (fullScreenCover)
     - SubscriptionView (fullScreenCover)
     - ChallengeDetailView (sheet)
   - Components used:
     - MagicalBackground
     - HeroLogoView
     - MagneticButton
     - HomeChallengeCard
     - FallingFoodManager (custom)

2. **CameraTabView** (Tab 1)
   - Simple launcher that opens:
     - EnhancedCameraView (fullScreenCover)
   - Components used:
     - MagicalBackground
     - MagneticButton

3. **EnhancedRecipesView** (Tab 2)
   - Navigates to:
     - RecipeFiltersView (sheet)
     - RecipeDetailView (sheet)
     - ShareGeneratorView (sheet)
   - Uses LocalRecipeDatabase for saved recipes
   - Components: RecipeGridView, EnhancedEmptyRecipesView

4. **EnhancedProfileView** (Tab 3)
   - Navigates to:
     - SubscriptionView (sheet)
     - EditProfileView (sheet)
     - FoodPreferencesView (fullScreenCover)
   - Embedded components:
     - GamificationStatsView
     - AchievementGalleryView
     - EnhancedSubscriptionCard
     - SocialStatsCard
     - EnhancedSettingsSection

#### Camera Flow:
- **EnhancedCameraView**
  - Navigates to:
    - EnhancedRecipeResultsView (fullScreenCover) - with recipes & ingredients
    - SubscriptionView (fullScreenCover)
  - Uses CameraModel
  - Shows MagicalProcessingOverlay during processing

#### Onboarding Flow:
- **OnboardingView** (first launch)
  - TODO: Analyze

#### Other Key Views:
- **LaunchAnimationView** - App launch animation
- **SubscriptionView** - IAP/subscription management
- **MysteryMealView** - Spin wheel game
- **ChallengeDetailView** - Challenge details
- **EnhancedRecipeResultsView** - Recipe results display

### Duplicate/Potentially Unused Views:
1. **HomeView.swift** vs **EnhancedHomeView.swift** - Enhanced version is used
2. **CameraView.swift** vs **EnhancedCameraView.swift** - Enhanced version is used
3. **RecipesView.swift** vs **EnhancedRecipesView.swift** - Enhanced version is used
4. **ProfileView.swift** vs **EnhancedProfileView.swift** - Enhanced version is used
5. **RecipeResultsView.swift** vs **EnhancedRecipeResultsView.swift** - Enhanced version is used
6. **AIPersonalityView.swift** - Not referenced in main navigation
7. **LeaderboardView.swift** - Not referenced in main navigation
8. **ChallengesView.swift** - Not referenced in main navigation (only ChallengeDetailView)
9. **FridgeInventoryView.swift** - Not referenced in main navigation
10. **AfterPhotoCaptureView.swift** - Not found in any navigation
11. **SocialShareView.swift** - Not found in any navigation
12. **SimplePhotoCaptureView.swift** - Not found in any navigation

## ViewModels and Managers

### Core Managers (Actually Used):
1. **AppState** - Global app state management
2. **AuthenticationManager** - User authentication
3. **DeviceManager** - Device fingerprinting & subscription
4. **KeychainManager** - Secure API key storage
5. **NetworkManager** - Network configuration
6. **CameraModel** - Camera functionality
7. **HapticManager** - Haptic feedback

### Managers Used in Specific Views:
1. **GamificationManager** - Used in ChallengesView, LeaderboardView (but these views aren't in main nav)
2. **AIPersonalityManager** - Used in MysteryMealView, AIPersonalityView
3. **SocialShareManager** - Used in SocialShareView (not in main nav)
4. **FallingFoodManager** - Custom manager in EnhancedHomeView
5. **LocalRecipeDatabase** - Used in EnhancedRecipesView for saved recipes

### Referenced but Not Implemented:
- **AnalyticsManager** - TODO comment in SnapChefApp

## API Usage

### SnapChefAPIManager:
- **Main endpoint**: `/analyze_fridge_image`
- **Method**: `sendImageForRecipeGeneration`
- **Used in**: EnhancedCameraView
- **Parameters sent**:
  - image_file (JPEG)
  - session_id
  - dietary_restrictions
  - food_type
  - difficulty_preference
  - health_preference
  - meal_type
  - cooking_time_preference
  - number_of_recipes

## UI Components Actually Used

### Core Design Components:
1. **MagicalBackground** - Used throughout app (20+ views)
2. **MorphingTabBar** - Main navigation
3. **GlassmorphicCard** - Card UI component
4. **MagneticButton** - Primary button style
5. **HeroLogoView** - App logo on home

### Supporting Components:
- **MagicalProcessingOverlay** - Loading state during recipe generation
- **ConfettiView** - Success animation
- **ShakeEffect** - Button animation
- **ParticleSystem** - Background effects
- **EmojiFlickGame** - Loading mini-game

### Design Files:
- **MagicalBackground.swift** ✅ Used
- **MorphingTabBar.swift** ✅ Used
- **GlassmorphicComponents.swift** ✅ Used
- **ColorExtensions.swift** ✅ Used (hex colors)
- **MagicalTransitions.swift** ❓ Minimal usage

## Colors & Assets

### Primary Colors (all use hex):
- `#667eea` - Primary purple
- `#764ba2` - Deep purple
- `#f093fb` - Pink
- `#4facfe` - Blue
- `#43e97b` - Green
- `#38f9d7` - Teal
- `#f5576c` - Red/Pink
- `#ffa726` - Orange

### System Icons Used:
- Camera: `camera.fill`, `camera.viewfinder`, `camera.rotate.fill`
- Navigation: `arrow.right`, `arrow.left.square.fill`, `chevron.right`, `xmark.circle.fill`
- Actions: `checkmark`, `sparkles`, `star.fill`
- Social: `arrow.up.forward.circle.fill`, `square.and.arrow.up`
- Status: `clock`, `flame`, `person.fill`, `book.fill`, `house.fill`

### No Custom Images/Assets Found
- All icons use SF Symbols (systemName)
- No image assets referenced
- No custom fonts

## Summary of Unused/Duplicate Files

### Duplicate Views (Non-Enhanced versions not used):
1. **HomeView.swift** - Use EnhancedHomeView instead ❌
2. **CameraView.swift** - Use EnhancedCameraView instead ❌
3. **RecipesView.swift** - Use EnhancedRecipesView instead ❌
4. **ProfileView.swift** - Use EnhancedProfileView instead ❌
5. **RecipeResultsView.swift** - Use EnhancedRecipeResultsView instead ❌

### Unused Views (Not in navigation flow):
1. **AIPersonalityView.swift** ❌
2. **LeaderboardView.swift** ❌
3. **ChallengesView.swift** ❌ (only ChallengeDetailView used)
4. **FridgeInventoryView.swift** ❌
5. **AfterPhotoCaptureView.swift** ❌
6. **SocialShareView.swift** ❌
7. **SimplePhotoCaptureView.swift** ❌

### Potentially Keep:
- **ShareSheet.swift** - Simple share functionality
- **PrintView.swift** - Recipe printing
- **CapturedImageView.swift** - Used in camera flow
- **FoodPreferencesView.swift** - Used in profile
- **EditProfileView.swift** - Used in profile

## Recommendations

### Files to Move to Archive:
1. All non-enhanced versions of main views
2. Unused feature views (AIPersonalityView, LeaderboardView, etc.)
3. SimplePhotoCaptureView (not used)
4. AfterPhotoCaptureView (not used)
5. SocialShareView (not used)

### Files to Keep:
- All Enhanced versions of views
- Core managers and services
- UI components in Design folder
- API manager and models
- Views actually referenced in navigation

### Potential Cleanup:
1. Remove TODO for AnalyticsManager or implement it
2. Consider consolidating duplicate functionality
3. Remove unused imports
4. Clean up preview data