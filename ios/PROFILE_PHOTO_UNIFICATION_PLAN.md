# Profile Photo System Unification Plan (NO NEW FILES)

## Overview
Unify the profile photo experience across the app by making UsernameSetupView (initial CloudKit setup) use the EXACT SAME photo picker implementation from ProfileView's EnhancedProfileHeader, with proper local-first storage and CloudKit sync.

## Current State Analysis

### Problems Identified:
1. **Inconsistent UI**: UsernameSetupView has a different design than ProfileView
2. **Different photo management**: UsernameSetupView doesn't use ProfilePhotoManager
3. **No camera option**: Only photo library selection available
4. **Sync issues**: Photos may not properly update across all followers
5. **No overwrite logic**: Old photos aren't properly replaced

### Existing Components to Reuse:
- `ProfilePhotoManager.swift` - Handles photo storage and CloudKit sync
- `ProfileView.swift` - Contains EnhancedProfileHeader with perfect photo implementation
- `UsernameSetupView.swift` - Needs to reuse ProfileView's photo code

## Implementation Plan (Using Existing Views Only)

### Phase 1: Extract Photo Picker Logic from ProfileView

#### 1.1 Identify Reusable Code in EnhancedProfileHeader
The ProfileView already has the perfect implementation in EnhancedProfileHeader:
```swift
// Lines 371-397 in ProfileView.swift
private var profileButton: some View {
    Button(action: {
        if authManager.isAuthenticated {
            showingImagePicker = true  // This triggers photo picker
        }
    }) {
        ZStack {
            profileButtonContent  // Glassmorphic 120x120 circle
            // Camera icon overlay
        }
    }
}
```

#### 1.2 Make EnhancedProfileHeader's Photo Section Reusable
Instead of creating a new file, we'll:
1. Add a `@ViewBuilder` function in ProfileView that can be called from UsernameSetupView
2. Or better: Make UsernameSetupView directly use parts of EnhancedProfileHeader

### Phase 2: Modify UsernameSetupView to Use ProfileView's Implementation

#### 2.1 Copy the Exact Photo Button from ProfileView
Replace lines 90-144 in UsernameSetupView with the exact implementation from ProfileView:
- Use the same 120x120 size (not 150x150)
- Use the same glassmorphic design
- Use the same camera overlay style
- Use PhotosPicker (already in ProfileView)

#### 2.2 Add Camera/Library Action Sheet
Add this functionality to BOTH views:
```swift
@State private var showingPhotoOptions = false
@State private var photoSourceType: UIImagePickerController.SourceType = .photoLibrary

// When photo button tapped:
.confirmationDialog("Choose Photo", isPresented: $showingPhotoOptions) {
    Button("Take Photo") {
        photoSourceType = .camera
        showingImagePicker = true
    }
    Button("Choose from Library") {
        photoSourceType = .photoLibrary
        showingImagePicker = true
    }
    if profilePhotoManager.currentUserPhoto != nil {
        Button("Remove Photo", role: .destructive) {
            await profilePhotoManager.deleteProfilePhoto()
        }
    }
}

```

### Phase 3: Update UsernameSetupView Implementation

#### 3.1 Add ProfilePhotoManager Integration
```swift
// Add to UsernameSetupView
@StateObject private var profilePhotoManager = ProfilePhotoManager.shared
@State private var showingPhotoOptions = false
@State private var photoSourceType: UIImagePickerController.SourceType = .photoLibrary
```

#### 3.2 Replace Photo Section (lines 90-144)
Replace the entire photo section with ProfileView's implementation:
```swift
// Photo picker section - EXACT copy from ProfileView
VStack(spacing: 20) {
    Button(action: { 
        showingPhotoOptions = true  // Show action sheet
    }) {
        ZStack {
            // Glassmorphic card (from ProfileView)
            GlassmorphicCard(content: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#667eea"),
                                Color(hex: "#764ba2")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(profileImageOverlay)
            }, cornerRadius: 60)
            .frame(width: 120, height: 120)
            
            // Camera icon overlay
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 35, height: 35)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                )
                .offset(x: 40, y: 40)
        }
    }
    .buttonStyle(PlainButtonStyle())
}
```

### Phase 4: Enhance ProfilePhotoManager (Existing File)

#### 3.1 Add Photo Overwrite Logic
```swift
func saveProfilePhoto(_ image: UIImage, for userID: String? = nil) async {
    // 1. Delete old photo from local storage
    deletePhotoLocally(for: targetUserID)
    
    // 2. Save new photo locally
    savePhotoLocally(image, for: targetUserID)
    
    // 3. Update memory cache
    cachedUserPhotos[targetUserID] = image
    
    // 4. Upload to CloudKit (replaces existing)
    await uploadPhotoToCloudKit(image, for: targetUserID)
    
    // 5. Notify all views to refresh
    objectWillChange.send()
}
```

#### 4.2 Add Camera Support Using Existing iOS Components
```swift
// Add to both UsernameSetupView and ProfileView
// Use native UIImagePickerController wrapped in UIViewControllerRepresentable

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true  // Allow cropping to square
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, 
                                  didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Then in the view, use it based on source type:
.sheet(isPresented: $showingImagePicker) {
    ImagePicker(image: $selectedImage, sourceType: photoSourceType)
        .onDisappear {
            if let image = selectedImage {
                Task {
                    await profilePhotoManager.saveProfilePhoto(image)
                }
            }
        }
}
```

### Phase 5: CloudKit Sync Improvements (Update Existing Methods)

#### 4.1 Update CloudKit Upload Method
```swift
private func uploadPhotoToCloudKit(_ image: UIImage, for userID: String) async {
    // 1. Compress image to reasonable size
    let compressedImage = compressImage(image, maxSizeMB: 2.0)
    
    // 2. Create/Update user record with new photo
    let record = try await fetchOrCreateUserRecord(userID)
    
    // 3. Delete old asset if exists
    if let oldAsset = record["profilePictureAsset"] as? CKAsset {
        // Mark for deletion
    }
    
    // 4. Create new asset
    let asset = CKAsset(image: compressedImage)
    record["profilePictureAsset"] = asset
    record["profilePictureUpdatedAt"] = Date()
    
    // 5. Save to CloudKit
    try await cloudKitActor.saveRecord(record)
    
    // 6. Broadcast update to followers
    await notifyFollowersOfPhotoUpdate(userID)
}
```

#### 4.2 Add Photo Update Notifications
```swift
func notifyFollowersOfPhotoUpdate(_ userID: String) async {
    // Create activity record for photo update
    let activity = createPhotoUpdateActivity(userID)
    
    // This triggers refresh in followers' feeds
    try await cloudKitActor.saveRecord(activity)
}
```

### Phase 6: Update All Existing Views Using Profile Photos

#### 5.1 Views to Update:
1. **UserAvatarView** - Already reactive with @ObservedObject
2. **ActivityFeedView** - Needs to refresh on photo updates
3. **DiscoverUsersView** - Should show latest photos
4. **SocialFeedView** - Must reflect photo changes
5. **UserProfileView** - Should update immediately

#### 5.2 Make Views Reactive
```swift
// All views should observe ProfilePhotoManager
@ObservedObject var photoManager = ProfilePhotoManager.shared

// Use computed property for photo
var userPhoto: UIImage? {
    photoManager.cachedUserPhotos[userID] ?? defaultPhoto
}
```

### Phase 7: Local Storage Structure (No New Files)

#### 6.1 File Organization
```
Documents/
├── ProfilePhotos/
│   ├── current_user.jpg      (current user's photo)
│   ├── user_abc123.jpg       (cached follower photos)
│   └── user_def456.jpg
```

#### 6.2 Cleanup Strategy
- Keep current user photo always
- Cache up to 50 follower photos
- LRU eviction for old follower photos
- Never delete during active session

### Phase 8: Testing Plan

#### 7.1 Test Scenarios:
1. **New User Flow**:
   - Sign up → UsernameSetupView → Add photo → Verify saved
   
2. **Photo Update Flow**:
   - ProfileView → Change photo → Verify old deleted → New saved
   
3. **Camera Flow**:
   - Select camera → Take photo → Verify saved and synced
   
4. **Follower Update**:
   - User A changes photo → User B (follower) sees update

#### 7.2 Edge Cases:
- No camera available (simulator)
- Large photo files (>10MB)
- No network (offline mode)
- Rapid photo changes
- Multiple devices same account

## Implementation Order (NO NEW FILES)

1. **Step 1**: Add camera/library action sheet to ProfileView's EnhancedProfileHeader
2. **Step 2**: Update ProfilePhotoManager with proper overwrite logic
3. **Step 3**: Copy ProfileView's photo implementation to UsernameSetupView
4. **Step 4**: Add the same action sheet to UsernameSetupView
5. **Step 5**: Enhance CloudKit sync to notify followers
6. **Step 6**: Verify all views update when photo changes
7. **Step 7**: Test complete flow

## Success Criteria

✅ UsernameSetupView looks identical to ProfileView photo section
✅ Both camera and library options work
✅ Photos save locally first (instant update)
✅ CloudKit sync happens in background
✅ Old photos are properly overwritten
✅ All followers see updated photos
✅ Works offline with sync on reconnect
✅ Consistent 120x120 photo size everywhere
✅ Glassmorphic design throughout

## Code Changes Required

### Files to Modify (NO NEW FILES):
1. `UsernameSetupView.swift` - Copy photo implementation from ProfileView
2. `ProfilePhotoManager.swift` - Add overwrite and camera support
3. `ProfileView.swift` - Add camera/library action sheet
4. `UserAvatarView.swift` - Already reactive, verify it works
5. `ActivityFeedView.swift` - Ensure photo refresh on updates

### Implementation Strategy:
1. **Copy exact code** from ProfileView's EnhancedProfileHeader
2. **Add action sheet** for camera/library selection to both views
3. **Use existing** ProfilePhotoManager for all operations
4. **No new components** - reuse what's already working

## Potential Issues & Solutions

### Issue 1: Large Photo Files
**Solution**: Compress images before saving (max 2MB for CloudKit)

### Issue 2: Sync Delays
**Solution**: Show local photo immediately, sync in background

### Issue 3: Cache Invalidation
**Solution**: Use timestamp-based cache with version tracking

### Issue 4: Memory Usage
**Solution**: Limit in-memory cache to 50 photos, use disk for rest

## Migration Strategy

1. Deploy ProfilePhotoManager updates first
2. Update views one at a time
3. Test with small user group
4. Monitor CloudKit usage
5. Full rollout

## Monitoring & Analytics

Track:
- Photo upload success rate
- Average photo size
- Sync latency
- Cache hit rate
- User engagement with photos

## Future Enhancements

- Photo filters/editing
- Multiple profile photos (gallery)
- Photo history/rollback
- Animated photo transitions
- AI-powered photo suggestions