# TikTok Developer Portal Setup Guide for SnapChef

*Last Updated: August 12, 2025*

## Step 1: Create TikTok Developer Account

### 1.1 Go to TikTok Developer Portal
1. Open your browser and go to: **https://developers.tiktok.com/**
2. Click **"Login"** in the top right corner
3. Choose login method:
   - Use your existing TikTok account (recommended)
   - Or create a new account

### 1.2 Complete Developer Registration
1. After login, you'll be prompted to register as a developer
2. Fill in required information:
   - **Developer Name**: Your name or company name
   - **Email**: Your contact email
   - **Phone Number**: For verification
   - **Country/Region**: Select your location
3. Accept the Developer Agreement
4. Click **"Register"**
5. Verify your email address (check your inbox)

## Step 2: Create Your App on TikTok

### 2.1 Access the App Dashboard
1. Once logged in, click **"Manage apps"** in the top menu
2. Click **"Create app"** button

### 2.2 Configure App Basic Information
Fill in the following:

```
App name: SnapChef
Description: AI-powered recipe generator that transforms fridge photos into personalized recipes with social sharing
Category: Lifestyle
Platform: iOS
Bundle ID: com.snapchefapp.app
App Store URL: [Leave blank for now, or add if published]
```

### 2.3 Add App Icon
1. Upload SnapChef app icon (1024x1024 PNG)
2. Use the icon from: `/SnapChef/Design/Assets.xcassets/AppIcon.appiconset/`

## Step 3: Add Products to Your App

### 3.1 Enable Share Kit
1. In your app dashboard, click **"Add products"**
2. Find **"Share Kit"** and click **"Add"**
3. Configure Share Kit settings:
   - Enable **"Share to TikTok"**
   - Enable **"Share to Stories"**

### 3.2 Configure iOS Settings
1. Under iOS configuration, you'll see:
   - **Client Key**: `aw[some-long-string]` (COPY THIS!)
   - **Client Secret**: `[another-long-string]` (COPY THIS!)
   - **App ID**: `[numeric-id]` (COPY THIS!)

2. Set Redirect URI:
   ```
   snapchef://tiktok/callback
   ```

### 3.3 Configure Permissions
Enable these permissions:
- ✅ Share Content
- ✅ Access Media Library
- ✅ Basic User Info (optional, for Login Kit)

## Step 4: Update Your iOS App

### 4.1 Add TikTok OpenSDK Package
1. Open your project in Xcode
2. Go to **File → Add Package Dependencies...**
3. Enter this URL:
   ```
   https://github.com/tiktok/tiktok-opensdk-ios
   ```
4. Click **"Add Package"**
5. Choose version: **Latest stable** (currently 5.x.x)
6. Select target: **SnapChef**
7. Click **"Add Package"**

### 4.2 Update TikTokSDKManager.swift
Replace the placeholder with your actual Client Key:

```swift
// In TikTokSDKManager.swift, line 17
private let clientKey = "awYOUR_ACTUAL_CLIENT_KEY_HERE"
```

### 4.3 Update Info.plist
Add these entries to your Info.plist:

```xml
<!-- TikTok Configuration -->
<key>TikTokAppID</key>
<string>YOUR_APP_ID_HERE</string>

<key>TikTokClientKey</key>
<string>YOUR_CLIENT_KEY_HERE</string>

<!-- Update CFBundleURLTypes (merge with existing) -->
<key>CFBundleURLTypes</key>
<array>
    <!-- Add this dict to existing array -->
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>awYOUR_CLIENT_KEY_HERE</string>
        </array>
        <key>CFBundleURLName</key>
        <string>tiktok</string>
    </dict>
</array>

<!-- Add these URL schemes if not already present -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <!-- Keep existing schemes and add: -->
    <string>tiktokopensdk</string>
    <string>tiktoksharesdk</string>
    <string>snssdk1233</string>
    <string>snssdk1180</string>
</array>
```

### 4.4 Update Keychain Storage (Secure)
Instead of hardcoding, store credentials securely:

```swift
// In TikTokSDKManager.swift
private var clientKey: String {
    // Store in Keychain for production
    KeychainManager.shared.getTikTokClientKey() ?? "YOUR_CLIENT_KEY"
}
```

## Step 5: Configure Universal Links (Optional but Recommended)

### 5.1 In Xcode
1. Select your project → **SnapChef** target
2. Go to **Signing & Capabilities** tab
3. Click **"+ Capability"**
4. Add **"Associated Domains"**
5. Add domain:
   ```
   applinks:www.tiktok.com
   ```

### 5.2 On Your Server
Create file at: `https://snapchef.app/.well-known/apple-app-site-association`

```json
{
    "applinks": {
        "apps": [],
        "details": [
            {
                "appID": "TEAM_ID.com.snapchefapp.app",
                "paths": [
                    "/oauth/*",
                    "/callback/*"
                ]
            }
        ]
    }
}
```

## Step 6: Initialize SDK in App

The SDK initialization is already set up in your code! The `SDKInitializer` will handle it automatically when the app launches.

## Step 7: Test Your Integration

### 7.1 Test on Simulator
1. Build and run the app
2. Navigate to a recipe
3. Tap share → TikTok
4. Should show "TikTok not installed" (expected on simulator)

### 7.2 Test on Real Device
1. Install TikTok app on your iPhone
2. Build and run SnapChef
3. Navigate to a recipe
4. Tap share → TikTok
5. Choose "Quick Post" or "Create Video"
6. Should open TikTok with content ready

## Step 8: Submit for Review (Production)

### 8.1 Testing Phase
During development, your app works in **sandbox mode**:
- Up to 50 test users
- Full functionality for testing
- No review needed

### 8.2 Production Submission
When ready for production:
1. Go to TikTok Developer Portal
2. Navigate to your app
3. Click **"Submit for review"**
4. Provide:
   - Test account credentials
   - Video demonstration of sharing flow
   - App Store link (when published)
5. Wait 3-5 business days for approval

## Common Issues & Solutions

### Issue: "Client Key not valid"
**Solution**: Make sure you're using the full key including the "aw" prefix

### Issue: "App not authorized"
**Solution**: Check that Bundle ID in TikTok portal matches your app exactly

### Issue: TikTok app doesn't open
**Solution**: Verify LSApplicationQueriesSchemes includes all TikTok schemes

### Issue: Content doesn't appear in TikTok
**Solution**: Ensure video/image is saved to photo library first

## Required Credentials Checklist

Copy these from TikTok Developer Portal:
- [ ] Client Key (starts with "aw")
- [ ] Client Secret
- [ ] App ID (numeric)

Update these files:
- [ ] TikTokSDKManager.swift (line 17)
- [ ] Info.plist (3 places)
- [ ] KeychainManager (optional, for production)

## Quick Copy-Paste Commands

### To find your Bundle ID:
```bash
grep PRODUCT_BUNDLE_IDENTIFIER SnapChef.xcodeproj/project.pbxproj | head -1
```

### To verify Info.plist changes:
```bash
grep -A2 "TikTokAppID\|TikTokClientKey" SnapChef/Info.plist
```

### To test URL schemes:
```bash
xcrun simctl openurl booted "tiktokopensdk://"
```

## Support Links

- **TikTok Developer Support**: https://developers.tiktok.com/support
- **SDK Documentation**: https://developers.tiktok.com/doc/share-kit-ios
- **SDK GitHub Issues**: https://github.com/tiktok/tiktok-opensdk-ios/issues
- **Developer Forum**: https://developers.tiktok.com/forum

## Next Steps After Setup

Once you've completed the setup:

1. **Test Basic Sharing**: Verify images and videos can be shared
2. **Test Deep Linking**: Ensure TikTok opens to the right screen
3. **Monitor Analytics**: Check TikTok Developer Portal for usage stats
4. **Implement Login Kit** (Optional): For user authentication
5. **Add Sound Kit** (Optional): For trending audio integration

---

**Estimated Time**: 30-45 minutes
**Difficulty**: Medium
**Prerequisites**: Apple Developer Account, TikTok Account