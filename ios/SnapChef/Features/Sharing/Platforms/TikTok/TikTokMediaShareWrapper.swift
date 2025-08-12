//
//  TikTokMediaShareWrapper.swift
//  SnapChef
//
//  Direct media sharing to TikTok without authentication
//

import UIKit
import Photos

#if canImport(TikTokOpenShareSDK)
import TikTokOpenShareSDK
#endif

@MainActor
class TikTokMediaShareWrapper: NSObject {
    
    static let shared = TikTokMediaShareWrapper()
    
    private override init() {
        super.init()
    }
    
    /// Share video to TikTok
    func shareVideo(videoURL: URL, caption: String? = nil, hashtags: [String]? = nil, completion: @escaping (Bool) -> Void) {
        
        // Prepare caption with hashtags for clipboard
        prepareCaptionForClipboard(caption: caption, hashtags: hashtags)
        
        #if canImport(TikTokOpenShareSDK)
        // Try direct SDK integration with proper threading
        shareVideoDirectSDK(videoURL: videoURL, caption: caption, hashtags: hashtags, completion: completion)
        #else
        // Fallback if SDK not available
        shareVideoFallback(videoURL: videoURL, caption: caption, hashtags: hashtags, completion: completion)
        #endif
    }
    
    #if canImport(TikTokOpenShareSDK)
    /// Direct SDK integration using PHAsset with proper threading
    private func shareVideoDirectSDK(videoURL: URL, caption: String? = nil, hashtags: [String]? = nil, completion: @escaping (Bool) -> Void) {
        
        // Must run PHPhotoLibrary operations on main thread
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // Request photo library permission if needed
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if status == .notDetermined {
                let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized
                guard granted else {
                    print("❌ Photo library permission denied")
                    completion(false)
                    return
                }
            } else if status != .authorized && status != .limited {
                print("❌ Photo library permission not granted")
                completion(false)
                return
            }
            
            // Save video and get PHAsset
            var localIdentifier: String?
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                localIdentifier = request?.placeholderForCreatedAsset?.localIdentifier
            }) { success, error in
                Task { @MainActor in
                    guard success, let assetId = localIdentifier else {
                        print("❌ Failed to save video: \(error?.localizedDescription ?? "unknown")")
                        self.shareVideoFallback(videoURL: videoURL, caption: caption, hashtags: hashtags, completion: completion)
                        return
                    }
                
                print("✅ Video saved with identifier: \(assetId)")
                
                // Create TikTok share request
                let shareRequest = TikTokShareRequest(localIdentifiers: [assetId], mediaType: .video, redirectURI: "snapchef://tiktok-callback")
                
                // Send the request
                let sendSuccess = shareRequest.send { response in
                    Task { @MainActor in
                        if let shareResponse = response as? TikTokShareResponse {
                            if shareResponse.errorCode == .noError {
                                print("✅ TikTok SDK: Successfully shared video")
                                completion(true)
                            } else {
                                print("❌ TikTok SDK: Share failed - \(shareResponse.errorCode.rawValue)")
                                // Fall back to URL scheme method
                                self.shareVideoFallback(videoURL: videoURL, caption: caption, hashtags: hashtags, completion: completion)
                            }
                        } else {
                            print("❌ TikTok SDK: Invalid response type")
                            self.shareVideoFallback(videoURL: videoURL, caption: caption, hashtags: hashtags, completion: completion)
                        }
                    }
                }
                
                if !sendSuccess {
                    print("❌ TikTok SDK: Failed to send request")
                    self.shareVideoFallback(videoURL: videoURL, caption: caption, hashtags: hashtags, completion: completion)
                }
                }
            }
        }
    }
    
    /// Direct SDK integration for images using PHAsset with proper threading
    private func shareImageDirectSDK(image: UIImage, caption: String? = nil, hashtags: [String]? = nil, completion: @escaping (Bool) -> Void) {
        
        // Must run PHPhotoLibrary operations on main thread
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // Request photo library permission if needed
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if status == .notDetermined {
                let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized
                guard granted else {
                    print("❌ Photo library permission denied")
                    completion(false)
                    return
                }
            } else if status != .authorized && status != .limited {
                print("❌ Photo library permission not granted")
                completion(false)
                return
            }
            
            // Save image and get PHAsset
            var localIdentifier: String?
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
            }) { success, error in
                Task { @MainActor in
                    guard success, let assetId = localIdentifier else {
                        print("❌ Failed to save image: \(error?.localizedDescription ?? "unknown")")
                        self.shareImageFallback(image: image, caption: caption, hashtags: hashtags, completion: completion)
                        return
                    }
                
                print("✅ Image saved with identifier: \(assetId)")
                
                // Create TikTok share request
                let shareRequest = TikTokShareRequest(localIdentifiers: [assetId], mediaType: .image, redirectURI: "snapchef://tiktok-callback")
                
                // Send the request
                let sendSuccess = shareRequest.send { response in
                    Task { @MainActor in
                        if let shareResponse = response as? TikTokShareResponse {
                            if shareResponse.errorCode == .noError {
                                print("✅ TikTok SDK: Successfully shared image")
                                completion(true)
                            } else {
                                print("❌ TikTok SDK: Share failed - \(shareResponse.errorCode.rawValue)")
                                // Fall back to URL scheme method
                                self.shareImageFallback(image: image, caption: caption, hashtags: hashtags, completion: completion)
                            }
                        } else {
                            print("❌ TikTok SDK: Invalid response type")
                            self.shareImageFallback(image: image, caption: caption, hashtags: hashtags, completion: completion)
                        }
                    }
                }
                
                if !sendSuccess {
                    print("❌ TikTok SDK: Failed to send request")
                    self.shareImageFallback(image: image, caption: caption, hashtags: hashtags, completion: completion)
                }
                }
            }
        }
    }
    #endif
    
    /// Fallback method if SDK is not available
    private func shareVideoFallback(videoURL: URL, caption: String? = nil, hashtags: [String]? = nil, completion: @escaping (Bool) -> Void) {
        // Save video using SafeVideoSaver
        SafeVideoSaver.shared.saveVideoToPhotoLibrary(videoURL) { [weak self] success, error in
            guard success else {
                print("❌ Failed to save video: \(error ?? "unknown")")
                completion(false)
                return
            }
            
            print("✅ Video saved to photo library")
            
            // Prepare caption for clipboard
            self?.prepareCaptionForClipboard(caption: caption, hashtags: hashtags)
            
            // Open TikTok with the best available method
            self?.openTikTokForSharing { opened in
                completion(opened)
            }
        }
    }
    
    /// Share image to TikTok
    func shareImage(image: UIImage, caption: String? = nil, hashtags: [String]? = nil, completion: @escaping (Bool) -> Void) {
        
        // Prepare caption with hashtags for clipboard
        prepareCaptionForClipboard(caption: caption, hashtags: hashtags)
        
        #if canImport(TikTokOpenShareSDK)
        // Try direct SDK integration with proper threading
        shareImageDirectSDK(image: image, caption: caption, hashtags: hashtags, completion: completion)
        #else
        // Fallback if SDK not available
        shareImageFallback(image: image, caption: caption, hashtags: hashtags, completion: completion)
        #endif
    }
    
    /// Fallback method for image sharing if SDK is not available
    private func shareImageFallback(image: UIImage, caption: String? = nil, hashtags: [String]? = nil, completion: @escaping (Bool) -> Void) {
        // Save image using SafePhotoSaver
        SafePhotoSaver.shared.saveImageToPhotoLibrary(image) { [weak self] success, error in
            guard success else {
                print("❌ Failed to save image: \(error ?? "unknown")")
                completion(false)
                return
            }
            
            print("✅ Image saved to photo library")
            
            // Prepare caption for clipboard
            self?.prepareCaptionForClipboard(caption: caption, hashtags: hashtags)
            
            // Open TikTok with the best available method
            self?.openTikTokForSharing { opened in
                completion(opened)
            }
        }
    }
    
    private func prepareCaptionForClipboard(caption: String?, hashtags: [String]?) {
        var fullCaption = caption ?? ""
        
        if let hashtags = hashtags {
            let hashtagString = hashtags.map { tag in
                tag.hasPrefix("#") ? tag : "#\(tag)"
            }.joined(separator: " ")
            
            if !fullCaption.isEmpty {
                fullCaption += "\n\n"
            }
            fullCaption += hashtagString
        }
        
        fullCaption += "\n\n🍳 Made with @snapchef"
        UIPasteboard.general.string = fullCaption
        print("📋 Caption copied to clipboard")
    }
    
    private func openTikTokForSharing(completion: @escaping (Bool) -> Void) {
        // URL schemes to try in priority order
        let schemes = [
            "snssdk1233://studio/publish",      // Direct to publish studio
            "tiktok://studio/publish",           // Alternative publish
            "snssdk1233://create?media=library", // Create with library
            "tiktok://create?media=library",     // Alternative create with library
            "snssdk1233://create",               // Create screen
            "tiktok://create",                   // Alternative create
            "snssdk1233://",                     // Main app
            "tiktok://"                          // Alternative main
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
            UIApplication.shared.open(url) { success in
                if success {
                    print("✅ Successfully opened TikTok")
                    self.showInstructions()
                    completion(true)
                } else {
                    print("❌ Failed to open TikTok")
                    completion(false)
                }
            }
        } else {
            print("❌ TikTok is not installed")
            completion(false)
        }
    }
    
    private func showInstructions() {
        // This could be enhanced to show a toast or notification
        print("""
        
        📱 TikTok Instructions:
        1. Select your video/photo from the gallery (most recent)
        2. Paste the caption from your clipboard
        3. Edit and share your creation!
        
        """)
    }
}