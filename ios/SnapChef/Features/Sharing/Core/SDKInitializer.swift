//
//  SDKInitializer.swift
//  SnapChef
//
//  Initializes all social media SDKs at app launch
//

import Foundation
import UIKit

@MainActor
final class SDKInitializer {
    static func initializeSDKs() {
        print("🚀 Initializing social media SDKs...")

        // TikTok SDK registration removed - using direct URL scheme approach
        // let tiktokSDK = TikTokSDKManager()
        // SocialSDKManager.shared.register(platform: .tiktok, sdk: tiktokSDK)
        // print("✅ TikTok SDK registered - Available: \(tiktokSDK.isAvailable())")

        // Social platform SDKs not implemented in production
        // Using direct URL scheme approach for all platforms
        // Instagram, Facebook, X (Twitter), and Snapchat use deep linking

        // Log available platforms
        let availablePlatforms = SocialSDKManager.shared.getAvailablePlatforms()
        print("📱 Available social platforms: \(availablePlatforms.map { $0.rawValue }.joined(separator: ", "))")
    }

    /// Handle URL callbacks from social platforms
    static func handleOpenURL(_ url: URL) -> Bool {
        print("🔗 Handling URL: \(url.absoluteString)")

        // Check if it's a TikTok callback
        if url.absoluteString.contains("tiktok") || url.absoluteString.contains("sbawj0946ft24i4wjv") {
            // TikTok SDK callback handling removed - using direct URL scheme
            // let handled = TikTokOpenSDKWrapper.shared.handleOpenURL(url)
            // print("✅ TikTok callback handled: \(handled)")
            return false
        }

        // Platform callbacks handled via direct URL schemes
        // No additional SDK callbacks needed for production

        return false
    }

    /// Configure URL schemes in Info.plist
    static func verifyURLSchemes() {
        let requiredSchemes = [
            "tiktok",
            "tiktokopensdk",
            "snssdk1233",
            "snssdk1180",
            "instagram",
            "instagram-stories",
            "fb",
            "facebook",
            "twitter",
            "x",
            "snapchat"
        ]

        // Check if URL schemes are configured
        if let urlTypes = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String] {
            for scheme in requiredSchemes {
                if !urlTypes.contains(scheme) {
                    print("⚠️ Warning: URL scheme '\(scheme)' not configured in Info.plist")
                }
            }
        } else {
            print("❌ Error: LSApplicationQueriesSchemes not found in Info.plist")
        }
    }
}
