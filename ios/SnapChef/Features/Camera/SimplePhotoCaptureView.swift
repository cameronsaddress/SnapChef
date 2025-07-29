import SwiftUI
import AVFoundation

struct SimplePhotoCaptureView: View {
    @StateObject private var cameraModel = CameraModel()
    @Environment(\.dismiss) var dismiss
    let onCapture: (UIImage) -> Void
    
    @State private var capturedImage: UIImage?
    @State private var showingPreview = false
    @State private var captureAnimation = false
    @State private var scanLineOffset: CGFloat = -200
    @State private var glowIntensity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Camera preview (bottom layer)
            if cameraModel.isCameraAuthorized {
                CameraPreview(cameraModel: cameraModel)
                    .ignoresSafeArea()
                    .opacity(cameraModel.isSessionReady ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: cameraModel.isSessionReady)
            } else {
                // Fallback background when camera not available
                MagicalBackground()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.3))
            }
            
            // Scanning overlay
            if !showingPreview {
                ScanningOverlay(scanLineOffset: $scanLineOffset)
                    .ignoresSafeArea()
            }
            
            // UI overlay
            if !showingPreview {
                VStack {
                    // Top bar with custom title
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.white, Color.white.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .blur(radius: 10)
                                )
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text("After Photo")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Show your masterpiece!")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        // Balance spacer
                        Color.clear
                            .frame(width: 32, height: 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.6), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 150)
                        .ignoresSafeArea()
                    )
                    
                    Spacer()
                    
                    // Bottom controls
                    CameraControlsEnhanced(
                        cameraModel: cameraModel,
                        capturePhoto: capturePhoto,
                        isProcessing: false,
                        captureAnimation: $captureAnimation
                    )
                }
            }
            
            // Captured image preview
            if showingPreview, let image = capturedImage {
                CapturedImageView(
                    image: image,
                    onRetake: {
                        showingPreview = false
                        capturedImage = nil
                    },
                    onConfirm: {
                        onCapture(image)
                        dismiss()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 1.1)))
            }
        }
        .onAppear {
            startScanAnimation()
            // Request permission and setup camera with delay
            Task {
                // Small delay to ensure view is fully loaded
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                await MainActor.run {
                    cameraModel.requestCameraPermission()
                }
            }
        }
        .onDisappear {
            cameraModel.stopSession()
        }
    }
    
    private func startScanAnimation() {
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
            scanLineOffset = 200
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
    }
    
    private func capturePhoto() {
        // Trigger capture animation
        captureAnimation = true
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        cameraModel.capturePhoto { image in
            capturedImage = image
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingPreview = true
            }
        }
    }
}