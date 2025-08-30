# 📱 Social Media Sharing Implementation Plan

## Overview
This document outlines the implementation of sharing functionality for X (Twitter), WhatsApp, and Messages, following the existing Instagram sharing pattern while adhering to platform-specific best practices and brand colors.

## 🎨 Platform Brand Colors

### X (Twitter)
- Primary: `#000000` (Black - new X branding)
- Secondary: `#1D9BF0` (Twitter Blue legacy)
- Accent: `#FFFFFF` (White)
- Gradient: Black to Dark Gray `#000000` → `#2F3336`

### WhatsApp
- Primary: `#25D366` (WhatsApp Green)
- Secondary: `#128C7E` (Dark Green)
- Accent: `#075E54` (Darker Green)
- Background: `#ECE5DD` (Chat Background)
- Gradient: `#25D366` → `#128C7E`

### Messages (iMessage)
- Primary: `#007AFF` (iOS Blue)
- Secondary: `#34C759` (Green bubble for SMS)
- Accent: `#5AC8FA` (Light Blue)
- Background: `#F2F2F7` (System Background)
- Gradient: `#007AFF` → `#5AC8FA`

## 📋 Implementation Phases

### Phase 1: X (Twitter) Share Implementation
**Files to modify:**
- `/SnapChef/Features/Sharing/Platforms/Twitter/TwitterShareView.swift`

**Features:**
1. **Tweet Composer**
   - Character counter (280 limit)
   - Auto-generated tweet text
   - Hashtag suggestions
   - Image attachment preview

2. **URL Scheme Integration**
   ```swift
   twitter://post?message={encoded_text}
   // Fallback to web: https://twitter.com/intent/tweet?text={encoded_text}
   ```

3. **Image Handling**
   - Save image to photo library
   - Copy tweet text to clipboard
   - Open Twitter app with pre-filled text

4. **Analytics Integration**
   - Track share events
   - Create CloudKit activity records

### Phase 2: WhatsApp Share Implementation
**Files to modify:**
- `/SnapChef/Features/Sharing/Platforms/WhatsApp/WhatsAppShareView.swift`

**Features:**
1. **Message Composer**
   - Pre-filled message text
   - Contact selector (optional)
   - Image preview

2. **URL Scheme Integration**
   ```swift
   whatsapp://send?text={encoded_text}
   // With specific number: whatsapp://send?phone={number}&text={encoded_text}
   ```

3. **Image Handling**
   - Save image to photo library first
   - Include app link in message
   - Emoji-rich message formatting

4. **Status Support**
   - Option to share as WhatsApp Status
   - Different formatting for status vs message

### Phase 3: Messages Share Implementation
**Files to modify:**
- `/SnapChef/Features/Sharing/Platforms/Messages/MessagesShareView.swift`

**Features:**
1. **Message Composer**
   - Native MFMessageComposeViewController
   - Recipient field
   - Message body with app link
   - Image attachment

2. **Implementation Details**
   ```swift
   MFMessageComposeViewController()
   addAttachmentData(imageData, typeIdentifier: "public.data", filename: "recipe.png")
   ```

3. **Rich Preview**
   - Include recipe metadata
   - App Store link
   - Formatted message body

4. **Fallback Handling**
   - Check canSendText() capability
   - Check canSendAttachments() capability
   - Handle delegate callbacks

## 🏗️ Architecture Pattern (Following Instagram)

### Base Structure
```swift
struct PlatformShareView: View {
    let content: ShareContent
    @Environment(\.dismiss) var dismiss
    @State private var messageText = ""
    @State private var isGenerating = false
    @State private var generatedImage: UIImage?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Platform-specific background color
                VStack {
                    // Header with platform branding
                    // Preview section
                    // Message/Caption composer
                    // Platform-specific options
                    // Share button with gradient
                }
            }
        }
    }
}
```

### Common Methods
- `generateCaption()` - Platform-specific message generation
- `generateAndShare()` - Image generation and sharing flow
- `createShareActivity()` - CloudKit activity tracking
- `getPlatformHashtags()` - Platform-specific hashtags

## 📊 Testing Checklist

### Per Platform Testing
- [ ] App availability check
- [ ] URL scheme functionality
- [ ] Web fallback
- [ ] Image generation
- [ ] Text encoding
- [ ] Character limits
- [ ] Analytics tracking
- [ ] Error handling
- [ ] UI responsiveness
- [ ] Color accuracy

### Cross-Platform Testing
- [ ] Consistent UI patterns
- [ ] Activity feed integration
- [ ] Memory management
- [ ] Build compilation
- [ ] SwiftUI preview

## 🔧 Technical Requirements

### Dependencies
```swift
import SwiftUI
import UIKit
import MessageUI  // For Messages only
```

### Info.plist Updates
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>twitter</string>
    <string>whatsapp</string>
    <!-- Messages uses native framework, no scheme needed -->
</array>
```

### Permissions
- Photo Library Usage (for saving generated images)
- Already configured in existing app

## 📈 Success Metrics

### Implementation Goals
- Maintain Instagram-level UI quality
- Platform-specific optimizations
- <2 second share flow
- Zero crashes
- Proper fallback handling

### User Experience Goals
- Intuitive interface
- Platform-familiar patterns
- Quick sharing flow
- Error recovery
- Visual feedback

## 🚀 Implementation Timeline

### Day 1: X (Twitter)
1. Create TwitterShareView.swift
2. Implement UI with X branding
3. Add URL scheme integration
4. Test and debug
5. Build verification

### Day 2: WhatsApp
1. Create WhatsAppShareView.swift
2. Implement UI with WhatsApp branding
3. Add URL scheme integration
4. Test and debug
5. Build verification

### Day 3: Messages
1. Create MessagesShareView.swift
2. Implement MFMessageComposeViewController
3. Add attachment handling
4. Test and debug
5. Build verification

### Day 4: Integration & Polish
1. Update BrandedSharePopup.swift
2. Add new platforms to share menu
3. Test all platforms together
4. Update CLAUDE.md documentation
5. Final build verification

## 🎯 Best Practices

### X (Twitter) Specific
- Respect 280 character limit
- Use trending hashtags
- Include media preview
- Handle @mentions properly
- Test with/without app

### WhatsApp Specific
- URL encode all text
- Support international numbers
- Rich emoji usage
- Link preview support
- Status vs Message distinction

### Messages Specific
- Use native framework
- Handle MMS vs SMS
- Proper attachment types
- Recipient validation
- Delegate implementation

## 🔍 Known Limitations

### X (Twitter)
- No direct image attachment via URL scheme
- Must save to photo library first
- User must manually attach from Twitter app

### WhatsApp
- No API/SDK available
- URL scheme only
- Cannot pre-attach images
- Limited to text and links

### Messages
- Camera button disabled in composer (iOS bug)
- MMS charges may apply
- No read receipts access
- Limited customization options

## 📝 Code Quality Standards

### Requirements
- Swift 6 compatibility
- Proper error handling
- Memory management
- SwiftUI best practices
- Accessibility support
- Documentation comments

### Testing
- Unit tests for caption generation
- UI tests for share flow
- Integration tests for URL schemes
- Error scenario testing
- Performance profiling

## 🎨 UI/UX Guidelines

### Consistency with Instagram Implementation
- Similar layout structure
- Matching animation styles
- Consistent button placement
- Similar preview sizing
- Matching font weights

### Platform-Specific Adaptations
- Use platform brand colors
- Platform-appropriate icons
- Native UI patterns where applicable
- Platform-specific terminology
- Appropriate default text

## 📱 Final Deliverables

### Code Files
1. `TwitterShareView.swift`
2. `WhatsAppShareView.swift`
3. `MessagesShareView.swift`
4. Updated `BrandedSharePopup.swift`

### Documentation
1. Updated `CLAUDE.md` with sharing methods
2. Code comments for complex logic
3. This implementation plan (updated with results)

### Testing Evidence
1. Screenshots of each platform
2. Build success logs
3. Test results documentation

---

## Implementation Status

| Platform | Status | Build Test | Notes |
|----------|--------|------------|-------|
| X (Twitter) | ⏳ Pending | - | - |
| WhatsApp | ⏳ Pending | - | - |
| Messages | ⏳ Pending | - | - |

Last Updated: 2025-01-08