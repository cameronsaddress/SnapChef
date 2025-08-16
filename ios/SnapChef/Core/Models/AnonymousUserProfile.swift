//
//  AnonymousUserProfile.swift
//  SnapChef
//
//  Created by Claude on 2025-01-16.
//  Progressive Authentication Implementation
//

import Foundation

/// Model for tracking anonymous user behavior and authentication state
/// Uses device-based identification with secure Keychain persistence
struct AnonymousUserProfile: Codable, Sendable {

    // MARK: - Core Identification

    /// Unique device identifier for anonymous user tracking
    let deviceID: UUID

    /// Date when the app was first opened on this device
    let firstLaunchDate: Date

    /// Most recent activity timestamp for engagement tracking
    var lastActiveDate: Date

    // MARK: - Usage Analytics

    /// Total number of times the app has been opened
    var appOpenCount: Int

    /// Number of recipes successfully created by the user
    var recipesCreatedCount: Int

    /// Number of recipe detail views accessed
    var recipesViewedCount: Int

    /// Number of TikTok videos generated
    var videosGeneratedCount: Int

    /// Number of videos shared to social platforms
    var videosSharedCount: Int

    /// Number of challenges viewed or interacted with
    var challengesViewed: Int

    /// Number of social features explored (feed, following, etc.)
    var socialFeaturesExplored: Int

    // MARK: - Authentication Tracking

    /// History of authentication prompts shown to the user
    var authPromptHistory: [AuthPromptEvent]

    /// Current authentication state for progressive prompting
    var authenticationState: AuthenticationState

    // MARK: - Nested Types

    /// Possible authentication states for progressive onboarding
    enum AuthenticationState: String, Codable, Sendable {
        case anonymous = "anonymous"           // Never prompted to authenticate
        case prompted = "prompted"             // Shown auth prompt but declined
        case dismissed = "dismissed"           // User said "maybe later"
        case neverAsk = "never_ask"           // User opted out permanently
        case authenticated = "authenticated"   // Successfully signed in
    }

    /// Record of authentication prompt interactions
    struct AuthPromptEvent: Codable, Sendable {
        /// When the prompt event occurred
        let date: Date

        /// Context where prompt was shown (e.g., "firstRecipeSuccess", "viralContentCreated")
        let context: String

        /// User action taken ("shown", "dismissed", "completed", "never")
        let action: String
    }

    // MARK: - Initialization

    /// Creates a new anonymous profile for first-time users
    /// - Parameter deviceID: Unique device identifier
    init(deviceID: UUID = UUID()) {
        self.deviceID = deviceID
        self.firstLaunchDate = Date()
        self.lastActiveDate = Date()
        self.appOpenCount = 1
        self.recipesCreatedCount = 0
        self.recipesViewedCount = 0
        self.videosGeneratedCount = 0
        self.videosSharedCount = 0
        self.challengesViewed = 0
        self.socialFeaturesExplored = 0
        self.authPromptHistory = []
        self.authenticationState = .anonymous
    }

    // MARK: - Computed Properties

    /// Days since first app launch for engagement analysis
    var daysSinceFirstLaunch: Int {
        Calendar.current.dateComponents([.day], from: firstLaunchDate, to: Date()).day ?? 0
    }

    /// Days since last activity for re-engagement targeting
    var daysSinceLastActive: Int {
        Calendar.current.dateComponents([.day], from: lastActiveDate, to: Date()).day ?? 0
    }

    /// Total content creation actions for engagement scoring
    var totalCreationActions: Int {
        recipesCreatedCount + videosGeneratedCount + videosSharedCount
    }

    /// Whether user has shown social media interest
    var hasShownSocialInterest: Bool {
        videosGeneratedCount > 0 || videosSharedCount > 0 || socialFeaturesExplored > 0
    }

    /// Whether user has explored gamification features
    var hasShownGamificationInterest: Bool {
        challengesViewed > 0
    }

    // MARK: - State Management

    /// Updates last active timestamp for engagement tracking
    mutating func updateLastActive() {
        lastActiveDate = Date()
    }

    /// Increments app open count and updates activity
    mutating func trackAppOpen() {
        appOpenCount += 1
        updateLastActive()
    }

    /// Records a new authentication prompt event
    /// - Parameters:
    ///   - context: Context where prompt was shown
    ///   - action: Action taken by user
    mutating func addAuthPromptEvent(context: String, action: String) {
        let event = AuthPromptEvent(date: Date(), context: context, action: action)
        authPromptHistory.append(event)
        updateLastActive()
    }

    /// Checks if a specific prompt context has been shown before
    /// - Parameter context: Context to check for
    /// - Returns: True if this context has been shown before
    func hasShownPrompt(for context: String) -> Bool {
        authPromptHistory.contains { $0.context == context }
    }

    /// Checks if user has dismissed prompts in the last N days
    /// - Parameter days: Number of days to check
    /// - Returns: True if user has dismissed prompts recently
    func hasRecentDismissals(within days: Int) -> Bool {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return authPromptHistory.contains { event in
            event.date >= cutoffDate && (event.action == "dismissed" || event.action == "never")
        }
    }

    /// Gets the number of times a specific action has been taken
    /// - Parameter action: Action type to count
    /// - Returns: Count of actions
    func countAuthActions(_ action: String) -> Int {
        authPromptHistory.filter { $0.action == action }.count
    }
}

// MARK: - Analytics Extensions

extension AnonymousUserProfile {

    /// Engagement score for determining optimal authentication timing
    var engagementScore: Double {
        let recipeWeight = 3.0
        let videoWeight = 5.0
        let shareWeight = 7.0
        let socialWeight = 2.0
        let challengeWeight = 2.0
        let frequencyWeight = 1.0

        let contentScore = Double(recipesCreatedCount) * recipeWeight +
                          Double(videosGeneratedCount) * videoWeight +
                          Double(videosSharedCount) * shareWeight +
                          Double(socialFeaturesExplored) * socialWeight +
                          Double(challengesViewed) * challengeWeight

        let frequencyScore = Double(appOpenCount) * frequencyWeight

        // Normalize by days active to get daily engagement
        let daysActive = max(1, daysSinceFirstLaunch)
        return (contentScore + frequencyScore) / Double(daysActive)
    }

    /// Whether user is in the optimal window for authentication prompts
    var isInOptimalAuthWindow: Bool {
        // Sweet spot: 1-7 days, created content, not recently dismissed
        let timeWindow = daysSinceFirstLaunch >= 1 && daysSinceFirstLaunch <= 7
        let hasContent = totalCreationActions >= 1
        let notRecentlyDismissed = !hasRecentDismissals(within: 3)

        return timeWindow && hasContent && notRecentlyDismissed && authenticationState == .anonymous
    }
}