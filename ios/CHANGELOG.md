# SnapChef iOS Changelog

All notable changes to the SnapChef iOS app will be documented in this file.

## [Unreleased]

### February 3, 2025

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