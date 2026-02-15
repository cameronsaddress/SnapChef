//
//  UsageTracker.swift
//  SnapChef
//
//  Created by AI Assistant on 1/16/25.
//

import Foundation
import SwiftUI

// Note: UsageFeature is now defined in UserLifecycle.swift
// Import the model to avoid duplicate definitions

/// Additional usage features specific to the tracker
enum TrackerFeature: String, CaseIterable {
    case advancedAI = "advanced_ai"
    case nutritionTracking = "nutrition_tracking"
    case unlimitedFavorites = "unlimited_favorites"
}

/// Data structure for storing daily usage counts
struct DailyUsageData: Codable {
    let date: Date
    var recipeCount: Int
    var videoCount: Int
    var featuresUsed: Set<String>

    init(date: Date = Date()) {
        self.date = date
        self.recipeCount = 0
        self.videoCount = 0
        self.featuresUsed = []
    }
}

/// Service for tracking user usage patterns and enforcing daily limits
@MainActor
final class UsageTracker: ObservableObject {
    // MARK: - Singleton
    static let shared = UsageTracker()

    // MARK: - Published Properties
    @Published private(set) var todaysUsage = DailyUsageData()
    @Published private(set) var usageHistory: [DailyUsageData] = []
    @Published private(set) var detectiveAnalysesUsed: Int = 0
    @Published private(set) var totalDetectiveAnalyses: Int = 0

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let calendar = Calendar.current

    // UserDefaults Keys
    private enum Keys {
        static let todaysUsage = "usage_tracker_todays_usage"
        static let usageHistory = "usage_tracker_usage_history"
        static let lastResetDate = "usage_tracker_last_reset_date"
        static let detectiveAnalysesUsedToday = "detectiveAnalysesUsedToday"
        static let totalDetectiveAnalyses = "totalDetectiveAnalyses"
        static let lastDetectiveResetDate = "lastDetectiveResetDate"
    }
    
    // Detective Feature Limits
    private enum DetectiveLimits {
        static let DETECTIVE_LIFETIME_LIMIT_FREE = 6  // 6 lifetime uses for free users
        static let DETECTIVE_DAILY_LIMIT_PREMIUM = 15  // 15 per day for premium users
    }

    // MARK: - Initialization
    private init() {
        loadPersistedData()
        setupMidnightTimer()
    }

    // MARK: - Public Methods

    /// Track a recipe generation event
    func trackRecipeGenerated() {
        todaysUsage.recipeCount += 1
        saveData()

        // Analytics tracking
        trackAnalyticsEvent("recipe_generated", metadata: [
            "daily_count": todaysUsage.recipeCount,
            "date": todaysUsage.date.timeIntervalSince1970
        ])
    }

    /// Track a video creation event
    func trackVideoCreated() {
        todaysUsage.videoCount += 1
        saveData()

        // Analytics tracking
        trackAnalyticsEvent("video_created", metadata: [
            "daily_count": todaysUsage.videoCount,
            "date": todaysUsage.date.timeIntervalSince1970
        ])
    }

    /// Track usage of a specific premium feature
    func trackFeatureUsed(_ feature: TrackerFeature) {
        todaysUsage.featuresUsed.insert(feature.rawValue)
        saveData()

        // Analytics tracking
        trackAnalyticsEvent("feature_used", metadata: [
            "feature": feature.rawValue,
            "date": todaysUsage.date.timeIntervalSince1970
        ])
    }

    /// Get remaining recipe count for today based on subscription tier
    func getRemainingRecipes() -> Int {
        let dailyLimit = getCurrentRecipeLimit()
        if dailyLimit == -1 { return -1 } // Unlimited
        return max(0, dailyLimit - todaysUsage.recipeCount)
    }

    /// Get remaining video count for today based on subscription tier
    func getRemainingVideos() -> Int {
        let dailyLimit = getCurrentVideoLimit()
        if dailyLimit == -1 { return -1 } // Unlimited
        return max(0, dailyLimit - todaysUsage.videoCount)
    }

    /// Check if user has reached the limit for recipe generation
    func hasReachedRecipeLimit() -> Bool {
        let limit = getCurrentRecipeLimit()
        return limit != -1 && todaysUsage.recipeCount >= limit
    }

    /// Check if user has reached the limit for video creation
    func hasReachedVideoLimit() -> Bool {
        let limit = getCurrentVideoLimit()
        return limit != -1 && todaysUsage.videoCount >= limit
    }

    /// Check if user has reached the limit for a specific tracker feature
    func hasReachedLimit(for feature: TrackerFeature) -> Bool {
        // These are premium-only features
        return !isPremiumUser()
    }

    /// Get usage percentage for recipe generation (0.0 to 1.0)
    func getRecipeUsagePercentage() -> Double {
        let limit = getCurrentRecipeLimit()
        if limit == -1 { return 0.0 } // Unlimited
        return min(1.0, Double(todaysUsage.recipeCount) / Double(limit))
    }

    /// Get usage percentage for video creation (0.0 to 1.0)
    func getVideoUsagePercentage() -> Double {
        let limit = getCurrentVideoLimit()
        if limit == -1 { return 0.0 } // Unlimited
        return min(1.0, Double(todaysUsage.videoCount) / Double(limit))
    }

    /// Get usage percentage for a tracker feature (0.0 to 1.0)
    func getUsagePercentage(for feature: TrackerFeature) -> Double {
        return hasReachedLimit(for: feature) ? 1.0 : 0.0
    }

    // MARK: - Recipe Detective Methods
    
    /// Check if user can use Recipe Detective feature
    func canUseDetective() -> Bool {
        if isPremiumUser() {
            // Premium users have a daily limit.
            return detectiveAnalysesUsed < DetectiveLimits.DETECTIVE_DAILY_LIMIT_PREMIUM
        }
        
        // Free users have lifetime limit
        return totalDetectiveAnalyses < DetectiveLimits.DETECTIVE_LIFETIME_LIMIT_FREE
    }
    
    /// Increment detective usage counter
    func incrementDetectiveUse() {
        detectiveAnalysesUsed += 1
        totalDetectiveAnalyses += 1
        saveDetectiveData()
        
        // Analytics tracking
        trackAnalyticsEvent("detective_analysis_used", metadata: [
            "lifetime_count": totalDetectiveAnalyses,
            "date": Date().timeIntervalSince1970,
            "is_premium": isPremiumUser()
        ])
    }
    
    /// Get remaining detective uses for free users (daily count for premium)
    func getDetectiveUsesRemaining() -> Int {
        if isPremiumUser() {
            // Premium users have daily limit
            return max(0, DetectiveLimits.DETECTIVE_DAILY_LIMIT_PREMIUM - detectiveAnalysesUsed)
        }
        
        return max(0, DetectiveLimits.DETECTIVE_LIFETIME_LIMIT_FREE - totalDetectiveAnalyses)
    }
    
    /// Reset detective daily counter (called at midnight)
    func resetDetectiveDaily() {
        detectiveAnalysesUsed = 0
        saveDetectiveData()
        
        // Update last reset date
        userDefaults.set(Date(), forKey: Keys.lastDetectiveResetDate)
        
        logMessage("Detective daily counter reset")
    }
    
    /// Check if user should see detective premium prompt
    func shouldShowDetectivePremiumPrompt() -> Bool {
        if isPremiumUser() {
            return false
        }
        
        // Show prompt when user hits the limit
        return totalDetectiveAnalyses >= DetectiveLimits.DETECTIVE_LIFETIME_LIMIT_FREE
    }

    /// Get analytics data for the last 30 days
    func getAnalyticsData(days: Int = 30) -> [DailyUsageData] {
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return usageHistory.filter { $0.date >= cutoffDate }
    }

    /// Manually reset daily counters (for testing or admin purposes)
    func resetDailyCounters() {
        // Save current day to history if it has any usage
        if todaysUsage.recipeCount > 0 || todaysUsage.videoCount > 0 || !todaysUsage.featuresUsed.isEmpty {
            usageHistory.append(todaysUsage)
        }

        // Create new usage data for today
        todaysUsage = DailyUsageData()
        
        // Reset detective daily counter (but not total)
        resetDetectiveDaily()

        // Clean up old history (keep last 30 days)
        cleanupOldHistory()

        // Save data
        saveData()

        // Update last reset date
        userDefaults.set(Date(), forKey: Keys.lastResetDate)

        // Log the reset (replacing print statement)
        logMessage("Daily counters reset")
    }

    // MARK: - Private Methods

    private func loadPersistedData() {
        // Load today's usage
        if let data = userDefaults.data(forKey: Keys.todaysUsage),
           let decoded = try? JSONDecoder().decode(DailyUsageData.self, from: data) {
            // Check if the data is from today
            if calendar.isDate(decoded.date, inSameDayAs: Date()) {
                todaysUsage = decoded
            } else {
                // Data is from a previous day, reset for today
                todaysUsage = DailyUsageData()
            }
        }

        // Load usage history
        if let data = userDefaults.data(forKey: Keys.usageHistory),
           let decoded = try? JSONDecoder().decode([DailyUsageData].self, from: data) {
            usageHistory = decoded
        }
        
        // Load detective data
        loadDetectiveData()

        // Check if we need to reset based on date change
        checkForDateChange()

        // Log the data loading (replacing print statement)
        logMessage("Loaded data - Recipes: \(todaysUsage.recipeCount), Videos: \(todaysUsage.videoCount), Detective: \(totalDetectiveAnalyses)")
    }

    private func saveData() {
        // Save today's usage
        if let encoded = try? JSONEncoder().encode(todaysUsage) {
            userDefaults.set(encoded, forKey: Keys.todaysUsage)
        }

        // Save usage history
        if let encoded = try? JSONEncoder().encode(usageHistory) {
            userDefaults.set(encoded, forKey: Keys.usageHistory)
        }
    }

    private func checkForDateChange() {
        let lastResetDate = userDefaults.object(forKey: Keys.lastResetDate) as? Date
        let today = Date()

        // If no last reset date or it's a new day, reset counters
        if let lastReset = lastResetDate {
            if !calendar.isDate(lastReset, inSameDayAs: today) {
                resetDailyCounters()
            }
        } else {
            // First time setup
            userDefaults.set(today, forKey: Keys.lastResetDate)
        }
    }

    private func setupMidnightTimer() {
        // Set up a timer to reset counters at midnight
        let now = Date()
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let timeInterval = tomorrow.timeIntervalSince(now)

        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.resetDailyCounters()
                self?.setupMidnightTimer() // Schedule next reset
            }
        }

        // Log the timer setup (replacing print statement)
        logMessage("Midnight reset timer scheduled for \(tomorrow)")
    }

    private func cleanupOldHistory() {
        let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        usageHistory = usageHistory.filter { $0.date >= cutoffDate }
    }

    private func getCurrentRecipeLimit() -> Int {
        // Get dynamic limits from UserLifecycleManager
        let limits = UserLifecycleManager.shared.getDailyLimits()
        return limits.recipes
    }

    func getCurrentVideoLimit() -> Int {
        // Get dynamic limits from UserLifecycleManager
        let limits = UserLifecycleManager.shared.getDailyLimits()
        return limits.videos
    }

    private func isPremiumUser() -> Bool {
        // Use cached premium status to avoid StoreKit initialization
        // This prevents "No active account" errors on startup
        return SubscriptionManager.shared.isPremiumCached
    }

    private func trackAnalyticsEvent(_ eventName: String, metadata: [String: Any]) {
        // Local analytics tracking for usage events
        var eventData = metadata
        eventData["event_name"] = eventName
        eventData["timestamp"] = Date()
        eventData["user_id"] = UserDefaults.standard.string(forKey: "userId") ?? "anonymous"

        // Store locally for potential future upload
        var events = UserDefaults.standard.array(forKey: "usage_analytics_events") as? [[String: Any]] ?? []
        events.append(eventData)

        // Keep only last 500 usage events
        if events.count > 500 {
            events = Array(events.suffix(500))
        }

        UserDefaults.standard.set(events, forKey: "usage_analytics_events")
        logMessage("Stored analytics event: \(eventName)")
    }

    private func loadDetectiveData() {
        detectiveAnalysesUsed = userDefaults.integer(forKey: Keys.detectiveAnalysesUsedToday)
        totalDetectiveAnalyses = userDefaults.integer(forKey: Keys.totalDetectiveAnalyses)
        
        // Check if we need to reset daily detective count based on date change
        checkForDetectiveDateChange()
    }
    
    private func saveDetectiveData() {
        userDefaults.set(detectiveAnalysesUsed, forKey: Keys.detectiveAnalysesUsedToday)
        userDefaults.set(totalDetectiveAnalyses, forKey: Keys.totalDetectiveAnalyses)
    }
    
    private func checkForDetectiveDateChange() {
        let lastResetDate = userDefaults.object(forKey: Keys.lastDetectiveResetDate) as? Date
        let today = Date()
        
        // If no last reset date or it's a new day, reset daily counter
        if let lastReset = lastResetDate {
            if !calendar.isDate(lastReset, inSameDayAs: today) {
                resetDetectiveDaily()
            }
        } else {
            // First time setup
            userDefaults.set(today, forKey: Keys.lastDetectiveResetDate)
        }
    }

    private func logMessage(_ message: String) {
        AppLog.debug(AppLog.app, "UsageTracker: \(message)")
    }
}

// MARK: - Extension for SwiftUI Integration
extension UsageTracker {
    /// Get a user-friendly usage status string for recipes
    func getRecipeStatusText() -> String {
        let remaining = getRemainingRecipes()
        if remaining == -1 {
            return "♾️ Unlimited"
        } else if remaining == 0 {
            return "🚫 Limit reached"
        } else {
            return "\(remaining) left today"
        }
    }

    /// Get a user-friendly usage status string for videos
    func getVideoStatusText() -> String {
        let remaining = getRemainingVideos()
        if remaining == -1 {
            return "♾️ Unlimited"
        } else if remaining == 0 {
            return "🚫 Limit reached"
        } else {
            return "\(remaining) left today"
        }
    }

    /// Get a user-friendly usage status string for tracker features
    func getUsageStatusText(for feature: TrackerFeature) -> String {
        return isPremiumUser() ? "✅ Available" : "🔒 Premium only"
    }
    
    /// Get a user-friendly usage status string for Recipe Detective
    func getDetectiveStatusText() -> String {
        let remaining = getDetectiveUsesRemaining()
        
        if isPremiumUser() {
            if remaining == 0 {
                return "🚫 Daily limit reached"
            } else {
                return "\(remaining) left today"
            }
        }
        
        if remaining == 0 {
            return "🚫 Limit reached"
        } else {
            return "\(remaining) left (lifetime)"
        }
    }

    /// Get color for recipe usage status UI
    func getRecipeStatusColor() -> Color {
        let percentage = getRecipeUsagePercentage()

        if hasReachedRecipeLimit() {
            return .red
        } else if percentage > 0.8 {
            return .orange
        } else if percentage > 0.5 {
            return .yellow
        } else {
            return .green
        }
    }

    /// Get color for video usage status UI
    func getVideoStatusColor() -> Color {
        let percentage = getVideoUsagePercentage()

        if hasReachedVideoLimit() {
            return .red
        } else if percentage > 0.8 {
            return .orange
        } else if percentage > 0.5 {
            return .yellow
        } else {
            return .green
        }
    }

    /// Get color for tracker feature usage status UI
    func getUsageStatusColor(for feature: TrackerFeature) -> Color {
        let percentage = getUsagePercentage(for: feature)

        if hasReachedLimit(for: feature) {
            return .red
        } else if percentage > 0.8 {
            return .orange
        } else if percentage > 0.5 {
            return .yellow
        } else {
            return .green
        }
    }
    
    /// Get color for Recipe Detective usage status UI
    func getDetectiveStatusColor() -> Color {
        if isPremiumUser() {
            return .green
        }
        
        let remaining = getDetectiveUsesRemaining()
        let total = DetectiveLimits.DETECTIVE_LIFETIME_LIMIT_FREE
        let percentage = Double(total - remaining) / Double(total)
        
        if remaining == 0 {
            return .red
        } else if percentage > 0.8 {
            return .orange
        } else if percentage > 0.5 {
            return .yellow
        } else {
            return .green
        }
    }
}
