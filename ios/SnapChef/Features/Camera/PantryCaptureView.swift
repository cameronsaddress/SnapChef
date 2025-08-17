import SwiftUI
import AVFoundation

struct PantryCaptureView: View {
    @StateObject private var cameraModel = CameraModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    // Binding to the fridge photo from the previous step
    @Binding var fridgePhoto: UIImage?

    // Navigation callbacks
    let onPantryPhotoCaptured: (UIImage, UIImage) -> Void // (fridgePhoto, pantryPhoto)
    let onSkip: (UIImage) -> Void // Only fridge photo
    let onBack: () -> Void

    @State private var isProcessing = false
    @State private var capturedPantryImage: UIImage?
    @State private var showingPreview = false
    @State private var captureAnimation = false
    @State private var scanLineOffset: CGFloat = -200

    var body: some View {
        ZStack {
            // Camera preview (bottom layer)
            if cameraModel.isCameraAuthorized && !isProcessing {
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
            if !isProcessing && !showingPreview {
                PantryScanningOverlay(scanLineOffset: $scanLineOffset)
                    .ignoresSafeArea()
            }

            // UI overlay
            if !showingPreview {
                VStack {
                    // Top bar with progress
                    PantryCaptureTopBar(onBack: onBack)

                    Spacer()

                    // Header and instructions
                    VStack(spacing: 20) {
                        // Main header
                        VStack(spacing: 8) {
                            Text("Got a pantry too? 🥫")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("Add pantry items for even better recipes!")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        // Camera instructions
                        if cameraModel.isSessionReady {
                            Text("Point at your pantry, cabinets, or spice rack")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        } else {
                            Text("Initializing camera...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    // Bottom controls
                    VStack(spacing: 30) {
                        // Primary capture button
                        PantryCaptureButton(
                            action: capturePhoto,
                            isDisabled: isProcessing || !cameraModel.isSessionReady,
                            triggerAnimation: $captureAnimation
                        )

                        // Secondary actions
                        HStack(spacing: 40) {
                            // Skip button
                            Button(action: {
                                guard let fridgePhoto = fridgePhoto else { return }
                                HapticManager.impact(.light)
                                onSkip(fridgePhoto)
                            }) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 60, height: 60)

                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.white)
                                    }

                                    Text("Skip")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .disabled(isProcessing)
                            .opacity(isProcessing ? 0.5 : 1)

                            Spacer()

                            // Back button
                            Button(action: {
                                HapticManager.impact(.light)
                                onBack()
                            }) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 60, height: 60)

                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.white)
                                    }

                                    Text("Back")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .disabled(isProcessing)
                            .opacity(isProcessing ? 0.5 : 1)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }

            // Captured image preview
            if showingPreview, let image = capturedPantryImage {
                PantryCapturedImageView(
                    fridgePhoto: fridgePhoto,
                    pantryPhoto: image,
                    onRetake: {
                        showingPreview = false
                        capturedPantryImage = nil
                    },
                    onConfirm: {
                        guard let fridgePhoto = fridgePhoto else { return }
                        showingPreview = false
                        onPantryPhotoCaptured(fridgePhoto, image)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 1.1)))
            }
        }
        .onAppear {
            startScanAnimation()

            // Request permission and setup camera
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                await MainActor.run {
                    cameraModel.requestCameraPermission()
                }
            }
        }
        .onDisappear {
            cameraModel.stopSession()
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func startScanAnimation() {
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
            scanLineOffset = 200
        }
    }

    private func capturePhoto() {
        // Trigger capture animation
        captureAnimation = true

        // Haptic feedback
        HapticManager.impact(.heavy)

        cameraModel.capturePhoto { image in
            capturedPantryImage = image
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingPreview = true
            }
        }
    }
}

// MARK: - Pantry Capture Top Bar
struct PantryCaptureTopBar: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                // Back button
                Button(action: onBack) {
                    ZStack {
                        BlurredCircle()

                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                }

                Spacer()

                // Progress indicator
                HStack(spacing: 12) {
                    // Step 1 (completed)
                    Circle()
                        .fill(Color(hex: "#43e97b"))
                        .frame(width: 12, height: 12)

                    // Connecting line
                    Rectangle()
                        .fill(Color(hex: "#43e97b"))
                        .frame(width: 30, height: 2)

                    // Step 2 (current)
                    Circle()
                        .fill(Color(hex: "#43e97b"))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 20, height: 20)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )

                Spacer()
            }

            // Step indicator text
            Text("Step 2 of 2")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
}

// MARK: - Pantry Scanning Overlay
struct PantryScanningOverlay: View {
    @Binding var scanLineOffset: CGFloat
    @State private var cornerAnimation = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Corner brackets - orange/yellow theme for pantry
                ForEach(0..<4) { index in
                    CornerBracket(corner: index)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#f093fb"),
                                    Color(hex: "#f5af19")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 60, height: 60)
                        .position(cornerPosition(for: index, in: geometry.size))
                        .scaleEffect(cornerAnimation ? 1.1 : 1)
                        .opacity(cornerAnimation ? 0.8 : 1)
                }

                // Scanning line - warm theme
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color(hex: "#f093fb").opacity(0.5),
                                Color(hex: "#f5af19"),
                                Color(hex: "#f093fb").opacity(0.5),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .blur(radius: 1)
                    .offset(y: scanLineOffset)

                // Center focus - pantry icon
                Image(systemName: "cabinet")
                    .font(.system(size: 100, weight: .ultraLight))
                    .foregroundColor(Color.white.opacity(0.1))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                cornerAnimation = true
            }
        }
    }

    private func cornerPosition(for index: Int, in size: CGSize) -> CGPoint {
        let padding: CGFloat = 60
        switch index {
        case 0: return CGPoint(x: padding, y: padding)
        case 1: return CGPoint(x: size.width - padding, y: padding)
        case 2: return CGPoint(x: padding, y: size.height - padding)
        case 3: return CGPoint(x: size.width - padding, y: size.height - padding)
        default: return .zero
        }
    }
}

// MARK: - Pantry Capture Button
struct PantryCaptureButton: View {
    let action: () -> Void
    let isDisabled: Bool
    @Binding var triggerAnimation: Bool

    @State private var isPressed = false
    @State private var ringScale: CGFloat = 1

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring with animation - green theme
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#43e97b"),
                                Color(hex: "#38f9d7")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(ringScale)
                    .opacity(triggerAnimation ? 0 : 1)

                // Inner circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#43e97b"),
                                Color(hex: "#38f9d7")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 85, height: 85)
                    .scaleEffect(isPressed ? 0.9 : 1)
                    .shadow(
                        color: Color(hex: "#43e97b").opacity(0.5),
                        radius: 15,
                        y: 5
                    )

                // Center text
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)

                    Text("Capture")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(isDisabled)
        .scaleEffect(isPressed ? 0.95 : 1)
        .opacity(isDisabled ? 0.5 : 1)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onChange(of: triggerAnimation) { _ in
            if triggerAnimation {
                withAnimation(.easeOut(duration: 0.6)) {
                    ringScale = 1.5
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    triggerAnimation = false
                    ringScale = 1
                }
            }
        }
    }
}

// MARK: - Pantry Captured Image View
struct PantryCapturedImageView: View {
    let fridgePhoto: UIImage?
    let pantryPhoto: UIImage
    let onRetake: () -> Void
    let onConfirm: () -> Void
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Full screen image
            Image(uiImage: pantryPhoto)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()

            // Dark overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // UI Overlay
            VStack {
                // Top bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Review Pantry Photo")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Perfect! Now you have both photos")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                // Photo thumbnails
                if let fridgePhoto = fridgePhoto {
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Image(uiImage: fridgePhoto)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#4facfe"), lineWidth: 2)
                                )

                            Text("Fridge")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        VStack(spacing: 8) {
                            Image(uiImage: pantryPhoto)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#43e97b"), lineWidth: 2)
                                )

                            Text("Pantry")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.8)
                }

                Spacer()

                // Bottom controls
                VStack(spacing: 20) {
                    Text("Ready to create amazing recipes?")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.8)

                    HStack(spacing: 40) {
                        // Retake button
                        Button(action: onRetake) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 70, height: 70)

                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(.white)
                                }

                                Text("Retake")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.8)

                        // Confirm button
                        Button(action: onConfirm) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(hex: "#43e97b"),
                                                    Color(hex: "#38f9d7")
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 100, height: 100)
                                        .shadow(
                                            color: Color(hex: "#43e97b").opacity(0.5),
                                            radius: 20,
                                            y: 10
                                        )

                                    VStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(.white)

                                        Text("Create")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }

                                Text("Generate Recipes")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.8)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
    }
}

#Preview {
    PantryCaptureView(
        fridgePhoto: .constant(UIImage(systemName: "photo")!),
        onPantryPhotoCaptured: { _, _ in },
        onSkip: { _ in },
        onBack: {}
    )
    .environmentObject(AppState())
}
