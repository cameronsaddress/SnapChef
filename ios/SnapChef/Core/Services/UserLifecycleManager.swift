//
//  UserLifecycleManager.swift
//  SnapChef
//
//  Created by Claude on 2025-01-16.
//  Progressive Premium Implementation
//

import Foundation

/// Manages user lifecycle phases and premium feature limitations
/// Integrates with AnonymousUserProfile for comprehensive user tracking
@MainActor
final class UserLifecycleManager: ObservableObject, @unchecked Sendable {
    // MARK: - Singleton
    static let shared = UserLifecycleManager()

    // MARK: - Published Properties
    @Published private(set) var currentPhase: UserPhase = .honeymoon
    @Published private(set) var daysActive: Int = 0
    @Published private(set) var recipesCreated: Int = 0
    @Published private(set) var videosShared: Int = 0
    @Published private(set) var challengesCompleted: Int = 0

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let keychainManager = KeychainProfileManager.shared

    // UserDefaults Keys
    private enum Keys {
        static let installDate = "userLifecycle.installDate"
        static let lastActiveDate = "userLifecycle.lastActiveDate"
        static let daysActive = "userLifecycle.daysActive"
        static let recipesCreated = "userLifecycle.recipesCreated"
        static let videosShared = "userLifecycle.videosShared"
        static let challengesCompleted = "userLifecycle.challengesCompleted"
    }
    
    // MARK: - Initialization
    
    private init() {
        initializeUserLifecycle()
        loadPersistedData()
        updateCurrentPhase()
    }
    
    // MARK: - Public Interface
    
    /// Gets the current user phase based on days since install
    func getCurrentPhase() -> UserPhase {
        return currentPhase
    }
    
    /// Gets daily limits based on current phase and subscription status
    func getDailyLimits() -> DailyLimits {
        // Check if user has premium subscription
        let isPremium = SubscriptionManager.shared.isPremium
        
        if isPremium {
            return DailyLimits.premium
        }
        
        switch currentPhase {
        case .honeymoon:
            return DailyLimits.honeymoon
        case .trial:
            return DailyLimits.trial
        case .standard:
            return DailyLimits.starterStandard
        }
    }
    
    /// Records a recipe creation and updates counters
    func trackRecipeCreated() {
        recipesCreated += 1
        persistCounter(Keys.recipesCreated, value: recipesCreated)
        
        // Also update AnonymousUserProfile
        _ = keychainManager.incrementCounter(\.recipesCreatedCount)
        
        updateLastActive()
    }
    
    /// Records a video share and updates counters
    func trackVideoShared() {
        videosShared += 1
        persistCounter(Keys.videosShared, value: videosShared)
        
        // Also update AnonymousUserProfile
        _ = keychainManager.incrementCounter(\.videosSharedCount)
        
        updateLastActive()
    }
    
    /// Records a challenge completion and updates counters
    func trackChallengeCompleted() {
        challengesCompleted += 1
        persistCounter(Keys.challengesCompleted, value: challengesCompleted)
        
        updateLastActive()
    }
    
    /// Updates last active date and recalculates days active
    func updateLastActive() {
        let now = Date()
        userDefaults.set(now, forKey: Keys.lastActiveDate)
        
        // Update days active calculation
        if let installDate = getInstallDate() {
            let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: now).day ?? 0
            daysActive = max(0, daysSinceInstall)
            userDefaults.set(daysActive, forKey: Keys.daysActive)
        }
        
        // Update AnonymousUserProfile last active
        _ = keychainManager.updateProfile { profile in
            profile.updateLastActive()
        }
        
        updateCurrentPhase()
    }
    
    /// Gets current usage for a specific feature
    func getCurrentUsage(for feature: UsageFeature) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let key = dailyUsageKey(for: feature, date: today)
        return userDefaults.integer(forKey: key)
    }
    
    /// Records usage for a specific feature
    func recordUsage(for feature: UsageFeature) {
        let today = Calendar.current.startOfDay(for: Date())
        let key = dailyUsageKey(for: feature, date: today)
        let currentUsage = userDefaults.integer(forKey: key)
        userDefaults.set(currentUsage + 1, forKey: key)
        
        // Clean up old usage data (keep only last 7 days)
        cleanupOldUsageData(for: feature, keepDays: 7)
        
        updateLastActive()
    }
    
    /// Checks if user has reached daily limit for a feature
    func hasReachedDailyLimit(for feature: UsageFeature) -> Bool {
        let currentUsage = getCurrentUsage(for: feature)
        let limits = getDailyLimits()
        
        switch feature {
        case .recipes:
            return limits.recipes != -1 && currentUsage >= limits.recipes
        case .videos:
            return limits.videos != -1 && currentUsage >= limits.videos
        case .premiumEffects:
            return !limits.premiumEffects
        }
    }
    
    /// Gets remaining usage for a specific feature
    func getRemainingUsage(for feature: UsageFeature) -> Int {
        let currentUsage = getCurrentUsage(for: feature)
        let limits = getDailyLimits()
        
        switch feature {
        case .recipes:
            return limits.recipes == -1 ? -1 : max(0, limits.recipes - currentUsage)
        case .videos:
            return limits.videos == -1 ? -1 : max(0, limits.videos - currentUsage)
        case .premiumEffects:
            return limits.premiumEffects ? -1 : 0
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeUserLifecycle() {
        // Set install date if this is first launch
        if userDefaults.object(forKey: Keys.installDate) == nil {
            userDefaults.set(Date(), forKey: Keys.installDate)
        }
        
        // Initialize last active date if needed
        if userDefaults.object(forKey: Keys.lastActiveDate) == nil {
            userDefaults.set(Date(), forKey: Keys.lastActiveDate)
        }
    }
    
    private func loadPersistedData() {
        daysActive = userDefaults.integer(forKey: Keys.daysActive)
        recipesCreated = userDefaults.integer(forKey: Keys.recipesCreated)
        videosShared = userDefaults.integer(forKey: Keys.videosShared)
        challengesCompleted = userDefaults.integer(forKey: Keys.challengesCompleted)
    }
    
    private func updateCurrentPhase() {
        guard let installDate = getInstallDate() else {
            currentPhase = .honeymoon
            return
        }
        
        let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        
        switch daysSinceInstall {
        case 0...7:
            currentPhase = .honeymoon
        case 8...30:
            currentPhase = .trial
        default:
            currentPhase = .standard
        }
    }
    
    private func getInstallDate() -> Date? {
        return userDefaults.object(forKey: Keys.installDate) as? Date
    }
    
    private func persistCounter(_ keyType: String, value: Int) {
        userDefaults.set(value, forKey: keyType)
    }
    
    private func dailyUsageKey(for feature: UsageFeature, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return "dailyUsage.\(feature.rawValue).\(dateString)"
    }
    
    private func cleanupOldUsageData(for feature: UsageFeature, keepDays: Int) {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -keepDays, to: Date()) ?? Date()
        
        // Get all UserDefaults keys
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Filter keys for this feature that are older than cutoff
        let keysToRemove = allKeys.filter { key in
            if key.hasPrefix("dailyUsage.\(feature.rawValue).") {
                let dateString = String(key.dropFirst("dailyUsage.\(feature.rawValue).".count))
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: dateString) {
                    return date < cutoffDate
                }
            }
            return false
        }
        
        // Remove old keys
        for key in keysToRemove {
            userDefaults.removeObject(forKey: key)
        }
    }
}

// MARK: - Data Models
// UserPhase, DailyLimits, and UsageFeature are imported from UserLifecycle.swift

// MARK: - Analytics Extensions

extension UserLifecycleManager {
    
    /// Gets comprehensive analytics data for tracking
    func getAnalyticsData() -> [String: Any] {
        let anonymousData = keychainManager.getAnalyticsData()
        
        var data: [String: Any] = [
            "currentPhase": currentPhase.rawValue,
            "daysActive": daysActive,
            "recipesCreated": recipesCreated,
            "videosShared": videosShared,
            "challengesCompleted": challengesCompleted,
            "installDate": getInstallDate()?.timeIntervalSince1970 ?? 0,
            "dailyLimits": [
                "recipes": getDailyLimits().recipes,
                "videos": getDailyLimits().videos,
                "premiumEffects": getDailyLimits().premiumEffects
            ]
        ]
        
        // Merge with anonymous profile data
        data.merge(anonymousData) { _, new in new }
        
        return data
    }
    
    /// Tracks phase transition events
    private func trackPhaseTransition(from oldPhase: UserPhase, to newPhase: UserPhase) {
        // This would integrate with your analytics service
        #if DEBUG
        print("📊 User phase transition: \(oldPhase.rawValue) → \(newPhase.rawValue)")
        #endif
    }
}

// MARK: - Debug Extensions

#if DEBUG
extension UserLifecycleManager {
    
    /// Resets all lifecycle data for testing
    func resetForTesting() {
        userDefaults.removeObject(forKey: Keys.installDate)
        userDefaults.removeObject(forKey: Keys.lastActiveDate)
        userDefaults.removeObject(forKey: Keys.daysActive)
        userDefaults.removeObject(forKey: Keys.recipesCreated)
        userDefaults.removeObject(forKey: Keys.videosShared)
        userDefaults.removeObject(forKey: Keys.challengesCompleted)
        
        // Clear daily usage data
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let usageKeys = allKeys.filter { $0.hasPrefix("dailyUsage.") }
        for key in usageKeys {
            userDefaults.removeObject(forKey: key)
        }
        
        initializeUserLifecycle()
        loadPersistedData()
        updateCurrentPhase()
    }
    
    /// Simulates phase progression for testing
    func simulatePhase(_ phase: UserPhase) {
        let now = Date()
        let daysToSubtract: Int
        
        switch phase {
        case .honeymoon:
            daysToSubtract = 3 // Day 3 of honeymoon
        case .trial:
            daysToSubtract = -15 // Day 15 of trial
        case .standard:
            daysToSubtract = -35 // Day 35, standard phase
        }
        
        let simulatedInstallDate = Calendar.current.date(byAdding: .day, value: daysToSubtract, to: now) ?? now
        userDefaults.set(simulatedInstallDate, forKey: Keys.installDate)
        
        updateCurrentPhase()
    }
    
    /// Prints debug information
    func debugPrint() {
        print("🔄 UserLifecycleManager Debug Info:")
        print("   Current Phase: \(currentPhase.rawValue)")
        print("   Days Active: \(daysActive)")
        print("   Recipes Created: \(recipesCreated)")
        print("   Videos Shared: \(videosShared)")
        print("   Challenges Completed: \(challengesCompleted)")
        print("   Install Date: \(getInstallDate() ?? Date())")
        print("   Daily Limits: \(getDailyLimits())")
        
        for feature in UsageFeature.allCases {
            let usage = getCurrentUsage(for: feature)
            let remaining = getRemainingUsage(for: feature)
            print("   \(feature.displayName): \(usage) used, \(remaining == -1 ? "unlimited" : "\(remaining)") remaining")
        }
    }
}
#endif
