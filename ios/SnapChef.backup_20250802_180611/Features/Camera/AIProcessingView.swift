import SwiftUI

struct AIProcessingView: View {
    @State private var isAnimating = false
    @State private var textOpacity = 0.0
    @State private var sparkleScale: CGFloat = 1.0
    @State private var buttonShake: CGFloat = 0
    
    // Callback for when user taps play game button
    var onPlayGameTapped: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
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
                
                // Text content with professional animation
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Our AI is scanning")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(textOpacity)
                            .scaleEffect(textOpacity)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: textOpacity)
                        
                        Text("Detecting food items,\nquantity & freshness")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .opacity(textOpacity)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: textOpacity)
                    }
                    
                    // Loading dots animation
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 10, height: 10)
                                .scaleEffect(isAnimating ? 1.0 : 0.5)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Text("While our chef prepares\nyour recipes...")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#f093fb"))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .opacity(textOpacity)
                        .animation(.easeInOut(duration: 0.5).delay(0.8), value: textOpacity)
                    
                    // Prominent game button
                    Button(action: {
                        onPlayGameTapped?()
                    }) {
                        ZStack {
                            // Pulsing background
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#f093fb"), Color(hex: "#f5576c")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 336, height: 56)
                                .scaleEffect(isAnimating ? 1.05 : 1.0)
                                .opacity(isAnimating ? 0.9 : 1.0)
                                .animation(
                                    Animation.easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                            
                            HStack(spacing: 10) {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 20))
                                Text("Play a game with your fridge while you wait!")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                        }
                    }
                    .buttonStyle(PlainButtonStyle()) // Remove default button styling
                    .opacity(textOpacity)
                    .scaleEffect(textOpacity)
                    .rotation3DEffect(
                        .degrees(buttonShake),
                        axis: (x: 0, y: 0, z: 1)
                    )
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(1.0), value: textOpacity)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 30)
                .frame(maxWidth: 400) // Limit width for readability
                
                Spacer()
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
            
            // Start button shake animation every 2 seconds
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation(
                    Animation.easeInOut(duration: 0.1)
                        .repeatCount(5, autoreverses: true)
                ) {
                    buttonShake = 3
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    buttonShake = 0
                }
            }
        }
    }
}

#Preview {
    AIProcessingView()
}