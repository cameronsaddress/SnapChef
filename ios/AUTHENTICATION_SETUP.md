# SnapChef Authentication Setup

## Overview
SnapChef uses passwordless authentication with Google, Apple, and Facebook Sign-In. We never store user passwords - only their authentication tokens and basic profile information.

## Features Requiring Authentication
- **NO AUTH REQUIRED**: Basic recipe generation
- **AUTH REQUIRED**: Challenges, Leaderboard, Social Sharing, Teams, Streaks, Premium Features

## Setup Instructions

### 1. Apple Sign-In
1. Enable "Sign in with Apple" capability in Xcode:
   - Select SnapChef target → Signing & Capabilities
   - Click "+ Capability" → Add "Sign in with Apple"
2. No additional configuration needed - uses bundle identifier

### 2. Google Sign-In
1. Create a project in [Google Cloud Console](https://console.cloud.google.com)
2. Enable Google Sign-In API
3. Create OAuth 2.0 credentials (iOS application)
4. Download configuration file (`GoogleService-Info.plist`)
5. Add to Xcode project
6. Update `AuthConfiguration.swift` with your Client ID
7. Add URL scheme to Info.plist:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>YOUR_REVERSED_CLIENT_ID</string>
           </array>
       </dict>
   </array>
   ```

### 3. Facebook Sign-In
1. Create app in [Facebook Developer Console](https://developers.facebook.com)
2. Add iOS platform with bundle ID
3. Update `AuthConfiguration.swift` with App ID
4. Add to Info.plist:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>fb{YOUR_APP_ID}</string>
           </array>
       </dict>
   </array>
   <key>FacebookAppID</key>
   <string>{YOUR_APP_ID}</string>
   <key>FacebookDisplayName</key>
   <string>SnapChef</string>
   <key>LSApplicationQueriesSchemes</key>
   <array>
       <string>fbapi</string>
       <string>fb-messenger-share-api</string>
   </array>
   ```

## Backend Integration

The backend should expect the following authentication payloads:

### Apple Sign-In
```json
{
  "provider": "apple",
  "userId": "apple_user_id",
  "email": "user@example.com",
  "givenName": "John",
  "familyName": "Doe",
  "identityToken": "base64_encoded_token"
}
```

### Google Sign-In
```json
{
  "provider": "google",
  "userId": "google_user_id",
  "email": "user@example.com",
  "name": "John Doe",
  "idToken": "google_id_token"
}
```

### Facebook Sign-In
```json
{
  "provider": "facebook",
  "userId": "facebook_user_id",
  "email": "user@example.com",
  "name": "John Doe",
  "accessToken": "facebook_access_token"
}
```

## User Data Model
```swift
struct User {
    let id: String              // Unique user ID from backend
    let username: String        // Unique username for social features
    let email: String?          // Optional email
    let name: String?           // Display name
    let profileImageURL: String? // Avatar URL
    
    // Social features
    let totalPoints: Int
    let currentStreak: Int
    let challengesCompleted: Int
    
    // Privacy
    let isProfilePublic: Bool
    let showOnLeaderboard: Bool
}
```

## Privacy & Security
- We NEVER store passwords
- Authentication tokens are stored in Keychain
- Users can opt out of public leaderboards
- Email is optional and never shared publicly
- Username is the only public identifier

## Testing
1. Test each provider in development
2. Verify token validation with backend
3. Test username uniqueness checking
4. Verify auth required features show login prompt
5. Test skip/cancel flows for non-required features