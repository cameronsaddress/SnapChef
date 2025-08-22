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

### Recent Changes
- **Migration Complete**: CloudKitAuthManager removed, using UnifiedAuthManager exclusively
- **CloudKit Schema Updated**: Added appleUserId, tiktokUserId, profilePictureAsset fields
- **Build Verified**: All compilation errors fixed, app builds successfully

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

## 🔄 Latest Updates (Aug 22, 2025)

### Authentication Migration Complete
- ✅ Removed CloudKitAuthManager completely
- ✅ All authentication through UnifiedAuthManager
- ✅ CloudKit schema updated with new fields
- ✅ Build verified and passing
- ✅ All 46 files updated to use UnifiedAuthManager

### CloudKit User Management
- CloudKitUser struct now in UnifiedAuthManager
- UserStatUpdates for profile updates
- Full social features support
- Activity feed integration

### Current Focus
- Unified authentication system working
- All CloudKit operations functional
- App builds without errors
- Ready for feature development