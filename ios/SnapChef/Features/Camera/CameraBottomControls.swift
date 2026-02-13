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
