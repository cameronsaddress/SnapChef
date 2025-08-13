//
//  SimpleMediaBundle.swift
//  SnapChef
//
//  Simplified MediaBundle with only the photos we actually use
//

import UIKit

/// Simplified media bundle with only before (fridge) and after (meal) photos
public struct SimpleMediaBundle: Sendable {
    public let fridgePhoto: UIImage     // Initial fridge photo
    public let mealPhoto: UIImage       // Final cooked meal photo
    public let brollClips: [URL]        // Optional cooking clips
    public let musicURL: URL?           // Optional music
    
    public init(
        fridgePhoto: UIImage,
        mealPhoto: UIImage,
        brollClips: [URL] = [],
        musicURL: URL? = nil
    ) {
        self.fridgePhoto = fridgePhoto
        self.mealPhoto = mealPhoto
        self.brollClips = brollClips
        self.musicURL = musicURL
        
        print("📸 SimpleMediaBundle created:")
        print("    - fridgePhoto: \(fridgePhoto.size) - Has CGImage: \(fridgePhoto.cgImage != nil)")
        print("    - mealPhoto: \(mealPhoto.size) - Has CGImage: \(mealPhoto.cgImage != nil)")
    }
    
    /// Convert to legacy MediaBundle for compatibility
    public func toLegacyMediaBundle() -> MediaBundle {
        // For legacy compatibility, use fridgePhoto for beforeFridge
        // and mealPhoto for both afterFridge and cookedMeal
        return MediaBundle(
            beforeFridge: fridgePhoto,
            afterFridge: mealPhoto,  // Using meal photo since we don't have after-fridge concept
            cookedMeal: mealPhoto,
            brollClips: brollClips,
            musicURL: musicURL
        )
    }
}

/// Extension to help with photo validation
extension UIImage {
    /// Check if this is a valid photo (not a placeholder)
    public var isValidPhoto: Bool {
        // Check if we have actual image data
        guard let cgImage = self.cgImage else { return false }
        
        // Check if it's not too small (likely a placeholder)
        if size.width < 100 || size.height < 100 {
            return false
        }
        
        // Check if it has reasonable dimensions
        return cgImage.width > 0 && cgImage.height > 0
    }
}