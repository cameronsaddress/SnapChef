# Authentication System Simplification

## Overview

This document outlines the consolidation of SnapChef's multiple authentication systems into a single, unified `UnifiedAuthManager`. This simplification reduces complexity while maintaining all existing functionality.

## Before: Multiple Auth Systems

The app previously had several overlapping authentication components:

1. **CloudKitAuthManager** - Primary CloudKit authentication
2. **AuthenticationManager** - Legacy auth manager (incomplete)
3. **TikTokAuthManager** - TikTok OAuth implementation
4. **Progressive Auth System** - AnonymousUserProfile + KeychainProfileManager + AuthPromptTrigger
5. **Multiple UI Views** - CloudKitAuthView, AuthenticationView, ProgressiveAuthPrompt

### Problems with the Old System

- **Complexity**: Multiple managers with overlapping responsibilities
- **Inconsistent UX**: Different auth flows for different features
- **Maintenance burden**: Changes required updates across multiple files
- **User confusion**: Different prompts and flows for similar actions
- **Code duplication**: Similar auth logic scattered across components

## After: Unified Authentication System

### Core Components

1. **UnifiedAuthManager** - Single source of truth for all authentication
2. **UnifiedAuthView** - Simplified authentication UI
3. **SimpleProgressivePrompt** - Streamlined progressive authentication
4. **Migration helpers** - Easy transition from legacy systems

### Key Benefits

- **Single API**: One manager handles all auth needs
- **Consistent UX**: Unified auth flow across all features
- **Simplified maintenance**: Changes in one place
- **Clear responsibility**: No overlapping auth logic
- **Better testing**: Single auth system to test

## Migration Guide

### 1. Replace Manager References

**Before:**
```swift
@StateObject private var cloudKitAuth = CloudKitAuthManager.shared
@StateObject private var tikTokAuth = TikTokAuthManager.shared
@StateObject private var authPromptTrigger = AuthPromptTrigger.shared
```

**After:**
```swift
@StateObject private var unifiedAuth = UnifiedAuthManager.shared
```

### 2. Update Authentication Checks

**Before:**
```swift
if CloudKitAuthManager.shared.isAuthenticated {
    // Authenticated content
}
```

**After:**
```swift
if unifiedAuth.isAuthenticated {
    // Authenticated content
}
```

### 3. Simplify Auth Prompts

**Before:**
```swift
CloudKitAuthManager.shared.promptAuthForFeature(.challenges)
// OR
AuthPromptTrigger.shared.onFirstRecipeSuccess()
```

**After:**
```swift
unifiedAuth.promptAuthForFeature(.challenges) {
    // Completion handler
}
// OR
unifiedAuth.trackAnonymousAction(.recipeCreated) // Auto-triggers progressive prompts
```

### 4. Update Auth UI

**Before:**
```swift
.sheet(isPresented: $showAuth) {
    CloudKitAuthView(requiredFor: .challenges)
}
.sheet(isPresented: $showProgressiveAuth) {
    ProgressiveAuthPrompt()
}
```

**After:**
```swift
.sheet(isPresented: $unifiedAuth.showAuthSheet) {
    UnifiedAuthView(requiredFor: .challenges)
}
.sheet(isPresented: $showProgressivePrompt) {
    SimpleProgressivePrompt(context: .firstRecipe)
}
```

### 5. Track User Actions

**Before:**
```swift
// Scattered across AppState and multiple managers
appState.trackAnonymousAction(.recipeCreated)
AuthPromptTrigger.shared.onFirstRecipeSuccess()
```

**After:**
```swift
// Single, consistent API
unifiedAuth.trackAnonymousAction(.recipeCreated)
```

## Implementation Details

### UnifiedAuthManager Features

- **CloudKit Authentication**: Full Apple Sign-In support with user profiles
- **TikTok Integration**: OAuth flow with token management
- **Progressive Authentication**: Smart prompts based on user behavior
- **Anonymous Tracking**: Secure anonymous user profiling
- **Feature Gating**: Consistent auth requirements across features
- **Migration Support**: Seamless transition from legacy systems

### Progressive Authentication

The unified system includes intelligent progressive authentication:

1. **Anonymous Tracking**: User actions tracked securely in Keychain
2. **Smart Triggers**: Prompts shown at optimal moments:
   - First recipe creation
   - Viral content generation
   - Social feature exploration
   - Challenge interest
3. **Respectful UX**: Timing constraints and user preferences honored
4. **Context-Aware**: Different prompts for different user journeys

### TikTok Integration

TikTok authentication is now seamlessly integrated:

- **Unified Flow**: Same UI for Apple Sign-In and TikTok
- **Token Management**: Automatic refresh and error handling
- **Account Linking**: TikTok can be linked to existing CloudKit accounts
- **Graceful Degradation**: App works with or without TikTok connection

## Usage Examples

### Basic Authentication

```swift
struct MyView: View {
    @StateObject private var unifiedAuth = UnifiedAuthManager.shared
    
    var body: some View {
        VStack {
            if unifiedAuth.isAuthenticated {
                Text("Welcome, \(unifiedAuth.currentUser?.displayName ?? "Chef")!")
            } else {
                Button("Sign In") {
                    unifiedAuth.promptAuthForFeature(.socialSharing)
                }
            }
        }
        .sheet(isPresented: $unifiedAuth.showAuthSheet) {
            UnifiedAuthView(requiredFor: .socialSharing)
        }
    }
}
```

### Progressive Authentication

```swift
struct CameraView: View {
    @StateObject private var unifiedAuth = UnifiedAuthManager.shared
    
    private func captureRecipe() {
        // Generate recipe...
        
        // Track action - may trigger progressive prompt
        unifiedAuth.trackAnonymousAction(.recipeCreated)
    }
}
```

### TikTok Integration

```swift
struct VideoShareView: View {
    @StateObject private var unifiedAuth = UnifiedAuthManager.shared
    
    private func shareToTikTok() {
        if unifiedAuth.tikTokUser == nil {
            Task {
                try await unifiedAuth.signInWithTikTok()
                // Now connected, proceed with sharing
            }
        } else {
            // Already connected, share directly
        }
    }
}
```

## Files Created/Modified

### New Files
- `Core/Services/UnifiedAuthManager.swift` - Main unified auth manager
- `Core/Services/UnifiedAuthManager+Migration.swift` - Migration helpers
- `Features/Authentication/UnifiedAuthView.swift` - Simplified auth UI
- `Features/Authentication/SimpleProgressivePrompt.swift` - Streamlined progressive prompts
- `Examples/UnifiedAuthIntegrationExample.swift` - Integration examples

### Modified Files
- `Core/ViewModels/AppState.swift` - Updated to use UnifiedAuthManager
- Various view files - Migrated to use unified auth system

### Deprecated (Can be removed after migration)
- `Core/Services/AuthenticationManager.swift` - Legacy auth manager
- `Features/Authentication/AuthenticationView.swift` - Legacy auth UI
- `Features/Authentication/ProgressiveAuthPrompt.swift` - Complex progressive auth
- `Features/Authentication/AuthPromptTrigger.swift` - Separate trigger system

## Migration Checklist

- [ ] Replace all `CloudKitAuthManager.shared` with `UnifiedAuthManager.shared`
- [ ] Update auth UI sheets to use `UnifiedAuthView`
- [ ] Migrate progressive auth triggers to `trackAnonymousAction()`
- [ ] Test all auth flows (Apple Sign-In, TikTok, Progressive)
- [ ] Update feature gating to use `isAuthRequiredFor()`
- [ ] Remove legacy auth manager references
- [ ] Clean up deprecated auth files
- [ ] Update documentation and comments

## Testing Strategy

1. **Unit Tests**: Test UnifiedAuthManager functionality
2. **Integration Tests**: Verify auth flows across features
3. **UI Tests**: Test authentication user journeys
4. **Migration Tests**: Ensure smooth transition from legacy systems
5. **Edge Cases**: Test network failures, token expiry, user cancellation

## Rollback Plan

If issues arise during migration:

1. Legacy managers are preserved (marked deprecated)
2. Individual views can be reverted to use legacy managers
3. Feature flags can control which auth system is used
4. Database/Keychain data remains compatible

## Performance Impact

- **Positive**: Reduced memory usage (fewer auth managers)
- **Positive**: Faster auth checks (single source of truth)
- **Positive**: Simpler state management
- **Neutral**: No impact on auth performance
- **Negative**: None expected

## Security Considerations

- All existing security measures maintained
- Keychain storage unchanged
- Token management improved with better error handling
- Anonymous data handling enhanced
- No new security risks introduced

---

**Next Steps:**
1. Review and test the unified authentication system
2. Begin migration of key views (CameraView, ChallengeHubView, etc.)
3. Update any remaining legacy auth references
4. Remove deprecated authentication files
5. Update app documentation to reflect simplified auth flow
