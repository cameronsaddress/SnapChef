import Foundation
import SwiftUI

/// ChallengeGenerator creates dynamic challenges based on various criteria
@MainActor
class ChallengeGenerator {
    // MARK: - Properties
    private let gamificationManager = GamificationManager.shared
    private let calendar = Calendar.current
    private let subscriptionManager = SubscriptionManager.shared

    // Challenge templates
    private let dailyChallengeTemplates: [ChallengeTemplate] = [
        ChallengeTemplate(
            titleFormat: "Speed Chef: %d Minute Challenge",
            descriptionFormat: "Create %d recipes in under %d minutes total",
            requirementFormat: "0/%d recipes",
            basePoints: 100,
            variables: [5, 3, 30, 3]
        ),
        ChallengeTemplate(
            titleFormat: "Ingredient Master",
            descriptionFormat: "Create %d recipes using only %d ingredients each",
            requirementFormat: "0/%d recipes",
            basePoints: 150,
            variables: [5, 5, 5]
        ),
        ChallengeTemplate(
            titleFormat: "Calorie Counter",
            descriptionFormat: "Create %d recipes under %d calories",
            requirementFormat: "0/%d recipes",
            basePoints: 120,
            variables: [3, 400, 3]
        ),
        ChallengeTemplate(
            titleFormat: "Cuisine Explorer",
            descriptionFormat: "Create recipes from %d different cuisines",
            requirementFormat: "0/%d cuisines",
            basePoints: 200,
            variables: [3, 3]
        ),
        ChallengeTemplate(
            titleFormat: "Breakfast Champion",
            descriptionFormat: "Create %d breakfast recipes today",
            requirementFormat: "0/%d recipes",
            basePoints: 80,
            variables: [3, 3]
        )
    ]

    private let weeklyChallengeTemplates: [ChallengeTemplate] = [
        ChallengeTemplate(
            titleFormat: "Healthy Week",
            descriptionFormat: "Create %d recipes under %d calories each",
            requirementFormat: "0/%d recipes",
            basePoints: 500,
            variables: [10, 500, 10]
        ),
        ChallengeTemplate(
            titleFormat: "Protein Power",
            descriptionFormat: "Create %d recipes with at least %dg protein",
            requirementFormat: "0/%d recipes",
            basePoints: 600,
            variables: [15, 30, 15]
        ),
        ChallengeTemplate(
            titleFormat: "Plant-Based Week",
            descriptionFormat: "Create %d vegetarian or vegan recipes",
            requirementFormat: "0/%d recipes",
            basePoints: 550,
            variables: [12, 12]
        ),
        ChallengeTemplate(
            titleFormat: "International Tour",
            descriptionFormat: "Create recipes from %d different countries",
            requirementFormat: "0/%d countries",
            basePoints: 700,
            variables: [7, 7]
        ),
        ChallengeTemplate(
            titleFormat: "Meal Prep Master",
            descriptionFormat: "Create %d recipes suitable for meal prep",
            requirementFormat: "0/%d recipes",
            basePoints: 450,
            variables: [8, 8]
        )
    ]

    private let specialEventTemplates: [String: ChallengeTemplate] = [
        "halloween": ChallengeTemplate(
            titleFormat: "Halloween Special 🎃",
            descriptionFormat: "Create %d spooky-themed recipes",
            requirementFormat: "0/%d recipes",
            basePoints: 1_000,
            variables: [5, 5]
        ),
        "christmas": ChallengeTemplate(
            titleFormat: "Holiday Feast 🎄",
            descriptionFormat: "Create %d festive holiday recipes",
            requirementFormat: "0/%d recipes",
            basePoints: 1_200,
            variables: [6, 6]
        ),
        "thanksgiving": ChallengeTemplate(
            titleFormat: "Thanksgiving Harvest 🦃",
            descriptionFormat: "Create %d autumn-inspired recipes",
            requirementFormat: "0/%d recipes",
            basePoints: 1_000,
            variables: [5, 5]
        ),
        "valentines": ChallengeTemplate(
            titleFormat: "Love & Food ❤️",
            descriptionFormat: "Create %d romantic dinner recipes",
            requirementFormat: "0/%d recipes",
            basePoints: 800,
            variables: [4, 4]
        ),
        "summer": ChallengeTemplate(
            titleFormat: "Summer BBQ 🌞",
            descriptionFormat: "Create %d grilling or outdoor recipes",
            requirementFormat: "0/%d recipes",
            basePoints: 900,
            variables: [6, 6]
        )
    ]

    // Premium-only challenge templates
    private let premiumChallengeTemplates: [ChallengeTemplate] = [
        ChallengeTemplate(
            titleFormat: "Master Chef Marathon",
            descriptionFormat: "Create %d gourmet recipes with 5-star ratings",
            requirementFormat: "0/%d gourmet recipes",
            basePoints: 2_000,
            variables: [10, 10]
        ),
        ChallengeTemplate(
            titleFormat: "Michelin Star Week",
            descriptionFormat: "Create %d restaurant-quality recipes in %d days",
            requirementFormat: "0/%d recipes",
            basePoints: 2_500,
            variables: [7, 7, 7]
        ),
        ChallengeTemplate(
            titleFormat: "Global Cuisine Tour",
            descriptionFormat: "Create recipes from %d different continents",
            requirementFormat: "0/%d continents",
            basePoints: 3_000,
            variables: [5, 5]
        ),
        ChallengeTemplate(
            titleFormat: "Zero Waste Champion",
            descriptionFormat: "Create %d recipes using all ingredients (no waste)",
            requirementFormat: "0/%d zero-waste recipes",
            basePoints: 2_200,
            variables: [8, 8]
        ),
        ChallengeTemplate(
            titleFormat: "Nutrition Perfectionist",
            descriptionFormat: "Create %d perfectly balanced nutritional recipes",
            requirementFormat: "0/%d balanced recipes",
            basePoints: 2_800,
            variables: [12, 12]
        ),
        ChallengeTemplate(
            titleFormat: "Speed Demon Deluxe",
            descriptionFormat: "Create %d recipes in under %d minutes each",
            requirementFormat: "0/%d speed recipes",
            basePoints: 1_800,
            variables: [15, 15, 15]
        ),
        ChallengeTemplate(
            titleFormat: "Social Butterfly Supreme",
            descriptionFormat: "Share %d recipes and get %d+ likes each",
            requirementFormat: "0/%d viral recipes",
            basePoints: 2_400,
            variables: [10, 50, 10]
        )
    ]

    // MARK: - Challenge Generation

    /// Generate daily challenges
    func generateDailyChallenge(for date: Date = Date()) -> Challenge {
        // Use date as seed for consistency
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let templateIndex = dayOfYear % dailyChallengeTemplates.count
        let template = dailyChallengeTemplates[templateIndex]

        // Add variation based on user stats
        let userLevel = gamificationManager.userStats.level
        let difficultyMultiplier = 1.0 + (Double(userLevel) * 0.1)

        // Determine base duration based on difficulty
        let baseDuration: TimeInterval = {
            if template.basePoints <= 100 { return 12 * 3_600 } // Easy: 12 hours
            else if template.basePoints <= 200 { return 24 * 3_600 } // Medium: 24 hours
            else if template.basePoints <= 500 { return 48 * 3_600 } // Hard: 48 hours
            else { return 72 * 3_600 } // Expert: 72 hours
        }()

        // Add variation to prevent identical countdowns
        let hourVariation = Double.random(in: -2...2) * 3_600
        let minuteVariation = Double.random(in: 0...59) * 60
        let secondVariation = Double.random(in: 0...59)

        let endDate = date.addingTimeInterval(baseDuration + hourVariation + minuteVariation + secondVariation)

        return createChallenge(
            from: template,
            type: .daily,
            endDate: endDate,
            difficultyMultiplier: difficultyMultiplier
        )
    }

    /// Generate weekly challenges
    func generateWeeklyChallenge(for date: Date = Date()) -> Challenge {
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        let templateIndex = weekOfYear % weeklyChallengeTemplates.count
        let template = weeklyChallengeTemplates[templateIndex]

        // Base end date is 7 days from now
        let baseEndDate = calendar.date(byAdding: .day, value: 7, to: date) ?? date

        // Add variation to prevent identical countdowns
        let hourVariation = Double.random(in: -4...4) * 3_600 // +/- 4 hours
        let minuteVariation = Double.random(in: 0...59) * 60
        let endDate = baseEndDate.addingTimeInterval(hourVariation + minuteVariation)

        return createChallenge(
            from: template,
            type: .weekly,
            endDate: endDate,
            difficultyMultiplier: 1.0
        )
    }

    /// Generate special event challenges
    func generateSpecialEventChallenge(event: String? = nil) -> Challenge? {
        let eventKey = event ?? detectCurrentEvent()
        guard let template = specialEventTemplates[eventKey] else { return nil }

        let endDate = calendar.date(byAdding: .day, value: 3, to: Date()) ?? Date()

        return createChallenge(
            from: template,
            type: .special,
            endDate: endDate,
            difficultyMultiplier: 1.0
        )
    }

    /// Generate community challenges
    func generateCommunityChallenge() -> Challenge {
        let currentMonth = calendar.component(.month, from: Date())
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: Date())?.addingTimeInterval(-1) ?? Date()

        let themes = [
            "Global Cook-Off",
            "Recipe Revolution",
            "Culinary Champions",
            "Food Festival",
            "Kitchen Heroes Unite"
        ]

        let theme = themes[currentMonth % themes.count]
        let targetRecipes = 1_000_000 + (currentMonth * 100_000)
        let currentRecipes = Int.random(in: 700_000...900_000)

        return Challenge(
            title: theme,
            description: "Community goal: \(targetRecipes / 1_000)K recipes this month",
            type: .community,
            points: 2_000,
            coins: 200,
            endDate: endOfMonth,
            requirements: ["\(currentRecipes.formatted())/\(targetRecipes.formatted())"],
            currentProgress: Double(currentRecipes) / Double(targetRecipes),
            participants: Int.random(in: 30_000...60_000)
        )
    }

    /// Generate personalized challenges based on user behavior
    func generatePersonalizedChallenge(for userId: String) -> Challenge? {
        let userStats = gamificationManager.userStats

        // Analyze user patterns
        if userStats.currentStreak > 5 {
            return generateStreakChallenge()
        } else if userStats.recipesCreated < 10 {
            return generateBeginnerChallenge()
        } else if userStats.perfectRecipes > 10 {
            return generatePerfectionistChallenge()
        }

        return nil
    }

    /// Generate premium challenges (only for premium subscribers)
    func generatePremiumChallenge() -> Challenge? {
        guard subscriptionManager.isPremium else { return nil }

        // Select a random premium template
        guard let template = premiumChallengeTemplates.randomElement() else { return nil }

        let endDate = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()

        let challenge = createChallenge(
            from: template,
            type: .weekly,
            endDate: endDate,
            difficultyMultiplier: 1.0
        )

        // Apply premium reward multiplier
        let multiplier = subscriptionManager.getPremiumRewardMultiplier()
        let premiumPoints = Int(Double(challenge.points) * multiplier)
        let premiumCoins = Int(Double(challenge.coins) * multiplier)

        // Create new challenge with updated rewards
        return Challenge(
            id: challenge.id,
            title: "⭐ \(challenge.title)",
            description: challenge.description,
            type: challenge.type,
            category: challenge.category,
            difficulty: challenge.difficulty,
            points: premiumPoints,
            coins: premiumCoins,
            startDate: challenge.startDate,
            endDate: challenge.endDate,
            requirements: challenge.requirements,
            currentProgress: challenge.currentProgress,
            isCompleted: challenge.isCompleted,
            isActive: challenge.isActive,
            participants: challenge.participants,
            completions: challenge.completions,
            imageURL: challenge.imageURL,
            isPremium: true
        )
    }

    // MARK: - Helper Methods

    private func createChallenge(
        from template: ChallengeTemplate,
        type: ChallengeType,
        endDate: Date,
        difficultyMultiplier: Double
    ) -> Challenge {
        let adjustedVariables = template.variables.map { Int(Double($0) * difficultyMultiplier) }
        let adjustedPoints = Int(Double(template.basePoints) * difficultyMultiplier)

        let title = String(format: template.titleFormat, arguments: adjustedVariables.map { $0 as CVarArg })
        let description = String(format: template.descriptionFormat, arguments: adjustedVariables.map { $0 as CVarArg })
        let requirement = String(format: template.requirementFormat, arguments: adjustedVariables.map { $0 as CVarArg })

        let badge = generateBadgeName(for: type, title: title)
        let unlockable = generateUnlockable(for: type, points: adjustedPoints)

        return Challenge(
            title: title,
            description: description,
            type: type,
            points: adjustedPoints,
            coins: adjustedPoints / 10,
            endDate: endDate,
            requirements: [requirement],
            currentProgress: 0,
            participants: generateParticipantCount(for: type)
        )
    }

    private func generateStreakChallenge() -> Challenge {
        let streak = gamificationManager.userStats.currentStreak
        let nextMilestone = ((streak / 7) + 1) * 7

        return Challenge(
            title: "Streak Master",
            description: "Maintain your \(nextMilestone)-day streak",
            type: .daily,
            points: nextMilestone * 20,
            coins: nextMilestone * 2,
            endDate: Date().addingTimeInterval(86_400),
            requirements: ["\(streak)/\(nextMilestone) days"],
            currentProgress: Double(streak) / Double(nextMilestone),
            participants: Int.random(in: 500...1_500)
        )
    }

    private func generateBeginnerChallenge() -> Challenge {
        return Challenge(
            title: "First Steps",
            description: "Create your first 5 recipes",
            type: .daily,
            points: 200,
            coins: 20,
            endDate: Date().addingTimeInterval(259_200), // 3 days
            requirements: ["\(gamificationManager.userStats.recipesCreated)/5 recipes"],
            currentProgress: Double(gamificationManager.userStats.recipesCreated) / 5.0,
            participants: Int.random(in: 2_000...5_000)
        )
    }

    private func generatePerfectionistChallenge() -> Challenge {
        return Challenge(
            title: "Perfection Week",
            description: "Create 5 perfect recipes (5-star rating)",
            type: .weekly,
            points: 1_000,
            coins: 100,
            endDate: Date().addingTimeInterval(604_800), // 7 days
            requirements: ["0/5 perfect recipes"],
            currentProgress: 0,
            participants: Int.random(in: 1_000...3_000)
        )
    }

    private func detectCurrentEvent() -> String {
        let month = calendar.component(.month, from: Date())
        let day = calendar.component(.day, from: Date())

        switch (month, day) {
        case (10, 20...31): return "halloween"
        case (12, 15...31): return "christmas"
        case (11, 20...30): return "thanksgiving"
        case (2, 10...16): return "valentines"
        case (6...8, _): return "summer"
        default: return "summer" // Default fallback
        }
    }

    private func endOfDay(for date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.date(from: components) ?? date
    }

    private func generateBadgeName(for type: ChallengeType, title: String) -> String? {
        switch type {
        case .daily:
            return nil // Daily challenges typically don't award badges
        case .weekly:
            return "\(title) Champion"
        case .special:
            return "\(title) Master"
        case .community:
            return "Community Hero"
        }
    }

    private func generateTitle(for points: Int) -> String? {
        switch points {
        case 0..<100: return nil
        case 100..<300: return "Dedicated Chef"
        case 300..<600: return "Challenge Expert"
        case 600..<1_000: return "Master Challenger"
        default: return "Challenge Legend"
        }
    }

    private func generateUnlockable(for type: ChallengeType, points: Int) -> String? {
        guard points >= 500 else { return nil }

        let unlockables = [
            "Exclusive recipe pack",
            "Premium theme",
            "Special stickers",
            "Chef's toolkit",
            "Bonus filters"
        ]

        return unlockables.randomElement()
    }

    private func generateParticipantCount(for type: ChallengeType) -> Int {
        switch type {
        case .daily:
            return Int.random(in: 500...2_000)
        case .weekly:
            return Int.random(in: 2_000...8_000)
        case .special:
            return Int.random(in: 10_000...30_000)
        case .community:
            return Int.random(in: 30_000...60_000)
        }
    }
}

// MARK: - Challenge Template
private struct ChallengeTemplate {
    let titleFormat: String
    let descriptionFormat: String
    let requirementFormat: String
    let basePoints: Int
    let variables: [Int]
}

// MARK: - Challenge Scheduler
extension ChallengeGenerator {
    /// Schedule automatic challenge generation
    func scheduleAutomaticGeneration() {
        // Generate daily challenge at midnight
        scheduleDailyGeneration()

        // Generate weekly challenge on Sunday
        scheduleWeeklyGeneration()

        // Check for special events
        scheduleSpecialEventGeneration()
    }

    private func scheduleDailyGeneration() {
        let timer = Timer.scheduledTimer(withTimeInterval: 86_400, repeats: true) { _ in
            Task { @MainActor in
                let challenge = self.generateDailyChallenge()
                self.gamificationManager.saveChallenge(challenge)
            }
        }

        RunLoop.current.add(timer, forMode: .common)
    }

    private func scheduleWeeklyGeneration() {
        let timer = Timer.scheduledTimer(withTimeInterval: 604_800, repeats: true) { _ in
            Task { @MainActor in
                let challenge = self.generateWeeklyChallenge()
                self.gamificationManager.saveChallenge(challenge)
            }
        }

        RunLoop.current.add(timer, forMode: .common)
    }

    private func scheduleSpecialEventGeneration() {
        // Check daily for special events
        let timer = Timer.scheduledTimer(withTimeInterval: 86_400, repeats: true) { _ in
            Task { @MainActor in
                if let challenge = self.generateSpecialEventChallenge() {
                    self.gamificationManager.saveChallenge(challenge)
                }
            }
        }

        RunLoop.current.add(timer, forMode: .common)
    }
}
