import Foundation
import SwiftUI

// MARK: - Reward Tiers
enum RewardTier: String, CaseIterable, Codable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"

    var multiplier: Double {
        switch self {
        case .bronze: return 1.0
        case .silver: return 1.5
        case .gold: return 2.0
        }
    }

    var color: Color {
        switch self {
        case .bronze: return Color(hex: "#CD7F32")
        case .silver: return Color(hex: "#C0C0C0")
        case .gold: return Color(hex: "#FFD700")
        }
    }

    var icon: String {
        switch self {
        case .bronze: return "medal.fill"
        case .silver: return "star.circle.fill"
        case .gold: return "crown.fill"
        }
    }

    var minimumScore: Double {
        switch self {
        case .bronze: return 0.5    // 50% completion
        case .silver: return 0.8    // 80% completion
        case .gold: return 1.0      // 100% completion
        }
    }
}

// MARK: - Reward Types
enum RewardType: String, CaseIterable, Codable {
    case chefCoins = "Chef Coins"
    case experiencePoints = "XP"
    case badge = "Badge"
    case title = "Title"
    case theme = "Theme"
    case sticker = "Sticker"
    case recipeUnlock = "Recipe Unlock"
    case booster = "Booster"

    var icon: String {
        switch self {
        case .chefCoins: return "dollarsign.circle.fill"
        case .experiencePoints: return "star.fill"
        case .badge: return "shield.fill"
        case .title: return "crown.fill"
        case .theme: return "paintbrush.fill"
        case .sticker: return "face.smiling.fill"
        case .recipeUnlock: return "book.fill"
        case .booster: return "bolt.fill"
        }
    }
}

// MARK: - Reward Model
struct Reward: Identifiable, Codable {
    var id = UUID()
    let type: RewardType
    let tier: RewardTier
    let value: Int
    let name: String
    let description: String
    let iconName: String?
    let unlockableId: String?
    let timestamp: Date
    var isClaimed: Bool = false

    var displayValue: String {
        switch type {
        case .chefCoins:
            return "+\(value) Chef Coins"
        case .experiencePoints:
            return "+\(value) XP"
        default:
            return name
        }
    }
}

// MARK: - Reward System Manager
@MainActor
class RewardSystem: ObservableObject {
    static let shared = RewardSystem()

    @Published var pendingRewards: [Reward] = []
    @Published var claimedRewards: [Reward] = []
    @Published var isShowingRewardAnimation = false
    @Published var currentRewardAnimation: Reward?

    private let gamificationManager = GamificationManager.shared
    private let chefCoinsManager = ChefCoinsManager.shared

    private init() {
        loadRewards()
    }

    // MARK: - Challenge Completion Rewards

    /// Calculate rewards based on challenge completion
    func calculateChallengeRewards(for challenge: Challenge, completionScore: Double) -> [Reward] {
        var rewards: [Reward] = []
        let tier = determineTier(for: completionScore)

        // Base coins reward
        let baseCoins = challenge.points
        let tierMultiplier = tier.multiplier
        let totalCoins = Int(Double(baseCoins) * tierMultiplier)

        rewards.append(Reward(
            type: .chefCoins,
            tier: tier,
            value: totalCoins,
            name: "Challenge Coins",
            description: "Coins earned from \(challenge.title)",
            iconName: "dollarsign.circle.fill",
            unlockableId: nil,
            timestamp: Date()
        ))

        // Experience points
        let xpValue = Int(Double(baseCoins) * 0.5 * tierMultiplier)
        rewards.append(Reward(
            type: .experiencePoints,
            tier: tier,
            value: xpValue,
            name: "Experience Points",
            description: "XP earned from challenge completion",
            iconName: "star.fill",
            unlockableId: nil,
            timestamp: Date()
        ))

        // Special rewards based on tier
        if tier == .gold {
            // Gold tier gets special rewards
            // Badge reward based on challenge type
            let badgeName = "\(challenge.type.rawValue) Champion"
            rewards.append(Reward(
                type: .badge,
                tier: .gold,
                value: 1,
                name: badgeName,
                description: "Exclusive gold tier badge",
                iconName: "shield.fill",
                unlockableId: "badge_\(badgeName.lowercased().replacingOccurrences(of: " ", with: "_"))",
                timestamp: Date()
            ))

            // Title reward
            let title = "Gold \(challenge.type.rawValue) Master"
            rewards.append(Reward(
                type: .title,
                tier: .gold,
                    value: 1,
                    name: title,
                    description: "Prestigious title for perfect completion",
                    iconName: "crown.fill",
                    unlockableId: "title_\(title.lowercased().replacingOccurrences(of: " ", with: "_"))",
                    timestamp: Date()
                ))
            }

        // Challenge-specific unlockables
        // Create unlockable based on challenge difficulty
        if challenge.difficulty.rawValue >= 3 { // Hard or above
            let unlockable = "Premium \(challenge.type.rawValue) Pack"
            let unlockableTier = tier == .bronze ? .silver : tier // Bronze gets silver tier unlockable
            rewards.append(createUnlockableReward(for: unlockable, tier: unlockableTier))
        }

        return rewards
    }

    /// Determine reward tier based on completion score
    private func determineTier(for score: Double) -> RewardTier {
        if score >= RewardTier.gold.minimumScore {
            return .gold
        } else if score >= RewardTier.silver.minimumScore {
            return .silver
        } else {
            return .bronze
        }
    }

    /// Create unlockable reward based on type
    private func createUnlockableReward(for unlockable: String, tier: RewardTier) -> Reward {
        let lowercased = unlockable.lowercased()

        if lowercased.contains("theme") {
            return Reward(
                type: .theme,
                tier: tier,
                value: 1,
                name: unlockable,
                description: "Unlock a new visual theme",
                iconName: "paintbrush.fill",
                unlockableId: "theme_\(lowercased.replacingOccurrences(of: " ", with: "_"))",
                timestamp: Date()
            )
        } else if lowercased.contains("sticker") {
            return Reward(
                type: .sticker,
                tier: tier,
                value: 1,
                name: unlockable,
                description: "New stickers for your recipes",
                iconName: "face.smiling.fill",
                unlockableId: "sticker_pack_\(lowercased.replacingOccurrences(of: " ", with: "_"))",
                timestamp: Date()
            )
        } else if lowercased.contains("recipe") {
            return Reward(
                type: .recipeUnlock,
                tier: tier,
                value: 1,
                name: unlockable,
                description: "Exclusive recipe collection",
                iconName: "book.fill",
                unlockableId: "recipe_pack_\(lowercased.replacingOccurrences(of: " ", with: "_"))",
                timestamp: Date()
            )
        } else {
            return Reward(
                type: .booster,
                tier: tier,
                value: 1,
                name: unlockable,
                description: "Special power-up for challenges",
                iconName: "bolt.fill",
                unlockableId: "booster_\(lowercased.replacingOccurrences(of: " ", with: "_"))",
                timestamp: Date()
            )
        }
    }

    // MARK: - Reward Management

    /// Award rewards for challenge completion
    func awardChallengeRewards(for challenge: Challenge, completionScore: Double) {
        let rewards = calculateChallengeRewards(for: challenge, completionScore: completionScore)

        for reward in rewards {
            pendingRewards.append(reward)

            // Process immediate rewards
            switch reward.type {
            case .chefCoins:
                chefCoinsManager.earnCoins(reward.value, reason: "Challenge: \(challenge.title)")
            case .experiencePoints:
                gamificationManager.awardPoints(reward.value, reason: "Challenge: \(challenge.title)")
            default:
                // Other rewards are stored for claiming
                break
            }
        }

        // Save rewards
        saveRewards()

        // Trigger celebration animation
        if let firstReward = rewards.first {
            showRewardAnimation(for: firstReward)
        }
    }

    /// Claim a pending reward
    func claimReward(_ reward: Reward) {
        guard let index = pendingRewards.firstIndex(where: { $0.id == reward.id }) else { return }

        var claimedReward = pendingRewards[index]
        claimedReward.isClaimed = true

        pendingRewards.remove(at: index)
        claimedRewards.append(claimedReward)

        // Apply the reward
        applyReward(claimedReward)

        // Save state
        saveRewards()
    }

    /// Apply a reward to the user's account
    private func applyReward(_ reward: Reward) {
        switch reward.type {
        case .chefCoins:
            chefCoinsManager.earnCoins(reward.value, reason: reward.name)
        case .experiencePoints:
            gamificationManager.awardPoints(reward.value, reason: reward.name)
        case .badge:
            gamificationManager.awardBadge(reward.name)
        case .title:
            // Store title in user preferences
            var unlockedTitles = UserDefaults.standard.stringArray(forKey: "unlockedTitles") ?? []
            unlockedTitles.append(reward.name)
            UserDefaults.standard.set(unlockedTitles, forKey: "unlockedTitles")
        case .theme, .sticker, .recipeUnlock, .booster:
            // Store unlockable in user preferences
            if let unlockableId = reward.unlockableId {
                var unlockedItems = UserDefaults.standard.stringArray(forKey: "unlockedItems") ?? []
                unlockedItems.append(unlockableId)
                UserDefaults.standard.set(unlockedItems, forKey: "unlockedItems")
            }
        }
    }

    // MARK: - Streak Rewards

    /// Award streak rewards
    func awardStreakReward(days: Int) {
        let coinsReward: Int
        let tier: RewardTier

        switch days {
        case 3:
            coinsReward = 50
            tier = .bronze
        case 7:
            coinsReward = 150
            tier = .silver
        case 14:
            coinsReward = 300
            tier = .silver
        case 30:
            coinsReward = 1_000
            tier = .gold
        default:
            return
        }

        let reward = Reward(
            type: .chefCoins,
            tier: tier,
            value: coinsReward,
            name: "\(days)-Day Streak Bonus",
            description: "Bonus for maintaining a \(days)-day streak",
            iconName: "flame.fill",
            unlockableId: nil,
            timestamp: Date()
        )

        pendingRewards.append(reward)
        chefCoinsManager.earnCoins(coinsReward, reason: "\(days)-day streak")
        showRewardAnimation(for: reward)
        saveRewards()
    }

    // MARK: - Animation

    /// Show reward animation
    func showRewardAnimation(for reward: Reward) {
        currentRewardAnimation = reward
        isShowingRewardAnimation = true

        // Auto-hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.isShowingRewardAnimation = false
            self?.currentRewardAnimation = nil
        }
    }

    // MARK: - Persistence

    /// Save rewards to UserDefaults
    private func saveRewards() {
        let encoder = JSONEncoder()

        if let pendingData = try? encoder.encode(pendingRewards) {
            UserDefaults.standard.set(pendingData, forKey: "pendingRewards")
        }

        if let claimedData = try? encoder.encode(claimedRewards) {
            UserDefaults.standard.set(claimedData, forKey: "claimedRewards")
        }
    }

    /// Load rewards from UserDefaults
    private func loadRewards() {
        let decoder = JSONDecoder()

        if let pendingData = UserDefaults.standard.data(forKey: "pendingRewards"),
           let pending = try? decoder.decode([Reward].self, from: pendingData) {
            pendingRewards = pending
        }

        if let claimedData = UserDefaults.standard.data(forKey: "claimedRewards"),
           let claimed = try? decoder.decode([Reward].self, from: claimedData) {
            claimedRewards = claimed
        }
    }

    // MARK: - Analytics

    /// Track reward analytics
    func trackRewardClaimed(_ reward: Reward) {
        // Analytics implementation would go here
        print("Reward claimed: \(reward.type.rawValue) - \(reward.name)")
    }
}

// MARK: - Reward Extensions

extension Reward {
    /// Check if reward has been unlocked
    var isUnlocked: Bool {
        switch type {
        case .badge:
            // Check if badge is unlocked
            return true
        case .title:
            let unlockedTitles = UserDefaults.standard.stringArray(forKey: "unlockedTitles") ?? []
            return unlockedTitles.contains(name)
        case .theme, .sticker, .recipeUnlock, .booster:
            if let unlockableId = unlockableId {
                let unlockedItems = UserDefaults.standard.stringArray(forKey: "unlockedItems") ?? []
                return unlockedItems.contains(unlockableId)
            }
            return false
        case .chefCoins, .experiencePoints:
            return true
        }
    }
}
