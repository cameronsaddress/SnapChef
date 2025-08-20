# SnapChef Social Features Testing Checklist

## 🧪 Quick Testing Guide

### Setup (2 Simulators Minimum)

1. **Simulator 1 - Main User**
   - Sign in with Apple ID #1
   - Create username: "mainchef"
   - Create 2-3 recipes
   
2. **Simulator 2 - Test Friend**
   - Sign in with Apple ID #2  
   - Create username: "friendchef"
   - Create 1-2 recipes

### Core Social Features to Test

#### ✅ Following System
- [ ] User 1: Search for User 2 in Discover
- [ ] User 1: Follow User 2
- [ ] User 2: Check follower count increased
- [ ] User 1: See User 2's recipes in "Following" tab
- [ ] User 1: Unfollow and verify removal

#### ✅ Recipe Interactions
- [ ] User 1: Like User 2's recipe
- [ ] User 2: See like count increase
- [ ] User 1: Comment on User 2's recipe
- [ ] User 2: See and reply to comment
- [ ] Both: Verify comment thread

#### ✅ Activity Feed
- [ ] User 2: Check activity feed for "User 1 followed you"
- [ ] User 2: Check for "User 1 liked your recipe"
- [ ] User 2: Check for "User 1 commented on your recipe"
- [ ] User 1: Share a recipe and verify activity created

#### ✅ Social Recipe Feed
- [ ] User 1: Go to Feed → Following tab
- [ ] User 1: Verify User 2's recipes appear
- [ ] User 1: Like recipe from feed
- [ ] User 1: Tap recipe to view details

#### ✅ Discovery
- [ ] Both: Search for users by username
- [ ] Both: Browse "New Chefs" category
- [ ] Both: Check "Trending" (most active)
- [ ] Verify no fake users appear

### CloudKit Verification

1. **Check CloudKit Dashboard:**
   - Verify User records created
   - Check Follow records exist
   - Confirm Activity records generated
   - Review RecipeLike records

2. **Data Sync Test:**
   - Make change on Simulator 1
   - Pull to refresh on Simulator 2
   - Verify change appears

### Common Issues & Solutions

**Issue: Users can't find each other**
- Solution: Ensure both users have completed username setup
- Check CloudKit User records exist

**Issue: Activities not appearing**
- Solution: Check authentication on both devices
- Verify CloudKit Activity records are created
- Pull to refresh the activity feed

**Issue: Recipes not showing in Following tab**
- Solution: Verify Follow relationship exists in CloudKit
- Check Recipe records have correct owner references
- Ensure recipes are marked as public

### Performance Testing

- [ ] Test with 10+ recipes in feed
- [ ] Test with 20+ comments on a recipe
- [ ] Test with 50+ users in discovery
- [ ] Verify smooth scrolling

### Edge Cases

- [ ] Block/unblock user (if implemented)
- [ ] Delete recipe with likes/comments
- [ ] User changes username
- [ ] Offline mode behavior

## 🎯 Testing Tips

1. **Use memorable usernames:** chef1, chef2, chef3 for easy tracking
2. **Take screenshots:** Document any bugs with visual proof
3. **Check CloudKit Dashboard:** Verify data is actually saved
4. **Test offline:** Turn on Airplane mode and test sync
5. **Test delays:** CloudKit may have 1-2 second delays

## 📊 Expected Results

After testing, you should have:
- Multiple users following each other
- Recipes with likes and comments
- Active feeds showing real interactions
- No mock/fake data appearing
- Smooth navigation between social features