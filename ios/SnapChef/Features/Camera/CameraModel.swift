import SwiftUI
import AVFoundation
import UIKit
import CoreMedia

class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer?
    @Published var isCameraAuthorized = false
    @Published var currentPosition: AVCaptureDevice.Position = .back
    
    private var photoCompletion: ((UIImage) -> Void)?
    
    override init() {
        super.init()
        checkCameraPermission()
    }
    
    func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
            isCameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                        self?.isCameraAuthorized = true
                    }
                }
            }
        case .denied, .restricted:
            isCameraAuthorized = false
        @unknown default:
            break
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
        default:
            isCameraAuthorized = false
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
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
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
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }
        
        // Process image (resize if needed)
        let processedImage = processImage(image)
        
        DispatchQueue.main.async { [weak self] in
            self?.photoCompletion?(processedImage)
            self?.photoCompletion = nil
        }
    }
    
    private func processImage(_ image: UIImage) -> UIImage {
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
        
        cameraModel.preview = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}