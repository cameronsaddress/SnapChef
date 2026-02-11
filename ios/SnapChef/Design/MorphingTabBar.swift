import SwiftUI

struct MorphingTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation
    let onTabSelection: ((Int) -> Void)?

    let tabs = [
        ("house.fill", "Home", Color(hex: "#667eea")),
        ("camera.fill", "Snap", Color(hex: "#f093fb")),
        ("magnifyingglass", "Detective", Color(hex: "#9b59b6")),
        ("book.fill", "Recipes", Color(hex: "#4facfe")),
        ("heart.text.square.fill", "Feed", Color(hex: "#f77062")),
        ("person.fill", "Profile", Color(hex: "#43e97b"))
    ]
    
    init(selectedTab: Binding<Int>, onTabSelection: ((Int) -> Void)? = nil) {
        self._selectedTab = selectedTab
        self.onTabSelection = onTabSelection
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                MorphingTabItem(
                    icon: tabs[index].0,
                    title: tabs[index].1,
                    color: tabs[index].2,
                    isSelected: selectedTab == index,
                    namespace: animation,
                    action: {
                        if let onTabSelection = onTabSelection {
                            onTabSelection(index)
                        } else {
                            withAnimation(.spring(response: MotionTuning.seconds(0.3), dampingFraction: 0.7)) {
                                selectedTab = index
                            }
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            GlassmorphicTabBarBackground()
        )
    }
}

// MARK: - Morphing Tab Item
struct MorphingTabItem: View {
    let icon: String
    let title: String
    let color: Color
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var iconRotation: Double = 0
    @State private var labelPulse = false

    var body: some View {
        Button(action: {
            action()
            withAnimation(.spring(response: MotionTuning.seconds(0.5), dampingFraction: 0.62)) {
                iconRotation += isSelected ? 320 : 12
                labelPulse = true
            }
            withAnimation(.easeOut(duration: MotionTuning.seconds(0.24)).delay(MotionTuning.seconds(0.08))) {
                labelPulse = false
            }
        }) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        // Selected background
                        RoundedRectangle(cornerRadius: 16)
                            .fill(color.opacity(0.2))
                            .frame(width: 60, height: 40)
                            .matchedGeometryEffect(id: "background", in: namespace)

                        // Glow effect
                        RoundedRectangle(cornerRadius: 16)
                            .fill(color.opacity(0.1))
                            .frame(width: 70, height: 50)
                            .blur(radius: 10)
                    }

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? color : .white.opacity(0.6))
                        .scaleEffect(isSelected ? 1.1 : 1)
                        .rotationEffect(.degrees(iconRotation))
                }

                if isSelected {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(color)
                        .scaleEffect(labelPulse ? 1.06 : 1.0)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(StudioSpringButtonStyle(pressedScale: 0.9, pressedYOffset: 1.2, activeRotation: 2.4))
    }
}

// MARK: - Glassmorphic Tab Bar Background
struct GlassmorphicTabBarBackground: View {
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        ZStack {
            // Base blur
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)

            // Gradient overlay
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Border
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            // Shimmer effect
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: UnitPoint(x: shimmerPhase - 0.3, y: 0),
                        endPoint: UnitPoint(x: shimmerPhase + 0.3, y: 1)
                    )
                )
                .mask(
                    RoundedRectangle(cornerRadius: 24)
                )
        }
        .onAppear {
            withAnimation(.linear(duration: MotionTuning.seconds(3)).repeatForever(autoreverses: false)) {
                shimmerPhase = 2
            }
        }
    }
}

// MARK: - Floating Tab Bar Modifier
struct FloatingTabBar: ViewModifier {
    @Binding var selectedTab: Int

    func body(content: Content) -> some View {
        ZStack {
            content

            VStack {
                Spacer()

                MorphingTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 20,
                        y: 10
                    )
            }
        }
    }
}

// MARK: - Custom Tab View
struct CustomTabView<Content: View>: View {
    @Binding var selectedTab: Int
    let content: () -> Content

    init(selectedTab: Binding<Int>, @ViewBuilder content: @escaping () -> Content) {
        self._selectedTab = selectedTab
        self.content = content
    }

    var body: some View {
        ZStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Spacer()

                MorphingTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 20,
                        y: 10
                    )
            }
        }
    }
}

// MARK: - Tab Indicator Animation
struct TabIndicatorShape: Shape {
    var tabWidth: CGFloat
    var xOffset: CGFloat

    var animatableData: CGFloat {
        get { xOffset }
        set { xOffset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let radius: CGFloat = 16
        let indicatorWidth = tabWidth - 20
        let x = xOffset + 10

        path.move(to: CGPoint(x: x + radius, y: 0))
        path.addLine(to: CGPoint(x: x + indicatorWidth - radius, y: 0))
        path.addArc(
            center: CGPoint(x: x + indicatorWidth - radius, y: radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: x + indicatorWidth, y: rect.height - radius))
        path.addArc(
            center: CGPoint(x: x + indicatorWidth - radius, y: rect.height - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: x + radius, y: rect.height))
        path.addArc(
            center: CGPoint(x: x + radius, y: rect.height - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: x, y: radius))
        path.addArc(
            center: CGPoint(x: x + radius, y: radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        return path
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        MagicalBackground()
            .ignoresSafeArea()

        VStack {
            Spacer()

            MorphingTabBar(selectedTab: .constant(0))
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
        }
    }
}
