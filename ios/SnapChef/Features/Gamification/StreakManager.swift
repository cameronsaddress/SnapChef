import Foundation
import SwiftUI
import UserNotifications

/// Main manager for all streak functionality
@MainActor
class StreakManager: ObservableObject {
    static let shared = StreakManager()
    
    // MARK: - Published Properties
    @Published var currentStreaks: [StreakType: StreakData] = [:]
    @Published var streakHistory: [StreakHistory] = []
    @Published var unclaimedAchievements: [StreakAchievement] = []
    @Published var activeInsurance: [StreakType: StreakInsurance] = [:]
    @Published var activeFreezes: [StreakType: StreakFreeze] = [:]
    @Published var teamStreaks: [TeamStreak] = []
    @Published var globalMultiplier: Double = 1.0
    @Published var isLoading = false
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private lazy var notificationCenter = UNUserNotificationCenter.current()
    private var updateTimer: Timer?
    private var midnightTimer: Timer?
    
    // Keys for UserDefaults
    private let streaksKey = "user_streaks_data"
    private let historyKey = "streak_history_data"
    private let achievementsKey = "streak_achievements_data"
    private let lastCheckKey = "last_streak_check"
    
    // MARK: - Initialization
    private init() {
        loadStreaksFromCache()
        setupTimers()
        // Don't setup notifications in init to avoid dispatch queue issues
        // setupNotifications() - removed, will be called lazily
        checkAllStreaks()
    }
    
    // MARK: - Public Methods
    
    private var hasSetupNotifications = false
    
    private func ensureNotificationsSetup() {
        guard !hasSetupNotifications else { return }
        hasSetupNotifications = true
        setupNotifications()
    }
    
    /// Record an activity for a streak type
    func recordActivity(for type: StreakType) async {
        ensureNotificationsSetup()
        var streak = currentStreaks[type] ?? StreakData(type: type)
        let calendar = Calendar.current
        
        // Check if already recorded today
        if calendar.isDateInToday(streak.lastActivityDate) {
            print("✅ Activity already recorded today for \(type.displayName)")
            return
        }
        
        // Check if streak is still active
        if streak.isActive {
            // Continue streak
            streak.currentStreak += 1
            streak.totalDaysActive += 1
            
            // Check for power-ups
            if hasPowerUp(.doubleDay, for: type) {
                streak.currentStreak += 1 // Extra day from power-up
            }
        } else {
            // Start new streak or check for restoration
            if await canRestoreStreak(type: type) {
                await restoreStreak(type: type)
                streak = currentStreaks[type]! // Get updated streak
                streak.currentStreak += 1
            } else {
                // Start fresh
                recordStreakBreak(for: streak)
                streak = StreakData(type: type)
                streak.currentStreak = 1
                streak.streakStartDate = Date()
            }
            streak.totalDaysActive += 1
        }
        
        // Update activity date
        streak.lastActivityDate = Date()
        
        // Update longest streak if needed
        if streak.currentStreak > streak.longestStreak {
            streak.longestStreak = streak.currentStreak
        }
        
        // Calculate multiplier
        streak.multiplier = calculateMultiplier(for: streak)
        
        // Check for milestones
        if let milestone = StreakMilestone.getMilestone(for: streak.currentStreak) {
            await awardMilestone(milestone, for: type)
        }
        
        // Update and save
        currentStreaks[type] = streak
        saveStreaksToCache()
        
        // Update global multiplier
        updateGlobalMultiplier()
        
        // Sync with CloudKit
        Task {
            await CloudKitStreakManager.shared.updateStreak(streak)
        }
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: Notification.Name("StreakUpdated"),
            object: nil,
            userInfo: ["type": type.rawValue, "streak": streak.currentStreak]
        )
        
        print("🔥 \(type.displayName) streak updated to \(streak.currentStreak) days!")
    }
    
    /// Freeze a streak for 24 hours
    func freezeStreak(type: StreakType, source: FreezeSource = .manual) -> Bool {
        guard var streak = currentStreaks[type] else { return false }
        
        // Check if already frozen
        if streak.isFrozen {
            print("❄️ Streak already frozen")
            return false
        }
        
        // Check freezes remaining (for non-premium)
        if source == .manual && streak.freezesRemaining <= 0 {
            print("❌ No freezes remaining")
            return false
        }
        
        // Apply freeze
        let freeze = StreakFreeze(streakType: type, source: source)
        streak.frozenUntil = freeze.expiresAt
        
        if source == .manual {
            streak.freezesRemaining -= 1
        }
        
        currentStreaks[type] = streak
        activeFreezes[type] = freeze
        saveStreaksToCache()
        
        // Schedule notification for freeze expiry
        scheduleNotification(
            title: "❄️ Freeze Expiring Soon",
            body: "Your \(type.displayName) streak freeze expires in 1 hour!",
            date: freeze.expiresAt.addingTimeInterval(-3600)
        )
        
        print("❄️ Streak frozen until \(freeze.expiresAt)")
        return true
    }
    
    /// Purchase insurance for a streak
    func purchaseInsurance(for type: StreakType) -> Bool {
        let cost = 200
        
        // Check if user has enough coins
        guard ChefCoinsManager.shared.canAfford(cost) else {
            print("💰 Not enough Chef Coins for insurance")
            return false
        }
        
        // Deduct coins
        _ = ChefCoinsManager.shared.spendCoins(cost, on: "Streak Insurance")
        
        // Create insurance
        let insurance = StreakInsurance(streakType: type)
        activeInsurance[type] = insurance
        
        print("🛡 Insurance purchased for \(type.displayName) streak")
        return true
    }
    
    /// Check if streak can be restored
    func canRestoreStreak(type: StreakType) async -> Bool {
        // Check for active insurance
        if let insurance = activeInsurance[type], insurance.isActive {
            return true
        }
        
        // Check for time machine power-up
        if hasPowerUp(.timeMachine, for: type) {
            return true
        }
        
        // Check if within grace period (premium feature)
        if SubscriptionManager.shared.isPremium {
            if let streak = currentStreaks[type] {
                let hoursSinceLastActivity = Date().timeIntervalSince(streak.lastActivityDate) / 3600
                return hoursSinceLastActivity < 48 // 48-hour grace period for premium
            }
        }
        
        return false
    }
    
    /// Get current multiplier for all streaks
    func getTotalMultiplier() -> Double {
        globalMultiplier
    }
    
    /// Claim rewards for an achievement
    func claimAchievementRewards(_ achievement: StreakAchievement) {
        guard !achievement.rewardsClaimed else { return }
        
        // Award coins
        ChefCoinsManager.shared.earnCoins(
            achievement.milestoneCoins,
            reason: "Milestone: \(achievement.milestoneTitle)"
        )
        
        // Award XP
        GamificationManager.shared.awardPoints(
            achievement.milestoneXP,
            reason: "Streak Milestone: \(achievement.milestoneTitle)"
        )
        
        // Mark as claimed
        if let index = unclaimedAchievements.firstIndex(where: { $0.id == achievement.id }) {
            unclaimedAchievements[index].rewardsClaimed = true
        }
        
        saveStreaksToCache()
    }
    
    // MARK: - Private Methods
    
    private func setupTimers() {
        // Update timer every minute
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                self.checkAllStreaks()
            }
        }
        
        // Midnight timer for daily reset check
        setupMidnightTimer()
    }
    
    private func setupMidnightTimer() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let midnight = calendar.startOfDay(for: tomorrow)
        let timeInterval = midnight.timeIntervalSince(Date())
        
        midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
            Task { @MainActor in
                self.performMidnightReset()
                self.setupMidnightTimer() // Setup for next midnight
            }
        }
    }
    
    private func performMidnightReset() {
        // Check all streaks for breaks
        for (type, streak) in currentStreaks {
            if !streak.isActive && !streak.isFrozen {
                recordStreakBreak(for: streak)
                // Reset streak
                currentStreaks[type] = StreakData(type: type)
            }
        }
        
        // Reset daily freezes for free users
        if !SubscriptionManager.shared.isPremium {
            for type in StreakType.allCases {
                if var streak = currentStreaks[type] {
                    streak.freezesRemaining = 1
                    currentStreaks[type] = streak
                }
            }
        }
        
        saveStreaksToCache()
    }
    
    private func checkAllStreaks() {
        let calendar = Calendar.current
        let now = Date()
        
        for (type, streak) in currentStreaks {
            // Check for streak at risk
            if streak.isActive && !streak.isFrozen && !calendar.isDateInToday(streak.lastActivityDate) {
                let hoursRemaining = streak.hoursUntilBreak
                
                if hoursRemaining <= 2 && hoursRemaining > 0 {
                    // Send notification
                    scheduleNotification(
                        title: "🔥 Streak at Risk!",
                        body: "Your \(streak.currentStreak)-day \(type.displayName) streak ends in \(hoursRemaining) hours!",
                        date: Date().addingTimeInterval(60) // 1 minute from now
                    )
                }
            }
            
            // Check freeze expiry
            if let freeze = activeFreezes[type], !freeze.isActive {
                activeFreezes.removeValue(forKey: type)
            }
            
            // Check insurance expiry
            if let insurance = activeInsurance[type], !insurance.isActive {
                activeInsurance.removeValue(forKey: type)
            }
        }
    }
    
    private func recordStreakBreak(for streak: StreakData) {
        guard streak.currentStreak > 0 else { return }
        
        let history = StreakHistory(
            type: streak.type,
            streakLength: streak.currentStreak,
            startDate: streak.streakStartDate,
            endDate: Date(),
            breakReason: determineBreakReason(for: streak)
        )
        
        streakHistory.append(history)
        
        // Track analytics
        Task {
            await CloudKitStreakManager.shared.recordStreakBreak(history)
        }
    }
    
    private func determineBreakReason(for streak: StreakData) -> StreakBreakReason {
        if streak.isFrozen {
            return .freezeExpired
        } else if activeInsurance[streak.type] != nil {
            return .insuranceUnavailable
        } else {
            return .missed
        }
    }
    
    private func restoreStreak(type: StreakType) async {
        guard var streak = currentStreaks[type] else { return }
        
        // Use insurance if available
        if let insurance = activeInsurance[type], insurance.isActive {
            print("🛡 Using insurance to restore streak")
            activeInsurance.removeValue(forKey: type)
        }
        // Use time machine power-up if available
        else if hasPowerUp(.timeMachine, for: type) {
            print("⏰ Using Time Machine to restore streak")
            consumePowerUp(.timeMachine, for: type)
        }
        
        // Mark history as restored
        if let lastBreak = streakHistory.last(where: { $0.type == type && !$0.wasRestored }) {
            if let index = streakHistory.firstIndex(where: { $0.id == lastBreak.id }) {
                var restoredHistory = lastBreak
                streakHistory[index] = StreakHistory(
                    type: restoredHistory.type,
                    streakLength: restoredHistory.streakLength,
                    startDate: restoredHistory.startDate,
                    endDate: restoredHistory.endDate,
                    breakReason: restoredHistory.breakReason,
                    wasRestored: true
                )
            }
        }
        
        saveStreaksToCache()
    }
    
    private func awardMilestone(_ milestone: StreakMilestone, for type: StreakType) async {
        let achievement = StreakAchievement(type: type, milestone: milestone)
        unclaimedAchievements.append(achievement)
        
        // Show celebration
        NotificationCenter.default.post(
            name: Notification.Name("ShowStreakCelebration"),
            object: nil,
            userInfo: ["milestone": milestone.days, "type": type.rawValue]
        )
        
        // Send push notification
        scheduleNotification(
            title: "🎉 Milestone Achieved!",
            body: "\(milestone.days)-day streak! You earned \(milestone.coins) Chef Coins!",
            date: Date().addingTimeInterval(1)
        )
        
        // Sync with CloudKit
        Task {
            await CloudKitStreakManager.shared.recordAchievement(achievement)
        }
        
        saveStreaksToCache()
    }
    
    private func calculateMultiplier(for streak: StreakData) -> Double {
        let baseMultiplier = 1.0
        let streakBonus = Double(streak.currentStreak) * 0.01 // 1% per day
        let maxMultiplier = 2.5
        
        var multiplier = baseMultiplier + streakBonus
        
        // Apply power-up boost if active
        if hasPowerUp(.multiplyBoost, for: streak.type) {
            multiplier *= 2.0
        }
        
        return min(multiplier, maxMultiplier)
    }
    
    private func updateGlobalMultiplier() {
        let activeStreakCount = currentStreaks.values.filter { $0.isActive }.count
        let multipliers = currentStreaks.values.map { $0.multiplier }
        let averageMultiplier = multipliers.isEmpty ? 1.0 : 
            multipliers.reduce(0, +) / Double(multipliers.count)
        
        // Bonus for maintaining multiple streaks
        let multiStreakBonus = Double(activeStreakCount) * 0.05
        
        globalMultiplier = min(averageMultiplier + multiStreakBonus, 3.0)
    }
    
    // MARK: - Power-Up Management
    
    private func hasPowerUp(_ type: StreakPowerUp.PowerUpType, for streakType: StreakType) -> Bool {
        // Check UserDefaults for active power-ups
        let key = "powerup_\(type.rawValue)_\(streakType.rawValue)"
        if let expiryDate = userDefaults.object(forKey: key) as? Date {
            return Date() < expiryDate
        }
        return false
    }
    
    private func consumePowerUp(_ type: StreakPowerUp.PowerUpType, for streakType: StreakType) {
        let key = "powerup_\(type.rawValue)_\(streakType.rawValue)"
        userDefaults.removeObject(forKey: key)
    }
    
    func activatePowerUp(_ powerUp: StreakPowerUp, for streakType: StreakType) -> Bool {
        // Check if user can afford it
        guard ChefCoinsManager.shared.canAfford(powerUp.costInCoins) else {
            return false
        }
        
        // Deduct coins
        _ = ChefCoinsManager.shared.spendCoins(powerUp.costInCoins, on: powerUp.name)
        
        // Activate power-up
        if let duration = powerUp.duration {
            let key = "powerup_\(powerUp.type.rawValue)_\(streakType.rawValue)"
            let expiryDate = Date().addingTimeInterval(duration)
            userDefaults.set(expiryDate, forKey: key)
        }
        
        return true
    }
    
    // MARK: - Persistence
    
    private func loadStreaksFromCache() {
        // Load streaks
        if let data = userDefaults.data(forKey: streaksKey),
           let decoded = try? JSONDecoder().decode([StreakType: StreakData].self, from: data) {
            currentStreaks = decoded
        } else {
            // Initialize default streaks
            for type in StreakType.allCases {
                currentStreaks[type] = StreakData(type: type)
            }
        }
        
        // Load history
        if let data = userDefaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([StreakHistory].self, from: data) {
            streakHistory = decoded
        }
        
        // Load achievements
        if let data = userDefaults.data(forKey: achievementsKey),
           let decoded = try? JSONDecoder().decode([StreakAchievement].self, from: data) {
            unclaimedAchievements = decoded
        }
    }
    
    private func saveStreaksToCache() {
        // Save streaks
        if let encoded = try? JSONEncoder().encode(currentStreaks) {
            userDefaults.set(encoded, forKey: streaksKey)
        }
        
        // Save history
        if let encoded = try? JSONEncoder().encode(streakHistory) {
            userDefaults.set(encoded, forKey: historyKey)
        }
        
        // Save achievements
        if let encoded = try? JSONEncoder().encode(unclaimedAchievements) {
            userDefaults.set(encoded, forKey: achievementsKey)
        }
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        Task.detached {
            // Request permission on background queue
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                if granted {
                    print("✅ Notification permission granted")
                }
            } catch {
                print("Notification permission error: \(error)")
            }
            
            // Schedule daily reminder
            await self.scheduleDailyReminder()
        }
    }
    
    private func scheduleDailyReminder() async {
        let content = UNMutableNotificationContent()
        content.title = "🔥 Keep Your Streak Alive!"
        content.body = "Don't forget to complete today's activities"
        content.sound = .default
        
        // Schedule for 8 PM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_streak_reminder",
            content: content,
            trigger: trigger
        )
        
        let center = UNUserNotificationCenter.current()
        try? await center.add(request)
    }
    
    private func scheduleNotification(title: String, body: String, date: Date) {
        Task.detached {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: date.timeIntervalSinceNow,
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            
            let center = UNUserNotificationCenter.current()
            try? await center.add(request)
        }
    }
    
    // MARK: - Analytics
    
    func getStreakAnalytics() -> StreakAnalytics {
        StreakAnalytics.calculate(from: streakHistory)
    }
    
    func getStreakSummary() -> [String: Any] {
        let activeCount = currentStreaks.values.filter { $0.isActive }.count
        let totalDays = currentStreaks.values.reduce(0) { $0 + $1.totalDaysActive }
        let longestStreak = currentStreaks.values.map { $0.longestStreak }.max() ?? 0
        
        return [
            "active_streaks": activeCount,
            "total_days": totalDays,
            "longest_streak": longestStreak,
            "multiplier": globalMultiplier,
            "achievements_earned": streakHistory.count
        ]
    }
}