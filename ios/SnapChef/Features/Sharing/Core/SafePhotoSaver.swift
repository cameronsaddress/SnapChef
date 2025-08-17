//
//  SafePhotoSaver.swift
//  SnapChef
//
//  Alternative photo saving approach without importing Photos framework
//

import UIKit

@MainActor
class SafePhotoSaver: NSObject {
    static let shared = SafePhotoSaver()

    private var completion: ((Bool, String?) -> Void)?

    override private init() {
        super.init()
    }

    func saveImageToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        self.completion = completion

        // This method should trigger the permission dialog if needed
        UIImageWriteToSavedPhotosAlbum(
            image,
            self,
            #selector(image(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }

    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
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
        }
    }
}
