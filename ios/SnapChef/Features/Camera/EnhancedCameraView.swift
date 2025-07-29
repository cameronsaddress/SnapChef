import SwiftUI
import AVFoundation

struct EnhancedCameraView: View {
    @StateObject private var cameraModel = CameraModel()
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.dismiss) var dismiss
    
    @State private var isProcessing = false
    @State private var showingResults = false
    @State private var generatedRecipes: [Recipe] = []
    @State private var capturedImage: UIImage?
    @State private var showingPreview = false
    @State private var captureAnimation = false
    @State private var scanLineOffset: CGFloat = -200
    @State private var glowIntensity: Double = 0.3
    @State private var showingUpgrade = false
    
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
            if !isProcessing && !showingPreview {
                ScanningOverlay(scanLineOffset: $scanLineOffset)
                    .ignoresSafeArea()
            }
            
            // UI overlay
            if !showingPreview {
                VStack {
                    // Top bar
                    CameraTopBar(dismiss: dismiss)
                    
                    Spacer()
                    
                    // Bottom controls
                    CameraControlsEnhanced(
                        cameraModel: cameraModel,
                        capturePhoto: capturePhoto,
                        isProcessing: isProcessing,
                        captureAnimation: $captureAnimation
                    )
                }
            }
            
            // Processing overlay
            if isProcessing {
                MagicalProcessingOverlay()
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
                        showingPreview = false
                        processImage(image)
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
        .fullScreenCover(isPresented: $showingResults) {
            EnhancedRecipeResultsView(
                recipes: generatedRecipes,
                capturedImage: capturedImage
            )
        }
        .fullScreenCover(isPresented: $showingUpgrade) {
            SubscriptionView()
                .environmentObject(deviceManager)
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
    
    private func processImage(_ image: UIImage) {
        isProcessing = true
        capturedImage = image // Store the captured image
        
        Task {
            // Check if user has free uses or subscription
            if !deviceManager.hasUnlimitedAccess && deviceManager.freeUsesRemaining <= 0 {
                isProcessing = false
                showingUpgrade = true
                return
            }
            
            // Consume a free use if not subscribed
            if !deviceManager.hasUnlimitedAccess {
                let success = await deviceManager.consumeFreeUse()
                if !success {
                    isProcessing = false
                    showingUpgrade = true
                    return
                }
            }
            
            do {
                // API call here
                // For now, using mock data
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                
                generatedRecipes = MockDataProvider.shared.mockRecipeResponse().recipes ?? []
                showingResults = true
                isProcessing = false
            } catch {
                isProcessing = false
            }
        }
    }
}

// MARK: - Camera Top Bar
struct CameraTopBar: View {
    let dismiss: DismissAction
    
    var body: some View {
        HStack {
            // Close button
            Button(action: { dismiss() }) {
                ZStack {
                    BlurredCircle()
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // AI Assistant
            AIAssistantIndicator()
            
            Spacer()
            
            // Settings
            Button(action: {}) {
                ZStack {
                    BlurredCircle()
                    
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
}

struct BlurredCircle: View {
    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - AI Assistant Indicator
struct AIAssistantIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                        .scaleEffect(isAnimating ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            
            Text("AI Ready")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Scanning Overlay
struct ScanningOverlay: View {
    @Binding var scanLineOffset: CGFloat
    @State private var cornerAnimation = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Corner brackets
                ForEach(0..<4) { index in
                    CornerBracket(corner: index)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#4facfe"),
                                    Color(hex: "#00f2fe")
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
                
                // Scanning line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color(hex: "#4facfe").opacity(0.5),
                                Color(hex: "#00f2fe"),
                                Color(hex: "#4facfe").opacity(0.5),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .blur(radius: 1)
                    .offset(y: scanLineOffset)
                
                // Center focus
                Image(systemName: "viewfinder")
                    .font(.system(size: 200, weight: .ultraLight))
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

struct CornerBracket: Shape {
    let corner: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = 20
        
        switch corner {
        case 0: // Top left
            path.move(to: CGPoint(x: 0, y: length))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: length, y: 0))
        case 1: // Top right
            path.move(to: CGPoint(x: rect.width - length, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: length))
        case 2: // Bottom left
            path.move(to: CGPoint(x: 0, y: rect.height - length))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: length, y: rect.height))
        case 3: // Bottom right
            path.move(to: CGPoint(x: rect.width - length, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - length))
        default:
            break
        }
        
        return path
    }
}

// MARK: - Enhanced Camera Controls
struct CameraControlsEnhanced: View {
    let cameraModel: CameraModel
    let capturePhoto: () -> Void
    let isProcessing: Bool
    @Binding var captureAnimation: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            // Instructions
            if !isProcessing {
                Text(cameraModel.isSessionReady ? "Point at your fridge or pantry" : "Initializing camera...")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
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
            }
            
            // Capture button
            CaptureButtonEnhanced(
                action: capturePhoto,
                isDisabled: isProcessing || !cameraModel.isSessionReady,
                triggerAnimation: $captureAnimation
            )
            
            // Bottom controls
            HStack(spacing: 40) {
                // Flash
                Button(action: {}) {
                    Image(systemName: "bolt.slash.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                
                Spacer()
                
                // Switch camera
                Button(action: { cameraModel.flipCamera() }) {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
            }
            .padding(.horizontal, 50)
        }
        .padding(.bottom, 50)
    }
}

struct CaptureButtonEnhanced: View {
    let action: () -> Void
    let isDisabled: Bool
    @Binding var triggerAnimation: Bool
    
    @State private var isPressed = false
    @State private var ringScale: CGFloat = 1
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring with animation
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#4facfe"),
                                Color(hex: "#00f2fe")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 90, height: 90)
                    .scaleEffect(ringScale)
                    .opacity(triggerAnimation ? 0 : 1)
                
                // Inner circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 75, height: 75)
                    .scaleEffect(isPressed ? 0.9 : 1)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, y: 3)
                
                // Center icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color(hex: "#667eea"))
            }
        }
        .disabled(isDisabled)
        .scaleEffect(isPressed ? 0.95 : 1)
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

// MARK: - Magical Processing Overlay
struct MagicalProcessingOverlay: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var messageIndex = 0
    
    let messages = [
        "Analyzing ingredients...",
        "Discovering recipes...",
        "Adding magic touches...",
        "Almost ready..."
    ]
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Animated loader
                ZStack {
                    // Rotating rings
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#667eea").opacity(0.8 - Double(index) * 0.2),
                                        Color(hex: "#764ba2").opacity(0.6 - Double(index) * 0.2),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 3
                            )
                            .frame(
                                width: CGFloat(80 + index * 30),
                                height: CGFloat(80 + index * 30)
                            )
                            .rotationEffect(.degrees(rotation + Double(index * 120)))
                    }
                    
                    // Center icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(scale)
                }
                
                // Animated text
                Text(messages[messageIndex])
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                    .id(messageIndex)
            }
        }
        .onAppear {
            // Rotation animation
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            // Scale animation
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                scale = 1.2
            }
            
            // Message rotation
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                withAnimation {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
    }
}

#Preview {
    EnhancedCameraView()
        .environmentObject(AppState())
        .environmentObject(DeviceManager())
}