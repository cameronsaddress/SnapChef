import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var isProcessing = false
    
    enum SubscriptionPlan: String, CaseIterable {
        case monthly = "com.snapchef.premium.monthly"
        case yearly = "com.snapchef.premium.yearly"
        
        var title: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }
        
        var price: String {
            switch self {
            case .monthly: return "$9.99/mo"
            case .yearly: return "$79.99/yr"
            }
        }
        
        var savings: String? {
            switch self {
            case .monthly: return nil
            case .yearly: return "Save 33%"
            }
        }
        
        var description: String {
            switch self {
            case .monthly: return "Billed monthly"
            case .yearly: return "Billed annually"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Text("🚀")
                                .font(.system(size: 60))
                            
                            Text("Unlock Premium")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Create unlimited recipes and access exclusive features")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 40)
                        
                        // Features
                        VStack(spacing: 16) {
                            FeatureRow(icon: "infinity", title: "Unlimited Recipes", description: "No daily limits")
                            FeatureRow(icon: "wand.and.stars", title: "Advanced AI", description: "Better recipe suggestions")
                            FeatureRow(icon: "bookmark.fill", title: "Save Favorites", description: "Build your cookbook")
                            FeatureRow(icon: "chart.bar.fill", title: "Nutrition Tracking", description: "Detailed health insights")
                            FeatureRow(icon: "headphones", title: "Priority Support", description: "Get help faster")
                        }
                        .padding(.horizontal, 20)
                        
                        // Plan selection
                        VStack(spacing: 12) {
                            ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                                PlanCard(
                                    plan: plan,
                                    isSelected: selectedPlan == plan,
                                    onSelect: { selectedPlan = plan }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Subscribe button
                        Button(action: subscribe) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Start Free Trial")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                        .padding(.horizontal, 20)
                        .disabled(isProcessing)
                        
                        // Terms
                        VStack(spacing: 8) {
                            Text("7-day free trial, then \(selectedPlan.price)")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                            
                            HStack(spacing: 16) {
                                Button("Terms of Service") {
                                    openURL("https://snapchef.app/terms")
                                }
                                
                                Button("Privacy Policy") {
                                    openURL("https://snapchef.app/privacy")
                                }
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            
                            Button("Restore Purchases") {
                                restorePurchases()
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 8)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                }
            }
        }
    }
    
    private func subscribe() {
        isProcessing = true
        
        Task {
            do {
                // Request product from App Store
                let products = try await Product.products(for: [selectedPlan.rawValue])
                
                guard let product = products.first else {
                    isProcessing = false
                    return
                }
                
                // Purchase product
                let result = try await product.purchase()
                
                switch result {
                case .success(let verification):
                    // Verify purchase
                    switch verification {
                    case .verified(let transaction):
                        // Update subscription status
                        await transaction.finish()
                        dismiss()
                    case .unverified:
                        // Handle unverified transaction
                        print("Unverified transaction")
                    }
                    
                case .userCancelled:
                    // User cancelled
                    break
                    
                case .pending:
                    // Transaction pending
                    break
                    
                @unknown default:
                    break
                }
                
            } catch {
                print("Purchase error: \(error)")
            }
            
            isProcessing = false
        }
    }
    
    private func restorePurchases() {
        Task {
            do {
                try await AppStore.sync()
                // Check for active subscriptions
                for await result in Transaction.currentEntitlements {
                    switch result {
                    case .verified(let transaction):
                        // Restore subscription
                        await transaction.finish()
                    case .unverified:
                        break
                    }
                }
            } catch {
                print("Restore error: \(error)")
            }
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct PlanCard: View {
    let plan: SubscriptionView.SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.title)
                            .font(.system(size: 18, weight: .semibold))
                        
                        if let savings = plan.savings {
                            Text(savings)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.2))
                                )
                        }
                    }
                    
                    Text(plan.description)
                        .font(.system(size: 14))
                        .opacity(0.7)
                }
                
                Spacer()
                
                Text(plan.price)
                    .font(.system(size: 18, weight: .medium))
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.3))
            }
            .foregroundColor(.white)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.2 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(isSelected ? 0.5 : 0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
    }
}

#Preview {
    SubscriptionView()
}