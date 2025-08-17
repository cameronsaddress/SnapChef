//
//  SafeVideoSaver.swift
//  SnapChef
//
//  Safe video saving without importing Photos framework
//

import UIKit

@MainActor
class SafeVideoSaver: NSObject {
    static let shared = SafeVideoSaver()

    private var completion: ((Bool, String?) -> Void)?
    private var videoPath: String?

    override private init() {
        super.init()
    }

    func saveVideoToPhotoLibrary(_ videoURL: URL, completion: @escaping (Bool, String?) -> Void) {
        // Check if video file exists
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            completion(false, "Video file not found")
            return
        }

        // Check if the video is compatible with the photo library
        guard UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(videoURL.path) else {
            completion(false, "Video format is not compatible with photo library")
            return
        }

        self.completion = completion
        self.videoPath = videoURL.path

        // This method should trigger the permission dialog if needed
        UISaveVideoAtPathToSavedPhotosAlbum(
            videoURL.path,
            self,
            #selector(video(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }

    @objc private func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer?) {
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                // Check if it's a permission error
                let nsError = error as NSError
                if nsError.code == -3_310 { // ALAssetsLibraryDataUnavailableError
                    self?.completion?(false, "Photo library access denied. Please go to Settings > Privacy & Security > Photos and allow SnapChef to add photos.")
                } else {
                    self?.completion?(false, error.localizedDescription)
                }
            } else {
                self?.completion?(true, nil)
            }
            self?.completion = nil
            self?.videoPath = nil
        }
    }
}
