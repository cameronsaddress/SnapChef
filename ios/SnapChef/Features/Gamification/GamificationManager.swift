import Foundation
import SwiftUI

// MARK: - Challenge Types
enum ChallengeType: String, CaseIterable {
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

// MARK: - Challenge Model
struct Challenge: Identifiable {
    let id = UUID()
    let type: ChallengeType
    let title: String
    let description: String
    let requirement: String
    let reward: ChallengeReward
    let endDate: Date
    let participants: Int
    var progress: Double = 0
    var isCompleted: Bool = false
    var rank: Int?
    
    var isActive: Bool {
        Date() < endDate
    }
    
    var timeRemaining: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: endDate, relativeTo: Date())
    }
}

// MARK: - Challenge Reward
struct ChallengeReward {
    let points: Int
    let badge: String?
    let title: String?
    let unlockable: String?
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
        level * 1000
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
class GamificationManager: ObservableObject {
    static let shared = GamificationManager()
    
    @Published var userStats = UserGameStats()
    @Published var activeChallenges: [Challenge] = []
    @Published var completedChallenges: [Challenge] = []
    @Published var weeklyLeaderboard: [LeaderboardEntry] = []
    @Published var globalLeaderboard: [LeaderboardEntry] = []
    @Published var unlockedBadges: [GameBadge] = []
    @Published var pendingRewards: [ChallengeReward] = []
    
    private init() {
        loadMockData()
    }
    
    // MARK: - Challenge Management
    
    func joinChallenge(_ challenge: Challenge) {
        // Join challenge logic
        print("Joined challenge: \(challenge.title)")
    }
    
    func updateChallengeProgress(_ challengeId: UUID, progress: Double) {
        if let index = activeChallenges.firstIndex(where: { $0.id == challengeId }) {
            activeChallenges[index].progress = progress
            
            if progress >= 1.0 {
                completeChallenge(activeChallenges[index])
            }
        }
    }
    
    private func completeChallenge(_ challenge: Challenge) {
        var completedChallenge = challenge
        completedChallenge.isCompleted = true
        completedChallenges.append(completedChallenge)
        
        // Award rewards
        awardPoints(challenge.reward.points)
        if let badge = challenge.reward.badge {
            awardBadge(badge)
        }
        
        // Remove from active
        activeChallenges.removeAll { $0.id == challenge.id }
        
        // Update stats
        userStats.challengesCompleted += 1
    }
    
    // MARK: - Points & Rewards
    
    func awardPoints(_ points: Int, reason: String = "") {
        userStats.totalPoints += points
        
        // Check for level up
        let newLevel = (userStats.totalPoints / 1000) + 1
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
                updateChallengeProgress(challenge.id, progress: min(challenge.progress + 0.1, 1.0))
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
    
    // MARK: - Mock Data
    
    private func loadMockData() {
        // Set user stats
        userStats = UserGameStats(
            totalPoints: 3250,
            level: 4,
            currentStreak: 5,
            longestStreak: 12,
            challengesCompleted: 8,
            recipesCreated: 47,
            perfectRecipes: 12,
            badges: [],
            weeklyRank: 156,
            globalRank: 2847
        )
        
        // Active challenges
        activeChallenges = [
            Challenge(
                type: .daily,
                title: "Speed Chef",
                description: "Create 3 recipes in under 30 minutes total",
                requirement: "0/3 recipes",
                reward: ChallengeReward(
                    points: 100,
                    badge: "Speedy",
                    title: "Speed Demon",
                    unlockable: nil
                ),
                endDate: Date().addingTimeInterval(86400), // 24 hours
                participants: 1284,
                progress: 0.33
            ),
            Challenge(
                type: .weekly,
                title: "Healthy Week",
                description: "Create 10 recipes under 500 calories",
                requirement: "4/10 recipes",
                reward: ChallengeReward(
                    points: 500,
                    badge: "Health Guru",
                    title: "Nutrition Master",
                    unlockable: "Green theme"
                ),
                endDate: Date().addingTimeInterval(604800), // 7 days
                participants: 5672,
                progress: 0.4
            ),
            Challenge(
                type: .special,
                title: "Halloween Special 🎃",
                description: "Create spooky-themed recipes",
                requirement: "2/5 recipes",
                reward: ChallengeReward(
                    points: 1000,
                    badge: "Spooky Chef",
                    title: "Halloween Master",
                    unlockable: "Halloween stickers"
                ),
                endDate: Date().addingTimeInterval(259200), // 3 days
                participants: 12847,
                progress: 0.4
            ),
            Challenge(
                type: .community,
                title: "Global Cook-Off",
                description: "Community goal: 1M recipes this month",
                requirement: "847,293/1,000,000",
                reward: ChallengeReward(
                    points: 2000,
                    badge: "Community Hero",
                    title: "Global Champion",
                    unlockable: "Exclusive recipe pack"
                ),
                endDate: Date().addingTimeInterval(1296000), // 15 days
                participants: 45892,
                progress: 0.847
            )
        ]
        
        // Leaderboard data
        weeklyLeaderboard = generateMockLeaderboard(count: 100, includeUser: true, userRank: 156)
        globalLeaderboard = generateMockLeaderboard(count: 100, includeUser: true, userRank: 2847)
        
        // Unlocked badges
        unlockedBadges = [
            GameBadge(
                name: "First Recipe",
                icon: "star.fill",
                description: "Created your first recipe",
                rarity: .common,
                unlockedDate: Date().addingTimeInterval(-864000)
            ),
            GameBadge(
                name: "Week Warrior",
                icon: "flame.fill",
                description: "7-day streak achieved",
                rarity: .rare,
                unlockedDate: Date().addingTimeInterval(-172800)
            ),
            GameBadge(
                name: "Social Butterfly",
                icon: "person.3.fill",
                description: "Shared 10 recipes",
                rarity: .rare,
                unlockedDate: Date().addingTimeInterval(-432000)
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
                    points: max(10000 - (i * 50), 100),
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
            type: .daily,
            title: "Quick Chef",
            description: "Create a recipe in under 5 minutes",
            requirement: "Time limit challenge",
            reward: ChallengeReward(
                points: 100,
                badge: nil,
                title: "Speedy",
                unlockable: nil
            ),
            endDate: Date().addingTimeInterval(86400),
            participants: 523,
            progress: 0
        )
    }
}