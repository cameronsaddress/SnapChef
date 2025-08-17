# SnapChef Comprehensive Error Handling System

This document describes the unified error handling system implemented in SnapChef to provide better user experiences, recovery strategies, and error analytics.

## Overview

The new error handling system provides:
- **Unified Error Types**: Comprehensive SnapChefError enum covering all app scenarios
- **Recovery Strategies**: Automatic retry mechanisms and user-guided recovery
- **User-Friendly Messages**: Context-aware, actionable error messages
- **Error Analytics**: Comprehensive logging and crash reporting
- **UI Components**: Banners, alerts, and boundary components

## Core Components

### 1. SnapChefError Enum

```swift
enum SnapChefError: LocalizedError, Equatable {
    // Network & API
    case networkError(String, recovery: ErrorRecoveryStrategy = .retry)
    case apiError(String, statusCode: Int? = nil, recovery: ErrorRecoveryStrategy = .retry)
    case timeoutError(String, recovery: ErrorRecoveryStrategy = .retry)
    case rateLimitError(String, retryAfter: TimeInterval? = nil)
    
    // Authentication & Authorization
    case authenticationError(String, recovery: ErrorRecoveryStrategy = .reauthenticate)
    case unauthorizedError(String, recovery: ErrorRecoveryStrategy = .reauthenticate)
    case subscriptionError(String, recovery: ErrorRecoveryStrategy = .manageSubscription)
    
    // Device & Permissions
    case cameraError(String, recovery: ErrorRecoveryStrategy = .openSettings)
    case photoLibraryError(String, recovery: ErrorRecoveryStrategy = .openSettings)
    case microphoneError(String, recovery: ErrorRecoveryStrategy = .openSettings)
    
    // Data & Storage
    case storageError(String, recovery: ErrorRecoveryStrategy = .retry)
    case cloudKitError(CKError, recovery: ErrorRecoveryStrategy = .retry)
    case dataCorruptionError(String, recovery: ErrorRecoveryStrategy = .clearData)
    case syncError(String, recovery: ErrorRecoveryStrategy = .forcSync)
    
    // And more...
}
```

### 2. Error Recovery Strategies

```swift
enum ErrorRecoveryStrategy: Equatable {
    case none
    case retry
    case retryAfter(TimeInterval)
    case reauthenticate
    case openSettings
    case manageSubscription
    case clearData
    case forcSync
    case closeApp
    case contactSupport
}
```

### 3. Error Severity Levels

```swift
enum ErrorSeverity {
    case low       // Informational, user can continue
    case medium    // Warning, may affect functionality
    case high      // Error, blocks current operation
    case critical  // Severe error, may require app restart
}
```

## Usage Examples

### Basic Error Handling

```swift
struct RecipeView: View {
    @State private var currentError: SnapChefError?
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            // Your content here
        }
        .errorBanner($currentError) {
            // Retry action
            loadRecipes()
        }
    }
    
    private func loadRecipes() {
        Task {
            do {
                let recipes = try await recipeService.fetchRecipes()
                // Handle success
            } catch {
                let snapChefError = error as? SnapChefError ?? 
                    .unknown("Failed to load recipes: \(error.localizedDescription)")
                currentError = snapChefError
                appState.handleError(snapChefError, context: "recipe_loading")
            }
        }
    }
}
```

### API Calls with Enhanced Error Handling

```swift
@MainActor
class RecipeService: ObservableObject {
    @Published var isLoading = false
    @Published var lastError: SnapChefError?
    
    private let apiService = ErrorAwareAPIService()
    
    func generateRecipes(from image: UIImage) async -> [Recipe] {
        isLoading = true
        
        let result = await apiService.generateRecipes(from: image)
        
        switch result {
        case .success(let recipes):
            isLoading = false
            return recipes
            
        case .failure(let error):
            isLoading = false
            lastError = error
            
            // Handle specific error types
            switch error {
            case .rateLimitError(_, let retryAfter):
                // Show rate limit message with countdown
                scheduleRetry(after: retryAfter ?? 60)
            case .authenticationError(_):
                // Navigate to sign-in
                NotificationCenter.default.post(name: .authenticationRequired, object: nil)
            default:
                // Show general error
                break
            }
            
            return []
        }
    }
}
```

### Error Boundaries for Robust UI

```swift
struct RobustRecipeListView: View {
    var body: some View {
        ErrorBoundary(
            content: {
                RecipeListView()
            },
            onError: { error in
                ErrorAnalytics.logError(error, context: "recipe_list_boundary")
            },
            fallback: { error in
                AnyView(
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text("Unable to load recipes")
                            .font(.headline)
                        
                        Text(error.userFriendlyMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Try Again") {
                            // Retry logic
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                )
            }
        )
    }
}
```

### CloudKit Operations with Error Handling

```swift
extension CloudKitRecipeManager {
    func uploadRecipeWithErrorHandling(_ recipe: Recipe) async {
        let result = await safeUploadRecipe(recipe)
        
        switch result {
        case .success(let recipeId):
            print("Recipe uploaded successfully: \(recipeId)")
            
        case .failure(let error):
            switch error {
            case .cloudKitError(let ckError):
                // Handle specific CloudKit errors
                if ckError.code == .quotaExceeded {
                    // Show storage management options
                }
            case .networkError(_):
                // Show retry with network troubleshooting
                break
            default:
                // Handle other errors
                break
            }
        }
    }
}
```

### Retry Mechanism Usage

```swift
@StateObject private var retryManager = RetryManager.shared

func performNetworkOperation() {
    retryManager.attemptRetry(
        operationId: "fetch_recipes",
        operation: {
            try await apiService.fetchRecipes()
        },
        onSuccess: { recipes in
            self.recipes = recipes
        },
        onFailure: { error in
            self.currentError = error
        }
    )
}
```

## UI Components

### Error Banner
Shows contextual error messages at the top of screens with auto-dismiss and action buttons.

```swift
.errorBanner($error, onAction: retryAction, onDismiss: dismissAction)
```

### Error Alert
Traditional modal alerts with enhanced action handling.

```swift
.errorAlert($error, onAction: actionHandler, onRetry: retryHandler)
```

### Loading with Error State
Combines loading indicators with error handling.

```swift
.withLoadingAndError(state: asyncState, retryAction: retryAction)
```

## Best Practices

### 1. Error Context
Always provide context when logging errors:

```swift
ErrorAnalytics.logError(error, context: "camera_capture_failed", userId: userID)
```

### 2. User-Friendly Messages
Use descriptive, actionable error messages:

```swift
// ❌ Bad
.apiError("HTTP 500")

// ✅ Good
.apiError("Our servers are temporarily busy. Please try again in a moment.", statusCode: 500, recovery: .retry)
```

### 3. Recovery Strategies
Choose appropriate recovery strategies:

```swift
// Network issues -> retry
.networkError("Connection failed", recovery: .retry)

// Permission issues -> open settings
.cameraError("Camera access needed", recovery: .openSettings)

// Authentication issues -> re-authenticate
.authenticationError("Please sign in again", recovery: .reauthenticate)
```

### 4. Error Boundaries
Wrap critical UI sections in error boundaries:

```swift
// Wrap entire features
ErrorBoundary {
    CameraFeatureView()
}

// Wrap data-dependent views
ErrorBoundary {
    RecipeListView()
}
```

### 5. Async State Management
Use AsyncState for consistent loading/error states:

```swift
@StateObject private var asyncOp = AsyncOperationManager<[Recipe]>(operationId: "load_recipes")

var body: some View {
    content
        .withLoadingAndError(state: asyncOp.state) {
            asyncOp.retry(operation: loadRecipes)
        }
}
```

## Testing Error Handling

### Unit Tests
```swift
func testNetworkErrorHandling() async {
    let error = SnapChefError.networkError("Test error")
    
    XCTAssertEqual(error.severity, .medium)
    XCTAssertEqual(error.recovery, .retry)
    XCTAssertEqual(error.category, .network)
}

func testRetryMechanism() async {
    let retryManager = RetryManager.shared
    var attemptCount = 0
    
    retryManager.attemptRetry(
        operationId: "test_operation",
        operation: {
            attemptCount += 1
            if attemptCount < 3 {
                throw SnapChefError.networkError("Test failure")
            }
            return "Success"
        },
        onSuccess: { result in
            XCTAssertEqual(result, "Success")
            XCTAssertEqual(attemptCount, 3)
        },
        onFailure: { _ in
            XCTFail("Should have succeeded after retries")
        }
    )
}
```

### UI Tests
```swift
func testErrorBannerDisplay() {
    app.launch()
    
    // Trigger error condition
    app.buttons["Trigger Error"].tap()
    
    // Verify error banner appears
    XCTAssertTrue(app.staticTexts["Network Error"].exists)
    XCTAssertTrue(app.buttons["Retry"].exists)
    
    // Test retry functionality
    app.buttons["Retry"].tap()
    
    // Verify banner dismisses on success
    XCTAssertFalse(app.staticTexts["Network Error"].exists)
}
```

## Integration Checklist

- [ ] Replace all legacy error handling with SnapChefError
- [ ] Add error boundaries to critical UI sections
- [ ] Implement retry mechanisms for network operations
- [ ] Add comprehensive error logging
- [ ] Update API services to use enhanced error handling
- [ ] Add error handling tests
- [ ] Update user-facing error messages
- [ ] Implement recovery strategies for each error type
- [ ] Add analytics for error tracking
- [ ] Test error scenarios across all features

## Migration from Legacy Errors

1. **Replace error types**: Convert existing error enums to SnapChefError
2. **Update error handling**: Replace basic alerts with enhanced UI components
3. **Add recovery strategies**: Implement appropriate recovery actions
4. **Enhance logging**: Use ErrorAnalytics for comprehensive tracking
5. **Test thoroughly**: Verify all error scenarios work correctly

This comprehensive error handling system ensures users have a smooth experience even when things go wrong, with clear messaging, automatic recovery, and robust error tracking for continuous improvement.