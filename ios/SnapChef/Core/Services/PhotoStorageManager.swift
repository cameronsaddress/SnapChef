//
//  PhotoStorageManager.swift
//  SnapChef
//
//  Manages local storage of recipe photos for video generation
//

import UIKit
import Foundation
import os.log

/// Manages local storage of recipe photos with efficient loading and memory optimization
@MainActor
public final class PhotoStorageManager: ObservableObject {
    static let shared = PhotoStorageManager()

    // Local storage for recipe photos with thread-safe access
    @Published private(set) var recipePhotos: [UUID: RecipePhotos] = [:]

    // Logging for storage operations
    private let logger = Logger(subsystem: "com.snapchef.photostorage", category: "PhotoStorageManager")

    // Background queue for cleanup operations
    private let cleanupQueue = DispatchQueue(label: "com.snapchef.photocleanup", qos: .utility)

    // Memory management properties
    private var lastCleanupTime = Date()
    private let cleanupInterval: TimeInterval = 300 // 5 minutes
    private let maxStoredPhotos = 10000 // Soft limit for monitoring (no longer enforced)

    // Photo storage structure
    public struct RecipePhotos {
        public let recipeId: UUID
        public let fridgePhoto: UIImage?      // Initial fridge photo
        public let pantryPhoto: UIImage?      // Pantry photo (optional)
        public let mealPhoto: UIImage?        // Final meal photo
        public let capturedAt: Date

        public init(recipeId: UUID, fridgePhoto: UIImage?, pantryPhoto: UIImage? = nil, mealPhoto: UIImage?) {
            self.recipeId = recipeId
            self.fridgePhoto = fridgePhoto
            self.pantryPhoto = pantryPhoto
            self.mealPhoto = mealPhoto
            self.capturedAt = Date()
        }
    }

    private init() {
        logger.info("📸 PhotoStorageManager initialized")
        
        // Load persisted photos from disk on initialization
        loadPersistedPhotos()

        // Start periodic cleanup timer
        startPeriodicCleanup()
    }
    
    // MARK: - Disk Persistence
    
    /// Get the documents directory for photo storage
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Get the photos storage directory
    private var photosDirectory: URL {
        documentsDirectory.appendingPathComponent("RecipePhotos")
    }
    
    /// Ensure photos directory exists
    private func ensurePhotosDirectoryExists() {
        if !FileManager.default.fileExists(atPath: photosDirectory.path) {
            try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Get file URL for a specific photo
    private func photoFileURL(recipeId: UUID, photoType: String) -> URL {
        photosDirectory.appendingPathComponent("\(recipeId.uuidString)_\(photoType).jpg")
    }
    
    /// Load all persisted photos from disk
    private func loadPersistedPhotos() {
        ensurePhotosDirectoryExists()
        
        logger.info("📸 Loading persisted photos from disk at: \(self.photosDirectory.path)")
        var loadedCount = 0
        
        // Get all files in photos directory
        do {
            let files = try FileManager.default.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: nil)
            logger.info("📸 Found \(files.count) files in photos directory")
            
            var recipePhotoGroups: [UUID: (fridge: UIImage?, pantry: UIImage?, meal: UIImage?)] = [:]
            
            for fileURL in files {
                let filename = fileURL.lastPathComponent
                logger.info("📸 Processing file: \(filename)")
                
                // Parse filename: recipeId_photoType.jpg
                let components = filename.replacingOccurrences(of: ".jpg", with: "").split(separator: "_")
                if components.count >= 2 {
                    if let recipeId = UUID(uuidString: String(components[0])) {
                        if let imageData = try? Data(contentsOf: fileURL),
                           let image = UIImage(data: imageData) {
                            
                            let photoType = String(components[1])
                            
                            if recipePhotoGroups[recipeId] == nil {
                                recipePhotoGroups[recipeId] = (nil, nil, nil)
                            }
                            
                            switch photoType {
                            case "fridge":
                                recipePhotoGroups[recipeId]?.fridge = image
                            case "pantry":
                                recipePhotoGroups[recipeId]?.pantry = image
                            case "meal":
                                recipePhotoGroups[recipeId]?.meal = image
                            default:
                                logger.warning("📸 Unknown photo type: \(photoType)")
                            }
                            loadedCount += 1
                            logger.info("📸 Loaded \(photoType) photo for recipe \(recipeId)")
                        } else {
                            logger.warning("📸 Failed to load image data from: \(filename)")
                        }
                    } else {
                        logger.warning("📸 Invalid UUID in filename: \(String(components[0]))")
                    }
                } else {
                    logger.warning("📸 Invalid filename format: \(filename)")
                }
            }
            
            // Create RecipePhotos objects from grouped photos
            for (recipeId, photos) in recipePhotoGroups {
                recipePhotos[recipeId] = RecipePhotos(
                    recipeId: recipeId,
                    fridgePhoto: photos.fridge,
                    pantryPhoto: photos.pantry,
                    mealPhoto: photos.meal
                )
            }
        } catch {
            logger.error("📸 Failed to read photos directory: \(error)")
        }
        
        logger.info("📸 Loaded \(loadedCount) photos for \(self.recipePhotos.count) recipes from disk")
    }
    
    /// Save photo to disk
    private func savePhotoToDisk(_ photo: UIImage, recipeId: UUID, photoType: String) {
        ensurePhotosDirectoryExists()
        
        let fileURL = photoFileURL(recipeId: recipeId, photoType: photoType)
        
        // Compress and save as JPEG
        if let data = photo.jpegData(compressionQuality: 0.8) {
            do {
                try data.write(to: fileURL)
                logger.info("📸 Saved \(photoType) photo for recipe \(recipeId) to disk at: \(fileURL.path)")
                
                // Verify file was saved
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    logger.info("📸 Verified: Photo file exists at \(fileURL.lastPathComponent)")
                }
            } catch {
                logger.error("📸 Failed to save photo to disk: \(error)")
            }
        } else {
            logger.error("📸 Failed to compress photo for saving")
        }
    }
    
    /// Delete photo from disk
    private func deletePhotoFromDisk(recipeId: UUID, photoType: String) {
        let fileURL = photoFileURL(recipeId: recipeId, photoType: photoType)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// Clear all cached photos (for account deletion)
    public func clearCache() {
        recipePhotos.removeAll()
        
        // Clear disk cache
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let photosPath = documentsPath.appendingPathComponent("RecipePhotos")
            try? FileManager.default.removeItem(at: photosPath)
        }
        
        logger.info("📸 PhotoStorageManager: All cache cleared")
    }

    /// Store fridge photo for multiple recipes (called after recipe generation)
    public func storeFridgePhoto(_ photo: UIImage, for recipeIds: [UUID]) {
        logger.info("📸 Storing fridge photo for \(recipeIds.count) recipes")
        
        // Don't compress - use original for better quality and ensure save works
        for recipeId in recipeIds {
            let existing = recipePhotos[recipeId]
            recipePhotos[recipeId] = RecipePhotos(
                recipeId: recipeId,
                fridgePhoto: photo,
                pantryPhoto: existing?.pantryPhoto,
                mealPhoto: existing?.mealPhoto
            )
            
            // Save to disk for persistence
            savePhotoToDisk(photo, recipeId: recipeId, photoType: "fridge")
        }

        logger.info("📸 Total stored photos: \(self.recipePhotos.count)")
    }

    /// Store meal photo for a specific recipe (called after cooking)
    public func storeMealPhoto(_ photo: UIImage, for recipeId: UUID) {
        logger.info("📸 Storing meal photo for recipe \(recipeId)")

        let existing = recipePhotos[recipeId]
        recipePhotos[recipeId] = RecipePhotos(
            recipeId: recipeId,
            fridgePhoto: existing?.fridgePhoto,
            pantryPhoto: existing?.pantryPhoto,
            mealPhoto: photo
        )
        
        // Save to disk for persistence
        savePhotoToDisk(photo, recipeId: recipeId, photoType: "meal")
    }

    /// Store pantry photo for multiple recipes
    public func storePantryPhoto(_ photo: UIImage, for recipeIds: [UUID]) {
        logger.info("📸 Storing pantry photo for \(recipeIds.count) recipes")

        for recipeId in recipeIds {
            let existing = recipePhotos[recipeId]
            recipePhotos[recipeId] = RecipePhotos(
                recipeId: recipeId,
                fridgePhoto: existing?.fridgePhoto,
                pantryPhoto: photo,
                mealPhoto: existing?.mealPhoto
            )
            
            // Save to disk for persistence
            savePhotoToDisk(photo, recipeId: recipeId, photoType: "pantry")
        }

        logger.info("📸 Total stored photos: \(self.recipePhotos.count)")
    }

    /// Store all photos for a recipe (called when syncing from CloudKit)
    public func storePhotos(fridgePhoto: UIImage?, pantryPhoto: UIImage? = nil, mealPhoto: UIImage?, for recipeId: UUID) {
        // Check if we already have these photos
        let existing = recipePhotos[recipeId]
        
        // If we already have photos and no new ones provided, skip
        if existing != nil && fridgePhoto == nil && mealPhoto == nil && pantryPhoto == nil {
            logger.info("📸 Skipping store - already have photos for recipe \(recipeId)")
            return
        }
        
        logger.info("📸 Storing CloudKit photos for recipe \(recipeId)")

        // Preserve existing photo if new one is nil
        let finalFridge = fridgePhoto ?? existing?.fridgePhoto
        let finalPantry = pantryPhoto ?? existing?.pantryPhoto
        let finalMeal = mealPhoto ?? existing?.mealPhoto
        
        // Always save new photos to disk
        if let photo = fridgePhoto {
            savePhotoToDisk(photo, recipeId: recipeId, photoType: "fridge")
        } else if let photo = finalFridge, existing?.fridgePhoto == nil {
            // Save existing photo if it wasn't saved before
            savePhotoToDisk(photo, recipeId: recipeId, photoType: "fridge")
        }
        
        if let photo = pantryPhoto {
            savePhotoToDisk(photo, recipeId: recipeId, photoType: "pantry")
        } else if let photo = finalPantry, existing?.pantryPhoto == nil {
            savePhotoToDisk(photo, recipeId: recipeId, photoType: "pantry")
        }
        
        if let photo = mealPhoto {
            savePhotoToDisk(photo, recipeId: recipeId, photoType: "meal")
        } else if let photo = finalMeal, existing?.mealPhoto == nil {
            savePhotoToDisk(photo, recipeId: recipeId, photoType: "meal")
        }
        
        // Update in-memory cache
        recipePhotos[recipeId] = RecipePhotos(
            recipeId: recipeId,
            fridgePhoto: finalFridge,
            pantryPhoto: finalPantry,
            mealPhoto: finalMeal
        )

        logger.info("📸 Stored photos for recipe \(recipeId). Total recipes with photos: \(self.recipePhotos.count)")
    }

    /// Get photos for a recipe
    public func getPhotos(for recipeId: UUID) -> RecipePhotos? {
        return recipePhotos[recipeId]
    }

    /// Check if we have both photos for a recipe
    public func hasCompletePhotos(for recipeId: UUID) -> Bool {
        guard let photos = recipePhotos[recipeId] else { return false }
        return photos.fridgePhoto != nil && photos.mealPhoto != nil
    }

    /// Check if we have any photos for a recipe (for sync optimization)
    public func hasAnyPhotos(for recipeId: UUID) -> Bool {
        guard let photos = recipePhotos[recipeId] else { return false }
        return photos.fridgePhoto != nil || photos.mealPhoto != nil || photos.pantryPhoto != nil
    }

    /// Get all recipe IDs that have photos stored locally
    public func getRecipeIDsWithPhotos() -> Set<UUID> {
        return Set(recipePhotos.keys)
    }

    // MARK: - New Optimization Methods

    /// Get all stored recipe IDs efficiently for bulk operations
    public func getAllStoredRecipeIDs() -> Set<String> {
        logger.info("📸 Getting all stored recipe IDs - count: \(self.recipePhotos.count)")
        let idStrings = Set(recipePhotos.keys.map { $0.uuidString })
        return idStrings
    }

    /// Bulk check for photo existence across multiple recipes
    /// Returns dictionary with recipe ID as key and boolean indicating photo existence
    public func hasPhotosForRecipes(recipeIDs: [String]) -> [String: Bool] {
        logger.info("📸 Bulk checking photo existence for \(recipeIDs.count) recipes")

        var results: [String: Bool] = [:]

        for recipeIDString in recipeIDs {
            guard let uuid = UUID(uuidString: recipeIDString) else {
                logger.warning("📸 Invalid UUID string: \(recipeIDString)")
                results[recipeIDString] = false
                continue
            }

            results[recipeIDString] = hasAnyPhotos(for: uuid)
        }

        let foundCount = results.values.filter { $0 }.count
        logger.info("📸 Bulk check complete: \(foundCount)/\(recipeIDs.count) recipes have photos")

        return results
    }

    /// Get memory usage information for monitoring
    public func getMemoryUsageInfo() -> (photoCount: Int, estimatedMemoryMB: Double) {
        let photoCount = recipePhotos.count

        // Estimate memory usage (rough calculation)
        var totalBytes: Double = 0
        for photos in recipePhotos.values {
            if let fridge = photos.fridgePhoto {
                totalBytes += Double(fridge.pngData()?.count ?? 0)
            }
            if let pantry = photos.pantryPhoto {
                totalBytes += Double(pantry.pngData()?.count ?? 0)
            }
            if let meal = photos.mealPhoto {
                totalBytes += Double(meal.pngData()?.count ?? 0)
            }
        }

        let memoryMB = totalBytes / (1_024 * 1_024)
        logger.info("📸 Memory usage: \(photoCount) photos, ~\(String(format: "%.1f", memoryMB)) MB")

        return (photoCount: photoCount, estimatedMemoryMB: memoryMB)
    }

    /// Remove photos for specific recipe IDs to free memory
    public func removePhotos(for recipeIDs: [UUID]) {
        logger.info("📸 Removing photos for \(recipeIDs.count) recipes")

        var removedCount = 0
        for recipeID in recipeIDs {
            if recipePhotos.removeValue(forKey: recipeID) != nil {
                // Also remove from disk
                deletePhotoFromDisk(recipeId: recipeID, photoType: "fridge")
                deletePhotoFromDisk(recipeId: recipeID, photoType: "pantry")
                deletePhotoFromDisk(recipeId: recipeID, photoType: "meal")
                removedCount += 1
            }
        }

        logger.info("📸 Removed \(removedCount) photo sets")
    }

    /// Get photos older than specified time interval
    private func getOldPhotos(olderThan interval: TimeInterval) -> [UUID] {
        let cutoffDate = Date().addingTimeInterval(-interval)

        return recipePhotos.compactMap { recipeID, photos in
            return photos.capturedAt < cutoffDate ? recipeID : nil
        }
    }

    /// Start periodic cleanup of old/unused photos
    private func startPeriodicCleanup() {
        // DISABLED: No automatic cleanup timer - photos stay forever
        // Photos only deleted when user explicitly deletes recipe
        // Was: Timer.scheduledTimer(withTimeInterval: cleanupInterval...)
    }

    /// Perform cleanup if memory usage is high or too much time has passed
    private func performCleanupIfNeeded() {
        let timeSinceLastCleanup = Date().timeIntervalSince(lastCleanupTime)
        let memoryInfo = getMemoryUsageInfo()

        let shouldCleanupByTime = timeSinceLastCleanup > cleanupInterval
        let shouldCleanupByMemory = memoryInfo.photoCount > maxStoredPhotos || memoryInfo.estimatedMemoryMB > 100

        if shouldCleanupByTime || shouldCleanupByMemory {
            logger.info("📸 Starting cleanup - Time: \(shouldCleanupByTime), Memory: \(shouldCleanupByMemory)")
            performBackgroundCleanup()
            lastCleanupTime = Date()
        }
    }

    /// Background cleanup - now only logs memory usage, doesn't delete photos
    public func performBackgroundCleanup() {
        cleanupQueue.async { [weak self] in
            guard let self = self else { return }

            Task { @MainActor in
                self.logger.info("📸 Checking photo storage status")

                let memoryInfo = self.getMemoryUsageInfo()
                self.logger.info("📸 Current storage: \(memoryInfo.photoCount) photos, \(String(format: "%.1f", memoryInfo.estimatedMemoryMB)) MB")
                
                // No longer removing photos - we want to keep all recipes and photos
                // Only log if we're over the soft limit for monitoring purposes
                if self.recipePhotos.count > self.maxStoredPhotos {
                    self.logger.info("📸 Note: Storage has \(self.recipePhotos.count) photos (soft limit: \(self.maxStoredPhotos))")
                }
            }
        }
    }

    /// Preload photos for specific recipe IDs (optimization for known upcoming usage)
    public func preloadPhotos(for recipeIDs: [UUID]) {
        logger.info("📸 Preloading photos for \(recipeIDs.count) recipes")

        // This method ensures photos are in memory and ready for quick access
        // Currently, photos are loaded on-demand, but this can be extended
        // to implement more sophisticated caching strategies

        var foundCount = 0
        for recipeID in recipeIDs where recipePhotos[recipeID] != nil {
            foundCount += 1
        }

        logger.info("📸 Preload check - \(foundCount)/\(recipeIDs.count) photos already in memory")
    }

    /// Create placeholder image if needed (for testing)
    public static func createPlaceholderImage(text: String, color: UIColor = .black) -> UIImage {
        let size = CGSize(width: 1_080, height: 1_920)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Background
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 120, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            text.draw(in: textRect, withAttributes: attributes)

            // Add border to indicate it's a placeholder
            let borderPath = UIBezierPath(rect: CGRect(origin: .zero, size: size))
            UIColor.red.setStroke()
            borderPath.lineWidth = 20
            borderPath.stroke()
        }
    }
    
    // MARK: - Photo Compression
    
    /// Compress photo to target size in KB
    private func compressPhoto(_ image: UIImage, maxSizeKB: Int) -> UIImage {
        let maxBytes = maxSizeKB * 1024
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)
        
        // Binary search for optimal compression
        var minCompression: CGFloat = 0.0
        var maxCompression: CGFloat = 1.0
        
        while let data = imageData, data.count > maxBytes && compression > 0.1 {
            compression = (minCompression + maxCompression) / 2
            
            if data.count > maxBytes {
                maxCompression = compression
            } else {
                minCompression = compression
            }
            
            imageData = image.jpegData(compressionQuality: compression)
            
            // Break if we're close enough
            if maxCompression - minCompression < 0.05 {
                break
            }
        }
        
        // If still too large, resize the image
        if let data = imageData, data.count > maxBytes {
            let scale = CGFloat(maxBytes) / CGFloat(data.count)
            let newSize = CGSize(
                width: image.size.width * sqrt(scale),
                height: image.size.height * sqrt(scale)
            )
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return resizedImage ?? image
        }
        
        // Return compressed image
        if let data = imageData, let compressedImage = UIImage(data: data) {
            logger.info("📸 Compressed photo from \(image.jpegData(compressionQuality: 1.0)?.count ?? 0) to \(data.count) bytes")
            return compressedImage
        }
        
        return image
    }
    
    // MARK: - Migration Methods
    
    /// Get count of photos not associated with a user (anonymous photos)
    public func getAnonymousPhotoCount() -> Int {
        // For now, return total count as we don't track ownership in PhotoStorageManager
        // In production, you'd track which photos belong to which user
        return recipePhotos.count
    }
    
    /// Migrate all photos to a specific user ID
    public func migratePhotosToUser(userID: String) {
        logger.info("📸 Migrating \(self.recipePhotos.count) photo sets to user: \(userID)")
        
        // In a production app, you would:
        // 1. Update photo metadata with user ownership
        // 2. Queue photos for CloudKit upload
        // 3. Track sync status
        
        // For now, just log the migration
        logger.info("📸 Photo migration completed for user: \(userID)")
    }
    
    /// Store photos with enhanced metadata
    public func storePhotos(fridgePhoto: UIImage?, mealPhoto: UIImage?, for recipeId: UUID) {
        logger.info("📸 Storing photos for recipe \(recipeId)")
        
        // Check if we already have these photos
        let existing = recipePhotos[recipeId]
        
        // Save to disk for persistence
        if let photo = fridgePhoto {
            savePhotoToDisk(photo, recipeId: recipeId, photoType: "fridge")
        }
        
        if let photo = mealPhoto {
            savePhotoToDisk(photo, recipeId: recipeId, photoType: "meal")
        }
        
        // Update in-memory cache
        recipePhotos[recipeId] = RecipePhotos(
            recipeId: recipeId,
            fridgePhoto: fridgePhoto ?? existing?.fridgePhoto,
            pantryPhoto: existing?.pantryPhoto,
            mealPhoto: mealPhoto ?? existing?.mealPhoto
        )
        
        logger.info("📸 Total stored photos: \(self.recipePhotos.count)")
    }
}
