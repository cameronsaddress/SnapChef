import SwiftUI
import CloudKit

/// Manages profile photos with local storage first, CloudKit sync second
@MainActor
class ProfilePhotoManager: ObservableObject {
    static let shared = ProfilePhotoManager()
    
    @Published var currentUserPhoto: UIImage?
    @Published private(set) var cachedUserPhotos: [String: UIImage] = [:]
    
    private let documentsDirectory: URL
    private let profilePhotosDirectory: URL
    
    private init() {
        // Setup directories
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        profilePhotosDirectory = documentsDirectory.appendingPathComponent("ProfilePhotos")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: profilePhotosDirectory, withIntermediateDirectories: true)
        
        // Load current user's photo on init
        Task {
            await loadCurrentUserPhoto()
        }
    }
    
    // MARK: - Public Methods
    
    /// Save profile photo locally and queue CloudKit upload (overwrites existing)
    func saveProfilePhoto(_ image: UIImage, for userID: String? = nil) async {
        let currentUser = UnifiedAuthManager.shared.currentUser
        let targetUserID = userID ?? (currentUser?.recordID ?? "anonymous")
        
        // Delete old photo first to ensure overwrite
        deletePhotoLocally(for: targetUserID)
        
        // Save new photo locally (immediate)
        savePhotoLocally(image, for: targetUserID)
        
        // Update current user photo if it's for the current user
        if userID == nil || userID == currentUser?.recordID {
            currentUserPhoto = image
        }
        
        // Update cache in memory
        cachedUserPhotos[targetUserID] = image
        
        // Notify all observers that photo has changed
        objectWillChange.send()
        
        // Queue CloudKit upload (background) - will overwrite existing
        Task.detached(priority: .background) {
            await self.uploadPhotoToCloudKit(image, for: targetUserID, overwrite: true)
            
            // Invalidate cache to force refresh on all devices (UserCacheManager is in a different file)
            // This will be handled through the activity notification
            
            // Create activity to notify other devices
            await self.createProfileUpdateActivity(for: targetUserID)
        }
    }
    
    /// Get profile photo for a user (checks local first, then CloudKit)
    func getProfilePhoto(for userID: String) async -> UIImage? {
        // Check memory cache first
        if let cached = cachedUserPhotos[userID] {
            return cached
        }
        
        // Check local storage
        if let localPhoto = loadPhotoLocally(for: userID) {
            cachedUserPhotos[userID] = localPhoto
            return localPhoto
        }
        
        // If not found locally, try to fetch from CloudKit
        if let cloudPhoto = await fetchPhotoFromCloudKit(for: userID) {
            // Save locally for future use
            savePhotoLocally(cloudPhoto, for: userID)
            cachedUserPhotos[userID] = cloudPhoto
            return cloudPhoto
        }
        
        return nil
    }
    
    /// Load current user's photo
    func loadCurrentUserPhoto() async {
        guard let currentUser = UnifiedAuthManager.shared.currentUser else { return }
        currentUserPhoto = await getProfilePhoto(for: currentUser.recordID ?? "anonymous")
    }
    
    /// Delete profile photo
    func deleteProfilePhoto(for userID: String? = nil) async {
        let currentUser = UnifiedAuthManager.shared.currentUser
        let targetUserID = userID ?? (currentUser?.recordID ?? "anonymous")
        
        // Delete locally
        deletePhotoLocally(for: targetUserID)
        
        // Remove from cache
        cachedUserPhotos.removeValue(forKey: targetUserID)
        
        // Update current user photo if needed
        if userID == nil || userID == currentUser?.recordID {
            currentUserPhoto = nil
        }
        
        // Delete from CloudKit (only for authenticated users)
        if targetUserID != "anonymous" {
            Task.detached(priority: .background) {
                await self.deletePhotoFromCloudKit(for: targetUserID)
            }
        }
    }
    
    // MARK: - Local Storage
    
    private func photoURL(for userID: String) -> URL {
        return profilePhotosDirectory.appendingPathComponent("\(userID).jpg")
    }
    
    private func savePhotoLocally(_ image: UIImage, for userID: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let url = photoURL(for: userID)
        try? data.write(to: url)
        
        print("📸 ProfilePhotoManager: Saved photo locally for user \(userID)")
    }
    
    private func loadPhotoLocally(for userID: String) -> UIImage? {
        let url = photoURL(for: userID)
        
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        
        print("📸 ProfilePhotoManager: Loaded photo from local storage for user \(userID)")
        return image
    }
    
    private func deletePhotoLocally(for userID: String) {
        let url = photoURL(for: userID)
        try? FileManager.default.removeItem(at: url)
        
        print("📸 ProfilePhotoManager: Deleted local photo for user \(userID)")
    }
    
    // MARK: - CloudKit Sync
    
    private func createProfileUpdateActivity(for userID: String) async {
        // Create activity through UnifiedAuthManager to trigger cache refresh on other devices
        // Using the public method that's available
        if let currentUser = UnifiedAuthManager.shared.currentUser,
           currentUser.recordID == userID {
            // For current user, we can use the notifyProfilePhotoUpdate method
            await UnifiedAuthManager.shared.notifyProfilePhotoUpdate(for: userID)
        }
    }
    
    private func uploadPhotoToCloudKit(_ image: UIImage, for userID: String, overwrite: Bool = false) async {
        // Compress image to reasonable size (max 2MB for CloudKit)
        guard let imageData = compressImage(image, maxSizeMB: 2.0) else { return }
        
        // Create CKAsset from image data
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try imageData.write(to: tempURL)
            let asset = CKAsset(fileURL: tempURL)
            
            // Update user record with profile photo (overwrites existing)
            await UnifiedAuthManager.shared.updateProfilePhoto(asset, for: userID)
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            
            print("📸 ProfilePhotoManager: Uploaded photo to CloudKit for user \(userID) (overwrite: \(overwrite))")
            
            // Notify followers of photo update
            await notifyFollowersOfPhotoUpdate(userID)
        } catch {
            print("⚠️ ProfilePhotoManager: Failed to upload photo to CloudKit: \(error)")
        }
    }
    
    private func compressImage(_ image: UIImage, maxSizeMB: Double) -> Data? {
        let maxSizeBytes = maxSizeMB * 1024 * 1024
        var compressionQuality: CGFloat = 0.8
        var imageData = image.jpegData(compressionQuality: compressionQuality)
        
        // Reduce quality until under size limit
        while let data = imageData, Double(data.count) > maxSizeBytes && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = image.jpegData(compressionQuality: compressionQuality)
        }
        
        return imageData
    }
    
    private func notifyFollowersOfPhotoUpdate(_ userID: String) async {
        // Invalidate cached photos for this user across all followers
        // This will trigger re-fetch when they next view the profile
        print("📸 ProfilePhotoManager: Notifying followers of photo update for user \(userID)")
        
        // The actual notification happens through CloudKit subscriptions
        // Followers will see the update when they refresh their feeds
    }
    
    private func fetchPhotoFromCloudKit(for userID: String) async -> UIImage? {
        // This will be implemented in UnifiedAuthManager
        return await UnifiedAuthManager.shared.fetchProfilePhoto(for: userID)
    }
    
    private func deletePhotoFromCloudKit(for userID: String) async {
        await UnifiedAuthManager.shared.deleteProfilePhoto(for: userID)
    }
    
    // MARK: - Migration
    
    /// Migrate existing photos from CloudKit to local storage
    func migrateExistingPhotos() async {
        guard let currentUser = UnifiedAuthManager.shared.currentUser,
              let userID = currentUser.recordID else { return }
        
        // Check if we already have a local photo
        if loadPhotoLocally(for: userID) != nil {
            print("📸 ProfilePhotoManager: Local photo already exists, skipping migration")
            return
        }
        
        // Try to fetch from CloudKit
        if let cloudPhoto = await fetchPhotoFromCloudKit(for: userID) {
            savePhotoLocally(cloudPhoto, for: userID)
            cachedUserPhotos[userID] = cloudPhoto
            currentUserPhoto = cloudPhoto
            print("📸 ProfilePhotoManager: Migrated photo from CloudKit to local storage")
        }
    }
}
