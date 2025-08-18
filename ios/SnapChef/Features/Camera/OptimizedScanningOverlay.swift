import SwiftUI

struct OptimizedScanningOverlay: View {
    @Binding var scanLineOffset: CGFloat
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var animationActive: Bool = true
    
    var body: some View {
        if deviceManager.shouldUseContinuousAnimations {
            // Full scanning overlay with animations
            ScanningOverlay(scanLineOffset: $scanLineOffset)
        } else {
            // Static overlay for performance
            GeometryReader { geometry in
                ZStack {
                    // Simple corner indicators
                    VStack {
                        HStack {
                            ScanCorner(position: .topLeft)
                            Spacer()
                            ScanCorner(position: .topRight)
                        }
                        Spacer()
                        HStack {
                            ScanCorner(position: .bottomLeft)
                            Spacer()
                            ScanCorner(position: .bottomRight)
                        }
                    }
                    .padding(40)
                    
                    // Static instruction text
                    VStack {
                        Spacer()
                        Text("Position items in the frame")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                            )
                        Spacer()
                            .frame(height: 200)
                    }
                }
            }
        }
    }
}

struct ScanCorner: View {
    enum Position {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let position: Position
    
    var body: some View {
        Path { path in
            let cornerSize: CGFloat = 20
            
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
        .frame(width: 20, height: 20)
    }
}

#Preview {
    OptimizedScanningOverlay(scanLineOffset: .constant(-200))
        .environmentObject(DeviceManager())
}