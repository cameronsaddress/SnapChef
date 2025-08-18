import SwiftUI

struct CameraBottomControls: View {
    let cameraModel: CameraModel
    let capturePhoto: () -> Void
    let processTestImage: () -> Void
    let isProcessing: Bool
    @Binding var captureAnimation: Bool
    let captureMode: CameraView.CaptureMode
    let fridgePhoto: UIImage?
    @EnvironmentObject var deviceManager: DeviceManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Instructions - simplified for performance
            if deviceManager.animationsEnabled {
                CameraControlsEnhanced(
                    cameraModel: cameraModel,
                    capturePhoto: capturePhoto,
                    isProcessing: isProcessing,
                    captureAnimation: $captureAnimation,
                    captureMode: captureMode,
                    fridgePhoto: fridgePhoto
                )
            } else {
                // Simplified instructions for low-end devices
                Text(captureMode == .fridge ? "Capture your fridge contents" : "Capture your pantry items")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
            }
            
            // Bottom controls with capture button and test button
            VStack(spacing: 20) {
                // Capture button
                CaptureButtonEnhanced(
                    action: capturePhoto,
                    isDisabled: isProcessing || !cameraModel.isSessionReady,
                    triggerAnimation: $captureAnimation
                )

                // TEMPORARY TEST BUTTON - only in debug builds
                #if DEBUG
                Button(action: {
                    processTestImage()
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18, weight: .medium))
                        Text("Test with Fridge Image")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.8))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .disabled(isProcessing)
                .opacity(isProcessing ? 0.5 : 1)
                #endif
            }
            .padding(.bottom, 50)
        }
    }
}

#Preview {
    CameraBottomControls(
        cameraModel: CameraModel(),
        capturePhoto: {},
        processTestImage: {},
        isProcessing: false,
        captureAnimation: .constant(false),
        captureMode: .fridge,
        fridgePhoto: nil
    )
    .environmentObject(DeviceManager())
}