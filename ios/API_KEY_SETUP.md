# API Key Configuration Guide

## Overview
SnapChef uses secure API key management to protect sensitive credentials. API keys are never hardcoded in source code.

## Quick Setup for Developers

### 1. Initial Setup
```bash
# Run the setup script
./Scripts/setup-dev-environment.sh
```

### 2. Configure API Key in Xcode
1. Open `SnapChef.xcodeproj` in Xcode
2. Select the SnapChef scheme
3. Edit Scheme (⌘<)
4. Go to Run → Arguments → Environment Variables
5. Add: `SNAPCHEF_API_KEY` = `your-actual-api-key-here`

### 3. Verify Setup
Build and run the app. Check the console for:
- ✅ "API key verification successful" - Setup is correct
- ⚠️ "WARNING: No API key found" - Check your environment variable

## API Key Sources (Priority Order)

### Debug Builds:
1. **Environment Variable** (highest priority)
   - Set in Xcode scheme
   - `SNAPCHEF_API_KEY` environment variable

2. **Info.plist** 
   - Injected at build time
   - Used in CI/CD pipelines

3. **Keychain** (cached)
   - Stored after first successful load
   - Persists between app launches

### Release Builds:
1. **Info.plist Only**
   - Must be injected at build time
   - No environment variable access in production

## Security Best Practices

### DO:
- ✅ Use different API keys for dev/staging/production
- ✅ Rotate keys regularly
- ✅ Store keys in secure password manager
- ✅ Use environment variables in CI/CD

### DON'T:
- ❌ Hardcode keys in source code
- ❌ Commit .env files to git
- ❌ Share API keys in chat/email
- ❌ Use production keys in development

## CI/CD Configuration

### GitHub Actions Example:
```yaml
env:
  SNAPCHEF_API_KEY: ${{ secrets.SNAPCHEF_API_KEY }}
```

### Xcode Cloud:
1. Go to App Store Connect
2. Xcode Cloud → Manage Workflows
3. Environment Variables → Add `SNAPCHEF_API_KEY`

### Fastlane:
```ruby
ENV['SNAPCHEF_API_KEY'] = ENV['CI_SNAPCHEF_API_KEY']
```

## Troubleshooting

### "No API key found" Error:
1. Check environment variable is set in Xcode scheme
2. Verify .env file exists and has valid key
3. Clean build folder (⇧⌘K) and rebuild

### "Invalid API key format" Error:
- Key must be 20-100 characters
- No spaces or special characters
- Not a placeholder value

### API Calls Failing:
1. Verify key matches server configuration
2. Check network connectivity
3. Ensure key hasn't expired/been revoked

## Key Rotation

If an API key is compromised:

1. **Generate new key on server**
2. **Update in Xcode:**
   ```swift
   // In debug console:
   KeychainManager.shared.rotateAPIKey("new-key-here")
   ```
3. **Update CI/CD secrets**
4. **Revoke old key on server**

## Testing

Verify your setup:
```bash
# Check no hardcoded keys exist
grep -RIn 'let apiKey = ".*"' ios/SnapChef/App/SnapChefApp.swift
# Should return no results

# Build and check for warnings
xcodebuild -scheme SnapChef -configuration Debug build 2>&1 | grep "API"
```

## Support

If you need help with API key setup:
1. Check this documentation
2. Run `./Scripts/setup-dev-environment.sh`
3. Ask team lead for development API key
4. Never use production keys in development
