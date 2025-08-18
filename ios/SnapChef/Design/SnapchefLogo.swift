import SwiftUI

struct SparkleState: Identifiable {
    let id = UUID()
    var position: CGPoint
    var opacity: Double
    var scale: CGFloat
    var isVisible: Bool
}

struct SnapchefLogo: View {
    let size: CGSize
    let animated: Bool
    let useImageAsset: Bool
    let showSparkles: Bool

    @State private var animate = false
    @State private var sparkleStates: [SparkleState] = []
    @State private var isAnimating = false

    init(
        size: CGSize = CGSize(width: 200, height: 50),
        animated: Bool = true,
        useImageAsset: Bool = false,
        showSparkles: Bool = false
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
        .onDisappear {
            isAnimating = false
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
            // Sparkling stars that appear and disappear randomly
            ForEach(sparkleStates.filter { $0.isVisible }) { sparkle in
                SparkleShape()
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color.yellow, Color.white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: sparkleSize * sparkle.scale, height: sparkleSize * sparkle.scale)
                    .position(sparkle.position)
                    .opacity(sparkle.opacity)
                    .scaleEffect(sparkle.scale)
                    .animation(.easeInOut(duration: 0.6), value: sparkle.opacity)
                    .animation(.easeInOut(duration: 0.4), value: sparkle.scale)
            }
        }
    }

    private var sparkleSize: CGFloat {
        max(size.width * 0.05, 8)
    }

    private func generateRandomSparklePosition() -> CGPoint {
        // Create positions around the logo in a more organic pattern
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        // Generate random positions in an ellipse around the logo
        let angle = Double.random(in: 0...(2 * .pi))
        let radiusX = size.width * Double.random(in: 0.35...0.55)
        let radiusY = size.height * Double.random(in: 0.8...1.2)
        
        let x = centerX + radiusX * cos(angle)
        let y = centerY + radiusY * sin(angle)
        
        return CGPoint(x: x, y: y)
    }
    
    private func startSparkleAnimations() {
        guard animated && showSparkles else { return }
        
        isAnimating = true
        
        // Initialize sparkle states
        sparkleStates = (0..<8).map { _ in
            SparkleState(
                position: generateRandomSparklePosition(),
                opacity: 0.0,
                scale: 0.5,
                isVisible: false
            )
        }
        
        // Start the sparkling animation cycle
        animateSparkles()
    }
    
    private func animateSparkles() {
        guard animated && showSparkles && isAnimating else { return }
        
        // Random delay for next animation cycle
        let delay = Double.random(in: 0.1...0.8)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard self.isAnimating else { return }
            
            // Randomly select 1-3 sparkles to animate
            let numberOfSparkles = Int.random(in: 1...3)
            let selectedIndices = Array(sparkleStates.indices.shuffled().prefix(numberOfSparkles))
            
            for index in selectedIndices {
                // Update position to a new random location
                sparkleStates[index].position = generateRandomSparklePosition()
                sparkleStates[index].isVisible = true
                
                // Animate sparkle appearing
                withAnimation(.easeOut(duration: 0.3)) {
                    sparkleStates[index].opacity = Double.random(in: 0.6...1.0)
                    sparkleStates[index].scale = CGFloat.random(in: 0.8...1.3)
                }
                
                // Animate sparkle disappearing after a short time
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.4...1.0)) {
                    guard self.isAnimating else { return }
                    
                    withAnimation(.easeIn(duration: 0.4)) {
                        sparkleStates[index].opacity = 0.0
                        sparkleStates[index].scale = 0.3
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        guard self.isAnimating else { return }
                        sparkleStates[index].isVisible = false
                    }
                }
            }
            
            // Continue the animation cycle
            animateSparkles()
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
            showSparkles: false
        )
    }

    /// Medium logo for navigation and section headers
    static func medium(useImageAsset: Bool = false) -> SnapchefLogo {
        SnapchefLogo(
            size: CGSize(width: 200, height: 50),
            animated: true,
            useImageAsset: useImageAsset,
            showSparkles: false
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
