# Recipe Results Authentication Plan

## Overview
Fix the close button and add authentication prompts for save/like actions in RecipeResultsView, while allowing unauthenticated users to view and share recipes.

## Current Issues
1. **Close Button Not Working**: The dismiss() function on line 69 doesn't work properly
2. **No Auth Check**: Save/like actions don't check authentication status
3. **Poor UX**: Unauthenticated users can't tell they need to sign in

## Implementation Plan

### Phase 1: Fix Close Button ✅
**Problem**: The dismiss() environment variable doesn't work because RecipeResultsView is presented as fullScreenCover
**Solution**: Pass a binding or callback from parent view

#### Changes Needed:
1. **CameraView.swift** (line 278-290)
   - Pass explicit dismiss callback to RecipeResultsView
   - Current: `.fullScreenCover(isPresented: $showingResults)`
   - Fix: Add onDismiss parameter

2. **RecipeResultsView.swift** (line 69)
   - Replace `@Environment(\.dismiss) var dismiss` with callback
   - Add: `let onDismiss: () -> Void`
   - Update button action to call `onDismiss()`

### Phase 2: Authentication State Management
**Goal**: Track auth state and show appropriate UI

#### Add to RecipeResultsView:
```swift
@StateObject private var authManager = UnifiedAuthManager.shared
@State private var showAuthPrompt = false
@State private var pendingAction: PendingAction?

enum PendingAction {
    case save(Recipe)
    case like(Recipe)
}
```

### Phase 3: Auth Check for Save Action
**Location**: `saveRecipe()` function (line 179)

#### Modify Save Logic:
```swift
private func saveRecipe(_ recipe: Recipe) {
    guard authManager.isAuthenticated else {
        // Show auth prompt
        pendingAction = .save(recipe)
        showAuthPrompt = true
        return
    }
    
    // Existing save logic...
}
```

### Phase 4: Auth Check for Like Action
**Note**: Currently no like action in DetectiveRecipeCard - only save

#### Add Like Functionality:
1. Add like state tracking
2. Create `likeRecipe()` function
3. Check auth before liking
4. Show auth prompt if needed

### Phase 5: Beautiful Auth Prompt UI
**Design**: Slide-up card matching app's purple gradient theme

#### Components:
1. **AuthPromptSheet**: New view for authentication
   ```swift
   struct RecipeAuthPromptSheet: View {
       let action: String // "save" or "like"
       let recipeName: String
       @Binding var isPresented: Bool
       let onAuthenticated: () -> Void
   }
   ```

2. **Features**:
   - Icon: Lock that transforms to unlocked
   - Title: "Sign In to [Save/Like] Recipes"
   - Message: "Create your account to save '\(recipeName)' and build your recipe collection"
   - Benefits list:
     - Save unlimited recipes
     - Sync across devices
     - Track your favorites
     - Join the community
   - Sign in with Apple button
   - "Maybe Later" option

### Phase 6: Visual Feedback for Auth State
**Goal**: Show different UI for authenticated vs unauthenticated users

#### Changes to DetectiveRecipeCard:
1. **Save Button**:
   - Authenticated: Current behavior
   - Unauthenticated: Show lock icon, different text

2. **Visual Indicators**:
   ```swift
   Button(action: onSave) {
       HStack(spacing: 8) {
           Image(systemName: authManager.isAuthenticated ? 
                 (isSaved ? "heart.fill" : "heart") : 
                 "lock.fill")
           Text(authManager.isAuthenticated ? 
                (isSaved ? "Saved" : "Save") : 
                "Sign In to Save")
       }
   }
   ```

### Phase 7: Post-Authentication Actions
**Goal**: Complete the action after successful authentication

#### Implementation:
```swift
.sheet(isPresented: $showAuthPrompt) {
    RecipeAuthPromptSheet(
        action: pendingAction?.description ?? "",
        recipeName: pendingAction?.recipeName ?? "",
        isPresented: $showAuthPrompt,
        onAuthenticated: {
            // Complete pending action
            if let pending = pendingAction {
                switch pending {
                case .save(let recipe):
                    saveRecipe(recipe)
                case .like(let recipe):
                    likeRecipe(recipe)
                }
            }
            pendingAction = nil
        }
    )
}
```

### Phase 8: Share Without Auth
**Current**: Share works without auth ✅
**Keep**: This behavior - allow sharing to encourage viral growth

## UI/UX Considerations

### For Unauthenticated Users:
- ✅ Can view all recipe details
- ✅ Can share recipes (viral growth)
- ⚠️ Cannot save recipes (prompt to sign in)
- ⚠️ Cannot like recipes (prompt to sign in)

### Visual Cues:
1. Lock icons on restricted actions
2. "Sign In to Save" text instead of "Save"
3. Subtle animation drawing attention to sign-in
4. Toast message after sign-in: "Recipe saved!"

### Progressive Disclosure:
1. First interaction: Gentle prompt
2. Second interaction: Show benefits
3. Third interaction: Offer incentive (e.g., "Save 3 recipes to unlock challenge")

## Testing Checklist
- [ ] Close button works from recipe results
- [ ] Save prompts for auth when not signed in
- [ ] Like prompts for auth when not signed in
- [ ] Share works without authentication
- [ ] Auth prompt appears smoothly
- [ ] Pending actions complete after sign-in
- [ ] Visual feedback is clear
- [ ] No crashes or console errors
- [ ] Works on all device sizes

## Code Quality
- Use existing auth components (AuthPromptCard)
- Follow SwiftUI best practices
- Add proper error handling
- Include haptic feedback
- Maintain consistent styling

## Migration Notes
- Update all references to RecipeResultsView
- Test from CameraView flow
- Test from DetectiveView flow
- Ensure CloudKit sync still works
- Verify streak tracking continues

## Success Metrics
- Increased sign-up conversion from recipe results
- Users understand why sign-in is needed
- Smooth, frustration-free experience
- Maintains viral sharing capability