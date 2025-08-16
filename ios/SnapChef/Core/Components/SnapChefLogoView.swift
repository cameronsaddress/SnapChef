import SwiftUI

struct SnapChefLogoView: View {
    let size: CGSize
    let animated: Bool
    let showSparkles: Bool
    
    @State private var sparkleRotation: Double = 0
    @State private var sparkleOpacity: Double = 1.0
    @State private var textScale: Double = 1.0
    
    init(
        size: CGSize = CGSize(width: 200, height: 50),
        animated: Bool = false,
        showSparkles: Bool = true
    ) {
        self.size = size
        self.animated = animated
        self.showSparkles = showSparkles
    }
    
    var body: some View {
        ZStack {
            // Main logo text
            Text("SNAPCHEF!")
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundStyle(snapChefGradient)
                .scaleEffect(textScale)
                .animation(
                    animated ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true) : .none,
                    value: textScale
                )
            
            // Sparkles overlay
            if showSparkles {
                sparklesOverlay
                    .opacity(sparkleOpacity)
                    .rotationEffect(.degrees(sparkleRotation))
                    .animation(
                        animated ? .linear(duration: 4.0).repeatForever(autoreverses: false) : .none,
                        value: sparkleRotation
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            if animated {
                startAnimations()
            }
        }
    }
    
    private var fontSize: CGFloat {
        // Scale font size based on the width
        return size.width * 0.12
    }
    
    private var snapChefGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.078, blue: 0.576), // #FF1493 - Pink
                Color(red: 0.6, green: 0.196, blue: 0.8),   // #9932CC - Purple
                Color(red: 0.0, green: 1.0, blue: 1.0)      // #00FFFF - Cyan
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var sparklesOverlay: some View {
        ZStack {
            // Large sparkles
            ForEach(0..<8, id: \.self) { index in
                SparkleShape()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: sparkleSize, height: sparkleSize)
                    .position(sparklePosition(for: index, total: 8, radius: size.width * 0.4))
                    .animation(
                        animated ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(index) * 0.2) : .none,
                        value: sparkleOpacity
                    )
            }
            
            // Small sparkles
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: sparkleSize * 0.3, height: sparkleSize * 0.3)
                    .position(sparklePosition(for: index, total: 12, radius: size.width * 0.5))
                    .animation(
                        animated ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(Double(index) * 0.1) : .none,
                        value: sparkleOpacity
                    )
            }
        }
    }
    
    private var sparkleSize: CGFloat {
        size.width * 0.03
    }
    
    private func sparklePosition(for index: Int, total: Int, radius: CGFloat) -> CGPoint {
        let angle = (Double(index) / Double(total)) * 2 * .pi
        let x = size.width / 2 + radius * cos(angle)
        let y = size.height / 2 + radius * sin(angle)
        return CGPoint(x: x, y: y)
    }
    
    private func startAnimations() {
        // Sparkle rotation animation
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            sparkleRotation = 360
        }
        
        // Sparkle opacity animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            sparkleOpacity = 0.3
        }
        
        // Text scale animation
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            textScale = 1.05
        }
    }
}

struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        // Create a 4-pointed star
        let outerRadius = radius
        let innerRadius = radius * 0.4
        
        let points = 8
        for i in 0..<points {
            let angle = (Double(i) * .pi) / Double(points / 2)
            let currentRadius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + currentRadius * cos(angle - .pi / 2)
            let y = center.y + currentRadius * sin(angle - .pi / 2)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Convenience Initializers
extension SnapChefLogoView {
    /// Large logo for splash screens and headers
    static func large(animated: Bool = false) -> SnapChefLogoView {
        SnapChefLogoView(
            size: CGSize(width: 300, height: 75),
            animated: animated,
            showSparkles: true
        )
    }
    
    /// Medium logo for navigation bars and sections
    static func medium(animated: Bool = false) -> SnapChefLogoView {
        SnapChefLogoView(
            size: CGSize(width: 180, height: 45),
            animated: animated,
            showSparkles: true
        )
    }
    
    /// Small logo for compact spaces
    static func small(animated: Bool = false) -> SnapChefLogoView {
        SnapChefLogoView(
            size: CGSize(width: 120, height: 30),
            animated: animated,
            showSparkles: false
        )
    }
    
    /// Mini logo for very small spaces
    static func mini() -> SnapChefLogoView {
        SnapChefLogoView(
            size: CGSize(width: 80, height: 20),
            animated: false,
            showSparkles: false
        )
    }
}

// MARK: - Preview
#Preview("Logo Sizes") {
    VStack(spacing: 30) {
        SnapChefLogoView.large(animated: true)
            .background(Color.black.opacity(0.1))
        
        SnapChefLogoView.medium(animated: true)
            .background(Color.black.opacity(0.1))
        
        SnapChefLogoView.small()
            .background(Color.black.opacity(0.1))
        
        SnapChefLogoView.mini()
            .background(Color.black.opacity(0.1))
    }
    .padding()
}

#Preview("Dark Background") {
    VStack(spacing: 30) {
        SnapChefLogoView.large(animated: true)
        SnapChefLogoView.medium(animated: true)
    }
    .padding()
    .background(Color.black)
}