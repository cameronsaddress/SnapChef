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

// MARK: - Shared Studio Camera Components

struct ConditionalParticleExplosion: ViewModifier {
    @Binding var trigger: Bool
    let enabled: Bool
    
    func body(content: Content) -> some View {
        if enabled {
            content.particleExplosion(trigger: $trigger)
        } else {
            content
        }
    }
}

struct StudioOptimizedScanningOverlay: View {
    @Binding var scanLineOffset: CGFloat
    @EnvironmentObject var deviceManager: DeviceManager

    var body: some View {
        if deviceManager.shouldUseContinuousAnimations {
            ScanningOverlay(scanLineOffset: $scanLineOffset)
        } else {
            GeometryReader { _ in
                ZStack {
                    VStack {
                        HStack {
                            StudioScanCorner(position: .topLeft)
                            Spacer()
                            StudioScanCorner(position: .topRight)
                        }
                        Spacer()
                        HStack {
                            StudioScanCorner(position: .bottomLeft)
                            Spacer()
                            StudioScanCorner(position: .bottomRight)
                        }
                    }
                    .padding(40)

                    VStack {
                        Spacer()
                        Text("Position ingredients in frame")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.55))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        Spacer()
                            .frame(height: 210)
                    }
                }
            }
        }
    }
}

struct StudioScanCorner: View {
    enum Position {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    let position: Position

    var body: some View {
        Path { path in
            let cornerSize: CGFloat = 22
            switch position {
            case .topLeft:
                path.move(to: CGPoint(x: cornerSize, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: cornerSize))
            case .topRight:
                path.move(to: CGPoint(x: -cornerSize, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: cornerSize))
            case .bottomLeft:
                path.move(to: CGPoint(x: 0, y: -cornerSize))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: cornerSize, y: 0))
            case .bottomRight:
                path.move(to: CGPoint(x: 0, y: -cornerSize))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: -cornerSize, y: 0))
            }
        }
        .stroke(Color.white, lineWidth: 3)
        .frame(width: 22, height: 22)
    }
}

struct StudioCameraTopBar: View {
    let captureMode: CameraView.CaptureMode
    let isSessionReady: Bool
    let flashIcon: String
    let onClose: () -> Void
    let onFlipCamera: () -> Void
    let onToggleFlash: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                studioCircleButton(icon: "xmark", action: onClose)

                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(isSessionReady ? Color(hex: "#43e97b") : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(captureModeTitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )

                Spacer()

                HStack(spacing: 10) {
                    studioCircleButton(icon: flashIcon, action: onToggleFlash)
                    studioCircleButton(icon: "camera.rotate.fill", action: onFlipCamera)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 58)
        }
    }

    private var captureModeTitle: String {
        switch captureMode {
        case .fridge:
            return "Fridge Scan"
        case .pantry:
            return "Pantry Add-On"
        }
    }

    private func studioCircleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.42))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(StudioSpringButtonStyle(pressedScale: 0.92, pressedYOffset: 1.2, activeRotation: 1.5))
    }
}

struct StudioCameraBottomDock: View {
    let captureMode: CameraView.CaptureMode
    let isSessionReady: Bool
    let isProcessing: Bool
    let fridgePhoto: UIImage?
    @Binding var triggerAnimation: Bool
    let onCapture: () -> Void
    let onDebugTest: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Text(primaryLine)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(secondaryLine)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if captureMode == .pantry, let fridgePhoto {
                    HStack(spacing: 8) {
                        Image(uiImage: fridgePhoto)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("Fridge captured")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.42))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, 20)

            CaptureButtonEnhanced(
                action: onCapture,
                isDisabled: isProcessing || !isSessionReady,
                triggerAnimation: $triggerAnimation
            )

            #if DEBUG
            Button(action: onDebugTest) {
                Label("Run Test Capture", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.9))
                    )
            }
            .buttonStyle(.plain)
            #endif
        }
        .padding(.bottom, 46)
    }

    private var primaryLine: String {
        if !isSessionReady {
            return "Initializing camera..."
        }
        switch captureMode {
        case .fridge:
            return "Capture your fridge"
        case .pantry:
            return "Add pantry for smarter recipes"
        }
    }

    private var secondaryLine: String {
        switch captureMode {
        case .fridge:
            return "Fill the frame with ingredients for best detection."
        case .pantry:
            return "Optional second photo for better substitutions and pairings."
        }
    }
}

struct StudioCameraWelcomeOverlay: View {
    var body: some View {
        VStack {
            Text("Welcome to SnapChef Studio")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color(hex: "#4facfe").opacity(0.84))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                )
                .shadow(color: Color(hex: "#4facfe").opacity(0.42), radius: 12, y: 6)
                .padding(.top, 120)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}
