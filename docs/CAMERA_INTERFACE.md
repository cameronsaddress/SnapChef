# SnapChef Camera Interface Documentation

## Overview
The SnapChef camera interface has been redesigned to provide a clean, minimalist experience that matches the landing page aesthetic. It features:

- Same gradient background as the landing page
- iOS-style camera capture button
- Clean camera frame with viewfinder corners
- Minimal UI with only essential elements

## Design Features

### 1. **Gradient Background**
- Consistent purple-blue gradient (`#667eea` to `#764ba2`)
- Creates visual continuity from landing page
- Enhances the premium feel of the app

### 2. **Camera Frame**
- Dark translucent frame with backdrop blur
- Viewfinder corner markers for visual guidance
- 4:3 aspect ratio optimized for food photos
- Responsive sizing for all devices

### 3. **iOS-Style Camera Button**
- 80px circular button with white background
- Inner circle with subtle shadow
- Press animation (scale down on click)
- Familiar design pattern for users

### 4. **Mode Toggle**
- Simple Camera/Upload toggle
- Allows fallback for users without camera access
- Clean pill-shaped selector

### 5. **Minimal Navigation**
- Only a back button in top-left
- No distracting UI elements
- Focus on the capture experience

## User Flow

1. **Landing Page** → User clicks "SnapChef" button
2. **Camera Page** → Clean interface with camera frame
3. **Capture** → User takes photo or uploads image
4. **Preview** → Photo shown in frame with "Tap to analyze" button
5. **Processing** → Elegant loading overlay
6. **Results Page** → Recipes displayed with same gradient background

## Technical Implementation

### Key Components:
- `camera_minimal.py` - Main camera interface
- `results.py` - Recipe results display
- CSS-in-JS styling for consistency
- Session state management for flow control

### Features:
- Image optimization (max 1920x1920)
- Error handling with user-friendly messages
- Progress tracking and points system
- Free uses counter integration

## Accessibility
- Clear visual hierarchy
- High contrast buttons
- Touch-friendly targets (minimum 44px)
- Fallback upload option

## Mobile Optimization
- Responsive design
- Touch-optimized interactions
- Reduced button size on small screens
- Full-width layout on mobile

## Future Enhancements
- Ingredient editing before processing
- Multiple photo capture
- Gallery view for previous snaps
- Real-time ingredient detection preview