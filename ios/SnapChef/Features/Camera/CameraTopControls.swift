import SwiftUI

struct CameraTopControls: View {
    @Binding var selectedTab: Int
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var userLifecycleManager: UserLifecycleManager
    @EnvironmentObject var usageTracker: UsageTracker
    @EnvironmentObject var paywallTriggerManager: PaywallTriggerManager
    @EnvironmentObject var deviceManager: DeviceManager
    
    @Binding var showPremiumPrompt: Bool
    @Binding var premiumPromptReason: PremiumUpgradePrompt.UpgradeReason
    
    var body: some View {
        VStack(spacing: 12) {
            // Honeymoon banner (if applicable) - only show if animations are enabled
            if userLifecycleManager.currentPhase == .honeymoon && deviceManager.animationsEnabled {
                HoneymoonBanner()
            }

            // Top controls with usage counter
            HStack {
                // Close button
                Button(action: {
                    // Try dismiss first (for modal presentation)
                    dismiss()
                    // Also set tab to 0 (for tab presentation)
                    selectedTab = 0
                }) {
                    ZStack {
                        BlurredCircle()

                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                }

                Spacer()

                // Usage counter - only show when user has limits (not unlimited)
                if !subscriptionManager.isPremium {
                    let dailyLimits = userLifecycleManager.getDailyLimits()
                    if dailyLimits.recipes != -1 {
                        UsageCounterView.recipes(
                            current: usageTracker.todaysUsage.recipeCount,
                            limit: dailyLimits.recipes
                        )
                        .onTapGesture {
                            // Check if should show paywall
                            if paywallTriggerManager.shouldShowPaywall(for: .recipeLimitReached) {
                                showPremiumPrompt = true
                                premiumPromptReason = .dailyLimitReached
                            }
                        }
                    }
                }

                Spacer()

                // AI Assistant - only show if animations are enabled
                if deviceManager.animationsEnabled {
                    AIAssistantIndicator()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
        }
    }
}

#Preview {
    CameraTopControls(
        selectedTab: .constant(1),
        showPremiumPrompt: .constant(false),
        premiumPromptReason: .constant(.dailyLimitReached)
    )
    .environmentObject(SubscriptionManager.shared)
    .environmentObject(UserLifecycleManager.shared)
    .environmentObject(UsageTracker.shared)
    .environmentObject(PaywallTriggerManager.shared)
    .environmentObject(DeviceManager())
}