# SnapChef iOS App

## Overview
Native iOS app for SnapChef - transform your fridge into recipes using AI.

## Requirements
- Xcode 15.0 or later
- iOS 16.0+ deployment target
- Swift 5.9+

## Project Structure
```
SnapChef/
├── App/                    # Main app entry point
│   ├── SnapChefApp.swift
│   └── ContentView.swift
├── Core/                   # Core functionality
│   ├── Models/            # Data models
│   ├── ViewModels/        # View models and app state
│   ├── Services/          # Business logic services
│   ├── Networking/        # API communication
│   └── Utilities/         # Helper classes
├── Features/              # Feature modules
│   ├── Camera/           # Camera and photo capture
│   ├── Recipes/          # Recipe display and management
│   ├── Authentication/   # User auth and onboarding
│   ├── Sharing/          # Social sharing features
│   └── Profile/          # User profile
└── Design/               # UI components and assets
    ├── Components/       # Reusable UI components
    └── Assets.xcassets/  # Images and colors
```

## Building the Project

### Using Xcode
1. Open `SnapChef.xcodeproj` in Xcode
2. Select a simulator or device
3. Press Cmd+R to build and run

### Using Command Line
```bash
# Make the build script executable (first time only)
chmod +x build.sh

# Build for simulator
./build.sh
```

## Configuration
- Bundle ID: `com.snapchef.app`
- Minimum iOS Version: 16.0
- Supported Orientations: Portrait only (iPhone), All (iPad)

## Key Features
- Camera integration for fridge/pantry photos
- AI-powered ingredient detection
- Recipe generation based on available ingredients
- Social sharing to TikTok and Instagram
- Google Sign-In authentication
- Haptic feedback for enhanced UX

## Dependencies
- GoogleSignIn-iOS (7.0.0+)

## Permissions Required
- Camera - For taking photos of ingredients
- Photo Library - For saving recipe photos
- Network - For API communication

## Development Notes
- SwiftUI-based architecture
- MVVM pattern with Combine for reactive updates
- Mock data provider for testing without API
- Haptic feedback manager for user interactions