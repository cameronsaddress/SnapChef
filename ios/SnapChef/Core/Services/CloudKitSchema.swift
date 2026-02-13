import Foundation
import CloudKit

// MARK: - CloudKit Schema Documentation
// This file documents the CloudKit schema for the SnapChef challenge system.
// These record types need to be created in the CloudKit Dashboard:
// https://icloud.developer.apple.com

/*
 IMPORTANT: CloudKit Schema Setup Instructions
 
 1. Go to CloudKit Dashboard
 2. Select the SnapChef container (iCloud.com.snapchefapp.app)
 3. Create the following Record Types with their fields:
 
 === RECORD TYPE: User ===
 Fields:
 - recordName: String (use provider ID as unique identifier)
 - username: String (Indexed, Queryable, Unique) // Lowercase, 3-20 chars
 - displayName: String
 - email: String
 - profileImageURL: String
 - authProvider: String (Indexed) // "apple", "google", "facebook"
 - totalPoints: Int64 (Indexed, Sortable)
 - currentStreak: Int64
 - longestStreak: Int64
 - challengesCompleted: Int64
 - recipesShared: Int64
 - recipesCreated: Int64
 - coinBalance: Int64
 - followerCount: Int64 (Indexed, Sortable)
 - followingCount: Int64 (Indexed, Sortable)
 - isVerified: Int64 // 0 or 1
 - isProfilePublic: Int64 // 0 or 1
 - showOnLeaderboard: Int64 // 0 or 1
 - subscriptionTier: String // "free", "basic", "premium"
 - createdAt: Date/Time (Indexed, Sortable)
 - lastLoginAt: Date/Time (Indexed, Sortable)
 - lastActiveAt: Date/Time (Indexed, Sortable)
 
 === RECORD TYPE: Challenge ===
 Fields:
 - id: String (Indexed, Queryable, Sortable)
 - title: String (Queryable)
 - description: String
 - type: String (Indexed, Queryable) // "daily", "weekly", "special", "premium"
 - category: String (Indexed, Queryable) // "cooking", "social", "creative", "exploration"
 - difficulty: Int64 (Indexed, Queryable) // 1-5
 - points: Int64
 - coins: Int64
 - requirements: String (JSON)
 - startDate: Date/Time (Indexed, Queryable, Sortable)
 - endDate: Date/Time (Indexed, Queryable, Sortable)
 - isActive: Int64 (Indexed, Queryable) // 0 or 1
 - isPremium: Int64 (Indexed, Queryable) // 0 or 1
 - participantCount: Int64
 - completionCount: Int64
 - imageURL: String
 - badgeID: String
 - teamBased: Int64 // 0 or 1
 - minTeamSize: Int64
 - maxTeamSize: Int64
 
 === RECORD TYPE: UserChallenge ===
 Fields:
 - userID: String (Indexed, Queryable)
 - challengeID: Reference (Challenge) (Indexed, Queryable)
 - status: String (Indexed, Queryable) // "active", "completed", "failed"
 - progress: Double // 0.0 to 1.0
 - startedAt: Date/Time (Indexed, Sortable)
 - completedAt: Date/Time (Indexed, Sortable)
 - earnedPoints: Int64
 - earnedCoins: Int64
 - proofImage: Asset
 - proofImageURL: String
 - notes: String
 - teamID: String (Indexed, Queryable)
 
 === RECORD TYPE: Team ===
 Fields:
 - id: String (Indexed, Queryable)
 - name: String (Queryable)
 - description: String
 - captainID: String (Indexed)
 - memberIDs: String List
 - challengeID: Reference (Challenge) (Indexed, Queryable)
 - totalPoints: Int64 (Sortable)
 - createdAt: Date/Time (Indexed, Sortable)
 - inviteCode: String (Indexed, Queryable)
 - isPublic: Int64 // 0 or 1
 - maxMembers: Int64
 
 === RECORD TYPE: TeamMessage ===
 Fields:
 - teamID: String (Indexed, Queryable)
 - senderID: String (Indexed)
 - senderName: String
 - message: String
 - timestamp: Date/Time (Indexed, Sortable, Queryable)
 - type: String // "text", "achievement", "completion"
 
 === RECORD TYPE: Leaderboard ===
 Fields:
 - userID: String (Indexed, Queryable)
 - userName: String
 - avatarURL: String
 - totalPoints: Int64 (Indexed, Sortable)
 - weeklyPoints: Int64 (Indexed, Sortable)
 - monthlyPoints: Int64 (Indexed, Sortable)
 - challengesCompleted: Int64
 - currentStreak: Int64
 - longestStreak: Int64
 - lastUpdated: Date/Time (Indexed, Sortable)
 - region: String (Indexed, Queryable) // For regional leaderboards
 
 === RECORD TYPE: Achievement ===
 Fields:
 - id: String (Indexed, Queryable)
 - userID: String (Indexed, Queryable)
 - type: String (Indexed, Queryable)
 - name: String
 - description: String
 - iconName: String
 - earnedAt: Date/Time (Indexed, Sortable)
 - rarity: String // "common", "rare", "epic", "legendary"
 - associatedChallengeID: String
 
 === RECORD TYPE: CoinTransaction ===
 Fields:
 - userID: String (Indexed, Queryable)
 - amount: Int64
 - type: String (Indexed) // "earned", "spent", "bonus"
 - reason: String
 - timestamp: Date/Time (Indexed, Sortable, Queryable)
 - balance: Int64
 - challengeID: String
 - itemPurchased: String

 === RECORD TYPE: Activity ===
 Fields:
 - id: String (Indexed, Queryable)
 - type: String (Indexed, Queryable) // "follow", "recipeShared", "recipeLiked", "recipeComment", "challengeCompleted", "badgeEarned"
 - actorID: String (Indexed, Queryable) // User who performed the action
 - actorName: String
 - targetUserID: String (Indexed, Queryable) // User affected by the action (if applicable)
 - targetUserName: String
 - recipeID: String (Indexed, Queryable) // Recipe involved (if applicable)
 - recipeName: String
 - recipeImageURL: String
 - challengeID: String (Indexed, Queryable) // Challenge involved (if applicable)
 - challengeName: String
 - badgeID: String // Badge earned (if applicable)
 - badgeName: String
 - timestamp: Date/Time (Indexed, Sortable, Queryable)
 - isRead: Int64 // 0 or 1, for the target user
 - metadata: String // JSON for additional data
 
 === RECORD TYPE: Follow ===
 Fields:
 - followerID: String (Indexed, Queryable)
 - followingID: String (Indexed, Queryable)
 - followedAt: Date/Time (Indexed, Sortable)
 - isActive: Int64 // 0 or 1 (for soft delete)
 
 === RECORD TYPE: RecipeLike ===
 Fields:
 - userID: String (Indexed, Queryable)
 - recipeID: String (Indexed, Queryable)
 - likedAt: Date/Time (Indexed, Sortable)
 - recipeOwnerID: String (Indexed, Queryable)
 
 === RECORD TYPE: RecipeView ===
 Fields:
 - userID: String (Indexed, Queryable) // Can be null for anonymous views
 - recipeID: String (Indexed, Queryable)
 - viewedAt: Date/Time (Indexed, Sortable)
 - viewDuration: Int64 // in seconds
 - recipeOwnerID: String (Indexed, Queryable)
 - source: String // "feed", "search", "profile", "challenge", "deeplink"
 
 === RECORD TYPE: RecipeComment ===
 Fields:
 - id: String (Indexed, Queryable)
 - userID: String (Indexed, Queryable)
 - recipeID: String (Indexed, Queryable)
 - content: String
 - createdAt: Date/Time (Indexed, Sortable)
 - editedAt: Date/Time
 - isDeleted: Int64 // 0 or 1 (soft delete)
 - parentCommentID: String // for threaded comments
 - likeCount: Int64 (Sortable)
 
 === RECORD TYPE: Recipe ===
 Fields:
 - id: String (Indexed, Queryable)
 - ownerID: String (Indexed, Queryable)
 - title: String (Queryable)
 - description: String
 - imageURL: String
 - beforePhotoAsset: Asset // CKAsset for fridge photo
 - afterPhotoAsset: Asset // CKAsset for completed meal photo
 - createdAt: Date/Time (Indexed, Sortable)
 - likeCount: Int64 (Indexed, Sortable)
 - commentCount: Int64 (Indexed, Sortable)
 - viewCount: Int64 (Indexed, Sortable)
 - shareCount: Int64 (Indexed, Sortable)
 - challengeID: String (Indexed, Queryable) // if created for a challenge
 - isPublic: Int64 // 0 or 1
 - ingredients: String (JSON array)
 - instructions: String (JSON array)
 - cookingTime: Int64 // in minutes
 - difficulty: String // "easy", "medium", "hard"
 - cuisine: String (Indexed, Queryable)
 - isDetectiveRecipe: Int64 // 0 or 1 (enhanced for Detective recipes)
 - cookingTechniques: String List // Detective recipe enhancement
 - flavorProfile: String (JSON) // Detective recipe enhancement
 - secretIngredients: String List // Detective recipe enhancement
 - proTips: String List // Detective recipe enhancement
 - visualClues: String List // Detective recipe enhancement
 - shareCaption: String // Detective recipe enhancement
 
 === SUBSCRIPTIONS TO CREATE ===
 1. Challenge Updates - Subscribe to Challenge record changes
 2. Team Messages - Subscribe to TeamMessage for user's teams
 3. Leaderboard Updates - Subscribe to top 100 Leaderboard changes
 4. User Challenge Progress - Subscribe to UserChallenge for current user
 
 === INDEXES TO CREATE ===
 1. Challenge.startDate + Challenge.isActive (for active challenges query)
 2. UserChallenge.userID + UserChallenge.status (for user's active challenges)
 3. Leaderboard.totalPoints (for global leaderboard)
 4. Leaderboard.weeklyPoints (for weekly leaderboard)
 5. Team.challengeID + Team.totalPoints (for challenge-specific team rankings)
 */

// MARK: - CloudKit Configuration
struct CloudKitConfig {
    static let containerIdentifier = "iCloud.com.snapchefapp.app"

    // Record Types
    static let userRecordType = "User"
    // static let userProfileRecordType = "UserProfile"  // REMOVED: Use userRecordType instead
    static let challengeRecordType = "Challenge"
    static let userChallengeRecordType = "UserChallenge"
    static let teamRecordType = "Team"
    static let teamMessageRecordType = "TeamMessage"
    static let leaderboardRecordType = "Leaderboard"
    static let achievementRecordType = "Achievement"
    static let coinTransactionRecordType = "CoinTransaction"

    // Social Record Types
    static let followRecordType = "Follow"
    static let recipeLikeRecordType = "RecipeLike"
    static let recipeViewRecordType = "RecipeView"
    static let recipeCommentRecordType = "RecipeComment"
    static let recipeRecordType = "Recipe"
    static let savedRecipeRecordType = "SavedRecipe"
    static let activityRecordType = "Activity"

    // Zone Names
    static let challengesZone = "ChallengesZone"
    static let userDataZone = "UserDataZone"

    // Subscription IDs
    static let challengeUpdatesSubscription = "challenge-updates"
    static let teamMessagesSubscription = "team-messages"
    static let leaderboardUpdatesSubscription = "leaderboard-updates"
    static let userProgressSubscription = "user-progress"
}

enum CloudKitRuntimeSupport {
    private static let disableOnSimulatorEnvKey = "SNAPCHEF_DISABLE_CLOUDKIT_ON_SIMULATOR"
    private static let enableOnSimulatorEnvKey = "SNAPCHEF_ENABLE_CLOUDKIT_ON_SIMULATOR"
    private static let disableAllEnvKey = "SNAPCHEF_DISABLE_CLOUDKIT"
    private static let fallbackContainerIdentifier = "iCloud.com.snapchefapp.app"

    static var resolvedContainerIdentifier: String {
        let configured = CloudKitConfig.containerIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if configured.isEmpty {
            return fallbackContainerIdentifier
        }
        return configured
    }

    static var hasCloudKitEntitlement: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment[disableAllEnvKey] == "1" {
            return false
        }
#if targetEnvironment(simulator)
        if environment[disableOnSimulatorEnvKey] == "1" {
            return false
        }
        // In Simulator, default to enabled so social/CloudKit features work out of the box.
        // If you're building without code signing (e.g. `CODE_SIGNING_ALLOWED=NO`) and hit a
        // CloudKit SIGTRAP, set `SNAPCHEF_DISABLE_CLOUDKIT_ON_SIMULATOR=1`.
        if environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil {
            // Avoid CloudKit during tests unless explicitly enabled for an integration run.
            return environment[enableOnSimulatorEnvKey] == "1"
        }
        return true
#else
        return true
#endif
    }

    static func makeContainer(identifier: String? = nil) -> CKContainer? {
        guard hasCloudKitEntitlement else {
            return nil
        }

        #if targetEnvironment(simulator)
        // On simulator, always use the default container (derived from entitlements).
        return CKContainer.default()
        #else
        let trimmedIdentifier = identifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveIdentifier: String
        if let trimmedIdentifier, !trimmedIdentifier.isEmpty {
            effectiveIdentifier = trimmedIdentifier
        } else {
            effectiveIdentifier = resolvedContainerIdentifier
        }
        return CKContainer(identifier: effectiveIdentifier)
        #endif
    }

    static var diagnostics: (hasEntitlement: Bool, mode: String) {
        #if targetEnvironment(simulator)
        let mode = hasCloudKitEntitlement ? "simulator-enabled" : "simulator-disabled"
        #else
        let mode = "device-entitled"
        #endif
        return (
            hasEntitlement: hasCloudKitEntitlement,
            mode: mode
        )
    }

    static func logDiagnosticsIfNeeded() {
        #if DEBUG
        let info = diagnostics
        if !info.hasEntitlement {
            print("⚠️ CloudKit runtime disabled (\(info.mode)). Running in local-only mode.")
        }
        #else
        _ = diagnostics
        #endif
    }
}

// MARK: - CloudKit Field Names
struct CKField {
    // User Fields - EXACT production field names from CloudKit (v4.0 Schema)
    struct User {
        // Authentication
        static let authProvider = "authProvider"
        static let appleUserId = "appleUserId"  // NEW: Store Apple Sign In ID
        static let tiktokUserId = "tiktokUserId"  // NEW: Store TikTok ID
        static let userID = "userID"  // This is a regular field in production
        static let username = "username"
        static let email = "email"
        
        // Profile
        static let displayName = "displayName"
        static let bio = "bio"
        static let profileImageURL = "profileImageURL"
        static let profilePictureAsset = "profilePictureAsset"  // NEW: Store actual photo
        
        // Timestamps
        static let createdAt = "createdAt"
        static let lastActiveAt = "lastActiveAt"
        static let lastLoginAt = "lastLoginAt"
        
        // Gamification & Points
        static let totalPoints = "totalPoints"
        static let currentStreak = "currentStreak"
        static let longestStreak = "longestStreak"
        static let challengesCompleted = "challengesCompleted"  // NOW QUERYABLE SORTABLE
        static let coinBalance = "coinBalance"
        
        // Recipe Stats
        static let recipesShared = "recipesShared"  // NOW QUERYABLE SORTABLE
        static let recipesCreated = "recipesCreated"  // NOW QUERYABLE SORTABLE
        static let recipeSaveCount = "recipeSaveCount"  // NEW v4.0: Total saves of user's recipes
        static let recipeLikeCount = "recipeLikeCount"  // NEW v4.0: Total likes on user's recipes
        static let recipeViewCount = "recipeViewCount"  // NEW v4.0: Total views on user's recipes
        
        // Social Stats
        static let followerCount = "followerCount"  // QUERYABLE SORTABLE
        static let followingCount = "followingCount"  // NOW QUERYABLE SORTABLE (fixed in v4.0)
        
        // Activity Tracking (NEW v4.0)
        static let activityCount = "activityCount"  // NEW v4.0: Total activities
        static let lastActivityAt = "lastActivityAt"  // NEW v4.0: Last activity timestamp
        
        // Challenges & Teams (NEW v4.0)
        static let joinedChallenges = "joinedChallenges"  // NEW v4.0: Number of challenges joined
        static let completedChallenges = "completedChallenges"  // NEW v4.0: Number of challenges completed
        static let teamMemberships = "teamMemberships"  // NEW v4.0: Number of teams joined
        static let achievementCount = "achievementCount"  // NEW v4.0: Total achievements earned
        
        // Settings & Permissions
        static let isVerified = "isVerified"
        static let isProfilePublic = "isProfilePublic"
        static let showOnLeaderboard = "showOnLeaderboard"
        static let subscriptionTier = "subscriptionTier"
    }

    // Challenge Fields
    struct Challenge {
        static let id = "id"
        static let title = "title"
        static let description = "description"
        static let type = "type"
        static let category = "category"
        static let difficulty = "difficulty"
        static let points = "points"
        static let coins = "coins"
        static let requirements = "requirements"
        static let startDate = "startDate"
        static let endDate = "endDate"
        static let isActive = "isActive"
        static let isPremium = "isPremium"
        static let participantCount = "participantCount"
        static let completionCount = "completionCount"
        static let imageURL = "imageURL"
        static let badgeID = "badgeID"
        static let teamBased = "teamBased"
        static let minTeamSize = "minTeamSize"
        static let maxTeamSize = "maxTeamSize"
    }

    // UserChallenge Fields
    struct UserChallenge {
        static let userID = "userID"
        static let challengeID = "challengeID"
        static let status = "status"
        static let progress = "progress"
        static let startedAt = "startedAt"
        static let completedAt = "completedAt"
        static let earnedPoints = "earnedPoints"
        static let earnedCoins = "earnedCoins"
        static let proofImage = "proofImage"
        static let proofImageURL = "proofImageURL"
        static let notes = "notes"
        static let teamID = "teamID"
    }

    // Team Fields

    // Leaderboard Fields
    struct Leaderboard {
        static let userID = "userID"
        static let userName = "userName"
        static let avatarURL = "avatarURL"
        static let totalPoints = "totalPoints"
        static let weeklyPoints = "weeklyPoints"
        static let monthlyPoints = "monthlyPoints"
        static let challengesCompleted = "challengesCompleted"
        static let currentStreak = "currentStreak"
        static let longestStreak = "longestStreak"
        static let lastUpdated = "lastUpdated"
        static let region = "region"
    }

    // Achievement Fields
    struct Achievement {
        static let id = "id"
        static let userID = "userID"
        static let type = "type"
        static let name = "name"
        static let description = "description"
        static let iconName = "iconName"
        static let earnedAt = "earnedAt"
        static let rarity = "rarity"
        static let associatedChallengeID = "associatedChallengeID"
    }

    // CoinTransaction Fields
    struct CoinTransaction {
        static let userID = "userID"
        static let amount = "amount"
        static let type = "type"
        static let reason = "reason"
        static let timestamp = "timestamp"
        static let balance = "balance"
        static let challengeID = "challengeID"
        static let itemPurchased = "itemPurchased"
    }

    // Follow Fields
    struct Follow {
        static let followerID = "followerID"
        static let followingID = "followingID"
        static let followedAt = "followedAt"
        static let isActive = "isActive"
    }

    // RecipeLike Fields
    struct RecipeLike {
        static let userID = "userID"
        static let recipeID = "recipeID"
        static let likedAt = "likedAt"
        static let recipeOwnerID = "recipeOwnerID"
    }

    // RecipeView Fields
    struct RecipeView {
        static let userID = "userID"
        static let recipeID = "recipeID"
        static let viewedAt = "viewedAt"
        static let viewDuration = "viewDuration"
        static let recipeOwnerID = "recipeOwnerID"
        static let source = "source"
    }

    // RecipeComment Fields
    struct RecipeComment {
        static let id = "id"
        static let userID = "userID"
        static let recipeID = "recipeID"
        static let content = "content"
        static let createdAt = "createdAt"
        static let editedAt = "editedAt"
        static let isDeleted = "isDeleted"
        static let parentCommentID = "parentCommentID"
        static let likeCount = "likeCount"
    }

    // Recipe Fields
    struct Recipe {
        static let id = "id"
        static let ownerID = "ownerID"
        static let title = "title"
        static let description = "description"
        static let imageURL = "imageURL"
        static let beforePhotoAsset = "beforePhotoAsset"
        static let afterPhotoAsset = "afterPhotoAsset"
        static let createdAt = "createdAt"
        static let likeCount = "likeCount"
        static let commentCount = "commentCount"
        static let viewCount = "viewCount"
        static let shareCount = "shareCount"
        static let challengeID = "challengeID"
        static let isPublic = "isPublic"
        static let ingredients = "ingredients"
        static let instructions = "instructions"
        static let cookingTime = "cookingTime"
        static let difficulty = "difficulty"
        static let cuisine = "cuisine"
        
        // Detective recipe enhancement fields
        static let isDetectiveRecipe = "isDetectiveRecipe"
        static let cookingTechniques = "cookingTechniques"
        static let flavorProfile = "flavorProfile"
        static let secretIngredients = "secretIngredients"
        static let proTips = "proTips"
        static let visualClues = "visualClues"
        static let shareCaption = "shareCaption"
    }

    // SavedRecipe Fields
    struct SavedRecipe {
        static let userID = "userID"
        static let recipeID = "recipeID"
        static let savedAt = "savedAt"
    }

    // Activity Fields
    struct Activity {
        static let id = "id"
        static let type = "type" // follow, recipeShared, recipeLiked, recipeComment, challengeCompleted, badgeEarned
        static let actorID = "actorID" // User who performed the action
        static let actorName = "actorName"
        static let targetUserID = "targetUserID" // User affected by the action (if applicable)
        static let targetUserName = "targetUserName"
        static let recipeID = "recipeID" // Recipe involved (if applicable)
        static let recipeName = "recipeName"
        static let recipeImageURL = "recipeImageURL"
        static let challengeID = "challengeID" // Challenge involved (if applicable)
        static let challengeName = "challengeName"
        static let badgeID = "badgeID" // Badge earned (if applicable)
        static let badgeName = "badgeName"
        static let timestamp = "timestamp"
        static let isRead = "isRead" // For the target user
        static let metadata = "metadata" // JSON for additional data
    }
}

// MARK: - Sample CloudKit Operations (for reference)
extension CloudKitConfig {
    // Example: How to create a challenge record
    static func createSampleChallengeRecord() -> CKRecord {
        let record = CKRecord(recordType: challengeRecordType)
        record[CKField.Challenge.id] = UUID().uuidString
        record[CKField.Challenge.title] = "Weekly Pasta Master"
        record[CKField.Challenge.description] = "Create 3 different pasta dishes this week"
        record[CKField.Challenge.type] = "weekly"
        record[CKField.Challenge.category] = "cooking"
        record[CKField.Challenge.difficulty] = 3
        record[CKField.Challenge.points] = 500
        record[CKField.Challenge.coins] = 50
        record[CKField.Challenge.startDate] = Date()
        record[CKField.Challenge.endDate] = Date().addingTimeInterval(7 * 24 * 60 * 60)
        record[CKField.Challenge.isActive] = 1
        record[CKField.Challenge.isPremium] = 0
        record[CKField.Challenge.teamBased] = 0
        return record
    }

    // Example: How to query active challenges
    static func activeChallengePredicate() -> NSPredicate {
        return NSPredicate(format: "%K == %d AND %K <= %@ AND %K >= %@",
                          CKField.Challenge.isActive, 1,
                          CKField.Challenge.startDate, Date() as NSDate,
                          CKField.Challenge.endDate, Date() as NSDate)
    }
}
