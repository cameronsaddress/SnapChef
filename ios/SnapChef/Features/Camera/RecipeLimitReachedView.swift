import SwiftUI

struct RecipeLimitReachedView: View {
    @Binding var isPresented: Bool
    @StateObject private var usageTracker = UsageTracker.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var userLifecycleManager = UserLifecycleManager.shared
    @State private var showingSubscriptionView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(hex: "#FF0050"),
                        Color(hex: "#00F2EA")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Icon and title
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.15))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                        
                        Text("Daily Limit Reached")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("You've used all your recipes for today")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    
                    // Usage information
                    VStack(spacing: 15) {
                        HStack {
                            Text("Recipes used today:")
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text("\(usageTracker.getTodayRecipeCount()) / \(userLifecycleManager.dailyRecipeLimit)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        
                        HStack {
                            Text("Resets in:")
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text(timeUntilMidnight())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        
                        HStack {
                            Text("Current plan:")
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text(userLifecycleManager.currentPhase.displayName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(20)
                    .background(.white.opacity(0.1))
                    .cornerRadius(15)
                    
                    // Upgrade benefits
                    VStack(spacing: 15) {
                        Text("Upgrade to Premium")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            BenefitRow(icon: "infinity", text: "Unlimited recipes daily")
                            BenefitRow(icon: "wand.and.stars", text: "AI Detective feature")
                            BenefitRow(icon: "video.fill", text: "TikTok video exports")
                            BenefitRow(icon: "sparkles", text: "Advanced AI features")
                        }
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            showingSubscriptionView = true
                        }) {
                            Text("Upgrade Now")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "#FF0050"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(.white)
                                .cornerRadius(28)
                        }
                        
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Wait Until Tomorrow")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(.white.opacity(0.2))
                                .cornerRadius(28)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
    }
    
    private func timeUntilMidnight() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Get tomorrow at midnight
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           let midnight = calendar.startOfDay(for: tomorrow) as Date? {
            let timeInterval = midnight.timeIntervalSince(now)
            let hours = Int(timeInterval) / 3600
            let minutes = (Int(timeInterval) % 3600) / 60
            
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
        
        return "Soon"
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 30)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.95))
            
            Spacer()
        }
    }
}

#Preview {
    RecipeLimitReachedView(isPresented: .constant(true))
}