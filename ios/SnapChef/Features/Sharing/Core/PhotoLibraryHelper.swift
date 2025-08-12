//
//  PhotoLibraryHelper.swift
//  SnapChef
//
//  Safe wrapper for photo library operations to prevent crashes
//

import UIKit
import Photos

@MainActor
class PhotoLibraryHelper {
    static let shared = PhotoLibraryHelper()
    
    private init() {}
    
    func requestPermissionAndSaveImage(_ image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.requestPermissionAndSaveImage(image, completion: completion)
            }
            return
        }
        
        // Check if Photos framework is available
        guard NSClassFromString("PHPhotoLibrary") != nil else {
            completion(false, "Photo library not available")
            return
        }
        
        // Use iOS 14+ API if available
        if #available(iOS 14.0, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized, .limited:
                        self.performSave(image, completion: completion)
                    case .denied:
                        completion(false, "Photo library access denied. Please go to Settings > Privacy & Security > Photos and allow SnapChef to add photos.")
                    case .restricted:
                        completion(false, "Photo library access is restricted on this device.")
                    case .notDetermined:
                        completion(false, "Unable to determine photo library permission status.")
                    @unknown default:
                        completion(false, "Unable to access photo library.")
                    }
                }
            }
        } else {
            // Fallback for iOS 13 and earlier
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self.performSave(image, completion: completion)
                    } else {
                        completion(false, "Photo library access denied. Please enable in Settings.")
                    }
                }
            }
        }
    }
    
    private func performSave(_ image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true, nil)
                } else {
                    completion(false, error?.localizedDescription ?? "Failed to save image")
                }
            }
        }
    }
}