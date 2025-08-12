# 🧪 TikTok Sharing Test Guide

## Current Status (Without SDK Package)

The TikTok sharing works in **fallback mode** - it saves the video and opens TikTok, but requires manual steps to complete the share.

## What You Should See When Testing:

### 1. Generate Video ✅
```
Console output:
🎬 Total frames processed: 450 of 450
🎬 Video saved to: file:///.../.../tmp/tiktok_xxx.mp4
```

### 2. Share to TikTok 📱
When you tap "Share to TikTok", you'll see:
```
🎬 TikTok SDK: Video saved to library
🎬 TikTok SDK: Caption copied to clipboard
📋 Caption: [Your recipe caption with hashtags]
🎬 TikTok SDK: Attempting to open TikTok for video sharing
🎬 TikTok SDK: Opening with URL: tiktok://library
🎬 TikTok SDK: TikTok app opened successfully
```

### 3. In the App UI:
- Status message: "✅ Video saved! Caption copied! Opening TikTok..."
- TikTok app opens
- Your video is in the photo library
- Caption is on clipboard ready to paste

### 4. Manual Steps in TikTok:
Since we don't have the SDK package yet, users need to:
1. Tap the "+" button in TikTok
2. Select "Upload" (bottom right)
3. Choose the video (it's the most recent one)
4. Paste the caption from clipboard
5. Post!

## 🚀 To Enable Direct Sharing (No Manual Steps):

### Add TikTok SDK Package:
1. **In Xcode:**
   - File → Add Package Dependencies
   - URL: `https://github.com/tiktok/tiktok-opensdk-ios`
   - Add to SnapChef target

2. **Update TikTokSDKManager.swift:**
   After adding the SDK, uncomment the SDK-specific code (currently we're using fallback URL schemes).

3. **What Changes:**
   - Video automatically appears in TikTok composer
   - Caption pre-filled (not just clipboard)
   - No manual upload needed
   - Analytics tracking enabled

## 📊 Testing Checklist:

### Without SDK (Current):
- [x] Video generates successfully
- [x] Video saves to photo library
- [x] Caption copies to clipboard
- [x] TikTok app opens
- [ ] Direct content sharing (needs SDK)
- [ ] Caption pre-population (needs SDK)

### With SDK (After Adding Package):
- [ ] All above features
- [ ] Video auto-loads in TikTok
- [ ] Caption pre-filled
- [ ] No manual steps needed
- [ ] Analytics tracking works

## 🐛 Common Issues & Solutions:

### "TikTok not installed"
**Solution:** Install TikTok from App Store on your test device

### TikTok opens but no video
**Current behavior:** This is expected without SDK. Video is in photo library - manually upload it.
**With SDK:** Video will auto-load

### Caption not appearing
**Current:** Caption is on clipboard - paste it manually
**With SDK:** Will auto-populate

### Video generation fails
**Check:**
- Photo library permissions enabled
- Enough storage space
- Try a shorter template

## 📝 Debug Output to Watch:

Good flow:
```
✅ Video saved to library
✅ Caption copied to clipboard  
✅ TikTok app opened successfully
```

Error flow:
```
❌ Failed to save video
❌ Could not open TikTok app
```

## 🎯 Success Criteria:

### Minimum (Current Implementation):
- ✅ Video saves to library
- ✅ Caption on clipboard
- ✅ TikTok opens

### Full (With SDK):
- ⏳ Direct video sharing
- ⏳ Auto-populated caption
- ⏳ One-tap sharing
- ⏳ Analytics tracking

## 📱 Test Scenarios:

1. **Happy Path:**
   - Generate recipe → Create video → Share → TikTok opens

2. **No TikTok Installed:**
   - Should show error message

3. **Permission Denied:**
   - Should request photo library access

4. **Network Issues:**
   - Video generation should still work (local)

---

**Current Mode:** Fallback (URL Schemes)
**Target Mode:** Full SDK Integration
**Sandbox Credentials:** Active ✅