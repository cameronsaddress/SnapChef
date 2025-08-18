# Swift 6 Best Practices Guide for SnapChef Agents

## Critical Instructions
**ALL AGENTS MUST READ AND FOLLOW THIS GUIDE BEFORE MAKING ANY CODE CHANGES**

This guide addresses the most common Swift 6 mistakes and provides specific patterns for the SnapChef codebase. Following these patterns will prevent compilation errors and maintain code quality.

---

## 1. Common Swift 6 Mistakes and How to Avoid Them

### 1.1 MainActor Isolation Errors
**❌ WRONG:**
```swift
class SomeManager {
    func updateUI() {
        // This will cause MainActor isolation error
    }
}
```

**✅ CORRECT:**
```swift
@MainActor
final class SomeManager: ObservableObject {
    func updateUI() {
        // Properly isolated to MainActor
    }
}
```

### 1.2 Singleton Pattern with MainActor
**❌ WRONG:**
```swift
@MainActor
class SomeManager {
    static let shared = SomeManager() // Compilation error
}
```

**✅ CORRECT:**
```swift
@MainActor
final class SomeManager {
    static let shared: SomeManager = {
        let instance = SomeManager()
        return instance
    }()
    
    private init() {} // Private initializer for singleton
}
```

### 1.3 Sendable Conformance
**❌ WRONG:**
```swift
struct Recipe: Codable {
    // Missing Sendable conformance for async operations
}
```

**✅ CORRECT:**
```swift
struct Recipe: Codable, Sendable {
    // Safe for concurrent operations
}
```

---

## 2. SwiftUI Property Wrapper Usage

### 2.1 When to Use Each Property Wrapper

#### @StateObject
Use for **creating and owning** a new ObservableObject instance:
```swift
struct ContentView: View {
    @StateObject private var viewModel = RecipeViewModel() // ✅ CORRECT
    
    var body: some View {
        // View content
    }
}
```

#### @ObservedObject  
Use for **receiving** an ObservableObject from parent:
```swift
struct RecipeDetailView: View {
    @ObservedObject var recipe: Recipe // ✅ CORRECT - passed from parent
    
    var body: some View {
        // View content
    }
}
```

#### @EnvironmentObject
Use for **dependency injection** across view hierarchy:
```swift
struct SomeView: View {
    @EnvironmentObject var appState: AppState // ✅ CORRECT
    
    var body: some View {
        // View content
    }
}
```

### 2.2 Critical Property Wrapper Rules
1. **NEVER** use `@StateObject` for objects passed from parent views
2. **NEVER** use `@ObservedObject` for creating new instances
3. **ALWAYS** check if the class conforms to `ObservableObject` before using property wrappers

---

## 3. Singleton Pattern Usage in SnapChef

### 3.1 Correct Singleton Access Patterns

#### SnapChefAPIManager
```swift
// ✅ CORRECT: Use .shared for singleton access
let apiManager = SnapChefAPIManager.shared
```

#### CloudKitAuthManager  
```swift
// ✅ CORRECT: Use .shared for singleton access
let authManager = CloudKitAuthManager.shared
```

#### UserLifecycleManager
```swift
// ✅ CORRECT: Use .shared for singleton access
let lifecycle = UserLifecycleManager.shared
```

### 3.2 When NOT to Use .shared
**❌ NEVER use .shared for:**
- Regular view models
- Data models (Recipe, User, etc.)
- Service classes that aren't singletons

---

## 4. API Manager Access Patterns

### 4.1 Correct API Manager Usage
```swift
// ✅ CORRECT: Access singleton properly
let apiManager = SnapChefAPIManager.shared

// ✅ CORRECT: Use async/await pattern
Task {
    do {
        let response = try await apiManager.analyzeRestaurantMeal(
            image: image,
            sessionID: sessionID
        )
        // Handle response
    } catch {
        // Handle error
    }
}
```

### 4.2 NetworkManager vs SnapChefAPIManager
**❌ WRONG:** There is no `NetworkManager` in SnapChef
**✅ CORRECT:** Use `SnapChefAPIManager.shared`

### 4.3 API Manager Capabilities
The SnapChefAPIManager provides:
- `sendImageForRecipeGeneration()` - For fridge/pantry analysis
- `sendBothImagesForRecipeGeneration()` - For dual image analysis  
- `analyzeRestaurantMeal()` - For Recipe Detective feature
- `convertAPIRecipeToAppRecipe()` - For API response conversion
- `convertAPIDetectiveRecipeToDetectiveRecipe()` - For detective recipe conversion

---

## 5. Concurrency and Actor Isolation

### 5.1 MainActor Usage
```swift
@MainActor
final class ViewModel: ObservableObject {
    @Published var state: String = ""
    
    func updateUI() {
        // Automatically runs on main thread
        self.state = "Updated"
    }
}
```

### 5.2 Background Tasks
```swift
// ✅ CORRECT: Explicit async/await
func performBackgroundWork() async {
    let result = await someAsyncOperation()
    
    // ✅ CORRECT: Switch to MainActor for UI updates
    await MainActor.run {
        self.updateUI(with: result)
    }
}
```

### 5.3 Task Management
```swift
// ✅ CORRECT: Proper Task usage
Task {
    do {
        let data = try await networkCall()
        await MainActor.run {
            self.updateUI(data)
        }
    } catch {
        await MainActor.run {
            self.handleError(error)
        }
    }
}
```

---

## 6. How to Check if a Class Conforms to ObservableObject

### 6.1 Before Using Property Wrappers
**ALWAYS verify conformance:**

```swift
// ✅ Check in Xcode:
// 1. Command+click on the class name
// 2. Look for ": ObservableObject" in the class declaration
// 3. Look for @Published properties

// Example - AppState DOES conform to ObservableObject:
@MainActor
final class AppState: ObservableObject {
    @Published var isLoading: Bool = false
    // ... other @Published properties
}

// Example - Recipe does NOT conform to ObservableObject:
struct Recipe: Codable, Sendable {
    // This is a data model, not an ObservableObject
}
```

### 6.2 Common Non-ObservableObject Classes
These classes do **NOT** conform to ObservableObject:
- `Recipe` (data model)
- `User` (data model)  
- `DetectiveRecipe` (data model)
- `Challenge` (data model)
- Plain service classes without `@Published` properties

---

## 7. When to Use Task, MainActor, and async/await

### 7.1 Task Usage
Use `Task` for:
- Starting async operations from sync context
- API calls from button actions
- Background processing

```swift
// ✅ CORRECT: Button action
Button("Analyze") {
    Task {
        await analyzeImage()
    }
}
```

### 7.2 MainActor Usage
Use `@MainActor` for:
- UI-related classes and methods
- ViewModels with @Published properties
- Any code that updates UI

### 7.3 async/await Usage
Use `async/await` for:
- Network operations
- File operations
- Database operations
- Any potentially time-consuming operations

---

## 8. How to Properly Access Environment Objects

### 8.1 Correct Environment Object Access
```swift
struct SomeView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            // ✅ CORRECT: Access published properties directly
            Text("Loading: \(appState.isLoading ? "Yes" : "No")")
            
            // ✅ CORRECT: Call methods on the environment object
            Button("Clear Error") {
                appState.clearError()
            }
        }
    }
}
```

### 8.2 AppState Property Access
**Available AppState properties:**
- `isLoading: Bool`
- `currentUser: User?`
- `selectedRecipe: Recipe?`
- `recentRecipes: [Recipe]`
- `allRecipes: [Recipe]`
- `savedRecipes: [Recipe]`
- `error: AppError?`
- `currentSnapChefError: SnapChefError?`

**Available AppState methods:**
- `addRecentRecipe(_:)`
- `toggleRecipeSave(_:)`
- `clearError()`
- `handleError(_:context:)`
- `trackRecipeCreated(_:)`

---

## 9. Common Compilation Errors and Solutions

### 9.1 "Cannot use instance member within property initializer"
**❌ WRONG:**
```swift
class ViewModel: ObservableObject {
    @Published var data = someInstanceMethod() // Error
}
```

**✅ CORRECT:**
```swift
class ViewModel: ObservableObject {
    @Published var data: DataType
    
    init() {
        self.data = someInstanceMethod()
    }
}
```

### 9.2 "Main actor-isolated property cannot be mutated from a nonisolated context"
**❌ WRONG:**
```swift
Task {
    self.isLoading = true // Error if not on MainActor
}
```

**✅ CORRECT:**
```swift
Task {
    await MainActor.run {
        self.isLoading = true
    }
}
```

### 9.3 "Value of type 'X' has no member 'toRegularRecipe'"
**❌ WRONG:**
```swift
let regular = detectiveRecipe.toRegularRecipe() // Method doesn't exist
```

**✅ CORRECT:**
```swift
let regular = detectiveRecipe.toBaseRecipe() // Correct method name
```

---

## 10. Testing Code with SwiftLint

### 10.1 Before Making Changes
**ALWAYS run SwiftLint before committing:**

```bash
# In the ios directory
swiftlint

# Auto-fix issues where possible
swiftlint --fix
```

### 10.2 Common SwiftLint Rules to Follow
- Use `final` for classes that won't be inherited
- Use proper access control (`private`, `internal`, `public`)
- Remove unused variables and imports
- Follow naming conventions
- Keep line length under 120 characters

---

## 11. Specific SnapChef Patterns

### 11.1 Error Handling Pattern
```swift
// ✅ CORRECT: Use SnapChefError for new error handling
func handleError(_ error: Error) {
    if let snapChefError = error as? SnapChefError {
        appState.handleError(snapChefError)
    } else {
        let converted = SnapChefError.unknown(error.localizedDescription)
        appState.handleError(converted)
    }
}
```

### 11.2 Recipe Conversion Pattern
```swift
// ✅ CORRECT: Convert API models to app models
let appRecipe = SnapChefAPIManager.shared.convertAPIRecipeToAppRecipe(apiRecipe)

// ✅ CORRECT: Convert detective recipes
let baseRecipe = detectiveRecipe.toBaseRecipe()
```

### 11.3 Authentication Check Pattern
```swift
// ✅ CORRECT: Check authentication state
if CloudKitAuthManager.shared.isAuthenticated {
    // Perform authenticated operation
} else {
    // Handle unauthenticated state
}
```

---

## 12. Pre-Flight Checklist

Before making ANY code changes, verify:

- [ ] The class you're modifying actually exists
- [ ] You're using the correct singleton pattern (`.shared` vs direct instantiation)
- [ ] You're using the correct property wrapper for the context
- [ ] You're checking ObservableObject conformance before using @StateObject/@ObservedObject
- [ ] You're using the correct method names (toBaseRecipe, not toRegularRecipe)
- [ ] You're handling MainActor isolation correctly
- [ ] You're using async/await patterns for network operations
- [ ] You've run SwiftLint to check for issues

---

## 13. Emergency Fixes for Common Errors

### 13.1 If You See "Cannot find 'NetworkManager'"
Replace with:
```swift
let apiManager = SnapChefAPIManager.shared
```

### 13.2 If You See "Cannot find 'toRegularRecipe'"
Replace with:
```swift
let recipe = detectiveRecipe.toBaseRecipe()
```

### 13.3 If You See MainActor Isolation Errors
Wrap UI updates in:
```swift
await MainActor.run {
    // UI update code here
}
```

### 13.4 If You See Property Wrapper Errors
Check if the class conforms to ObservableObject:
- If YES: Use @StateObject (for creation) or @ObservedObject (for injection)
- If NO: Use @State or regular property

---

## 14. Resources and References

### 14.1 Key Files to Reference
- `/SnapChef/Core/Networking/SnapChefAPIManager.swift` - API patterns
- `/SnapChef/Core/ViewModels/AppState.swift` - State management patterns
- `/SnapChef/Core/Models/` - Data model patterns

### 14.2 When in Doubt
1. **Check existing code** for similar patterns
2. **Use the Read tool** to examine file structure before modifying
3. **Follow the singleton patterns** established in the codebase
4. **Test with SwiftLint** before committing

---

**Remember: It's better to ask for clarification than to introduce compilation errors!**