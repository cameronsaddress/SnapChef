import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var isProcessing = false
    @State private var errorMessage: String?

    enum SubscriptionPlan: String, CaseIterable {
        case monthly = "com.snapchef.premium.monthly"
        case yearly = "com.snapchef.premium.yearly"

        var title: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }

        // Use dynamic pricing from actual products
        func getPrice(from products: [Product]) -> String {
            let productId = self == .monthly ? 
                SubscriptionManager.ProductID.monthly.rawValue : 
                SubscriptionManager.ProductID.yearly.rawValue
            
            if let product = products.first(where: { $0.id == productId }) {
                return product.displayPrice
            }
            
            // Fallback for display purposes only
            return self == .monthly ? "Loading..." : "Loading..."
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
                MagicalBackground()
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
                                    products: subscriptionManager.products,
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
                            Text("7-day free trial, then \(selectedPlan.getPrice(from: subscriptionManager.products))")
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
                            
                            // Abuse protection disclaimer
                            Text("Fair use limits apply to prevent abuse")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.top, 4)
                        }
                        .padding(.bottom, 40)

                        // Error message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
            .onAppear {
                print("🔍 DEBUG: [SubscriptionView] appeared")
                // Load products when view appears
                Task {
                    await subscriptionManager.loadProducts()
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
        errorMessage = nil

        Task {
            do {
                // Find the product
                guard let product = subscriptionManager.products.first(where: { $0.id == selectedPlan.rawValue }) else {
                    errorMessage = "Product not found. Please try again."
                    isProcessing = false
                    return
                }

                // Purchase through SubscriptionManager
                if try await subscriptionManager.purchase(product) != nil {
                    // Success - dismiss view
                    dismiss()
                } else {
                    // User cancelled or pending
                    errorMessage = nil
                }
            } catch {
                errorMessage = "Purchase failed: \(error.localizedDescription)"
                print("Purchase error: \(error)")
            }

            isProcessing = false
        }
    }

    private func restorePurchases() {
        isProcessing = true
        errorMessage = nil

        Task {
            await subscriptionManager.restorePurchases()

            // Check if subscription was restored
            if subscriptionManager.isPremium {
                dismiss()
            } else {
                errorMessage = "No active subscription found"
            }

            isProcessing = false
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
    let products: [Product]
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

                Text(plan.getPrice(from: products))
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
