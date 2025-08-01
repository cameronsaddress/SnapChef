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
 - timestamp: Date/Time (Indexed, Sortable)
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
 - timestamp: Date/Time (Indexed, Sortable)
 - balance: Int64
 - challengeID: String
 - itemPurchased: String
 
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
    static let challengeRecordType = "Challenge"
    static let userChallengeRecordType = "UserChallenge"
    static let teamRecordType = "Team"
    static let teamMessageRecordType = "TeamMessage"
    static let leaderboardRecordType = "Leaderboard"
    static let achievementRecordType = "Achievement"
    static let coinTransactionRecordType = "CoinTransaction"
    
    // Zone Names
    static let challengesZone = "ChallengesZone"
    static let userDataZone = "UserDataZone"
    
    // Subscription IDs
    static let challengeUpdatesSubscription = "challenge-updates"
    static let teamMessagesSubscription = "team-messages"
    static let leaderboardUpdatesSubscription = "leaderboard-updates"
    static let userProgressSubscription = "user-progress"
}

// MARK: - CloudKit Field Names
struct CKField {
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
        static let proofImageURL = "proofImageURL"
        static let notes = "notes"
        static let teamID = "teamID"
    }
    
    // Team Fields
    struct Team {
        static let id = "id"
        static let name = "name"
        static let description = "description"
        static let captainID = "captainID"
        static let memberIDs = "memberIDs"
        static let challengeID = "challengeID"
        static let totalPoints = "totalPoints"
        static let createdAt = "createdAt"
        static let inviteCode = "inviteCode"
        static let isPublic = "isPublic"
        static let maxMembers = "maxMembers"
    }
    
    // TeamMessage Fields
    struct TeamMessage {
        static let teamID = "teamID"
        static let senderID = "senderID"
        static let senderName = "senderName"
        static let message = "message"
        static let timestamp = "timestamp"
        static let type = "type"
    }
    
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