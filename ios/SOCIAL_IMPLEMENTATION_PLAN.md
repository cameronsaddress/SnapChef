# SnapChef Social Features Implementation Plan

## Overview
This plan breaks down the social features implementation into manageable steps, using EXISTING views and components. Each step includes test builds to ensure stability.

## 🎯 Phase 1: Foundation (Week 1-2)

### Step 1.1: CloudKit Schema Updates
**Files to modify:**
- `CloudKitConfig.swift` - Add new record types
- `CloudKitModels.swift` - Add social model structures

**Tasks:**
1. Add Follow record type to CloudKit schema
2. Add Like record type 
3. Add RecipeView record type for analytics
4. Update CloudKitUser model with social counts
5. **TEST BUILD** ✓

### Step 1.2: Update CloudKitAuthManager
**Files to modify:**
- `CloudKitAuthManager.swift` - Add social methods

**Tasks:**
1. Add `followUser()` method
2. Add `unfollowUser()` method
3. Add `isFollowing()` check method
4. Add `updateSocialCounts()` method
5. **TEST BUILD** ✓

### Step 1.3: Enhance Profile View Social Section
**Files to modify:**
- `ProfileView.swift` - Update SocialStatsCard with real data
- `RecipeCardView.swift` - Add like button functionality

**Tasks:**
1. Connect follower/following counts to CloudKit
2. Make follower/following counts tappable (show list)
3. Add follow/unfollow button to profile (when viewing others)
4. Update likes count to use CloudKit data
5. **TEST BUILD** ✓

### Step 1.4: Recipe Like System
**Files to modify:**
- `RecipeDetailView.swift` - Add like button
- `RecipeResultsView.swift` - Show like count on cards
- `CloudKitSyncService.swift` - Add like sync methods

**Tasks:**
1. Add heart button to RecipeDetailView
2. Implement like/unlike functionality
3. Show like count with animation
4. Sync likes to CloudKit
5. **TEST BUILD** ✓

## 🎯 Phase 2: Engagement (Week 3-4)

### Step 2.1: Recipe Sharing Enhancement
**Files to modify:**
- `ShareGeneratorView.swift` - Add platform-specific options
- `RecipeDetailView.swift` - Update share button

**Tasks:**
1. Add share tracking to CloudKit
2. Create platform selector in ShareGeneratorView
3. Add share count to recipe cards
4. Track which platform was used for sharing
5. **TEST BUILD** ✓

### Step 2.2: Activity Feed
**Files to modify:**
- `HomeView.swift` - Add activity section
- `ChallengeHubView.swift` - Show friends' challenge activity

**Tasks:**
1. Add "Friends' Activity" section to HomeView (below challenges)
2. Create ActivityRow component (reusable)
3. Show when friends complete challenges
4. Show when friends create new recipes
5. **TEST BUILD** ✓

### Step 2.3: User Discovery
**Files to modify:**
- `ProfileView.swift` - Add "Discover Chefs" button
- `RecipeDetailView.swift` - Make chef name tappable

**Tasks:**
1. Add search functionality to find users by username
2. Show suggested chefs based on cooking style
3. Make usernames throughout app tappable
4. Add mini profile preview sheet
5. **TEST BUILD** ✓

### Step 2.4: Comments System (Basic)
**Files to modify:**
- `RecipeDetailView.swift` - Add comments section
- `CloudKitModels.swift` - Add Comment model

**Tasks:**
1. Add comment input field to RecipeDetailView
2. Display comments list
3. Implement comment posting
4. Add comment count to recipe cards
5. **TEST BUILD** ✓

## 🎯 Phase 3: Platform Integration (Week 5-6)

### Step 3.1: URL Scheme Setup
**Files to modify:**
- `Info.plist` - Add URL schemes
- `SnapChefApp.swift` - Handle incoming URLs

**Tasks:**
1. Register snapchef:// URL scheme
2. Add LSApplicationQueriesSchemes for social apps
3. Implement URL handling in SnapChefApp
4. Add deep link routing logic
5. **TEST BUILD** ✓

### Step 3.2: Instagram Integration
**Files to modify:**
- `ShareGeneratorView.swift` - Add Instagram-specific sharing
- `ChallengeSharingManager.swift` - Update with Stories support

**Tasks:**
1. Implement Instagram Stories sharing with stickers
2. Add Instagram Feed sharing option
3. Create Instagram-optimized image layouts
4. Add "Share to Instagram" tracking
5. **TEST BUILD** ✓

### Step 3.3: TikTok Integration
**Files to modify:**
- `ShareGeneratorView.swift` - Add TikTok options
- `RecipeDetailView.swift` - Add "Create TikTok" button

**Tasks:**
1. Add TikTok share functionality
2. Create recipe video template (images + text)
3. Add trending hashtags suggestion
4. Track TikTok shares
5. **TEST BUILD** ✓

### Step 3.4: Universal Links
**Files to modify:**
- `SnapChefApp.swift` - Handle web URLs
- Create `DeepLinkHandler.swift` in Utilities

**Tasks:**
1. Set up apple-app-site-association file
2. Handle snapchef.com URLs
3. Route to appropriate views
4. Add share web links generation
5. **TEST BUILD** ✓

## 🎯 Phase 4: Analytics & Polish (Week 7-8)

### Step 4.1: Social Analytics
**Files to modify:**
- `ProfileView.swift` - Add insights section
- `RecipeDetailView.swift` - Show view count

**Tasks:**
1. Track recipe views in CloudKit
2. Add "Insights" to profile (for own recipes)
3. Show engagement rate
4. Add trending indicator to popular recipes
5. **TEST BUILD** ✓

### Step 4.2: Notifications
**Files to modify:**
- `ChallengeNotificationManager.swift` - Add social notifications
- `AppState.swift` - Add notification badge counts

**Tasks:**
1. Send notification when someone follows
2. Notify on recipe likes/comments
3. Challenge completion notifications
4. Add in-app notification center
5. **TEST BUILD** ✓

### Step 4.3: Privacy Controls
**Files to modify:**
- `ProfileView.swift` - Add privacy settings
- `CloudKitAuthManager.swift` - Add privacy flags

**Tasks:**
1. Add private/public account toggle
2. Implement block user functionality
3. Add content reporting system
4. Hide social features for private accounts
5. **TEST BUILD** ✓

### Step 4.4: Performance & Polish
**Tasks:**
1. Optimize CloudKit queries with indexes
2. Add pagination to social lists
3. Implement caching for social data
4. Add loading states and error handling
5. **FINAL TEST BUILD** ✓

## 📋 Implementation Checklist

### Pre-requisites
- [ ] Ensure CloudKit container is properly configured
- [ ] Verify all team members have CloudKit access
- [ ] Set up test user accounts

### Phase 1 Checklist
- [ ] CloudKit schema updated
- [ ] Follow/unfollow working
- [ ] Likes system functional
- [ ] Profile shows real social data

### Phase 2 Checklist
- [ ] Activity feed showing
- [ ] User discovery working
- [ ] Comments functional
- [ ] Share tracking active

### Phase 3 Checklist
- [ ] URL schemes registered
- [ ] Instagram sharing works
- [ ] TikTok integration complete
- [ ] Deep links routing correctly

### Phase 4 Checklist
- [ ] Analytics dashboard ready
- [ ] Notifications working
- [ ] Privacy controls in place
- [ ] Performance optimized

## 🚨 Important Notes

1. **Use Existing Views**: 
   - Modify existing views rather than creating new ones
   - Reuse components like GlassmorphicCard, MagneticButton
   - Extend current models instead of creating duplicates

2. **Test Builds**:
   - Run test build after EACH step
   - Fix all errors before proceeding
   - Check for performance issues

3. **CloudKit Considerations**:
   - Use batch operations where possible
   - Implement proper error handling
   - Cache frequently accessed data
   - Consider rate limits

4. **UI Consistency**:
   - Maintain existing design language
   - Use current color scheme and animations
   - Follow established patterns

5. **Backward Compatibility**:
   - Ensure app works without social features
   - Graceful degradation for non-authenticated users
   - Don't break existing functionality

## 🎯 Success Metrics

### Week 2 Goals
- 100+ test follows between team
- 500+ test likes on recipes
- Profile view shows accurate counts

### Week 4 Goals
- Activity feed populated
- Comments on 50+ recipes
- User discovery working

### Week 6 Goals
- 100+ shares to social platforms
- Deep links bringing users back
- Platform integrations stable

### Week 8 Goals
- Full analytics available
- All privacy controls working
- <2s load time for social features

## 🔧 Troubleshooting

### Common Issues
1. **CloudKit sync delays**: Implement optimistic UI updates
2. **Rate limiting**: Add request queuing
3. **Large follower lists**: Implement pagination
4. **Notification spam**: Add frequency limits

### Performance Tips
1. Prefetch social data on app launch
2. Cache user relationships
3. Batch CloudKit operations
4. Use lightweight preview models

## 📝 Code Examples

### Follow User Example
```swift
// In CloudKitAuthManager.swift
func followUser(_ userID: String) async throws {
    guard let currentUserID = currentUser?.recordID else { throw CloudKitAuthError.notAuthenticated }
    
    let follow = CKRecord(recordType: "Follow")
    follow["followerID"] = currentUserID
    follow["followingID"] = userID
    follow["followedAt"] = Date()
    
    try await database.save(follow)
    
    // Update local counts
    await updateSocialCounts()
}
```

### Like Recipe Example
```swift
// In RecipeDetailView.swift
@State private var isLiked = false
@State private var likeCount = 0

private func toggleLike() {
    Task {
        if isLiked {
            try await cloudKitManager.unlikeRecipe(recipe.id)
            likeCount -= 1
        } else {
            try await cloudKitManager.likeRecipe(recipe.id)
            likeCount += 1
        }
        isLiked.toggle()
    }
}
```

This plan provides a structured approach to implementing social features while maintaining code quality and app stability.