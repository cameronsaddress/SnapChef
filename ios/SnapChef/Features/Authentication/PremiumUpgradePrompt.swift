import SwiftUI

struct PremiumUpgradePrompt: View {
    @Binding var isPresented: Bool
    @State private var showSubscriptionView = false
    @StateObject private var userLifecycle = UserLifecycleManager.shared
    @StateObject private var usageTracker = UsageTracker.shared
    let reason: UpgradeReason

    enum UpgradeReason {
        case dailyLimitReached
        case premiumFeature(String)
        case videoLimitReached
        case challengeLimitReached

        var title: String {
            switch self {
            case .dailyLimitReached:
                return "Recipe Limit Reached"
            case .videoLimitReached:
                return "Video Limit Reached"
            case .premiumFeature:
                return "Premium Feature"
            case .challengeLimitReached:
                return "Challenge Limit Reached"
            }
        }

        @MainActor
        func message(userLifecycle: UserLifecycleManager) -> String {
            switch self {
            case .dailyLimitReached:
                let dailyLimits = userLifecycle.getDailyLimits()
                let limit = dailyLimits.recipes
                return "You've used all \(limit) free recipes today. Upgrade to Premium for unlimited recipes!"
            case .videoLimitReached:
                let dailyLimits = userLifecycle.getDailyLimits()
                let limit = dailyLimits.videos
                return "You've created your \(limit == 1 ? "daily video" : "\(limit) daily videos"). Upgrade for unlimited video creation!"
            case .premiumFeature(let feature):
                return "\(feature) is a premium feature. Upgrade to unlock all features!"
            case .challengeLimitReached:
                return "You've reached your daily challenge limit. Upgrade for unlimited challenges and 2x rewards!"
            }
        }

        var icon: String {
            switch self {
            case .dailyLimitReached:
                return "hourglass"
            case .videoLimitReached:
                return "video.slash"
            case .premiumFeature:
                return "lock.fill"
            case .challengeLimitReached:
                return "trophy.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            // Content card
            VStack(spacing: 24) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                // Icon
                ZStack {
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
                        .frame(width: 80, height: 80)

                    Image(systemName: reason.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }

                // Title
                Text(reason.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                // Message
                Text(reason.message(userLifecycle: userLifecycle))
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Benefits - Dynamic based on user phase
                VStack(alignment: .leading, spacing: 12) {
                    if userLifecycle.currentPhase == .honeymoon {
                        Text("Currently in Premium Preview")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(.bottom, 4)
                    }

                    BenefitRow(icon: "infinity", text: "Unlimited recipes every day")
                    BenefitRow(icon: "video.fill", text: "Unlimited TikTok videos")
                    BenefitRow(icon: "sparkles", text: "Premium video effects")
                    BenefitRow(icon: "trophy.fill", text: "2x challenge rewards")

                    if userLifecycle.currentPhase == .honeymoon {
                        let daysRemaining = 7 - userLifecycle.daysActive
                        Text("\(daysRemaining) days of free premium remaining")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 16)

                // Upgrade button
                MagneticButton(
                    title: "Upgrade to Premium",
                    icon: "crown.fill",
                    action: {
                        showSubscriptionView = true
                    }
                )

                // Additional actions
                HStack(spacing: 20) {
                    // Restore Purchases button
                    Button(action: {
                        Task {
                            await SubscriptionManager.shared.restorePurchases()
                            if SubscriptionManager.shared.isPremium {
                                isPresented = false
                            }
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                            .underline()
                    }
                    
                    // Continue with limited - Dynamic based on reason
                    switch reason {
                    case .dailyLimitReached, .videoLimitReached:
                        Button(action: { isPresented = false }) {
                            VStack(spacing: 4) {
                                Text("Continue with Free")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Resets at midnight")
                                    .font(.system(size: 12))
                                    .opacity(0.7)
                            }
                            .foregroundColor(.white.opacity(0.6))
                        }
                    default:
                        Button(action: { isPresented = false }) {
                            Text("Maybe Later")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
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
                    )
            )
            .padding(.horizontal, 40)
            .scaleEffect(isPresented ? 1 : 0.8)
            .opacity(isPresented ? 1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
        }
        .fullScreenCover(isPresented: $showSubscriptionView) {
            SubscriptionView()
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#667eea"))
                .frame(width: 28)

            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white)

            Spacer()
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        PremiumUpgradePrompt(
            isPresented: .constant(true),
            reason: .dailyLimitReached
        )
    }
}
