import SwiftUI
@preconcurrency import AVFoundation
import UIKit
import CoreMedia

@MainActor
class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer?
    @Published var isCameraAuthorized = false
    @Published var currentPosition: AVCaptureDevice.Position = .back
    
    private var photoCompletion: ((UIImage) -> Void)?
    
    nonisolated override init() {
        super.init()
        Task { @MainActor in
            checkCameraPermission()
        }
    }
    
    func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { [weak self] in
                self?.isCameraAuthorized = true
                self?.setupCamera()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isCameraAuthorized = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.isCameraAuthorized = false
            }
        @unknown default:
            break
        }
    }
    
    private func checkCameraPermission() {
        let authorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        DispatchQueue.main.async { [weak self] in
            self?.isCameraAuthorized = authorized
        }
    }
    
    func setupCamera() {
        session.beginConfiguration()
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        
        // Setup camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
            session.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
                // Use maxPhotoDimensions for iOS 16+
                if #available(iOS 16.0, *) {
                    output.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024) // iPhone default max
                }
                output.maxPhotoQualityPrioritization = .quality
            }
            
            session.commitConfiguration()
            
            // Start session on background queue
            let captureSession = session
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
            
        } catch {
            print("Camera setup error: \(error)")
            session.commitConfiguration()
        }
    }
    
    func flipCamera() {
        HapticManager.impact(.light)
        
        currentPosition = currentPosition == .back ? .front : .back
        setupCamera()
    }
    
    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        photoCompletion = completion
        
        // High quality settings - use HEVC if available
        let settings: AVCapturePhotoSettings
        if output.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }
        settings.flashMode = .off
        
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func stopSession() {
        let captureSession = session
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error)")
            // Create a fallback image for simulator
            #if targetEnvironment(simulator)
            Task { @MainActor in
                if let fallbackImage = self.createFallbackImage() {
                    self.photoCompletion?(fallbackImage)
                    self.photoCompletion = nil
                }
            }
            #endif
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to get image data from photo")
            return
        }
        
        // Process image (resize if needed)
        let processedImage = processImage(image)
        
        Task { @MainActor in
            self.photoCompletion?(processedImage)
            self.photoCompletion = nil
        }
    }
    
    nonisolated private func createFallbackImage() -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Draw gradient
        let colors = [UIColor.systemTeal.cgColor, UIColor.systemBlue.cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    nonisolated private func processImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1920
        
        let width = image.size.width
        let height = image.size.height
        
        // Check if resizing is needed
        if width <= maxDimension && height <= maxDimension {
            return image
        }
        
        // Calculate new size
        let ratio = width > height ? maxDimension / width : maxDimension / height
        let newSize = CGSize(width: width * ratio, height: height * ratio)
        
        // Resize image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraModel: CameraModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraModel.session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        Task { @MainActor in
            cameraModel.preview = previewLayer
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}