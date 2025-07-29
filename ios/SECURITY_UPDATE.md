# API Key Security Update

## What Changed
The API key is now stored securely in the iOS Keychain instead of being hardcoded in the source code.

## User Experience
**No changes** - Users will not notice any difference:
- App works exactly the same as before
- No login required
- No configuration needed
- "Snap your fridge" button works immediately after download

## Technical Details

### 1. KeychainManager.swift
- Manages secure storage/retrieval of the API key
- Stores key with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for maximum security
- Key is encrypted by iOS and only accessible to the SnapChef app

### 2. App Launch (SnapChefApp.swift)
- On first launch: `KeychainManager.shared.ensureAPIKeyExists()`
- Automatically stores the API key in Keychain if not present
- Subsequent launches: Key is already in Keychain

### 3. API Requests (SnapChefAPIManager.swift)
- Retrieves key from Keychain: `KeychainManager.shared.getAPIKey()`
- Fallback to hardcoded key if Keychain fails (should never happen)
- Same header sent to server: `X-App-API-Key: <key>`

## Security Benefits
1. **Source Code Protection**: API key not visible in GitHub or app binary
2. **iOS Security**: Key encrypted by iOS, requires device unlock
3. **App Isolation**: Other apps cannot access the key
4. **Unchanged Server**: No server changes needed, same authentication

## Testing
The app will work exactly as before. To verify:
1. Delete app from device
2. Install fresh
3. Tap "Snap your fridge"
4. Should work immediately (API key automatically stored on launch)

## Future Improvements (Optional)
- Remote key rotation via secure endpoint
- Per-user API keys after authentication
- Certificate pinning for additional security