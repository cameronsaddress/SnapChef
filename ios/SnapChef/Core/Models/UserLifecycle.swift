//
//  UserLifecycle.swift
//  SnapChef
//
//  Created by Claude on 2025-01-16.
//  Progressive Premium Models for User Lifecycle Management
//

import Foundation

// MARK: - User Lifecycle Phase

/// User lifecycle phases for progressive premium strategy
public enum UserPhase: String, CaseIterable, Sendable {
    case honeymoon    // Day 1-7: Everything free
    case trial        // Day 8-30: Progressive limits
    case standard     // Day 31+: Full restrictions

    /// Human-readable display name for the phase
    public var displayName: String {
        switch self {
        case .honeymoon:
            return "Premium Preview"
        case .trial:
            return "Trial Period"
        case .standard:
            return "Free Tier"
        }
    }

    /// Description of what the user gets in this phase
    public var description: String {
        switch self {
        case .honeymoon:
            return "Enjoy unlimited access to all features"
        case .trial:
            return "Limited access to premium features"
        case .standard:
            return "Basic features with daily limits"
        }
    }

    /// Number of days this phase lasts
    public var duration: Int {
        switch self {
        case .honeymoon:
            return 7
        case .trial:
            return 23 // Days 8-30
        case .standard:
            return Int.max // Forever
        }
    }
}

// MARK: - Subscription Tier

/// Available subscription tiers in the progressive premium system
public enum UserLifecycleSubscriptionTier: String, CaseIterable, Sendable {
    case starter      // Free tier with limits
    case premium      // Paid tier with everything

    /// Human-readable display name for the tier
    public var displayName: String {
        switch self {
        case .starter:
            return "Starter"
        case .premium:
            return "Premium"
        }
    }

    /// Detailed description of tier benefits
    public var description: String {
        switch self {
        case .starter:
            return "Basic features with daily limits"
        case .premium:
            return "Unlimited access to all features"
        }
    }

    /// Monthly price for this tier (in USD)
    public var monthlyPrice: Double {
        switch self {
        case .starter:
            return 0.0
        case .premium:
            return 9.99
        }
    }

    /// Annual price for this tier (in USD)
    public var annualPrice: Double {
        switch self {
        case .starter:
            return 0.0
        case .premium:
            return 79.99 // Save 33%
        }
    }
}

// MARK: - Daily Limits

/// Daily usage limits for different tiers and phases
public struct DailyLimits: Sendable, Equatable {
    public let recipes: Int               // Starter: 3, Premium: Unlimited (-1)
    public let videos: Int                // Starter: 1, Premium: Unlimited (-1)
    public let premiumEffects: Bool       // Starter: false, Premium: true
    public let challengeMultiplier: Double // Starter: 1.0x, Premium: 2.0x

    /// Initializes daily limits with specified values
    public init(
        recipes: Int,
        videos: Int,
        premiumEffects: Bool,
        challengeMultiplier: Double
    ) {
        self.recipes = recipes
        self.videos = videos
        self.premiumEffects = premiumEffects
        self.challengeMultiplier = challengeMultiplier
    }

    // MARK: - Predefined Limits

    /// Honeymoon phase limits (unlimited everything)
    public static let honeymoon = DailyLimits(
        recipes: -1,
        videos: -1,
        premiumEffects: true,
        challengeMultiplier: 1.0
    )

    /// Trial phase limits (generous but limited)
    public static let trial = DailyLimits(
        recipes: 10,
        videos: 5,
        premiumEffects: false,
        challengeMultiplier: 1.0
    )

    /// Standard phase limits (basic free tier)
    public static let starterStandard = DailyLimits(
        recipes: 3,
        videos: 1,
        premiumEffects: false,
        challengeMultiplier: 1.0
    )

    /// Premium tier limits (unlimited everything)
    public static let premium = DailyLimits(
        recipes: -1,
        videos: -1,
        premiumEffects: true,
        challengeMultiplier: 2.0
    )

    // MARK: - Display Properties

    /// User-friendly display text for recipe limit
    public var recipesDisplayText: String {
        return recipes == -1 ? "Unlimited" : "\(recipes)"
    }

    /// User-friendly display text for video limit
    public var videosDisplayText: String {
        return videos == -1 ? "Unlimited" : "\(videos)"
    }

    /// User-friendly display text for premium effects
    public var effectsDisplayText: String {
        return premiumEffects ? "All Effects" : "Basic Only"
    }

    /// User-friendly display text for challenge multiplier
    public var multiplierDisplayText: String {
        return challengeMultiplier == 1.0 ? "1x" : "\(String(format: "%.1f", challengeMultiplier))x"
    }

    // MARK: - Utility Methods

    /// Checks if recipes are unlimited
    public var hasUnlimitedRecipes: Bool {
        return recipes == -1
    }

    /// Checks if videos are unlimited
    public var hasUnlimitedVideos: Bool {
        return videos == -1
    }

    /// Checks if this represents premium limits
    public var isPremiumTier: Bool {
        return hasUnlimitedRecipes && hasUnlimitedVideos && premiumEffects && challengeMultiplier > 1.0
    }

    /// Gets limits based on subscription tier and user phase
    public static func getLimits(for tier: UserLifecycleSubscriptionTier, phase: UserPhase) -> DailyLimits {
        switch tier {
        case .premium:
            return .premium
        case .starter:
            switch phase {
            case .honeymoon:
                return .honeymoon
            case .trial:
                return .trial
            case .standard:
                return .starterStandard
            }
        }
    }
}

// MARK: - Feature Usage Tracking

/// Features that have usage limits and tracking
public enum UsageFeature: String, CaseIterable, Sendable {
    case recipes
    case videos
    case premiumEffects

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .recipes:
            return "Recipe Generation"
        case .videos:
            return "Video Creation"
        case .premiumEffects:
            return "Premium Effects"
        }
    }

    /// Icon for this feature
    public var iconName: String {
        switch self {
        case .recipes:
            return "book.circle.fill"
        case .videos:
            return "video.circle.fill"
        case .premiumEffects:
            return "sparkles"
        }
    }
}

// MARK: - User Lifecycle State

/// Complete state of user's lifecycle progression
public struct UserLifecycleState: Sendable, Equatable {
    public let phase: UserPhase
    public let tier: UserLifecycleSubscriptionTier
    public let daysActive: Int
    public let dailyLimits: DailyLimits
    public let installDate: Date
    public let lastActiveDate: Date

    /// Initializes user lifecycle state
    public init(
        phase: UserPhase,
        tier: UserLifecycleSubscriptionTier,
        daysActive: Int,
        dailyLimits: DailyLimits,
        installDate: Date,
        lastActiveDate: Date
    ) {
        self.phase = phase
        self.tier = tier
        self.daysActive = daysActive
        self.dailyLimits = dailyLimits
        self.installDate = installDate
        self.lastActiveDate = lastActiveDate
    }

    /// Checks if user is in premium preview period
    public var isInPremiumPreview: Bool {
        return phase == .honeymoon
    }

    /// Checks if user should see upgrade prompts
    public var shouldShowUpgradePrompts: Bool {
        return tier == .starter && phase != .honeymoon
    }

    /// Gets days remaining in current phase (nil if unlimited)
    public var daysRemainingInPhase: Int? {
        switch phase {
        case .honeymoon:
            return max(0, 7 - daysActive)
        case .trial:
            return max(0, 30 - daysActive)
        case .standard:
            return nil // Unlimited
        }
    }
}

// MARK: - Usage Analytics

/// Analytics data for tracking user behavior and conversion
public struct UserLifecycleAnalytics: Sendable {
    public let userId: String
    public let phase: UserPhase
    public let tier: UserLifecycleSubscriptionTier
    public let daysActive: Int
    public let totalRecipes: Int
    public let totalVideos: Int
    public let totalChallenges: Int
    public let featureUsage: [UsageFeature: Int]
    public let timestamp: Date

    /// Initializes analytics data
    public init(
        userId: String,
        phase: UserPhase,
        tier: UserLifecycleSubscriptionTier,
        daysActive: Int,
        totalRecipes: Int,
        totalVideos: Int,
        totalChallenges: Int,
        featureUsage: [UsageFeature: Int],
        timestamp: Date = Date()
    ) {
        self.userId = userId
        self.phase = phase
        self.tier = tier
        self.daysActive = daysActive
        self.totalRecipes = totalRecipes
        self.totalVideos = totalVideos
        self.totalChallenges = totalChallenges
        self.featureUsage = featureUsage
        self.timestamp = timestamp
    }

    /// Converts to dictionary for analytics tracking
    public var analyticsData: [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "phase": phase.rawValue,
            "tier": tier.rawValue,
            "daysActive": daysActive,
            "totalRecipes": totalRecipes,
            "totalVideos": totalVideos,
            "totalChallenges": totalChallenges,
            "timestamp": timestamp.timeIntervalSince1970
        ]

        // Add feature usage
        for (feature, count) in featureUsage {
            data["usage_\(feature.rawValue)"] = count
        }

        return data
    }
}
