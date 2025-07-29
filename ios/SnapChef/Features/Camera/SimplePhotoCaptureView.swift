import SwiftUI
import AVFoundation

struct SimplePhotoCaptureView: View {
    @StateObject private var cameraModel = CameraModel()
    @Environment(\.dismiss) var dismiss
    let onCapture: (UIImage) -> Void
    
    @State private var capturedImage: UIImage?
    @State private var showingPreview = false
    
    var body: some View {
        ZStack {
            // Camera preview
            if cameraModel.isCameraAuthorized {
                CameraPreview(cameraModel: cameraModel)
                    .ignoresSafeArea()
                    .opacity(showingPreview ? 0 : 1)
            } else {
                // Fallback background
                MagicalBackground()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.3))
            }
            
            // UI overlay
            if !showingPreview {
                VStack {
                    // Top bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding()
                        
                        Spacer()
                        
                        Text("Take After Photo")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Placeholder for balance
                        Color.clear
                            .frame(width: 32, height: 32)
                            .padding()
                    }
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
                    
                    // Capture button
                    VStack(spacing: 20) {
                        Text("Show your finished dish!")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .multilineTextAlignment(.center)
                        
                        Button(action: capturePhoto) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 80, height: 80)
                            }
                        }
                        .padding(.bottom, 50)
                    }
                    .background(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 200)
                        .ignoresSafeArea()
                    )
                }
            }
            
            // Preview overlay
            if showingPreview, let image = capturedImage {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: 30) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
                            .cornerRadius(20)
                            .shadow(radius: 20)
                        
                        HStack(spacing: 40) {
                            Button(action: retakePhoto) {
                                VStack(spacing: 8) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 24, weight: .medium))
                                    Text("Retake")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 80, height: 80)
                                )
                            }
                            
                            Button(action: usePhoto) {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 24, weight: .bold))
                                    Text("Use Photo")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.black)
                                .padding()
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 80, height: 80)
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            cameraModel.requestCameraPermission()
        }
    }
    
    private func capturePhoto() {
        cameraModel.capturePhoto { image in
            capturedImage = image
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingPreview = true
            }
        }
    }
    
    private func retakePhoto() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showingPreview = false
            capturedImage = nil
        }
    }
    
    private func usePhoto() {
        if let image = capturedImage {
            onCapture(image)
            dismiss()
        }
    }
}