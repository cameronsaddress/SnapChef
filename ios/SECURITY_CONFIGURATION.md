# SnapChef Security Configuration Guide

## Overview

This document outlines how to securely configure API keys and sensitive data in the SnapChef iOS application. **All sensitive data must be stored in the iOS Keychain, never hardcoded in source code.**

## Critical Security Fixes Applied

### 1. Removed Hardcoded API Keys
- ❌ **REMOVED:** Hardcoded API key from `KeychainManager.swift:81`
- ❌ **REMOVED:** `"YOUR_API_KEY"` placeholder from `ChallengeService.swift:228`
- ❌ **REMOVED:** Hardcoded Google API key from `troubleshoot_with_gemini.py:16`

### 2. Fixed TikTok Configuration
- ❌ **REMOVED:** Hardcoded `TikTokClientSecret` from `Info.plist`
- ✅ **REPLACED:** With environment variable `$(TIKTOK_CLIENT_SECRET)`
- ❌ **REMOVED:** Hardcoded secrets from archived TikTok files

### 3. Enhanced KeychainManager
- ✅ **ADDED:** Secure storage methods for all sensitive data
- ✅ **ADDED:** Security audit functionality
- ✅ **ADDED:** Generic secure storage methods

## Secure Configuration Steps

### Step 1: Configure API Keys Securely

#### Option A: Using Xcode Build Configuration
1. Create environment variables in your Xcode scheme:
   - Edit Scheme > Run > Environment Variables
   - Add `SNAPCHEF_API_KEY` with your actual API key
   - Add `TIKTOK_CLIENT_SECRET` with your TikTok client secret

2. Access in code:
```swift
// Store API key securely on first launch
if let apiKey = ProcessInfo.processInfo.environment["SNAPCHEF_API_KEY"] {
    KeychainManager.shared.storeAPIKey(apiKey)
}
```

#### Option B: Manual Configuration (Recommended for Production)
```swift
// In your app's settings or onboarding flow
func configureAPIKey() {
    let apiKey = "your-secure-api-key-here"
    KeychainManager.shared.storeAPIKey(apiKey)
}

func configureTikTokSecret() {
    let secret = "your-tiktok-client-secret"
    _ = KeychainManager.shared.storeTikTokClientSecret(secret)
}
```

### Step 2: Environment Variables for Build Scripts

Create a `.env` file (add to `.gitignore`):
```bash
# .env (DO NOT COMMIT TO GIT)
TIKTOK_CLIENT_SECRET=your_actual_tiktok_secret
GOOGLE_GENERATIVE_AI_API_KEY=your_google_ai_key
SNAPCHEF_API_KEY=your_snapchef_api_key
```

For the troubleshoot script:
```bash
export GOOGLE_GENERATIVE_AI_API_KEY="your-key-here"
python3 troubleshoot_with_gemini.py
```

### Step 3: Update Your Build Process

#### Xcode Build Settings
1. Add a Run Script Phase:
```bash
# Load environment variables and inject into Info.plist
if [ -f "${SRCROOT}/.env" ]; then
    export $(cat ${SRCROOT}/.env | xargs)
fi

# Replace placeholder with actual secret
/usr/libexec/PlistBuddy -c "Set :TikTokClientSecret $TIKTOK_CLIENT_SECRET" "${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
```

#### CI/CD Configuration
For GitHub Actions or similar:
```yaml
env:
  TIKTOK_CLIENT_SECRET: ${{ secrets.TIKTOK_CLIENT_SECRET }}
  SNAPCHEF_API_KEY: ${{ secrets.SNAPCHEF_API_KEY }}
```

## Security Best Practices

### 1. Never Store in UserDefaults
❌ **WRONG:**
```swift
UserDefaults.standard.set("secret-api-key", forKey: "apiKey")
```

✅ **CORRECT:**
```swift
KeychainManager.shared.storeAPIKey("secret-api-key")
```

### 2. Use Secure Retrieval
```swift
// Safe API key retrieval
private func addAuthenticationHeaders(to request: inout URLRequest) {
    if let apiKey = KeychainManager.shared.getAPIKey() {
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    } else {
        print("⚠️ WARNING: No API key configured")
    }
}
```

### 3. Regular Security Audits
```swift
// Check for missing secrets
let missingSecrets = KeychainManager.shared.auditSecurityConfiguration()
if !missingSecrets.isEmpty {
    print("⚠️ Missing secrets: \(missingSecrets)")
}
```

### 4. Clear Secrets on Logout
```swift
func logout() {
    // Clear authentication token but keep API keys
    _ = KeychainManager.shared.deleteAuthToken()
}

func resetAllSecrets() {
    // Complete security reset
    KeychainManager.shared.clearAllSecrets()
}
```

## Available Secure Storage Methods

### KeychainManager Methods
```swift
// Generic storage
func store(value: String, forKey identifier: String) -> Bool
func getValue(forKey identifier: String) -> String?
func deleteValue(forKey identifier: String) -> Bool

// Specific methods
func storeAPIKey(_ key: String)
func getAPIKey() -> String?
func storeTikTokClientSecret(_ secret: String) -> Bool
func getTikTokClientSecret() -> String?
func storeAuthToken(_ token: String) -> Bool
func getAuthToken() -> String?

// Security utilities
func auditSecurityConfiguration() -> [String]
func clearAllSecrets()
```

## Migration Guide

### Updating Existing Code

1. **Replace hardcoded keys:**
```swift
// OLD (INSECURE)
let apiKey = "hardcoded-key"

// NEW (SECURE)
let apiKey = KeychainManager.shared.getAPIKey()
```

2. **Update Info.plist references:**
```swift
// OLD (INSECURE)
guard let secret = Bundle.main.object(forInfoDictionaryKey: "TikTokClientSecret") as? String else { return }

// NEW (SECURE)
guard let secret = KeychainManager.shared.getTikTokClientSecret() else { 
    print("⚠️ TikTok client secret not configured")
    return 
}
```

3. **Update authentication flows:**
```swift
// OLD (INSECURE)
UserDefaults.standard.set(token, forKey: "authToken")

// NEW (SECURE)
_ = KeychainManager.shared.storeAuthToken(token)
```

## Deployment Checklist

- [ ] All hardcoded secrets removed from source code
- [ ] Environment variables configured for build process
- [ ] Keychain storage implemented for all sensitive data
- [ ] `.env` file added to `.gitignore`
- [ ] CI/CD secrets configured
- [ ] Security audit passes: `KeychainManager.shared.auditSecurityConfiguration()`
- [ ] App Store submission includes no hardcoded secrets

## Emergency Response

If secrets are accidentally committed:

1. **Immediately rotate all exposed keys:**
   - Generate new TikTok client secret
   - Generate new API keys
   - Update server configurations

2. **Clean Git history:**
```bash
# Use git-filter-branch or BFG Repo-Cleaner to remove secrets from history
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch path/to/file/with/secrets' \
  --prune-empty --tag-name-filter cat -- --all
```

3. **Force push cleaned history:**
```bash
git push --force --all
git push --force --tags
```

4. **Update all team members and CI/CD systems**

## Contact

For security concerns or questions about this configuration, contact the development team.

---

**🔒 Security is everyone's responsibility. When in doubt, don't hardcode it.**