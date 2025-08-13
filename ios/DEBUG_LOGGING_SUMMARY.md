# Debug Logging for TikTok Video Generation with Photos

## Purpose
Track photos from recipe cards through the entire video generation pipeline to verify CloudKit photos are being properly handed to the video generation process.

## Logging Added at Each Stage

### 1. Recipe Card Photo Retrieval
**File:** `/SnapChef/Features/Recipes/RecipesView.swift`
**Functions:** `getBeforePhotoForRecipe()` and `getAfterPhotoForRecipe()`

```
📸 RecipeCard: Found before photo for [Recipe Name]:
    - Size: (width, height)
    - Has CGImage: true/false
    - Photo object: <UIImage details>
⚠️ RecipeCard: No before photo found for [Recipe Name]
```

### 2. TikTok Share View Photo Preparation
**File:** `/SnapChef/Features/Sharing/Platforms/TikTok/TikTokShareViewEnhanced.swift`
**Function:** `startVideoGeneration()`

```
🎬 TikTok: Starting video generation with:
    - Before (fridge) photo: ✓ Available / ✗ Missing
      Size: (width, height), Has CGImage: true/false
      Photo object: <UIImage details>
    - After (meal) photo: ✓ Available / ✗ Missing
      Size: (width, height), Has CGImage: true/false
      Photo object: <UIImage details>
```

### 3. Viral Video Engine Asset Preparation
**File:** `/SnapChef/Features/Sharing/Platforms/TikTok/ViralVideoEngine.swift`
**Function:** `prepareAssets()`

```
📸 ViralVideoEngine: Preparing assets from MediaBundle:
    - beforeFridge: (width, height) - Has CGImage: true/false
    - afterFridge: (width, height) - Has CGImage: true/false
    - cookedMeal: (width, height) - Has CGImage: true/false
```

### 4. Viral Video Renderer Processing
**File:** `/SnapChef/Features/Sharing/Platforms/TikTok/ViralVideoRenderer.swift`
**Function:** `render()`

```
🎥 ViralVideoRenderer: Starting render with plan containing [X] items
  📸 Item 0 - Still image for [X]s:
      - Image size: (width, height)
      - Has CGImage: true/false
      - Has CIImage: true/false
  🎬 Item 1 - Video: filename.mp4
🎥 ViralVideoRenderer: Final video URL: overlay_video_[timestamp].mp4
📏 ViralVideoRenderer: Video file size: X.XX MB
```

### 5. Still Writer Image Processing
**File:** `/SnapChef/Features/Sharing/Platforms/TikTok/StillWriter.swift`
**Function:** `createVideoFromImage()`

```
📸 StillWriter: Processing image:
    - Original size: (width, height)
    - Has CGImage: true/false
    - Has CIImage: true/false
    - Image object: <UIImage details>
📸 StillWriter: After optimization:
    - Optimized size: (1080.0, 1920.0)
    - Target size: (1080.0, 1920.0)
📝 DEBUG StillWriter: CIImage extent: (0.0, 0.0, 1080.0, 1920.0)
```

## Expected Flow for CloudKit Photos

### Successful Flow:
1. **Recipe Card retrieves photo:**
   - `📸 RecipeCard: Found before photo for Pasta Carbonara`
   - Shows size and confirms `Has CGImage: true`

2. **TikTok view receives photo:**
   - `🎬 TikTok: Starting video generation with:`
   - `- Before (fridge) photo: ✓ Available`
   - Shows matching size and CGImage status

3. **MediaBundle created with photos:**
   - `📸 ViralVideoEngine: Preparing assets from MediaBundle:`
   - Shows all three images with proper sizes

4. **Renderer processes images:**
   - `🎥 ViralVideoRenderer: Starting render with plan containing 3 items`
   - Each item shows correct image size and CGImage availability

5. **StillWriter converts to video:**
   - `📸 StillWriter: Processing image:`
   - Shows optimization to 1080x1920
   - Confirms CIImage creation

6. **Final video created:**
   - `🎥 ViralVideoRenderer: Final video URL: overlay_video_XXX.mp4`
   - `📏 ViralVideoRenderer: Video file size: 5-20 MB`

### Problem Indicators:
- `⚠️ RecipeCard: No before photo found` - Photo not in savedRecipesWithPhotos
- `Has CGImage: false` - Image might be CI-backed, needs conversion
- Video size < 1MB - Likely rendering white/blank frames
- Missing log entries - Photo not being passed through pipeline

## How to Use This Debug Info

1. **Run the app and navigate to recipe cards**
2. **Tap share on a CloudKit recipe**
3. **Select TikTok video generation**
4. **Check Xcode console for the logging sequence**

### What to Look For:
- Verify photos are found at recipe card level
- Confirm sizes match throughout the pipeline
- Check CGImage availability (should be true)
- Verify final video size > 1MB

### Common Issues:
1. **No photos found:** CloudKit photos not fetched into savedRecipesWithPhotos
2. **CGImage false:** Photos need CGImage backing for rendering
3. **Size 0x0:** Invalid or corrupted image data
4. **Video < 1MB:** White/blank frames being rendered

## Build Status
✅ **BUILD SUCCEEDED** - All logging code compiles successfully