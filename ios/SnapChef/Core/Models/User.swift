import Foundation

struct User: Codable {
    let id: String
    let email: String?
    let name: String?
    let username: String  // Unique username for social features
    let profileImageURL: String?
    let subscription: Subscription
    let credits: Int
    let deviceId: String
    let createdAt: Date
    let lastLoginAt: Date

    // Social features
    let totalPoints: Int
    let currentStreak: Int
    let longestStreak: Int
    let challengesCompleted: Int
    let recipesShared: Int

    // Privacy settings
    let isProfilePublic: Bool
    let showOnLeaderboard: Bool
}

struct Subscription: Codable {
    let tier: SubscriptionTier
    let status: SubscriptionStatus
    let expiresAt: Date?
    let autoRenew: Bool

    enum SubscriptionTier: String, Codable, CaseIterable {
        case free = "free"
        case basic = "basic"
        case premium = "premium"

        var displayName: String {
            switch self {
            case .free: return "Free"
            case .basic: return "Basic"
            case .premium: return "Premium"
            }
        }

        var price: String {
            switch self {
            case .free: return "$0"
            case .basic: return "$4.99/mo"
            case .premium: return "$9.99/mo"
            }
        }

        var features: [String] {
            switch self {
            case .free:
                return ["1 recipe per day", "Basic ingredients detection"]
            case .basic:
                return ["2 recipes per day", "Advanced detection", "Save favorites"]
            case .premium:
                return ["Unlimited recipes", "Premium features", "Priority support", "Export recipes"]
            }
        }
    }

    enum SubscriptionStatus: String, Codable {
        case active = "active"
        case expired = "expired"
        case cancelled = "cancelled"
        case trial = "trial"
    }
}

struct DeviceInfo: Codable {
    let deviceId: String
    let freeUsesRemaining: Int
    let firstUsedAt: Date
    let lastUsedAt: Date
    let isBlocked: Bool
}
