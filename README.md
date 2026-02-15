# SnapChef

AI-powered iOS recipe app that turns a photo of your fridge into personalized meal suggestions. Snap a picture of what you have, and the app generates recipes tailored to your available ingredients, dietary preferences, and cooking skill level.

**Live on the App Store:** [Download SnapChef](https://apps.apple.com/us/app/snapchef/id6749384208)

## Architecture

```
                    SnapChef iOS App (SwiftUI)
               Camera | Recipes | Social | Premium
                              |
                         HTTPS/REST
                              |
                    FastAPI Backend (Render)
                              |
              +---------------+---------------+
              |                               |
         Gemini Vision                    Grok Vision
         (primary)                        (fallback)
              |                               |
              +---------------+---------------+
                              |
                     Recipe Generation
                  (ingredients + preferences
                   + dietary restrictions)
```

## Tech Stack

| Layer | Technologies |
|---|---|
| **iOS App** | Swift, SwiftUI, CloudKit, StoreKit 2 |
| **Backend** | FastAPI, Python, Render (auto-deploy) |
| **AI/Vision** | Google Gemini Vision, Grok Vision (dual-provider with fallback) |
| **Storage** | CloudKit (user data, recipes, social), local caching |
| **Auth** | CloudKit-based authentication |
| **Payments** | StoreKit 2 (in-app purchases, premium subscription) |

## Key Features

### AI Recipe Generation
- Dual-image analysis: photograph both fridge and pantry for comprehensive ingredient detection
- Multi-provider LLM backend (Gemini primary, Grok fallback)
- Dietary restriction support (vegetarian, gluten-free, etc.)
- Configurable recipe count, cuisine preference, difficulty level, and health focus
- Duplicate recipe prevention across sessions

### Social Platform
- Recipe sharing and discovery feed
- Challenge system with viral mechanics
- User profiles with follower/following
- Like and comment system
- TikTok video sharing integration

### Premium Features
- Unlimited daily recipe generations
- Advanced dietary preferences
- Priority API access

## Project Structure

```
ios/SnapChef/
  App/                   App lifecycle and configuration
  Components/            Reusable SwiftUI components
  Core/                  Data models, networking, CloudKit
  Design/                Design system, colors, typography
  Features/              Feature modules (camera, recipes, social, premium)
  Resources/             Assets and localization
```

## Getting Started

### Prerequisites
- Xcode 15+
- iOS 17+ deployment target
- Apple Developer account (for CloudKit and StoreKit)

### Setup

1. Open `ios/SnapChef/SnapChef.xcodeproj` in Xcode
2. Configure signing with your Apple Developer team
3. Set up CloudKit container in Apple Developer portal
4. Build and run on simulator or device

### Backend

The FastAPI backend is hosted on Render and auto-deploys from the [SnapChef_Server](https://github.com/cameronsaddress/SnapChef_Server) repo.
