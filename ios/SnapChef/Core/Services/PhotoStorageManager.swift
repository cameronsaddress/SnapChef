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
    private let maxStoredPhotos = 100 // Maximum photos to keep in memory

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

        // Start periodic cleanup timer
        startPeriodicCleanup()
    }

    /// Store fridge photo for multiple recipes (called after recipe generation)
    public func storeFridgePhoto(_ photo: UIImage, for recipeIds: [UUID]) {
        logger.info("📸 Storing fridge photo for \(recipeIds.count) recipes")

        for recipeId in recipeIds {
            let existing = recipePhotos[recipeId]
            recipePhotos[recipeId] = RecipePhotos(
                recipeId: recipeId,
                fridgePhoto: photo,
                pantryPhoto: existing?.pantryPhoto,
                mealPhoto: existing?.mealPhoto
            )
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
        }

        logger.info("📸 Total stored photos: \(self.recipePhotos.count)")
    }

    /// Store all photos for a recipe (called when syncing from CloudKit)
    public func storePhotos(fridgePhoto: UIImage?, pantryPhoto: UIImage? = nil, mealPhoto: UIImage?, for recipeId: UUID) {
        logger.info("📸 Storing CloudKit photos for recipe \(recipeId)")

        recipePhotos[recipeId] = RecipePhotos(
            recipeId: recipeId,
            fridgePhoto: fridgePhoto,
            pantryPhoto: pantryPhoto,
            mealPhoto: mealPhoto
        )

        logger.info("📸 Total stored photos now: \(self.recipePhotos.count)")
    }

    /// Get photos for a recipe
    public func getPhotos(for recipeId: UUID) -> RecipePhotos? {
        let photos = recipePhotos[recipeId]
        logger.info("📸 Getting photos for recipe \(recipeId) - found: \(photos != nil)")
        return photos
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
        for recipeID in recipeIDs where recipePhotos.removeValue(forKey: recipeID) != nil {
            removedCount += 1
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
        Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performCleanupIfNeeded()
            }
        }
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

    /// Background cleanup of orphaned and old photos
    public func performBackgroundCleanup() {
        cleanupQueue.async { [weak self] in
            guard let self = self else { return }

            Task { @MainActor in
                self.logger.info("📸 Starting background photo cleanup")

                _ = self.getMemoryUsageInfo()

                // Remove photos older than 7 days
                let oldPhotoIDs = self.getOldPhotos(olderThan: 7 * 24 * 60 * 60) // 7 days
                if !oldPhotoIDs.isEmpty {
                    self.logger.info("📸 Removing \(oldPhotoIDs.count) old photos")
                    self.removePhotos(for: oldPhotoIDs)
                }

                // If still over limit, remove oldest photos
                if self.recipePhotos.count > self.maxStoredPhotos {
                    let sortedPhotos = self.recipePhotos.sorted { $0.value.capturedAt < $1.value.capturedAt }
                    let excessCount = self.recipePhotos.count - self.maxStoredPhotos
                    let toRemove = Array(sortedPhotos.prefix(excessCount)).map { $0.key }

                    self.logger.info("📸 Removing \(toRemove.count) excess photos")
                    self.removePhotos(for: toRemove)
                }

                let memoryInfoAfter = self.getMemoryUsageInfo()
                self.logger.info("📸 Cleanup complete - \(memoryInfoAfter.photoCount) photos, \(String(format: "%.1f", memoryInfoAfter.estimatedMemoryMB)) MB")
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
}
