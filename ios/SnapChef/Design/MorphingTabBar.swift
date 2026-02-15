import SwiftUI

enum AppTab: Int, CaseIterable {
    case home = 0
    case camera = 1
    case detective = 2
    case recipes = 3
    case socialFeed = 4
    case profile = 5

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .camera: return "camera.fill"
        case .detective: return "magnifyingglass"
        case .recipes: return "book.fill"
        case .socialFeed: return "heart.text.square.fill"
        case .profile: return "person.fill"
        }
    }

    var tabBarTitle: String {
        switch self {
        case .home: return "Home"
        case .camera: return "Snap"
        case .detective: return "Detective"
        case .recipes: return "Recipes"
        case .socialFeed: return "Feed"
        case .profile: return "Profile"
        }
    }

    var tabBarColor: Color {
        switch self {
        case .home: return Color(hex: "#667eea")
        case .camera: return Color(hex: "#f093fb")
        case .detective: return Color(hex: "#9b59b6")
        case .recipes: return Color(hex: "#4facfe")
        case .socialFeed: return Color(hex: "#f77062")
        case .profile: return Color(hex: "#43e97b")
        }
    }

    var momentTitle: String {
        switch self {
        case .home: return "Home"
        case .camera: return "Snap Time"
        case .detective: return "Detective Mode"
        case .recipes: return "Recipes"
        case .socialFeed: return "Social Feed"
        case .profile: return "Profile"
        }
    }

    var momentIcon: String {
        switch self {
        case .home: return "house.fill"
        case .camera: return "camera.fill"
        case .detective: return "magnifyingglass"
        case .recipes: return "book.fill"
        case .socialFeed: return "heart.text.square.fill"
        case .profile: return "person.fill"
        }
    }

    var momentColor: Color {
        switch self {
        case .home: return Color(hex: "#4facfe")
        case .camera: return Color(hex: "#f093fb")
        case .detective: return Color(hex: "#43e97b")
        case .recipes: return Color(hex: "#f6d365")
        case .socialFeed: return Color(hex: "#f77062")
        case .profile: return Color(hex: "#84fab0")
        }
    }

    var requiresCameraPermission: Bool {
        switch self {
        case .camera, .detective:
            return true
        case .home, .recipes, .socialFeed, .profile:
            return false
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .home:
            return "tab_home"
        case .camera:
            return "tab_camera"
        case .detective:
            return "tab_detective"
        case .recipes:
            return "tab_recipes"
        case .socialFeed:
            return "tab_feed"
        case .profile:
            return "tab_profile"
        }
    }
}

enum ViralCoachSpotlightTarget: Hashable {
    case feedCopyInvite
    case profileInviteCenter
    case profileGrowthHub
    case tab(AppTab)
}

struct ViralCoachSpotlightAnchorsKey: PreferenceKey {
    static var defaultValue: [ViralCoachSpotlightTarget: Anchor<CGRect>] { [:] }

    static func reduce(
        value: inout [ViralCoachSpotlightTarget: Anchor<CGRect>],
        nextValue: () -> [ViralCoachSpotlightTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func viralCoachSpotlightAnchor(_ target: ViralCoachSpotlightTarget) -> some View {
        anchorPreference(key: ViralCoachSpotlightAnchorsKey.self, value: .bounds) {
            [target: $0]
        }
    }
}

struct MorphingTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation
    let onTabSelection: ((Int) -> Void)?
    
    init(selectedTab: Binding<Int>, onTabSelection: ((Int) -> Void)? = nil) {
        self._selectedTab = selectedTab
        self.onTabSelection = onTabSelection
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                let index = tab.rawValue
                MorphingTabItem(
                    icon: tab.icon,
                    title: tab.tabBarTitle,
                    color: tab.tabBarColor,
                    isSelected: selectedTab == index,
                    namespace: animation,
                    accessibilityID: tab.accessibilityIdentifier,
                    action: {
                        if let onTabSelection = onTabSelection {
                            onTabSelection(index)
                        } else {
                            withAnimation(MotionTuning.settleSpring(response: 0.3, damping: 0.8)) {
                                selectedTab = index
                            }
                        }
                    }
                )
                .viralCoachSpotlightAnchor(.tab(tab))
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
    let accessibilityID: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconRotation: Double = 0
    @State private var labelPulse = false

    var body: some View {
        Button(action: {
            action()
            if !reduceMotion {
                withAnimation(MotionTuning.settleSpring(response: 0.44, damping: 0.72)) {
                    iconRotation += isSelected ? 320 : 12
                    labelPulse = true
                }
                withAnimation(MotionTuning.softExit(0.22, delay: 0.08)) {
                    labelPulse = false
                }
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
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel(Text(title))
    }
}

// MARK: - Glassmorphic Tab Bar Background
struct GlassmorphicTabBarBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            if reduceMotion {
                shimmerPhase = 0.3
            } else {
                withAnimation(.linear(duration: MotionTuning.seconds(3)).repeatForever(autoreverses: false)) {
                    shimmerPhase = 2
                }
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
