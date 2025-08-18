import SwiftUI

struct CameraOverlays: View {
    let isProcessing: Bool
    let showingPreview: Bool
    let capturedImage: UIImage?
    let showWelcomeMessage: Bool
    @Binding var showConfetti: Bool
    @EnvironmentObject var deviceManager: DeviceManager
    
    // Callbacks
    let onRetake: () -> Void
    let onConfirm: () -> Void
    var onCloseProcessing: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Processing overlay
            if isProcessing {
                MagicalProcessingOverlay(capturedImage: capturedImage, onClose: onCloseProcessing)
            }

            // Captured image preview
            if showingPreview, let image = capturedImage {
                CapturedImageView(
                    image: image,
                    onRetake: onRetake,
                    onConfirm: onConfirm
                )
                .transition(.opacity.combined(with: .scale(scale: 1.1)))
            }

            // Welcome message - only show if animations are enabled
            if showWelcomeMessage && deviceManager.animationsEnabled {
                VStack {
                    Spacer()
                    Text("Yay! This will be fun! 🎉")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "#667eea").opacity(0.9))
                                .shadow(radius: deviceManager.shouldUseHeavyEffects ? 20 : 5)
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    Spacer()
                }
            }
        }
        .particleExplosion(trigger: $showConfetti)
    }
}

#Preview {
    CameraOverlays(
        isProcessing: false,
        showingPreview: false,
        capturedImage: nil,
        showWelcomeMessage: true,
        showConfetti: .constant(false),
        onRetake: {},
        onConfirm: {}
    )
    .environmentObject(DeviceManager())
}