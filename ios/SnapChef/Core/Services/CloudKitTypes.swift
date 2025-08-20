import Foundation
import CloudKit

// MARK: - User Types
struct CloudKitUser {
    let recordID: String?
    var username: String?
    var displayName: String
    var email: String
    var profileImageURL: String?
    var authProvider: String
    var totalPoints: Int
    var currentStreak: Int
    var longestStreak: Int
    var challengesCompleted: Int
    var recipesShared: Int
    var recipesCreated: Int
    var coinBalance: Int
    var followerCount: Int
    var followingCount: Int
    var isVerified: Bool
    var isProfilePublic: Bool
    var showOnLeaderboard: Bool
    var subscriptionTier: String
    var createdAt: Date
    var lastLoginAt: Date
    var lastActiveAt: Date
    
    init(from record: CKRecord) {
        self.recordID = record.recordID.recordName
        self.username = record[CKField.User.username] as? String
        self.displayName = record[CKField.User.displayName] as? String ?? "Anonymous Chef"
        self.email = record[CKField.User.email] as? String ?? ""
        self.profileImageURL = record[CKField.User.profileImageURL] as? String
        self.authProvider = record[CKField.User.authProvider] as? String ?? "unknown"
        self.totalPoints = Int(record[CKField.User.totalPoints] as? Int64 ?? 0)
        self.currentStreak = Int(record[CKField.User.currentStreak] as? Int64 ?? 0)
        self.longestStreak = Int(record[CKField.User.longestStreak] as? Int64 ?? 0)
        self.challengesCompleted = Int(record[CKField.User.challengesCompleted] as? Int64 ?? 0)
        self.recipesShared = Int(record[CKField.User.recipesShared] as? Int64 ?? 0)
        self.recipesCreated = Int(record[CKField.User.recipesCreated] as? Int64 ?? 0)
        self.coinBalance = Int(record[CKField.User.coinBalance] as? Int64 ?? 0)
        self.followerCount = Int(record[CKField.User.followerCount] as? Int64 ?? 0)
        self.followingCount = Int(record[CKField.User.followingCount] as? Int64 ?? 0)
        self.isVerified = (record[CKField.User.isVerified] as? Int64 ?? 0) == 1
        self.isProfilePublic = (record[CKField.User.isProfilePublic] as? Int64 ?? 1) == 1
        self.showOnLeaderboard = (record[CKField.User.showOnLeaderboard] as? Int64 ?? 1) == 1
        self.subscriptionTier = record[CKField.User.subscriptionTier] as? String ?? "free"
        self.createdAt = record[CKField.User.createdAt] as? Date ?? Date()
        self.lastLoginAt = record[CKField.User.lastLoginAt] as? Date ?? Date()
        self.lastActiveAt = record[CKField.User.lastActiveAt] as? Date ?? Date()
    }
}

struct UserStatUpdates {
    var totalPoints: Int?
    var currentStreak: Int?
    var longestStreak: Int?
    var challengesCompleted: Int?
    var recipesShared: Int?
    var recipesCreated: Int?
    var coinBalance: Int?
    var followerCount: Int?
    var followingCount: Int?
    
    init(totalPoints: Int? = nil,
         currentStreak: Int? = nil,
         longestStreak: Int? = nil,
         challengesCompleted: Int? = nil,
         recipesShared: Int? = nil,
         recipesCreated: Int? = nil,
         coinBalance: Int? = nil,
         followerCount: Int? = nil,
         followingCount: Int? = nil) {
        self.totalPoints = totalPoints
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.challengesCompleted = challengesCompleted
        self.recipesShared = recipesShared
        self.recipesCreated = recipesCreated
        self.coinBalance = coinBalance
        self.followerCount = followerCount
        self.followingCount = followingCount
    }
}

// MARK: - Recipe Types
struct SyncStats {
    let totalCloudKitRecipes: Int
    let totalLocalRecipes: Int
    let missingRecipes: Int
    let recipesWithPhotos: Int
    let recipesNeedingPhotos: Int
}

struct SyncResult {
    let newRecipesSynced: Int
    let photosDownloaded: Int
    let duration: TimeInterval
    let success: Bool
}

// MARK: - Error Types
enum CloudKitAuthError: LocalizedError {
    case notAuthenticated
    case invalidCredential
    case usernameUnavailable
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .invalidCredential:
            return "Invalid authentication credentials"
        case .usernameUnavailable:
            return "Username is already taken"
        case .networkError:
            return "Network connection error"
        }
    }
}

enum CloudKitUserError: LocalizedError {
    case notAuthenticated
    case invalidData
    case usernameTaken
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to iCloud in Settings"
        case .invalidData:
            return "Invalid data format"
        case .usernameTaken:
            return "Username is already taken"
        case .networkError:
            return "Network connection error"
        }
    }
}

enum CloudKitTeamError: LocalizedError {
    case notAuthenticated
    case invalidInviteCode
    case alreadyMember
    case teamFull
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to join a team"
        case .invalidInviteCode:
            return "Invalid invite code"
        case .alreadyMember:
            return "You're already a member of this team"
        case .teamFull:
            return "This team is full"
        }
    }
}

enum RecipeError: LocalizedError {
    case invalidRecord
    case invalidJSON
    case uploadFailed
    case invalidShareLink
    
    var errorDescription: String? {
        switch self {
        case .invalidRecord:
            return "Invalid recipe record"
        case .invalidJSON:
            return "Invalid JSON data"
        case .uploadFailed:
            return "Failed to upload recipe"
        case .invalidShareLink:
            return "Invalid share link"
        }
    }
}

// MARK: - Data Types
struct FoodPreferences: Codable {
    var dietaryRestrictions: [String]
    var allergies: [String]
    var favoriteCuisines: [String]
    var dislikedIngredients: [String]
    var cookingSkillLevel: String
    var preferredCookTime: Int
    var kitchenTools: [String]
    var mealPlanningGoals: String
}

struct CameraSessionData {
    let sessionID: String
    let captureType: String
    let flashEnabled: Bool
    let ingredientsDetected: [String]
    let recipesGenerated: Int
    let aiModel: String
    let processingTime: Double
}

struct RecipeGenerationData {
    let sessionID: String
    let recipe: Recipe
    let ingredients: [String]
    let preferencesJSON: String
    let generationTime: Double
    let quality: String
}

struct CloudKitAppError {
    let type: String
    let message: String
    let stackTrace: String?
    let context: String?
    let severity: String
}

// MARK: - User Profile Types
struct CloudKitUserProfile {
    let recordID: CKRecord.ID
    let username: String
    let userID: String
    let displayName: String
    let bio: String?
    let profileImageURL: String?
    let createdAt: Date
    let updatedAt: Date
    let isVerified: Bool
    let isPremium: Bool
    let totalPoints: Int
    let recipesShared: Int
    let followersCount: Int
    let followingCount: Int
    
    init?(from record: CKRecord) {
        guard let username = record["username"] as? String,
              let userID = record["userID"] as? String else {
            return nil
        }
        
        self.recordID = record.recordID
        self.username = username
        self.userID = userID
        self.displayName = record["displayName"] as? String ?? username
        self.bio = record["bio"] as? String
        
        if let imageAsset = record["profileImageAsset"] as? CKAsset {
            self.profileImageURL = imageAsset.fileURL?.absoluteString
        } else {
            self.profileImageURL = nil
        }
        
        self.createdAt = record["createdAt"] as? Date ?? Date()
        self.updatedAt = record["updatedAt"] as? Date ?? Date()
        self.isVerified = record["isVerified"] as? Bool ?? false
        self.isPremium = record["isPremium"] as? Bool ?? false
        self.totalPoints = record["totalPoints"] as? Int ?? 0
        self.recipesShared = record["recipesShared"] as? Int ?? 0
        self.followersCount = record["followersCount"] as? Int ?? 0
        self.followingCount = record["followingCount"] as? Int ?? 0
    }
}

// MARK: - Challenge Types
struct CloudKitUserChallenge {
    let userID: String
    let challengeID: String
    let status: String
    let progress: Double
    let startedAt: Date?
    let completedAt: Date?
    let earnedPoints: Int
    let earnedCoins: Int
}

struct CloudKitTeam {
    let id: String
    let name: String
    let description: String
    let captainID: String
    let memberIDs: [String]
    let challengeID: String
    let totalPoints: Int
    let createdAt: Date
    let inviteCode: String
    let isPublic: Bool
    let maxMembers: Int
}

// MARK: - Streak Types (placeholder)
enum StreakType: String, CaseIterable {
    case cooking = "cooking"
    case recipe = "recipe"
    case challenge = "challenge"
}

struct StreakData {
    let type: StreakType
    var currentStreak: Int
    var longestStreak: Int
    var lastActivityDate: Date
    var streakStartDate: Date
    var totalDaysActive: Int
    var frozenUntil: Date?
    var insuranceActive: Bool
    var multiplier: Double
    
    init(type: StreakType) {
        self.type = type
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastActivityDate = Date.distantPast
        self.streakStartDate = Date()
        self.totalDaysActive = 0
        self.frozenUntil = nil
        self.insuranceActive = false
        self.multiplier = 1.0
    }
}

struct StreakHistory {
    let type: StreakType
    let streakLength: Int
    let startDate: Date
    let endDate: Date
    let breakReason: StreakBreakReason?
    let wasRestored: Bool
}

enum StreakBreakReason: String {
    case missed = "missed"
    case technical = "technical"
    case vacation = "vacation"
}

struct StreakAchievement {
    let type: StreakType
    let unlockedAt: Date
    let milestoneDays: Int
    let rewardsClaimed: Bool
    let milestoneBadge: String
}

// MARK: - Missing Challenge Types (placeholder)
enum ChallengeType: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case special = "special"
    case community = "community"
}

enum DifficultyLevel: Int, CaseIterable {
    case easy = 1
    case medium = 2
    case hard = 3
    case expert = 4
    case extreme = 5
}

struct Challenge {
    let id: String
    let title: String
    let description: String
    let type: ChallengeType
    let category: String
    let difficulty: DifficultyLevel
    let points: Int
    let coins: Int
    let startDate: Date
    let endDate: Date
    let requirements: [String]
    let currentProgress: Double
    let isCompleted: Bool
    let isActive: Bool
    let isJoined: Bool
    let participants: Int
    let completions: Int
    let imageURL: String?
    let isPremium: Bool
}

// MARK: - Extensions for Challenge CloudKit Integration
extension Challenge {
    init?(from record: CKRecord) {
        guard let id = record[CKField.Challenge.id] as? String,
              let title = record[CKField.Challenge.title] as? String,
              let description = record[CKField.Challenge.description] as? String,
              let typeRaw = record[CKField.Challenge.type] as? String,
              let category = record[CKField.Challenge.category] as? String,
              let difficultyInt = record[CKField.Challenge.difficulty] as? Int64,
              let difficulty = DifficultyLevel(rawValue: Int(difficultyInt)),
              let points = record[CKField.Challenge.points] as? Int64,
              let coins = record[CKField.Challenge.coins] as? Int64,
              let startDate = record[CKField.Challenge.startDate] as? Date,
              let endDate = record[CKField.Challenge.endDate] as? Date,
              let isActiveInt = record[CKField.Challenge.isActive] as? Int64,
              let isPremiumInt = record[CKField.Challenge.isPremium] as? Int64,
              let participantCount = record[CKField.Challenge.participantCount] as? Int64,
              let completionCount = record[CKField.Challenge.completionCount] as? Int64 else {
            print("❌ Failed to parse challenge from CloudKit record")
            return nil
        }
        
        // Parse type
        let type: ChallengeType
        switch typeRaw.lowercased() {
        case "daily":
            type = .daily
        case "weekly":
            type = .weekly
        case "special":
            type = .special
        case "community":
            type = .community
        default:
            type = .daily
        }
        
        // Parse requirements from pipe-separated string
        var requirements: [String] = []
        if let requirementsString = record[CKField.Challenge.requirements] as? String {
            requirements = requirementsString.split(separator: "|").map { String($0) }
        }
        
        self.init(
            id: id,
            title: title,
            description: description,
            type: type,
            category: category,
            difficulty: difficulty,
            points: Int(points),
            coins: Int(coins),
            startDate: startDate,
            endDate: endDate,
            requirements: requirements,
            currentProgress: 0,
            isCompleted: false,
            isActive: isActiveInt == 1,
            isJoined: false,
            participants: Int(participantCount),
            completions: Int(completionCount),
            imageURL: record[CKField.Challenge.imageURL] as? String,
            isPremium: isPremiumInt == 1
        )
    }
}