import Foundation
import SwiftUI

// MARK: - Streak Type
enum StreakType: String, CaseIterable, Codable {
    case dailySnap = "daily_snap"
    case recipeCreation = "recipe_creation"
    case challengeCompletion = "challenge_completion"
    case socialShare = "social_share"
    case healthyEating = "healthy_eating"

    var displayName: String {
        switch self {
        case .dailySnap: return "Daily Snap"
        case .recipeCreation: return "Recipe Creator"
        case .challengeCompletion: return "Challenge Master"
        case .socialShare: return "Social Chef"
        case .healthyEating: return "Healthy Habits"
        }
    }

    var icon: String {
        switch self {
        case .dailySnap: return "📸"
        case .recipeCreation: return "👨‍🍳"
        case .challengeCompletion: return "🏆"
        case .socialShare: return "📱"
        case .healthyEating: return "🥗"
        }
    }

    var description: String {
        switch self {
        case .dailySnap: return "Take a photo of your fridge or pantry"
        case .recipeCreation: return "Generate at least one recipe"
        case .challengeCompletion: return "Complete any challenge"
        case .socialShare: return "Share a recipe on social media"
        case .healthyEating: return "Create a healthy recipe under 500 calories"
        }
    }

    var basePoints: Int {
        switch self {
        case .dailySnap: return 10
        case .recipeCreation: return 20
        case .challengeCompletion: return 30
        case .socialShare: return 15
        case .healthyEating: return 25
        }
    }
}

// MARK: - Streak Data
struct StreakData: Codable, Identifiable {
    let id: UUID
    let type: StreakType
    var currentStreak: Int
    var longestStreak: Int
    var lastActivityDate: Date
    var streakStartDate: Date
    var totalDaysActive: Int
    var frozenUntil: Date?
    var insuranceActive: Bool
    var multiplier: Double
    var freezesRemaining: Int

    init(type: StreakType) {
        self.id = UUID()
        self.type = type
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastActivityDate = Date.distantPast
        self.streakStartDate = Date()
        self.totalDaysActive = 0
        self.frozenUntil = nil
        self.insuranceActive = false
        self.multiplier = 1.0
        self.freezesRemaining = 1 // Free users get 1 freeze per month
    }

    var isActive: Bool {
        let calendar = Calendar.current

        // Check if frozen
        if let frozenUntil = frozenUntil, Date() < frozenUntil {
            return true
        }

        // Check if activity was today or yesterday
        return calendar.isDateInToday(lastActivityDate) ||
               calendar.isDateInYesterday(lastActivityDate)
    }

    var isFrozen: Bool {
        if let frozenUntil = frozenUntil {
            return Date() < frozenUntil
        }
        return false
    }

    var hoursUntilBreak: Int {
        let calendar = Calendar.current

        // If frozen, return hours until freeze expires
        if let frozenUntil = frozenUntil, Date() < frozenUntil {
            return calendar.dateComponents([.hour], from: Date(), to: frozenUntil).hour ?? 0
        }

        // Calculate hours until midnight tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let midnight = calendar.startOfDay(for: tomorrow)
        return calendar.dateComponents([.hour], from: Date(), to: midnight).hour ?? 0
    }

    var nextMilestone: StreakMilestone? {
        StreakMilestone.milestones.first { $0.days > currentStreak }
    }

    var progressToNextMilestone: Double {
        guard let next = nextMilestone else { return 1.0 }
        let previous = StreakMilestone.milestones
            .filter { $0.days < next.days }
            .last?.days ?? 0
        let progress = Double(currentStreak - previous) / Double(next.days - previous)
        return min(max(progress, 0), 1)
    }
}

// MARK: - Streak Milestone
struct StreakMilestone: Identifiable {
    let id = UUID()
    let days: Int
    let coins: Int
    let badge: String
    let title: String
    let xpBonus: Int
    let description: String

    static let milestones = [
        StreakMilestone(
            days: 3,
            coins: 10,
            badge: "🔥",
            title: "Starter",
            xpBonus: 50,
            description: "3-day streak achieved!"
        ),
        StreakMilestone(
            days: 7,
            coins: 50,
            badge: "📅",
            title: "Week Warrior",
            xpBonus: 200,
            description: "One week of consistency!"
        ),
        StreakMilestone(
            days: 14,
            coins: 100,
            badge: "💪",
            title: "Two Week Champion",
            xpBonus: 500,
            description: "Two weeks strong!"
        ),
        StreakMilestone(
            days: 30,
            coins: 500,
            badge: "🌟",
            title: "Monthly Master",
            xpBonus: 2_000,
            description: "30 days of dedication!"
        ),
        StreakMilestone(
            days: 50,
            coins: 1_000,
            badge: "🎯",
            title: "Streak Elite",
            xpBonus: 5_000,
            description: "50 days of excellence!"
        ),
        StreakMilestone(
            days: 100,
            coins: 5_000,
            badge: "👑",
            title: "Century Chef",
            xpBonus: 20_000,
            description: "100 days! Legendary!"
        ),
        StreakMilestone(
            days: 365,
            coins: 20_000,
            badge: "🌈",
            title: "Year Legend",
            xpBonus: 100_000,
            description: "One full year! Incredible!"
        )
    ]

    static func getMilestone(for days: Int) -> StreakMilestone? {
        milestones.first { $0.days == days }
    }
}

// MARK: - Streak History
struct StreakHistory: Codable, Identifiable {
    let id: UUID
    let type: StreakType
    let streakLength: Int
    let startDate: Date
    let endDate: Date
    let breakReason: StreakBreakReason?
    let wasRestored: Bool

    init(
        type: StreakType,
        streakLength: Int,
        startDate: Date,
        endDate: Date = Date(),
        breakReason: StreakBreakReason? = nil,
        wasRestored: Bool = false
    ) {
        self.id = UUID()
        self.type = type
        self.streakLength = streakLength
        self.startDate = startDate
        self.endDate = endDate
        self.breakReason = breakReason
        self.wasRestored = wasRestored
    }
}

// MARK: - Streak Break Reason
enum StreakBreakReason: String, Codable {
    case missed = "missed_day"
    case appNotOpened = "app_not_opened"
    case noActivity = "no_activity"
    case freezeExpired = "freeze_expired"
    case insuranceUnavailable = "insurance_unavailable"

    var displayText: String {
        switch self {
        case .missed: return "Missed a day"
        case .appNotOpened: return "App not opened"
        case .noActivity: return "No activity completed"
        case .freezeExpired: return "Freeze period expired"
        case .insuranceUnavailable: return "Insurance not available"
        }
    }
}

// MARK: - Streak Freeze
struct StreakFreeze: Codable, Identifiable {
    let id: UUID
    let streakType: StreakType
    let freezeDate: Date
    let expiresAt: Date
    let freezeSource: FreezeSource

    init(streakType: StreakType, duration: TimeInterval = 86_400, source: FreezeSource = .manual) {
        self.id = UUID()
        self.streakType = streakType
        self.freezeDate = Date()
        self.expiresAt = Date().addingTimeInterval(duration)
        self.freezeSource = source
    }

    var isActive: Bool {
        Date() < expiresAt
    }

    var hoursRemaining: Int {
        let interval = expiresAt.timeIntervalSince(Date())
        return max(0, Int(interval / 3_600))
    }
}

enum FreezeSource: String, Codable {
    case manual = "manual"       // User activated
    case premium = "premium"     // Premium auto-freeze
    case reward = "reward"       // Earned through achievement
    case purchase = "purchase"   // Bought with coins
}

// MARK: - Streak Insurance
struct StreakInsurance: Codable {
    let purchaseDate: Date
    let expiresAt: Date
    let streakType: StreakType
    let autoRestoreEnabled: Bool
    let costInCoins: Int

    init(streakType: StreakType, duration: TimeInterval = 604_800) { // 7 days default
        self.purchaseDate = Date()
        self.expiresAt = Date().addingTimeInterval(duration)
        self.streakType = streakType
        self.autoRestoreEnabled = true
        self.costInCoins = 200
    }

    var isActive: Bool {
        Date() < expiresAt
    }

    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expiresAt)
        return max(0, components.day ?? 0)
    }
}

// MARK: - Team Streak (Removed)

// MARK: - Streak Power-Up
struct StreakPowerUp: Identifiable {
    let id = UUID()
    let type: PowerUpType
    let name: String
    let icon: String
    let description: String
    let costInCoins: Int
    let duration: TimeInterval?

    enum PowerUpType: String, Codable {
        case doubleDay = "double_day"           // Counts as 2 days
        case shield = "shield"                   // Protects for 24h
        case timeMachine = "time_machine"       // Backfill missed day
        case multiplyBoost = "multiply_boost"   // 2x multiplier for a day
        case freezeExtension = "freeze_extension" // Extend freeze by 24h
    }

    static let availablePowerUps = [
        StreakPowerUp(
            type: .doubleDay,
            name: "Double Day",
            icon: "⚡",
            description: "Today counts as 2 streak days",
            costInCoins: 300,
            duration: 86_400
        ),
        StreakPowerUp(
            type: .shield,
            name: "Streak Shield",
            icon: "🛡",
            description: "Protects your streak for 24 hours",
            costInCoins: 250,
            duration: 86_400
        ),
        StreakPowerUp(
            type: .timeMachine,
            name: "Time Machine",
            icon: "⏰",
            description: "Fill in a missed day from the past week",
            costInCoins: 1_000,
            duration: nil
        ),
        StreakPowerUp(
            type: .multiplyBoost,
            name: "Multiplier Boost",
            icon: "🚀",
            description: "2x streak multiplier for 24 hours",
            costInCoins: 500,
            duration: 86_400
        ),
        StreakPowerUp(
            type: .freezeExtension,
            name: "Freeze Extension",
            icon: "❄️",
            description: "Extend current freeze by 24 hours",
            costInCoins: 150,
            duration: 86_400
        )
    ]
}

// MARK: - Streak Achievement  
struct StreakAchievement: Codable, Identifiable {
    let id: UUID
    let type: StreakType
    let milestoneDays: Int
    let milestoneTitle: String
    let milestoneBadge: String
    let milestoneCoins: Int
    let milestoneXP: Int
    let unlockedAt: Date
    var rewardsClaimed: Bool

    init(type: StreakType, milestone: StreakMilestone) {
        self.id = UUID()
        self.type = type
        self.milestoneDays = milestone.days
        self.milestoneTitle = milestone.title
        self.milestoneBadge = milestone.badge
        self.milestoneCoins = milestone.coins
        self.milestoneXP = milestone.xpBonus
        self.unlockedAt = Date()
        self.rewardsClaimed = false
    }
}

// MARK: - Streak Analytics
struct StreakAnalytics: Codable {
    let averageStreakLength: Double
    let breakPatterns: [Int: Int] // Day of week: break count
    let recoveryRate: Double // % who restore after break
    let topStreakTypes: [StreakType]
    let engagementCorrelation: Double // Streak vs app usage
    let totalStreakDays: Int
    let uniqueStreaksStarted: Int

    static func calculate(from history: [StreakHistory]) -> StreakAnalytics {
        // Calculate average length
        let average = history.isEmpty ? 0 :
            Double(history.reduce(0) { $0 + $1.streakLength }) / Double(history.count)

        // Calculate break patterns
        var patterns: [Int: Int] = [:]
        let calendar = Calendar.current
        for record in history {
            let dayOfWeek = calendar.component(.weekday, from: record.endDate)
            patterns[dayOfWeek, default: 0] += 1
        }

        // Calculate recovery rate
        let restoredCount = history.filter { $0.wasRestored }.count
        let recoveryRate = history.isEmpty ? 0 :
            Double(restoredCount) / Double(history.count)

        // Get top streak types
        let typeGroups = Dictionary(grouping: history, by: { $0.type })
        let topTypes = typeGroups
            .sorted { $0.value.count > $1.value.count }
            .prefix(3)
            .map { $0.key }

        return StreakAnalytics(
            averageStreakLength: average,
            breakPatterns: patterns,
            recoveryRate: recoveryRate,
            topStreakTypes: topTypes,
            engagementCorrelation: 0.75, // Placeholder
            totalStreakDays: history.reduce(0) { $0 + $1.streakLength },
            uniqueStreaksStarted: history.count
        )
    }
}
