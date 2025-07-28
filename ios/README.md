# SnapChef iOS App

Native iOS implementation of SnapChef using Swift and SwiftUI.

## Project Structure

```
SnapChef/
├── App/                    # App entry point and configuration
├── Core/                   # Core business logic
│   ├── Models/            # Data models
│   ├── ViewModels/        # View models (MVVM)
│   ├── Services/          # Business services
│   ├── Networking/        # API client
│   └── Utilities/         # Helper functions
├── Features/              # Feature modules
│   ├── Camera/           # Camera and photo capture
│   ├── Recipes/          # Recipe display and management
│   ├── Authentication/   # Sign in with Apple/Google
│   ├── Sharing/          # Social sharing
│   └── Profile/          # User profile
├── Design/               # UI components and styling
│   ├── Components/       # Reusable UI components
│   ├── Modifiers/        # SwiftUI view modifiers
│   └── Styles/           # Design system
└── Resources/            # Assets and configuration
```

## Requirements

- Xcode 15.0+
- iOS 16.0+
- Swift 5.9+

## Setup

1. Open `SnapChef.xcodeproj` in Xcode
2. Add required API keys to Info.plist:
   - `GOOGLE_CLIENT_ID`
   - `API_BASE_URL`
3. Configure signing & capabilities
4. Build and run

## Key Features

- Camera integration with AVFoundation
- Device fingerprinting for free tier
- OAuth authentication (Apple/Google)
- Real-time recipe generation
- Social sharing with rewards
- Offline capability

## Architecture

- **Pattern**: MVVM with Coordinators
- **UI**: SwiftUI
- **Networking**: URLSession with async/await
- **Storage**: Core Data + Keychain
- **Dependencies**: Minimal (Google Sign-In SDK only)

## Development Status

Currently implementing core features following the 8-agent development plan.