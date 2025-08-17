//
//  PhotoValidator.swift
//  SnapChef
//
//  Ensures photos are valid for video generation
//

import UIKit
import CoreGraphics

/// Validates and prepares photos for video generation
public final class PhotoValidator {
    /// Ensure image has CGImage for video rendering
    public static func ensureCGImage(_ image: UIImage?) -> UIImage? {
        guard let image = image else {
            print("⚠️ PhotoValidator: Image is nil")
            return nil
        }

        print("🔍 PhotoValidator: Checking image")
        print("    - Size: \(image.size)")
        print("    - Has CGImage: \(image.cgImage != nil)")
        print("    - Has CIImage: \(image.ciImage != nil)")

        // If already has CGImage, return as is
        if image.cgImage != nil {
            print("✅ PhotoValidator: Image already has CGImage")
            return image
        }

        // If has CIImage, convert to CGImage
        if let ciImage = image.ciImage {
            print("🔄 PhotoValidator: Converting CIImage to CGImage")
            let context = CIContext()
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let newImage = UIImage(cgImage: cgImage)
                print("✅ PhotoValidator: Successfully created CGImage")
                return newImage
            }
        }

        // Try to render image to get CGImage
        print("🔄 PhotoValidator: Rendering image to get CGImage")
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }

        image.draw(at: .zero)
        let renderedImage = UIGraphicsGetImageFromCurrentImageContext()

        if let renderedImage = renderedImage, renderedImage.cgImage != nil {
            print("✅ PhotoValidator: Successfully rendered image with CGImage")
            return renderedImage
        }

        print("❌ PhotoValidator: Failed to create valid image with CGImage")
        return nil
    }

    /// Validate and prepare photos for video generation
    public static func preparePhotosForVideo(
        fridgePhoto: UIImage?,
        mealPhoto: UIImage?
    ) -> (fridge: UIImage?, meal: UIImage?) {
        print("📸 PhotoValidator: Preparing photos for video")

        let validFridge = ensureCGImage(fridgePhoto)
        let validMeal = ensureCGImage(mealPhoto)

        print("📸 PhotoValidator: Results:")
        print("    - Fridge photo: \(validFridge != nil ? "✅ Valid" : "❌ Invalid")")
        print("    - Meal photo: \(validMeal != nil ? "✅ Valid" : "❌ Invalid")")

        return (validFridge, validMeal)
    }
}
