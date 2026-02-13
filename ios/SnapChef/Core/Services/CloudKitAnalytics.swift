import Foundation

/// Legacy compatibility surface for older analytics call-sites.
///
/// New analytics and growth-loop behavior lives in `AnalyticsManager`,
/// `GrowthLoopManager`, and `CloudKitDataManager`.
@MainActor
final class CloudKitAnalytics {
    static let shared = CloudKitAnalytics()

    private let trackedScreens: Set<String> = ["Home", "Camera", "Recipes", "Feed", "Profile", "ChallengeHub"]
    private let trackedFeatures: Set<String> = [
        "recipe_generated",
        "challenge_joined",
        "recipe_shared",
        "achievement_earned",
        "premium_feature_used",
        "waiting_game_shown",
        "waiting_game_manual_start",
        "waiting_game_auto_start",
        "waiting_game_dismissed",
        "viral_prompt_shown",
        "viral_cta_tapped",
        "viral_share_started",
        "referral_attributed_open",
        "referral_attributed_conversion"
    ]

    private init() {}

    // MARK: - Navigation Tracking

    func trackScreenView(_ screenName: String) {
        guard trackedScreens.contains(screenName) else { return }
        AnalyticsManager.shared.logScreen(screenName)
    }

    // MARK: - Feature Tracking

    func trackFeatureUsage(_ feature: String, details: [String: Any]? = nil) {
        guard trackedFeatures.contains(feature) else { return }
        AnalyticsManager.shared.logEvent(feature, parameters: details)
    }

    // MARK: - Preferences

    func syncUserPreferences(_ preferences: UserPreferences) async throws {
        // Legacy compatibility: persist app-level preference hints locally for UI continuity.
        let defaults = UserDefaults.standard
        defaults.set(preferences.dietaryRestrictions, forKey: "dietary_restrictions")
        defaults.set(preferences.cuisinePreferences, forKey: "cuisine_preferences")
        defaults.set(preferences.difficultyPreference, forKey: "difficulty_preference")
        defaults.set(preferences.cookingTimePreference, forKey: "cooking_time_preference")
        defaults.set(preferences.aiModelPreference, forKey: "SelectedLLMProvider")

        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else { return }
        try await CloudKitDataManager.shared.syncUserPreferences()
    }

    func fetchUserPreferences() async throws -> UserPreferences? {
        if CloudKitRuntimeSupport.hasCloudKitEntitlement,
           let cloudKitPreferences = try await CloudKitDataManager.shared.fetchUserPreferences() {
            return UserPreferences(
                dietaryRestrictions: cloudKitPreferences.dietaryRestrictions,
                cuisinePreferences: cloudKitPreferences.favoriteCuisines,
                difficultyPreference: cloudKitPreferences.cookingSkillLevel,
                cookingTimePreference: "\(cloudKitPreferences.preferredCookTime) mins",
                aiModelPreference: UserDefaults.standard.string(forKey: "SelectedLLMProvider") ?? "gemini",
                notificationSettings: "all",
                themePreference: "auto"
            )
        }

        let defaults = UserDefaults.standard
        return UserPreferences(
            dietaryRestrictions: defaults.stringArray(forKey: "dietary_restrictions") ?? [],
            cuisinePreferences: defaults.stringArray(forKey: "cuisine_preferences") ?? [],
            difficultyPreference: defaults.string(forKey: "difficulty_preference") ?? "medium",
            cookingTimePreference: defaults.string(forKey: "cooking_time_preference") ?? "30 mins",
            aiModelPreference: defaults.string(forKey: "SelectedLLMProvider") ?? "gemini",
            notificationSettings: "all",
            themePreference: "auto"
        )
    }

    // MARK: - Social Share Tracking

    func trackSocialShare(platform: String, contentType: String, contentID: String?) async {
        AnalyticsManager.shared.logEvent(
            "viral_share_completed_external",
            parameters: [
                "platform": platform,
                "content_type": contentType,
                "content_id": contentID ?? "",
                "source": "legacy_cloudkit_analytics"
            ]
        )
    }
}

struct UserPreferences: Codable {
    var dietaryRestrictions: [String] = []
    var cuisinePreferences: [String] = []
    var difficultyPreference: String = "medium"
    var cookingTimePreference: String = "30 mins"
    var aiModelPreference: String = "gemini"
    var notificationSettings: String = "all"
    var themePreference: String = "auto"

    init() {}

    init(
        dietaryRestrictions: [String],
        cuisinePreferences: [String],
        difficultyPreference: String,
        cookingTimePreference: String,
        aiModelPreference: String,
        notificationSettings: String,
        themePreference: String
    ) {
        self.dietaryRestrictions = dietaryRestrictions
        self.cuisinePreferences = cuisinePreferences
        self.difficultyPreference = difficultyPreference
        self.cookingTimePreference = cookingTimePreference
        self.aiModelPreference = aiModelPreference
        self.notificationSettings = notificationSettings
        self.themePreference = themePreference
    }
}
