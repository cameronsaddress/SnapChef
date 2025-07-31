import SwiftUI

struct PremiumUpgradePrompt: View {
    @Binding var isPresented: Bool
    @State private var showSubscriptionView = false
    let reason: UpgradeReason
    
    enum UpgradeReason {
        case dailyLimitReached
        case premiumFeature(String)
        
        var title: String {
            switch self {
            case .dailyLimitReached:
                return "Daily Limit Reached"
            case .premiumFeature(let feature):
                return "Premium Feature"
            }
        }
        
        var message: String {
            switch self {
            case .dailyLimitReached:
                return "You've used all 3 free recipes today. Upgrade to Premium for unlimited recipes!"
            case .premiumFeature(let feature):
                return "\(feature) is a premium feature. Upgrade to unlock all features!"
            }
        }
        
        var icon: String {
            switch self {
            case .dailyLimitReached:
                return "hourglass"
            case .premiumFeature:
                return "lock.fill"
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
                Text(reason.message)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Benefits
                VStack(alignment: .leading, spacing: 12) {
                    BenefitRow(icon: "infinity", text: "Unlimited recipes every day")
                    BenefitRow(icon: "sparkles", text: "Advanced AI features")
                    BenefitRow(icon: "bookmark.fill", text: "Save unlimited favorites")
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
                
                // Continue with limited
                if case .dailyLimitReached = reason {
                    Button(action: { isPresented = false }) {
                        Text("Wait until tomorrow")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 8)
                }
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