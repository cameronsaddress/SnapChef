# CloudKit Authentication Setup

## Overview
SnapChef uses CloudKit for all user authentication and data storage. No passwords are stored anywhere - users sign in with Apple, Google, or Facebook, and all data is stored in iCloud.

## Benefits of CloudKit-Only Approach
- ✅ **No backend costs** - Apple provides free infrastructure
- ✅ **No password storage** - OAuth only, no security risks
- ✅ **Automatic sync** - Works across all user's devices
- ✅ **Offline support** - CloudKit handles sync when online
- ✅ **Real-time updates** - Push notifications for changes
- ✅ **Privacy built-in** - Apple's privacy standards

## Setup Instructions

### 1. Enable CloudKit in Xcode
1. Select SnapChef target → Signing & Capabilities
2. Click "+ Capability" → Add "CloudKit"
3. Select or create container: `iCloud.com.snapchefapp.app`

### 2. Import Schema to CloudKit Dashboard
1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com)
2. Select your container
3. Go to Schema → Import Schema
4. Upload `SnapChef_CloudKit_Schema.ckdb`
5. Deploy to Production when ready

### 3. Enable Sign in with Apple
1. In Xcode: Signing & Capabilities → Add "Sign in with Apple"
2. No additional configuration needed

### 4. Test Authentication Flow
1. Run app on device/simulator
2. Navigate to Challenges tab
3. Sign in with Apple ID
4. Choose username
5. Start using social features

## CloudKit Record Types

### User Record
- **Record Name**: Uses provider ID (e.g., Apple user ID)
- **Username**: Unique, lowercase, 3-20 chars
- **Auth Provider**: "apple", "google", or "facebook"
- **Stats**: Points, streaks, challenges completed
- **Privacy**: Profile visibility, leaderboard opt-in

### How It Works
```swift
// 1. User signs in with Apple
SignInWithAppleButton { result in
    // 2. Get Apple user ID (no password!)
    let userID = result.credential.user
    
    // 3. Create/fetch user in CloudKit
    let record = CKRecord(recordType: "User", recordID: userID)
    
    // 4. User is authenticated!
}
```

## Authentication Flow
1. **New User**:
   - Sign in with Apple/Google/Facebook
   - User record created in CloudKit
   - Prompted to choose unique username
   - Gets 100 starting coins
   
2. **Existing User**:
   - Sign in with same provider
   - User record fetched from CloudKit
   - Last login updated
   - Continues where they left off

## Features Without Auth
- ✅ Basic recipe generation
- ✅ Viewing app content
- ✅ Using AI to analyze fridge

## Features Requiring Auth
- 🔐 Joining challenges
- 🔐 Viewing leaderboard
- 🔐 Creating/joining teams
- 🔐 Tracking streaks
- 🔐 Sharing recipes socially
- 🔐 Premium features

## Privacy & Security
- **No passwords** stored anywhere
- **OAuth tokens** never leave device
- **User IDs** are provider-specific
- **Email** is optional and private
- **Username** is the only public identifier
- **Privacy controls** for profile/leaderboard

## Testing Checklist
- [ ] Sign in with Apple works
- [ ] Username selection appears for new users
- [ ] Username uniqueness checking works
- [ ] User stats update in CloudKit
- [ ] Sign out clears local data
- [ ] Re-sign in restores user data
- [ ] Auth required features show login
- [ ] Basic recipes work without auth

## Troubleshooting

### "No iCloud account" error
- User must be signed into iCloud on device
- Simulator: Device → iCloud → Sign in

### Username already taken
- CloudKit enforces uniqueness
- App suggests alternatives

### Sign in not working
- Check CloudKit container is correct
- Verify capabilities are enabled
- Check network connection

## Future Enhancements
- [ ] Add Google Sign-In (when package added)
- [ ] Add Facebook Sign-In (when SDK added)
- [ ] Link multiple auth providers
- [ ] Account recovery options
- [ ] Export user data