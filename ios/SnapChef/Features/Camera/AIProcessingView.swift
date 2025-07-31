import SwiftUI

struct AIProcessingView: View {
    @State private var isAnimating = false
    @State private var textOpacity = 0.0
    @State private var sparkleScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Animated AI Icon
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#667eea").opacity(0.5),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.3 : 1.0)
                        .opacity(isAnimating ? 0.5 : 0.8)
                    
                    // Rotating ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2"),
                                    Color(hex: "#f093fb")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    
                    // Inner circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    // AI Icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(sparkleScale)
                }
                
                // Text content
                VStack(spacing: 20) {
                    Text("Our awesome AI is now")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(textOpacity)
                    
                    VStack(spacing: 8) {
                        Text("✨ Scanning for all food items")
                        Text("📊 Analyzing quantity and freshness")
                        Text("👨‍🍳 Crafting perfect recipes")
                    }
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(textOpacity)
                    .animation(.easeInOut(duration: 0.5).delay(0.3), value: textOpacity)
                    
                    Text("While he cooks, here's a fun game on us!")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#f093fb"))
                        .padding(.top, 10)
                        .opacity(textOpacity)
                        .animation(.easeInOut(duration: 0.5).delay(0.6), value: textOpacity)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            }
        }
        .onAppear {
            // Start animations
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                sparkleScale = 1.2
            }
            
            withAnimation(.easeInOut(duration: 0.6)) {
                textOpacity = 1.0
            }
        }
    }
}

#Preview {
    AIProcessingView()
}