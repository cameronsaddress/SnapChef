import Foundation
import SwiftUI
import Combine

// MARK: - Chef Coins Transaction
struct ChefCoinsTransaction: Identifiable, Codable {
    var id = UUID()
    let amount: Int
    let type: TransactionType
    let reason: String
    let timestamp: Date
    let balanceAfter: Int

    enum TransactionType: String, Codable {
        case earned = "Earned"
        case spent = "Spent"
        case bonus = "Bonus"
        case refund = "Refund"

        var color: Color {
            switch self {
            case .earned, .bonus:
                return .green
            case .spent:
                return .red
            case .refund:
                return .blue
            }
        }

        var icon: String {
            switch self {
            case .earned:
                return "plus.circle.fill"
            case .spent:
                return "minus.circle.fill"
            case .bonus:
                return "gift.fill"
            case .refund:
                return "arrow.uturn.backward.circle.fill"
            }
        }
    }
}

// MARK: - Chef Coins Package
struct ChefCoinsPackage: Identifiable {
    let id = UUID()
    let coins: Int
    let price: Double
    let bonusCoins: Int
    let isBestValue: Bool
    let productId: String

    var totalCoins: Int {
        coins + bonusCoins
    }

    var pricePerCoin: Double {
        price / Double(totalCoins)
    }

    var bonusPercentage: Int {
        guard coins > 0 else { return 0 }
        return Int((Double(bonusCoins) / Double(coins)) * 100)
    }
}

// MARK: - Chef Coins Manager
@MainActor
class ChefCoinsManager: ObservableObject {
    static let shared = ChefCoinsManager()

    @Published var currentBalance: Int = 0
    @Published var transactions: [ChefCoinsTransaction] = []
    @Published var lifetimeEarned: Int = 0
    @Published var lifetimeSpent: Int = 0
    @Published var isProcessingTransaction = false

    // Coin packages for purchase
    let coinPackages: [ChefCoinsPackage] = [
        ChefCoinsPackage(coins: 100, price: 0.99, bonusCoins: 0, isBestValue: false, productId: "com.snapchef.coins.100"),
        ChefCoinsPackage(coins: 500, price: 4.99, bonusCoins: 50, isBestValue: false, productId: "com.snapchef.coins.500"),
        ChefCoinsPackage(coins: 1_000, price: 9.99, bonusCoins: 200, isBestValue: true, productId: "com.snapchef.coins.1000"),
        ChefCoinsPackage(coins: 5_000, price: 49.99, bonusCoins: 1_500, isBestValue: false, productId: "com.snapchef.coins.5000")
    ]

    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadCoinsData()
        setupObservers()
    }

    // MARK: - Coin Management

    /// Earn coins from various activities
    func earnCoins(_ amount: Int, reason: String, isBonus: Bool = false) {
        guard amount > 0 else { return }

        isProcessingTransaction = true

        currentBalance += amount
        lifetimeEarned += amount

        let transaction = ChefCoinsTransaction(
            amount: amount,
            type: isBonus ? .bonus : .earned,
            reason: reason,
            timestamp: Date(),
            balanceAfter: currentBalance
        )

        transactions.insert(transaction, at: 0)

        // Keep only last 100 transactions
        if transactions.count > 100 {
            transactions = Array(transactions.prefix(100))
        }

        saveCoinsData()
        isProcessingTransaction = false

        // Send notification for significant earnings
        if amount >= 100 {
            sendCoinNotification(amount: amount, reason: reason)
        }
    }

    /// Spend coins on items
    func spendCoins(_ amount: Int, on item: String) -> Bool {
        guard amount > 0, currentBalance >= amount else {
            return false
        }

        isProcessingTransaction = true

        currentBalance -= amount
        lifetimeSpent += amount

        let transaction = ChefCoinsTransaction(
            amount: amount,
            type: .spent,
            reason: item,
            timestamp: Date(),
            balanceAfter: currentBalance
        )

        transactions.insert(transaction, at: 0)

        // Keep only last 100 transactions
        if transactions.count > 100 {
            transactions = Array(transactions.prefix(100))
        }

        saveCoinsData()
        isProcessingTransaction = false

        return true
    }

    /// Check if user can afford an item
    func canAfford(_ cost: Int) -> Bool {
        return currentBalance >= cost
    }

    /// Refund coins
    func refundCoins(_ amount: Int, reason: String) {
        guard amount > 0 else { return }

        currentBalance += amount
        lifetimeSpent -= amount

        let transaction = ChefCoinsTransaction(
            amount: amount,
            type: .refund,
            reason: reason,
            timestamp: Date(),
            balanceAfter: currentBalance
        )

        transactions.insert(transaction, at: 0)
        saveCoinsData()
    }

    // MARK: - Coin Earning Activities

    /// Daily login bonus
    func awardDailyBonus() {
        let lastBonusDate = userDefaults.object(forKey: "lastDailyBonusDate") as? Date ?? .distantPast
        let calendar = Calendar.current

        if !calendar.isDateInToday(lastBonusDate) {
            let bonusAmount = calculateDailyBonus()
            earnCoins(bonusAmount, reason: "Daily Login Bonus", isBonus: true)
            userDefaults.set(Date(), forKey: "lastDailyBonusDate")
        }
    }

    /// Calculate daily bonus based on streak
    private func calculateDailyBonus() -> Int {
        let streak = GamificationManager.shared.userStats.currentStreak

        switch streak {
        case 0...2:
            return 10
        case 3...6:
            return 20
        case 7...13:
            return 30
        case 14...29:
            return 50
        default:
            return 100
        }
    }

    /// Award coins for recipe creation
    func awardRecipeCreationCoins(recipeQuality: RecipeQuality) {
        let coins: Int
        let reason: String

        switch recipeQuality {
        case .basic:
            coins = 5
            reason = "Recipe Created"
        case .good:
            coins = 10
            reason = "Good Recipe Created"
        case .excellent:
            coins = 20
            reason = "Excellent Recipe Created"
        case .perfect:
            coins = 50
            reason = "Perfect Recipe Created!"
        }

        earnCoins(coins, reason: reason)
    }

    /// Award coins for social actions
    func awardSocialCoins(action: SocialAction) {
        let coins: Int
        let reason: String

        switch action {
        case .share:
            coins = 5
            reason = "Recipe Shared"
        case .like:
            coins = 2
            reason = "Recipe Liked"
        case .comment:
            coins = 3
            reason = "Comment Posted"
        case .follow:
            coins = 10
            reason = "New Follower"
        }

        earnCoins(coins, reason: reason)
    }

    // MARK: - Purchase Management

    /// Purchase coins package
    func purchaseCoins(package: ChefCoinsPackage) async -> Bool {
        // In a real app, this would integrate with StoreKit
        isProcessingTransaction = true

        do {
            // Simulate purchase delay
            try await Task.sleep(nanoseconds: 1_000_000_000)

            let totalCoins = package.totalCoins
            earnCoins(totalCoins, reason: "Purchased \(package.coins) + \(package.bonusCoins) bonus coins")

            isProcessingTransaction = false
            return true
        } catch {
            isProcessingTransaction = false
            return false
        }
    }

    // MARK: - Analytics

    /// Get spending analytics
    func getSpendingAnalytics() -> SpendingAnalytics {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!

        let weeklySpent = transactions
            .filter { $0.type == .spent && $0.timestamp > weekAgo }
            .reduce(0) { $0 + $1.amount }

        let monthlySpent = transactions
            .filter { $0.type == .spent && $0.timestamp > monthAgo }
            .reduce(0) { $0 + $1.amount }

        let weeklyEarned = transactions
            .filter { ($0.type == .earned || $0.type == .bonus) && $0.timestamp > weekAgo }
            .reduce(0) { $0 + $1.amount }

        let monthlyEarned = transactions
            .filter { ($0.type == .earned || $0.type == .bonus) && $0.timestamp > monthAgo }
            .reduce(0) { $0 + $1.amount }

        return SpendingAnalytics(
            weeklySpent: weeklySpent,
            monthlySpent: monthlySpent,
            weeklyEarned: weeklyEarned,
            monthlyEarned: monthlyEarned,
            lifetimeEarned: lifetimeEarned,
            lifetimeSpent: lifetimeSpent
        )
    }

    // MARK: - Persistence

    private func saveCoinsData() {
        userDefaults.set(currentBalance, forKey: "chefCoinsBalance")
        userDefaults.set(lifetimeEarned, forKey: "chefCoinsLifetimeEarned")
        userDefaults.set(lifetimeSpent, forKey: "chefCoinsLifetimeSpent")

        if let encoded = try? JSONEncoder().encode(transactions) {
            userDefaults.set(encoded, forKey: "chefCoinsTransactions")
        }
    }

    private func loadCoinsData() {
        currentBalance = userDefaults.integer(forKey: "chefCoinsBalance")
        lifetimeEarned = userDefaults.integer(forKey: "chefCoinsLifetimeEarned")
        lifetimeSpent = userDefaults.integer(forKey: "chefCoinsLifetimeSpent")

        if currentBalance == 0 && lifetimeEarned == 0 {
            // New user bonus
            earnCoins(50, reason: "Welcome Bonus!", isBonus: true)
        }

        if let data = userDefaults.data(forKey: "chefCoinsTransactions"),
           let decoded = try? JSONDecoder().decode([ChefCoinsTransaction].self, from: data) {
            transactions = decoded
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        // Listen for app becoming active to check daily bonus
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.awardDailyBonus()
            }
            .store(in: &cancellables)
    }

    // MARK: - Notifications

    private func sendCoinNotification(amount: Int, reason: String) {
        // In a real app, this would send a local notification
        print("Coins earned: +\(amount) - \(reason)")
    }
}

// MARK: - Supporting Types

enum RecipeQuality: String {
    case basic = "basic"
    case good = "good"
    case excellent = "excellent"
    case perfect = "perfect"
}

enum SocialAction {
    case share
    case like
    case comment
    case follow
}

struct SpendingAnalytics {
    let weeklySpent: Int
    let monthlySpent: Int
    let weeklyEarned: Int
    let monthlyEarned: Int
    let lifetimeEarned: Int
    let lifetimeSpent: Int
}

// MARK: - Mock Data

extension ChefCoinsManager {
    func loadMockTransactions() {
        transactions = [
            ChefCoinsTransaction(
                amount: 100,
                type: .earned,
                reason: "Challenge: Speed Chef",
                timestamp: Date().addingTimeInterval(-3_600),
                balanceAfter: 500
            ),
            ChefCoinsTransaction(
                amount: 50,
                type: .spent,
                reason: "Halloween Theme",
                timestamp: Date().addingTimeInterval(-7_200),
                balanceAfter: 400
            ),
            ChefCoinsTransaction(
                amount: 20,
                type: .bonus,
                reason: "Daily Login Bonus",
                timestamp: Date().addingTimeInterval(-86_400),
                balanceAfter: 450
            ),
            ChefCoinsTransaction(
                amount: 10,
                type: .earned,
                reason: "Recipe Created",
                timestamp: Date().addingTimeInterval(-172_800),
                balanceAfter: 430
            )
        ]
    }
}
