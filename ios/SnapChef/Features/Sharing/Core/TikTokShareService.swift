//
//  TikTokShareService.swift
//  SnapChef
//
//  TikTok Viral Content Generation - ShareService & SDK Integration
//  Following EXACT specifications from TIKTOK_VIRAL_COMPLETE_REQUIREMENTS.md
//

import Foundation
import UIKit
import Photos

// Helper class for thread-safe mutable capture
private final class Box<T>: @unchecked Sendable {
    var value: T
    init(value: T) {
        self.value = value
    }
}

// Import TikTok SDK components
#if canImport(TikTokOpenSDKCore)
import TikTokOpenSDKCore
#endif

#if canImport(TikTokOpenShareSDK)
import TikTokOpenShareSDK
#endif

// MARK: - Share Errors (EXACT SPECIFICATION)
enum TikTokShareError: Error, LocalizedError {
    case photoAccessDenied
    case saveFailed
    case fetchFailed
    case tiktokNotInstalled
    case shareFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .photoAccessDenied:
            return "Photo library access denied. Please enable it in Settings."
        case .saveFailed:
            return "Failed to save video to Photos"
        case .fetchFailed:
            return "Failed to fetch PHAssets from photo library"
        case .tiktokNotInstalled:
            return "TikTok is not installed on this device"
        case .shareFailed(let message):
            return "Share failed: \(message)"
        }
    }
}

// MARK: - TikTokShareService (EXACT SPECIFICATION)
enum TikTokShareService {
    
    // MARK: - Photo Permission Handling
    
    /// Request photo library permission (EXACT SPECIFICATION)
    static func requestPhotoPermission(_ completion: @escaping @Sendable (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            completion(true)
        case .denied, .restricted:
            completion(false)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
        @unknown default:
            completion(false)
        }
    }
    
    // MARK: - Save to Photos with LocalIdentifier (EXACT SPECIFICATION)
    
    /// Save video to Photos and return PHAsset localIdentifier (EXACT SPECIFICATION)
    static func saveToPhotos(videoURL: URL, completion: @escaping @Sendable (Result<String, TikTokShareError>) -> Void) {
        requestPhotoPermission { granted in
            guard granted else {
                completion(.failure(.photoAccessDenied))
                return
            }
            
            // Use a thread-safe container for the identifier
            let identifierBox = Box(value: nil as String?)
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                identifierBox.value = request?.placeholderForCreatedAsset?.localIdentifier
            }) { success, error in
                DispatchQueue.main.async {
                    if success, let identifier = identifierBox.value {
                        completion(.success(identifier))
                    } else {
                        print("❌ Failed to save video: \(error?.localizedDescription ?? "Unknown error")")
                        completion(.failure(.saveFailed))
                    }
                }
            }
        }
    }
    
    // MARK: - Fetch Assets (EXACT SPECIFICATION)
    
    /// Fetch PHAssets using localIdentifiers (EXACT SPECIFICATION)
    static func fetchAssets(localIdentifiers: [String]) -> [PHAsset] {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        var assets: [PHAsset] = []
        
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        return assets
    }
    
    // MARK: - TikTok Share (EXACT SPECIFICATION)
    
    /// Share to TikTok using localIdentifiers and caption (EXACT SPECIFICATION)
    static func shareToTikTok(
        localIdentifiers: [String], 
        caption: String?, 
        completion: @escaping @Sendable (Result<Void, TikTokShareError>) -> Void
    ) {
        DispatchQueue.main.async {
            // Check TikTok installation
            guard isTikTokInstalled() else {
                completion(.failure(.tiktokNotInstalled))
                return
            }
            
            // Copy caption to clipboard for user to paste
            if let caption = caption {
                UIPasteboard.general.string = caption
                print("📋 Caption copied to clipboard: \(caption)")
            }
            
            #if canImport(TikTokOpenShareSDK)
            // Use TikTok SDK if available
            shareWithTikTokSDK(localIdentifiers: localIdentifiers, completion: completion)
            #else
            // Fallback to URL scheme
            shareWithTikTokURLScheme(completion: completion)
            #endif
        }
    }
    
    // MARK: - Private TikTok SDK Implementation
    
    #if canImport(TikTokOpenShareSDK)
    private static func shareWithTikTokSDK(
        localIdentifiers: [String], 
        completion: @escaping @Sendable (Result<Void, TikTokShareError>) -> Void
    ) {
        // Fetch assets
        let assets = fetchAssets(localIdentifiers: localIdentifiers)
        guard !assets.isEmpty else {
            completion(.failure(.fetchFailed))
            return
        }
        
        // Create TikTok share request with required parameters
        let shareRequest = TikTokShareRequest(
            localIdentifiers: localIdentifiers,
            mediaType: .video,
            redirectURI: "snapchef://tiktok-callback"
        )
        
        // Send share request
        let sendResult = shareRequest.send { response in
            // Extract data from response before entering Task
            let isSuccess: Bool
            let errorMessage: String?
            
            if let shareResponse = response as? TikTokShareResponse {
                isSuccess = (shareResponse.errorCode == .noError)
                errorMessage = shareResponse.errorDescription
            } else {
                isSuccess = false
                errorMessage = nil
            }
            
            Task { @MainActor in
                // Use the extracted data to avoid data race
                if isSuccess {
                    print("✅ TikTok share succeeded")
                    completion(.success(()))
                } else {
                    let message = errorMessage ?? "Unknown TikTok share error"
                    print("❌ TikTok share failed: \(message)")
                    completion(.failure(.shareFailed(message)))
                }
            }
        }
        
        // Check if send was successful
        if !sendResult {
            print("❌ Failed to send TikTok share request")
            completion(.failure(.shareFailed("Failed to send share request to TikTok")))
        }
    }
    #endif
    
    // MARK: - Private TikTok URL Scheme Fallback
    
    @MainActor
    private static func shareWithTikTokURLScheme(completion: @escaping @Sendable (Result<Void, TikTokShareError>) -> Void) {
        // Try different TikTok URL schemes in order of preference
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
        guard let url = urlToOpen else {
            completion(.failure(.shareFailed("No TikTok URL scheme available")))
            return
        }
        
        UIApplication.shared.open(url) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully opened TikTok")
                    completion(.success(()))
                } else {
                    completion(.failure(.shareFailed("Failed to open TikTok app")))
                }
            }
        }
    }
    
    // MARK: - TikTok Installation Check
    
    @MainActor
    private static func isTikTokInstalled() -> Bool {
        let schemes = ["tiktok://", "snssdk1233://", "snssdk1180://", "tiktokopensdk://"]
        
        for scheme in schemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Recipe Integration (Using Recipe struct from project)

extension TikTokShareService {
    
    /// Generate default caption from recipe title and time (EXACT SPECIFICATION)
    static func defaultCaption(title: String, timeMinutes: Int?, costDollars: Int? = nil) -> String {
        let mins = timeMinutes.map { "\($0) min" } ?? "quick"
        let cost = costDollars.map { "$\($0)" } ?? ""
        let tags = ["#FridgeGlowUp", "#BeforeAfter", "#DinnerHack", "#HomeCooking"].joined(separator: " ")
        
        return "\(title) — \(mins) \(cost)\nComment \"RECIPE\" for details 👇\n\(tags)"
    }
    
    /// Generate caption for recipe with customizable components
    static func generateCaption(
        title: String,
        timeMinutes: Int?,
        costDollars: Int?,
        customHashtags: [String]? = nil
    ) -> String {
        let mins = timeMinutes.map { "\($0) min" } ?? "quick"
        let cost = costDollars.map { "$\($0)" } ?? ""
        
        let defaultTags = ["#FridgeGlowUp", "#BeforeAfter", "#DinnerHack", "#HomeCooking"]
        let hashtags = customHashtags ?? defaultTags
        let tags = hashtags.joined(separator: " ")
        
        return "\(title) — \(mins) \(cost)\nComment \"RECIPE\" for details 👇\n\(tags)"
    }
}

// MARK: - End-to-End Share Pipeline (DEMONSTRATION)

extension TikTokShareService {
    
    /// Complete sharing pipeline from video render to TikTok share (EXACT SPECIFICATION)
    /// This demonstrates the exact flow specified in TIKTOK_VIRAL_COMPLETE_REQUIREMENTS.md
    static func shareRecipeToTikTok(
        videoURL: URL,
        recipeTitle: String,
        timeMinutes: Int?,
        completion: @escaping @Sendable (Result<Void, TikTokShareError>) -> Void
    ) {
        print("🎬 Starting complete TikTok share pipeline")
        
        // Step 1: Generate caption using exact specification
        let caption = defaultCaption(title: recipeTitle, timeMinutes: timeMinutes)
        print("📋 Generated caption: \(caption)")
        
        // Step 2: Save to Photos and get localIdentifier
        saveToPhotos(videoURL: videoURL) { saveResult in
            switch saveResult {
            case .success(let localIdentifier):
                print("✅ Video saved with localIdentifier: \(localIdentifier)")
                
                // Step 3: Share to TikTok with localIdentifier and caption
                shareToTikTok(localIdentifiers: [localIdentifier], caption: caption) { shareResult in
                    switch shareResult {
                    case .success():
                        print("✅ Complete TikTok share pipeline succeeded!")
                        completion(.success(()))
                    case .failure(let error):
                        print("❌ TikTok share failed: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                print("❌ Failed to save video: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Convenience method for sharing with custom caption
    static func shareRecipeToTikTok(
        videoURL: URL,
        customCaption: String,
        completion: @escaping @Sendable (Result<Void, TikTokShareError>) -> Void
    ) {
        print("🎬 Starting TikTok share with custom caption")
        print("📋 Custom caption: \(customCaption)")
        
        // Step 1: Save to Photos and get localIdentifier  
        saveToPhotos(videoURL: videoURL) { saveResult in
            switch saveResult {
            case .success(let localIdentifier):
                print("✅ Video saved with localIdentifier: \(localIdentifier)")
                
                // Step 2: Share to TikTok
                shareToTikTok(localIdentifiers: [localIdentifier], caption: customCaption) { shareResult in
                    switch shareResult {
                    case .success():
                        print("✅ TikTok share with custom caption succeeded!")
                        completion(.success(()))
                    case .failure(let error):
                        print("❌ TikTok share failed: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                print("❌ Failed to save video: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}