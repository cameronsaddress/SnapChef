//
//  ImprovedShareService.swift
//  SnapChef
//
//  Enhanced deep linking for social media platforms
//

import SwiftUI
import UIKit
import Photos

// MARK: - Improved Deep Linking Service
@MainActor
class ImprovedShareService {
    // MARK: - TikTok Deep Linking
    static func shareToTikTok(content: ShareContent, videoURL: URL? = nil) async -> Bool {
        // For TikTok, we need to:
        // 1. Save video to Photos if available
        // 2. Copy caption/hashtags to clipboard
        // 3. Open TikTok with proper deep link

        var captionText = content.text
        let hashtags = content.hashtags.map { "#\($0)" }.joined(separator: " ")
        captionText += "\n\n\(hashtags)"

        // Add app download link
        captionText += "\n\nMade with SnapChef 🍳\nDownload: https://snapchef.app"

        // Copy to clipboard for easy pasting
        UIPasteboard.general.string = captionText

        // If we have a video, save it first
        if let videoURL = videoURL {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }
                print("✅ Video saved to Photos for TikTok")
            } catch {
                print("❌ Failed to save video: \(error)")
            }
        }

        // TikTok deep link options:
        // - tiktok://create - Opens camera/creation screen
        // - tiktok://library - Opens user's library to select video
        // - tiktok://publish - Goes to publish screen

        let deepLinkURL = videoURL != nil ? "tiktok://library" : "tiktok://create"

        if let url = URL(string: deepLinkURL),
           UIApplication.shared.canOpenURL(url) {
            await UIApplication.shared.open(url)
            return true
        } else {
            // Fallback to web
            if let webURL = URL(string: "https://www.tiktok.com/upload") {
                await UIApplication.shared.open(webURL)
                return true
            }
        }

        return false
    }

    // MARK: - Instagram Deep Linking
    static func shareToInstagramStories(content: ShareContent, image: UIImage?) async -> Bool {
        guard let image = image else { return false }

        // Instagram Stories requires special handling
        guard let imageData = image.pngData() else { return false }

        // Prepare pasteboard items
        var items = [[String: Any]]()
        items.append(["com.instagram.sharedSticker.stickerImage": imageData])

        // Add background color
        items.append(["com.instagram.sharedSticker.backgroundTopColor": "#FF0050"])
        items.append(["com.instagram.sharedSticker.backgroundBottomColor": "#00F2EA"])

        // Add attribution link
        if let deepLink = content.deepLink {
            items.append(["com.instagram.sharedSticker.contentURL": deepLink.absoluteString])
        }

        // Set pasteboard options
        let pasteboardOptions = [
            UIPasteboard.OptionsKey.expirationDate: Date().addingTimeInterval(60 * 5)
        ]

        UIPasteboard.general.setItems(items, options: pasteboardOptions)

        // Open Instagram Stories
        if let url = URL(string: "instagram-stories://share?source_application=com.snapchefapp.app") {
            if UIApplication.shared.canOpenURL(url) {
                await UIApplication.shared.open(url)
                return true
            }
        }

        return false
    }

    static func shareToInstagramFeed(content: ShareContent, image: UIImage?) async -> Bool {
        // For feed posts, we need to save the image and copy caption
        guard let image = image else { return false }

        // Save image to Photos
        do {
            try await PHPhotoLibrary.shared().performChanges {
                _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            print("✅ Image saved to Photos for Instagram")
        } catch {
            print("❌ Failed to save image: \(error)")
            return false
        }

        // Prepare caption with hashtags
        var captionText = content.text
        let hashtags = content.hashtags.map { "#\($0)" }.joined(separator: " ")
        captionText += "\n\n\(hashtags)"
        captionText += "\n\n📱 Download SnapChef: https://snapchef.app"

        UIPasteboard.general.string = captionText

        // Instagram deep links:
        // - instagram://camera - Opens camera
        // - instagram://library - Opens photo library
        // - instagram://share - Opens share screen

        if let url = URL(string: "instagram://library"),
           UIApplication.shared.canOpenURL(url) {
            await UIApplication.shared.open(url)
            return true
        }

        return false
    }

    // MARK: - X (Twitter) Deep Linking
    static func shareToX(content: ShareContent, image: UIImage? = nil) async -> Bool {
        var tweetText = content.text
        let hashtags = content.hashtags.map { "#\($0)" }.joined(separator: " ")
        tweetText += "\n\n\(hashtags)"

        // Add app link
        tweetText += "\n\n📱 snapchef.app"

        // URL encode the text
        guard let encodedText = tweetText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return false
        }

        // X/Twitter URL schemes:
        // - twitter://post?message=TEXT
        // - x-com://post?text=TEXT (newer X app)
        // - https://twitter.com/intent/tweet?text=TEXT (web fallback)

        // Try X app first
        if let xURL = URL(string: "x-com://post?text=\(encodedText)"),
           UIApplication.shared.canOpenURL(xURL) {
            await UIApplication.shared.open(xURL)
            return true
        }

        // Try Twitter app
        if let twitterURL = URL(string: "twitter://post?message=\(encodedText)"),
           UIApplication.shared.canOpenURL(twitterURL) {
            await UIApplication.shared.open(twitterURL)
            return true
        }

        // Fallback to web
        if let webURL = URL(string: "https://x.com/intent/tweet?text=\(encodedText)") {
            await UIApplication.shared.open(webURL)
            return true
        }

        return false
    }

    // MARK: - Facebook Deep Linking
    static func shareToFacebook(content: ShareContent, image: UIImage? = nil) async -> Bool {
        var postText = content.text
        let hashtags = content.hashtags.map { "#\($0)" }.joined(separator: " ")
        postText += "\n\n\(hashtags)"

        guard let encodedText = postText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return false
        }

        // Facebook URL schemes:
        // - fb://publish/profile/me - Opens post composer
        // - fb://feed - Opens news feed
        // - fb://compose - Opens composer (deprecated)
        // - fbapi20130214://dialog/feed - Facebook SDK dialog

        // Facebook's deep linking is limited, most params are ignored
        // Best approach is to use Facebook SDK or web share

        let shareURL = "https://snapchef.app"
        let encodedURL = shareURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Try native app with share dialog
        if let fbURL = URL(string: "fb://publish/profile/me?quote=\(encodedText)"),
           UIApplication.shared.canOpenURL(fbURL) {
            await UIApplication.shared.open(fbURL)
            return true
        }

        // Fallback to web share dialog
        if let webURL = URL(string: "https://www.facebook.com/sharer/sharer.php?u=\(encodedURL)&quote=\(encodedText)") {
            await UIApplication.shared.open(webURL)
            return true
        }

        return false
    }

    // MARK: - WhatsApp Deep Linking
    static func shareToWhatsApp(content: ShareContent, image: UIImage? = nil) async -> Bool {
        var messageText = content.text
        let hashtags = content.hashtags.map { "#\($0)" }.joined(separator: " ")
        messageText += "\n\n\(hashtags)"
        messageText += "\n\n📱 Download SnapChef: https://snapchef.app"

        guard let encodedText = messageText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return false
        }

        // WhatsApp URL schemes:
        // - whatsapp://send?text=MESSAGE
        // - whatsapp://app - Opens WhatsApp
        // - https://wa.me/?text=MESSAGE (web fallback)

        if let whatsappURL = URL(string: "whatsapp://send?text=\(encodedText)"),
           UIApplication.shared.canOpenURL(whatsappURL) {
            await UIApplication.shared.open(whatsappURL)
            return true
        }

        // Fallback to web
        if let webURL = URL(string: "https://wa.me/?text=\(encodedText)") {
            await UIApplication.shared.open(webURL)
            return true
        }

        return false
    }

    // MARK: - Helper Methods

    /// Check if an app is installed
    static func isAppInstalled(_ platform: SharePlatformType) -> Bool {
        guard let scheme = platform.urlScheme,
              let url = URL(string: scheme) else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Get fallback web URL for platform
    static func getFallbackURL(for platform: SharePlatformType) -> URL? {
        switch platform {
        case .tiktok:
            return URL(string: "https://www.tiktok.com")
        case .instagram, .instagramStory:
            return URL(string: "https://www.instagram.com")
        case .twitter:
            return URL(string: "https://x.com")
        case .facebook:
            return URL(string: "https://www.facebook.com")
        case .whatsapp:
            return URL(string: "https://web.whatsapp.com")
        default:
            return nil
        }
    }
}

// MARK: - URL Scheme Detection Extension
extension SharePlatformType {
    /// Check multiple URL schemes for better compatibility
    var alternativeSchemes: [String] {
        switch self {
        case .tiktok:
            return ["tiktok://", "snssdk1128://", "snssdk1180://"] // Different TikTok versions
        case .instagram:
            return ["instagram://", "instagram-stories://"]
        case .twitter:
            return ["twitter://", "x-com://", "twitterrific://"] // X and third-party clients
        case .facebook:
            return ["fb://", "facebook://", "fbapi20130214://"]
        case .whatsapp:
            return ["whatsapp://", "whatsapp-business://"]
        default:
            return []
        }
    }

    /// Get the best available scheme
    func getBestAvailableScheme() -> String? {
        for scheme in alternativeSchemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                return scheme
            }
        }
        return urlScheme
    }
}
