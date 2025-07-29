# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
SnapChef is an iOS app that transforms fridge/pantry photos into personalized recipes using AI (Grok Vision API), with built-in social sharing and gamification features.

## Key Commands

### Development
```bash
# Build the project
xcodebuild -project SnapChef.xcodeproj -scheme SnapChef -configuration Debug

# Run tests
xcodebuild test -project SnapChef.xcodeproj -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Clean build folder
xcodebuild clean -project SnapChef.xcodeproj -scheme SnapChef
```

### Linting & Type Checking
```bash
# SwiftLint (if installed)
swiftlint

# Swift format (if using)
swift-format -i -r SnapChef/
```

## Architecture

### Core Components
1. **SnapChefApp.swift** - App entry point and scene configuration
2. **Core/Networking/SnapChefAPIManager.swift** - Grok Vision API integration
3. **Features/Camera/EnhancedCameraView.swift** - Main camera interface
4. **Features/Recipes/EnhancedRecipeResultsView.swift** - Recipe display
5. **Core/ViewModels/AppState.swift** - Global app state management

### API Integration

#### Server Details
- **Base URL**: https://snapchef-server.onrender.com
- **Main Endpoint**: /analyze_fridge_image
- **Method**: POST (multipart/form-data)
- **Authentication**: X-App-API-Key header required

#### API Key
- **Header Name**: X-App-API-Key
- **Header Value**: 5380e4b60818cf237678fccfd4b8f767d1c94

#### Request Format
```swift
// Required fields
- image_file: UIImage as JPEG data
- session_id: UUID string

// Optional fields
- dietary_restrictions: JSON array string (e.g., "[\"vegetarian\", \"gluten-free\"]")
- food_type: String (e.g., "Italian", "Mexican")
- difficulty_preference: String (e.g., "easy", "medium", "hard")
- health_preference: String (e.g., "healthy", "balanced", "indulgent")
- meal_type: String (e.g., "breakfast", "lunch", "dinner")
- cooking_time_preference: String (e.g., "quick", "under 30 mins")
- number_of_recipes: String number (e.g., "3")
```

#### Response Models
```swift
struct APIResponse {
    let data: GrokParsedResponse
    let message: String
}

struct GrokParsedResponse {
    let image_analysis: ImageAnalysis
    let ingredients: [IngredientAPI]
    let recipes: [RecipeAPI]
}

struct RecipeAPI {
    let id: String
    let name: String
    let description: String
    let difficulty: String
    let instructions: [String]
    let nutrition: NutritionAPI?
    // ... other fields
}
```

### Data Flow
1. User captures photo in EnhancedCameraView
2. Image sent to SnapChefAPIManager with preferences
3. API returns analyzed ingredients and recipes
4. Recipes converted from API format to app Recipe model
5. Results displayed in EnhancedRecipeResultsView
6. User can share via ShareGeneratorView

### Key Features
- Real-time camera preview with AR-style overlays
- Magical UI animations and transitions
- Recipe sharing with custom graphics
- Gamification system (points, badges, challenges)
- Subscription management (free tier + premium)
- Offline recipe storage

### Testing Strategy
- Unit tests for API response parsing
- UI tests for camera flow
- Integration tests for recipe generation
- Performance tests for image processing

## Common Tasks

### Adding New User Preferences
1. Add @State variable in EnhancedCameraView
2. Update SnapChefAPIManager.sendImageForRecipeGeneration parameters
3. Add form field in createMultipartRequest
4. Update UI to collect preference

### Debugging API Issues
1. Check API key in SnapChefAPIManager.swift
2. Verify server is running at https://snapchef-server.onrender.com
3. Check network logs for response details
4. Ensure image compression quality is appropriate

### Security Notes
- API key is currently hardcoded - consider moving to secure storage
- For production: Use Keychain or environment variables
- Validate all user inputs before sending to API
- Handle authentication errors gracefully

## Server Repository
The FastAPI backend code is located at: https://github.com/cameronsaddress/snapchef-server