import Foundation
import SwiftUI

/// Complete 365-day challenge database with proper scheduling
@MainActor
class ChallengeDatabase: ObservableObject {
    static let shared = ChallengeDatabase()

    @Published var activeChallenges: [Challenge] = []
    private var updateTimer: Timer?

    // Challenge duration by difficulty (in hours)
    private let challengeDurations: [DifficultyLevel: TimeInterval] = [
        .easy: 24,      // 1 day
        .medium: 48,    // 2 days
        .hard: 72,      // 3 days
        .expert: 168,   // 7 days (1 week)
        .master: 336    // 14 days (2 weeks)
    ]

    // Offset patterns for staggering challenge start times (in hours)
    private let timeOffsets: [Int] = [0, 3, 6, 9, 12, 15, 18, 21, 27, 33]

    // Initialize and start monitoring
    init() {
        updateActiveChallenges()
        startTimer()
    }

    private func startTimer() {
        // Update every minute to keep countdowns accurate
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                self.updateActiveChallenges()
            }
        }
    }

    /// Update the list of active challenges based on current date/time
    func updateActiveChallenges() {
        let now = Date()
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1

        // Get all challenges for today and recent days
        var active: [Challenge] = []

        // Check last 14 days worth of challenges (to catch long-running ones)
        for daysAgo in 0..<14 {
            let checkDay = (dayOfYear - daysAgo + 365) % 365 + 1
            let challenges = getChallengesForDay(checkDay, year: calendar.component(.year, from: now))

            // Filter to only include challenges that are still active
            for challenge in challenges {
                if challenge.startDate <= now && challenge.endDate > now {
                    active.append(challenge)
                }
            }
        }

        // Sort by end date (soonest first)
        active.sort { $0.endDate < $1.endDate }

        // Update published property
        self.activeChallenges = active
    }

    /// Get challenges for a specific day of the year
    private func getChallengesForDay(_ dayOfYear: Int, year: Int) -> [Challenge] {
        var challenges: [Challenge] = []
        let calendar = Calendar.current

        // Create base date for this day
        var components = DateComponents()
        components.year = year
        components.day = dayOfYear
        guard let baseDate = calendar.dateFromDayOfYear(dayOfYear, year: year) else { return [] }

        // ALWAYS add 3-4 challenges per day for better variety
        
        // 1. Daily challenge (always one per day)
        let dailyChallenge = createDailyChallenge(for: dayOfYear, baseDate: baseDate)
        challenges.append(dailyChallenge)

        // 2. Always add a second daily challenge with different timing
        let secondDailyChallenge = createDailyChallenge(for: dayOfYear + 100, baseDate: baseDate.addingTimeInterval(3600 * 6))
        challenges.append(secondDailyChallenge)

        // 3. Weekly challenge (always active, rotates content)
        let weeklyChallenge = createWeeklyChallenge(for: dayOfYear, baseDate: baseDate)
        challenges.append(weeklyChallenge)

        // 4. Add weekend challenge on Thu/Fri/Sat/Sun, viral challenge on other days
        let weekday = calendar.component(.weekday, from: baseDate)
        if weekday >= 5 || weekday == 1 { // Thursday through Sunday
            let weekendChallenge = createWeekendChallenge(for: dayOfYear, baseDate: baseDate)
            challenges.append(weekendChallenge)
        } else {
            // Add viral challenge on weekdays
            let viralChallenge = createViralChallenge(for: dayOfYear, baseDate: baseDate)
            challenges.append(viralChallenge)
        }

        // 5. Special challenges (if applicable, as 5th challenge)
        if let specialChallenge = createSpecialChallenge(for: dayOfYear, baseDate: baseDate) {
            challenges.append(specialChallenge)
        }

        return challenges
    }

    // MARK: - Challenge Creation Methods

    private func createDailyChallenge(for dayOfYear: Int, baseDate: Date) -> Challenge {
        let templates = [
            ("🍳", "Morning Magic", "Create 3 breakfast recipes under 15 minutes", "breakfast", 100, "0/3 recipes"),
            ("🥗", "Salad Spectacular", "Make 2 creative salads with 5+ ingredients", "healthy", 120, "0/2 salads"),
            ("🍝", "Pasta Perfect", "Create 2 pasta dishes from pantry staples", "italian", 130, "0/2 dishes"),
            ("🌮", "Taco Tuesday", "Transform leftovers into 3 different tacos", "mexican", 110, "0/3 tacos"),
            ("🍜", "Soup & Comfort", "Make 2 warming soups or stews", "comfort", 140, "0/2 soups"),
            ("🥘", "One-Pot Wonder", "Create a complete meal in a single pot", "efficient", 100, "0/1 meal"),
            ("🍕", "Pizza Party", "Make pizza with unconventional toppings", "creative", 150, "0/1 pizza"),
            ("🍱", "Bento Box Beauty", "Create an Instagram-worthy lunch box", "aesthetic", 130, "0/1 bento"),
            ("🥙", "Wrap It Up", "Make 3 different wraps or sandwiches", "lunch", 90, "0/3 wraps"),
            ("🍛", "Curry Night", "Create 2 curry dishes from scratch", "indian", 160, "0/2 curries")
        ]

        let template = templates[dayOfYear % templates.count]
        let difficulty: DifficultyLevel = dayOfYear % 3 == 0 ? .medium : .easy
        let duration = challengeDurations[difficulty]!

        // Add time offset based on day to stagger challenge times
        let offsetHours = timeOffsets[dayOfYear % timeOffsets.count]
        let startDate = baseDate.addingTimeInterval(TimeInterval(offsetHours * 3_600))

        return Challenge(
            id: "daily-\(dayOfYear)-\(Calendar.current.component(.year, from: baseDate))",
            title: template.1,
            description: template.2,
            type: .daily,
            category: template.3,
            difficulty: difficulty,
            points: template.4,
            coins: template.4 / 10,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(duration * 3_600),
            requirements: [template.5],
            currentProgress: 0,
            isCompleted: false,
            isActive: true,
            isJoined: false,  // Make challenges opt-in
            participants: 100 + (dayOfYear * 17) % 2_000,
            completions: 50 + (dayOfYear * 7) % 500
        )
    }

    private func createWeeklyChallenge(for dayOfYear: Int, baseDate: Date) -> Challenge {
        let weekNumber = dayOfYear / 7
        let templates = [
            ("🌱", "Plant-Based Week", "Create 10 vegetarian or vegan recipes", "vegetarian", 500, "0/10 recipes"),
            ("💪", "Protein Power", "Make 15 recipes with 30g+ protein", "fitness", 600, "0/15 recipes"),
            ("🌍", "World Tour", "Cook recipes from 7 different countries", "international", 700, "0/7 countries"),
            ("⏱", "Speed Week", "Create 20 recipes in under 20 minutes each", "quick", 550, "0/20 recipes"),
            ("❤️", "Heart Healthy", "Make 12 low-sodium, low-fat recipes", "healthy", 580, "0/12 recipes"),
            ("🎨", "Recipe Makeover", "Transform 5 classic recipes with new twists", "creative", 620, "0/5 makeovers"),
            ("🥦", "Veggie Victory", "Use 30 different vegetables this week", "vegetables", 650, "0/30 veggies"),
            ("🍞", "Bread & Bakes", "Bake 5 different bread or pastry recipes", "baking", 700, "0/5 bakes")
        ]

        let template = templates[weekNumber % templates.count]
        let difficulty: DifficultyLevel = .hard
        let duration = challengeDurations[difficulty]!

        // Add different offset for weekly challenges
        let offsetHours = timeOffsets[(weekNumber + 3) % timeOffsets.count]
        let startDate = baseDate.addingTimeInterval(TimeInterval(offsetHours * 3_600))

        return Challenge(
            id: "weekly-\(weekNumber)-\(Calendar.current.component(.year, from: baseDate))",
            title: template.1,
            description: template.2,
            type: .weekly,
            category: template.3,
            difficulty: difficulty,
            points: template.4,
            coins: template.4 / 10,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(duration * 3_600),
            requirements: [template.5],
            currentProgress: 0,
            isCompleted: false,
            isActive: true,
            isJoined: false,  // Opt-in
            participants: 500 + (weekNumber * 37) % 5_000,
            completions: 100 + (weekNumber * 17) % 1_000
        )
    }

    func getChallenge(by id: String) -> Challenge? {
        // Check active challenges
        if let challenge = activeChallenges.first(where: { $0.id == id }) {
            return challenge
        }

        // For now, return nil if not found in active challenges
        // Full year challenge generation not implemented - using active challenges only
        return nil
    }

    private func createWeekendChallenge(for dayOfYear: Int, baseDate: Date) -> Challenge {
        let weekendNumber = dayOfYear / 7
        let templates = [
            ("🍖", "BBQ Weekend", "Grill 5 different recipes", "grilling", 300, "0/5 grilled"),
            ("🧁", "Baking Bonanza", "Bake 3 desserts from scratch", "dessert", 350, "0/3 desserts"),
            ("🍸", "Cocktail Hour", "Create 5 mocktails with fresh ingredients", "drinks", 280, "0/5 mocktails"),
            ("🥞", "Brunch Bliss", "Make 4 brunch recipes", "brunch", 320, "0/4 recipes"),
            ("🍿", "Movie Night Snacks", "Create 5 cinema-worthy snacks", "snacks", 290, "0/5 snacks"),
            ("🎉", "Party Platter", "Make 6 party appetizers", "entertaining", 400, "0/6 appetizers")
        ]

        let template = templates[weekendNumber % templates.count]
        let difficulty: DifficultyLevel = .medium
        let duration = challengeDurations[difficulty]!

        // Different offset for weekend challenges
        let offsetHours = timeOffsets[(weekendNumber + 5) % timeOffsets.count]
        let startDate = baseDate.addingTimeInterval(TimeInterval(offsetHours * 3_600))

        return Challenge(
            id: "weekend-\(weekendNumber)-\(Calendar.current.component(.year, from: baseDate))",
            title: template.1,
            description: template.2,
            type: .special,
            category: template.3,
            difficulty: difficulty,
            points: template.4,
            coins: template.4 / 10,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(duration * 3_600),
            requirements: [template.5],
            currentProgress: 0,
            isCompleted: false,
            isActive: true,
            isJoined: false,  // Opt-in
            participants: 300 + (weekendNumber * 23) % 3_000,
            completions: 75 + (weekendNumber * 11) % 750
        )
    }

    private func createViralChallenge(for dayOfYear: Int, baseDate: Date) -> Challenge {
        let viralTemplates = [
            ("🔥", "#FoodHack", "Share your best kitchen hack that went viral", "viral", 200, "0/1 hack"),
            ("📸", "#FoodPorn", "Create the most photogenic meal", "aesthetic", 250, "0/1 photo"),
            ("🎬", "#30SecondMeal", "Film a recipe in 30 seconds or less", "video", 300, "0/1 video"),
            ("🔥", "#SpiceChallenge", "Create the spiciest dish you can handle", "spicy", 280, "0/1 dish"),
            ("🎭", "#FoodFail", "Turn a cooking fail into a win", "funny", 220, "0/1 transformation"),
            ("🏃", "#QuickBite", "Make a meal in under 5 minutes", "speed", 260, "0/1 meal"),
            ("🌟", "#GlowUp", "Transform basic ingredients into gourmet", "transformation", 340, "0/1 glow-up"),
            ("🎪", "#FoodCircus", "Create an outrageously creative dish", "creative", 380, "0/1 creation"),
            ("💃", "#DancingChef", "Cook while dancing to trending music", "entertainment", 200, "0/1 dance"),
            ("🍜", "#NoodleMania", "Create unique noodle dishes from scratch", "noodles", 320, "0/3 noodles")
        ]

        let template = viralTemplates[dayOfYear % viralTemplates.count]
        let difficulty: DifficultyLevel = [.easy, .medium][dayOfYear % 2]
        let duration = challengeDurations[difficulty]!

        // Viral challenges get more varied offsets
        let offsetHours = timeOffsets[(dayOfYear * 7) % timeOffsets.count]
        let startDate = baseDate.addingTimeInterval(TimeInterval(offsetHours * 3_600))

        return Challenge(
            id: "viral-\(dayOfYear)-\(Calendar.current.component(.year, from: baseDate))",
            title: template.1,
            description: template.2,
            type: .community,
            category: template.3,
            difficulty: difficulty,
            points: template.4,
            coins: template.4 / 10,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(duration * 3_600),
            requirements: [template.5],
            currentProgress: 0,
            isCompleted: false,
            isActive: true,
            isJoined: false,  // Opt-in
            participants: 1_000 + (dayOfYear * 91) % 10_000,
            completions: 200 + (dayOfYear * 31) % 2_000,
            isPremium: dayOfYear % 5 == 0 // Every 5th viral challenge is premium
        )
    }

    private func createSpecialChallenge(for dayOfYear: Int, baseDate: Date) -> Challenge? {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: baseDate)
        let day = calendar.component(.day, from: baseDate)

        // Special holiday challenges
        let specialDates: [(month: Int, day: Int, template: (String, String, String, String, Int, String))] = [
            // January
            (1, 1, ("🎊", "New Year Fresh Start", "Create 5 healthy recipes to start the year", "healthy", 1_000, "0/5 recipes")),
            (1, 15, ("🥶", "Winter Warmers", "Make 4 cozy comfort foods", "comfort", 400, "0/4 foods")),

            // February
            (2, 14, ("❤️", "Valentine's Special", "Create a romantic 3-course meal", "romantic", 800, "0/3 courses")),
            (2, 28, ("🥞", "Pancake Day", "Make 5 creative pancake recipes", "breakfast", 500, "0/5 pancakes")),

            // March
            (3, 17, ("☘️", "St. Patrick's Day", "Create 3 green-themed dishes", "irish", 600, "0/3 dishes")),
            (3, 20, ("🌸", "Spring Awakening", "Use 5 spring vegetables", "seasonal", 550, "0/5 vegetables")),

            // April
            (4, 1, ("🃏", "April Fools Food", "Create trick foods that surprise", "fun", 400, "0/3 tricks")),
            (4, 22, ("🌿", "Fresh Herbs Festival", "Create 5 recipes featuring fresh herbs", "herbs", 700, "0/5 herbs")),

            // May
            (5, 5, ("🌮", "Cinco de Mayo", "Create 5 Mexican dishes", "mexican", 650, "0/5 dishes")),
            (5, 28, ("🍔", "Memorial Day BBQ", "Grill 6 summer favorites", "grilling", 700, "0/6 grilled")),

            // June
            (6, 21, ("☀️", "Summer Solstice", "Create 5 refreshing summer dishes", "summer", 600, "0/5 dishes")),

            // July
            (7, 4, ("🇺🇸", "Independence Day", "Make 5 American classics", "american", 750, "0/5 classics")),
            (7, 25, ("🍦", "Ice Cream Day", "Create 3 frozen desserts", "dessert", 500, "0/3 desserts")),

            // August
            (8, 15, ("🏖", "Beach Picnic", "Make 5 portable beach foods", "outdoor", 550, "0/5 foods")),

            // September
            (9, 22, ("🍂", "Fall Harvest", "Use 5 autumn ingredients", "seasonal", 600, "0/5 ingredients")),

            // October
            (10, 31, ("🎃", "Halloween Spooktacular", "Create 5 spooky-themed recipes", "halloween", 1_000, "0/5 spooky")),

            // November
            (11, 24, ("🦃", "Thanksgiving Feast", "Make 6 traditional dishes with a twist", "thanksgiving", 1_200, "0/6 dishes")),

            // December
            (12, 24, ("🎄", "Holiday Magic", "Create 8 festive recipes", "christmas", 1_500, "0/8 festive")),
            (12, 31, ("🥂", "New Year's Eve", "Make 5 party appetizers", "party", 800, "0/5 appetizers"))
        ]

        for special in specialDates {
            if month == special.0 && day == special.1 {
                let template = special.2
                let difficulty: DifficultyLevel = template.4 >= 1_000 ? .master : template.4 >= 700 ? .expert : .hard
                let duration = challengeDurations[difficulty]!

                // Special events get unique timing
                let offsetHours = timeOffsets[(month + day) % timeOffsets.count]
                let startDate = baseDate.addingTimeInterval(TimeInterval(offsetHours * 3_600))

                return Challenge(
                    id: "special-\(month)-\(day)-\(calendar.component(.year, from: baseDate))",
                    title: template.1,
                    description: template.2,
                    type: .special,
                    category: template.3,
                    difficulty: difficulty,
                    points: template.4,
                    coins: template.4 / 10,
                    startDate: startDate,
                    endDate: startDate.addingTimeInterval(duration * 3_600),
                    requirements: [template.5],
                    currentProgress: 0,
                    isCompleted: false,
                    isActive: true,
                    isJoined: false,  // Opt-in
                    participants: 2_000 + (dayOfYear * 47) % 20_000,
                    completions: 500 + (dayOfYear * 19) % 5_000,
                    imageURL: nil,
                    isPremium: template.4 >= 1_000
                )
            }
        }

        // Seasonal challenges (4 per year)
        let seasonalChallenges: [(range: ClosedRange<Int>, template: (String, String, String, String, Int, String))] = [
            (80...89, ("🌸", "Spring Feast", "Create 10 fresh spring-inspired dishes", "seasonal", 800, "0/10 dishes")),
            (172...181, ("☀️", "Summer Sizzle", "Create 10 no-cook summer meals", "summer", 900, "0/10 meals")),
            (264...273, ("🍁", "Autumn Comfort", "Make 8 cozy fall recipes", "autumn", 850, "0/8 recipes")),
            (355...364, ("❄️", "Winter Feast", "Create 10 warming winter dishes", "winter", 950, "0/10 dishes"))
        ]

        for seasonal in seasonalChallenges {
            if seasonal.range.contains(dayOfYear) && dayOfYear == seasonal.range.lowerBound {
                let template = seasonal.template
                let difficulty: DifficultyLevel = .expert
                let duration = challengeDurations[difficulty]!

                // Seasonal challenges start at different times
                let offsetHours = timeOffsets[(dayOfYear / 30) % timeOffsets.count]
                let startDate = baseDate.addingTimeInterval(TimeInterval(offsetHours * 3_600))

                return Challenge(
                    id: "seasonal-\(dayOfYear)-\(calendar.component(.year, from: baseDate))",
                    title: template.1,
                    description: template.2,
                    type: .special,
                    category: template.3,
                    difficulty: difficulty,
                    points: template.4,
                    coins: template.4 / 10,
                    startDate: startDate,
                    endDate: startDate.addingTimeInterval(duration * 3_600),
                    requirements: [template.5],
                    currentProgress: 0,
                    isCompleted: false,
                    isActive: true,
                    isJoined: false,  // Opt-in
                    participants: 3_000 + (dayOfYear * 53) % 15_000,
                    completions: 600 + (dayOfYear * 23) % 3_000
                )
            }
        }

        return nil
    }

    /// Get emoji for a challenge based on its title/category
    func getEmojiForChallenge(_ challenge: Challenge) -> String {
        // Check title for emoji hints
        let title = challenge.title.lowercased()

        let emojiMap: [String: String] = [
            "breakfast": "🍳",
            "salad": "🥗",
            "pasta": "🍝",
            "taco": "🌮",
            "soup": "🍜",
            "pizza": "🍕",
            "curry": "🍛",
            "bbq": "🍖",
            "grill": "🔥",
            "baking": "🧁",
            "dessert": "🍰",
            "plant": "🌱",
            "vegetarian": "🥦",
            "vegan": "🌿",
            "protein": "💪",
            "world": "🌍",
            "speed": "⏱",
            "quick": "🏃",
            "heart": "❤️",
            "healthy": "🥗",
            "color": "🌈",
            "spicy": "🌶️",
            "bread": "🍞",
            "cocktail": "🍸",
            "drink": "🥤",
            "party": "🎉",
            "halloween": "🎃",
            "christmas": "🎄",
            "thanksgiving": "🦃",
            "valentine": "❤️",
            "summer": "☀️",
            "winter": "❄️",
            "spring": "🌸",
            "fall": "🍂",
            "autumn": "🍁"
        ]

        for (keyword, emoji) in emojiMap {
            if title.contains(keyword) {
                return emoji
            }
        }

        // Default emojis by challenge type
        switch challenge.type {
        case .daily: return "📅"
        case .weekly: return "📆"
        case .special: return "⭐"
        case .community: return "👥"
        }
    }
}

// MARK: - Helper Extensions

extension Calendar {
    func dateFromDayOfYear(_ dayOfYear: Int, year: Int) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.day = dayOfYear
        return self.date(from: dateComponents)
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
