//
//  PaywallTriggerManager.swift
//  SnapChef
//
//  Created by Claude on 2025-01-17.
//  Smart Paywall Trigger System for Progressive Premium Strategy
//

import Foundation
import SwiftUI

// MARK: - Paywall Context

/// Context for when and why a paywall is being shown
public enum PaywallContext: String, CaseIterable, Sendable {
    case recipeLimitReached = "recipe_limit_reached"
    case videoLimitReached = "video_limit_reached"
    case premiumFeatureAccess = "premium_feature_access"
    case engagementMilestone = "engagement_milestone"
    case naturalBreakPoint = "natural_break_point"
    case honeymoonEnding = "honeymoon_ending"
    case trialEnding = "trial_ending"
    case organicUpgrade = "organic_upgrade"

    /// Human-readable title for the paywall
    public var title: String {
        switch self {
        case .recipeLimitReached:
            return "Recipe Limit Reached"
        case .videoLimitReached:
            return "Video Limit Reached"
        case .premiumFeatureAccess:
            return "Premium Feature"
        case .engagementMilestone:
            return "You're on Fire!"
        case .naturalBreakPoint:
            return "Ready for More?"
        case .honeymoonEnding:
            return "Premium Preview Ending"
        case .trialEnding:
            return "Trial Ending Soon"
        case .organicUpgrade:
            return "Unlock Everything"
        }
    }

    /// Contextual message for this trigger
    public var message: String {
        switch self {
        case .recipeLimitReached:
            return "You've reached your daily recipe limit. Upgrade to Premium for unlimited recipes!"
        case .videoLimitReached:
            return "You've used all your daily videos. Get unlimited video creation with Premium!"
        case .premiumFeatureAccess:
            return "This feature is available with Premium. Unlock all advanced features!"
        case .engagementMilestone:
            return "You've created amazing recipes! Get unlimited access with Premium."
        case .naturalBreakPoint:
            return "Love what you're seeing? Upgrade to Premium for the full experience!"
        case .honeymoonEnding:
            return "Your premium preview ends in {days} days. Keep unlimited access!"
        case .trialEnding:
            return "Your trial ends in {days} days. Don't lose your progress!"
        case .organicUpgrade:
            return "Ready to unlock the full SnapChef experience?"
        }
    }

    /// Priority for showing this paywall (higher = more important)
    public var priority: Int {
        switch self {
        case .recipeLimitReached, .videoLimitReached:
            return 100 // Highest - hard limits
        case .honeymoonEnding, .trialEnding:
            return 90  // Very high - time-sensitive
        case .premiumFeatureAccess:
            return 80  // High - user requested feature
        case .engagementMilestone:
            return 70  // Medium-high - user is engaged
        case .naturalBreakPoint:
            return 60  // Medium - opportunistic
        case .organicUpgrade:
            return 50  // Low - general upgrade
        }
    }
}

// MARK: - Paywall Trigger Rules

/// Configuration for when paywalls should trigger
public struct PaywallTriggerRules: Sendable {
    public let minimumDaysSinceInstall: Int
    public let minimumRecipesCreated: Int
    public let minimumVideosShared: Int
    public let cooldownHours: Int
    public let maxDismissalsPerDay: Int
    public let honeymoonWarningDays: Int
    public let trialWarningDays: Int

    /// Default trigger rules based on premium strategy
    public static let standard = PaywallTriggerRules(
        minimumDaysSinceInstall: 3,     // Never show in first 3 days
        minimumRecipesCreated: 10,      // Show after 10 recipes created
        minimumVideosShared: 3,         // Show after 3 videos shared
        cooldownHours: 6,               // 6 hour cooldown between paywalls
        maxDismissalsPerDay: 3,         // Max 3 dismissals per day
        honeymoonWarningDays: 2,        // Warn 2 days before honeymoon ends
        trialWarningDays: 5             // Warn 5 days before trial ends
    )

    /// Conservative rules for testing
    public static let conservative = PaywallTriggerRules(
        minimumDaysSinceInstall: 7,
        minimumRecipesCreated: 20,
        minimumVideosShared: 5,
        cooldownHours: 12,
        maxDismissalsPerDay: 2,
        honeymoonWarningDays: 1,
        trialWarningDays: 3
    )

    /// Aggressive rules for high engagement users
    public static let aggressive = PaywallTriggerRules(
        minimumDaysSinceInstall: 1,
        minimumRecipesCreated: 5,
        minimumVideosShared: 2,
        cooldownHours: 3,
        maxDismissalsPerDay: 5,
        honeymoonWarningDays: 3,
        trialWarningDays: 7
    )
}

// MARK: - Paywall Analytics Data

/// Analytics data for paywall tracking
public struct PaywallAnalyticsData: Sendable {
    public let context: PaywallContext
    public let userPhase: UserPhase
    public let daysActive: Int
    public let recipesCreated: Int
    public let videosShared: Int
    public let dismissalCount: Int
    public let previousConversions: Int
    public let timestamp: Date

    /// Converts to dictionary for analytics tracking
    public var analyticsData: [String: Any] {
        return [
            "paywall_context": context.rawValue,
            "user_phase": userPhase.rawValue,
            "days_active": daysActive,
            "recipes_created": recipesCreated,
            "videos_shared": videosShared,
            "dismissal_count": dismissalCount,
            "previous_conversions": previousConversions,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }
}

// MARK: - Paywall Trigger Manager

/// Manages when and how paywalls are triggered based on user behavior and lifecycle
@MainActor
final class PaywallTriggerManager: ObservableObject, @unchecked Sendable {
    // MARK: - Singleton
    static let shared = PaywallTriggerManager()

    // MARK: - Published Properties
    @Published private(set) var isInCooldown: Bool = false
    @Published private(set) var lastPaywallContext: PaywallContext?
    @Published private(set) var todaysDismissals: Int = 0
    @Published private(set) var totalConversions: Int = 0

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let lifecycleManager = UserLifecycleManager.shared
    private let usageTracker = UsageTracker.shared
    private let subscriptionManager = SubscriptionManager.shared
    private var currentRules: PaywallTriggerRules = .standard

    // UserDefaults Keys
    private enum Keys {
        static let lastPaywallDate = "paywall_trigger_last_shown"
        static let lastPaywallContext = "paywall_trigger_last_context"
        static let todaysDismissals = "paywall_trigger_todays_dismissals"
        static let dismissalResetDate = "paywall_trigger_dismissal_reset_date"
        static let totalConversions = "paywall_trigger_total_conversions"
        static let totalPaywallsShown = "paywall_trigger_total_shown"
        static let currentRules = "paywall_trigger_current_rules"
        static let abTestGroup = "paywall_trigger_ab_test_group"
    }

    // MARK: - Initialization

    private init() {
        loadPersistedData()
        setupABTestGroup()
        checkForNewDay()
    }

    // MARK: - Public Interface

    /// Determines if a paywall should be shown for the given context
    /// - Parameter context: The context for the paywall trigger
    /// - Returns: True if paywall should be shown, false otherwise
    func shouldShowPaywall(for context: PaywallContext) -> Bool {
        // Never show to premium users
        guard !subscriptionManager.isPremium else {
            return false
        }

        // Check basic eligibility
        guard isEligibleForPaywall() else {
            return false
        }

        // Check context-specific rules
        guard shouldTriggerForContext(context) else {
            return false
        }

        // Check cooldown and dismissal limits
        guard !isInCooldown && todaysDismissals < currentRules.maxDismissalsPerDay else {
            return false
        }

        // Passed all checks
        return true
    }

    /// Records that a paywall was shown
    /// - Parameter context: The context for which the paywall was shown
    func recordPaywallShown(context: PaywallContext) {
        let now = Date()

        // Update last shown data
        userDefaults.set(now, forKey: Keys.lastPaywallDate)
        userDefaults.set(context.rawValue, forKey: Keys.lastPaywallContext)
        lastPaywallContext = context

        // Start cooldown
        startCooldown()

        // Increment total shown count
        let totalShown = userDefaults.integer(forKey: Keys.totalPaywallsShown)
        userDefaults.set(totalShown + 1, forKey: Keys.totalPaywallsShown)

        // Track analytics
        trackPaywallAnalytics(event: "paywall_shown", context: context)

        logMessage("Paywall shown for context: \(context.rawValue)")
    }

    /// Records that a paywall was dismissed by the user
    func recordPaywallDismissed() {
        todaysDismissals += 1
        userDefaults.set(todaysDismissals, forKey: Keys.todaysDismissals)

        // Track analytics
        if let context = lastPaywallContext {
            trackPaywallAnalytics(event: "paywall_dismissed", context: context)
        }

        logMessage("Paywall dismissed. Today's dismissals: \(todaysDismissals)")
    }

    /// Records that a user converted from a paywall
    func recordPaywallConverted() {
        totalConversions += 1
        userDefaults.set(totalConversions, forKey: Keys.totalConversions)

        // Reset dismissal count as user converted
        todaysDismissals = 0
        userDefaults.set(0, forKey: Keys.todaysDismissals)

        // Track analytics
        if let context = lastPaywallContext {
            trackPaywallAnalytics(event: "paywall_converted", context: context)
        }

        logMessage("Paywall conversion recorded. Total conversions: \(totalConversions)")
    }

    /// Resets the cooldown period (for testing or admin purposes)
    func resetCooldown() {
        isInCooldown = false
        userDefaults.removeObject(forKey: Keys.lastPaywallDate)

        logMessage("Paywall cooldown reset")
    }

    /// Updates the trigger rules (for A/B testing)
    /// - Parameter rules: New rules to apply
    func updateTriggerRules(_ rules: PaywallTriggerRules) {
        currentRules = rules

        // Save to UserDefaults for persistence
        if let encoded = try? JSONEncoder().encode(rules) {
            userDefaults.set(encoded, forKey: Keys.currentRules)
        }

        logMessage("Trigger rules updated")
    }

    /// Gets the most appropriate paywall context for current user state
    /// - Returns: Suggested paywall context or nil if none appropriate
    func getSuggestedPaywallContext() -> PaywallContext? {
        // Note: User lifecycle data available but not used in this simple implementation
        _ = lifecycleManager.getCurrentPhase()
        _ = lifecycleManager.daysActive
        _ = lifecycleManager.recipesCreated
        _ = lifecycleManager.videosShared

        // Priority order based on context priority
        let potentialContexts: [(PaywallContext, Bool)] = [
            (.recipeLimitReached, usageTracker.hasReachedRecipeLimit()),
            (.videoLimitReached, usageTracker.hasReachedVideoLimit()),
            (.honeymoonEnding, shouldWarnAboutHoneymoonEnding()),
            (.trialEnding, shouldWarnAboutTrialEnding()),
            (.engagementMilestone, hasReachedEngagementMilestone()),
            (.naturalBreakPoint, shouldShowAtNaturalBreakPoint()),
            (.organicUpgrade, shouldShowOrganicUpgrade())
        ]

        // Find highest priority applicable context
        return potentialContexts
            .filter { $0.1 && shouldShowPaywall(for: $0.0) }
            .max(by: { $0.0.priority < $1.0.priority })?.0
    }

    /// Gets analytics data for paywall performance
    /// - Returns: Dictionary with analytics data
    func getAnalyticsData() -> [String: Any] {
        let totalShown = userDefaults.integer(forKey: Keys.totalPaywallsShown)
        let conversionRate = totalShown > 0 ? Double(totalConversions) / Double(totalShown) : 0.0

        return [
            "total_paywalls_shown": totalShown,
            "total_conversions": totalConversions,
            "conversion_rate": conversionRate,
            "todays_dismissals": todaysDismissals,
            "is_in_cooldown": isInCooldown,
            "current_rules": currentRules.debugDescription,
            "ab_test_group": userDefaults.string(forKey: Keys.abTestGroup) ?? "control"
        ]
    }

    // MARK: - Private Methods

    private func loadPersistedData() {
        // Load dismissal count and check if it's from today
        let dismissalDate = userDefaults.object(forKey: Keys.dismissalResetDate) as? Date
        if let date = dismissalDate, Calendar.current.isDate(date, inSameDayAs: Date()) {
            todaysDismissals = userDefaults.integer(forKey: Keys.todaysDismissals)
        } else {
            todaysDismissals = 0
            userDefaults.set(Date(), forKey: Keys.dismissalResetDate)
            userDefaults.set(0, forKey: Keys.todaysDismissals)
        }

        // Load total conversions
        totalConversions = userDefaults.integer(forKey: Keys.totalConversions)

        // Load last context
        if let contextRaw = userDefaults.string(forKey: Keys.lastPaywallContext) {
            lastPaywallContext = PaywallContext(rawValue: contextRaw)
        }

        // Load custom rules if any
        if let rulesData = userDefaults.data(forKey: Keys.currentRules),
           let rules = try? JSONDecoder().decode(PaywallTriggerRules.self, from: rulesData) {
            currentRules = rules
        }

        // Check cooldown status
        checkCooldownStatus()
    }

    private func setupABTestGroup() {
        // Assign A/B test group if not already assigned
        if userDefaults.string(forKey: Keys.abTestGroup) == nil {
            let groups = ["control", "conservative", "aggressive"]
            let randomGroup = groups.randomElement() ?? "control"
            userDefaults.set(randomGroup, forKey: Keys.abTestGroup)

            // Apply corresponding rules
            switch randomGroup {
            case "conservative":
                updateTriggerRules(.conservative)
            case "aggressive":
                updateTriggerRules(.aggressive)
            default:
                updateTriggerRules(.standard)
            }
        }
    }

    private func checkForNewDay() {
        let dismissalDate = userDefaults.object(forKey: Keys.dismissalResetDate) as? Date
        let today = Date()

        if let lastDate = dismissalDate, !Calendar.current.isDate(lastDate, inSameDayAs: today) {
            // Reset daily counters
            todaysDismissals = 0
            userDefaults.set(0, forKey: Keys.todaysDismissals)
            userDefaults.set(today, forKey: Keys.dismissalResetDate)
        }
    }

    private func isEligibleForPaywall() -> Bool {
        let daysActive = lifecycleManager.daysActive
        let recipesCreated = lifecycleManager.recipesCreated
        let videosShared = lifecycleManager.videosShared

        // Check minimum requirements
        return daysActive >= currentRules.minimumDaysSinceInstall &&
               recipesCreated >= currentRules.minimumRecipesCreated &&
               videosShared >= currentRules.minimumVideosShared
    }

    private func shouldTriggerForContext(_ context: PaywallContext) -> Bool {
        switch context {
        case .recipeLimitReached:
            return usageTracker.hasReachedRecipeLimit()
        case .videoLimitReached:
            return usageTracker.hasReachedVideoLimit()
        case .premiumFeatureAccess:
            return true // Always valid when user tries to access premium feature
        case .engagementMilestone:
            return hasReachedEngagementMilestone()
        case .naturalBreakPoint:
            return shouldShowAtNaturalBreakPoint()
        case .honeymoonEnding:
            return shouldWarnAboutHoneymoonEnding()
        case .trialEnding:
            return shouldWarnAboutTrialEnding()
        case .organicUpgrade:
            return shouldShowOrganicUpgrade()
        }
    }

    private func hasReachedEngagementMilestone() -> Bool {
        let recipesCreated = lifecycleManager.recipesCreated
        let videosShared = lifecycleManager.videosShared

        // Engagement milestones: 5, 10, 25, 50 recipes or 3, 5, 10 videos
        let recipeMilestones = [5, 10, 25, 50]
        let videoMilestones = [3, 5, 10]

        return recipeMilestones.contains(recipesCreated) || videoMilestones.contains(videosShared)
    }

    private func shouldShowAtNaturalBreakPoint() -> Bool {
        // Natural break points: after completing a recipe generation, before sharing
        // This would be determined by the calling context
        let recipesCreated = lifecycleManager.recipesCreated
        let currentPhase = lifecycleManager.getCurrentPhase()

        // Show at natural points during trial/standard phases
        return currentPhase != .honeymoon && recipesCreated > 3
    }

    private func shouldWarnAboutHoneymoonEnding() -> Bool {
        let currentPhase = lifecycleManager.getCurrentPhase()
        let daysActive = lifecycleManager.daysActive

        return currentPhase == .honeymoon &&
               daysActive >= (7 - currentRules.honeymoonWarningDays)
    }

    private func shouldWarnAboutTrialEnding() -> Bool {
        let currentPhase = lifecycleManager.getCurrentPhase()
        let daysActive = lifecycleManager.daysActive

        return currentPhase == .trial &&
               daysActive >= (30 - currentRules.trialWarningDays)
    }

    private func shouldShowOrganicUpgrade() -> Bool {
        let currentPhase = lifecycleManager.getCurrentPhase()
        let recipesCreated = lifecycleManager.recipesCreated

        // Show organic upgrade during standard phase with good engagement
        return currentPhase == .standard && recipesCreated >= 15
    }

    private func checkCooldownStatus() {
        guard let lastPaywallDate = userDefaults.object(forKey: Keys.lastPaywallDate) as? Date else {
            isInCooldown = false
            return
        }

        let hoursSinceLastPaywall = Date().timeIntervalSince(lastPaywallDate) / 3_600
        isInCooldown = hoursSinceLastPaywall < Double(currentRules.cooldownHours)
    }

    private func startCooldown() {
        isInCooldown = true

        // Schedule cooldown end
        let cooldownSeconds = Double(currentRules.cooldownHours * 3_600)
        Timer.scheduledTimer(withTimeInterval: cooldownSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isInCooldown = false
                self?.logMessage("Paywall cooldown ended")
            }
        }
    }

    private func trackPaywallAnalytics(event: String, context: PaywallContext) {
        let analyticsData = PaywallAnalyticsData(
            context: context,
            userPhase: lifecycleManager.getCurrentPhase(),
            daysActive: lifecycleManager.daysActive,
            recipesCreated: lifecycleManager.recipesCreated,
            videosShared: lifecycleManager.videosShared,
            dismissalCount: todaysDismissals,
            previousConversions: totalConversions,
            timestamp: Date()
        )

        // Local analytics tracking for paywall events
        var eventData = analyticsData.analyticsData
        eventData["event_name"] = event
        eventData["timestamp"] = Date()
        eventData["user_id"] = UserDefaults.standard.string(forKey: "userId") ?? "anonymous"

        // Store locally for potential future upload
        var events = UserDefaults.standard.array(forKey: "paywall_analytics_events") as? [[String: Any]] ?? []
        events.append(eventData)

        // Keep only last 200 paywall events
        if events.count > 200 {
            events = Array(events.suffix(200))
        }

        UserDefaults.standard.set(events, forKey: "paywall_analytics_events")
        logMessage("📊 Analytics: \(event) - \(eventData)")
    }

    private func logMessage(_ message: String) {
        NSLog("💰 PaywallTriggerManager: \(message)")
    }
}

// MARK: - PaywallTriggerRules Codable Extension

extension PaywallTriggerRules: Codable {
    var debugDescription: String {
        return """
        PaywallTriggerRules(
            minDays: \(minimumDaysSinceInstall),
            minRecipes: \(minimumRecipesCreated),
            minVideos: \(minimumVideosShared),
            cooldown: \(cooldownHours)h,
            maxDismissals: \(maxDismissalsPerDay),
            honeymoonWarning: \(honeymoonWarningDays)d,
            trialWarning: \(trialWarningDays)d
        )
        """
    }
}

// MARK: - Debug Extensions

#if DEBUG
extension PaywallTriggerManager {
    /// Resets all paywall data for testing
    func resetForTesting() {
        userDefaults.removeObject(forKey: Keys.lastPaywallDate)
        userDefaults.removeObject(forKey: Keys.lastPaywallContext)
        userDefaults.removeObject(forKey: Keys.todaysDismissals)
        userDefaults.removeObject(forKey: Keys.dismissalResetDate)
        userDefaults.removeObject(forKey: Keys.totalConversions)
        userDefaults.removeObject(forKey: Keys.totalPaywallsShown)
        userDefaults.removeObject(forKey: Keys.abTestGroup)

        // Reset state
        isInCooldown = false
        lastPaywallContext = nil
        todaysDismissals = 0
        totalConversions = 0

        // Reassign A/B test group
        setupABTestGroup()

        logMessage("Reset all data for testing")
    }

    /// Simulates various paywall scenarios for testing
    func simulateScenario(_ scenario: PaywallTestScenario) {
        switch scenario {
        case .newUser:
            resetForTesting()
        case .engagedUser:
            // Simulate engaged user with many recipes
            let userDefaults = UserDefaults.standard
            userDefaults.set(15, forKey: "userLifecycle.recipesCreated")
            userDefaults.set(5, forKey: "userLifecycle.videosShared")
        case .limitReached:
            // Force usage limits to be reached
            usageTracker.trackRecipeGenerated()
            usageTracker.trackRecipeGenerated()
            usageTracker.trackRecipeGenerated()
        case .cooldownActive:
            recordPaywallShown(context: .naturalBreakPoint)
        case .honeymoonEnding:
            lifecycleManager.simulatePhase(.honeymoon)
            // Set days to near end of honeymoon
            let install = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
            userDefaults.set(install, forKey: "userLifecycle.installDate")
        }

        logMessage("Simulated scenario: \(scenario)")
    }

    /// Prints debug information about current state
    func debugPrint() {
        logMessage("💰 PaywallTriggerManager Debug Info:")
        logMessage("   Is in cooldown: \(isInCooldown)")
        logMessage("   Today's dismissals: \(todaysDismissals)")
        logMessage("   Total conversions: \(totalConversions)")
        logMessage("   Last context: \(lastPaywallContext?.rawValue ?? "none")")
        logMessage("   Current rules: \(currentRules.debugDescription)")
        logMessage("   A/B test group: \(userDefaults.string(forKey: Keys.abTestGroup) ?? "unknown")")
        logMessage("   Suggested context: \(getSuggestedPaywallContext()?.rawValue ?? "none")")

        // Test all contexts
        logMessage("   Context eligibility:")
        for context in PaywallContext.allCases {
            logMessage("     \(context.rawValue): \(shouldShowPaywall(for: context))")
        }
    }
}

enum PaywallTestScenario {
    case newUser
    case engagedUser
    case limitReached
    case cooldownActive
    case honeymoonEnding
}
#endif
