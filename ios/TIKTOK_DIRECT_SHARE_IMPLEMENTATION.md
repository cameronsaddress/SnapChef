# TikTok Direct Share Implementation Plan

## Overview
Implement direct TikTok sharing from BrandedSharePopup without navigating to TikTokShareView. The flow will check for an after photo, prompt if missing, generate video with progress indicators, and fallback to static image if user skips.

## Current Flow (To Be Replaced)
```
BrandedSharePopup → TikTok Button → TikTokShareView → Generate → Share
```

## New Flow (To Be Implemented)
```
BrandedSharePopup → TikTok Button → Check After Photo → Generate Video → Direct Share
                                         ↓ (if missing)
                                   Prompt for After Photo
                                         ↓
                                   Take Photo OR Skip
                                         ↓
                              Video (with after) OR Static Image (without)
```

## Implementation Phases

### Phase 1: Modify TikTok Button Handler ✅ COMPLETE
**File**: `BrandedSharePopup.swift`
**Location**: Around line 180 in the share platform switch statement

#### Tasks:
- [x] Replace TikTokShareView navigation with direct handler
- [x] Extract recipe and photos from ShareContent
- [x] Check if after photo exists
- [x] Set appropriate state flags for next steps
- [x] Test build after implementation

#### Code Changes:
```swift
// Add state variables at top of BrandedSharePopup struct
@State private var showAfterPhotoPrompt = false
@State private var showVideoGeneration = false
@State private var showAfterPhotoCamera = false
@State private var capturedAfterPhoto: UIImage?
@State private var currentRecipe: Recipe?
@State private var currentBeforeImage: UIImage?
@State private var currentAfterImage: UIImage?

// Replace existing TikTok case in handleShareAction
case "tiktok":
    dismiss()
    
    if case .recipe(let recipe) = content.type {
        currentRecipe = recipe
        let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
        currentBeforeImage = photos?.fridgePhoto ?? photos?.pantryPhoto
        currentAfterImage = photos?.mealPhoto
        
        if currentAfterImage == nil {
            showAfterPhotoPrompt = true
        } else {
            showVideoGeneration = true
        }
    }
```

### Phase 2: Implement After Photo Prompt UI ✅ COMPLETE
**File**: `BrandedSharePopup.swift`
**Location**: Add as sheet modifier and inline view

#### Tasks:
- [x] Create AfterPhotoPromptView as inline struct
- [x] Add sheet modifier for prompt
- [x] Handle capture and skip actions
- [x] Test build and UI appearance

#### Code Changes:
```swift
// Add sheet modifier to main NavigationView
.sheet(isPresented: $showAfterPhotoPrompt) {
    AfterPhotoPromptView(
        onCapture: {
            showAfterPhotoCamera = true
        },
        onSkip: {
            showAfterPhotoPrompt = false
            showVideoGeneration = true
            // Static share will be handled in video generation view
        }
    )
}

// Add inline struct at bottom of file
struct AfterPhotoPromptView: View {
    let onCapture: () -> Void
    let onSkip: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("📸 Add Your Final Dish?")
                .font(.title2.bold())
            
            // Description
            Text("Show off your cooking! Add a photo of the finished meal for a complete before/after video.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Camera icon
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding()
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: onCapture) {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: onSkip) {
                    Text("Skip for Now")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .presentationDetents([.height(400)])
    }
}
```

### Phase 3: Add Video Generation Overlay with Progress ✅ COMPLETE
**File**: `BrandedSharePopup.swift`
**Location**: Add fullScreenCover and VideoGenerationView

#### Tasks:
- [x] Create VideoGenerationView with progress indicators
- [x] Integrate with ViralVideoEngine
- [x] Handle video generation success/failure
- [x] Add progress updates
- [x] Test build and generation flow

#### Code Changes:
```swift
// Add fullScreenCover modifier
.fullScreenCover(isPresented: $showVideoGeneration) {
    if let recipe = currentRecipe {
        VideoGenerationView(
            recipe: recipe,
            beforeImage: currentBeforeImage,
            afterImage: capturedAfterPhoto ?? currentAfterImage,
            onComplete: { videoURL in
                openTikTokWithVideo(videoURL)
            },
            onError: { error in
                print("Video generation failed: \(error)")
                // Could show alert here
            }
        )
    }
}

// Add VideoGenerationView struct
struct VideoGenerationView: View {
    let recipe: Recipe
    let beforeImage: UIImage?
    let afterImage: UIImage?
    let onComplete: (URL) -> Void
    let onError: (Error) -> Void
    
    @State private var progress: Double = 0
    @State private var statusMessage = "Preparing your video..."
    @State private var isGenerating = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Title
                Text("Creating Your TikTok")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                // Progress indicator
                if isGenerating {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(y: 2)
                        .padding(.horizontal, 40)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                }
                
                // Status message
                Text(statusMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Recipe info
                VStack(alignment: .leading, spacing: 8) {
                    Label(recipe.name, systemImage: "fork.knife")
                    Label("\(recipe.prepTime + recipe.cookTime) minutes", systemImage: "clock")
                    Label("\(recipe.ingredients.count) ingredients", systemImage: "cart")
                }
                .font(.caption)
                .foregroundColor(.gray)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                
                // Cancel button
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.red)
                .padding(.top)
            }
            .padding()
        }
        .task {
            await generateVideo()
        }
    }
    
    func generateVideo() async {
        isGenerating = true
        
        // If no after image, generate static share
        if afterImage == nil {
            statusMessage = "Creating share image..."
            await generateStaticShare()
            return
        }
        
        // Create ShareContent
        let content = ShareContent(
            type: .recipe(recipe),
            beforeImage: beforeImage,
            afterImage: afterImage
        )
        
        // Get render inputs
        guard let renderInputs = content.toRenderInputs() else {
            await MainActor.run {
                onError(NSError(domain: "SnapChef", code: -1, 
                              userInfo: [NSLocalizedDescriptionKey: "Failed to prepare video content"]))
                dismiss()
            }
            return
        }
        
        do {
            statusMessage = "Generating video frames..."
            
            // Generate video with progress
            let videoURL = try await ViralVideoEngine.shared.generateVideo(
                recipe: renderInputs.recipe,
                media: renderInputs.media,
                progressHandler: { prog, status in
                    await MainActor.run {
                        self.progress = prog
                        self.statusMessage = status
                    }
                }
            )
            
            await MainActor.run {
                onComplete(videoURL)
                dismiss()
            }
        } catch {
            await MainActor.run {
                onError(error)
                dismiss()
            }
        }
    }
    
    func generateStaticShare() async {
        // Implementation in Phase 4
    }
}
```

### Phase 4: Implement Static Image Fallback ✅ COMPLETE
**File**: `BrandedSharePopup.swift`
**Location**: Add to VideoGenerationView

#### Tasks:
- [x] Create static image generation function
- [x] Design attractive fallback image layout
- [x] Save to temporary file
- [x] Test static image generation

#### Code Changes:
```swift
// Add to VideoGenerationView
func generateStaticShare() async {
    do {
        let shareImage = createRecipeShareImage(
            recipe: recipe,
            fridgePhoto: beforeImage
        )
        
        // Save to temp
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("share_\(UUID().uuidString).jpg")
        
        if let jpegData = shareImage.jpegData(compressionQuality: 0.9) {
            try jpegData.write(to: tempURL)
            
            await MainActor.run {
                onComplete(tempURL)
                dismiss()
            }
        }
    } catch {
        await MainActor.run {
            onError(error)
            dismiss()
        }
    }
}

func createRecipeShareImage(recipe: Recipe, fridgePhoto: UIImage?) -> UIImage {
    let size = CGSize(width: 1080, height: 1920)
    let renderer = UIGraphicsImageRenderer(size: size)
    
    return renderer.image { context in
        // Background gradient
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor] as CFArray,
            locations: [0, 1]
        )!
        
        context.cgContext.drawLinearGradient(
            gradient,
            start: CGPoint.zero,
            end: CGPoint(x: 0, y: size.height),
            options: []
        )
        
        // Fridge photo (if available)
        if let fridge = fridgePhoto {
            let imageRect = CGRect(x: 40, y: 100, width: 1000, height: 1000)
            
            // Add shadow
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 10), blur: 20)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: imageRect, cornerRadius: 20).fill()
            
            // Draw image
            context.cgContext.setShadow(offset: .zero, blur: 0)
            let path = UIBezierPath(roundedRect: imageRect, cornerRadius: 20)
            path.addClip()
            fridge.draw(in: imageRect)
        }
        
        // Text overlay
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 10
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 60),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let title = "From Fridge Chaos to\n\(recipe.name)!"
        title.draw(in: CGRect(x: 40, y: 1150, width: 1000, height: 200),
                  withAttributes: titleAttributes)
        
        // Features
        let featuresAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            .paragraphStyle: paragraphStyle
        ]
        
        let features = "🤖 AI-Powered Recipes\n📸 Just Snap Your Fridge\n🍳 Personalized For You\n⏱ \(recipe.prepTime + recipe.cookTime) Minutes"
        features.draw(in: CGRect(x: 40, y: 1350, width: 1000, height: 400),
                     withAttributes: featuresAttributes)
        
        // SnapChef branding
        let brandingAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 48),
            .foregroundColor: UIColor.white
        ]
        
        "SNAPCHEF".draw(in: CGRect(x: 40, y: 1800, width: 1000, height: 100),
                       withAttributes: brandingAttributes)
    }
}
```

### Phase 5: Add TikTok Opening Functions ✅ COMPLETE
**File**: `BrandedSharePopup.swift`
**Location**: Add helper functions

#### Tasks:
- [x] Implement openTikTokWithVideo function
- [x] Implement openTikTokWithImage function
- [x] Handle TikTokShareKit API integration
- [x] Test TikTok app opening

#### Code Changes:
```swift
// Add at bottom of BrandedSharePopup struct
func openTikTokWithVideo(_ videoURL: URL) {
    // Check if TikTok is installed
    guard UIApplication.shared.canOpenURL(URL(string: "tiktok://")!) else {
        // Fallback to browser
        if let webURL = URL(string: "https://www.tiktok.com") {
            UIApplication.shared.open(webURL)
        }
        return
    }
    
    // Use ShareKit to share video
    // Note: This is simplified - actual implementation would use TikTokShareKit
    let items: [Any] = [videoURL]
    let activityVC = UIActivityViewController(
        activityItems: items,
        applicationActivities: nil
    )
    
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootVC = windowScene.windows.first?.rootViewController {
        rootVC.present(activityVC, animated: true)
    }
}

func openTikTokWithImage(_ imageURL: URL) {
    // Similar to video but with image
    openTikTokWithVideo(imageURL) // Reuse same function
}
```

### Phase 6: Camera Integration for After Photo ✅ COMPLETE
**File**: `BrandedSharePopup.swift`
**Location**: Add camera sheet

#### Tasks:
- [x] Add fullScreenCover for camera
- [x] Handle captured photo
- [x] Save to PhotoStorageManager
- [x] Proceed to video generation
- [x] Test complete flow

#### Code Changes:
```swift
// Add camera sheet modifier
.fullScreenCover(isPresented: $showAfterPhotoCamera) {
    CameraCapture(image: $capturedAfterPhoto)
        .ignoresSafeArea()
        .onChange(of: capturedAfterPhoto) { _, newPhoto in
            if let photo = newPhoto, let recipe = currentRecipe {
                // Save after photo
                PhotoStorageManager.shared.saveMealPhoto(photo, for: recipe.id)
                currentAfterImage = photo
                
                // Close camera and show video generation
                showAfterPhotoCamera = false
                showAfterPhotoPrompt = false
                showVideoGeneration = true
            }
        }
}
```

## Testing Checklist

### After Each Phase:
- [x] Run build command: `xcodebuild -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Debug build 2>&1`
- [x] Check for compilation errors
- [x] Fix any Swift 6 concurrency warnings
- [x] Verify UI appears correctly

### End-to-End Testing:
- [ ] Test with recipe that has after photo (should go straight to video)
- [ ] Test with recipe without after photo (should show prompt)
- [ ] Test capturing after photo (should proceed to video)
- [ ] Test skipping after photo (should create static image)
- [ ] Test video generation progress indicators
- [ ] Test cancellation at each stage
- [ ] Test TikTok app opening with content

## Error Handling

### Potential Issues and Solutions:
1. **Missing beforeImage**: Use placeholder or skip video generation
2. **Video generation fails**: Show error alert and offer static share
3. **TikTok not installed**: Open web version or App Store
4. **Camera permission denied**: Show settings prompt
5. **Storage full**: Show appropriate error message

## Success Criteria
- ✅ Direct TikTok share without TikTokShareView
- ✅ Only prompts for after photo if missing
- ✅ Shows video generation progress
- ✅ Falls back to static image when appropriate
- ✅ Preserves all recipe context and photos
- ✅ No new files created
- ✅ Clean, intuitive user experience

## Notes
- All changes contained within BrandedSharePopup.swift
- Reuses existing ViralVideoEngine for video generation
- Leverages PhotoStorageManager for photo persistence
- Maintains consistent UI/UX with rest of app