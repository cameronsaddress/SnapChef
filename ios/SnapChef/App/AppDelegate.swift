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

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // TikTok SDK initialization happens automatically when creating share requests
        // No explicit initialization needed according to latest SDK
        print("✅ AppDelegate initialized")
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        // Handle TikTok callbacks through our wrapper
        if url.absoluteString.contains("tiktok") || url.absoluteString.contains("sbawj0946ft24i4wjv") {
            let handled = TikTokOpenSDKWrapper.shared.handleOpenURL(url)
            if handled {
                print("✅ TikTok callback handled: \(url)")
                return true
            }
        }
        
        // Let the app handle other URLs
        return false
    }
}