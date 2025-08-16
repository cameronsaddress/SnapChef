import SwiftUI

struct SnapchefLogo: View {
    let size: CGSize
    let animated: Bool
    let useImageAsset: Bool
    let showSparkles: Bool
    
    @State private var animate = false
    @State private var sparkleRotation: Double = 0
    @State private var sparkleOpacity: Double = 1.0

    init(
        size: CGSize = CGSize(width: 200, height: 50),
        animated: Bool = true,
        useImageAsset: Bool = false,
        showSparkles: Bool = true
    ) {
        self.size = size
        self.animated = animated
        self.useImageAsset = useImageAsset
        self.showSparkles = showSparkles
    }

    var body: some View {
        ZStack {
            if useImageAsset {
                // Use the PNG image asset when available
                Image("SnapChefLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(animate ? 1.05 : 1.0)
            } else {
                // Fallback to text-based logo
                textBasedLogo
            }
            
            if showSparkles && !useImageAsset {
                sparklesOverlay
            }
        }
        .animation(
            animated ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .none,
            value: animate
        )
        .onAppear {
            if animated {
                animate = true
                startSparkleAnimations()
            }
        }
    }
    
    private var textBasedLogo: some View {
        Text("SNAPCHEF!")
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(snapChefGradient)
            .shadow(color: .purple.opacity(0.4), radius: 5, x: 2, y: 2)
            .scaleEffect(animate ? 1.05 : 1.0)
    }
    
    private var fontSize: CGFloat {
        // Scale font size based on the width
        max(size.width * 0.24, 16)
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
            // Main sparkles around the logo
            ForEach(0..<6, id: \.self) { index in
                SparkleShape()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: sparkleSize, height: sparkleSize)
                    .position(sparklePosition(for: index, total: 6))
                    .opacity(sparkleOpacity)
                    .rotationEffect(.degrees(sparkleRotation))
            }
        }
        .animation(
            animated ? .linear(duration: 4.0).repeatForever(autoreverses: false) : .none,
            value: sparkleRotation
        )
        .animation(
            animated ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true) : .none,
            value: sparkleOpacity
        )
    }
    
    private var sparkleSize: CGFloat {
        max(size.width * 0.05, 8)
    }
    
    private func sparklePosition(for index: Int, total: Int) -> CGPoint {
        let angle = (Double(index) / Double(total)) * 2 * .pi
        let radius = size.width * 0.4
        let x = size.width / 2 + radius * cos(angle)
        let y = size.height / 2 + radius * sin(angle)
        return CGPoint(x: x, y: y)
    }
    
    private func startSparkleAnimations() {
        if animated && showSparkles {
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
            
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                sparkleOpacity = 0.3
            }
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

// MARK: - Convenience Extensions
extension SnapchefLogo {
    /// Large animated logo for splash screens and main headers
    static func large(useImageAsset: Bool = false) -> SnapchefLogo {
        SnapchefLogo(
            size: CGSize(width: 300, height: 75),
            animated: true,
            useImageAsset: useImageAsset,
            showSparkles: true
        )
    }
    
    /// Medium logo for navigation and section headers
    static func medium(useImageAsset: Bool = false) -> SnapchefLogo {
        SnapchefLogo(
            size: CGSize(width: 200, height: 50),
            animated: true,
            useImageAsset: useImageAsset,
            showSparkles: true
        )
    }
    
    /// Small logo for compact spaces
    static func small(useImageAsset: Bool = false) -> SnapchefLogo {
        SnapchefLogo(
            size: CGSize(width: 120, height: 30),
            animated: false,
            useImageAsset: useImageAsset,
            showSparkles: false
        )
    }
    
    /// Mini logo for very small spaces (navigation bars, etc.)
    static func mini(useImageAsset: Bool = false) -> SnapchefLogo {
        SnapchefLogo(
            size: CGSize(width: 80, height: 20),
            animated: false,
            useImageAsset: useImageAsset,
            showSparkles: false
        )
    }
}

#Preview("Logo Variants") {
    VStack(spacing: 30) {
        Text("SnapChef Logo Variants")
            .font(.title2)
            .padding(.bottom)
        
        Group {
            Text("Large (Animated)")
                .font(.caption)
            SnapchefLogo.large()
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            
            Text("Medium (Animated)")
                .font(.caption)
            SnapchefLogo.medium()
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            
            Text("Small (Static)")
                .font(.caption)
            SnapchefLogo.small()
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
            
            Text("Mini (Static)")
                .font(.caption)
            SnapchefLogo.mini()
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
        }
    }
    .padding()
}

#Preview("Dark Background") {
    VStack(spacing: 20) {
        SnapchefLogo.large()
        SnapchefLogo.medium()
    }
    .padding()
    .background(Color.black)
}