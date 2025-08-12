# TikTok App Configuration for SnapChef

## Your Credentials (KEEP SECURE!)
```
Client Key: aw1bmq37wrvp0ddj
Client Secret: MkRnVKjg1NW9gTWjjLewqAIG5iEk4NJk
```

## TikTok Developer Portal Form Fields

### Basic Information

**App name:**
```
SnapChef
```

**Category:**
```
Lifestyle
```

**Description (max 120 chars):**
```
AI-powered recipe app that transforms fridge photos into personalized recipes with easy TikTok video sharing
```

**Terms of Service URL:**
```
https://snapchef.app/terms
```
(Note: Create a simple terms page on your website or use a generator like https://www.termsfeed.com/terms-conditions-generator/)

**Privacy Policy URL:**
```
https://snapchef.app/privacy
```
(Note: Create a privacy policy or use a generator like https://www.privacypolicygenerator.info/)

**Platforms:**
```
✅ iOS (Check this box)
```

### App Review Section

**Explain how each product and scope works (for Share Kit):**
```
SnapChef users can share their AI-generated recipes to TikTok as videos or images. The integration works as follows:

1. User generates a recipe from their fridge photo using our AI
2. User taps "Share to TikTok" button
3. App creates a branded video/image with recipe details
4. Content is saved to user's photo library
5. TikTok app opens with the content ready to post
6. Recipe caption and trending hashtags are pre-populated via clipboard

Share Kit is used to:
- Open TikTok app directly to the create/upload screen
- Pass recipe content and metadata
- Enable seamless sharing without manual steps

No user data is collected. Only recipe content is shared with user consent.
```

**Demo Video Script (you'll need to record this):**
```
1. Open SnapChef app on iPhone
2. Take photo of fridge/pantry
3. Generate recipe with AI
4. Tap share button
5. Select TikTok option
6. Choose "Create Video" 
7. Show video being generated with recipe
8. Show TikTok app opening
9. Show content ready to post with caption
10. Post the video to TikTok
```

### Products to Add
1. Click "Add products"
2. Select **"Share Kit"** only (for now)

### Scopes to Add
1. Click "Add scopes"
2. Select:
   - ✅ `share.content` - Share content to TikTok
   - ✅ `user.info.basic` (optional - if you want usernames)

## Now Update Your iOS App

### 1. Update TikTokSDKManager.swift

Replace line 17: