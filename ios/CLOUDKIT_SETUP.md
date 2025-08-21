# CloudKit Setup Guide for SnapChef

## Current Issues & Solutions

### 1. CloudKit Query Field Limitations ("Field not queryable" errors)

**CRITICAL ISSUE FIXED:** Many queries were failing because the `userID` field and other fields are not marked as "Queryable" in the CloudKit schema.

#### Root Cause:
CloudKit requires fields to be explicitly marked as "Queryable" in the schema to be used in NSPredicate queries. Using non-queryable fields results in runtime errors.

#### Solution Implemented:
- **Replaced userID-based queries** with "fetch all and filter locally" approach
- **Updated all CloudKit service classes** to use `NSPredicate(value: true)` followed by local filtering
- **Enhanced CollectionProgressView** with proper refresh mechanisms
- **Fixed Achievement loading** by updating query methods

#### Files Updated:
- `CloudKitUserManager.swift` - Fixed achievement queries
- `CloudKitSyncService.swift` - Fixed user challenge queries
- `ProfileView.swift` - Fixed achievement and challenge loading
- `GamificationManager.swift` - Fixed challenge progress sync
- `CloudKitModules/ChallengeModule.swift` - Fixed user challenge queries
- `CloudKitModules/StreakModule.swift` - Fixed user streak queries
- `CloudKitModules/UserModule.swift` - Fixed user profile queries
- `CloudKitModules/DataModule.swift` - Fixed food preference queries

#### Performance Note:
While "fetch all and filter locally" is less efficient than server-side filtering, it's necessary when fields aren't queryable. For production, consider:
1. Making key fields queryable in CloudKit schema
2. Using alternative query patterns with queryable fields
3. Implementing client-side caching for better performance

### 2. CloudKit Permission Errors ("CREATE operation not permitted")

The app is encountering permission errors when trying to create records in CloudKit. This needs to be fixed in the CloudKit Dashboard.

#### Solution Steps:

1. **Open CloudKit Dashboard**
   - Go to https://icloud.developer.apple.com/dashboard
   - Sign in with your Apple Developer account
   - Select the SnapChef app container: `iCloud.com.snapchefapp.app`

2. **Configure Schema Permissions**
   - Navigate to "Schema" → "Record Types"
   - For each of these record types, configure permissions:
     - `Challenge`
     - `Team`
     - `Leaderboard`
     - `UserActivity`
     - `RecipeComment` **[CRITICAL FIX NEEDED]**
   
3. **Set Public Database Permissions**
   For the **Public Database**:
   - Click on each record type listed above
   - Go to "Security Roles" tab
   - Set permissions for "World" (unauthenticated users):
     - **Read**: ✅ Allowed
     - **Write**: ❌ Not Allowed (for security)
   - Set permissions for "Authenticated" users (_icloud):
     - **Read**: ✅ Allowed
     - **Write**: ✅ Allowed (for Challenge, Team, Leaderboard, **RecipeComment**)
   - Set permissions for "Creator":
     - **Read**: ✅ Allowed
     - **Write**: ✅ Allowed
     - **Delete**: ✅ Allowed

   **CRITICAL: RecipeComment Record Type Permissions**
   - The `RecipeComment` record type must have **CREATE** permission for authenticated users (_icloud)
   - Without this permission, users cannot create comments on recipes
   - Ensure the following permissions are set for `RecipeComment`:
     - World (unauthenticated): Read ✅, Write ❌
     - Authenticated (_icloud): **Create ✅**, Read ✅, Write ✅ 
     - Creator: Read ✅, Write ✅, Delete ✅

4. **Deploy Schema to Production**
   - After making changes, click "Deploy Schema Changes..."
   - Deploy to Production environment
   - This may take a few minutes to propagate

### 2. StoreKit Configuration Issues

The app can't load subscription products. This needs App Store Connect configuration.

#### Solution Steps:

1. **Configure In-App Purchases in App Store Connect**
   - Log in to App Store Connect
   - Select your app
   - Go to "Monetization" → "In-App Purchases"
   - Create two auto-renewable subscriptions:
     - Product ID: `com.snapchef.premium.monthly`
     - Product ID: `com.snapchef.premium.yearly`

2. **Configure Subscription Group**
   - Create a subscription group (e.g., "SnapChef Premium")
   - Add both subscriptions to this group
   - Set up pricing for each tier

3. **Configure StoreKit Configuration File (for testing)**
   - In Xcode, create a StoreKit Configuration file
   - Add your products with matching IDs
   - Enable the configuration in your scheme for testing

### 3. Record Not Found Errors

Some records referenced in the app don't exist yet. These will be created as users interact with the app.

#### Expected Initial Errors (Safe to Ignore):
- User profile not found (created on first sign-in)
- Recipe count records not found (created when recipes are saved)
- User activity records not found (created on first activity)

### 4. Challenge Upload Issues

The app is trying to upload challenges to the public database but lacks permissions.

#### Temporary Solution:
Challenges are now stored locally and will sync once permissions are configured.

#### Permanent Solution:
1. **Option A: Admin-Only Challenge Creation**
   - Keep public database write-restricted
   - Create challenges through CloudKit Dashboard manually
   - App only reads challenges from public database

2. **Option B: User-Generated Challenges (Current Implementation)**
   - Allow authenticated users to create challenges
   - Implement moderation system
   - Add reporting mechanism for inappropriate content

## Testing CloudKit Integration

After completing the setup:

1. **Test Authentication**
   ```swift
   // Sign in with Apple ID
   // Check console for "✅ iCloud available"
   ```

2. **Test Challenge Sync**
   ```swift
   // Create a local challenge
   // Check console for "✅ Uploaded challenge to CloudKit"
   ```

3. **Test Recipe Sync**
   ```swift
   // Save a recipe
   // Check console for "✅ Recipe saved to CloudKit"
   ```

## CloudKit Schema Reference

### Required Record Types

#### Recipe (UPDATED - Enhanced Fields for ALL Recipe Sources)
- `id` (String) - Recipe UUID
- `title` (String) - Recipe name
- `description` (String) - Brief description
- `ingredients` (String) - JSON encoded array of ingredients
- `instructions` (String) - JSON encoded array of instructions (now with detailed steps, temperatures, timing)
- `nutrition` (String) - JSON encoded nutrition object
- `tags` (List<String>) - Recipe tags
- `cookingTime` (Int64) - Cook time in minutes
- `prepTime` (Int64) - Prep time in minutes
- `servings` (Int64) - Number of servings
- `difficulty` (String) - easy/medium/hard
- `cuisine` (String) - Cuisine type
- `mealType` (String) - Meal type
- `createdAt` (Date) - Creation timestamp
- `isPublic` (Int64) - 1 for public, 0 for private
- `fromLLM` (Int64) - 1 if AI generated (both Fridge Snap and Detective)
- `likeCount` (Int64) - Number of likes
- `viewCount` (Int64) - View count
- `shareCount` (Int64) - Share count
- `beforePhotoAsset` (Asset) - Fridge/pantry photo (Fridge Snap) or original dish photo (Detective)
- `afterPhotoAsset` (Asset) - Completed meal photo
- **ENHANCED FIELDS (Used by BOTH Fridge Snap and Detective):**
- `isDetectiveRecipe` (Int64) - 1 if from Detective feature, 0 for Fridge Snap
- `cookingTechniques` (List<String>) - Array of cooking methods used (e.g., ["sautéing", "braising", "roasting"])
- `flavorProfile` (String) - JSON encoded flavor profile object with sweet/salty/sour/bitter/umami (1-10 scale)
- `secretIngredients` (List<String>) - Hidden ingredients that enhance flavor (e.g., ["fish sauce", "butter", "MSG"])
- `proTips` (List<String>) - Professional cooking tips for restaurant-quality results
- `visualClues` (List<String>) - Visual indicators for doneness (e.g., ["golden brown", "bubbling edges"])
- `shareCaption` (String) - Pre-written social media caption with emojis and hashtags

#### Challenge
- `id` (String)
- `title` (String)
- `description` (String)
- `type` (String)
- `category` (String)
- `difficulty` (Int64)
- `points` (Int64)
- `coins` (Int64)
- `requirements` (String) - Base64 encoded JSON
- `startDate` (Date)
- `endDate` (Date)
- `isActive` (Int64)
- `isPremium` (Int64)
- `participantCount` (Int64)
- `completionCount` (Int64)
- `imageURL` (String)
- `badgeID` (String)
- `teamBased` (Int64)
- `minTeamSize` (Int64)
- `maxTeamSize` (Int64)

#### Team
- `id` (String)
- `name` (String)
- `description` (String)
- `captainID` (String)
- `memberIDs` (List<String>)
- `challengeID` (Reference)
- `totalPoints` (Int64)
- `createdAt` (Date)
- `inviteCode` (String)
- `isPublic` (Int64)
- `maxMembers` (Int64)

#### UserChallenge (Private Database)
- `userID` (String)
- `challengeID` (Reference)
- `status` (String)
- `progress` (Double)
- `startedAt` (Date)
- `completedAt` (Date)
- `earnedPoints` (Int64)
- `earnedCoins` (Int64)

#### Leaderboard
- `userID` (String)
- `userName` (String)
- `totalPoints` (Int64)
- `weeklyPoints` (Int64)
- `monthlyPoints` (Int64)
- `lastUpdated` (Date)

## Debugging Tips

### Enable CloudKit Debugging
Add to your scheme's environment variables:
- `CKDebugLogging` = `3`
- `CKVerboseLogging` = `1`

### Common Error Codes
- **10/2007**: Permission Failure - Check security roles
- **11/2003**: Unknown Item - Record doesn't exist yet
- **1/2**: Network Unavailable - Check internet connection
- **4/2015**: Quota Exceeded - CloudKit limits reached

### Console Monitoring
Watch for these success indicators:
- `✅ iCloud available`
- `✅ Synced X active challenges from CloudKit`
- `✅ Recipe saved to CloudKit`
- `✅ Full sync completed`

## Production Checklist

- [ ] CloudKit schema deployed to production
- [ ] Security roles configured for all record types
- [ ] In-App Purchases configured in App Store Connect
- [ ] StoreKit products tested in sandbox
- [ ] CloudKit Dashboard access for team members
- [ ] Error monitoring in place (Crashlytics/Sentry)
- [ ] Backup strategy for CloudKit data
- [ ] Rate limiting implemented for API calls