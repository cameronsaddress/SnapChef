//
//  PhotoStorageManager.swift
//  SnapChef
//
//  Manages local storage of recipe photos for video generation
//

import UIKit
import Foundation

/// Manages local storage of recipe photos
@MainActor
public final class PhotoStorageManager: ObservableObject {
    static let shared = PhotoStorageManager()
    
    // Local storage for recipe photos
    @Published private(set) var recipePhotos: [UUID: RecipePhotos] = [:]
    
    // Photo storage structure
    public struct RecipePhotos {
        public let recipeId: UUID
        public let fridgePhoto: UIImage?      // Initial fridge photo
        public let mealPhoto: UIImage?        // Final meal photo
        public let capturedAt: Date
        
        public init(recipeId: UUID, fridgePhoto: UIImage?, mealPhoto: UIImage?) {
            self.recipeId = recipeId
            self.fridgePhoto = fridgePhoto
            self.mealPhoto = mealPhoto
            self.capturedAt = Date()
            
            print("📸 PhotoStorageManager: Storing photos for recipe \(recipeId)")
            print("    - fridgePhoto: \(fridgePhoto != nil ? "✅ \(fridgePhoto!.size)" : "❌ nil")")
            print("    - mealPhoto: \(mealPhoto != nil ? "✅ \(mealPhoto!.size)" : "❌ nil")")
        }
    }
    
    private init() {
        print("📸 PhotoStorageManager initialized")
    }
    
    /// Store fridge photo for multiple recipes (called after recipe generation)
    public func storeFridgePhoto(_ photo: UIImage, for recipeIds: [UUID]) {
        print("📸 PhotoStorageManager: Storing fridge photo for \(recipeIds.count) recipes")
        print("    - Photo size: \(photo.size)")
        print("    - Has CGImage: \(photo.cgImage != nil)")
        print("    - Has CIImage: \(photo.ciImage != nil)")
        
        for recipeId in recipeIds {
            let existing = recipePhotos[recipeId]
            recipePhotos[recipeId] = RecipePhotos(
                recipeId: recipeId,
                fridgePhoto: photo,
                mealPhoto: existing?.mealPhoto
            )
            print("    - Stored for recipe: \(recipeId)")
        }
        
        print("📸 PhotoStorageManager: Total stored photos: \(recipePhotos.count)")
    }
    
    /// Store meal photo for a specific recipe (called after cooking)
    public func storeMealPhoto(_ photo: UIImage, for recipeId: UUID) {
        print("📸 PhotoStorageManager: Storing meal photo for recipe \(recipeId)")
        
        let existing = recipePhotos[recipeId]
        recipePhotos[recipeId] = RecipePhotos(
            recipeId: recipeId,
            fridgePhoto: existing?.fridgePhoto,
            mealPhoto: photo
        )
    }
    
    /// Store both photos for a recipe (called when syncing from CloudKit)
    public func storePhotos(fridgePhoto: UIImage?, mealPhoto: UIImage?, for recipeId: UUID) {
        print("📸 PhotoStorageManager: Storing CloudKit photos for recipe \(recipeId)")
        print("    - fridgePhoto: \(fridgePhoto != nil ? "✅ \(fridgePhoto!.size)" : "❌ nil")")
        print("    - mealPhoto: \(mealPhoto != nil ? "✅ \(mealPhoto!.size)" : "❌ nil")")
        
        recipePhotos[recipeId] = RecipePhotos(
            recipeId: recipeId,
            fridgePhoto: fridgePhoto,
            mealPhoto: mealPhoto
        )
        
        print("📸 PhotoStorageManager: Total stored photos now: \(recipePhotos.count)")
    }
    
    /// Get photos for a recipe
    public func getPhotos(for recipeId: UUID) -> RecipePhotos? {
        let photos = recipePhotos[recipeId]
        
        print("📸 PhotoStorageManager: Getting photos for recipe \(recipeId)")
        print("    - Total stored recipes: \(recipePhotos.count)")
        print("    - Stored recipe IDs: \(recipePhotos.keys.map { $0.uuidString })")
        
        if let photos = photos {
            print("    - ✅ Found photos for recipe!")
            print("    - fridgePhoto: \(photos.fridgePhoto != nil ? "✅ \(photos.fridgePhoto!.size)" : "❌")")
            print("    - mealPhoto: \(photos.mealPhoto != nil ? "✅ \(photos.mealPhoto!.size)" : "❌")")
        } else {
            print("    - ❌ No photos found for recipe ID: \(recipeId)")
            print("    - Available recipe IDs in storage:")
            for (id, _) in recipePhotos {
                print("      - \(id)")
            }
        }
        
        return photos
    }
    
    /// Check if we have both photos for a recipe
    public func hasCompletePhotos(for recipeId: UUID) -> Bool {
        guard let photos = recipePhotos[recipeId] else { return false }
        return photos.fridgePhoto != nil && photos.mealPhoto != nil
    }
    
    /// Create placeholder image if needed (for testing)
    public static func createPlaceholderImage(text: String, color: UIColor = .black) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
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