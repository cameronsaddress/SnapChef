import SwiftUI
import CloudKit

/// Manages profile photos with local storage first, CloudKit sync second
@MainActor
class ProfilePhotoManager: ObservableObject {
    static let shared = ProfilePhotoManager()
    
    @Published var currentUserPhoto: UIImage?
    private var cachedUserPhotos: [String: UIImage] = [:]
    
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
    
    /// Save profile photo locally and queue CloudKit upload
    func saveProfilePhoto(_ image: UIImage, for userID: String? = nil) async {
        let currentUser = await UnifiedAuthManager.shared.currentUser
        let targetUserID = userID ?? (currentUser?.recordID ?? "anonymous")
        
        // Save locally first (immediate)
        savePhotoLocally(image, for: targetUserID)
        
        // Update current user photo if it's for the current user
        if userID == nil || userID == currentUser?.recordID {
            currentUserPhoto = image
        }
        
        // Cache in memory
        cachedUserPhotos[targetUserID] = image
        
        // Queue CloudKit upload (background)
        Task.detached(priority: .background) {
            await self.uploadPhotoToCloudKit(image, for: targetUserID)
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
        guard let currentUser = await UnifiedAuthManager.shared.currentUser else { return }
        currentUserPhoto = await getProfilePhoto(for: currentUser.recordID ?? "anonymous")
    }
    
    /// Delete profile photo
    func deleteProfilePhoto(for userID: String? = nil) async {
        let currentUser = await UnifiedAuthManager.shared.currentUser
        let targetUserID = userID ?? (currentUser?.recordID ?? "anonymous")
        
        // Delete locally
        deletePhotoLocally(for: targetUserID)
        
        // Remove from cache
        cachedUserPhotos.removeValue(forKey: targetUserID)
        
        // Update current user photo if needed
        if userID == nil || userID == currentUser?.recordID {
            currentUserPhoto = nil
        }
        
        // Delete from CloudKit
        Task.detached(priority: .background) {
            await self.deletePhotoFromCloudKit(for: targetUserID)
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
    
    private func uploadPhotoToCloudKit(_ image: UIImage, for userID: String) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        // Create CKAsset from image data
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try imageData.write(to: tempURL)
            let asset = CKAsset(fileURL: tempURL)
            
            // Update user record with profile photo
            await UnifiedAuthManager.shared.updateProfilePhoto(asset, for: userID)
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            
            print("📸 ProfilePhotoManager: Uploaded photo to CloudKit for user \(userID)")
        } catch {
            print("⚠️ ProfilePhotoManager: Failed to upload photo to CloudKit: \(error)")
        }
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
        guard let currentUser = await UnifiedAuthManager.shared.currentUser,
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