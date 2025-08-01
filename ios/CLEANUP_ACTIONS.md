# SnapChef Cleanup Actions Required

Based on the comprehensive code audit, here are the immediate cleanup actions needed:

## 1. Delete Unused Files ❌

### Archive Directory (Safe to Delete)
```bash
# Remove duplicate/unused views
rm -rf Archive/UnusedFeatures/
rm -rf Archive/DuplicateViews/

# These contain old versions replaced by active implementations
```

### Unused Feature Files
```bash
# Remove old gamification manager (replaced)
rm SnapChef/Features/Gamification/EnhancedGamificationManager.swift

# Remove stub implementations
rm SnapChef/Features/Gamification/TeamChallengeManager.swift
```

## 2. Fix Implementation Gaps 🔧

### Analytics (Choose One)
```bash
# Option A: Implement AnalyticsManager
# Create SnapChef/Core/Services/AnalyticsManager.swift with basic implementation

# Option B: Remove references
# Comment out line 38 in SnapChefApp.swift
# Remove AnalyticsService.swift and ChallengeAnalytics.swift
```

### CloudKit Configuration
```
1. Open Xcode
2. Select SnapChef target
3. Signing & Capabilities tab
4. Add CloudKit capability
5. Create container: iCloud.com.snapchef.app
6. Update CloudKitManager.swift with container
```

### Notifications
```bash
# Either implement or remove:
rm SnapChef/Features/Gamification/ChallengeNotificationManager.swift
rm SnapChef/Core/Services/GamificationNotificationService.swift
```

## 3. Add Missing Assets 🎨

### App Icons
```
1. Create 1024x1024 app icon
2. Use icon generator for all sizes
3. Add to Assets.xcassets/AppIcon.appiconset/
```

### Launch Screen
```
1. Create LaunchScreen.storyboard
2. Or use Info.plist launch screen configuration
```

## 4. Fix Build Warnings ⚠️

### Core Data Resources
```
1. Open Xcode
2. Select project
3. Build Phases
4. Copy Bundle Resources
5. Remove any .swift files listed
```

### Unused Variables
```swift
// In CameraView.swift:439
} else if case APIError.serverError(let statusCode, let message) = error {
// Change to:
} else if case APIError.serverError(_, let message) = error {

// In SubscriptionView.swift:183
// Add usage or change to:
for _ in await Transaction.currentEntitlements {

// In PremiumUpgradePrompt.swift:16
case missingFeature(_):
// Change to:
case missingFeature:
```

## 5. Complete Configurations 📝

### Subscription Setup
```
1. Complete App Store Connect agreements
2. Configure products in App Store Connect
3. Add StoreKit configuration file
4. Test in sandbox environment
```

### Push Notifications
```
1. Enable capability in Xcode
2. Create APNs certificates
3. Implement notification handlers
4. Test with development certificates
```

## 6. Code Organization 📁

### Move Models
```bash
# Move challenge-related models to Core/Models/
# Keep all data models in one place
```

### Consolidate Services
```bash
# Group related services
# Remove empty service files
```

## Quick Cleanup Script

```bash
#!/bin/bash
# cleanup.sh

echo "🧹 Starting SnapChef cleanup..."

# Remove archives
echo "Removing archived files..."
rm -rf Archive/

# Remove unused files
echo "Removing unused implementations..."
rm -f SnapChef/Features/Gamification/EnhancedGamificationManager.swift
rm -f SnapChef/Features/Gamification/TeamChallengeManager.swift
rm -f SnapChef/Features/Gamification/ChallengeNotificationManager.swift
rm -f SnapChef/Core/Services/GamificationNotificationService.swift

# Remove empty analytics if not implementing
read -p "Remove analytics references? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    rm -f SnapChef/Core/Services/AnalyticsService.swift
    rm -f SnapChef/Core/Services/ChallengeAnalytics.swift
    echo "Remember to comment out line 38 in SnapChefApp.swift"
fi

echo "✅ Cleanup complete!"
echo "📝 Don't forget to:"
echo "   - Fix Core Data build phase warnings in Xcode"
echo "   - Add app icons"
echo "   - Configure CloudKit"
echo "   - Fix unused variable warnings"
```

## Priority Order

1. **High**: Delete unused files (5 min)
2. **High**: Fix build warnings (10 min)
3. **Medium**: Configure CloudKit (30 min)
4. **Medium**: Add app icons (20 min)
5. **Low**: Implement analytics (2 hours)
6. **Low**: Complete notifications (2 hours)

---
Generated: January 31, 2025
Ready for cleanup sprint!