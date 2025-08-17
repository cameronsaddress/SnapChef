import Foundation
import CloudKit

// MARK: - Social Models
struct FollowRelation {
    let followerID: String
    let followingID: String
    let followedAt: Date
    let isActive: Bool

    init(followerID: String, followingID: String, followedAt: Date = Date(), isActive: Bool = true) {
        self.followerID = followerID
        self.followingID = followingID
        self.followedAt = followedAt
        self.isActive = isActive
    }

    init(from record: CKRecord) {
        followerID = record[CKField.Follow.followerID] as? String ?? ""
        followingID = record[CKField.Follow.followingID] as? String ?? ""
        followedAt = record[CKField.Follow.followedAt] as? Date ?? Date()
        isActive = (record[CKField.Follow.isActive] as? Int64 ?? 1) == 1
    }

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CloudKitConfig.followRecordType)
        record[CKField.Follow.followerID] = followerID
        record[CKField.Follow.followingID] = followingID
        record[CKField.Follow.followedAt] = followedAt
        record[CKField.Follow.isActive] = isActive ? Int64(1) : Int64(0)
        return record
    }
}

struct RecipeLike {
    let userID: String
    let recipeID: String
    let likedAt: Date
    let recipeOwnerID: String

    init(userID: String, recipeID: String, recipeOwnerID: String, likedAt: Date = Date()) {
        self.userID = userID
        self.recipeID = recipeID
        self.recipeOwnerID = recipeOwnerID
        self.likedAt = likedAt
    }

    init(from record: CKRecord) {
        userID = record[CKField.RecipeLike.userID] as? String ?? ""
        recipeID = record[CKField.RecipeLike.recipeID] as? String ?? ""
        recipeOwnerID = record[CKField.RecipeLike.recipeOwnerID] as? String ?? ""
        likedAt = record[CKField.RecipeLike.likedAt] as? Date ?? Date()
    }

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CloudKitConfig.recipeLikeRecordType)
        record[CKField.RecipeLike.userID] = userID
        record[CKField.RecipeLike.recipeID] = recipeID
        record[CKField.RecipeLike.recipeOwnerID] = recipeOwnerID
        record[CKField.RecipeLike.likedAt] = likedAt
        return record
    }
}

struct RecipeView {
    let userID: String?
    let recipeID: String
    let viewedAt: Date
    let viewDuration: Int
    let recipeOwnerID: String
    let source: String

    init(userID: String?, recipeID: String, recipeOwnerID: String, viewDuration: Int = 0, source: String = "feed") {
        self.userID = userID
        self.recipeID = recipeID
        self.recipeOwnerID = recipeOwnerID
        self.viewedAt = Date()
        self.viewDuration = viewDuration
        self.source = source
    }

    init(from record: CKRecord) {
        userID = record[CKField.RecipeView.userID] as? String
        recipeID = record[CKField.RecipeView.recipeID] as? String ?? ""
        viewedAt = record[CKField.RecipeView.viewedAt] as? Date ?? Date()
        viewDuration = Int(record[CKField.RecipeView.viewDuration] as? Int64 ?? 0)
        recipeOwnerID = record[CKField.RecipeView.recipeOwnerID] as? String ?? ""
        source = record[CKField.RecipeView.source] as? String ?? "unknown"
    }

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CloudKitConfig.recipeViewRecordType)
        record[CKField.RecipeView.userID] = userID ?? ""
        record[CKField.RecipeView.recipeID] = recipeID
        record[CKField.RecipeView.viewedAt] = viewedAt
        record[CKField.RecipeView.viewDuration] = Int64(viewDuration)
        record[CKField.RecipeView.recipeOwnerID] = recipeOwnerID
        record[CKField.RecipeView.source] = source
        return record
    }
}

struct RecipeComment {
    let id: String
    let userID: String
    let recipeID: String
    let content: String
    let createdAt: Date
    var editedAt: Date?
    let isDeleted: Bool
    let parentCommentID: String?
    var likeCount: Int

    init(id: String = UUID().uuidString, userID: String, recipeID: String, content: String, parentCommentID: String? = nil) {
        self.id = id
        self.userID = userID
        self.recipeID = recipeID
        self.content = content
        self.createdAt = Date()
        self.editedAt = nil
        self.isDeleted = false
        self.parentCommentID = parentCommentID
        self.likeCount = 0
    }

    init(from record: CKRecord) {
        id = record[CKField.RecipeComment.id] as? String ?? UUID().uuidString
        userID = record[CKField.RecipeComment.userID] as? String ?? ""
        recipeID = record[CKField.RecipeComment.recipeID] as? String ?? ""
        content = record[CKField.RecipeComment.content] as? String ?? ""
        createdAt = record[CKField.RecipeComment.createdAt] as? Date ?? Date()
        editedAt = record[CKField.RecipeComment.editedAt] as? Date
        isDeleted = (record[CKField.RecipeComment.isDeleted] as? Int64 ?? 0) == 1
        parentCommentID = record[CKField.RecipeComment.parentCommentID] as? String
        likeCount = Int(record[CKField.RecipeComment.likeCount] as? Int64 ?? 0)
    }

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CloudKitConfig.recipeCommentRecordType)
        record[CKField.RecipeComment.id] = id
        record[CKField.RecipeComment.userID] = userID
        record[CKField.RecipeComment.recipeID] = recipeID
        record[CKField.RecipeComment.content] = content
        record[CKField.RecipeComment.createdAt] = createdAt
        record[CKField.RecipeComment.editedAt] = editedAt
        record[CKField.RecipeComment.isDeleted] = isDeleted ? Int64(1) : Int64(0)
        record[CKField.RecipeComment.parentCommentID] = parentCommentID
        record[CKField.RecipeComment.likeCount] = Int64(likeCount)
        return record
    }
}

// MARK: - Helper Models
struct UserChallenge {
    let userID: String
    let challengeID: String
    let status: String
    let progress: Double
    let startedAt: Date
    var completedAt: Date?
    let earnedPoints: Int
    let earnedCoins: Int
    var proofImageURL: String?
    var notes: String?
    var teamID: String?

    init(userID: String, challengeID: String, status: String, progress: Double, startedAt: Date, completedAt: Date? = nil, earnedPoints: Int, earnedCoins: Int, proofImageURL: String? = nil, notes: String? = nil, teamID: String? = nil) {
        self.userID = userID
        self.challengeID = challengeID
        self.status = status
        self.progress = progress
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.earnedPoints = earnedPoints
        self.earnedCoins = earnedCoins
        self.proofImageURL = proofImageURL
        self.notes = notes
        self.teamID = teamID
    }

    init(from record: CKRecord) {
        userID = record[CKField.UserChallenge.userID] as? String ?? ""
        challengeID = (record[CKField.UserChallenge.challengeID] as? CKRecord.Reference)?.recordID.recordName ?? ""
        status = record[CKField.UserChallenge.status] as? String ?? "active"
        progress = record[CKField.UserChallenge.progress] as? Double ?? 0.0
        startedAt = record[CKField.UserChallenge.startedAt] as? Date ?? Date()
        completedAt = record[CKField.UserChallenge.completedAt] as? Date
        earnedPoints = record[CKField.UserChallenge.earnedPoints] as? Int ?? 0
        earnedCoins = record[CKField.UserChallenge.earnedCoins] as? Int ?? 0
        teamID = record[CKField.UserChallenge.teamID] as? String
    }

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CloudKitConfig.userChallengeRecordType)
        record[CKField.UserChallenge.userID] = userID
        record[CKField.UserChallenge.challengeID] = CKRecord.Reference(recordID: CKRecord.ID(recordName: challengeID), action: .none)
        record[CKField.UserChallenge.status] = status
        record[CKField.UserChallenge.progress] = progress
        record[CKField.UserChallenge.startedAt] = startedAt
        record[CKField.UserChallenge.completedAt] = completedAt
        record[CKField.UserChallenge.earnedPoints] = earnedPoints
        record[CKField.UserChallenge.earnedCoins] = earnedCoins
        record[CKField.UserChallenge.teamID] = teamID
        return record
    }
}

struct Achievement {
    let id: String
    let userID: String
    let type: String
    let name: String
    let description: String
    let iconName: String
    let earnedAt: Date
    let rarity: String
    let associatedChallengeID: String?
}

struct CoinTransaction {
    let userID: String
    let amount: Int
    let type: String
    let reason: String
    let timestamp: Date
    let balance: Int
    let challengeID: String?
    let itemPurchased: String?
}

struct CloudKitLeaderboardEntry {
    let userID: String
    let userName: String
    let avatarURL: String?
    let totalPoints: Int
    let weeklyPoints: Int
    let monthlyPoints: Int
    let challengesCompleted: Int
    let currentStreak: Int

    init(from record: CKRecord) {
        userID = record[CKField.Leaderboard.userID] as? String ?? ""
        userName = record[CKField.Leaderboard.userName] as? String ?? "Anonymous"
        avatarURL = record[CKField.Leaderboard.avatarURL] as? String
        totalPoints = record[CKField.Leaderboard.totalPoints] as? Int ?? 0
        weeklyPoints = record[CKField.Leaderboard.weeklyPoints] as? Int ?? 0
        monthlyPoints = record[CKField.Leaderboard.monthlyPoints] as? Int ?? 0
        challengesCompleted = record[CKField.Leaderboard.challengesCompleted] as? Int ?? 0
        currentStreak = record[CKField.Leaderboard.currentStreak] as? Int ?? 0
    }
}

// MARK: - Team CloudKit Extension (Removed)

// MARK: - Model Extensions for CloudKit
extension Challenge {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CloudKitConfig.challengeRecordType)
        record[CKField.Challenge.id] = id
        record[CKField.Challenge.title] = title
        record[CKField.Challenge.description] = description
        record[CKField.Challenge.type] = type.rawValue
        record[CKField.Challenge.category] = category
        record[CKField.Challenge.difficulty] = difficulty.rawValue
        record[CKField.Challenge.points] = points
        record[CKField.Challenge.coins] = coins
        record[CKField.Challenge.startDate] = startDate
        record[CKField.Challenge.endDate] = endDate
        record[CKField.Challenge.isActive] = isActive ? 1 : 0
        record[CKField.Challenge.isPremium] = isPremium ? 1 : 0
        record[CKField.Challenge.participantCount] = participants
        record[CKField.Challenge.completionCount] = completions
        record[CKField.Challenge.imageURL] = imageURL
        return record
    }
}
