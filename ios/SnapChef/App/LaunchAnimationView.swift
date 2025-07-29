import SwiftUI

struct LaunchAnimationView: View {
    @State private var letterOpacities: [Double] = Array(repeating: 0, count: 8)
    @State private var letterScales: [CGFloat] = Array(repeating: 0.5, count: 8)
    @State private var sparklePosition: CGPoint = CGPoint(x: -50, y: 0)
    @State private var sparkleRotation: Double = 0
    @State private var showSparkle = false
    @State private var animationComplete = false
    
    let letters = ["S", "n", "a", "p", "C", "h", "e", "f"]
    let onAnimationComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "#667eea"),
                    Color(hex: "#764ba2")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // SnapChef letters
            HStack(spacing: 2) {
                ForEach(0..<letters.count, id: \.self) { index in
                    Text(letters[index])
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(letterOpacities[index])
                        .scaleEffect(letterScales[index])
                        .animation(
                            .spring(
                                response: 0.4,
                                dampingFraction: 0.7,
                                blendDuration: 0
                            ).delay(Double(index) * 0.08),
                            value: letterOpacities[index]
                        )
                }
            }
            
            // Animated sparkle emoji
            if showSparkle {
                Text("✨")
                    .font(.system(size: 48))
                    .position(sparklePosition)
                    .rotationEffect(.degrees(sparkleRotation))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            animateLetters()
            animateSparkle()
        }
    }
    
    private func animateLetters() {
        // Animate each letter popping in
        for index in 0..<letters.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                letterOpacities[index] = 1.0
                letterScales[index] = 1.0
            }
        }
    }
    
    private func animateSparkle() {
        // Wait for letters to appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSparkle = true
                sparklePosition = CGPoint(x: -100, y: -50)
            }
            
            // Animate sparkle circling around
            withAnimation(.easeInOut(duration: 1.0).delay(0.3)) {
                sparklePosition = CGPoint(x: 140, y: -25) // Final position next to 'f'
                sparkleRotation = 360
            }
            
            // Complete animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    animationComplete = true
                }
                
                // Notify completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onAnimationComplete()
                }
            }
        }
    }
}

#Preview {
    LaunchAnimationView {
        print("Animation complete!")
    }
}