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
        let secondDailyChallenge = createSecondDailyChallenge(for: dayOfYear, baseDate: baseDate.addingTimeInterval(3600 * 6))
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
            ("🍳", "15-Minute Gourmet Breakfast", "Create a restaurant-quality breakfast using exactly 5 ingredients, including one protein cooked two ways", "breakfast", 100, "1 breakfast with dual-protein technique"),
            ("🥗", "Rainbow Salad Architecture", "Build a salad with 7 different colors using 3 different cutting techniques (julienne, chiffonade, brunoise)", "healthy", 120, "1 salad with 7 colors, 3 cuts shown"),
            ("🍝", "Fresh Pasta Mastery", "Make pasta from scratch with homemade sauce using only 6 pantry staples - photo document each step", "italian", 130, "1 scratch pasta with 6-ingredient sauce"),
            ("🌮", "Zero-Waste Fusion Tacos", "Use 3 different leftovers to create fusion tacos with homemade salsa from vegetable scraps", "mexican", 110, "3 leftover tacos + scrap salsa"),
            ("🍜", "Layered Soup Science", "Create a soup with 3 visible layers before stirring - protein, starch, and vegetable layers", "comfort", 140, "1 three-layer soup with photo proof"),
            ("🥘", "One-Pot Time-Lapse", "Build a one-pot meal adding ingredients at 5-minute intervals - document each addition stage", "efficient", 100, "1 meal with 5 timed stages documented"),
            ("🍕", "Fusion Pizza Laboratory", "Create pizza combining 2 cuisines with homemade sauces representing each culture", "creative", 150, "1 dual-culture pizza with 2 sauces"),
            ("🍱", "Color Theory Bento", "Design a bento with 5 colors from natural ingredients, each using different cooking method", "aesthetic", 130, "5 colors, 5 cooking methods in one box"),
            ("🥙", "Texture Master Wrap", "Create a wrap featuring 5 distinct textures: crunchy, creamy, chewy, crispy, and tender", "lunch", 90, "1 wrap showcasing 5 textures"),
            ("🍛", "Spice Gradient Curry", "Build a curry with 3 spice levels in one dish - mild, medium, and hot sections", "indian", 160, "1 curry with 3 visible spice zones")
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

    private func createSecondDailyChallenge(for dayOfYear: Int, baseDate: Date) -> Challenge {
        let templates = [
            ("🥚", "Egg Excellence Challenge", "Master 3 different egg techniques in one dish - poached, scrambled, and crispy fried edges", "breakfast", 100, "1 dish with 3 egg techniques shown"),
            ("🥬", "Greens Transformation", "Take one type of leafy green and prepare it 3 ways - raw, sautéed, and crispy chips", "healthy", 120, "1 green prepared 3 ways with photos"),
            ("🍜", "Noodle Architecture", "Create homemade noodles in 2 different widths and build a structured presentation", "italian", 130, "2 noodle widths, architectural plating"),
            ("🌯", "Burrito Engineering", "Build a perfectly wrapped burrito with 4 distinct flavor quadrants - no mixing allowed", "mexican", 110, "1 burrito with 4 flavor zones mapped"),
            ("🥣", "Stock From Scratch", "Make stock from vegetable scraps and use it for a complete soup in under 2 hours", "comfort", 140, "1 scrap stock soup with time proof"),
            ("🍳", "Cast Iron Mastery", "Cook an entire meal in one cast iron pan - appetizer, main, and dessert", "efficient", 100, "3 courses in 1 pan documented"),
            ("🥖", "Bread & Spread Duo", "Make quick bread and 2 complementary spreads using same base ingredient differently", "creative", 150, "1 bread + 2 spreads from same ingredient"),
            ("🍙", "Rice Ball Revolution", "Create 3 different onigiri with visible filling cross-sections when cut", "aesthetic", 130, "3 onigiri with cross-section photos"),
            ("🥪", "Sandwich Architecture", "Build a sandwich with perfect ingredient ratios - measure and document each layer", "lunch", 90, "1 sandwich with measured layer ratios"),
            ("🍲", "Tempering Technique", "Demonstrate proper spice tempering with before/after aroma photos in your curry", "indian", 160, "1 curry with tempering process shown")
        ]

        let templateIndex = (dayOfYear + 100) % templates.count
        let template = templates[templateIndex]
        let difficulty: DifficultyLevel = (dayOfYear + 100) % 3 == 0 ? .medium : .easy
        let duration = challengeDurations[difficulty]!

        // Add time offset based on day to stagger challenge times
        let offsetHours = timeOffsets[(dayOfYear + 100) % timeOffsets.count]
        let startDate = baseDate.addingTimeInterval(TimeInterval(offsetHours * 3_600))

        return Challenge(
            id: "daily-\(dayOfYear)-b-\(Calendar.current.component(.year, from: baseDate))",
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
            participants: 100 + ((dayOfYear + 100) * 17) % 2_000,
            completions: 50 + ((dayOfYear + 100) * 7) % 500
        )
    }

    private func createWeeklyChallenge(for dayOfYear: Int, baseDate: Date) -> Challenge {
        let weekNumber = dayOfYear / 7
        let templates = [
            ("🌱", "Meat Illusion Mastery", "Create a plant-based dish that mimics meat in texture AND appearance using 3 techniques", "vegetarian", 500, "1 convincing meat substitute, 3 techniques shown"),
            ("💪", "Protein Architecture", "Build a 40g protein meal with visible protein sources in 5 different forms", "fitness", 600, "1 meal with 5 protein forms documented"),
            ("🌍", "Fusion Passport Challenge", "Combine techniques from 3 different cuisines in one cohesive dish with origin map", "international", 700, "1 dish fusing 3 cuisines with technique map"),
            ("⏱", "Mise en Place Master", "Show 10-min prep setup, then execute complex dish in 10 mins using only your prep", "quick", 550, "Prep grid photo + 20-min total execution"),
            ("❤️", "Flavor Without Guilt", "Create a dish with max flavor using herbs/spices instead of salt/fat - list all seasonings", "healthy", 580, "1 dish with seasoning blueprint documented"),
            ("🎨", "Deconstructed Classic", "Take a traditional dish and rebuild it with modern techniques and presentation", "creative", 620, "1 classic reimagined with technique notes"),
            ("🥦", "Root-to-Leaf Challenge", "Use every part of 3 vegetables including stems, leaves, and peels creatively", "vegetables", 650, "3 whole vegetables utilized, zero waste"),
            ("🍞", "Fermentation Station", "Create bread using homemade starter and document 3 fermentation stages", "baking", 700, "1 fermented bread with 3-stage photos")
        ]

        let template = templates[weekNumber % templates.count]
        let difficulty: DifficultyLevel = .hard
        let duration = challengeDurations[difficulty]!

        // Add different offset for weekly challenges
        let offsetHours = timeOffsets[(weekNumber + 3) % timeOffsets.count]
        let startDate = baseDate.addingTimeInterval(TimeInterval(offsetHours * 3_600))

        return Challenge(
            id: "weekly-\(dayOfYear)-\(Calendar.current.component(.year, from: baseDate))",
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
            ("🍖", "Smoke & Char Science", "Master 2 grilling techniques - direct heat sear and indirect smoke - on same dish", "grilling", 300, "1 dish with sear + smoke techniques shown"),
            ("🧁", "Texture Trinity Dessert", "Create a dessert with 3 textures in every bite - crunchy, creamy, and chewy elements", "dessert", 350, "1 dessert with 3 textures mapped"),
            ("🍸", "Mocktail Mixology Lab", "Build a layered mocktail with 3 density levels that don't mix - photo each layer", "drinks", 280, "1 tri-layer mocktail with density science"),
            ("🥞", "Brunch Board Balance", "Create a complete brunch board with sweet, savory, protein, and fresh elements in golden ratio", "brunch", 320, "1 board with 4 elements in 1:1:2:2 ratio"),
            ("🍿", "Gourmet Cinema Trilogy", "Transform movie snacks into gourmet with 3 flavor profiles - umami, sweet, spicy", "snacks", 290, "1 snack in 3 gourmet variations shown"),
            ("🎉", "Canape Construction", "Build 5 identical appetizers with precise measurements - document consistency", "entertaining", 400, "5 identical canapes with measurement proof")
        ]

        let template = templates[weekendNumber % templates.count]
        let difficulty: DifficultyLevel = .medium
        let duration = challengeDurations[difficulty]!

        // Different offset for weekend challenges
        let offsetHours = timeOffsets[(weekendNumber + 5) % timeOffsets.count]
        let startDate = baseDate.addingTimeInterval(TimeInterval(offsetHours * 3_600))

        return Challenge(
            id: "weekend-\(dayOfYear)-\(Calendar.current.component(.year, from: baseDate))",
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
            ("🔥", "#KitchenHackGenius", "Demonstrate a game-changing kitchen hack with before/after comparison photos", "viral", 200, "1 hack with before/after proof"),
            ("📸", "#PlatingPerfection", "Create a restaurant-worthy plate using the rule of thirds and height variation", "aesthetic", 250, "1 dish with plating breakdown photo"),
            ("⚡", "#SpeedrunChef", "Document a complete meal in 10 photos showing each 1-minute interval", "speed", 300, "10 timed progress photos"),
            ("🌶️", "#SpiceGradient", "Build a dish with 5 heat levels on one plate - mild to extreme with labels", "spicy", 280, "1 dish with 5 spice zones labeled"),
            ("🎭", "#UglyDelicious", "Transform an ugly ingredient into a beautiful dish - document the journey", "funny", 220, "Before/during/after transformation photos"),
            ("🏃", "#5MinuteMiracle", "Create a complete meal in 5 minutes with photo proof of timer at start/finish", "speed", 260, "1 meal with timer evidence"),
            ("🌟", "#PantryGlowUp", "Transform 5 basic pantry items into restaurant-quality dish with technique notes", "transformation", 340, "5 ingredients to 1 dish journey"),
            ("🎪", "#FoodIllusion", "Create a dish that looks like something else entirely - reveal the surprise", "creative", 380, "1 illusion dish with reveal photo"),
            ("🎨", "#ColorBlockCooking", "Create a dish with 6 distinct color blocks that don't blend", "aesthetic", 200, "1 dish with 6 separated colors"),
            ("🍜", "#NoodlePull", "Make hand-pulled noodles and capture the stretching technique in photos", "noodles", 320, "Noodle pulling sequence photos")
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
            (1, 1, ("🎊", "New Year Detox Bowl", "Build a rainbow detox bowl with 7 colors and fermented element for gut health", "healthy", 1_000, "1 bowl with 7 colors + fermented item")),
            (1, 15, ("🥶", "Layered Winter Stew", "Create a stew with 4 distinct layers cooked separately then combined - photo each layer", "comfort", 400, "1 stew with 4 layers documented")),

            // February
            (2, 14, ("❤️", "Heart-Shaped Mastery", "Create a dish with 3 heart-shaped elements using different techniques", "romantic", 800, "1 dish with 3 heart techniques shown")),
            (2, 28, ("🥞", "Pancake Stack Engineering", "Build a 5-layer pancake tower with different flavors/colors per layer - no mixing", "breakfast", 500, "5-layer stack with each layer detailed")),

            // March
            (3, 17, ("☘️", "Green Gradient Feast", "Create a dish with 5 shades of green from light to dark using natural ingredients", "irish", 600, "1 dish with 5 green gradients shown")),
            (3, 20, ("🌸", "Edible Garden Plate", "Design a dish that looks like a garden with 5 different spring vegetables as 'plants'", "seasonal", 550, "1 garden plate with 5 veggie 'plants'")),

            // April
            (4, 1, ("🃏", "Food Disguise Master", "Create a dessert that looks like a main dish or vice versa - document the reveal", "fun", 400, "1 disguised dish with reveal photos")),
            (4, 22, ("🌿", "Herb Symphony", "Use 7 different fresh herbs in one dish with each herb's role documented", "herbs", 700, "1 dish with 7 herbs and their purposes")),

            // May
            (5, 5, ("🌮", "Three-Salsa Fiesta", "Make 3 different salsas (red, green, white) from scratch for one Mexican dish", "mexican", 650, "1 dish with 3 homemade salsas shown")),
            (5, 28, ("🍔", "Grill Mark Mastery", "Create perfect crosshatch grill marks on 3 different items - document technique", "grilling", 700, "3 items with perfect grill marks shown")),

            // June
            (6, 21, ("☀️", "No-Cook Summer Magic", "Create a complete meal with 5 components without using any heat", "summer", 600, "1 no-heat meal with 5 components")),

            // July
            (7, 4, ("🇺🇸", "Red White Blue Layers", "Create a dish with distinct red, white, and blue layers using natural colors", "american", 750, "1 patriotic dish with 3 color layers")),
            (7, 25, ("🍦", "Three-Texture Frozen Treat", "Make frozen dessert with soft, crunchy, and chewy elements in each bite", "dessert", 500, "1 frozen dessert with 3 textures shown")),

            // August
            (8, 15, ("🏖", "Stackable Picnic Tower", "Create a portable meal that stacks in 4 layers for transport - show assembly", "outdoor", 550, "1 4-layer stackable meal documented")),

            // September
            (9, 22, ("🍂", "Autumn Texture Map", "Use 5 fall ingredients prepared 5 different ways (roasted, raw, pickled, pureed, fried)", "seasonal", 600, "5 fall ingredients, 5 preparations shown")),

            // October
            (10, 31, ("🎃", "Spooky Food Illusion", "Create an edible 'scary' dish with 3 surprise elements revealed when cut/broken", "halloween", 1_000, "1 scary dish with 3 hidden surprises")),

            // November
            (11, 24, ("🦃", "Deconstructed Thanksgiving", "Reimagine a classic Thanksgiving dish with all elements separated and elevated", "thanksgiving", 1_200, "1 classic deconstructed with technique notes")),

            // December
            (12, 24, ("🎄", "Edible Gift Masterpiece", "Create a dish that can be packaged as 5 individual gifts - show packaging", "christmas", 1_500, "1 dish portioned into 5 gift packages")),
            (12, 31, ("🥂", "Countdown Canapes", "Create 12 bite-sized appetizers representing each month - document each", "party", 800, "12 themed bites with month connections"))
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
            (80...89, ("🌸", "Spring Color Spectrum", "Create a dish using 6 spring vegetables in rainbow order with technique for each", "seasonal", 800, "6 spring veggies in spectrum with techniques")),
            (172...181, ("☀️", "Temperature Play", "Create a dish with hot, cold, and room temperature elements served together", "summer", 900, "1 dish with 3 temperatures documented")),
            (264...273, ("🍁", "Harvest Layer Cake", "Build a savory 'cake' with 4 autumn vegetable layers - slice to show layers", "autumn", 850, "1 savory cake with 4 visible layers")),
            (355...364, ("❄️", "Braising Masterclass", "Braise 3 different proteins/vegetables using 3 different liquids - document each", "winter", 950, "3 items braised in 3 liquids shown"))
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
