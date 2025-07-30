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
xcodebuild test -project SnapChef.xcodeproj -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

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
3. **Features/Camera/CameraView.swift** - Main camera interface
4. **Features/Recipes/RecipeResultsView.swift** - Recipe display
5. **Core/ViewModels/AppState.swift** - Global app state management

### API Integration

#### Server Details
- **Base URL**: https://snapchef-server.onrender.com
- **Main Endpoint**: /analyze_fridge_image
- **Method**: POST (multipart/form-data)
- **Authentication**: X-App-API-Key header required

#### API Key
- **Header Name**: X-App-API-Key
- **Storage**: iOS Keychain (secure)
- **Fallback**: Available in code for development only

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
1. User captures photo in CameraView
2. Image sent to SnapChefAPIManager with preferences
3. API returns analyzed ingredients and recipes
4. Recipes converted from API format to app Recipe model
5. Results displayed in RecipeResultsView
6. User can save via ShareGeneratorView

### Key Features
- Real-time camera preview with AR-style overlays
- Magical UI animations and transitions (60fps target)
- Recipe sharing with custom graphics
- Gamification system (points, badges, challenges)
- AI Chef personalities (8 unique personas)
- Offline recipe storage
- Social media integration (Instagram, TikTok, Twitter/X)

### Testing Strategy
- Unit tests for API response parsing
- UI tests for camera flow
- Integration tests for recipe generation
- Performance tests for image processing

## Common Tasks

### Adding New User Preferences
1. Add @State variable in CameraView
2. Update SnapChefAPIManager.sendImageForRecipeGeneration parameters
3. Add form field in createMultipartFormData
4. Update UI to collect preference

### Debugging API Issues
1. Check API key in KeychainManager
2. Verify server is running at https://snapchef-server.onrender.com
3. Check network logs for response details
4. Ensure image compression quality is appropriate (80% JPEG)

### Adding New Features
1. Create feature folder under Features/
2. Add models in Core/Models if needed
3. Update navigation in ContentView if new tab
4. Add to Xcode project file
5. Update documentation

### UI/Animation Guidelines
- Use spring animations for natural motion
- Limit particle counts for performance
- Test on older devices (iPhone 12 minimum)
- Profile with Instruments for 60fps

### Security Notes
- API key should be in Keychain for production
- No sensitive data in UserDefaults
- Validate all user inputs before API calls
- Handle authentication errors gracefully

## Code Style Guidelines
- Use SwiftUI's declarative syntax
- Prefer @StateObject for view models
- Extract reusable components
- Keep views under 200 lines
- Use meaningful variable names
- Add MARK comments for organization

## Performance Tips
- Compress images before upload (80% JPEG)
- Use .drawingGroup() for complex animations
- Cache API responses when appropriate
- Lazy load heavy resources
- Profile memory usage regularly

## Common Issues & Solutions

### Build Errors
- Clean build folder: Cmd+Shift+K
- Delete derived data if needed
- Check Swift version compatibility

### API Timeout
- Default timeout is 30 seconds
- Can increase to 60 for slow connections
- Check image size (max 10MB)

### Animation Lag
- Reduce particle count
- Use .drawingGroup() modifier
- Profile with Instruments

## Server Repository
The FastAPI backend code is located at: https://github.com/cameronsaddress/snapchef-server