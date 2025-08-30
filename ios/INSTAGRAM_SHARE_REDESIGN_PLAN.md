# Instagram Share Redesign Implementation Plan

## Overview
Complete redesign of InstagramShareView to be cleaner, more professional, and match SnapChef's brand identity.

## Design Goals
- ✨ Clean, minimal layout matching SnapChef's aesthetic
- 📱 Mobile-first single-column design
- 🎯 Larger preview as focal point
- ⚡ Fewer decisions for faster sharing
- 🎨 SnapChef brand colors (not Instagram gradient)

## Phase 1: Core UI Restructure ⚙️

### TODO:
- [ ] Remove Instagram gradient background
- [ ] Implement clean white/light background
- [ ] Add segmented control for Feed/Story toggle
- [ ] Create single-column layout
- [ ] Remove toolbar redundancy (keep only X close button)
- [ ] Implement large centered preview (70% of screen)

### Components to Remove:
- Multiple template selection
- Color picker grid
- Sticker options
- Hashtag grid
- Duplicate share buttons in toolbar

### New Structure:
```
NavigationStack {
  VStack {
    // Header
    - Title: "Share to Instagram"
    - Segmented Control: [Feed | Story]
    
    // Preview (70% height)
    - Large centered preview
    - Auto-template based on content
    - Card shadow effect
    
    // Options (minimal)
    - Caption editor (Feed only)
    - Background style (Story only - 3 options)
    
    // Action
    - Single share button
  }
}
```

## Phase 2: Caption System 📝

### TODO:
- [ ] Remove AI caption generation
- [ ] Implement template-based captions
- [ ] Add recipe variable interpolation
- [ ] Include character counter
- [ ] Add SnapChef App Store CTA

### Caption Templates:

#### Recipe Caption (Short & Witty):
```swift
"Just turned my sad fridge into {recipe.name} 🎉

{emoji} {totalTime} min magic
📱 Get SnapChef on the App Store!

#{primaryHashtag} #SnapChef #FridgeToFeast"
```

#### Variables:
- `{recipe.name}` - Recipe title
- `{totalTime}` - Total cook time
- `{emoji}` - Food emoji based on cuisine/type
- `{primaryHashtag}` - Main recipe hashtag

#### Achievement Caption:
```swift
"🏆 {achievementName} unlocked!

Level up your kitchen game 👨‍🍳
📱 Download SnapChef on the App Store

#SnapChef #CookingWin"
```

#### Challenge Caption:
```swift
"Challenge crushed: {challengeName} ✅

Who's next? 💪
📱 Join me on SnapChef (App Store)

#SnapChefChallenge"
```

## Phase 3: Story Mode Simplification 📸

### TODO:
- [ ] Reduce to 3 background styles only
- [ ] Remove sticker system
- [ ] Implement text overlay toggle
- [ ] Simplify story preview
- [ ] Keep pasteboard integration

### Story Backgrounds:
1. **Photo** - Recipe photo background
2. **Gradient** - SnapChef brand gradient
3. **Solid** - Clean color background

## Phase 4: Preview Generation 🖼️

### TODO:
- [ ] Simplify InstagramContentGenerator
- [ ] Auto-select template by content type
- [ ] Remove template selection UI
- [ ] Implement consistent branding
- [ ] Optimize image generation

### Templates (Auto-selected):
- **Recipe Template** - For recipe shares
- **Achievement Template** - For achievements/challenges/profile

## Phase 5: Final Polish & Testing ✨

### TODO:
- [ ] Add loading states
- [ ] Implement error handling
- [ ] Add success feedback
- [ ] Test Instagram app integration
- [ ] Test web fallback
- [ ] Verify CloudKit activity logging

## Implementation Order

### Step 1: Core UI (Phase 1)
1. Strip out existing complex UI
2. Implement new clean layout
3. Add Feed/Story toggle
4. **Build & Test**

### Step 2: Caption System (Phase 2)
1. Remove AI generation code
2. Add template functions
3. Implement variable replacement
4. Add character counter
5. **Build & Test**

### Step 3: Story Simplification (Phase 3)
1. Remove stickers
2. Reduce background options
3. Clean up story UI
4. **Build & Test**

### Step 4: Preview System (Phase 4)
1. Update content generator
2. Remove template selection
3. Auto-select based on type
4. **Build & Test**

### Step 5: Polish (Phase 5)
1. Add polish and animations
2. Test all flows
3. Verify sharing works
4. **Final Build & Test**

## Success Metrics
- ✅ Sharing takes < 3 taps
- ✅ UI matches SnapChef design
- ✅ No Instagram branding
- ✅ Clear SnapChef CTA
- ✅ Works with/without Instagram app

## Files to Modify
- `InstagramShareView.swift` - Main redesign
- `InstagramContentGenerator.swift` - Simplify generation
- `InstagramModels.swift` - Update templates

## Testing Checklist
- [ ] Feed post with recipe
- [ ] Story with recipe  
- [ ] Achievement sharing
- [ ] Challenge sharing
- [ ] Caption editing works
- [ ] Instagram app opens correctly
- [ ] Web fallback works
- [ ] CloudKit activity logs
- [ ] Preview looks good
- [ ] No UI glitches

## Brand Colors to Use
- Primary: #FF0050 (SnapChef Red)
- Secondary: #00F2EA (SnapChef Teal)
- Background: #FFFFFF (White)
- Text: #1C1C1E (Near Black)
- Secondary Text: #8E8E93 (Gray)