# SnapChef iOS Testing Guide

## Quick Start

1. **Open in Xcode**
   ```bash
   open SnapChef.xcodeproj
   ```

2. **Configure Signing**
   - Select your Apple Developer team in project settings
   - Update bundle ID if needed

3. **Run on Simulator**
   - Select iPhone 15 simulator
   - Press ⌘R to build and run

## Testing Without Backend

To test the app without a live API, I've included mock data support:

### Enable Mock Mode

1. In `NetworkManager.swift`, find the `analyzeImage` function
2. Add this at the beginning:

```swift
#if DEBUG
// Return mock data for testing
if true { // Set to false to use real API
    let mockRecipe = Recipe(
        name: "Test Recipe",
        description: "A delicious mock recipe",
        ingredients: [
            Ingredient(name: "Test Item 1", quantity: "2", unit: "cups", isAvailable: true),
            Ingredient(name: "Test Item 2", quantity: "1", unit: "tbsp", isAvailable: true)
        ],
        instructions: [
            "Step 1: Prepare ingredients",
            "Step 2: Cook everything",
            "Step 3: Enjoy!"
        ],
        cookTime: 20,
        prepTime: 10,
        servings: 4,
        difficulty: .easy,
        nutrition: Nutrition(calories: 250, protein: 20, carbs: 30, fat: 10, fiber: 5, sugar: 8, sodium: 500),
        imageURL: nil,
        createdAt: Date()
    )
    
    return RecipeGenerationResponse(
        success: true,
        recipes: [mockRecipe],
        error: nil,
        creditsRemaining: 2
    )
}
#endif
```

## Test Checklist

### ✅ Onboarding Flow
- [ ] App shows onboarding on first launch
- [ ] Can swipe through all 3 screens
- [ ] Skip button works
- [ ] Get Started completes onboarding

### ✅ Home Screen
- [ ] Gradient background animates
- [ ] Floating food animations work
- [ ] Free uses indicator shows (3 initially)
- [ ] "Snap Your Fridge" button opens camera

### ✅ Camera View
- [ ] Camera permission request appears
- [ ] Camera preview displays (black in simulator is normal)
- [ ] Switch camera button visible
- [ ] Test photo button appears in Debug mode
- [ ] Close (X) button works

### ✅ Recipe Results
- [ ] Recipes display after photo capture
- [ ] Can expand/collapse recipe details
- [ ] Ingredients scroll if many items
- [ ] Instructions show step-by-step
- [ ] Nutrition grid displays correctly
- [ ] Share button opens share sheet
- [ ] Print button shows print preview

### ✅ Share Functionality
- [ ] Share sheet displays recipe preview
- [ ] Can add custom message
- [ ] TikTok button styled correctly (black)
- [ ] Instagram button has gradient
- [ ] Copy link button works
- [ ] Credits reward message visible

### ✅ Profile
- [ ] Shows guest state initially
- [ ] Free uses remaining displays
- [ ] Stats show zeros initially
- [ ] Subscription card shows Free tier
- [ ] Settings rows are tappable

## Simulator Limitations

- **Camera**: Will show black screen - use "Test Photo" button
- **Sign in with Apple**: Requires real device or special simulator setup
- **TikTok/Instagram**: Deep links won't work, will show App Store

## Next Steps

1. **Add Mock Data**: Implement the mock response above
2. **Test on Device**: For camera and authentication testing
3. **Add API Backend**: Deploy the API for full functionality
4. **Configure OAuth**: Add real Google Client ID and Apple Sign-In

## Troubleshooting

### Build Errors
- Clean build folder: ⌘⇧K
- Reset package caches: File → Packages → Reset Package Caches

### Camera Issues
- Ensure Info.plist has camera usage description
- Test on real device for actual camera functionality

### Authentication
- Add your Google Client ID to Info.plist
- Configure Sign in with Apple in App Store Connect

## Assets Needed

Create these in Assets.xcassets:
- AppIcon (1024x1024)
- LaunchScreenImage (optional)
- AccentColor (set to white or gradient color)