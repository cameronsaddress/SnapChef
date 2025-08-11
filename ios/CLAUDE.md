# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
SnapChef is an iOS app that transforms fridge/pantry photos into personalized recipes using AI (Grok Vision API), with built-in social sharing and gamification features.

## Essential Documentation for AI Assistants
1. **Start Here**: [AI_DEVELOPER_GUIDE.md](AI_DEVELOPER_GUIDE.md) - Comprehensive guide for AI assistants
2. **Code Flow**: [COMPLETE_CODE_TRACE.md](COMPLETE_CODE_TRACE.md) - Full app flow analysis  
3. **File Status**: [FILE_USAGE_ANALYSIS.md](FILE_USAGE_ANALYSIS.md) - What's used/unused

### Latest Updates (Jan 11, 2025) - Part 4
- **Fixed TikTok Video Photo Orientation**
  - Photos were appearing upside down in generated TikTok videos
  - Removed unnecessary coordinate system flip in drawImage method
  - CGContext already handles correct image orientation
  - Images now display correctly in all video templates

### Latest Updates (Jan 11, 2025) - Part 3
- **Fixed Duplicate Recipe Prevention**
  - Fixed issue where only local recipes were being checked for duplicates
  - CameraView now fetches CloudKit recipes before generating new ones
  - Sends both local and CloudKit recipe names to backend API
  - Backend LLM properly instructed to avoid all existing recipes
  - Prevents users from getting duplicate recipes they already have saved in cloud

### Latest Updates (Jan 11, 2025) - Part 2
- **CloudKit Photo Storage Implementation**
  - Added `beforePhotoAsset` and `afterPhotoAsset` fields to Recipe record in CloudKit schema
  - Implemented automatic upload of fridge photos to all generated recipes
  - Each recipe from the same generation gets its own copy of the fridge photo (CloudKit requirement)
  - Created `AfterPhotoCaptureView` for capturing meal completion photos
  - Added comprehensive photo management methods to `CloudKitRecipeManager`:
    - `uploadImageAsset()` - Uploads UIImage as CKAsset with compression
    - `updateAfterPhoto()` - Updates recipe with after photo
    - `fetchRecipePhotos()` - Retrieves both photos for a recipe
  - Enhanced TikTok video generation to use CloudKit-stored photos:
    - Automatically fetches before (fridge) photo if not provided
    - Fetches after (meal) photo from CloudKit if available
    - Prompts user to capture after photo if missing
  - Added detailed console logging for all photo operations:
    - Upload progress with file sizes and recipe details
    - Download status with success/failure indicators
    - Photo availability tracking for video generation
  - Fixed TikTok video to properly display both before/after photos with:
    - `drawImage()` helper for rendering UIImages in video frames
    - Shadow support for text overlays on images
    - Vignette effects for better text visibility

### Latest Updates (Jan 11, 2025)
- **CRITICAL FIX: Resolved Swift 6 Build Failure**
  - **Root Cause**: Naming conflict - `struct Scene` in TikTokVideoGeneratorEnhanced.swift was conflicting with SwiftUI's `Scene` protocol
  - **Solution**: Renamed `Scene` to `VideoScene` throughout the file
  - **Impact**: Fixed "Type 'SnapChefApp' does not conform to protocol 'App'" error
  - This was causing the compiler error: "a 'some' type must specify only 'Any', 'AnyObject', protocols, and/or a base class"
- **Swift 6 Concurrency Improvements**
  - Fixed multiple @MainActor isolation issues across the codebase
  - Updated Timer callbacks to use `Task { @MainActor in ... }` pattern
  - Marked manager classes as `final` for better Swift 6 compliance:
    - AuthenticationManager
    - DeviceManager
    - AppState
    - GamificationManager
  - Fixed singleton initialization patterns for thread safety
- **Swift 6 Dispatch Queue Fixes (Part 2)**
  - Fixed all dispatch queue assertion failures that prevented app launch
  - Wrapped UNUserNotificationCenter.current() calls in Task.detached blocks
  - Made singleton references lazy to prevent early initialization
  - Fixed notification center access patterns in all gamification managers
  - Resolved "No 'async' operations occur within 'await' expression" warnings
- **TikTok Video Generation Fixes**
  - Fixed text rendering (backwards/upside down) with coordinate transformation
  - Ensured all video frames are written (was missing ~30 frames)
  - Fixed duplicate hashtag warnings
  - Added proper photo library permissions for video saving

### Previous Updates (Feb 3, 2025)
- **NEW: Share Functionality Standardization (COMPLETE)**
  - Created comprehensive implementation plan (SHARE_FUNCTIONALITY_IMPLEMENTATION_PLAN.md)
  - Enhanced Ruby script with safety features (safe_add_files_to_xcode.rb)
    - Automatic timestamped backups
    - Rollback capability on failure
    - Dry run mode for testing
  - **Core Infrastructure:**
    - ShareService.swift - Central coordinator with deep linking
    - BrandedSharePopup.swift - Branded UI with platform icons
    - SharePlatformType enum for platform management
    - Platform detection and availability checking
    - Full deep link support for all platforms
  - **TikTok Integration:**
    - TikTokShareView.swift - Full TikTok sharing interface
    - TikTokVideoGenerator.swift - AVFoundation video generation
    - TikTokTemplates.swift - 5 viral video templates
    - Features: Before/After reveals, 360° views, timelapses
    - Trending audio suggestions and hashtag recommendations
  - **Instagram Integration:**
    - InstagramShareView.swift - Stories and posts creation
    - InstagramContentGenerator.swift - Image rendering
    - InstagramTemplates.swift - 5 design templates
    - Features: Stickers, hashtags, carousel support
  - **X (Twitter) Integration:**
    - XShareView.swift - Tweet composer with preview
    - XContentGenerator.swift - Card generation
    - Tweet styles: Classic, Thread, Viral, Professional, Funny
    - Character counter and hashtag management
  - **Messages Integration:**
    - MessagesShareView.swift - Interactive card creator
    - MessageCardGenerator.swift - 3D card rendering
    - Rotating cards, flip animations, carousel views
    - MFMessageComposeViewController integration
  - **Deep Linking:**
    - All platforms support deep links
    - Fallback to web for uninstalled apps
    - Clipboard integration for seamless sharing
  - Successfully integrated with Xcode project (all builds pass)
### Previous Updates (Feb 3, 2025)
- **NEW: Complete CloudKit Bidirectional Sync**
  - All user data now syncs both ways (push and pull) with CloudKit
  - Recipes: Automatically uploaded when created, synced across devices
  - Profile Stats: Real-time sync of recipes created, favorites, and shares
  - Challenges: Start/progress/completion synced to CloudKit
  - Achievements: Automatically saved to CloudKit when earned
  - Leaderboards: Updated in real-time with challenge completions
  - ProfileView: Now loads active challenges and achievements from CloudKit
  - Interactive profile tiles for recipes and favorites navigation
- **FIXED: Authentication & Username Setup Flow**
  - Fixed username setup view not showing after Sign in with Apple
  - Added username check for both new and existing users
  - Properly handles auth flow completion with username validation
  - Fixed error 1001 handling for Sign in with Apple cancellation
- **NEW: Local Challenge System with 365 Days of Content**
  - Embedded full year of challenges directly in app (no CloudKit needed)
  - Automatic daily/weekly challenge rotation
  - Seasonal challenges (Winter, Spring, Summer, Fall)
  - Viral TikTok-style challenges
  - Weekend special challenges
  - Dynamic scheduling based on current date
  - Hourly refresh to update active challenges
- Enhanced emoji flick game with improved UI
- Updated recipe results view with better text layout
- Improved share generator with simplified workflow
- Comprehensive documentation added
- Separated server code into dedicated repository
- Removed server-main.py and server-prompt.py from iOS repo
- **COMPLETED: Full Challenge System Implementation (Phase 1-3)**
  - Database foundation with Core Data
  - Complete UI with Challenge Hub, cards, and leaderboards
  - Reward system with Chef Coins and unlockables
  - Social features including teams and sharing
  - Full integration with recipe creation and sharing
  - Premium challenges and analytics tracking
  - CloudKit user profiles with username management
- **NEW: Challenge Proof Submission System (Feb 2, 2025)**
  - Complete photo proof submission interface (ChallengeProofSubmissionView)
  - Camera and photo library integration with proper permissions
  - Notes field for additional context
  - Automatic point and coin rewards upon submission
  - CloudKit integration for storing proof images as CKAssets
  - Fixed Xcode project corruption (duplicate GUIDs and broken proxies)
  - Resolved naming conflicts (ImagePicker renamed across multiple views)
- **FIXED: Recipe Book CloudKit Integration (Feb 2, 2025)**
  - Recipe book now loads saved CloudKit recipes for authenticated users
  - Automatically syncs user's saved and created recipes from CloudKit
  - Recipe deletion now syncs back to CloudKit to remove from user's profile
  - Added loading indicator while fetching CloudKit recipes
  - Recipes refresh when app returns to foreground
  - Combined local and CloudKit recipes with deduplication
- **NEW: CloudKit Challenge Synchronization (Feb 2, 2025)**
  - Replaced non-existent API calls with CloudKit sync for challenges
  - Challenges automatically upload to CloudKit when created locally
  - User progress syncs bidirectionally between device and CloudKit
  - Real-time sync runs every 5 minutes for active challenges
  - Supports team challenges, achievements, and leaderboards
  - Fixed network errors from api.snapchef.com (non-existent server)
  - ChallengeService now uses CloudKitChallengeManager for all operations
- **FIXED: Social Features & Real-time Sync (Feb 3, 2025)**
  - Fixed ProfileView recipe count showing only local recipes
  - Added 200 fake local user accounts with realistic distribution
  - Follower/following counts now update immediately in FeedView
  - Recipe counts sync with CloudKit in real-time
  - Pull-to-refresh added to FeedView for manual stat updates
  - Fixed range error in fake user generation
  - Unified search across local and CloudKit users
- **IMPROVED: AI Processing Screen UI (Feb 3, 2025)**
  - Increased "While our chef prepares" text size by 50% for better readability
  - Changed button text to "Play a game with your fridge while you wait!"
  - Button now shakes every 2 seconds to draw attention
  - Removed auto-navigation to emoji game (requires user tap)
  - Widened game button by 20% for better text fit
- **CloudKit Schema & Permissions Fixed (Feb 3, 2025)**
  - Added CREATE permissions for authenticated users (_icloud)
  - Fixed permission errors for Challenge, Team, Leaderboard, RecipeLike, Activity
  - Created detailed setup documentation (CLOUDKIT_SETUP.md)
  - Added specific permission change guide (CLOUDKIT_PERMISSION_CHANGES.md)

### Documentation
- **APP_ARCHITECTURE_DOCUMENTATION.md** - Complete system overview
- **COMPONENT_REFERENCE.md** - Detailed component guide
- **PROJECT_BRIEF.md** - Original project specifications
- **WORKSPACE_STRUCTURE.md** - Multi-repository workflow guide

## Key Commands

### Development
```bash
# Build the project
xcodebuild -project SnapChef.xcodeproj -scheme SnapChef -configuration Debug

# Run tests
xcodebuild test -project SnapChef.xcodeproj -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Clean build folder
xcodebuild clean -project SnapChef.xcodeproj -scheme SnapChef
```

### Linting & Type Checking
```bash
# SwiftLint (if installed)
swiftlint

# Swift format (if using)
swift-format -i -r SnapChef/
```

## Architecture

### Core Components
1. **SnapChefApp.swift** - App entry point and scene configuration
2. **Core/Networking/SnapChefAPIManager.swift** - Grok Vision API integration
3. **Features/Camera/CameraView.swift** - Main camera interface with emoji game
4. **Features/Recipes/RecipeResultsView.swift** - Recipe display with enhanced cards
5. **Core/ViewModels/AppState.swift** - Global app state management
6. **Features/Sharing/ShareGeneratorView.swift** - Social media share creation
7. **Features/Gamification/EnhancedGamificationManager.swift** - Points and badges
8. **Core/Services/CloudKitAuthManager.swift** - Authentication with Apple, Google, Facebook
9. **Features/Authentication/UsernameSetupView.swift** - Profile setup after authentication

### API Integration

#### Server Details
- **Base URL**: https://snapchef-server.onrender.com
- **Main Endpoint**: /analyze_fridge_image
- **Method**: POST (multipart/form-data)
- **Authentication**: X-App-API-Key header required

#### API Key
- **Header Name**: X-App-API-Key
- **Storage**: iOS Keychain (secure)
- **Fallback**: Available in code for development only

#### Request Format
```swift
// Required fields
- image_file: UIImage as JPEG data
- session_id: UUID string

// Optional fields
- dietary_restrictions: JSON array string (e.g., "[\"vegetarian\", \"gluten-free\"]")
- food_type: String (e.g., "Italian", "Mexican")
- difficulty_preference: String (e.g., "easy", "medium", "hard")
- health_preference: String (e.g., "healthy", "balanced", "indulgent")
- meal_type: String (e.g., "breakfast", "lunch", "dinner")
- cooking_time_preference: String (e.g., "quick", "under 30 mins")
- number_of_recipes: String number (e.g., "3")
```

#### Response Models
```swift
struct APIResponse {
    let data: GrokParsedResponse
    let message: String
}

struct GrokParsedResponse {
    let image_analysis: ImageAnalysis
    let ingredients: [IngredientAPI]
    let recipes: [RecipeAPI]
}

struct RecipeAPI {
    let id: String
    let name: String
    let description: String
    let difficulty: String
    let instructions: [String]
    let nutrition: NutritionAPI?
    // ... other fields
}
```

### Data Flow
1. User captures photo in CameraView
2. Image sent to SnapChefAPIManager with preferences
3. API returns analyzed ingredients and recipes
4. Recipes converted from API format to app Recipe model
5. Results displayed in RecipeResultsView
6. User can save via ShareGeneratorView

### Key Features
- Real-time camera preview with AR-style overlays
- Magical UI animations and transitions (60fps target)
- Recipe sharing with custom graphics
- Gamification system (points, badges, challenges)
- AI Chef personalities (8 unique personas)
- Offline recipe storage
- Social media integration (Instagram, TikTok, Twitter/X)
- Multi-provider authentication (Apple, Google, Facebook)
- CloudKit-based user profiles and social features

### Authentication System

#### Authentication Flow
1. User triggers auth-required feature (challenges, teams, sharing)
2. CloudKitAuthView presents sign-in options
3. User authenticates with Apple/Google/Facebook
4. System checks if user exists in CloudKit:
   - **New User**: Creates profile, shows UsernameSetupView
   - **Existing User without username**: Shows UsernameSetupView
   - **Existing User with username**: Proceeds to requested feature
5. Username validation includes:
   - Availability check in CloudKit
   - Profanity filtering with leetspeak detection
   - 3-20 character alphanumeric requirement
6. Profile photo upload (optional) stored as CKAsset

#### Key Components
- **CloudKitAuthManager**: Central authentication service
- **CloudKitUserManager**: Username and profile management
- **ProfanityFilter**: Content moderation for usernames
- **UsernameSetupView**: Onboarding UI for new users

### Challenge System Architecture

#### Core Components
- **ChallengeGenerator** - Creates dynamic daily/weekly/special challenges
- **ChallengeProgressTracker** - Real-time progress monitoring and updates
- **ChallengeService** - Core Data persistence and CloudKit sync
- **ChefCoinsManager** - Virtual currency system with transactions
- **ChallengeAnalytics** - Comprehensive engagement tracking

#### UI Components
- **ChallengeHubView** - Main challenge dashboard
- **ChallengeCardView** - Individual challenge display
- **LeaderboardView** - Global and regional rankings
- **AchievementGalleryView** - Badge and reward collection
- **DailyCheckInView** - Streak maintenance interface

#### Integration Points
- **CameraView** - Tracks recipe creation for challenges
- **ShareGeneratorView** - Awards coins for social sharing
- **SubscriptionManager** - Premium challenges and 2x rewards
- **GamificationManager** - XP and level progression

#### Premium Features
- Exclusive premium-only challenges
- Double coin rewards (2x multiplier)
- Special badges and titles
- Advanced analytics access
- Priority leaderboard placement

### Testing Strategy
- Unit tests for API response parsing
- UI tests for camera flow
- Integration tests for recipe generation
- Performance tests for image processing

## Common Tasks

### Adding New User Preferences
1. Add @State variable in CameraView
2. Update SnapChefAPIManager.sendImageForRecipeGeneration parameters
3. Add form field in createMultipartFormData
4. Update UI to collect preference

### Debugging API Issues
1. Check API key in KeychainManager
2. Verify server is running at https://snapchef-server.onrender.com
3. Check network logs for response details
4. Ensure image compression quality is appropriate (80% JPEG)

### Adding New Features
1. Create feature folder under Features/
2. Add models in Core/Models if needed
3. Update navigation in ContentView if new tab
4. Add to Xcode project file
5. Update documentation

### UI/Animation Guidelines
- Use spring animations for natural motion
- Limit particle counts for performance
- Test on older devices (iPhone 12 minimum)
- Profile with Instruments for 60fps

### Security Notes
- API key should be in Keychain for production
- No sensitive data in UserDefaults
- Validate all user inputs before API calls
- Handle authentication errors gracefully

## Code Style Guidelines
- Use SwiftUI's declarative syntax
- Prefer @StateObject for view models
- Extract reusable components
- Keep views under 200 lines
- Use meaningful variable names
- Add MARK comments for organization

## Performance Tips
- Compress images before upload (80% JPEG)
- Use .drawingGroup() for complex animations
- Cache API responses when appropriate
- Lazy load heavy resources
- Profile memory usage regularly

## Common Issues & Solutions

### Build Errors
- Clean build folder: Cmd+Shift+K
- Delete derived data if needed
- Check Swift version compatibility

### API Timeout
- Default timeout is 30 seconds
- Can increase to 60 for slow connections
- Check image size (max 10MB)

### Animation Lag
- Reduce particle count
- Use .drawingGroup() modifier
- Profile with Instruments

## Recent UI/UX Improvements

### Emoji Flick Game
- Fridge background opacity increased to 0.375 (25% less transparent)
- Removed instructional text, moved AI indicator to top
- Added 60-second progress bar with gradient theme

### Recipe Results
- Removed "we found X recipes" text for cleaner UI
- Updated fridge inventory to "Here's what is in your fridge" (multi-line)
- Recipe titles moved to top of cards (2 lines max)
- Calorie container widened with minWidth: 40

### Share Generator
- Changed from infinite spin to single 30° rotation
- Made after photo area clickable
- Added "Take your after photo" button with status indicator
- Removed challenge text editor section
- Removed style selector, uses random style

### AI Processing View
- Moved scanning circle to top with 60px spacing
- Increased text size from 22px to 44px for better visibility

## Multi-Repository Structure

### iOS App (This Repository)
- **Location**: `/Users/cameronanderson/SnapChef/snapchef/ios/`
- **GitHub**: https://github.com/cameronsaddress/snapchef
- **Purpose**: iOS mobile application

### FastAPI Server (Separate Repository)
- **Location**: `/Users/cameronanderson/snapchef-server/snapchef-server/`
- **GitHub**: https://github.com/cameronsaddress/snapchef-server
- **Purpose**: Backend API server
- **Files**: `main.py`, `prompt.py`, `requirements.txt`

### Working with Multiple Repositories
See [WORKSPACE_STRUCTURE.md](WORKSPACE_STRUCTURE.md) for detailed instructions on managing both repositories.

## Challenge System Development (Multi-Agent Orchestration)

### IMPORTANT: Challenge System Coordination
When working on the challenge system:
1. **Always check** `CHALLENGE_SYSTEM_ORCHESTRATION.md` for the plan
2. **Update progress** in `CHALLENGE_SYSTEM_PROGRESS.json` after each task
3. **No duplication** - reuse existing components listed in orchestration doc
4. **Coordinate work** - check which phase is active before starting

### Orchestration Files:
- `CHALLENGE_SYSTEM_ORCHESTRATION.md` - Master plan and coordination
- `CHALLENGE_SYSTEM_PROGRESS.json` - Real-time progress tracking

### Recovery Process:
If returning to challenge system work:
1. Read `CHALLENGE_SYSTEM_PROGRESS.json` to see what's completed
2. Check current phase status
3. Continue from next pending task
4. Update progress file after each completion