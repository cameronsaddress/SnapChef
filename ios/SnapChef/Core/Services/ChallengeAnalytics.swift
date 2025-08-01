import Foundation
import SwiftUI

/// ChallengeAnalyticsService tracks and analyzes challenge engagement and performance
@MainActor
class ChallengeAnalyticsService: ObservableObject {
    static let shared = ChallengeAnalyticsService()
    
    // MARK: - Analytics Data
    @Published var dailyMetrics: DailyChallengeMetrics
    @Published var weeklyMetrics: WeeklyChallengeMetrics
    @Published var userEngagement: UserEngagementMetrics
    @Published var performanceInsights: [PerformanceInsight] = []
    
    private let analyticsQueue = DispatchQueue(label: "com.snapchef.challengeanalytics")
    
    // MARK: - Event Types
    enum AnalyticsEvent: String {
        case challengeStarted = "challenge_started"
        case challengeCompleted = "challenge_completed"
        case challengeAbandoned = "challenge_abandoned"
        case rewardClaimed = "reward_claimed"
        case milestoneReached = "milestone_reached"
        case socialShare = "social_share"
        case teamJoined = "team_joined"
        case leaderboardViewed = "leaderboard_viewed"
        case achievementUnlocked = "achievement_unlocked"
        case coinsEarned = "coins_earned"
        case coinsSpent = "coins_spent"
    }
    
    // MARK: - Initialization
    private init() {
        self.dailyMetrics = DailyChallengeMetrics()
        self.weeklyMetrics = WeeklyChallengeMetrics()
        self.userEngagement = UserEngagementMetrics()
        
        loadStoredMetrics()
        setupPeriodicUpdates()
    }
    
    // MARK: - Event Tracking
    
    /// Track an analytics event
    func trackEvent(_ event: AnalyticsEvent, parameters: [String: Any] = [:]) {
        analyticsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let eventData = AnalyticsEventData(
                event: event,
                timestamp: Date(),
                parameters: parameters
            )
            
            // Update metrics based on event
            Task { @MainActor in
                self.updateMetrics(for: eventData)
                self.storeEvent(eventData)
            }
        }
    }
    
    /// Track challenge interaction
    func trackChallengeInteraction(challengeId: String, action: String, metadata: [String: Any] = [:]) {
        var parameters = metadata
        parameters["challengeId"] = challengeId
        parameters["action"] = action
        
        let event: AnalyticsEvent = {
            switch action {
            case "started": return .challengeStarted
            case "completed": return .challengeCompleted
            case "abandoned": return .challengeAbandoned
            default: return .challengeStarted
            }
        }()
        
        trackEvent(event, parameters: parameters)
    }
    
    /// Track reward interaction
    func trackRewardInteraction(rewardType: String, amount: Int, source: String) {
        trackEvent(.rewardClaimed, parameters: [
            "rewardType": rewardType,
            "amount": amount,
            "source": source
        ])
    }
    
    // MARK: - Metrics Calculation
    
    private func updateMetrics(for event: AnalyticsEventData) {
        switch event.event {
        case .challengeStarted:
            dailyMetrics.challengesStarted += 1
            userEngagement.totalChallengesStarted += 1
            
        case .challengeCompleted:
            dailyMetrics.challengesCompleted += 1
            userEngagement.totalChallengesCompleted += 1
            updateCompletionRate()
            
        case .challengeAbandoned:
            dailyMetrics.challengesAbandoned += 1
            
        case .rewardClaimed:
            if let amount = event.parameters["amount"] as? Int {
                dailyMetrics.coinsEarned += amount
                userEngagement.totalCoinsEarned += amount
            }
            
        case .milestoneReached:
            dailyMetrics.milestonesReached += 1
            
        case .socialShare:
            dailyMetrics.socialShares += 1
            userEngagement.totalShares += 1
            
        case .coinsEarned:
            if let amount = event.parameters["amount"] as? Int {
                dailyMetrics.coinsEarned += amount
                userEngagement.totalCoinsEarned += amount
            }
            
        case .coinsSpent:
            if let amount = event.parameters["amount"] as? Int {
                dailyMetrics.coinsSpent += amount
                userEngagement.totalCoinsSpent += amount
            }
            
        default:
            break
        }
        
        // Update last active timestamp
        userEngagement.lastActiveDate = Date()
    }
    
    private func updateCompletionRate() {
        let total = userEngagement.totalChallengesStarted
        let completed = userEngagement.totalChallengesCompleted
        
        if total > 0 {
            userEngagement.completionRate = Double(completed) / Double(total)
        }
    }
    
    // MARK: - Performance Insights
    
    /// Generate performance insights based on user data
    func generateInsights() {
        var insights: [PerformanceInsight] = []
        
        // Completion rate insight
        if userEngagement.completionRate < 0.5 {
            insights.append(PerformanceInsight(
                type: .improvement,
                title: "Challenge Completion",
                message: "Try easier challenges to build momentum! Your completion rate is \(Int(userEngagement.completionRate * 100))%",
                icon: "chart.line.uptrend.xyaxis"
            ))
        } else if userEngagement.completionRate > 0.8 {
            insights.append(PerformanceInsight(
                type: .achievement,
                title: "Challenge Master",
                message: "Amazing! You complete \(Int(userEngagement.completionRate * 100))% of challenges!",
                icon: "trophy.fill"
            ))
        }
        
        // Engagement insight
        let daysSinceActive = Calendar.current.dateComponents([.day], from: userEngagement.lastActiveDate, to: Date()).day ?? 0
        if daysSinceActive > 3 {
            insights.append(PerformanceInsight(
                type: .suggestion,
                title: "Welcome Back!",
                message: "You've been away for \(daysSinceActive) days. Check out today's challenges!",
                icon: "sparkles"
            ))
        }
        
        // Coin efficiency insight
        if userEngagement.totalCoinsEarned > 0 {
            let efficiency = Double(userEngagement.totalCoinsSpent) / Double(userEngagement.totalCoinsEarned)
            if efficiency < 0.3 {
                insights.append(PerformanceInsight(
                    type: .suggestion,
                    title: "Coin Collector",
                    message: "You have \(userEngagement.totalCoinsEarned - userEngagement.totalCoinsSpent) unspent coins! Visit the store for rewards.",
                    icon: "bitcoinsign.circle.fill"
                ))
            }
        }
        
        // Social engagement insight
        if userEngagement.totalShares == 0 && userEngagement.totalChallengesCompleted > 5 {
            insights.append(PerformanceInsight(
                type: .suggestion,
                title: "Share Your Success",
                message: "Share your achievements to earn bonus coins and inspire friends!",
                icon: "square.and.arrow.up"
            ))
        }
        
        performanceInsights = insights
    }
    
    // MARK: - Reporting
    
    /// Get challenge completion statistics
    func getChallengeStats() -> ChallengeStatistics {
        return ChallengeStatistics(
            totalStarted: userEngagement.totalChallengesStarted,
            totalCompleted: userEngagement.totalChallengesCompleted,
            completionRate: userEngagement.completionRate,
            averageCompletionTime: calculateAverageCompletionTime(),
            favoriteCategory: determineFavoriteCategory(),
            currentStreak: GamificationManager.shared.userStats.currentStreak
        )
    }
    
    /// Get reward statistics
    func getRewardStats() -> RewardStatistics {
        return RewardStatistics(
            totalCoinsEarned: userEngagement.totalCoinsEarned,
            totalCoinsSpent: userEngagement.totalCoinsSpent,
            currentBalance: ChefCoinsManager.shared.currentBalance,
            mostValuableReward: determineMostValuableReward(),
            totalBadgesEarned: GamificationManager.shared.unlockedBadges.count,
            averageCoinsPerChallenge: calculateAverageCoinsPerChallenge()
        )
    }
    
    /// Get engagement trends over time
    func getEngagementTrends() -> EngagementTrends {
        return EngagementTrends(
            dailyActiveUsers: calculateDAU(),
            weeklyActiveUsers: calculateWAU(),
            monthlyActiveUsers: calculateMAU(),
            retentionRate: calculateRetentionRate(),
            engagementScore: calculateEngagementScore()
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculateAverageCompletionTime() -> TimeInterval {
        // This would calculate from stored event data
        return 3600 // 1 hour placeholder
    }
    
    private func determineFavoriteCategory() -> String {
        // This would analyze completed challenges by category
        return "Speed Challenges"
    }
    
    private func determineMostValuableReward() -> String {
        // This would find the highest value reward earned
        return "Master Chef Badge"
    }
    
    private func calculateAverageCoinsPerChallenge() -> Double {
        guard userEngagement.totalChallengesCompleted > 0 else { return 0 }
        return Double(userEngagement.totalCoinsEarned) / Double(userEngagement.totalChallengesCompleted)
    }
    
    private func calculateDAU() -> Int {
        // Daily active users (for this user, 1 if active today, 0 otherwise)
        return Calendar.current.isDateInToday(userEngagement.lastActiveDate) ? 1 : 0
    }
    
    private func calculateWAU() -> Int {
        // Weekly active users
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return userEngagement.lastActiveDate > weekAgo ? 1 : 0
    }
    
    private func calculateMAU() -> Int {
        // Monthly active users
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        return userEngagement.lastActiveDate > monthAgo ? 1 : 0
    }
    
    private func calculateRetentionRate() -> Double {
        // Simplified retention calculation
        let daysActive = userEngagement.daysActive
        let daysSinceFirstUse = Calendar.current.dateComponents([.day], 
            from: userEngagement.firstActiveDate, 
            to: Date()
        ).day ?? 1
        
        return min(Double(daysActive) / Double(daysSinceFirstUse), 1.0)
    }
    
    private func calculateEngagementScore() -> Double {
        // Composite engagement score (0-100)
        let completionScore = userEngagement.completionRate * 30
        let activityScore = min(Double(dailyMetrics.challengesStarted) / 5.0, 1.0) * 20
        let socialScore = min(Double(dailyMetrics.socialShares) / 3.0, 1.0) * 20
        let rewardScore = min(Double(dailyMetrics.coinsEarned) / 100.0, 1.0) * 30
        
        return completionScore + activityScore + socialScore + rewardScore
    }
    
    // MARK: - Persistence
    
    private func loadStoredMetrics() {
        // Load from UserDefaults or Core Data
        if let data = UserDefaults.standard.data(forKey: "ChallengeAnalyticsData"),
           let decoded = try? JSONDecoder().decode(StoredAnalyticsData.self, from: data) {
            self.userEngagement = decoded.userEngagement
            self.dailyMetrics = decoded.dailyMetrics
            self.weeklyMetrics = decoded.weeklyMetrics
        } else {
            // Initialize with default values
            userEngagement.firstActiveDate = Date()
        }
    }
    
    private func storeEvent(_ event: AnalyticsEventData) {
        // Store event for historical analysis
        let storedData = StoredAnalyticsData(
            userEngagement: userEngagement,
            dailyMetrics: dailyMetrics,
            weeklyMetrics: weeklyMetrics
        )
        
        if let encoded = try? JSONEncoder().encode(storedData) {
            UserDefaults.standard.set(encoded, forKey: "ChallengeAnalyticsData")
        }
    }
    
    private func setupPeriodicUpdates() {
        // Reset daily metrics at midnight
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in
                self.checkForDailyReset()
                self.checkForWeeklyReset()
                self.generateInsights()
            }
        }
    }
    
    private func checkForDailyReset() {
        let lastReset = UserDefaults.standard.object(forKey: "LastDailyMetricsReset") as? Date ?? Date.distantPast
        
        if !Calendar.current.isDateInToday(lastReset) {
            // Archive daily metrics to weekly
            weeklyMetrics.addDailyMetrics(dailyMetrics)
            
            // Reset daily metrics
            dailyMetrics = DailyChallengeMetrics()
            
            UserDefaults.standard.set(Date(), forKey: "LastDailyMetricsReset")
        }
    }
    
    private func checkForWeeklyReset() {
        let lastReset = UserDefaults.standard.object(forKey: "LastWeeklyMetricsReset") as? Date ?? Date.distantPast
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        
        if lastReset < weekAgo {
            // Reset weekly metrics
            weeklyMetrics = WeeklyChallengeMetrics()
            
            UserDefaults.standard.set(Date(), forKey: "LastWeeklyMetricsReset")
        }
    }
}

// MARK: - Supporting Types

struct AnalyticsEventData {
    let event: ChallengeAnalyticsService.AnalyticsEvent
    let timestamp: Date
    let parameters: [String: Any]
}

struct DailyChallengeMetrics: Codable {
    var challengesStarted: Int = 0
    var challengesCompleted: Int = 0
    var challengesAbandoned: Int = 0
    var milestonesReached: Int = 0
    var coinsEarned: Int = 0
    var coinsSpent: Int = 0
    var socialShares: Int = 0
    var date: Date = Date()
}

struct WeeklyChallengeMetrics: Codable {
    var totalChallengesStarted: Int = 0
    var totalChallengesCompleted: Int = 0
    var totalCoinsEarned: Int = 0
    var totalCoinsSpent: Int = 0
    var dailyMetrics: [DailyChallengeMetrics] = []
    
    mutating func addDailyMetrics(_ metrics: DailyChallengeMetrics) {
        totalChallengesStarted += metrics.challengesStarted
        totalChallengesCompleted += metrics.challengesCompleted
        totalCoinsEarned += metrics.coinsEarned
        totalCoinsSpent += metrics.coinsSpent
        
        dailyMetrics.append(metrics)
        
        // Keep only last 7 days
        if dailyMetrics.count > 7 {
            dailyMetrics.removeFirst()
        }
    }
}

struct UserEngagementMetrics: Codable {
    var totalChallengesStarted: Int = 0
    var totalChallengesCompleted: Int = 0
    var completionRate: Double = 0.0
    var totalCoinsEarned: Int = 0
    var totalCoinsSpent: Int = 0
    var totalShares: Int = 0
    var lastActiveDate: Date = Date()
    var firstActiveDate: Date = Date()
    var daysActive: Int = 1
    var averageDailyTime: TimeInterval = 0 // In seconds
}

struct PerformanceInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let message: String
    let icon: String
    
    enum InsightType {
        case achievement
        case improvement
        case suggestion
    }
}

struct ChallengeStatistics {
    let totalStarted: Int
    let totalCompleted: Int
    let completionRate: Double
    let averageCompletionTime: TimeInterval
    let favoriteCategory: String
    let currentStreak: Int
}

struct RewardStatistics {
    let totalCoinsEarned: Int
    let totalCoinsSpent: Int
    let currentBalance: Int
    let mostValuableReward: String
    let totalBadgesEarned: Int
    let averageCoinsPerChallenge: Double
}

struct EngagementTrends {
    let dailyActiveUsers: Int
    let weeklyActiveUsers: Int
    let monthlyActiveUsers: Int
    let retentionRate: Double
    let engagementScore: Double
}

struct StoredAnalyticsData: Codable {
    let userEngagement: UserEngagementMetrics
    let dailyMetrics: DailyChallengeMetrics
    let weeklyMetrics: WeeklyChallengeMetrics
}

// MARK: - Analytics Export

extension ChallengeAnalyticsService {
    
    /// Export analytics data for external analysis
    func exportAnalyticsData() -> Data? {
        let exportData = AnalyticsExportData(
            userEngagement: userEngagement,
            dailyMetrics: dailyMetrics,
            weeklyMetrics: weeklyMetrics,
            challengeStats: getChallengeStats(),
            rewardStats: getRewardStats(),
            engagementTrends: getEngagementTrends(),
            exportDate: Date()
        )
        
        return try? JSONEncoder().encode(exportData)
    }
}

struct AnalyticsExportData: Codable {
    let userEngagement: UserEngagementMetrics
    let dailyMetrics: DailyChallengeMetrics
    let weeklyMetrics: WeeklyChallengeMetrics
    let challengeStats: ChallengeStatistics
    let rewardStats: RewardStatistics
    let engagementTrends: EngagementTrends
    let exportDate: Date
}

// Make statistics types Codable for export
extension ChallengeStatistics: Codable {}
extension RewardStatistics: Codable {}
extension EngagementTrends: Codable {}

// Extension for InsightType color
extension PerformanceInsight.InsightType {
    var color: Color {
        switch self {
        case .achievement:
            return Color(hex: "#667eea")
        case .improvement:
            return .orange
        case .suggestion:
            return .blue
        }
    }
}