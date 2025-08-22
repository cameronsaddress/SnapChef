# CloudKit Schema Permission Audit

## Summary
After analyzing the CloudKit schema and codebase, I've identified multiple record types that are missing the required `GRANT CREATE TO "_icloud"` permission. This prevents authenticated users from creating these records, causing failures in the app.

## ✅ Record Types WITH Correct Permissions
These already have `GRANT CREATE TO "_icloud"`:
- Activity ✅
- Challenge ✅
- Follow ✅
- Recipe ✅
- RecipeComment ✅
- RecipeGeneration ✅
- RecipeLike ✅
- RecipeRating ✅
- RecipeView ✅
- StreakAchievement ✅
- Team ✅
- User ✅
- UserProfile ✅
- Leaderboard ✅

## ❌ Record Types MISSING CREATE Permission
These need `GRANT CREATE TO "_icloud"` added:

### Critical - Used in Core Features:
1. **Achievement** - Created when users earn badges/complete challenges
   - Used in: CloudKitChallengeManager.swift, GamificationManager.swift
   - Impact: Users can't earn achievements

2. **UserChallenge** - Created when users join challenges
   - Used in: CloudKitSyncService.swift, CloudKitManager.swift
   - Impact: Users can't participate in challenges

3. **CoinTransaction** - Created for virtual currency transactions
   - Used in: CloudKitManager.swift
   - Impact: Users can't earn/spend coins

### Analytics & Tracking (May be app-only):
4. **AnalyticsEvent** - App analytics tracking
5. **AppSession** - Session tracking
6. **CameraSession** - Camera usage tracking
7. **DeviceSync** - Device synchronization
8. **ErrorLog** - Error tracking
9. **FeatureUsage** - Feature usage analytics
10. **SearchHistory** - Search tracking
11. **SocialShare** - Social sharing tracking

### User Preferences & Data:
12. **FoodPreference** - User food preferences
13. **NotificationPreference** - Notification settings
14. **UserPreferences** - General user preferences
15. **PhotoModeration** - Photo moderation records

### Streak System:
16. **UserStreak** - User streak tracking
17. **StreakFreeze** - Streak freeze purchases
18. **StreakHistory** - Historical streak data
19. **StreakLeaderboard** - Streak leaderboard entries
20. **StreakPowerUp** - Streak power-up purchases
21. **TeamStreak** - Team streak tracking

### Team Features:
22. **TeamMessage** - Team chat messages

## 🔧 Required CloudKit Dashboard Changes

Add the following permission to each record type listed above:
```
GRANT CREATE TO "_icloud"
```

## Priority Recommendations

### High Priority (Core Features):
1. Achievement
2. UserChallenge
3. CoinTransaction
4. UserStreak

### Medium Priority (Enhanced Features):
5. UserPreferences
6. FoodPreference
7. NotificationPreference
8. TeamMessage
9. Other streak-related types

### Low Priority (Analytics - Consider if needed):
- Analytics types might only need app-level creation
- Consider if these should be created by users or only by the app backend

## Code Locations Creating These Records

### Achievement
- `CloudKitChallengeManager.swift:281`
- `GamificationManager.swift:773`
- `CloudKitModules/ChallengeModule.swift:257`

### UserChallenge
- `CloudKitSyncService.swift` (multiple locations)
- `CloudKitManager.swift`

### CoinTransaction
- `CloudKitManager.swift:967`

### UserStreak
- `CloudKitSyncService.swift`
- Streak management features

## Testing After Permission Changes

After adding permissions, test:
1. Earning an achievement
2. Joining a challenge
3. Earning/spending coins
4. Starting/maintaining streaks
5. Saving user preferences
6. Team messaging (if team features are active)

## Notes
- The `Users` record type in the schema appears to be legacy (only has roles field)
- The app primarily uses the `User` record type for user profiles
- Some analytics record types might be intended for server-side creation only