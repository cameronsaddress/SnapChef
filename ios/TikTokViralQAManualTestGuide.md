# TikTok Viral Content Generation - Manual QA Testing Guide

## Overview

This comprehensive manual testing guide ensures the TikTok viral content generation feature meets all specifications outlined in `TIKTOK_VIRAL_COMPLETE_REQUIREMENTS.md`. Use this guide to systematically test all components before release.

## Pre-Testing Setup

### Required Test Environment
- **Device Requirements**: iPhone 11, 12, 13, 14, 15, 16 (test on at least 3 different models)
- **iOS Versions**: iOS 15, 16, 17, 18 (test on at least 2 versions)
- **Network**: Test on both WiFi and cellular
- **Storage**: Ensure at least 1GB free space for video generation
- **TikTok App**: Install TikTok app for integration testing

### Test Data Preparation
Create test recipes with these characteristics:
1. **Minimal Recipe**: 2 ingredients, 2 steps, 10 minutes total time
2. **Full Recipe**: 7+ ingredients, 6+ steps, 35+ minutes total time
3. **Long Title Recipe**: Title >80 characters
4. **Many Ingredients**: 15+ ingredients
5. **Single Ingredient**: 1 ingredient only
6. **Long Steps**: Steps >60 characters each

### Test Images
Prepare test images:
- **Before (Fridge) Photo**: 1080x1920 or higher resolution
- **After (Meal) Photo**: 1080x1920 or higher resolution
- **No Images**: Test scenarios without photos

---

## Test Categories

## 1. Template Testing ✅

### Test 1.1: All Templates with Minimal Recipe
**Objective**: Verify all 5 templates work with basic recipe data

**Steps**:
1. Create a minimal recipe (2 ingredients, 2 steps)
2. Navigate to Share → TikTok → Create Video
3. Test each template:
   - Before/After Reveal ⭐ (should show "HOT" indicator)
   - 60-Second Recipe
   - 360° Ingredients
   - Cooking Timelapse  
   - Split Screen

**Expected Results**:
- [ ] All templates generate without errors
- [ ] Video duration appropriate for template
- [ ] Content displays clearly
- [ ] No crashes or freezing

**Notes**: Before/After Reveal should be marked as "HOT" template

### Test 1.2: All Templates with Full Recipe
**Objective**: Verify templates handle complex recipe data

**Steps**:
1. Create a full recipe (7+ ingredients, 6+ steps)
2. Test all 5 templates
3. Verify content adaptation

**Expected Results**:
- [ ] Complex data handled gracefully
- [ ] Text doesn't overflow
- [ ] All ingredients visible (first 3 for displays)
- [ ] Steps shortened appropriately (5-7 words max)

### Test 1.3: Edge Case Scenarios

#### No B-Roll (Stills Only)
**Steps**:
1. Test templates without video clips
2. Verify still images are used throughout

**Expected Results**:
- [ ] Videos generate successfully with stills
- [ ] Ken Burns effect applied to images (1.08x scale, alternating pan)
- [ ] No black frames

#### No Music (Silent)
**Steps**:
1. Test templates without audio selection
2. Verify silent video generation

**Expected Results**:
- [ ] Videos generate without audio track
- [ ] No audio-related errors
- [ ] File size appropriately smaller

#### Missing Hook (Default Generation)
**Steps**:
1. Test recipe without hook text
2. Verify fallback generation

**Expected Results**:
- [ ] Default hook generated: "Fridge chaos → dinner in X min"
- [ ] Hook appears in first 2 seconds

#### 0-1 Ingredients
**Steps**:
1. Test recipe with no ingredients
2. Test recipe with 1 ingredient

**Expected Results**:
- [ ] No crashes
- [ ] Appropriate fallback content
- [ ] Graceful handling of empty data

#### Long Step Text (>60 chars)
**Steps**:
1. Create recipe with very long instruction steps
2. Test 60-Second Recipe template

**Expected Results**:
- [ ] Text automatically shortened
- [ ] Key information preserved
- [ ] No text overflow

---

## 2. Safe Zone Compliance Testing ✅

### Test 2.1: Text Placement Verification
**Objective**: Ensure all text remains within safe zones

**Test Zones**:
- **Top Safe Zone**: 192px from top (10% of 1920px)
- **Bottom Safe Zone**: 192px from bottom (10% of 1920px)  
- **Left Safe Zone**: 72px from left
- **Right Safe Zone**: 72px from right

**Steps**:
1. Generate videos for all templates
2. Screenshot key frames
3. Measure text placement using design tools
4. Verify no critical text in unsafe zones

**Expected Results**:
- [ ] Hook text within safe zones
- [ ] Step text within safe zones
- [ ] Counter text within safe zones
- [ ] CTA text within safe zones
- [ ] Ingredient callouts within safe zones
- [ ] SnapChef watermark appropriately placed

### Test 2.2: TikTok UI Overlay Simulation
**Steps**:
1. Add TikTok UI overlay to screenshots
2. Verify content remains visible
3. Check text readability at 50% zoom

**Expected Results**:
- [ ] Content not obscured by TikTok UI
- [ ] Text readable when zoomed out
- [ ] Important elements remain visible

---

## 3. Error Handling Testing ✅

### Test 3.1: Photo Permission Denied
**Steps**:
1. Go to Settings → Privacy → Photos
2. Disable photo access for SnapChef
3. Attempt video generation and sharing

**Expected Results**:
- [ ] Clear error message displayed
- [ ] Settings deep link provided
- [ ] No app crash
- [ ] User can retry after enabling permission

### Test 3.2: TikTok Not Installed
**Steps**:
1. Uninstall TikTok app (or test on device without TikTok)
2. Attempt TikTok sharing

**Expected Results**:
- [ ] "TikTok not installed" error shown
- [ ] App Store redirect offered
- [ ] Web fallback option provided
- [ ] Graceful degradation

### Test 3.3: Network Failure
**Steps**:
1. Disable internet connection
2. Attempt photo fetching from CloudKit
3. Attempt share operations

**Expected Results**:
- [ ] Network error messages displayed
- [ ] Retry options provided
- [ ] Offline functionality where possible
- [ ] No indefinite loading states

### Test 3.4: Memory Warning
**Steps**:
1. Generate multiple videos rapidly
2. Monitor memory usage
3. Test on older devices (iPhone 11)

**Expected Results**:
- [ ] Memory usage under 150MB peak
- [ ] Graceful handling of memory pressure
- [ ] No memory-related crashes
- [ ] Proper cleanup of resources

### Test 3.5: Invalid Data Handling
**Steps**:
1. Test with corrupted recipe data
2. Test with invalid image formats
3. Test with empty recipe fields

**Expected Results**:
- [ ] No crashes with invalid data
- [ ] Appropriate fallback content
- [ ] Clear error messages for users

---

## 4. Performance Testing ✅

### Test 4.1: Render Time Benchmarking
**Objective**: Verify render time under 5 seconds

**Steps**:
1. Test each template on different devices
2. Measure time from "Generate" tap to completion
3. Test with various recipe complexities

**Performance Targets**:
- [ ] Before/After Reveal: <4 seconds
- [ ] 60-Second Recipe: <5 seconds  
- [ ] 360° Ingredients: <3 seconds
- [ ] Timelapse: <4 seconds
- [ ] Split Screen: <4 seconds

**Test on**:
- [ ] iPhone 16 (newest)
- [ ] iPhone 13 (mid-range)
- [ ] iPhone 11 (oldest supported)

### Test 4.2: Memory Profiling
**Steps**:
1. Monitor memory usage during video generation
2. Check for memory leaks
3. Test multiple consecutive generations

**Expected Results**:
- [ ] Peak memory usage <150MB
- [ ] Memory properly released after generation
- [ ] No progressive memory increase

### Test 4.3: File Size Validation
**Steps**:
1. Generate videos for all templates
2. Check exported file sizes
3. Verify quality vs. size balance

**Expected Results**:
- [ ] File size under 50MB maximum
- [ ] Target under 20MB for most videos
- [ ] Good quality maintained

---

## 5. Video Quality Testing ✅

### Test 5.1: Technical Specifications
**Verify all videos meet**:
- [ ] Resolution: 1080×1920 (9:16 aspect ratio)
- [ ] Frame Rate: Exactly 30 FPS
- [ ] Format: H.264 + AAC
- [ ] Bitrate: 8-12 Mbps (10 Mbps target)

### Test 5.2: Visual Quality Checks
**For each template verify**:
- [ ] No black frames
- [ ] Smooth transitions
- [ ] Text clearly readable
- [ ] Images properly scaled
- [ ] Ken Burns effect working (1.08x scale)
- [ ] Color pop effect on AFTER images

### Test 5.3: Duration Compliance
**Verify template durations**:
- [ ] Before/After Reveal: 15 seconds
- [ ] 60-Second Recipe: 60 seconds
- [ ] 360° Ingredients: 10 seconds
- [ ] Timelapse: 15 seconds
- [ ] Split Screen: 15 seconds

### Test 5.4: Content Timing
**For Before/After Reveal template verify**:
- [ ] Hook appears in first 2 seconds
- [ ] Reveal moment at 3-5 seconds
- [ ] CTA appears in last 3 seconds
- [ ] Minimum 2 visual changes per second

---

## 6. Share Flow Testing ✅

### Test 6.1: Complete Share Pipeline
**Steps**:
1. Generate video
2. Tap "Share to TikTok"
3. Verify save to Photos
4. Check caption copying
5. Verify TikTok app opening

**Expected Results**:
- [ ] Video saved to Photos successfully
- [ ] localIdentifier retrieved
- [ ] Caption copied to clipboard
- [ ] TikTok app opens to correct screen
- [ ] Video appears in TikTok library

### Test 6.2: Caption Generation
**Test default caption format**:
```
[Recipe Title] — [Time] min [Cost]
Comment "RECIPE" for details 👇
#FridgeGlowUp #BeforeAfter #DinnerHack #HomeCooking
```

**Verify**:
- [ ] Recipe title included
- [ ] Time calculation correct
- [ ] Hashtags properly formatted
- [ ] Call-to-action included

### Test 6.3: Hashtag Management
**Steps**:
1. Test auto-selected hashtags
2. Add custom hashtags
3. Verify 30 hashtag limit

**Expected Results**:
- [ ] Default hashtags auto-selected
- [ ] Custom hashtags can be added
- [ ] Limit enforced (30 max)
- [ ] Hashtags properly formatted with #

### Test 6.4: Quick Share vs Video Creator
**Test both modes**:
1. **Quick Post**: Simple card + link
2. **Video Creator**: Full video generation

**Verify**:
- [ ] Mode selection works
- [ ] Quick post generates share card
- [ ] Video creator generates full video
- [ ] Both modes copy appropriate content

---

## 7. TikTok Integration Testing ✅

### Test 7.1: TikTok URL Schemes
**Test URL schemes in order**:
1. `snssdk1233://studio/publish`
2. `tiktok://studio/publish`
3. `snssdk1233://create?media=library`
4. `tiktok://create?media=library`
5. `snssdk1233://create`
6. `tiktok://create`

**Expected Results**:
- [ ] Best available scheme used
- [ ] TikTok opens to appropriate screen
- [ ] Fallback schemes work
- [ ] Graceful handling if none work

### Test 7.2: SDK Integration
**If TikTok SDK available**:
- [ ] localIdentifiers passed correctly
- [ ] Share request succeeds
- [ ] Error handling works
- [ ] Response callbacks function

### Test 7.3: Cross-Platform Testing
**Test TikTok integration on**:
- [ ] iOS 15 + iPhone 11
- [ ] iOS 16 + iPhone 13
- [ ] iOS 17 + iPhone 14
- [ ] iOS 18 + iPhone 15/16

---

## 8. Typography & Design Testing ✅

### Test 8.1: Text Hierarchy
**Verify font sizes**:
- [ ] Hooks: 60-72pt bold (64pt default)
- [ ] Steps: 44-52pt bold (48pt default)
- [ ] Counters: 36-48pt regular (42pt default)
- [ ] CTAs: 40pt bold in rounded stickers
- [ ] Ingredient callouts: 42pt bold

### Test 8.2: Text Styling
**Verify text appearance**:
- [ ] 4px shadow as fake stroke
- [ ] Black shadow with opacity 1.0
- [ ] Max width respects safe zones
- [ ] Line limit: 28-32 characters per line

### Test 8.3: Font Fallback
**Steps**:
1. Test on device without SF-Pro-Display
2. Verify system font fallback

**Expected Results**:
- [ ] Graceful font fallback
- [ ] No broken text rendering
- [ ] Consistent appearance

---

## 9. Animation & Effects Testing ✅

### Test 9.1: Animation Timing
**Verify animation specifications**:
- [ ] Fade duration: 200-300ms
- [ ] Spring damping: 12-14 for pop animations
- [ ] Scale range: 0.6 to 1.0 for entrance
- [ ] Max 2 concurrent animations
- [ ] Stagger delay: 120-150ms between elements

### Test 9.2: Specific Animations
**Test each animation type**:
- [ ] Hero Hook: Fade in 0.3s
- [ ] CTA Pop: Spring 0.6s with scale 0.6→1.0
- [ ] Ingredient Callout: Drop animation 0.5s with Y+50 offset
- [ ] Split Wipe: Circular reveal
- [ ] Kinetic Steps: Slide up with 0.35s group animation
- [ ] Sticker Stack: Staggered pop with 0.12s delay
- [ ] Progress Bar: Linear animation matching duration

### Test 9.3: Ken Burns Effect
**Verify on Before/After template**:
- [ ] Scale: 1.08x applied
- [ ] Direction: Alternating (index % 2)
- [ ] Translation: ±2% of size

---

## 10. Device Matrix Testing ✅

### Test 10.1: Device Compatibility
**Test on each device type**:

#### iPhone 16 (Latest)
- [ ] All templates work
- [ ] Performance optimal
- [ ] No crashes
- [ ] Share flow complete

#### iPhone 15
- [ ] All templates work
- [ ] Performance good
- [ ] Share functionality
- [ ] TikTok integration

#### iPhone 14
- [ ] All templates work
- [ ] Performance acceptable
- [ ] Memory usage monitored
- [ ] Full functionality

#### iPhone 13
- [ ] All templates work
- [ ] Performance within limits
- [ ] Memory optimization effective
- [ ] No degradation

#### iPhone 12
- [ ] All templates work
- [ ] Render times under threshold
- [ ] Memory usage controlled
- [ ] Stable operation

#### iPhone 11 (Minimum)
- [ ] All templates work
- [ ] Performance meets minimums
- [ ] Memory usage under 150MB
- [ ] No crashes or timeouts

#### iPhone SE (if supported)
- [ ] Basic functionality
- [ ] Performance acceptable
- [ ] UI scales properly
- [ ] Core features work

### Test 10.2: iOS Version Compatibility
**Test on supported iOS versions**:

#### iOS 18 (Latest)
- [ ] Full feature compatibility
- [ ] Latest API usage
- [ ] Performance optimized
- [ ] No deprecation warnings

#### iOS 17
- [ ] Feature parity maintained
- [ ] Performance stable
- [ ] Compatibility verified
- [ ] No regression issues

#### iOS 16
- [ ] Core functionality works
- [ ] Performance adequate
- [ ] Fallbacks functional
- [ ] Stable operation

#### iOS 15 (Minimum)
- [ ] Essential features work
- [ ] Graceful degradation
- [ ] Performance acceptable
- [ ] No crashes

---

## 11. Audio & Music Testing ✅

### Test 11.1: Trending Audio Selection
**Test audio picker interface**:
- [ ] Audio list loads
- [ ] Selection works
- [ ] Preview functionality
- [ ] None selected option

### Test 11.2: Audio Integration
**Verify audio in videos**:
- [ ] Audio syncs with video
- [ ] No audio glitches
- [ ] Proper audio format (AAC)
- [ ] Bitrate: 128-192 kbps
- [ ] Sample rate: 44.1 kHz

### Test 11.3: Silent Video Handling
**Test videos without audio**:
- [ ] Silent generation works
- [ ] No audio track created
- [ ] File size appropriately smaller
- [ ] No audio errors

---

## 12. User Experience Testing ✅

### Test 12.1: Loading States
**Verify all loading indicators**:
- [ ] Video generation progress
- [ ] Status messages update
- [ ] Progress percentage accurate
- [ ] Cancel functionality works

### Test 12.2: Error Messages
**Test error message clarity**:
- [ ] Messages are user-friendly
- [ ] Clear next steps provided
- [ ] Technical details hidden
- [ ] Recovery options offered

### Test 12.3: Haptic Feedback
**Test haptic responses**:
- [ ] Selection feedback works
- [ ] Success feedback triggers
- [ ] Error feedback appropriate
- [ ] Not overwhelming

### Test 12.4: Accessibility
**Test accessibility features**:
- [ ] VoiceOver support
- [ ] Dynamic type support
- [ ] High contrast compatibility
- [ ] Reduced motion respect

---

## Test Scenarios Checklist

### Required Test Scenarios (from requirements)

#### Template Testing
- [ ] All 5 templates with minimal recipe
- [ ] All 5 templates with full recipe
- [ ] No b-roll (stills only)
- [ ] No music (silent)
- [ ] Missing hook (default generation)
- [ ] 0-1 ingredients
- [ ] Long step text (>60 chars)

#### Error Scenarios  
- [ ] Permission denied flows
- [ ] TikTok not installed
- [ ] Share completion callback

#### Performance Testing
- [ ] Memory profiling during render
- [ ] Device testing matrix
- [ ] Performance benchmarking

#### Quality Validation
- [ ] Safe zone compliance
- [ ] Video specifications
- [ ] Typography standards
- [ ] Animation timing

---

## Bug Reporting Template

When reporting issues, include:

**Bug Title**: [Brief description]

**Severity**: Critical / High / Medium / Low

**Device**: iPhone model, iOS version

**Steps to Reproduce**:
1. Step 1
2. Step 2
3. Step 3

**Expected Result**: What should happen

**Actual Result**: What actually happened

**Screenshots/Videos**: Attach evidence

**Additional Notes**: Any relevant context

---

## Performance Benchmarks

### Render Time Targets
- **Before/After Reveal**: <4 seconds
- **60-Second Recipe**: <5 seconds
- **360° Ingredients**: <3 seconds
- **Timelapse**: <4 seconds
- **Split Screen**: <4 seconds

### Memory Usage Targets
- **Peak Usage**: <150MB
- **Average Usage**: <100MB
- **Post-Generation**: Return to baseline

### File Size Targets
- **Maximum**: 50MB
- **Target**: <20MB
- **Minimum Quality**: 1080p@30fps

---

## Final Checklist

Before approving release:

### Functionality
- [ ] All 5 templates work on all supported devices
- [ ] Share flow completes successfully
- [ ] Error handling is robust
- [ ] Performance meets requirements

### Quality
- [ ] Videos meet technical specifications
- [ ] Safe zones are respected
- [ ] Typography is consistent
- [ ] Animations are smooth

### Integration
- [ ] TikTok integration works
- [ ] CloudKit photo fetching works
- [ ] Photo library saving works
- [ ] Caption generation works

### User Experience
- [ ] Interface is intuitive
- [ ] Loading states are clear
- [ ] Error messages are helpful
- [ ] Performance feels fast

### Compliance
- [ ] Meets all requirements specification
- [ ] No critical bugs remain
- [ ] Performance benchmarks met
- [ ] Device compatibility verified

---

**QA Sign-off**: _________________ Date: _________

**Notes**: _____________________________________________