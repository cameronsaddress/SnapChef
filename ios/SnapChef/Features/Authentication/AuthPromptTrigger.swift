//
//  AuthPromptTrigger.swift
//  SnapChef
//
//  Created by Claude on 2025-01-16.
//  Progressive Authentication Implementation
//

import Foundation
import SwiftUI

/// Component for strategically triggering authentication prompts at optimal moments
/// Integrates with AnonymousUserProfile and KeychainProfileManager for smart timing
@MainActor
final class AuthPromptTrigger: ObservableObject, @unchecked Sendable {
    // MARK: - Singleton

    static let shared = AuthPromptTrigger()

    // MARK: - Dependencies

    private let profileManager = KeychainProfileManager.shared
    private let authManager = UnifiedAuthManager.shared

    // MARK: - State

    @Published var shouldShowPrompt = false
    @Published private(set) var currentContext: TriggerContext?
    @Published private(set) var lastPromptDate: Date?

    // MARK: - Constants

    private let minimumTimeBetweenPrompts: TimeInterval = 24 * 60 * 60 // 24 hours
    private let maxPromptsPerWeek = 3
    private let promptCooldownAfterDismissal: TimeInterval = 3 * 24 * 60 * 60 // 3 days

    // MARK: - Trigger Contexts

    enum TriggerContext: String, CaseIterable, Sendable {
        case firstRecipeSuccess = "first_recipe_success"
        case viralContentCreated = "viral_content_created"
        case dailyLimitReached = "daily_limit_reached"
        case socialFeatureExplored = "social_feature_explored"
        case challengeInterest = "challenge_interest"
        case shareAttempt = "share_attempt"
        case weeklyHighEngagement = "weekly_high_engagement"
        case returningUser = "returning_user"

        var title: String {
            switch self {
            case .firstRecipeSuccess:
                return "Love your first recipe?"
            case .viralContentCreated:
                return "Ready to go viral?"
            case .dailyLimitReached:
                return "Unlock unlimited recipes"
            case .socialFeatureExplored:
                return "Connect with other chefs"
            case .challengeInterest:
                return "Join cooking challenges"
            case .shareAttempt:
                return "Share with your friends"
            case .weeklyHighEngagement:
                return "You're on fire this week!"
            case .returningUser:
                return "Welcome back, chef!"
            }
        }

        var message: String {
            switch self {
            case .firstRecipeSuccess:
                return "Save your recipes and unlock premium features with a free account!"
            case .viralContentCreated:
                return "Sign in to track your viral videos and compete with other chefs!"
            case .dailyLimitReached:
                return "Create unlimited recipes and save your favorites with a free account!"
            case .socialFeatureExplored:
                return "Follow other chefs, share your creations, and join the community!"
            case .challengeInterest:
                return "Participate in daily challenges and earn rewards with other food lovers!"
            case .shareAttempt:
                return "Sign in to easily share your recipes and connect with friends!"
            case .weeklyHighEngagement:
                return "Save your progress and unlock exclusive features for active chefs!"
            case .returningUser:
                return "Pick up where you left off and sync your recipes across devices!"
            }
        }

        var priority: Int {
            switch self {
            case .firstRecipeSuccess: return 5
            case .viralContentCreated: return 8
            case .dailyLimitReached: return 9
            case .socialFeatureExplored: return 6
            case .challengeInterest: return 7
            case .shareAttempt: return 8
            case .weeklyHighEngagement: return 7
            case .returningUser: return 4
            }
        }
    }

    // MARK: - Private Initialization

    private init() {
        updatePromptState()
    }

    // MARK: - Public Interface

    /// Evaluates whether to show an authentication prompt for a specific context
    /// - Parameter context: The trigger context being evaluated
    /// - Returns: True if prompt should be shown, false otherwise
    func shouldTriggerPrompt(for context: TriggerContext) async -> Bool {
        guard let profile = await profileManager.loadProfile() else {
            return false
        }

        // Never prompt if user is already authenticated
        guard profile.authenticationState == .anonymous else {
            return false
        }

        // Respect user's "never ask again" preference
        guard profile.authenticationState != .neverAsk else {
            return false
        }

        // Check if context-specific conditions are met
        guard evaluateContextConditions(context, profile: profile) else {
            return false
        }

        // Check timing constraints
        guard evaluateTimingConstraints(context, profile: profile) else {
            return false
        }

        // Check frequency limits
        guard evaluateFrequencyLimits(profile: profile) else {
            return false
        }

        return true
    }

    /// Triggers a prompt for the specified context if conditions are met
    /// - Parameter context: The trigger context
    func triggerPrompt(for context: TriggerContext) async {
        guard await shouldTriggerPrompt(for: context) else {
            return
        }

        currentContext = context
        shouldShowPrompt = true
        lastPromptDate = Date()

        // Record the prompt event
        Task {
            await profileManager.recordAuthPromptEvent(context: context.rawValue, action: "shown")
        }
    }

    /// Records user action on the authentication prompt
    /// - Parameters:
    ///   - action: Action taken by user ("completed", "dismissed", "never")
    ///   - context: The context that triggered the prompt
    func recordPromptAction(_ action: String, for context: TriggerContext) async {
        await profileManager.recordAuthPromptEvent(context: context.rawValue, action: action)

        // Update authentication state if applicable
        switch action {
        case "completed":
            await profileManager.updateAuthenticationState(.authenticated)
        case "never":
            await profileManager.updateAuthenticationState(.neverAsk)
        case "dismissed":
            await profileManager.updateAuthenticationState(.dismissed)
        default:
            break
        }

        // Reset prompt state
        shouldShowPrompt = false
        currentContext = nil
    }

    /// Dismisses the current prompt without recording action
    func dismissPrompt() {
        shouldShowPrompt = false
        if let context = currentContext {
            Task {
                await recordPromptAction("dismissed", for: context)
            }
        }
    }

    /// Checks if user has indicated they never want to be prompted
    func hasUserOptedOut() async -> Bool {
        guard let profile = await profileManager.loadProfile() else {
            return false
        }
        return profile.authenticationState == .neverAsk
    }

    // MARK: - Context-Specific Triggers

    /// Trigger for first successful recipe creation
    func onFirstRecipeSuccess() {
        Task {
            await triggerPrompt(for: .firstRecipeSuccess)
        }
    }

    /// Trigger for viral content creation (video generation)
    func onViralContentCreated() {
        Task {
            await triggerPrompt(for: .viralContentCreated)
        }
    }

    /// Trigger when user hits daily limits (if implemented)
    func onDailyLimitReached() {
        Task {
            await triggerPrompt(for: .dailyLimitReached)
        }
    }

    /// Trigger when user explores social features
    func onSocialFeatureExplored() {
        Task {
            await triggerPrompt(for: .socialFeatureExplored)
        }
    }

    /// Trigger when user shows interest in challenges
    func onChallengeInterest() {
        Task {
            await triggerPrompt(for: .challengeInterest)
        }
    }

    /// Trigger when user attempts to share content
    func onShareAttempt() {
        Task {
            await triggerPrompt(for: .shareAttempt)
        }
    }

    /// Trigger for high engagement users
    func onWeeklyHighEngagement() {
        Task {
            await triggerPrompt(for: .weeklyHighEngagement)
        }
    }

    /// Trigger for returning users
    func onReturningUser() {
        Task {
            await triggerPrompt(for: .returningUser)
        }
    }

    // MARK: - Private Helper Methods

    /// Evaluates context-specific conditions for showing prompts
    private func evaluateContextConditions(_ context: TriggerContext, profile: AnonymousUserProfile) -> Bool {
        switch context {
        case .firstRecipeSuccess:
            return profile.recipesCreatedCount == 1 && !profile.hasShownPrompt(for: context.rawValue)

        case .viralContentCreated:
            return profile.videosGeneratedCount >= 1 && profile.hasShownSocialInterest

        case .dailyLimitReached:
            // This would be triggered by premium logic when limits are hit
            return true

        case .socialFeatureExplored:
            return profile.socialFeaturesExplored >= 1 && !profile.hasShownPrompt(for: context.rawValue)

        case .challengeInterest:
            return profile.challengesViewed >= 2 && !profile.hasShownPrompt(for: context.rawValue)

        case .shareAttempt:
            return profile.videosSharedCount >= 1 || profile.socialFeaturesExplored >= 1

        case .weeklyHighEngagement:
            return profile.engagementScore >= 3.0 && profile.daysSinceFirstLaunch >= 3

        case .returningUser:
            return profile.daysSinceLastActive >= 1 && profile.appOpenCount >= 3
        }
    }

    /// Evaluates timing constraints for showing prompts
    private func evaluateTimingConstraints(_ context: TriggerContext, profile: AnonymousUserProfile) -> Bool {
        // Don't prompt too early (within first day for most contexts)
        let minDaysForContext: Int
        switch context {
        case .firstRecipeSuccess:
            minDaysForContext = 0 // Can show immediately after first recipe
        case .returningUser:
            minDaysForContext = 1 // Only for returning users
        default:
            minDaysForContext = 0 // Most contexts can show immediately
        }

        if profile.daysSinceFirstLaunch < minDaysForContext {
            return false
        }

        // Check if user recently dismissed prompts
        if profile.hasRecentDismissals(within: 3) {
            return false
        }

        // Check minimum time between any prompts
        if let lastDate = lastPromptDate,
           Date().timeIntervalSince(lastDate) < minimumTimeBetweenPrompts {
            return false
        }

        return true
    }

    /// Evaluates frequency limits for showing prompts
    private func evaluateFrequencyLimits(profile: AnonymousUserProfile) -> Bool {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentPrompts = profile.authPromptHistory.filter { $0.date >= oneWeekAgo && $0.action == "shown" }

        return recentPrompts.count < maxPromptsPerWeek
    }

    /// Updates the internal prompt state based on current conditions
    private func updatePromptState() {
        // This could be called periodically or on app state changes
        // For now, keep it simple - prompts are triggered by specific events
    }
}

// MARK: - Analytics Extensions

extension AuthPromptTrigger {
    /// Gets analytics data about prompt performance
    func getPromptAnalytics() async -> [String: Any] {
        guard let profile = await profileManager.loadProfile() else {
            return [:]
        }

        let totalShown = profile.countAuthActions("shown")
        let totalCompleted = profile.countAuthActions("completed")
        let totalDismissed = profile.countAuthActions("dismissed")
        let totalNever = profile.countAuthActions("never")

        let conversionRate = totalShown > 0 ? Double(totalCompleted) / Double(totalShown) : 0.0
        let dismissalRate = totalShown > 0 ? Double(totalDismissed) / Double(totalShown) : 0.0

        return [
            "totalPromptsShown": totalShown,
            "totalCompleted": totalCompleted,
            "totalDismissed": totalDismissed,
            "totalNever": totalNever,
            "conversionRate": conversionRate,
            "dismissalRate": dismissalRate,
            "userOptedOut": await hasUserOptedOut(),
            "engagementScore": profile.engagementScore
        ]
    }

    /// Gets the most effective prompt contexts for analytics
    func getContextEffectiveness() async -> [String: Double] {
        guard let profile = await profileManager.loadProfile() else {
            return [:]
        }

        var contextStats: [String: (shown: Int, completed: Int)] = [:]

        // Group events by context
        for event in profile.authPromptHistory where contextStats[event.context] == nil {
            contextStats[event.context] = (shown: 0, completed: 0)
        }

        for event in profile.authPromptHistory where event.action == "shown" {
            contextStats[event.context]?.shown += 1
        }

        for event in profile.authPromptHistory where event.action == "completed" {
            contextStats[event.context]?.completed += 1
        }

        // Calculate conversion rates
        var effectiveness: [String: Double] = [:]
        for (context, stats) in contextStats where stats.shown > 0 {
            effectiveness[context] = Double(stats.completed) / Double(stats.shown)
        }

        return effectiveness
    }
}

// MARK: - Debug Extensions

#if DEBUG
extension AuthPromptTrigger {
    /// Resets all prompt history for testing
    func resetForTesting() async {
        shouldShowPrompt = false
        currentContext = nil
        lastPromptDate = nil
        await profileManager.resetProfileForTesting()
    }

    /// Forces a prompt for testing purposes
    func forcePrompt(context: TriggerContext) {
        currentContext = context
        shouldShowPrompt = true
        lastPromptDate = Date()
    }

    /// Simulates user actions for testing
    func simulatePromptShown(for context: TriggerContext) async {
        await profileManager.recordAuthPromptEvent(context: context.rawValue, action: "shown")
    }

    func simulatePromptCompleted(for context: TriggerContext) async {
        await profileManager.recordAuthPromptEvent(context: context.rawValue, action: "completed")
        await profileManager.updateAuthenticationState(.authenticated)
    }

    func simulatePromptDismissed(for context: TriggerContext) async {
        await profileManager.recordAuthPromptEvent(context: context.rawValue, action: "dismissed")
        await profileManager.updateAuthenticationState(.dismissed)
    }
}
#endif
