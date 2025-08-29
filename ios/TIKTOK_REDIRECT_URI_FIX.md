# TikTok Redirect URI Configuration Fix

## Current Issue
The app is receiving error code 10028: "The redirect uri does not match registration records"

## What's Happening
1. The app is using redirect URI: `snapchef://tiktok/callback`
2. TikTok is correctly calling back to this URI
3. But TikTok's servers are rejecting it because it doesn't match what's registered

## Fix Required in TikTok Developer Portal

### Step 1: Login to TikTok Developer Portal
1. Go to https://developers.tiktok.com/
2. Login with your developer account
3. Navigate to "Manage apps"
4. Select your SnapChef app

### Step 2: Update OAuth Settings
1. Go to the **"Login Kit"** or **"OAuth"** section (may be under "Products")
2. Find the **"Redirect URIs"** or **"OAuth redirect URIs"** field
3. **REMOVE** any existing URIs like:
   - `snapchef://tiktok-auth-callback` (old, incorrect)
   - `snapchef://oauth/callback`
   - Any others

4. **ADD** exactly this URI:
   ```
   snapchef://tiktok/callback
   ```
   
5. Make sure there are NO trailing slashes or spaces
6. The URI must be EXACTLY: `snapchef://tiktok/callback`

### Step 3: Save and Wait
1. Click **Save** or **Update**
2. Wait 1-2 minutes for changes to propagate
3. Some portals require app review - if so, submit for review

### Step 4: Verify Settings
Double-check these are all correct:
- Bundle ID: `com.snapchefapp.app`
- URL Scheme: `snapchef` (in iOS settings)
- Redirect URI: `snapchef://tiktok/callback`
- Platform: iOS

## Testing After Fix
1. Kill the SnapChef app completely
2. Reopen and try TikTok authentication
3. Check console for debug logs starting with "🎬 TikTok:"

## Alternative URIs (if above doesn't work)
If TikTok requires a specific format, try these in order:
1. `snapchef://tiktok/callback` (current, should work)
2. `snapchef://oauth/callback` 
3. `snapchef://auth/callback`
4. `com.snapchefapp.app://tiktok/callback` (using bundle ID)

## Code Reference
The redirect URI is defined in:
- `/SnapChef/Core/Services/TikTokAuthManager.swift` line 29

## Important Notes
- The URI in the portal MUST match exactly what's in the code
- No http/https URIs - must be custom scheme
- Case sensitive - use lowercase
- The callback URL shows it's working: The app IS receiving callbacks at the right URI
- The issue is purely server-side validation in TikTok's system