import SwiftUI
import AVFoundation
import Photos

/// Simplified camera view specifically for capturing meal/after photos
struct MealPhotoCameraView: View {
    @Binding var afterPhoto: UIImage?
    let recipeID: UUID
    @Environment(\.dismiss) var dismiss
    @StateObject private var cameraModel = CameraModel()
    @State private var capturedImage: UIImage?
    @State private var showingPreview = false
    @State private var captureAnimation = false
    
    var flashIcon: String {
        switch cameraModel.flashMode {
        case .off:
            return "bolt.slash.fill"
        case .on:
            return "bolt.fill"
        case .auto:
            return "bolt.badge.automatic.fill"
        @unknown default:
            return "bolt.slash.fill"
        }
    }
    
    var body: some View {
        ZStack {
            // Camera preview
            if cameraModel.isCameraAuthorized {
                CameraPreview(cameraModel: cameraModel)
                    .ignoresSafeArea()
                    .opacity(cameraModel.isSessionReady ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: cameraModel.isSessionReady)
            } else {
                // Fallback when camera not available
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 20) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                            Text("Camera access required")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                            Button("Open Settings") {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                    )
            }
            
            // UI Overlay
            if !showingPreview {
                VStack {
                    // Top bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        
                        Spacer()
                        
                        Text("Capture Your Dish")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                        
                        Spacer()
                        
                        // Flash button
                        Button(action: {
                            cameraModel.toggleFlash()
                        }) {
                            Image(systemName: flashIcon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // Bottom controls
                    HStack(spacing: 60) {
                        // Photo library button
                        Button(action: openPhotoLibrary) {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                        }
                        
                        // Capture button
                        Button(action: capturePhoto) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 80, height: 80)
                                
                                if captureAnimation {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 80, height: 80)
                                        .scaleEffect(1.3)
                                        .opacity(0)
                                        .animation(.easeOut(duration: 0.3), value: captureAnimation)
                                }
                            }
                        }
                        .disabled(!cameraModel.isSessionReady)
                        
                        // Camera flip button
                        Button(action: {
                            cameraModel.flipCamera()
                        }) {
                            Image(systemName: "camera.rotate")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            
            // Preview overlay
            if showingPreview, let image = capturedImage {
                ZStack {
                    // Black background
                    Color.black.ignoresSafeArea()
                    
                    // Full screen photo with proper aspect ratio
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea()
                    
                    // Bottom controls overlay
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 30) {
                            // Retake button
                            Button(action: retakePhoto) {
                                Text("Retake")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.5))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            
                            // Use Photo button
                            Button(action: usePhoto) {
                                Text("Use Photo")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .background(
                                        Capsule()
                                            .fill(LinearGradient(
                                                colors: [Color(hex: "#4facfe"), Color(hex: "#00f2fe")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                    )
                                    .shadow(color: Color(hex: "#4facfe").opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                        }
                        .padding(.bottom, 50)
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            cameraModel.requestCameraPermission()
            shouldShowFullUI()
        }
        .onDisappear {
            cameraModel.stopSession()
        }
    }
    
    private func shouldShowFullUI() {
        // Delay UI loading for better initial performance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                // Any additional UI setup if needed
            }
        }
    }
    
    private func capturePhoto() {
        // Trigger animation
        withAnimation(.easeOut(duration: 0.3)) {
            captureAnimation = true
        }
        
        // Reset animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            captureAnimation = false
        }
        
        // Capture the photo
        cameraModel.capturePhoto { image in
            self.capturedImage = image
            withAnimation {
                self.showingPreview = true
            }
        }
    }
    
    private func retakePhoto() {
        withAnimation {
            showingPreview = false
            capturedImage = nil
        }
    }
    
    private func usePhoto() {
        if let image = capturedImage {
            afterPhoto = image
            dismiss()
        }
    }
    
    private func openPhotoLibrary() {
        // Request photo library permission
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // Photo library access would be handled by a photo picker
                // For now, just dismiss
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        }
    }
}