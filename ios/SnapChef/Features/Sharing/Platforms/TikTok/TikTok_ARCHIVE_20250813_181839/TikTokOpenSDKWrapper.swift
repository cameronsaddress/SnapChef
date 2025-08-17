//
//  TikTokOpenSDKWrapper.swift
//  SnapChef
//
//  Proper TikTok OpenSDK Integration
//

import Foundation
import UIKit
import Photos

// Import the actual TikTok SDK
#if canImport(TikTokOpenSDKCore)
import TikTokOpenSDKCore
#endif

#if canImport(TikTokOpenShareSDK)
import TikTokOpenShareSDK
#endif

#if canImport(TikTokOpenAuthSDK)
import TikTokOpenAuthSDK
#endif

@MainActor
final class TikTokOpenSDKWrapper: NSObject {
    static let shared = TikTokOpenSDKWrapper()

    // Sandbox credentials
    private let clientKey = "sbawj0946ft24i4wjv"
    private let clientSecret = "1BsqJsVa6bKjzlt2BvJgrapjgfNw7Ewk"

    private var shareCompletion: ((Bool, String?) -> Void)?

    override init() {
        super.init()
        setupSDK()
    }

    // MARK: - SDK Setup

    private func setupSDK() {
        #if canImport(TikTokOpenSDKCore) && canImport(TikTokOpenAuthSDK)
        // Initialize the TikTok SDK
        // Note: TikTok SDK initialization happens in the app delegate
        // We just register our settings here
        print("✅ TikTok OpenSDK configured with client key: \(clientKey)")
        #else
        print("⚠️ TikTok SDK not found - using fallback mode")
        #endif
    }

    // MARK: - Check Installation

    var isTikTokInstalled: Bool {
        // Check using URL schemes
        let schemes = ["tiktok://", "snssdk1233://", "tiktokopensdk://"]
        for scheme in schemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                return true
            }
        }
        return false
    }

    // MARK: - Share Video

    func shareVideo(videoURL: URL, caption: String?, hashtags: [String]?, completion: @escaping (Bool, String?) -> Void) {
        shareCompletion = completion

        guard isTikTokInstalled else {
            completion(false, "TikTok is not installed")
            return
        }

        // Use the media share wrapper for clean implementation
        TikTokMediaShareWrapper.shared.shareVideo(videoURL: videoURL, caption: caption, hashtags: hashtags) { success in
            completion(success, success ? nil : "Failed to share to TikTok")
        }
    }

    #if canImport(TikTokOpenShareSDK)
    private func shareVideoWithSDK(videoURL: URL, caption: String?, hashtags: [String]?, completion: @escaping (Bool, String?) -> Void) {
        // This method is kept for compatibility but delegates to TikTokMediaShareWrapper
        TikTokMediaShareWrapper.shared.shareVideo(videoURL: videoURL, caption: caption, hashtags: hashtags) { success in
            completion(success, success ? nil : "Failed to share video")
        }
    }
    #endif

    // MARK: - Fallback Implementation

    private func shareVideoFallback(videoURL: URL, caption: String?, hashtags: [String]?, completion: @escaping (Bool, String?) -> Void) {
        // Use SafeVideoSaver for fallback
        SafeVideoSaver.shared.saveVideoToPhotoLibrary(videoURL) { success, error in
            guard success else {
                completion(false, error ?? "Failed to save video")
                return
            }

            print("✅ Video saved to photo library (fallback mode)")

            // Prepare caption
            var fullCaption = caption ?? ""
            if let hashtags = hashtags {
                let hashtagString = hashtags.map { tag in
                    tag.hasPrefix("#") ? tag : "#\(tag)"
                }.joined(separator: " ")
                fullCaption += "\n\n\(hashtagString)"
            }
            fullCaption += "\n\n🍳 Made with @snapchef"

            UIPasteboard.general.string = fullCaption
            print("📋 Caption copied to clipboard")

            // Open TikTok to the upload/create screen
            // Find the first available scheme and open it
            let schemes = [
                "snssdk1233://studio/publish",     // Direct to publish studio
                "tiktok://studio/publish",          // Alternative publish studio
                "snssdk1233://create?media=library", // Create with library option
                "tiktok://create?media=library",    // Alternative create with library
                "snssdk1233://create",              // Create screen
                "tiktok://create",                  // Alternative create
                "snssdk1233://",                    // Main app
                "tiktok://"                         // Alternative main
            ]

            // Find first scheme that can be opened
            var urlToOpen: URL?
            for scheme in schemes {
                if let url = URL(string: scheme),
                   UIApplication.shared.canOpenURL(url) {
                    urlToOpen = url
                    print("🎬 Will open TikTok with: \(scheme)")
                    break
                }
            }

            // Open the URL if found
            if let url = urlToOpen {
                UIApplication.shared.open(url) { [weak self] success in
                    if success {
                        print("✅ Successfully opened TikTok")

                        // Show instructions to user
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.showTikTokInstructions()
                        }

                        completion(true, nil)
                    } else {
                        completion(false, "Failed to open TikTok")
                    }
                }
            } else {
                completion(false, "TikTok is not installed or cannot be opened")
            }
        }
    }

    // MARK: - Share Image

    func shareImage(image: UIImage, caption: String?, hashtags: [String]?, completion: @escaping (Bool, String?) -> Void) {
        shareCompletion = completion

        guard isTikTokInstalled else {
            completion(false, "TikTok is not installed")
            return
        }

        // Use the media share wrapper for clean implementation
        TikTokMediaShareWrapper.shared.shareImage(image: image, caption: caption, hashtags: hashtags) { success in
            completion(success, success ? nil : "Failed to share to TikTok")
        }
    }

    #if canImport(TikTokOpenShareSDK)
    private func shareImageWithSDK(image: UIImage, caption: String?, hashtags: [String]?, completion: @escaping (Bool, String?) -> Void) {
        // This method is kept for compatibility but delegates to TikTokMediaShareWrapper
        TikTokMediaShareWrapper.shared.shareImage(image: image, caption: caption, hashtags: hashtags) { success in
            completion(success, success ? nil : "Failed to share image")
        }
    }
    #endif

    private func shareImageFallback(image: UIImage, caption: String?, hashtags: [String]?, completion: @escaping (Bool, String?) -> Void) {
        SafePhotoSaver.shared.saveImageToPhotoLibrary(image) { success, error in
            guard success else {
                completion(false, error ?? "Failed to save image")
                return
            }

            // Prepare caption
            var fullCaption = caption ?? ""
            if let hashtags = hashtags {
                let hashtagString = hashtags.map { tag in
                    tag.hasPrefix("#") ? tag : "#\(tag)"
                }.joined(separator: " ")
                fullCaption += "\n\n\(hashtagString)"
            }
            fullCaption += "\n\n🍳 Made with @snapchef"

            UIPasteboard.general.string = fullCaption

            // Open TikTok using same approach as video
            let schemes = [
                "snssdk1233://studio/publish",
                "tiktok://studio/publish",
                "snssdk1233://create?media=library",
                "tiktok://create?media=library",
                "snssdk1233://create",
                "tiktok://create",
                "snssdk1233://",
                "tiktok://"
            ]

            // Find first scheme that can be opened
            var urlToOpen: URL?
            for scheme in schemes {
                if let url = URL(string: scheme),
                   UIApplication.shared.canOpenURL(url) {
                    urlToOpen = url
                    print("🎬 Will open TikTok with: \(scheme)")
                    break
                }
            }

            // Open the URL if found
            if let url = urlToOpen {
                UIApplication.shared.open(url) { [weak self] success in
                    if success {
                        print("✅ Successfully opened TikTok")

                        // Show instructions to user
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.showTikTokInstructions()
                        }

                        completion(true, nil)
                    } else {
                        completion(false, "Failed to open TikTok")
                    }
                }
            } else {
                completion(false, "TikTok is not installed or cannot be opened")
            }
        }
    }

    // MARK: - Helper Methods

    private func showTikTokInstructions() {
        // This could show a toast or notification
        // For now just log the instructions
        print("""
        📱 TikTok Instructions:
        1. Tap the '+' button if not already there
        2. Select your video/photo from the gallery (most recent)
        3. Paste the caption from your clipboard
        4. Share your creation!
        """)
    }

    // MARK: - URL Handling

    func handleOpenURL(_ url: URL) -> Bool {
        // Check if it's our callback
        if url.absoluteString.contains("tiktok/callback") {
            // Parse the response from the URL if needed
            shareCompletion?(true, nil)
            return true
        }
        return false
    }
}

// MARK: - Public Interface

extension TikTokOpenSDKWrapper {
    func share(content: SDKShareContent, completion: @escaping (Bool, String?) -> Void) {
        switch content.type {
        case .video(let url):
            shareVideo(videoURL: url, caption: content.caption, hashtags: content.hashtags, completion: completion)
        case .image(let image):
            shareImage(image: image, caption: content.caption, hashtags: content.hashtags, completion: completion)
        case .multipleImages(let images):
            if let first = images.first {
                shareImage(image: first, caption: content.caption, hashtags: content.hashtags, completion: completion)
            } else {
                completion(false, "No images to share")
            }
        default:
            completion(false, "Content type not supported")
        }
    }
}
