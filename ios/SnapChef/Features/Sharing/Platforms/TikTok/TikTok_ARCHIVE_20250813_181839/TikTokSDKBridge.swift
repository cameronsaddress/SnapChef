//
//  TikTokSDKBridge.swift
//  SnapChef
//
//  TikTok SDK Bridge - Enhanced sharing with proper video handling
//

import Foundation
import UIKit

@MainActor
final class TikTokSDKBridge: NSObject {
    static let shared = TikTokSDKBridge()

    // Sandbox credentials - REMOVED: Use secure KeychainManager instead
    private let clientKey = "sbawj0946ft24i4wjv"
    private var clientSecret: String? {
        return KeychainManager.shared.getTikTokClientSecret()
    }

    private var currentCompletion: ((Bool, String?) -> Void)?

    override init() {
        super.init()
        setupSDK()
    }

    // MARK: - SDK Setup

    private func setupSDK() {
        print("🎬 TikTok SDK Bridge: Initialized with client key: \(clientKey)")
    }

    // MARK: - Share Video with Enhanced Method

    func shareVideo(videoURL: URL, caption: String?, hashtags: [String]?, completion: @escaping (Bool, String?) -> Void) {
        currentCompletion = completion

        // Check if TikTok is installed
        guard isTikTokInstalled else {
            completion(false, "TikTok app is not installed")
            return
        }

        print("🎬 TikTok SDK Bridge: Starting video share process")

        // Use SafeVideoSaver to save video
        SafeVideoSaver.shared.saveVideoToPhotoLibrary(videoURL) { [weak self] success, error in
            guard success else {
                completion(false, error ?? "Failed to save video to photo library")
                return
            }

            print("✅ TikTok SDK Bridge: Video saved to photo library")

            // Prepare full caption with hashtags
            let fullCaption = self?.prepareFullCaption(caption: caption, hashtags: hashtags) ?? ""

            // Copy to clipboard
            UIPasteboard.general.string = fullCaption
            print("📋 TikTok SDK Bridge: Caption copied to clipboard")

            // Open TikTok with the best available method
            self?.openTikTokForVideo { opened in
                if opened {
                    print("✅ TikTok SDK Bridge: TikTok opened successfully")
                    completion(true, nil)
                } else {
                    completion(false, "Failed to open TikTok")
                }
            }
        }
    }

    // MARK: - Share Image

    func shareImage(image: UIImage, caption: String?, hashtags: [String]?, completion: @escaping (Bool, String?) -> Void) {
        currentCompletion = completion

        // Check if TikTok is installed
        guard isTikTokInstalled else {
            completion(false, "TikTok app is not installed")
            return
        }

        // Use SafePhotoSaver to save image
        SafePhotoSaver.shared.saveImageToPhotoLibrary(image) { [weak self] success, error in
            guard success else {
                completion(false, error ?? "Failed to save image to photo library")
                return
            }

            print("✅ TikTok SDK Bridge: Image saved to photo library")

            // Prepare caption
            let fullCaption = self?.prepareFullCaption(caption: caption, hashtags: hashtags) ?? ""
            UIPasteboard.general.string = fullCaption

            // Open TikTok
            self?.openTikTokForImage { opened in
                completion(opened, opened ? nil : "Failed to open TikTok")
            }
        }
    }

    // MARK: - TikTok Opening Methods

    private func openTikTokForVideo(completion: @escaping (Bool) -> Void) {
        // Show user instructions first
        showInstructions(for: "video")

        // Try various URL schemes to open TikTok in the best mode for sharing
        let schemes = [
            "snssdk1233://aweme/create?source=snapchef", // TikTok create with source
            "tiktok://create?source=snapchef",           // Alternative create
            "snssdk1233://studio/upload",                // Studio upload
            "tiktok://studio/upload",                    // Alternative studio
            "snssdk1233://aweme/library",                // Library view
            "tiktok://library",                          // Alternative library
            "snssdk1233://aweme",                        // Main feed
            "tiktok://"                                  // Fallback
        ]

        // Add a small delay to ensure video is fully processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for scheme in schemes {
                if let url = URL(string: scheme),
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url) { success in
                        if success {
                            print("🎬 Opened TikTok with: \(scheme)")
                        }
                        completion(success)
                    }
                    return
                }
            }
            completion(false)
        }
    }

    private func openTikTokForImage(completion: @escaping (Bool) -> Void) {
        showInstructions(for: "image")

        let schemes = [
            "snssdk1233://aweme/create",
            "tiktok://create",
            "snssdk1233://",
            "tiktok://"
        ]

        for scheme in schemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url) { success in
                    completion(success)
                }
                return
            }
        }
        completion(false)
    }

    // MARK: - Helper Methods

    private func prepareFullCaption(caption: String?, hashtags: [String]?) -> String {
        var components: [String] = []

        // Add caption
        if let caption = caption, !caption.isEmpty {
            components.append(caption)
        }

        // Add hashtags
        if let hashtags = hashtags, !hashtags.isEmpty {
            let hashtagString = hashtags.map { tag in
                tag.hasPrefix("#") ? tag : "#\(tag)"
            }.joined(separator: " ")
            components.append(hashtagString)
        }

        // Add app attribution
        components.append("\n🍳 Made with @snapchef")
        components.append("Download: snapchef.app")

        return components.joined(separator: "\n")
    }

    private func showInstructions(for mediaType: String) {
        let message = """
        ✅ Your \(mediaType) has been saved!
        📋 Caption copied to clipboard

        In TikTok:
        1. Tap '+' to create
        2. Select 'Upload'
        3. Choose your \(mediaType) (most recent)
        4. Paste the caption
        """

        print("📱 User Instructions: \(message)")

        // You could show this as an alert or toast in the UI
    }

    // MARK: - URL Handling

    func handleOpenURL(_ url: URL) -> Bool {
        // Handle TikTok callbacks if they come back
        if url.absoluteString.contains(clientKey) {
            print("✅ TikTok callback received")
            currentCompletion?(true, nil)
            return true
        }
        return false
    }
}

// MARK: - Public Interface

extension TikTokSDKBridge {
    /// Check if TikTok is installed
    var isTikTokInstalled: Bool {
        let schemes = ["tiktok://", "snssdk1233://", "musically://"]
        for scheme in schemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                return true
            }
        }
        return false
    }

    /// Share content using the bridge
    func share(content: SDKShareContent, completion: @escaping (Bool, String?) -> Void) {
        switch content.type {
        case .video(let url):
            shareVideo(videoURL: url, caption: content.caption, hashtags: content.hashtags, completion: completion)
        case .image(let image):
            shareImage(image: image, caption: content.caption, hashtags: content.hashtags, completion: completion)
        case .multipleImages(let images):
            // Share first image for TikTok
            if let firstImage = images.first {
                shareImage(image: firstImage, caption: content.caption, hashtags: content.hashtags, completion: completion)
            } else {
                completion(false, "No images to share")
            }
        default:
            completion(false, "Content type not supported for TikTok sharing")
        }
    }
}
