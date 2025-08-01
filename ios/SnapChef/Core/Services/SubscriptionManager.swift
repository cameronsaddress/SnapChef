import Foundation
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    @Published var isPremium = false
    @Published var isLoading = false
    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var subscriptionStatus: SubscriptionStatus = .none
    
    // MARK: - Subscription Status
    enum SubscriptionStatus {
        case none
        case active(product: Product, expirationDate: Date?)
        case expired
        case inGracePeriod
        
        var isActive: Bool {
            switch self {
            case .active, .inGracePeriod:
                return true
            case .none, .expired:
                return false
            }
        }
    }
    
    // MARK: - Product Identifiers
    enum ProductID: String, CaseIterable {
        case monthly = "com.snapchef.premium.monthly"
        case yearly = "com.snapchef.premium.yearly"
    }
    
    // MARK: - Properties
    private var updateListenerTask: Task<Void, Error>?
    private let productIDs = ProductID.allCases.map { $0.rawValue }
    
    // MARK: - Initialization
    private init() {
        // Start listening for transactions
        updateListenerTask = listenForTransactions()
        
        // Load products and check subscription status
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    func loadProducts() async {
        isLoading = true
        
        do {
            // Fetch products from App Store
            print("Attempting to load products with IDs: \(productIDs)")
            products = try await Product.products(for: Set(productIDs))
            print("Loaded \(products.count) products")
            for product in products {
                print("Product loaded: \(product.id) - \(product.displayName) - \(product.displayPrice)")
            }
        } catch {
            print("Failed to load products: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        // Attempt purchase
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Check verification
            let transaction = try checkVerified(verification)
            
            // Update subscription status
            await updateSubscriptionStatus()
            
            // Finish transaction
            await transaction.finish()
            
            return transaction
            
        case .userCancelled:
            print("User cancelled purchase")
            return nil
            
        case .pending:
            print("Purchase pending")
            return nil
            
        @unknown default:
            print("Unknown purchase result")
            return nil
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        do {
            // Sync with App Store
            try await AppStore.sync()
            
            // Update subscription status
            await updateSubscriptionStatus()
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }
    
    // MARK: - Update Subscription Status
    func updateSubscriptionStatus() async {
        var highestStatus: Product.SubscriptionInfo.Status?
        var highestProduct: Product?
        
        // Check all subscription statuses
        for product in products {
            guard let status = try? await product.subscription?.status.first else { continue }
            
            switch status.state {
            case .subscribed, .inGracePeriod:
                if highestStatus == nil {
                    highestStatus = status
                    highestProduct = product
                }
            default:
                break
            }
        }
        
        // Update subscription status
        if let status = highestStatus, let product = highestProduct {
            switch status.state {
            case .subscribed:
                subscriptionStatus = .active(
                    product: product,
                    expirationDate: nil // Will be set from transaction
                )
                isPremium = true
                
            case .inGracePeriod:
                subscriptionStatus = .inGracePeriod
                isPremium = true
                
            case .expired:
                subscriptionStatus = .expired
                isPremium = false
                
            default:
                subscriptionStatus = .none
                isPremium = false
            }
        } else {
            subscriptionStatus = .none
            isPremium = false
        }
        
        // Update purchased subscriptions
        purchasedSubscriptions = []
        for product in products {
            if let statuses = try? await product.subscription?.status {
                for status in statuses {
                    if status.state == .subscribed || status.state == .inGracePeriod {
                        purchasedSubscriptions.append(product)
                        break
                    }
                }
            }
        }
        
        print("Subscription status updated: \(subscriptionStatus)")
    }
    
    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Listen for transactions
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    // Update subscription status
                    await self.updateSubscriptionStatus()
                    
                    // Finish transaction
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }
    
    // MARK: - Entitlement Checking
    func hasActiveSubscription() -> Bool {
        return isPremium
    }
    
    func canAccessPremiumFeature(_ feature: PremiumFeature) -> Bool {
        switch feature {
        case .unlimitedRecipes:
            return isPremium
        case .advancedAI:
            return isPremium
        case .nutritionTracking:
            return isPremium
        case .prioritySupport:
            return isPremium
        case .saveRecipes:
            // Allow limited saves for free users
            return true
        case .premiumChallenges:
            return isPremium
        case .doubleRewards:
            return isPremium
        case .exclusiveBadges:
            return isPremium
        }
    }
    
    // MARK: - Premium Challenge Management
    
    /// Get available premium challenges
    func getPremiumChallenges() -> [String] {
        guard isPremium else { return [] }
        
        return [
            "Master Chef Marathon",
            "Michelin Star Week",
            "Global Cuisine Tour",
            "Zero Waste Champion",
            "Nutrition Perfectionist",
            "Speed Demon Deluxe",
            "Social Butterfly Supreme"
        ]
    }
    
    /// Check if a challenge is premium-only
    func isPremiumChallenge(_ challengeTitle: String) -> Bool {
        return getPremiumChallenges().contains(challengeTitle)
    }
    
    /// Get reward multiplier for premium users
    func getPremiumRewardMultiplier() -> Double {
        return isPremium ? 2.0 : 1.0
    }
    
    // MARK: - Free Tier Limits
    func getRemainingDailyRecipes() -> Int {
        guard !isPremium else { return Int.max }
        
        // Check today's recipe count from UserDefaults
        let today = Calendar.current.startOfDay(for: Date())
        let lastResetDate = UserDefaults.standard.object(forKey: "lastRecipeResetDate") as? Date ?? Date.distantPast
        let recipeCount = UserDefaults.standard.integer(forKey: "dailyRecipeCount")
        
        if Calendar.current.isDate(lastResetDate, inSameDayAs: today) {
            return max(0, 10 - recipeCount) // 10 free recipes per day (for testing)
        } else {
            // Reset count for new day
            UserDefaults.standard.set(today, forKey: "lastRecipeResetDate")
            UserDefaults.standard.set(0, forKey: "dailyRecipeCount")
            return 10
        }
    }
    
    func incrementDailyRecipeCount() {
        let count = UserDefaults.standard.integer(forKey: "dailyRecipeCount")
        UserDefaults.standard.set(count + 1, forKey: "dailyRecipeCount")
    }
    
    // MARK: - Price Formatting
    func formattedPrice(for product: Product) -> String {
        return product.displayPrice
    }
    
    func formattedIntroductoryPrice(for product: Product) -> String? {
        guard let intro = product.subscription?.introductoryOffer else { return nil }
        
        switch intro.type {
        case .introductory:
            return "\(intro.period.value) \(intro.period.unit) free trial"
        case .promotional:
            return intro.displayPrice
        default:
            return nil
        }
    }
}

// MARK: - Premium Features
enum PremiumFeature {
    case unlimitedRecipes
    case advancedAI
    case nutritionTracking
    case prioritySupport
    case saveRecipes
    case premiumChallenges
    case doubleRewards
    case exclusiveBadges
}

// MARK: - Subscription Period Extension
extension Product.SubscriptionPeriod.Unit {
    var description: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "period"
        }
    }
}