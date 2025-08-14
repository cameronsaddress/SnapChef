//
//  AppDelegate.swift
//  SnapChef
//
//  App delegate for TikTok SDK initialization
//

import UIKit

#if canImport(TikTokOpenShareSDK)
import TikTokOpenShareSDK
#endif

#if canImport(TikTokOpenSDKCore)
import TikTokOpenSDKCore
#endif

#if canImport(TikTokOpenAuthSDK)
import TikTokOpenAuthSDK
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // TikTok SDK initialization with sandbox credentials
        // The SDK will be initialized when first used
        #if canImport(TikTokOpenShareSDK)
        print("✅ TikTok OpenShareSDK available for use")
        #endif
        
        print("✅ AppDelegate initialized")
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        // Handle TikTok callbacks through URL schemes
        // The TikTok SDK handles callbacks internally when sharing
        
        // TikTok callback handling removed - using direct URL scheme
        // if url.absoluteString.contains("tiktok") || url.absoluteString.contains("sbawj0946ft24i4wjv") {
        //     let handled = TikTokOpenSDKWrapper.shared.handleOpenURL(url)
        //     if handled {
        //         print("✅ TikTok callback handled by wrapper: \(url)")
        //         return true
        //     }
        // }
        
        // Let the app handle other URLs
        return false
    }
}