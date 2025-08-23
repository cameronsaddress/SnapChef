# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
SnapChef is an iOS app that transforms fridge/pantry photos into personalized recipes using AI (Gemini default, Grok fallback). Features include unified authentication (Apple/Google/Facebook/TikTok), progressive premium tiers, intelligent photo storage, TikTok video generation, and comprehensive gamification.

## 🏗️ CURRENT APP ARCHITECTURE

### Authentication System
- **UnifiedAuthManager**: Single authentication manager for all auth flows
  - Sign in with Apple/Google/Facebook/TikTok
  - CloudKit user record management  
  - Progressive authentication with anonymous tracking
  - Username and profile management
- **Progressive Authentication**: Anonymous users tracked via Keychain
- **User Lifecycle**: Honeymoon (7 days unlimited) → Trial (14 days, 10/day) → Standard (5/day)

### Core Services
- **UnifiedAuthManager** - All authentication and user management ✅
- **SnapChefAPIManager** - API communication (Gemini/Grok)
- **PhotoStorageManager** - Centralized photo storage with cleanup
- **UserLifecycleManager** - Progressive premium phase tracking
- **UsageTracker** - Daily limits and usage monitoring
- **KeychainProfileManager** - Anonymous user persistence
- **GamificationManager** - Points, badges, challenges
- **TikTokAuthManager** - TikTok OAuth integration
- **ViralVideoEngine** - TikTok video generation
- **ErrorHandler** - Comprehensive error handling

### Data Models
- **CloudKitUser** - User profile (defined in UnifiedAuthManager)
- **Recipe** - Core recipe model with CloudKit integration
- **Challenge** - Gamification challenges
- **AnonymousUserProfile** - Anonymous user tracking
- **UserStatUpdates** - User statistics updates

### Core Views (DO NOT CREATE NEW WITHOUT PERMISSION)
1. **ContentView.swift** - Main tab navigation (5 tabs)
2. **HomeView.swift** - Landing page with challenges
3. **CameraView.swift** - Dual photo capture (fridge + pantry)
4. **RecipeResultsView.swift** - Recipe display
5. **RecipesView.swift** - Saved recipes with CloudKit sync
6. **FeedView.swift** - Social feed
7. **ProfileView.swift** - User profile and settings

## 🚨 CRITICAL RULES

### 1. Build Verification
```bash
# THIS IS THE ONLY BUILD COMMAND TO USE
xcodebuild -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Debug build 2>&1
```
- MUST use iPhone 16 Pro simulator
- The `2>&1` is REQUIRED for error output
- ALWAYS test builds after code changes

### 2. File Operations
- **NEVER use echo/cat to write files** - Use Write, Edit, MultiEdit tools
- **ALWAYS modify existing files** when possible
- **NEVER create new files** without explicit permission

### 3. Swift 6 Compliance
- Strict concurrency checking required
- Proper actor isolation and Sendable conformance
- Use @MainActor appropriately
- Modern async/await patterns

### 4. Local-First Architecture
```
Photo Capture → API Generation → Local Save → Background CloudKit Upload
```
- Save locally FIRST, sync to CloudKit in background
- Never block UI for CloudKit operations
- App must work fully offline

### 5. CloudKit Database Rules
- Recipes → PUBLIC database
- User profiles → PUBLIC database (for social features)
- Activities/Social → PUBLIC database
- Never use privateDB for shared content

## 📁 Project Structure

### Features/
- **Camera/** - Photo capture and processing
- **Recipes/** - Recipe display and management
- **Sharing/** - Social media integration
- **Gamification/** - Points, challenges, achievements
- **Authentication/** - Sign in flows
- **Social/** - Following, feed, activity
- **Detective/** - Recipe detective features
- **Profile/** - User profile views

### Core/
- **Services/** - All managers and services
- **Models/** - Data models
- **ViewModels/** - View models (AppState)
- **Utilities/** - Helper functions
- **Configuration/** - App configuration

## 🔧 Common Tasks

### Testing Build
```bash
cd /Users/cameronanderson/SnapChef/snapchef/ios
xcodebuild -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Debug build 2>&1
```

### Committing Changes
```bash
git add -A
git commit -m "Type: Brief description

- Detail 1
- Detail 2"
git push origin main
```

### Adding Authentication
All authentication goes through UnifiedAuthManager:
- `UnifiedAuthManager.shared.signInWithApple()`
- `UnifiedAuthManager.shared.currentUser` for user state
- `UnifiedAuthManager.shared.isAuthenticated` for auth status

### Working with CloudKit
- Use UnifiedAuthManager for user operations
- Use CloudKitRecipeManager for recipe operations
- Use CloudKitChallengeManager for challenge operations

### Social Follow Implementation
```swift
// Follow a user
try await UnifiedAuthManager.shared.followUser(userID: "user_id")

// Unfollow a user
try await UnifiedAuthManager.shared.unfollowUser(userID: "user_id")

// Check if following
let isFollowing = await UnifiedAuthManager.shared.isFollowing(userID: "user_id")

// Refresh current user data (updates counts)
try await UnifiedAuthManager.shared.refreshCurrentUserData()
```
**Important**: Always refresh user data when views appear to show accurate follower/following counts

## 🚫 Anti-Patterns to Avoid

❌ Creating duplicate authentication managers
❌ Uploading to CloudKit before local save
❌ Blocking UI during CloudKit operations
❌ Creating new files for existing functionality
❌ Using privateDB for public content
❌ Ignoring Swift 6 concurrency warnings

## 🎯 Current State

### What's Working
✅ Unified authentication with all providers
✅ CloudKit user management and sync
✅ Recipe generation with Gemini/Grok
✅ Photo storage and management
✅ TikTok video generation
✅ Progressive premium features
✅ Gamification system

### Recent Changes (Aug 23, 2025)
- **Migration Complete**: CloudKitAuthManager removed, using UnifiedAuthManager exclusively
- **CloudKit Schema Updated**: Added appleUserId, tiktokUserId, profilePictureAsset fields
- **Build Verified**: All compilation errors fixed, app builds successfully
- **Social Feed Fixed**: Username display and duplicate activities resolved
- **New User Experience**: Fixed username setup errors for first-time users
- **Share Consistency**: All share buttons use BrandedSharePopup with auto-feed sharing

## 📝 API Integration

### Server Details
- **Base URL**: `https://snapchef-server.onrender.com`
- **Endpoint**: `/analyze_fridge_image`
- **Method**: POST (multipart/form-data)
- **Auth Header**: X-App-API-Key

### Request Fields
```swift
- image_file: UIImage as JPEG (required)
- pantry_image: UIImage as JPEG (optional)
- session_id: UUID string
- dietary_restrictions: JSON array
- food_type: String
- difficulty_preference: String
- number_of_recipes: String (default "3")
```

## 🔐 Security Notes

- API keys stored in Keychain
- No sensitive data in UserDefaults
- Validate all user inputs
- Handle auth errors gracefully
- Use proper error handling

## 💡 Development Tips

### Performance
- Compress images before upload (80% JPEG)
- Cache API responses appropriately
- Profile memory usage regularly
- Use .drawingGroup() for complex animations

### Debugging
1. Check API key in Keychain
2. Verify server status
3. Check network logs
4. Monitor CloudKit console

### Code Style
- SwiftUI declarative syntax
- Extract reusable components
- Keep views under 200 lines
- Use meaningful variable names
- Add MARK comments for organization

## 📱 Device Support

- **Minimum iOS**: 16.0
- **Target Device**: iPhone
- **Recommended Test Device**: iPhone 16 Pro Simulator
- **Swift Version**: 6.0

## 🚀 Quick Start

1. Open project in Xcode
2. Select iPhone 16 Pro simulator
3. Build and run (⌘R)
4. Test with sample fridge photos

## 📄 Documentation

- **AI_DEVELOPER_GUIDE.md** - Comprehensive AI assistant guide
- **COMPLETE_CODE_TRACE.md** - App flow analysis
- **FILE_USAGE_ANALYSIS.md** - File usage status

## 🔄 Latest Updates (Aug 23, 2025)

### Social Follow System (Fixed Aug 23)
- ✅ Follow/unfollow properly updates CloudKit User records
- ✅ Both follower and following counts update immediately
- ✅ Counts persist correctly after app restart
- ✅ All views refresh to show accurate counts
- ✅ Follow relationships stored in CloudKit Follow records

#### How Follow System Works:
1. **Follow Action**: Creates Follow record + updates both users' counts in CloudKit
2. **Unfollow Action**: Soft deletes Follow record (isActive=0) + updates counts
3. **Count Updates**: Current user's followingCount and target user's followerCount both updated
4. **Data Refresh**: Views call `refreshCurrentUserData()` on appear to show latest counts
5. **Persistence**: All counts stored in CloudKit User records, survive app restarts

### Social Sharing & Feed System (Fixed Aug 23)
- ✅ BrandedSharePopup used consistently across all share buttons
- ✅ Automatic sharing to followers' feeds when popup opens
- ✅ Activity feed displays correct usernames (not "Anonymous User")
- ✅ Duplicate activity IDs filtered out in feed
- ✅ User's own activities appear in their feed

### CloudKit User Management (Fixed Aug 23)
- ✅ Username setup for new users works correctly
- ✅ Proper handling of CloudKit record IDs with "user_" prefix
- ✅ CloudKitUser strips prefix internally for consistency
- ✅ Better error handling with informative messages

### CloudKit Debug System Complete
- ✅ Comprehensive debug logging for all CloudKit operations
- ✅ Error-only logging in debug mode (no success spam)
- ✅ Critical error assertions for immediate debugging
- ✅ Recipe ownership system fixed - proper user association
- ✅ Added `debugListAllRecipes()` method for troubleshooting

### ProfileView CloudKit Integration (NEEDS FIXING)
**Components Not Syncing with CloudKit:**

1. **Collection Progress Tile**
   - Should show: recipesCreated, recipesShared, challengesCompleted
   - Currently: Not pulling from CloudKit User record
   
2. **Active Challenges Tile**  
   - Should show: Active challenges from UserChallenge records
   - Currently: Not querying CloudKit for user's challenges
   
3. **Achievements Tile**
   - Should show: Unlocked achievements from Achievement records
   - Currently: Not syncing with CloudKit

4. **Streaks Sheet (All components broken):**
   - **Daily Snap**: Should sync with UserStreak (streakType: "daily")
   - **Recipe Creator**: Should sync with UserStreak (streakType: "recipe")
   - **Challenge Master**: Should sync with UserStreak (streakType: "challenge")
   - **Social Chef**: Should sync with UserStreak (streakType: "social")
   - **Multiplier**: Should persist in UserStreak.multiplier
   - **Longest Streak**: Should sync with UserStreak.longestStreak
   - **Total Active Days**: Should sync with UserStreak.totalDaysActive

### CloudKit Schema Key Fields
```
User Record:
- recipesCreated (INT64)
- challengesCompleted (INT64)
- currentStreak (INT64)
- totalPoints (INT64)
- followerCount (INT64)

UserStreak Record:
- streakType (STRING)
- currentStreak (INT64)
- longestStreak (INT64)
- lastActivityDate (TIMESTAMP)
- multiplier (DOUBLE)
- totalDaysActive (INT64)

Achievement Record:
- type (STRING)
- userID (STRING)
- earnedAt (TIMESTAMP)
- points (INT64)

UserChallenge Record:
- status (STRING)
- progress (DOUBLE)
- completedAt (TIMESTAMP)
```

### Authentication System
- ✅ All authentication through UnifiedAuthManager
- ✅ CloudKit user record management working
- ✅ Progressive authentication with anonymous tracking

### Current Priority
1. Fix ProfileView CloudKit sync
2. Implement streak persistence
3. Achievement tracking
4. Challenge progress sync