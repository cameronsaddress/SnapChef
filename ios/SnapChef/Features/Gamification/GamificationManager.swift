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

// MARK: - Difficulty Level
enum DifficultyLevel: Int, CaseIterable {
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
struct Challenge: Identifiable {
    let id: String
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
    @Published var hasCheckedInToday: Bool = false
    
    private init() {
        loadMockData()
        checkDailyCheckInStatus()
        setupCloudKitSync()
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
        // Merge CloudKit challenges with local ones
        for challenge in challenges {
            if let index = activeChallenges.firstIndex(where: { $0.id == challenge.id }) {
                // Update existing challenge
                activeChallenges[index] = challenge
            } else if !completedChallenges.contains(where: { $0.id == challenge.id }) {
                // Add new challenge
                activeChallenges.append(challenge)
            }
        }
        
        // Sort by end date
        activeChallenges.sort { $0.endDate < $1.endDate }
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
    
    func updateChallengeProgress(_ challengeId: String, progress: Double) {
        if let index = activeChallenges.firstIndex(where: { $0.id == challengeId }) {
            activeChallenges[index].currentProgress = progress
            
            if progress >= 1.0 {
                completeChallenge(activeChallenges[index])
            }
            
            // Sync with CloudKit
            Task {
                await syncChallengeProgress(for: challengeId, progress: progress)
            }
        }
    }
    
    func completeChallenge(challengeId: String) {
        // Find challenge by title (used as ID in some cases)
        if let challenge = activeChallenges.first(where: { $0.title == challengeId }) {
            completeChallenge(challenge)
        }
    }
    
    private func completeChallenge(_ challenge: Challenge) {
        var completedChallenge = challenge
        completedChallenge.isCompleted = true
        completedChallenges.append(completedChallenge)
        
        // Award rewards
        awardPoints(challenge.points)
        
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
        
        // Award rewards with score
        awardPoints(score)
        
        // Remove from active
        activeChallenges.removeAll { $0.id == challenge.id }
        
        // Update stats
        userStats.challengesCompleted += 1
        
        // Save to persistent storage
        saveChallengeProgress(
            challengeId: challenge.id,
            action: "completed",
            value: 1.0,
            metadata: ["score": score]
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
        
        // Active challenges - empty initially, will be populated when user joins from HomeView
        activeChallenges = []
        
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
            title: "Quick Chef",
            description: "Create a recipe in under 5 minutes",
            type: .daily,
            endDate: Date().addingTimeInterval(86400),
            requirements: ["Time limit challenge"],
            currentProgress: 0,
            participants: 523
        )
    }
}