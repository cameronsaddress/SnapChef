import SwiftUI

/// A beautiful, animated usage counter component that shows usage like "2/3 recipes today"
/// with progressive color changes and pulse animations when approaching limits.
struct UsageCounterView: View {
    let current: Int
    let limit: Int?
    let type: String

    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerPhase: CGFloat = -1.0
    @State private var glowIntensity: Double = 0.3

    // MARK: - Computed Properties

    private var isUnlimited: Bool {
        limit == nil
    }

    private var shouldPulse: Bool {
        guard let limit = limit else { return false }
        return current >= limit - 1
    }

    private var progressRatio: Double {
        guard let limit = limit, limit > 0 else { return 0 }
        return min(Double(current) / Double(limit), 1.0)
    }

    private var statusColor: Color {
        if isUnlimited {
            return Color(hex: "#43e97b") // Unlimited green
        }

        guard let limit = limit else { return Color(hex: "#43e97b") }

        let ratio = progressRatio
        if ratio >= 1.0 {
            return Color(hex: "#ff4757") // Red - limit reached
        } else if ratio >= 0.8 {
            return Color(hex: "#ffa502") // Orange - approaching limit
        } else if ratio >= 0.6 {
            return Color(hex: "#ffdd59") // Yellow - caution
        } else {
            return Color(hex: "#43e97b") // Green - safe
        }
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                statusColor.opacity(0.2),
                statusColor.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                statusColor.opacity(0.8),
                statusColor.opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Main View

    var body: some View {
        HStack(spacing: 8) {
            // Usage Text
            usageTextView

            // Status Icon
            statusIconView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(containerBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(borderGradient, lineWidth: 1.5)
        )
        .shadow(
            color: statusColor.opacity(0.3),
            radius: shouldPulse ? 12 : 6,
            x: 0,
            y: 4
        )
        .scaleEffect(pulseScale)
        .onAppear {
            startAnimations()
        }
        .onChange(of: current) { _ in
            triggerUpdateAnimation()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: statusColor)
    }

    // MARK: - Subviews

    private var usageTextView: some View {
        Text(usageString)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(textGradient)
            .animation(.easeInOut(duration: 0.3), value: usageString)
    }

    private var statusIconView: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(statusColor.opacity(glowIntensity))
                .frame(width: 20, height: 20)
                .blur(radius: 4)
            // Icon
            Image(systemName: statusIconName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(statusColor)
                .scaleEffect(shouldPulse ? 1.1 : 1.0)
        }
        .animation(.easeInOut(duration: 0.5), value: statusIconName)
    }

    private var containerBackground: some View {
        ZStack {
            // Glass base
            Capsule()
                .fill(.ultraThinMaterial)

            // Gradient overlay
            Capsule()
                .fill(backgroundGradient)
            // Shimmer effect
            Capsule()
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
    }

    // MARK: - Text and Icon Logic

    private var usageString: String {
        if isUnlimited {
            return "♾️ \(type)"
        } else {
            return "\(current)/\(limit ?? 0) \(type) today"
        }
    }

    private var statusIconName: String {
        if isUnlimited {
            return "crown.fill"
        }

        guard let limit = limit else { return "checkmark.circle.fill" }

        let ratio = progressRatio
        if ratio >= 1.0 {
            return "exclamationmark.triangle.fill"
        } else if ratio >= 0.8 {
            return "exclamationmark.circle.fill"
        } else if ratio >= 0.6 {
            return "clock.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var textGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white,
                Color.white.opacity(0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Animations

    private func startAnimations() {
        // Shimmer animation
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            shimmerPhase = 1.3
        }

        // Pulse animation (only when approaching limit)
        if shouldPulse {
            startPulseAnimation()
        }

        // Glow animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = isUnlimited ? 0.6 : 0.1
        }
    }

    private func startPulseAnimation() {
        guard shouldPulse else { return }

        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
        }
    }

    private func triggerUpdateAnimation() {
        // Reset and restart pulse if needed
        pulseScale = 1.0

        if shouldPulse {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                startPulseAnimation()
            }
        }

        // Haptic feedback
        Task { @MainActor in
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
}

// MARK: - Convenience Initializers

extension UsageCounterView {
    /// Creates a usage counter for recipes
    static func recipes(current: Int, limit: Int?) -> UsageCounterView {
        UsageCounterView(current: current, limit: limit, type: "recipes")
    }

    /// Creates a usage counter for videos
    static func videos(current: Int, limit: Int?) -> UsageCounterView {
        UsageCounterView(current: current, limit: limit, type: "videos")
    }

    /// Creates a usage counter for challenges
    static func challenges(current: Int, limit: Int?) -> UsageCounterView {
        UsageCounterView(current: current, limit: limit, type: "challenges")
    }

    /// Creates a usage counter for any custom type
    static func custom(current: Int, limit: Int?, type: String) -> UsageCounterView {
        UsageCounterView(current: current, limit: limit, type: type)
    }

    /// Creates an unlimited usage counter
    static func unlimited(type: String) -> UsageCounterView {
        UsageCounterView(current: 0, limit: nil, type: type)
    }
}

// MARK: - Preview

#Preview("Usage States") {
    ZStack {
        // Dark gradient background matching SnapChef's style
        LinearGradient(
            colors: [
                Color(hex: "#0c0c0c"),
                Color(hex: "#1a1a2e"),
                Color(hex: "#16213e")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 24) {
            Text("Usage Counter States")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.bottom, 20)

            VStack(spacing: 16) {
                // Safe usage (green)
                UsageCounterView.recipes(current: 1, limit: 5)

                // Caution usage (yellow)
                UsageCounterView.recipes(current: 3, limit: 5)

                // Warning usage (orange)
                UsageCounterView.recipes(current: 4, limit: 5)

                // Limit reached (red)
                UsageCounterView.recipes(current: 5, limit: 5)

                // Unlimited (green with infinity)
                UsageCounterView.unlimited(type: "recipes")

                // Video counter
                UsageCounterView.videos(current: 0, limit: 1)

                // Custom type
                UsageCounterView.custom(current: 2, limit: 3, type: "shares")
            }

            Spacer()
        }
        .padding()
    }
}

#Preview("Animation Test") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 30) {
            // Pulse animation (1 remaining)
            UsageCounterView.recipes(current: 4, limit: 5)

            // Unlimited with crown
            UsageCounterView.unlimited(type: "videos")
        }
        .padding()
    }
}
