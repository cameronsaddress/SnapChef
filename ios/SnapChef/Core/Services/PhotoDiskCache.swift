//
//  PhotoDiskCache.swift
//  SnapChef
//
//  Manages persistent disk storage of recipe photos to prevent CloudKit re-downloads
//

import UIKit
import Foundation
import os.log

/// Manages persistent disk storage of recipe photos with compression and efficient loading
@MainActor
public final class PhotoDiskCache {
    static let shared = PhotoDiskCache()
    
    private let logger = Logger(subsystem: "com.snapchef.photocache", category: "PhotoDiskCache")
    
    // Disk storage directories
    private let photoCacheDirectory: URL
    private let maxDiskSizeMB: Double = 500 // Maximum disk cache size in MB
    private let compressionQuality: CGFloat = 0.7 // JPEG compression quality
    
    // Cache metadata
    private var cacheMetadata: CacheMetadata = CacheMetadata()
    private let metadataFileName = "photo_cache_metadata.json"
    
    // Background queue for disk operations
    private let diskQueue = DispatchQueue(label: "com.snapchef.photodisk", qos: .utility)
    
    struct CacheMetadata: Codable {
        var entries: [String: PhotoEntry] = [:]
        var totalSizeBytes: Int64 = 0
        var lastCleanup: Date = Date()
        
        struct PhotoEntry: Codable {
            let recipeId: String
            let hasFridgePhoto: Bool
            let hasPantryPhoto: Bool
            let hasMealPhoto: Bool
            let sizeBytes: Int64
            var lastAccessed: Date
            let createdAt: Date
        }
    }
    
    private init() {
        // Create cache directory in Caches folder (can be cleared by system if needed)
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        photoCacheDirectory = cachesDirectory.appendingPathComponent("RecipePhotos", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: photoCacheDirectory, withIntermediateDirectories: true)
        
        // Load metadata
        loadMetadata()
        
        logger.info("📸 PhotoDiskCache initialized with \(self.cacheMetadata.entries.count) cached recipes")
        logger.info("📸 Total cache size: \(Double(self.cacheMetadata.totalSizeBytes) / 1_048_576, format: .fixed(precision: 1)) MB")
    }
    
    // MARK: - Public Interface
    
    /// Save photos to disk for a recipe
    public func savePhotos(fridgePhoto: UIImage?, pantryPhoto: UIImage?, mealPhoto: UIImage?, for recipeId: UUID) async {
        await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                let recipeIdString = recipeId.uuidString
                let recipeDirectory = self.photoCacheDirectory.appendingPathComponent(recipeIdString, isDirectory: true)
                
                // Create recipe directory
                try? FileManager.default.createDirectory(at: recipeDirectory, withIntermediateDirectories: true)
                
                var totalSize: Int64 = 0
                var hasFridge = false
                var hasPantry = false
                var hasMeal = false
                
                // Save fridge photo
                if let photo = fridgePhoto {
                    let fridgeURL = recipeDirectory.appendingPathComponent("fridge.jpg")
                    if let data = photo.jpegData(compressionQuality: self.compressionQuality) {
                        try? data.write(to: fridgeURL)
                        totalSize += Int64(data.count)
                        hasFridge = true
                        self.logger.info("📸 Saved fridge photo for \(recipeIdString): \(data.count / 1024) KB")
                    }
                }
                
                // Save pantry photo
                if let photo = pantryPhoto {
                    let pantryURL = recipeDirectory.appendingPathComponent("pantry.jpg")
                    if let data = photo.jpegData(compressionQuality: self.compressionQuality) {
                        try? data.write(to: pantryURL)
                        totalSize += Int64(data.count)
                        hasPantry = true
                        self.logger.info("📸 Saved pantry photo for \(recipeIdString): \(data.count / 1024) KB")
                    }
                }
                
                // Save meal photo
                if let photo = mealPhoto {
                    let mealURL = recipeDirectory.appendingPathComponent("meal.jpg")
                    if let data = photo.jpegData(compressionQuality: self.compressionQuality) {
                        try? data.write(to: mealURL)
                        totalSize += Int64(data.count)
                        hasMeal = true
                        self.logger.info("📸 Saved meal photo for \(recipeIdString): \(data.count / 1024) KB")
                    }
                }
                
                // Update metadata
                Task { @MainActor in
                    // Remove old entry size if exists
                    if let oldEntry = self.cacheMetadata.entries[recipeIdString] {
                        self.cacheMetadata.totalSizeBytes -= oldEntry.sizeBytes
                    }
                    
                    // Add new entry
                    self.cacheMetadata.entries[recipeIdString] = CacheMetadata.PhotoEntry(
                        recipeId: recipeIdString,
                        hasFridgePhoto: hasFridge,
                        hasPantryPhoto: hasPantry,
                        hasMealPhoto: hasMeal,
                        sizeBytes: totalSize,
                        lastAccessed: Date(),
                        createdAt: Date()
                    )
                    self.cacheMetadata.totalSizeBytes += totalSize
                    
                    self.saveMetadata()
                    
                    // Check if cleanup needed
                    if Double(self.cacheMetadata.totalSizeBytes) > self.maxDiskSizeMB * 1_048_576 {
                        Task {
                            await self.performCleanup()
                        }
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    /// Load photos from disk for a recipe
    public func loadPhotos(for recipeId: UUID) async -> (fridge: UIImage?, pantry: UIImage?, meal: UIImage?) {
        return await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: (nil, nil, nil))
                    return
                }
                
                let recipeIdString = recipeId.uuidString
                let recipeDirectory = self.photoCacheDirectory.appendingPathComponent(recipeIdString, isDirectory: true)
                
                // Check if directory exists
                guard FileManager.default.fileExists(atPath: recipeDirectory.path) else {
                    self.logger.info("📸 No cached photos for \(recipeIdString)")
                    continuation.resume(returning: (nil, nil, nil))
                    return
                }
                
                var fridgePhoto: UIImage?
                var pantryPhoto: UIImage?
                var mealPhoto: UIImage?
                
                // Load fridge photo
                let fridgeURL = recipeDirectory.appendingPathComponent("fridge.jpg")
                if let data = try? Data(contentsOf: fridgeURL) {
                    fridgePhoto = UIImage(data: data)
                    self.logger.info("📸 Loaded fridge photo from disk for \(recipeIdString)")
                }
                
                // Load pantry photo
                let pantryURL = recipeDirectory.appendingPathComponent("pantry.jpg")
                if let data = try? Data(contentsOf: pantryURL) {
                    pantryPhoto = UIImage(data: data)
                    self.logger.info("📸 Loaded pantry photo from disk for \(recipeIdString)")
                }
                
                // Load meal photo
                let mealURL = recipeDirectory.appendingPathComponent("meal.jpg")
                if let data = try? Data(contentsOf: mealURL) {
                    mealPhoto = UIImage(data: data)
                    self.logger.info("📸 Loaded meal photo from disk for \(recipeIdString)")
                }
                
                // Update last accessed time
                Task { @MainActor in
                    if var entry = self.cacheMetadata.entries[recipeIdString] {
                        entry.lastAccessed = Date()
                        self.cacheMetadata.entries[recipeIdString] = entry
                        self.saveMetadata()
                    }
                }
                
                continuation.resume(returning: (fridgePhoto, pantryPhoto, mealPhoto))
            }
        }
    }
    
    /// Check if photos exist on disk for a recipe
    public func hasPhotos(for recipeId: UUID) -> Bool {
        let recipeIdString = recipeId.uuidString
        return cacheMetadata.entries[recipeIdString] != nil
    }
    
    /// Get all cached recipe IDs
    public func getCachedRecipeIDs() -> Set<String> {
        return Set(cacheMetadata.entries.keys)
    }
    
    /// Get cache size information
    public func getCacheInfo() -> (recipeCount: Int, totalSizeMB: Double) {
        let count = cacheMetadata.entries.count
        let sizeMB = Double(cacheMetadata.totalSizeBytes) / 1_048_576
        return (count, sizeMB)
    }
    
    // MARK: - Private Methods
    
    private func loadMetadata() {
        let metadataURL = photoCacheDirectory.appendingPathComponent(metadataFileName)
        
        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(CacheMetadata.self, from: data) else {
            logger.info("📸 No existing metadata found, starting fresh")
            return
        }
        
        cacheMetadata = metadata
        logger.info("📸 Loaded metadata for \(metadata.entries.count) cached recipes")
    }
    
    private func saveMetadata() {
        let metadataURL = photoCacheDirectory.appendingPathComponent(metadataFileName)
        
        guard let data = try? JSONEncoder().encode(cacheMetadata) else {
            logger.error("📸 Failed to encode metadata")
            return
        }
        
        try? data.write(to: metadataURL)
    }
    
    private func performCleanup() async {
        logger.info("📸 Starting cache cleanup (current size: \(Double(self.cacheMetadata.totalSizeBytes) / 1_048_576, format: .fixed(precision: 1)) MB)")
        
        // Sort entries by last accessed date (oldest first)
        let sortedEntries = cacheMetadata.entries.values.sorted { $0.lastAccessed < $1.lastAccessed }
        
        // Remove oldest entries until under limit
        let targetSize = Int64(maxDiskSizeMB * 0.8 * 1_048_576) // Target 80% of max
        var currentSize = cacheMetadata.totalSizeBytes
        var entriesToRemove: [String] = []
        
        for entry in sortedEntries {
            if currentSize <= targetSize {
                break
            }
            
            entriesToRemove.append(entry.recipeId)
            currentSize -= entry.sizeBytes
        }
        
        // Remove from disk and metadata
        for recipeId in entriesToRemove {
            let recipeDirectory = photoCacheDirectory.appendingPathComponent(recipeId, isDirectory: true)
            try? FileManager.default.removeItem(at: recipeDirectory)
            
            if let entry = cacheMetadata.entries.removeValue(forKey: recipeId) {
                cacheMetadata.totalSizeBytes -= entry.sizeBytes
            }
        }
        
        cacheMetadata.lastCleanup = Date()
        saveMetadata()
        
        logger.info("📸 Cleanup complete: removed \(entriesToRemove.count) recipes, new size: \(Double(self.cacheMetadata.totalSizeBytes) / 1_048_576, format: .fixed(precision: 1)) MB")
    }
    
    /// Clear all cached photos (for debugging/testing)
    public func clearAllCache() async {
        logger.info("📸 Clearing all photo cache")
        
        // Remove all directories
        try? FileManager.default.removeItem(at: photoCacheDirectory)
        try? FileManager.default.createDirectory(at: photoCacheDirectory, withIntermediateDirectories: true)
        
        // Reset metadata
        cacheMetadata = CacheMetadata()
        saveMetadata()
        
        logger.info("📸 Photo cache cleared")
    }
}