# SnapChef iOS Changelog

All notable changes to the SnapChef iOS app will be documented in this file.

## [Unreleased]

### January 12, 2025 - Part 2 - TikTok SDK Direct Integration

#### Added
- **Full TikTok SDK Integration**:
  - Direct SDK integration using PHAsset identifiers
  - Pre-populates media in TikTok app when SDK succeeds
  - Proper threading with PHPhotoLibrary operations on main thread
  - Automatic fallback to safe URL scheme method if SDK fails
  - Swift 6 concurrency compatibility with Task/MainActor usage
  - Comprehensive error handling and logging

#### Fixed
- Thread 28: EXC_BREAKPOINT crashes when sharing to TikTok
- PHPhotoLibrary threading issues with main thread enforcement
- Swift continuation misuse errors in share operations
- TikTokShareResponse handling with proper type casting
- Concurrency warnings with non-Sendable closures

#### Technical Improvements
- Replaced async/await PHPhotoLibrary calls with completion handlers
- Added proper weak self capture in Task blocks
- Implemented TikTokShareResponse error checking with .noError
- Enhanced fallback mechanism for reliability

### January 12, 2025 - Unified Share Experience & Enhanced TikTok Integration

#### Added
- **Enhanced TikTok Quick Share**:
  - Quick Post now generates branded share card image (1080x1920 TikTok aspect ratio)
  - Share card includes recipe photo, name, cooking time, calories, and difficulty
  - Automatic image save to photo library for easy selection in TikTok
  - Pre-formatted caption with hashtags copied to clipboard
  - Smart deep linking with multiple URL scheme attempts:
    - `snssdk1233://create` for international TikTok create screen
    - `tiktok://library` for accessing saved content
    - Multiple fallback options to find best entry point
  - Added `snssdk1233` to Info.plist for international TikTok support
  - CAGradientLayer extension for gradient image generation

#### Changed
- **Unified Share Experience**:
  - Replaced ShareGeneratorView with BrandedSharePopup across entire app
  - RecipesView: Updated recipe cards and context menu to use BrandedSharePopup
  - RecipeResultsView: Now uses BrandedSharePopup for consistency
  - All share buttons present same branded popup with social platform icons
  - SMS/Messages fully integrated into main share flow
  - Added helper methods to retrieve before/after photos from saved recipes
  - Consistent share experience across all recipe-related views

#### Technical Improvements
- Added QuartzCore import for gradient functionality
- Created async image generation and save functionality
- Implemented smart URL scheme detection with graceful fallbacks
- Enhanced user flow with status messages during share process

### January 11, 2025 - Part 6 - Enhanced Deep Linking for Social Media Sharing

#### Added
- **Improved Deep Linking Support**:
  - Created ImprovedShareService with enhanced deep linking capabilities
  - Added multiple URL scheme support for better app compatibility
  - TikTok: Now opens library view after saving video for easier selection
  - Instagram: Opens library view for feed posts, enhanced Stories integration
  - Added fallback URL schemes for different app versions
  - Extended LSApplicationQueriesSchemes in Info.plist for broader compatibility

#### Changed
- **TikTok Sharing**:
  - Enhanced caption with recipe details and cooking time
  - Better URL scheme detection (tries multiple schemes)
  - Opens video library instead of just the app
  - Improved fallback to web upload page
- **Instagram Sharing**:
  - Stories now include attribution links and brand colors
  - Feed posts open library for easier photo selection
  - Added source application parameter for better tracking
  - Enhanced captions with call-to-action
- **URL Schemes Configuration**:
  - Added snssdk1128, snssdk1180 for TikTok variants
  - Added x-com for new X app
  - Added fbapi20130214 for Facebook SDK
  - Added whatsapp-business and wa schemes

### January 11, 2025 - Part 5 - TikTok Video Photo Orientation Fix

#### Fixed
- **TikTok Video Photo Orientation**:
  - Fixed upside-down photos in TikTok video generation
  - Removed unnecessary coordinate system flip in drawImage method
  - CGContext already uses correct orientation for image drawing
  - Photos now display right-side up in generated videos

### January 11, 2025 - Part 4 - Duplicate Recipe Prevention Enhancement

#### Fixed
- **Enhanced Duplicate Recipe Prevention**:
  - Fixed issue where only local recipes were being sent to backend for duplicate prevention
  - Now includes both local AND CloudKit recipes when checking for duplicates
  - Fetches user's saved and created recipes from CloudKit before generating new ones
  - Prevents LLM from suggesting recipes that already exist in user's cloud collection
  - Added detailed logging showing total recipe count for duplicate prevention
  - Backend properly receives all recipe names and instructs LLM to avoid duplicates

### January 11, 2025 - Part 3 - CloudKit Photo Storage & TikTok Video Enhancement

#### Added
- **CloudKit Photo Storage System**:
  - Added `beforePhotoAsset` and `afterPhotoAsset` fields to Recipe CloudKit schema
  - Created `AfterPhotoCaptureView` for capturing meal completion photos
  - Photo upload and retrieval methods in `CloudKitRecipeManager`:
    - `uploadImageAsset()` - Compresses and uploads UIImage as CKAsset
    - `updateAfterPhoto()` - Adds after photo to existing recipe
    - `fetchRecipePhotos()` - Retrieves both photos from CloudKit
  - Automatic association of fridge photo with all generated recipes
  - JPEG compression at 80% quality for optimal storage

- **Enhanced Console Logging**:
  - Detailed photo upload tracking with file sizes and compression stats
  - Recipe title and ID logging for all photo operations
  - Photo type identification (FRIDGE vs MEAL)
  - Success/failure indicators for upload and download operations
  - Multi-recipe upload progress tracking (1/3, 2/3, 3/3)

#### Changed
- **TikTok Video Generation Improvements**:
  - Automatic fetching of before/after photos from CloudKit
  - `drawImage()` helper method for rendering photos in video frames
  - Text shadow support for better visibility over images
  - Vignette effect on photos for improved text readability
  - Proper aspect fill scaling for images in videos
  - State management for CloudKit-fetched photos

- **CameraView Recipe Upload**:
  - Now uploads fridge photo to all generated recipes
  - Clear progress tracking for multi-recipe uploads
  - Confirmation that same fridge photo is intentionally shared

#### Fixed
- **TikTok Video Photo Display**:
  - Before (fridge) photo now properly displays in videos
  - After (meal) photo correctly rendered with overlays
  - Coordinate system transformation for proper image orientation
  - Photos fetched from CloudKit if not provided initially

### January 11, 2025 - Part 2 - Swift 6 Dispatch Queue Fixes & TikTok Video Improvements

#### Fixed
- **Dispatch Queue Assertions**: Resolved all dispatch queue assertion failures preventing app launch
  - Fixed UNUserNotificationCenter.current() calls to use Task.detached blocks
  - Made singleton references lazy to defer initialization
  - Fixed notification center access in ChallengeNotificationManager and StreakManager
  - Wrapped all notification API calls in proper async contexts
  - Fixed TeamChallengeManager and ChallengeSharingManager notification calls
  
- **TikTok Video Generation Issues**:
  - Fixed text rendering appearing backwards/upside down due to Core Graphics coordinate system
  - Applied proper coordinate transformation (Y-axis flip) in drawText method
  - Fixed video frame writing to ensure all 450 frames are written
  - Changed to wait for video input ready state before writing frames
  - Fixed duplicate hashtag IDs warning (EasyRecipe appearing twice)
  
- **Photo Library Permissions**:
  - Added NSPhotoLibraryAddUsageDescription to Info.plist for saving videos
  - Updated photo library authorization to use requestAuthorization(for: .addOnly)
  - Fixed crashes when saving TikTok videos to photo library

#### Changed
- **Async/Await Updates**:
  - Removed unnecessary await keywords from non-async methods in SnapChefApp
  - Fixed "No 'async' operations occur within 'await' expression" warnings

### January 11, 2025 - Swift 6 Migration Fixes & Google Sign-In Removal

#### Changed
- **Removed Google Sign-In Integration**: Completely removed all Google Sign-In code and dependencies per user request
  - Removed GoogleSignIn package dependency
  - Cleaned up CloudKitAuthView to only show Sign in with Apple
  - Removed signInWithGoogle method from CloudKitAuthManager
  - Authentication now uses Sign in with Apple exclusively

#### Fixed
- **Critical Build Failure**: Resolved Swift 6 compilation error preventing app from building
  - Root cause: `struct Scene` in TikTokVideoGeneratorEnhanced.swift conflicted with SwiftUI's `Scene` protocol
  - Solution: Renamed to `VideoScene` throughout the file
  - Impact: Fixed "Type 'SnapChefApp' does not conform to protocol 'App'" error
- **Swift 6 Concurrency Issues**: Fixed multiple @MainActor isolation violations
  - Updated Timer callbacks across the codebase to use `Task { @MainActor in ... }` pattern
  - Fixed files: InfluencerCarousel, AIProcessingView, ChallengeGenerator, PhysicsLoadingOverlay, EmojiFlickGame
  - Added proper @MainActor annotations to ShareService
- **Code Quality Improvements**: Enhanced type safety for Swift 6
  - Marked core manager classes as `final`: AuthenticationManager, DeviceManager, AppState, GamificationManager
  - Ensures better compiler optimization and prevents inheritance issues

#### Known Issues
- Minor concurrency warnings remain in:
  - TikTokTemplates.swift (currentStep property)
  - MessagesShareView.swift (dismiss call)
  - TikTokShareViewEnhanced.swift (haptic feedback)
- These are non-critical and will be addressed in next update

### February 3, 2025 - Share Functionality Standardization

#### Added
- Comprehensive share functionality implementation plan (SHARE_FUNCTIONALITY_IMPLEMENTATION_PLAN.md)
- Enhanced Ruby script for safe Xcode file insertion (safe_add_files_to_xcode.rb)
  - Automatic backup creation before modifications
  - Rollback capability on failure
  - Dry run mode for testing
  - Detailed logging and reporting
- Core share infrastructure:
  - ShareService.swift - Central coordinator for all sharing operations
  - BrandedSharePopup.swift - Modern branded UI with platform-specific icons
  - SharePlatformType enum for platform management
- Platform availability detection for installed apps
- Deep link support infrastructure
- Share content types (recipe, challenge, achievement, profile)

#### Changed
- Renamed SharePlatform to SharePlatformType to avoid naming conflicts

#### Platform-Specific Implementations

##### TikTok Integration
- TikTok Video Generator (TikTokShareView.swift, TikTokVideoGenerator.swift, TikTokTemplates.swift)
  - 5 viral video templates (Before/After, 60-Second Recipe, 360° View, Timelapse, Split Screen)
  - Real-time video generation with progress tracking
  - Trending audio suggestions
  - Smart hashtag recommendations
  - Direct export to TikTok app
  - AVFoundation video generation at 30fps, 9:16 aspect ratio

##### Instagram Integration
- Instagram Stories and Posts (InstagramShareView.swift, InstagramContentGenerator.swift, InstagramTemplates.swift)
  - 5 design templates (Classic, Modern, Minimal, Bold, Gradient)
  - Story stickers (Poll, Question, Location, Mention, Hashtag, Emoji)
  - Caption generator with smart hashtags
  - Carousel generation for multi-slide posts
  - UIPasteboard integration for Instagram Stories
  - ImageRenderer for SwiftUI to UIImage conversion

##### X (Twitter) Integration
- X/Twitter Composer (XShareView.swift, XContentGenerator.swift)
  - 5 tweet styles (Classic, Thread, Viral, Professional, Funny)
  - Real-time character counter (280 limit)
  - Thread generation with multiple cards
  - Hashtag management and suggestions
  - Tweet preview with mock UI
  - Deep link support with fallback to web

##### Messages Integration
- Interactive Messages Cards (MessagesShareView.swift, MessageCardGenerator.swift)
  - 4 card styles (Rotating 3D, Flip, Stack, Carousel)
  - Interactive rotating card with auto-rotate
  - Before/After transformation views
  - MFMessageComposeViewController integration
  - High-resolution card rendering (600x800)
  - 3D perspective effects and animations

#### Deep Linking
- All platforms support deep links (snapchef://recipe/[id], etc.)
- Automatic fallback to web for uninstalled apps
- Clipboard integration for seamless content transfer
- URL scheme detection for app availability

#### Technical Details
- Successfully integrated with Xcode project (all builds pass)
- Platform availability detection using canOpenURL
- SwiftUI and UIKit integration for native components
- Enhanced ShareService with comprehensive platform support

### February 3, 2025 - CloudKit and UI Updates

#### Added
- Real-time follower/following count synchronization with CloudKit
- Pull-to-refresh functionality in FeedView for manual stats updates
- Recipe count synchronization (created/shared) with CloudKit
- Public `refreshCurrentUser()` method in CloudKitAuthManager
- Shake animation to AI processing screen game button (every 2 seconds)
- Comprehensive CloudKit setup documentation (CLOUDKIT_SETUP.md)
- Detailed permission change guide (CLOUDKIT_PERMISSION_CHANGES.md)
- 200 fake local user accounts with realistic social media distribution

#### Changed
- AI processing screen "While our chef prepares" text increased by 50% (19pt to 28pt)
- Game button text changed to "Play a game with your fridge while you wait!"
- Game button width increased by 20% (280px to 336px)
- Button padding reduced from 20px to 10px for better text fit
- CloudKit schema permissions updated to allow CREATE for authenticated users
- `recipesCreated` property changed from `let` to `var` in CloudKitUser model

#### Fixed
- ProfileView recipe count now includes both local and CloudKit recipes
- Follower/following counts now update immediately when following/unfollowing users
- Range error in fake user generation (followerCount/2 validation)
- CloudKit permission errors for Challenge, Team, Leaderboard, RecipeLike, and Activity records
- Build errors related to `loadCurrentUser` method not found
- Recipe counts not syncing with CloudKit

#### Removed
- Auto-navigation to emoji flick game after 6 seconds (now requires user tap)

### February 2, 2025

#### Added
- CloudKit Challenge synchronization replacing non-existent API calls
- Challenge upload to CloudKit when created locally
- Bidirectional challenge progress sync
- Team challenge support via CloudKit
- Challenge proof submission system with photo upload
- CloudKit integration for storing proof images as CKAssets

#### Changed
- ChallengeService now uses CloudKitChallengeManager for all operations
- Challenges sync every 5 minutes automatically

#### Fixed
- Network errors from api.snapchef.com (non-existent server)
- Xcode project corruption (duplicate GUIDs and broken proxies)
- ImagePicker naming conflicts across multiple views
- Recipe Book CloudKit integration issues
- Authentication & username setup flow for Sign in with Apple

### January 2025

#### Added
- Complete CloudKit bidirectional sync for all user data
- Local Challenge System with 365 days of embedded content
- Full Challenge System Implementation (Phase 1-3)
- Enhanced emoji flick game with improved UI
- Comprehensive documentation suite
- CloudKit user profiles with username management

#### Changed
- Separated server code into dedicated repository
- Updated recipe results view with better text layout
- Improved share generator with simplified workflow

#### Removed
- server-main.py and server-prompt.py from iOS repo

## Version History

### v1.0.0 - Initial Release
- Core camera functionality with ingredient detection
- AI-powered recipe generation using Grok Vision API
- Basic recipe display and saving
- Initial gamification system
- Social sharing capabilities