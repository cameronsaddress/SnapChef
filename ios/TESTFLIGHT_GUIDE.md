# 🚀 TestFlight Setup Guide for SnapChef

## Overview
TestFlight allows you to distribute beta versions of SnapChef to up to 10,000 external testers. Perfect for testing social features with real users on real devices.

## Prerequisites
- Apple Developer Account ($99/year)
- Xcode 15+ with SnapChef project
- App Store Connect access
- Valid provisioning profiles and certificates

## Step 1: Prepare Your App for TestFlight

### 1.1 Update Version and Build Number
In Xcode:
1. Select SnapChef project → SnapChef target
2. General tab → Identity section
3. Update:
   - **Version**: 1.0.0 (or current version)
   - **Build**: Increment each upload (1, 2, 3, etc.)

### 1.2 Set Build Configuration
1. Product → Scheme → Edit Scheme
2. Archive → Build Configuration: **Release**
3. Close

### 1.3 Configure App Capabilities
1. Signing & Capabilities tab
2. Ensure these are enabled:
   - **CloudKit** ✓ (for social features)
   - **Push Notifications** ✓ (if using)
   - **Sign in with Apple** ✓

## Step 2: Archive and Upload

### 2.1 Create Archive
1. Select target device: **Any iOS Device (arm64)**
2. Product → Clean Build Folder (⇧⌘K)
3. Product → Archive (takes 5-10 minutes)
4. Organizer window opens automatically

### 2.2 Upload to App Store Connect
1. In Organizer, select your archive
2. Click **Distribute App**
3. Choose **App Store Connect**
4. Choose **Upload**
5. Options:
   - ✓ Include bitcode (recommended)
   - ✓ Upload symbols
6. **Automatically manage signing** (easier)
7. Click **Upload**

## Step 3: Configure in App Store Connect

### 3.1 Access App Store Connect
1. Go to https://appstoreconnect.apple.com
2. My Apps → SnapChef

### 3.2 TestFlight Tab Setup
1. Click **TestFlight** tab
2. Your build appears (may take 10-30 minutes)
3. Build status: Processing → Ready to Test

### 3.3 Add App Information
First time only:
- **Beta App Description**: 
  ```
  SnapChef transforms your fridge photos into personalized recipes using AI. 
  Test our social features: follow chefs, share recipes, and join cooking challenges!
  ```
- **Beta App Review Information**:
  - Contact email
  - Phone number
  - Demo account (if needed)

## Step 4: Create Test Groups

### 4.1 Internal Testing (Up to 100 testers)
Best for: Team, close friends, family

1. TestFlight → Internal Testing
2. Create Internal Group: "SnapChef Team"
3. **+ Add Testers** → Enter Apple IDs:
   ```
   friend1@icloud.com
   friend2@gmail.com
   family@icloud.com
   ```
4. Testers get invite immediately

### 4.2 External Testing (Up to 10,000 testers)
Best for: Wider testing, social features

1. TestFlight → External Testing
2. **+ Add External Group**: "SnapChef Beta Testers"
3. Add testers by email
4. Submit for Beta Review (first time only, 24-48 hours)

### 4.3 Public Link (Easiest!)
1. External Groups → Your Group
2. **Enable Public Link**
3. Share link: `https://testflight.apple.com/join/XXXXXXXX`
4. Anyone with link can join (up to limit you set)

## Step 5: Testing Social Features

### 5.1 Create Test Scenarios
Share these instructions with testers:

```markdown
# SnapChef Social Testing Instructions

## Getting Started
1. Download TestFlight app from App Store
2. Accept invite or use public link
3. Install SnapChef beta
4. Sign in with your Apple ID
5. Create unique username

## Test Tasks
- [ ] Follow 3 other testers
- [ ] Create and share 2 recipes
- [ ] Like and comment on others' recipes
- [ ] Complete a daily challenge
- [ ] Check your activity feed
- [ ] Try discovering new chefs

## Report Issues
- Screenshot any bugs
- Use "Send Beta Feedback" in TestFlight
- Include: What you did, what happened, what should happen
```

### 5.2 Organize Testing Parties
Create a testing event:
```
📅 SnapChef Testing Party!
Time: Saturday 2-3 PM
Goal: Everyone online simultaneously
Activities:
- Follow each other
- Share recipes live
- Test real-time features
- Create viral TikTok videos
Prize: Most creative recipe wins!
```

## Step 6: Managing Beta Feedback

### 6.1 View Feedback
App Store Connect → TestFlight → Feedback
- Screenshots attached automatically
- Device info included
- Crash reports linked

### 6.2 Respond to Testers
Use TestFlight feedback to:
- Thank testers
- Ask follow-up questions
- Announce new builds

### 6.3 Push Updates
New build process:
1. Fix reported issues
2. Increment build number
3. Archive and upload
4. Add build to test groups
5. Testers get notification

## Step 7: TestFlight Best Practices

### Build Naming Convention
```
Version 1.0.0 (Build 1) - Initial social features
Version 1.0.0 (Build 2) - Fixed login issues
Version 1.0.0 (Build 3) - Added recipe comments
Version 1.0.1 (Build 1) - Performance improvements
```

### Test Notes Template
```
What's New in Build X:
✨ New Features:
- Social recipe feed from followed chefs
- Real-time comments on recipes

🐛 Bug Fixes:
- Fixed crash when liking recipes
- Resolved CloudKit sync issues

📝 Please Test:
- Follow other users and check their recipes appear
- Comment on recipes and verify sync
- Report any issues via Send Beta Feedback
```

### Tester Communication
Create a Discord/Slack/WhatsApp group:
- Coordinate testing sessions
- Share usernames for following
- Report bugs quickly
- Build community

## Step 8: CloudKit Considerations

### Important for Social Features
1. **CloudKit Environment**:
   - TestFlight uses **Production** CloudKit
   - Different from Development (simulator)
   - Data doesn't sync between environments

2. **First-Time Setup**:
   - Deploy Development schema to Production
   - CloudKit Dashboard → Deploy Schema Changes
   - Select all record types → Deploy

3. **Monitor CloudKit**:
   - Check CloudKit Dashboard during testing
   - Monitor quota usage
   - Watch for errors

## Step 9: Quick Troubleshooting

### Common Issues

**Build not appearing in TestFlight**
- Wait 10-30 minutes after upload
- Check email for processing errors
- Verify certificates are valid

**Testers can't install**
- Ensure iOS version compatibility
- Check device type restrictions
- Verify tester accepted invite

**CloudKit not working**
- Deploy schema to Production
- Check container permissions
- Verify capabilities in Xcode

**Social features not showing users**
- Users need to complete sign-in
- Username setup required
- Pull to refresh for sync

## Step 10: Launch Checklist

### Before Major Testing
- [ ] Increment build number
- [ ] Test on your device first
- [ ] Write clear test notes
- [ ] Deploy CloudKit schema
- [ ] Prepare test scenarios
- [ ] Set up feedback monitoring
- [ ] Create tester group chat
- [ ] Plan testing party

### Success Metrics
Track these for social features:
- Number of active testers
- Follows per user
- Recipes shared
- Comments/likes generated
- Crash-free sessions
- User retention

## 🎯 Pro Tips

1. **Start Small**: 5-10 internal testers first
2. **Test Weekends**: Higher engagement
3. **Gamify Testing**: Rewards for most bugs found
4. **Regular Updates**: Push weekly builds
5. **Clear Communication**: Set expectations
6. **Thank Testers**: They're helping for free!

## 📱 Ready to Launch?

Your social features testing plan:
1. Week 1: Internal testing (5-10 close contacts)
2. Week 2: External testing (20-50 users)
3. Week 3: Public link (100+ users)
4. Week 4: Analyze and iterate

## 🔗 Useful Links

- [App Store Connect](https://appstoreconnect.apple.com)
- [CloudKit Dashboard](https://icloud.developer.apple.com)
- [TestFlight for Developers](https://developer.apple.com/testflight/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

---

## Example Tester Invitation Message

```
🧑‍🍳 You're Invited to Test SnapChef!

Hi [Name]!

I'm excited to invite you to beta test SnapChef, my AI-powered cooking app with social features!

What SnapChef Does:
• Snap your fridge → Get personalized recipes
• Follow other home chefs
• Share your cooking creations
• Join daily cooking challenges

How to Join:
1. Install TestFlight from the App Store
2. Click this link: [TestFlight Link]
3. Install SnapChef beta
4. Create your chef profile!

Testing Focus:
- Try the social features
- Follow other testers
- Share a recipe
- Report any bugs

Join our tester chat: [Discord/WhatsApp link]

Thanks for helping make SnapChef amazing!

[Your name]
```

---

*Last updated: January 2025*
*For SnapChef v1.0.0*