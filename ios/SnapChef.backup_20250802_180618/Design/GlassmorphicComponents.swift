import SwiftUI

// MARK: - Glassmorphic Card
struct GlassmorphicCard<Content: View>: View {
    let content: () -> Content
    var cornerRadius: CGFloat = 20
    var glowColor: Color = Color(hex: "#4facfe")
    
    @State private var isPressed = false
    @State private var shimmerPhase: CGFloat = -1
    
    var body: some View {
        content()
            .background(
                ZStack {
                    // Glow effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(glowColor.opacity(0.3))
                        .blur(radius: 20)
                        .offset(y: 10)
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                    
                    // Glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            // Border gradient
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    // Shimmer effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: UnitPoint(x: shimmerPhase - 0.3, y: 0),
                                endPoint: UnitPoint(x: shimmerPhase + 0.3, y: 1)
                            )
                        )
                        .allowsHitTesting(false)
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Magnetic Button
struct MagneticButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    @State private var offset: CGSize = .zero
    @State private var isPressed = false
    @State private var particleScale: CGFloat = 0
    
    var body: some View {
        Button(action: {
            impact(.medium)
            triggerParticles()
            action()
        }) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    // Gradient background
                    LinearGradient(
                        colors: [
                            Color(hex: "#667eea"),
                            Color(hex: "#764ba2")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Particle burst
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .scaleEffect(particleScale)
                        .opacity(particleScale > 0 ? 0 : 1)
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 20, y: 10)
            .offset(offset)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let translation = value.translation
                    let distance = sqrt(pow(translation.width, 2) + pow(translation.height, 2))
                    let maxDistance: CGFloat = 30
                    
                    if distance < maxDistance {
                        offset = CGSize(
                            width: translation.width * 0.5,
                            height: translation.height * 0.5
                        )
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = .zero
                    }
                }
        )
    }
    
    private func triggerParticles() {
        particleScale = 0
        withAnimation(.easeOut(duration: 0.6)) {
            particleScale = 3
        }
    }
    
    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let badge: String?
    let action: () -> Void
    
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1
    @State private var showRipple = false
    
    init(icon: String, badge: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.badge = badge
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            triggerAnimation()
            action()
        }) {
            ZStack {
                // Ripple effect
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .scaleEffect(showRipple ? 2.5 : 1)
                    .opacity(showRipple ? 0 : 1)
                
                // Button background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#f093fb"),
                                Color(hex: "#f5576c")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "#f093fb").opacity(0.5), radius: 15, y: 8)
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
                
                // Badge
                if let badge = badge {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color(hex: "#667eea"))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(badge)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        }
                        Spacer()
                    }
                    .offset(x: 5, y: -5)
                }
            }
            .frame(width: 60, height: 60)
            .scaleEffect(scale)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func triggerAnimation() {
        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Scale animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 0.9
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
            scale = 1.0
        }
        
        // Rotation animation
        withAnimation(.easeInOut(duration: 0.5)) {
            rotation += 360
        }
        
        // Ripple animation
        showRipple = true
        withAnimation(.easeOut(duration: 0.6)) {
            showRipple = false
        }
    }
}

// MARK: - Neumorphic Toggle
struct NeumorphicToggle: View {
    @Binding var isOn: Bool
    let label: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            ZStack {
                // Track
                Capsule()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 50, height: 30)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                // Thumb
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isOn ? [
                                Color(hex: "#43e97b"),
                                Color(hex: "#38f9d7")
                            ] : [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                    .offset(x: isOn ? 10 : -10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
            }
            .onTapGesture {
                withAnimation {
                    isOn.toggle()
                }
                
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Animated Progress Ring
struct AnimatedProgressRing: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat = 8
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#667eea"),
                            Color(hex: "#764ba2"),
                            Color(hex: "#f093fb"),
                            Color(hex: "#667eea")
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 5)
            
            // Center text
            Text("\(Int(animatedProgress * 100))%")
                .font(.system(size: size / 4, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}


#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 30) {
            GlassmorphicCard {
                VStack {
                    Text("Glassmorphic Card")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Beautiful glass effect")
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(30)
            }
            
            MagneticButton(
                title: "Get Started",
                icon: "arrow.right",
                action: {}
            )
            
            FloatingActionButton(
                icon: "camera.fill",
                action: {}
            )
        }
    }
}