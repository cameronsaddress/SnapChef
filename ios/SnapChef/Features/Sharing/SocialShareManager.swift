import Foundation
import SwiftUI
import Photos
import AVFoundation

@MainActor
class SocialShareManager: ObservableObject {
    static let shared = SocialShareManager()
    
    @Published var isSharing = false
    @Published var shareResult: ShareResult?
    @Published var showRecipeFromDeepLink = false
    @Published var pendingRecipe: Recipe?
    @Published var pendingDeepLink: DeepLinkType?
    
    private init() {}
    
    enum ShareResult {
        case success(String)
        case failure(Error)
    }
    
    enum SharePlatform {
        case instagram
        case tiktok
        case twitter
        case messages
        case general
    }
    
    enum DeepLinkType {
        case recipe(String)
    }
    
    // MARK: - Public Interface
    
    func shareRecipe(_ recipe: Recipe, image: UIImage?, platform: SharePlatform) async {
        isSharing = true
        defer { isSharing = false }
        
        do {
            switch platform {
            case .instagram:
                try await shareToInstagram(recipe: recipe, image: image)
            case .tiktok:
                try await shareToTikTok(recipe: recipe, image: image)
            case .twitter:
                try await shareToTwitter(recipe: recipe, image: image)
            case .messages:
                try await shareToMessages(recipe: recipe, image: image)
            case .general:
                try await shareGeneral(recipe: recipe, image: image)
            }
            
            shareResult = .success("Successfully shared to \(platform)")
        } catch {
            shareResult = .failure(error)
        }
    }
    
    // MARK: - Platform-Specific Sharing
    
    private func shareToInstagram(recipe: Recipe, image: UIImage?) async throws {
        guard let image = image else {
            throw ShareError.missingImage
        }
        
        // Save image to photo library first
        try await saveImageToPhotoLibrary(image)
        
        // Open Instagram if available
        if let instagramURL = URL(string: "instagram://app") {
            if UIApplication.shared.canOpenURL(instagramURL) {
                await UIApplication.shared.open(instagramURL)
            } else {
                throw ShareError.appNotInstalled("Instagram")
            }
        }
    }
    
    private func shareToTikTok(recipe: Recipe, image: UIImage?) async throws {
        guard let image = image else {
            throw ShareError.missingImage
        }
        
        // Save image to photo library first
        try await saveImageToPhotoLibrary(image)
        
        // Open TikTok if available
        if let tiktokURL = URL(string: "tiktok://") {
            if UIApplication.shared.canOpenURL(tiktokURL) {
                await UIApplication.shared.open(tiktokURL)
            } else {
                throw ShareError.appNotInstalled("TikTok")
            }
        }
    }
    
    private func shareToTwitter(recipe: Recipe, image: UIImage?) async throws {
        let text = generateShareText(for: recipe)
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let twitterURL = URL(string: "twitter://post?message=\(encodedText)") {
            if UIApplication.shared.canOpenURL(twitterURL) {
                await UIApplication.shared.open(twitterURL)
            } else if let webURL = URL(string: "https://twitter.com/intent/tweet?text=\(encodedText)") {
                await UIApplication.shared.open(webURL)
            }
        }
    }
    
    private func shareToMessages(recipe: Recipe, image: UIImage?) async throws {
        let text = generateShareText(for: recipe)
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let messagesURL = URL(string: "sms:&body=\(encodedText)") {
            await UIApplication.shared.open(messagesURL)
        }
    }
    
    private func shareGeneral(recipe: Recipe, image: UIImage?) async throws {
        // This will trigger the system share sheet
        // Implementation depends on the calling view
    }
    
    // MARK: - Helper Methods
    
    private func generateShareText(for recipe: Recipe) -> String {
        return "Check out this amazing recipe I found on SnapChef: \(recipe.name)! 🍽️ #SnapChef #Recipe"
    }
    
    // MARK: - Deep Link Handling
    
    func handleIncomingURL(_ url: URL) -> Bool {
        // Parse URL to extract recipe ID
        let urlString = url.absoluteString
        if urlString.contains("snapchef.app/recipe/") {
            // Extract recipe ID from URL path
            let components = url.pathComponents
            if components.count >= 3 && components[1] == "recipe" {
                let recipeID = components[2]
                // Store the pending deep link
                pendingDeepLink = .recipe(recipeID)
                showRecipeFromDeepLink = true
                return true
            }
        }
        return false
    }
    
    func resolvePendingDeepLink() {
        // This would typically fetch the recipe from CloudKit or the server
        // For now, just hide the sheet
        showRecipeFromDeepLink = false
        pendingRecipe = nil
        pendingDeepLink = nil
    }
    
    // MARK: - Universal Link Generation
    
    func generateUniversalLink(for recipe: Recipe, cloudKitRecordID: String?) -> URL {
        let baseURL = "https://snapchef.app/recipe"
        let urlString: String
        if let recordID = cloudKitRecordID {
            urlString = "\(baseURL)/\(recordID)"
        } else {
            urlString = "\(baseURL)/\(recipe.id.uuidString)"
        }
        if let url = URL(string: urlString) {
            return url
        } else if let fallbackURL = URL(string: baseURL) {
            return fallbackURL
        } else {
            // Final fallback to snapchef.com
            return URL(string: "https://snapchef.com")!
        }
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? ShareError.saveFailed)
                }
            }
        }
    }
    
    // MARK: - Photo Library Permission
    
    func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}