# SnapChef iOS Architecture Guide

## Overview

SnapChef follows a clean architecture pattern with clear separation of concerns, making the codebase maintainable, testable, and scalable.

## Architecture Pattern: MVVM + SwiftUI

```
┌─────────────────────────────────────────────────────────┐
│                     Presentation Layer                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │    Views    │  │   ViewModels │  │  UI Components│    │
│  │  (SwiftUI)  │  │  (@StateObject)│ │(Reusable)   │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                      Domain Layer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   Models    │  │   Managers   │  │   Services   │    │
│  │  (Entities) │  │ (Business Logic)│ │(Use Cases)  │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                       Data Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │     API     │  │   Keychain   │  │  UserDefaults│    │
│  │  (Network)  │  │  (Secure)    │  │  (Settings)  │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Core Principles

### 1. **Single Responsibility**
Each class/struct has one clear purpose:
- Views: UI presentation only
- ViewModels: UI state and logic
- Managers: Business logic
- Services: External integrations

### 2. **Dependency Injection**
- Environment objects for app-wide dependencies
- Explicit initializer injection for testability
- Protocol-oriented design for mocking

### 3. **Reactive Data Flow**
- SwiftUI's declarative approach
- Combine for async operations
- @Published properties for state changes

## Layer Breakdown

### Presentation Layer

#### Views
- Pure SwiftUI views
- No business logic
- Bind to ViewModels or StateObjects
- Example: `HomeView.swift`, `CameraView.swift`

```swift
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingCamera = false
    
    var body: some View {
        // Pure UI code
    }
}
```

#### ViewModels
- Contains view-specific logic
- Manages UI state
- Communicates with services/managers
- Example: `AppState.swift`

```swift
class AppState: ObservableObject {
    @Published var isFirstLaunch: Bool
    @Published var currentUser: User?
    @Published var savedRecipes: [SavedRecipe] = []
}
```

#### Reusable Components
- Generic UI components
- Highly customizable
- No business logic
- Example: `GlassmorphicComponents.swift`

### Domain Layer

#### Models
- Data structures
- Business entities
- Codable for API/persistence
- Example: `Recipe.swift`

```swift
struct Recipe: Identifiable, Codable {
    let id: String
    let name: String
    let ingredients: [String]
    // ... other properties
}
```

#### Managers
- Orchestrate business logic
- Coordinate between services
- Maintain app state
- Example: `GamificationManager.swift`

```swift
class GamificationManager: ObservableObject {
    @Published var points: Int = 0
    @Published var achievements: [Achievement] = []
    
    func awardPoints(for action: GameAction) {
        // Business logic
    }
}
```

#### Services
- Handle specific operations
- External integrations
- Stateless when possible
- Example: `AuthenticationManager.swift`

### Data Layer

#### Network Layer
- API communication
- Request/response handling
- Error management
- Example: `SnapChefAPIManager.swift`

```swift
class SnapChefAPIManager {
    static let shared = SnapChefAPIManager()
    
    func analyzeImage(_ image: UIImage, preferences: UserPreferences) async throws -> [Recipe] {
        // API call implementation
    }
}
```

#### Persistence
- Keychain for sensitive data
- UserDefaults for settings
- File system for cache
- Example: `KeychainManager.swift`

## Data Flow

### Unidirectional Data Flow
```
User Action → View → ViewModel → Service/Manager → API/Storage
                ↑                                        ↓
                ←────────── State Update ←───────────────
```

### Example: Taking a Photo
1. User taps camera button in `HomeView`
2. View presents `CameraView`
3. `CameraModel` handles AVFoundation
4. Photo captured → `CapturedImageView`
5. User confirms → `SnapChefAPIManager.analyzeImage()`
6. API response → `Recipe` models created
7. `RecipeResultsView` displays results
8. User can save → Updates `AppState.savedRecipes`

## Key Design Patterns

### 1. **Singleton Pattern**
Used sparingly for truly global services:
```swift
class HapticManager {
    static let shared = HapticManager()
    private init() {}
}
```

### 2. **Observer Pattern**
SwiftUI's built-in property wrappers:
- `@StateObject` / `@ObservedObject`
- `@EnvironmentObject`
- `@Published`

### 3. **Factory Pattern**
For creating complex objects:
```swift
struct RecipeFactory {
    static func createFromAPI(_ apiRecipe: APIRecipe) -> Recipe {
        // Transformation logic
    }
}
```

### 4. **Coordinator Pattern**
Navigation handling (simplified in SwiftUI):
```swift
class NavigationManager: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var navigationPath = NavigationPath()
}
```

## Error Handling

### API Errors
```swift
enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case serverError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        // User-friendly messages
    }
}
```

### UI Error Presentation
```swift
struct ErrorView: View {
    let error: Error
    let retry: () -> Void
}
```

## Testing Strategy

### Unit Tests
- Test models and business logic
- Mock dependencies
- Test ViewModels in isolation

### Integration Tests
- Test API integration
- Test data persistence
- Test service interactions

### UI Tests
- Test critical user flows
- Test error scenarios
- Test different device sizes

## Performance Considerations

### Image Handling
- Compress before upload
- Cache processed images
- Load thumbnails in lists

### Animation Performance
- Use `.drawingGroup()` for complex animations
- Limit particle counts
- Profile with Instruments

### Memory Management
- Weak references where appropriate
- Clear caches on memory warnings
- Lazy loading for heavy resources

## Security Architecture

### Data Protection
- API keys in Keychain
- No sensitive data in UserDefaults
- SSL pinning for API calls

### User Privacy
- Minimal data collection
- Local processing when possible
- Clear data retention policies

## Scalability

### Modular Design
- Features in separate folders
- Clear dependencies
- Easy to add new features

### Code Reusability
- Generic components
- Protocol-oriented design
- Shared utilities

### Future Considerations
- Modularization with Swift packages
- Feature flags for A/B testing
- Backend-driven UI updates