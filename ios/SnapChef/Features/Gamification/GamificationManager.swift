import Foundation
import SwiftUI
import CloudKit

// MARK: - Challenge Types
public enum ChallengeType: String, CaseIterable {
    case daily = "Daily Challenge"
    case weekly = "Weekly Challenge"
    case special = "Special Event"
    case community = "Community Challenge"

    var icon: String {
        switch self {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar"
        case .special: return "star.fill"
        case .community: return "person.3.fill"
        }
    }

    var color: Color {
        switch self {
        case .daily: return Color(hex: "#ffa726")
        case .weekly: return Color(hex: "#667eea")
        case .special: return Color(hex: "#f093fb")
        case .community: return Color(hex: "#43e97b")
        }
    }
}

// MARK: - Difficulty Level
public enum DifficultyLevel: Int, CaseIterable {
    case easy = 1
    case medium = 2
    case hard = 3
    case expert = 4
    case master = 5

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .expert: return "Expert"
        case .master: return "Master"
        }
    }

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .orange
        case .expert: return .red
        case .master: return .purple
        }
    }
}

// MARK: - Challenge Model
public struct Challenge: Identifiable {
    public let id: String
    let type: ChallengeType
    let title: String
    let description: String
    let category: String
    let difficulty: DifficultyLevel
    let points: Int
    let coins: Int
    let startDate: Date
    let endDate: Date
    let requirements: [String]
    var currentProgress: Double
    var isCompleted: Bool
    var isActive: Bool
    var isJoined: Bool
    let participants: Int
    let completions: Int
    let imageURL: String?
    let isPremium: Bool

    init(id: String = UUID().uuidString,
         title: String,
         description: String,
         type: ChallengeType,
         category: String = "cooking",
         difficulty: DifficultyLevel = .medium,
         points: Int = 100,
         coins: Int = 10,
         startDate: Date = Date(),
         endDate: Date,
         requirements: [String] = [],
         currentProgress: Double = 0,
         isCompleted: Bool = false,
         isActive: Bool = true,
         isJoined: Bool = false,
         participants: Int = 0,
         completions: Int = 0,
         imageURL: String? = nil,
         isPremium: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.category = category
        self.difficulty = difficulty
        self.points = points
        self.coins = coins
        self.startDate = startDate
        self.endDate = endDate
        self.requirements = requirements
        self.currentProgress = currentProgress
        self.isCompleted = isCompleted
        self.isActive = isActive && Date() < endDate
        self.isJoined = isJoined
        self.participants = participants
        self.completions = completions
        self.imageURL = imageURL
        self.isPremium = isPremium
    }

    var timeRemaining: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: endDate, relativeTo: Date())
    }
}

// MARK: - Challenge Reward
struct ChallengeReward {
    var points: Int
    var badge: String?
    var title: String?
    var unlockable: String?
}

// MARK: - User Stats
struct UserGameStats {
    var totalPoints: Int = 0
    var level: Int = 1
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var challengesCompleted: Int = 0
    var recipesCreated: Int = 0
    var perfectRecipes: Int = 0
    var badges: [GameBadge] = []
    var weeklyRank: Int?
    var globalRank: Int?

    var nextLevelPoints: Int {
        level * 1_000
    }

    var levelProgress: Double {
        let currentLevelPoints = totalPoints % nextLevelPoints
        return Double(currentLevelPoints) / Double(nextLevelPoints)
    }
}

// MARK: - Game Badge
struct GameBadge: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let rarity: BadgeRarity
    let unlockedDate: Date
}

enum BadgeRarity: String, CaseIterable {
    case common = "Common"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"

    var color: Color {
        switch self {
        case .common: return Color.gray
        case .rare: return Color(hex: "#4facfe")
        case .epic: return Color(hex: "#667eea")
        case .legendary: return Color(hex: "#f093fb")
        }
    }
}

// MARK: - Leaderboard Entry
struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let username: String
    let avatar: String
    let points: Int
    let level: Int
    let country: String?
    let isCurrentUser: Bool
}

// MARK: - Gamification Manager
@MainActor
final class GamificationManager: ObservableObject {
    static let shared = GamificationManager()

    @Published var userStats = UserGameStats()
    @Published var activeChallenges: [Challenge] = []
    @Published var completedChallenges: [Challenge] = []
    @Published var weeklyLeaderboard: [LeaderboardEntry] = []
    @Published var globalLeaderboard: [LeaderboardEntry] = []
    @Published var unlockedBadges: [GameBadge] = []
    @Published var pendingRewards: [ChallengeReward] = []
    @Published var hasCheckedInToday: Bool = false

    private let challengeDatabase = ChallengeDatabase.shared

    init() {
        loadMockData()
        checkDailyCheckInStatus()
        loadChallengesFromDatabase()

        // Subscribe to database updates
        challengeDatabase.$activeChallenges
            .assign(to: &$activeChallenges)

        // Also sync with CloudKit if authenticated
        if CloudKitAuthManager.shared.isAuthenticated {
            Task {
                await syncChallengesFromCloudKit()
            }
        }
    }

    // MARK: - Challenge Database Loading

    private func loadChallengesFromDatabase() {
        // The database automatically updates its active challenges
        // We just need to trigger an initial update
        challengeDatabase.updateActiveChallenges()
    }

    // MARK: - CloudKit Sync

    @MainActor
    private func syncChallengesFromCloudKit() async {
        do {
            // Sync challenges from CloudKit
            try await CloudKitManager.shared.syncChallenges()

            // Also sync user's challenge progress
            if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
                let predicate = NSPredicate(format: "userID == %@ AND status != %@", userID, "completed")
                let container = CKContainer(identifier: "iCloud.com.snapchefapp.app")
                let privateDB = container.privateCloudDatabase

                let query = CKQuery(recordType: "UserChallenge", predicate: predicate)
                let (results, _) = try await privateDB.records(matching: query)

                var userChallengeCount = 0
                for (_, result) in results {
                    if let record = try? result.get() {
                        // Update local challenge progress
                        if let challengeIDRef = record["challengeID"] as? CKRecord.Reference,
                           let progress = record["progress"] as? Double {
                            let challengeID = challengeIDRef.recordID.recordName
                            updateChallengeProgress(challengeID, progress: progress)
                            userChallengeCount += 1
                        }
                    }
                }

                print("✅ Synced \(userChallengeCount) active challenges from CloudKit")
            }
        } catch {
            print("❌ Failed to sync challenges from CloudKit: \(error)")
        }
    }

    // MARK: - Local Challenge Loading (Legacy - kept for reference)

    private func loadLocalChallenges() {
        // Generate all challenges locally
        let allChallenges = generateYearOfChallenges()

        // Create challenges with proper scheduling
        let calendar = Calendar.current
        let now = Date()
        var currentDate = calendar.startOfDay(for: now)

        // Go back 7 days to show some past challenges
        currentDate = calendar.date(byAdding: .day, value: -7, to: currentDate) ?? currentDate

        var scheduledChallenges: [Challenge] = []

        for (index, template) in allChallenges.enumerated() {
            let challenge = Challenge(
                id: "local_\(index)_\(template.title.lowercased().replacingOccurrences(of: " ", with: "_"))",
                title: template.title,
                description: template.description,
                type: template.durationDays <= 2 ? .daily : .weekly,
                category: template.category,
                difficulty: template.difficulty,
                points: template.points,
                coins: template.coins,
                startDate: currentDate,
                endDate: currentDate.addingTimeInterval(TimeInterval(template.durationDays * 24 * 60 * 60)),
                requirements: template.requirements,
                currentProgress: 0,
                isCompleted: false,
                isActive: true,
                isJoined: false,
                participants: Int.random(in: 100...2_000),
                completions: Int.random(in: 50...500),
                imageURL: nil,
                isPremium: template.isPremium
            )

            scheduledChallenges.append(challenge)

            // Move to next date for scheduling
            currentDate = currentDate.addingTimeInterval(TimeInterval(template.durationDays * 24 * 60 * 60))
        }

        // Filter to show only current and upcoming challenges
        let activeWindow = Date().addingTimeInterval(14 * 24 * 60 * 60) // Show next 2 weeks
        activeChallenges = scheduledChallenges.filter { challenge in
            return challenge.startDate <= Date() && challenge.endDate >= Date()
        }

        // Sort by end date (soonest first)
        activeChallenges.sort { $0.endDate < $1.endDate }

        print("📱 Loaded \(activeChallenges.count) active challenges from local data")

        // Schedule daily refresh
        Timer.scheduledTimer(withTimeInterval: 3_600, repeats: true) { _ in
            Task { @MainActor in
                self.refreshActiveChallenges()
            }
        }
    }

    private func refreshActiveChallenges() {
        // Reload challenges to update active status
        loadLocalChallenges()
    }

    // MARK: - Challenge Data

    private struct ChallengeTemplate {
        let emoji: String
        let title: String
        let description: String
        let category: String
        let difficulty: DifficultyLevel
        let points: Int
        let coins: Int
        let durationDays: Int
        let requirements: [String]
        let tags: [String]
        let isPremium: Bool
    }

    private func generateYearOfChallenges() -> [ChallengeTemplate] {
        var challenges: [ChallengeTemplate] = []

        // Winter Challenges
        challenges.append(contentsOf: [
            ChallengeTemplate(emoji: "🎄", title: "Holiday Cookie Decorating", description: "Create festive cookies that'll make Santa jealous!", category: "dessert", difficulty: .easy, points: 100, coins: 10, durationDays: 2, requirements: ["Decorate at least 6 cookies", "Use 3+ colors", "Share your creation"], tags: ["holiday", "baking", "family"], isPremium: false),
            ChallengeTemplate(emoji: "☕️", title: "Cozy Hot Chocolate Bar", description: "Build the ultimate hot chocolate station with toppings galore", category: "drinks", difficulty: .easy, points: 150, coins: 15, durationDays: 3, requirements: ["Create 3+ topping options", "Make it Instagram-worthy", "Try a unique flavor"], tags: ["winter", "cozy", "drinks"], isPremium: false),
            ChallengeTemplate(emoji: "🍲", title: "Soup Season Champion", description: "Master a hearty soup that warms the soul", category: "comfort", difficulty: .medium, points: 200, coins: 20, durationDays: 3, requirements: ["Make from scratch", "Include 5+ vegetables", "Perfect for freezing"], tags: ["winter", "healthy", "mealprep"], isPremium: false),
            ChallengeTemplate(emoji: "🥧", title: "New Year's Lucky Dish", description: "Cook a traditional good luck meal from any culture", category: "cultural", difficulty: .medium, points: 250, coins: 25, durationDays: 4, requirements: ["Research the tradition", "Use authentic ingredients", "Share the story"], tags: ["newyear", "cultural", "tradition"], isPremium: false),
            ChallengeTemplate(emoji: "🥗", title: "New Year New Salad", description: "Create a salad so good, you'll actually crave it", category: "healthy", difficulty: .easy, points: 150, coins: 15, durationDays: 2, requirements: ["Use 5+ ingredients", "Make homemade dressing", "Add protein"], tags: ["healthy", "newyear", "fresh"], isPremium: false),
            ChallengeTemplate(emoji: "🍜", title: "Ramen Glow-Up", description: "Transform instant ramen into restaurant-quality bowls", category: "asian", difficulty: .easy, points: 100, coins: 10, durationDays: 1, requirements: ["Start with instant ramen", "Add 5+ toppings", "Make it beautiful"], tags: ["budget", "quick", "asian"], isPremium: false),
            ChallengeTemplate(emoji: "🧃", title: "Smoothie Bowl Art", description: "Design a smoothie bowl that's almost too pretty to eat", category: "breakfast", difficulty: .easy, points: 150, coins: 15, durationDays: 2, requirements: ["Create a pattern/design", "Use 3+ toppings", "Natural colors only"], tags: ["healthy", "breakfast", "art"], isPremium: false),
            ChallengeTemplate(emoji: "❤️", title: "Valentine's Treats", description: "Spread love with homemade Valentine's goodies", category: "dessert", difficulty: .medium, points: 200, coins: 20, durationDays: 3, requirements: ["Make it heart-shaped", "Use pink/red colors", "Package beautifully"], tags: ["valentine", "love", "gift"], isPremium: false),
            ChallengeTemplate(emoji: "🫔", title: "Comfort Food Remix", description: "Give your favorite comfort food a healthy makeover", category: "comfort", difficulty: .medium, points: 250, coins: 25, durationDays: 3, requirements: ["Cut calories by 30%", "Keep it delicious", "Share the swap tips"], tags: ["healthy", "comfort", "remix"], isPremium: false),
            ChallengeTemplate(emoji: "🥞", title: "Pancake Art Master", description: "Create edible art with colorful pancake designs", category: "breakfast", difficulty: .hard, points: 300, coins: 30, durationDays: 2, requirements: ["Create a character/design", "Use natural food coloring", "Make it flip-able"], tags: ["breakfast", "art", "viral"], isPremium: true)
        ])

        // Spring Challenges
        challenges.append(contentsOf: [
            ChallengeTemplate(emoji: "🌈", title: "Rainbow Veggie Challenge", description: "Eat the rainbow with colorful veggie creations", category: "healthy", difficulty: .easy, points: 150, coins: 15, durationDays: 3, requirements: ["Use 5+ colors", "All natural ingredients", "Make it appealing to kids"], tags: ["spring", "healthy", "colorful"], isPremium: false),
            ChallengeTemplate(emoji: "☘️", title: "Lucky Green Foods", description: "Go green for St. Patrick's Day with natural green dishes", category: "holiday", difficulty: .medium, points: 200, coins: 20, durationDays: 2, requirements: ["Everything green", "No artificial coloring", "Include a green drink"], tags: ["stpatricks", "green", "holiday"], isPremium: false),
            ChallengeTemplate(emoji: "🥚", title: "Egg-cellent Creations", description: "Master eggs in ways you never imagined", category: "breakfast", difficulty: .medium, points: 200, coins: 20, durationDays: 3, requirements: ["Try 3 cooking methods", "Make it Instagram-worthy", "Perfect the timing"], tags: ["easter", "breakfast", "protein"], isPremium: false),
            ChallengeTemplate(emoji: "🌷", title: "Edible Flowers", description: "Incorporate edible flowers into gorgeous dishes", category: "gourmet", difficulty: .hard, points: 350, coins: 35, durationDays: 4, requirements: ["Use real edible flowers", "Create 2+ dishes", "Focus on presentation"], tags: ["spring", "fancy", "flowers"], isPremium: true),
            ChallengeTemplate(emoji: "🧺", title: "Perfect Picnic Spread", description: "Create portable foods perfect for spring picnics", category: "outdoor", difficulty: .medium, points: 250, coins: 25, durationDays: 3, requirements: ["Make 3+ items", "Everything travel-friendly", "No heating required"], tags: ["spring", "outdoor", "portable"], isPremium: false),
            ChallengeTemplate(emoji: "🌮", title: "Taco Tuesday Takeover", description: "Reinvent Taco Tuesday with creative fillings", category: "mexican", difficulty: .easy, points: 150, coins: 15, durationDays: 1, requirements: ["Make 3+ taco varieties", "One must be vegetarian", "Make fresh salsa"], tags: ["mexican", "tuesday", "party"], isPremium: false),
            ChallengeTemplate(emoji: "🍓", title: "Berry Delicious", description: "Celebrate berry season with fresh berry creations", category: "dessert", difficulty: .easy, points: 150, coins: 15, durationDays: 2, requirements: ["Use 3+ berry types", "Make something unexpected", "No added sugar option"], tags: ["spring", "fruit", "fresh"], isPremium: false)
        ])

        // Summer Challenges
        challenges.append(contentsOf: [
            ChallengeTemplate(emoji: "🍔", title: "Better Burger Battle", description: "Create a gourmet burger that beats any restaurant", category: "grilling", difficulty: .medium, points: 250, coins: 25, durationDays: 3, requirements: ["Make the bun from scratch", "Create a signature sauce", "Stack it high"], tags: ["summer", "grilling", "american"], isPremium: false),
            ChallengeTemplate(emoji: "🍦", title: "No-Churn Ice Cream", description: "Make creamy ice cream without a machine", category: "dessert", difficulty: .medium, points: 200, coins: 20, durationDays: 2, requirements: ["Create 2+ flavors", "Add mix-ins", "Achieve creamy texture"], tags: ["summer", "frozen", "dessert"], isPremium: false),
            ChallengeTemplate(emoji: "🎆", title: "Red, White & Blue", description: "Create patriotic treats for Independence Day", category: "holiday", difficulty: .easy, points: 150, coins: 15, durationDays: 2, requirements: ["Use all 3 colors", "Make it festive", "Kid-friendly"], tags: ["july4th", "patriotic", "holiday"], isPremium: false),
            ChallengeTemplate(emoji: "🌽", title: "Corn on the Cob Remix", description: "Elevate corn with international flavors", category: "sides", difficulty: .easy, points: 100, coins: 10, durationDays: 1, requirements: ["Try 3+ flavor profiles", "Include a spicy version", "Make it messy-good"], tags: ["summer", "bbq", "vegetables"], isPremium: false),
            ChallengeTemplate(emoji: "🍉", title: "Watermelon Wow", description: "Transform watermelon into unexpected dishes", category: "fruit", difficulty: .medium, points: 200, coins: 20, durationDays: 2, requirements: ["Make a savory dish", "Try grilling/cooking", "Zero waste challenge"], tags: ["summer", "fruit", "creative"], isPremium: false),
            ChallengeTemplate(emoji: "🥤", title: "Mocktail Mixologist", description: "Create Instagram-worthy alcohol-free cocktails", category: "drinks", difficulty: .medium, points: 200, coins: 20, durationDays: 3, requirements: ["Design 3+ mocktails", "Make fancy ice cubes", "Garnish game strong"], tags: ["summer", "drinks", "party"], isPremium: false),
            ChallengeTemplate(emoji: "🏖️", title: "Beach Snack Pack", description: "Create portable snacks perfect for beach days", category: "snacks", difficulty: .easy, points: 150, coins: 15, durationDays: 2, requirements: ["No refrigeration needed", "Sand-proof packaging", "Healthy options"], tags: ["summer", "beach", "portable"], isPremium: false)
        ])

        // Fall Challenges
        challenges.append(contentsOf: [
            ChallengeTemplate(emoji: "🍎", title: "Apple Everything", description: "Celebrate apple season with sweet and savory dishes", category: "seasonal", difficulty: .medium, points: 200, coins: 20, durationDays: 3, requirements: ["Make 1 sweet + 1 savory", "Use 3+ apple varieties", "Include apple chips"], tags: ["fall", "apples", "harvest"], isPremium: false),
            ChallengeTemplate(emoji: "📚", title: "Back to School Lunch", description: "Create exciting lunches kids will actually eat", category: "lunch", difficulty: .medium, points: 250, coins: 25, durationDays: 5, requirements: ["Make 5 different lunches", "No repeats", "Include fun notes"], tags: ["school", "kids", "lunch"], isPremium: false),
            ChallengeTemplate(emoji: "🎃", title: "Pumpkin Spice Everything", description: "Go beyond the latte with creative pumpkin dishes", category: "seasonal", difficulty: .medium, points: 250, coins: 25, durationDays: 4, requirements: ["Make 3+ items", "One must be savory", "From-scratch pumpkin puree"], tags: ["fall", "pumpkin", "trending"], isPremium: false),
            ChallengeTemplate(emoji: "👻", title: "Spooky Food Art", description: "Create Halloween treats that are scary good", category: "holiday", difficulty: .hard, points: 300, coins: 30, durationDays: 3, requirements: ["Make it creepy-cute", "Use natural ingredients", "Kid-approved"], tags: ["halloween", "spooky", "fun"], isPremium: true),
            ChallengeTemplate(emoji: "🍄", title: "Mushroom Magic", description: "Explore the world of mushrooms in creative dishes", category: "vegetarian", difficulty: .medium, points: 200, coins: 20, durationDays: 3, requirements: ["Use 3+ mushroom types", "Make mushroom 'meat'", "Try a new technique"], tags: ["fall", "vegetarian", "umami"], isPremium: false),
            ChallengeTemplate(emoji: "🦃", title: "Thanksgiving Sides Star", description: "Create a side dish that steals the show", category: "holiday", difficulty: .hard, points: 350, coins: 35, durationDays: 5, requirements: ["Elevate a classic", "Make it ahead-friendly", "Wow factor required"], tags: ["thanksgiving", "sides", "holiday"], isPremium: true),
            ChallengeTemplate(emoji: "🥧", title: "Pie Perfection", description: "Master the art of pie making from crust to filling", category: "dessert", difficulty: .hard, points: 400, coins: 40, durationDays: 4, requirements: ["Make crust from scratch", "Try a lattice top", "Perfect the edges"], tags: ["thanksgiving", "baking", "dessert"], isPremium: true),
            ChallengeTemplate(emoji: "🍂", title: "Leftover Makeover", description: "Transform Thanksgiving leftovers into new meals", category: "creative", difficulty: .medium, points: 200, coins: 20, durationDays: 2, requirements: ["Create 3+ new dishes", "No simple reheating", "Make it crave-worthy"], tags: ["thanksgiving", "leftovers", "creative"], isPremium: false)
        ])

        // Viral Challenges
        challenges.append(contentsOf: [
            ChallengeTemplate(emoji: "🧈", title: "Butter Board Bonanza", description: "Create a trendy butter board that goes viral", category: "trending", difficulty: .easy, points: 200, coins: 20, durationDays: 2, requirements: ["Use compound butters", "Make it artistic", "Include 5+ toppings"], tags: ["viral", "trending", "party"], isPremium: false),
            ChallengeTemplate(emoji: "🍳", title: "Tiny Kitchen Challenge", description: "Cook a full meal using only miniature tools", category: "challenge", difficulty: .hard, points: 500, coins: 50, durationDays: 3, requirements: ["Use toy cookware", "Make 3 courses", "Everything must work"], tags: ["viral", "challenge", "fun"], isPremium: true),
            ChallengeTemplate(emoji: "🧀", title: "Cheese Pull Champion", description: "Create the most epic cheese pull video", category: "viral", difficulty: .medium, points: 250, coins: 25, durationDays: 2, requirements: ["Get the perfect stretch", "Try 3+ dishes", "Slow-mo required"], tags: ["viral", "cheese", "video"], isPremium: false),
            ChallengeTemplate(emoji: "🌯", title: "Wrap Hack Magic", description: "Master the viral tortilla wrap hack with creative fillings", category: "trending", difficulty: .easy, points: 150, coins: 15, durationDays: 1, requirements: ["Try 3+ combinations", "One breakfast version", "Perfect the fold"], tags: ["viral", "hack", "quick"], isPremium: false),
            ChallengeTemplate(emoji: "🥞", title: "Pancake Cereal", description: "Join the mini pancake cereal trend", category: "trending", difficulty: .medium, points: 200, coins: 20, durationDays: 1, requirements: ["Make them tiny", "Try 2+ flavors", "Serve in a bowl"], tags: ["viral", "breakfast", "mini"], isPremium: false),
            ChallengeTemplate(emoji: "☁️", title: "Cloud Bread Dreams", description: "Make the fluffiest cloud bread in pastel colors", category: "trending", difficulty: .medium, points: 250, coins: 25, durationDays: 2, requirements: ["Achieve cloud texture", "Natural colors only", "Make it jiggle"], tags: ["viral", "baking", "aesthetic"], isPremium: false),
            ChallengeTemplate(emoji: "🍝", title: "One-Pot Pasta Magic", description: "Create a one-pot pasta that looks like wizardry", category: "easy", difficulty: .easy, points: 150, coins: 15, durationDays: 1, requirements: ["Everything in one pot", "15 minutes max", "Restaurant quality"], tags: ["viral", "easy", "pasta"], isPremium: false),
            ChallengeTemplate(emoji: "🎂", title: "Mug Cake Master", description: "Perfect the 2-minute mug cake", category: "dessert", difficulty: .easy, points: 100, coins: 10, durationDays: 1, requirements: ["Under 2 minutes", "Try 3 flavors", "No overflow allowed"], tags: ["viral", "quick", "dessert"], isPremium: false),
            ChallengeTemplate(emoji: "🥑", title: "Avocado Rose Art", description: "Master the art of avocado roses", category: "skills", difficulty: .medium, points: 200, coins: 20, durationDays: 2, requirements: ["Create perfect roses", "3+ presentation styles", "Tutorial video"], tags: ["viral", "skills", "art"], isPremium: false),
            ChallengeTemplate(emoji: "🌊", title: "Ocean Water Cake", description: "Create a mesmerizing ocean-effect gelatin cake", category: "dessert", difficulty: .hard, points: 400, coins: 40, durationDays: 3, requirements: ["Create wave effect", "Multiple blue shades", "Add 'sea creatures'"], tags: ["viral", "artistic", "challenge"], isPremium: true)
        ])

        // Weekend Challenges
        challenges.append(contentsOf: [
            ChallengeTemplate(emoji: "🥓", title: "Breakfast for Dinner", description: "Flip the script with epic breakfast at dinnertime", category: "weekend", difficulty: .easy, points: 150, coins: 15, durationDays: 2, requirements: ["Make it fancy", "Include a cocktail/mocktail", "Candlelit breakfast"], tags: ["weekend", "breakfast", "fun"], isPremium: false),
            ChallengeTemplate(emoji: "🍕", title: "Pizza Night Reinvented", description: "Take pizza night to the next level", category: "weekend", difficulty: .medium, points: 250, coins: 25, durationDays: 3, requirements: ["Make dough from scratch", "Try 3+ topping combos", "One dessert pizza"], tags: ["weekend", "pizza", "family"], isPremium: false),
            ChallengeTemplate(emoji: "🍿", title: "Movie Night Snacks", description: "Create cinema-worthy snacks at home", category: "weekend", difficulty: .easy, points: 150, coins: 15, durationDays: 2, requirements: ["Make 3+ snacks", "Gourmet popcorn required", "Create snack boxes"], tags: ["weekend", "snacks", "movie"], isPremium: false),
            ChallengeTemplate(emoji: "🧺", title: "Farmers Market Haul", description: "Create a meal using only farmers market finds", category: "weekend", difficulty: .medium, points: 300, coins: 30, durationDays: 3, requirements: ["Visit local market", "Use 5+ vendors", "Share vendor stories"], tags: ["weekend", "local", "fresh"], isPremium: false),
            ChallengeTemplate(emoji: "🎮", title: "Game Day Spread", description: "Create the ultimate spread for game day", category: "weekend", difficulty: .medium, points: 250, coins: 25, durationDays: 3, requirements: ["Make 5+ items", "Include a showstopper", "Easy to eat while watching"], tags: ["weekend", "sports", "party"], isPremium: false),
            ChallengeTemplate(emoji: "🌅", title: "Sunrise Breakfast", description: "Wake up early for a spectacular sunrise meal", category: "weekend", difficulty: .easy, points: 200, coins: 20, durationDays: 2, requirements: ["Cook outdoors", "Capture sunrise", "Make it memorable"], tags: ["weekend", "outdoor", "breakfast"], isPremium: false),
            ChallengeTemplate(emoji: "🎨", title: "Edible Art Project", description: "Create food that belongs in a gallery", category: "weekend", difficulty: .hard, points: 400, coins: 40, durationDays: 3, requirements: ["Recreate famous art", "Use only food", "Frame-worthy presentation"], tags: ["weekend", "art", "creative"], isPremium: true),
            ChallengeTemplate(emoji: "🏕️", title: "Indoor Camping Cuisine", description: "Bring camping food indoors with a twist", category: "weekend", difficulty: .medium, points: 200, coins: 20, durationDays: 2, requirements: ["Make s'mores 2.0", "Indoor 'campfire' cooking", "Tell ghost stories"], tags: ["weekend", "camping", "family"], isPremium: false),
            ChallengeTemplate(emoji: "🎪", title: "Carnival at Home", description: "Recreate carnival favorites in your kitchen", category: "weekend", difficulty: .medium, points: 250, coins: 25, durationDays: 3, requirements: ["Make 3+ fair foods", "Include cotton candy", "Create the atmosphere"], tags: ["weekend", "carnival", "fun"], isPremium: false),
            ChallengeTemplate(emoji: "🌍", title: "Around the World", description: "Cook a dish from 5 different countries in one weekend", category: "weekend", difficulty: .hard, points: 500, coins: 50, durationDays: 3, requirements: ["5 different cuisines", "Authentic recipes", "Create passports"], tags: ["weekend", "international", "adventure"], isPremium: true)
        ])

        // Add duplicates to ensure we have 365 days worth
        while challenges.count < 365 {
            challenges.append(contentsOf: challenges.prefix(365 - challenges.count))
        }

        return challenges
    }

    // MARK: - CloudKit Integration

    private func setupCloudKitSync() {
        // Start syncing with CloudKit
        Task {
            await CloudKitSyncService.shared.syncChallenges()
            await CloudKitSyncService.shared.syncUserProgress()
        }
    }

    func updateChallenges(_ challenges: [Challenge]) {
        // Clear old challenges and use CloudKit as source of truth
        activeChallenges = challenges.filter { challenge in
            let now = Date()
            return challenge.startDate <= now && challenge.endDate >= now && !challenge.isCompleted
        }

        // Sort by end date (soonest first)
        activeChallenges.sort { $0.endDate < $1.endDate }

        print("📱 Updated challenges from CloudKit: \(activeChallenges.count) active")
    }

    func syncUserChallenges(_ userChallenges: [UserChallenge]) {
        // Update local challenge progress from CloudKit
        for userChallenge in userChallenges {
            if let index = activeChallenges.firstIndex(where: { $0.id == userChallenge.challengeID }) {
                activeChallenges[index].currentProgress = userChallenge.progress
                activeChallenges[index].isCompleted = userChallenge.status == "completed"

                if userChallenge.status == "completed" {
                    // Move to completed
                    let challenge = activeChallenges.remove(at: index)
                    completedChallenges.append(challenge)

                    // Update stats
                    userStats.totalPoints += userChallenge.earnedPoints
                    userStats.challengesCompleted += 1
                }
            }
        }
    }

    func getChallenge(by id: String) -> Challenge? {
        // Check active challenges first
        if let challenge = activeChallenges.first(where: { $0.id == id }) {
            return challenge
        }

        // Check completed challenges
        if let challenge = completedChallenges.first(where: { $0.id == id }) {
            return challenge
        }

        // Check database for all challenges
        return challengeDatabase.getChallenge(by: id)
    }

    func updateChallengeProgress(_ challengeID: String, progress: Double) {
        if let index = activeChallenges.firstIndex(where: { $0.id == challengeID }) {
            activeChallenges[index].currentProgress = progress

            // Only mark as completed when progress reaches 1.0 AND proof has been submitted
            // The actual completion happens in submitChallengeProof method
            if progress >= 1.0 {
                activeChallenges[index].isCompleted = true
                // Move to completed
                let challenge = activeChallenges.remove(at: index)
                completedChallenges.append(challenge)
                
                print("✅ Challenge marked as completed after proof submission: \(challenge.title)")
            }
        }
    }

    func syncChallengeProgress(for challengeID: String, progress: Double) async {
        guard let userID = AuthenticationManager().currentUser?.id else { return }

        let userChallenge = UserChallenge(
            userID: userID,
            challengeID: challengeID,
            status: progress >= 1.0 ? "completed" : "active",
            progress: progress,
            startedAt: Date(),
            completedAt: progress >= 1.0 ? Date() : nil,
            earnedPoints: progress >= 1.0 ? (activeChallenges.first { $0.id == challengeID }?.points ?? 0) : 0,
            earnedCoins: progress >= 1.0 ? (activeChallenges.first { $0.id == challengeID }?.coins ?? 0) : 0,
            proofImageURL: nil,
            notes: nil,
            teamID: nil
        )

        do {
            try await CloudKitManager.shared.saveUserChallenge(userChallenge)
        } catch {
            print("Failed to sync challenge progress: \(error)")
        }
    }

    // MARK: - Challenge Management

    func saveChallenge(_ challenge: Challenge) {
        // Add challenge to active challenges
        activeChallenges.append(challenge)
    }

    func saveChallengeProgress(challengeId: String, action: String, value: Double, metadata: [String: Any]? = nil) {
        // Save challenge progress
        print("Saving progress for challenge \(challengeId): \(action) = \(value)")

        // Update local progress
        if let index = activeChallenges.firstIndex(where: { $0.id == challengeId }) {
            activeChallenges[index].currentProgress = min(value, 1.0)

            // Sync with CloudKit
            Task {
                await syncChallengeProgress(for: challengeId, progress: value)
            }
        }
    }

    func joinChallenge(_ challenge: Challenge) {
        // Check if authentication is required
        let authManager = CloudKitAuthManager.shared
        if authManager.isAuthRequiredFor(feature: .challenges) {
            authManager.promptAuthForFeature(.challenges)
            return
        }

        // Join challenge logic
        print("Joined challenge: \(challenge.title)")

        // Check if already joined by ID or title
        if !activeChallenges.contains(where: { $0.id == challenge.id || $0.title == challenge.title }) {
            var joinedChallenge = challenge
            joinedChallenge.isJoined = true
            joinedChallenge.currentProgress = 0
            activeChallenges.append(joinedChallenge)

            // Track analytics
            ChallengeAnalyticsService.shared.trackChallengeInteraction(
                challengeId: challenge.id,
                action: "started",
                metadata: [
                    "challengeType": challenge.type.rawValue,
                    "difficulty": challenge.difficulty.rawValue,
                    "category": challenge.category
                ]
            )

            // Sync with CloudKit
            Task {
                await syncChallengeProgress(for: challenge.id, progress: 0)
            }
        }
    }

    func isChallengeJoined(_ challengeId: String) -> Bool {
        return activeChallenges.contains(where: { $0.id == challengeId }) ||
               completedChallenges.contains(where: { $0.id == challengeId })
    }

    func isChallengeJoinedByTitle(_ title: String) -> Bool {
        return activeChallenges.contains(where: { $0.title == title }) ||
               completedChallenges.contains(where: { $0.title == title })
    }

    func completeChallenge(challengeId: String) {
        // This method should not be used for completing challenges
        // Challenge completion should only happen via submitChallengeProof
        print("⚠️ WARNING: completeChallenge called directly. Challenges should only be completed via proof submission.")
        // Find challenge by title (used as ID in some cases)
        if let challenge = activeChallenges.first(where: { $0.title == challengeId }) {
            print("⚠️ Challenge '\(challenge.title)' cannot be completed without proof submission")
            // Do not complete the challenge - require proof submission
        }
    }

    private func completeChallenge(_ challenge: Challenge) {
        var completedChallenge = challenge
        completedChallenge.isCompleted = true
        completedChallenges.append(completedChallenge)

        // Apply premium rewards if applicable
        let premiumManager = PremiumChallengeManager.shared
        let (finalPoints, finalCoins) = premiumManager.applyDoubleRewards(
            basePoints: challenge.points,
            baseCoins: challenge.coins
        )

        // Award rewards (with premium multiplier)
        awardPoints(finalPoints)

        // Remove from active
        activeChallenges.removeAll { $0.id == challenge.id }

        // Update stats
        userStats.challengesCompleted += 1

        // Track analytics
        ChallengeAnalyticsService.shared.trackChallengeInteraction(
            challengeId: challenge.id,
            action: "completed",
            metadata: [
                "challengeType": challenge.type.rawValue,
                "difficulty": challenge.difficulty.rawValue,
                "category": challenge.category,
                "pointsEarned": challenge.points,
                "coinsEarned": challenge.coins
            ]
        )

        // Track coin earning
        ChallengeAnalyticsService.shared.trackRewardInteraction(
            rewardType: "coins",
            amount: challenge.coins,
            source: "challenge_completion"
        )

        // Update CloudKit leaderboard
        Task {
            do {
                try await CloudKitManager.shared.updateLeaderboardEntry(
                    for: AuthenticationManager().currentUser?.id ?? "",
                    points: challenge.points,
                    challengesCompleted: userStats.challengesCompleted
                )
            } catch {
                print("Failed to update leaderboard: \(error)")
            }
        }
    }

    func completeChallengeWithPersistence(_ challenge: Challenge, score: Int) {
        var completedChallenge = challenge
        completedChallenge.isCompleted = true
        completedChallenges.append(completedChallenge)

        // Apply premium rewards if applicable
        let premiumManager = PremiumChallengeManager.shared
        let (finalPoints, _) = premiumManager.applyDoubleRewards(
            basePoints: score,
            baseCoins: 0
        )

        // Award rewards with score (with premium multiplier)
        awardPoints(finalPoints)

        // Remove from active
        activeChallenges.removeAll { $0.id == challenge.id }

        // Update stats
        userStats.challengesCompleted += 1

        // Save to persistent storage
        saveChallengeProgress(
            challengeId: challenge.id,
            action: "completed",
            value: 1.0,
            metadata: ["score": finalPoints]
        )

        // Track analytics
        ChallengeAnalyticsService.shared.trackChallengeInteraction(
            challengeId: challenge.id,
            action: "completed",
            metadata: [
                "challengeType": challenge.type.rawValue,
                "difficulty": challenge.difficulty.rawValue,
                "category": challenge.category,
                "score": score,
                "pointsEarned": score,
                "coinsEarned": challenge.coins
            ]
        )

        // Update CloudKit
        Task {
            await syncChallengeProgress(for: challenge.id, progress: 1.0)
        }
    }

    // MARK: - Points & Rewards

    func awardPoints(_ points: Int, reason: String = "") {
        userStats.totalPoints += points

        // Check for level up
        let newLevel = (userStats.totalPoints / 1_000) + 1
        if newLevel > userStats.level {
            levelUp(to: newLevel)
        }

        print("Awarded \(points) points. Total: \(userStats.totalPoints)")
    }

    private func levelUp(to newLevel: Int) {
        userStats.level = newLevel

        // Award level up rewards
        let levelBadge = GameBadge(
            name: "Level \(newLevel) Chef",
            icon: "star.fill",
            description: "Reached level \(newLevel)",
            rarity: newLevel < 10 ? .common : newLevel < 25 ? .rare : newLevel < 50 ? .epic : .legendary,
            unlockedDate: Date()
        )
        unlockedBadges.append(levelBadge)
    }

    func awardBadge(_ badgeName: String) {
        // Award badge logic
        print("Awarded badge: \(badgeName)")

        // Save achievement to CloudKit if authenticated
        if CloudKitAuthManager.shared.isAuthenticated {
            Task {
                do {
                    guard let userID = UserDefaults.standard.string(forKey: "currentUserID") else { return }

                    let container = CKContainer(identifier: "iCloud.com.snapchefapp.app")
                    let privateDB = container.privateCloudDatabase

                    // Create achievement record
                    let achievementRecord = CKRecord(recordType: "Achievement")
                    achievementRecord["id"] = UUID().uuidString
                    achievementRecord["userID"] = userID
                    achievementRecord["name"] = badgeName
                    achievementRecord["description"] = "Earned \(badgeName) badge"
                    achievementRecord["iconName"] = "🏆"
                    achievementRecord["earnedAt"] = Date()
                    achievementRecord["points"] = 100

                    _ = try await privateDB.save(achievementRecord)
                    print("✅ Achievement saved to CloudKit: \(badgeName)")
                } catch {
                    print("❌ Failed to save achievement to CloudKit: \(error)")
                }
            }
        }
    }

    // MARK: - Streak Management

    func updateStreak() {
        userStats.currentStreak += 1
        if userStats.currentStreak > userStats.longestStreak {
            userStats.longestStreak = userStats.currentStreak
        }

        // Award streak bonuses
        switch userStats.currentStreak {
        case 3:
            awardPoints(50, reason: "3-day streak")
        case 7:
            awardPoints(150, reason: "7-day streak")
            awardBadge("Week Warrior")
        case 30:
            awardPoints(500, reason: "30-day streak")
            awardBadge("Dedication Master")
        default:
            break
        }
    }

    func breakStreak() {
        userStats.currentStreak = 0
    }

    // MARK: - Recipe Tracking

    func trackRecipeCreated(_ recipe: Recipe) {
        userStats.recipesCreated += 1
        awardPoints(10, reason: "Recipe created")

        // Check for milestones
        switch userStats.recipesCreated {
        case 10:
            awardBadge("Recipe Explorer")
        case 50:
            awardBadge("Culinary Creator")
        case 100:
            awardBadge("Master Chef")
        default:
            break
        }

        // Update challenge progress
        for challenge in activeChallenges {
            if challenge.title.contains("recipe") || challenge.title.contains("cook") {
                updateChallengeProgress(challenge.id, progress: min(challenge.currentProgress + 0.1, 1.0))
            }
        }
    }

    func trackPerfectRecipe() {
        userStats.perfectRecipes += 1
        awardPoints(50, reason: "Perfect recipe")

        if userStats.perfectRecipes == 5 {
            awardBadge("Perfectionist")
        }
    }

    // MARK: - Leaderboard

    func updateLeaderboards() async {
        // In real app, fetch from server
        // For now, using mock data
    }

    // MARK: - Daily Check-In

    func performDailyCheckIn() {
        hasCheckedInToday = true
        updateStreak()

        // Save check-in date
        UserDefaults.standard.set(Date(), forKey: "lastCheckInDate")

        // Award daily points
        awardPoints(50, reason: "Daily check-in")

        // Track analytics
        ChallengeAnalyticsService.shared.trackEvent(.milestoneReached, parameters: [
            "milestone": "daily_checkin",
            "streak": userStats.currentStreak,
            "pointsEarned": 50
        ])

        // Track coin earning from daily check-in
        ChallengeAnalyticsService.shared.trackRewardInteraction(
            rewardType: "points",
            amount: 50,
            source: "daily_checkin"
        )
    }

    private func checkDailyCheckInStatus() {
        // Check if user has already checked in today
        if let lastCheckIn = UserDefaults.standard.object(forKey: "lastCheckInDate") as? Date {
            let calendar = Calendar.current
            hasCheckedInToday = calendar.isDateInToday(lastCheckIn)

            // Check if streak should be broken
            if !calendar.isDateInYesterday(lastCheckIn) && !calendar.isDateInToday(lastCheckIn) {
                breakStreak()
            }
        }
    }

    // MARK: - Mock Data

    private func loadMockData() {
        // Set user stats
        userStats = UserGameStats(
            totalPoints: 3_250,
            level: 4,
            currentStreak: 5,
            longestStreak: 12,
            challengesCompleted: 8,
            recipesCreated: 47,
            perfectRecipes: 12,
            badges: [],
            weeklyRank: 156,
            globalRank: 2_847
        )

        // Active challenges - empty initially, will be populated when user joins from HomeView
        activeChallenges = []

        // Leaderboard data
        weeklyLeaderboard = generateMockLeaderboard(count: 100, includeUser: true, userRank: 156)
        globalLeaderboard = generateMockLeaderboard(count: 100, includeUser: true, userRank: 2_847)

        // Unlocked badges
        unlockedBadges = [
            GameBadge(
                name: "First Recipe",
                icon: "star.fill",
                description: "Created your first recipe",
                rarity: .common,
                unlockedDate: Date().addingTimeInterval(-864_000)
            ),
            GameBadge(
                name: "Week Warrior",
                icon: "flame.fill",
                description: "7-day streak achieved",
                rarity: .rare,
                unlockedDate: Date().addingTimeInterval(-172_800)
            ),
            GameBadge(
                name: "Social Butterfly",
                icon: "person.3.fill",
                description: "Shared 10 recipes",
                rarity: .rare,
                unlockedDate: Date().addingTimeInterval(-432_000)
            )
        ]
    }

    private func generateMockLeaderboard(count: Int, includeUser: Bool, userRank: Int) -> [LeaderboardEntry] {
        var entries: [LeaderboardEntry] = []

        let usernames = ["ChefMaster", "CookingNinja", "RecipeKing", "FoodieQueen", "KitchenHero", "FlavorWizard", "SpiceGuru", "MealMagician"]
        let countries = ["US", "UK", "CA", "AU", "DE", "FR", "JP", "BR", "IN", "MX"]

        for i in 1...count {
            let isUser = includeUser && i == min(userRank, count)
            entries.append(
                LeaderboardEntry(
                    rank: i,
                    username: isUser ? "You" : "\(usernames.randomElement()!)\(i)",
                    avatar: "person.circle.fill",
                    points: max(10_000 - (i * 50), 100),
                    level: max(50 - (i / 10), 1),
                    country: countries.randomElement(),
                    isCurrentUser: isUser
                )
            )
        }

        return entries
    }
}

// MARK: - Challenge Extensions
extension Challenge {
    static var mockDailyChallenge: Challenge {
        Challenge(
            title: "Quick Chef",
            description: "Create a recipe in under 5 minutes",
            type: .daily,
            endDate: Date().addingTimeInterval(86_400),
            requirements: ["Time limit challenge"],
            currentProgress: 0,
            participants: 523
        )
    }
}
