//
//  TikTokSDKManager.swift
//  SnapChef
//
//  TikTok OpenSDK integration for native sharing
//

import Foundation
import UIKit
import Photos

@MainActor
final class TikTokSDKManager: SocialShareSDKProtocol {
    
    // MARK: - Properties
    
    // Sandbox credentials for testing
    private let clientKey = "sbawj0946ft24i4wjv"
    private let clientSecret = "1BsqJsVa6bKjzlt2BvJgrapjgfNw7Ewk"
    private let redirectURI = "snapchef://tiktok/callback"
    
    // TikTok URL schemes for different regions/versions
    private let tiktokSchemes = [
        "tiktokopensdk://",
        "snssdk1233://",     // International version
        "snssdk1180://",     // Some regions
        "tiktok://",         // Fallback
        "musically://"       // Legacy
    ]
    
    // MARK: - SocialShareSDKProtocol
    
    func isAvailable() -> Bool {
        // Use the proper SDK wrapper to check if TikTok is installed
        return TikTokOpenSDKWrapper.shared.isTikTokInstalled
    }
    
    func share(content: SDKShareContent) async throws {
        // Use the new ShareService implementation for TikTok
        switch content.type {
        case .video(let url):
            try await shareVideo(url, caption: content.caption, hashtags: content.hashtags)
        case .image(let image):
            try await shareImage(image, caption: content.caption, hashtags: content.hashtags)
        case .multipleImages(let images):
            if let firstImage = images.first {
                try await shareImage(firstImage, caption: content.caption, hashtags: content.hashtags)
            } else {
                throw SDKError.unknown("No images to share")
            }
        default:
            throw SDKError.unknown("Content type not supported")
        }
    }
    
    func authenticate() async throws -> Bool {
        // TikTok OpenSDK doesn't require authentication for sharing
        // This would be implemented if using Login Kit
        return true
    }
    
    func getConfigurationRequirements() -> [String: String] {
        return [
            "Client Key": clientKey,
            "Client Secret": "***" + String(clientSecret.suffix(4)), // Hide most of secret
            "Redirect URI": redirectURI,
            "URL Schemes": tiktokSchemes.joined(separator: ", "),
            "Status": "Configured ✅"
        ]
    }
    
    // MARK: - Private Methods
    
    private func shareImage(_ image: UIImage, caption: String?, hashtags: [String]?) async throws {
        // Prepare caption with hashtags
        let fullCaption = prepareCaption(caption: caption, hashtags: hashtags)
        
        print("🎬 TikTok SDK: Starting image share process")
        print("📋 Caption: \(fullCaption)")
        
        // Save image to photo library and get localIdentifier
        let result = await withCheckedContinuation { continuation in
            var localIdentifier: String?
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: image.jpegData(compressionQuality: 0.9) ?? Data(), options: nil)
                localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
            }) { success, error in
                continuation.resume(returning: (success, localIdentifier, error))
            }
        }
        
        guard result.0, let identifier = result.1 else {
            throw SDKError.permissionDenied
        }
        
        print("✅ Image saved with identifier: \(identifier)")
        
        // Share using TikTokShareService
        try await withCheckedThrowingContinuation { continuation in
            TikTokShareService.shareToTikTok(localIdentifiers: [identifier], caption: fullCaption) { shareResult in
                switch shareResult {
                case .success():
                    print("✅ TikTok image share completed successfully")
                    continuation.resume()
                case .failure(let error):
                    print("❌ TikTok image share failed: \(error.localizedDescription)")
                    continuation.resume(throwing: SDKError.unknown(error.localizedDescription))
                }
            }
        }
        
        print("🎬 TikTok SDK: Image share process completed")
    }
    
    private func shareVideo(_ videoURL: URL, caption: String?, hashtags: [String]?) async throws {
        // Prepare caption with hashtags
        let fullCaption = prepareCaption(caption: caption, hashtags: hashtags)
        
        print("🎬 TikTok SDK: Starting video share process")
        print("📋 Caption: \(fullCaption)")
        
        // Use the new TikTokShareService for the complete pipeline
        try await withCheckedThrowingContinuation { continuation in
            TikTokShareService.shareRecipeToTikTok(
                videoURL: videoURL,
                customCaption: fullCaption
            ) { result in
                switch result {
                case .success():
                    print("✅ TikTok share completed successfully")
                    continuation.resume()
                case .failure(let error):
                    print("❌ TikTok share failed: \(error.localizedDescription)")
                    continuation.resume(throwing: SDKError.unknown(error.localizedDescription))
                }
            }
        }
        
        print("🎬 TikTok SDK: Share process completed")
    }
    
    private func saveImageToLibrary(_ image: UIImage) async -> Bool {
        await withCheckedContinuation { continuation in
            SafePhotoSaver.shared.saveImageToPhotoLibrary(image) { success, error in
                continuation.resume(returning: success)
            }
        }
    }
    
    private func saveVideoToLibrary(_ videoURL: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            SafeVideoSaver.shared.saveVideoToPhotoLibrary(videoURL) { success, error in
                continuation.resume(returning: success)
            }
        }
    }
    
    private func prepareCaption(caption: String?, hashtags: [String]?) -> String {
        var components: [String] = []
        
        if let caption = caption {
            components.append(caption)
        }
        
        if let hashtags = hashtags, !hashtags.isEmpty {
            let hashtagString = hashtags.map { tag in
                tag.hasPrefix("#") ? tag : "#\(tag)"
            }.joined(separator: " ")
            components.append(hashtagString)
        }
        
        // Add app attribution
        components.append("\n\n🍳 Made with SnapChef")
        components.append("#SnapChef #AIRecipes")
        
        return components.joined(separator: "\n")
    }
    
    private func openTikTokForSharing(mediaType: String) async -> Bool {
        // For sandbox environment, we need to use specific URL schemes
        // The SDK would normally handle this, but without it we use direct deep links
        
        // Show instructions to user since SDK isn't integrated
        await showSharingInstructions()
        
        // Try URL schemes in order of preference for media upload
        let uploadSchemes = [
            "tiktok://publish/video",     // Direct to video publish
            "tiktok://studio/upload",      // Creator studio upload
            "snssdk1233://studio/upload",  // International version
            "tiktok://create",             // Create screen
            "snssdk1233://create",         // International create
            "tiktok://library",            // Library to select saved video
            "snssdk1233://library",        // International library
            "tiktok://camera",             // Camera (fallback)
            "tiktok://",                   // Just open app
            "snssdk1233://"               // International fallback
        ]
        
        print("🎬 TikTok SDK: Attempting to open TikTok for \(mediaType) sharing")
        
        for urlString in uploadSchemes {
            if let url = URL(string: urlString),
               UIApplication.shared.canOpenURL(url) {
                print("🎬 TikTok SDK: Opening with URL: \(urlString)")
                let opened = await UIApplication.shared.open(url)
                if opened {
                    return true
                }
            }
        }
        
        print("❌ TikTok SDK: Could not open TikTok app")
        return false
    }
    
    @MainActor
    private func showSharingInstructions() async {
        // Create an alert to guide the user
        let message = """
        Your video has been saved to your photo library!
        
        To share on TikTok:
        1. TikTok will open
        2. Tap the '+' button
        3. Select 'Upload' 
        4. Choose your video (most recent)
        5. Your caption is copied - just paste!
        """
        
        print("📱 Instructions: \(message)")
    }
}

// MARK: - TikTok Share Options

extension TikTokSDKManager {
    
    /// Create a TikTok-ready video from recipe content
    func createTikTokVideo(from recipe: Recipe, beforePhoto: UIImage?, afterPhoto: UIImage?) async throws -> URL? {
        // This will use the existing TikTokVideoGenerator
        // We'll integrate it here once the SDK is set up
        return nil
    }
    
    /// Prepare hashtags based on recipe content
    func prepareTikTokHashtags(for recipe: Recipe) -> [String] {
        var hashtags = [
            "SnapChef",
            "AIRecipes",
            "FoodTok",
            "RecipeOfTheDay",
            "HomeCooking"
        ]
        
        // Add cuisine-specific hashtags from tags
        for tag in recipe.tags {
            if tag.lowercased().contains("cuisine") || tag.lowercased().contains("food") {
                hashtags.append(tag.replacingOccurrences(of: " ", with: ""))
            }
        }
        
        // Add difficulty hashtags
        switch recipe.difficulty {
        case .easy:
            hashtags.append("EasyRecipes")
            hashtags.append("QuickMeals")
        case .medium:
            hashtags.append("HomeCook")
        case .hard:
            hashtags.append("ChefLife")
            hashtags.append("AdvancedCooking")
        }
        
        // Add time-based hashtags
        let totalTime = recipe.prepTime + recipe.cookTime
        if totalTime <= 30 {
            hashtags.append("30MinuteMeals")
        } else if totalTime <= 60 {
            hashtags.append("UnderAnHour")
        }
        
        // Add dietary hashtags
        if recipe.dietaryInfo.isVegan {
            hashtags.append("VeganRecipes")
        } else if recipe.dietaryInfo.isVegetarian {
            hashtags.append("VegetarianRecipes")
        }
        
        if recipe.dietaryInfo.isGlutenFree {
            hashtags.append("GlutenFree")
        }
        
        return hashtags
    }
    
    /// Generate engaging caption for TikTok
    func generateTikTokCaption(for recipe: Recipe) -> String {
        let templates = [
            "POV: You turned your fridge chaos into \(recipe.name) 🤯",
            "Rating my AI chef's recipe: \(recipe.name) ⭐️⭐️⭐️⭐️⭐️",
            "Day \(Int.random(in: 1...30)) of letting AI pick my meals: \(recipe.name)",
            "The AI said I could make \(recipe.name) with THIS?! 🤔",
            "Watch me transform random ingredients into \(recipe.name) ✨"
        ]
        
        return templates.randomElement() ?? "Check out this amazing \(recipe.name)!"
    }
}