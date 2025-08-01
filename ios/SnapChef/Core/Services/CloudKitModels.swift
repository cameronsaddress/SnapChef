import Foundation
import CloudKit

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
    var teamID: String?
    
    init(userID: String, challengeID: String, status: String, progress: Double, startedAt: Date, completedAt: Date? = nil, earnedPoints: Int, earnedCoins: Int, teamID: String? = nil) {
        self.userID = userID
        self.challengeID = challengeID
        self.status = status
        self.progress = progress
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.earnedPoints = earnedPoints
        self.earnedCoins = earnedCoins
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

// MARK: - Team CloudKit Extension
struct CloudKitTeam {
    let team: Team
    var recordID: CKRecord.ID?
    
    func toCKRecord() -> CKRecord {
        let record = recordID != nil ? CKRecord(recordType: CloudKitConfig.teamRecordType, recordID: recordID!) 
                                     : CKRecord(recordType: CloudKitConfig.teamRecordType)
        
        record[CKField.Team.id] = team.id.uuidString
        record[CKField.Team.name] = team.name
        record[CKField.Team.description] = team.description
        record[CKField.Team.captainID] = team.captain
        record[CKField.Team.memberIDs] = team.members
        
        // Store active challenges
        if !team.activeChallenges.isEmpty {
            // For now, just store the first challenge ID
            if let firstChallenge = team.activeChallenges.first {
                record[CKField.Team.challengeID] = CKRecord.Reference(recordID: CKRecord.ID(recordName: firstChallenge), action: .none)
            }
        }
        
        record[CKField.Team.totalPoints] = team.totalPoints
        record[CKField.Team.createdAt] = team.createdAt
        record[CKField.Team.inviteCode] = UUID().uuidString // Generate invite code
        record[CKField.Team.isPublic] = team.isPublic ? 1 : 0
        record[CKField.Team.maxMembers] = team.maxMembers
        
        return record
    }
}

// MARK: - Model Extensions for CloudKit
extension Challenge {
    init?(from record: CKRecord) {
        guard let id = record[CKField.Challenge.id] as? String,
              let title = record[CKField.Challenge.title] as? String,
              let description = record[CKField.Challenge.description] as? String,
              let type = record[CKField.Challenge.type] as? String,
              let startDate = record[CKField.Challenge.startDate] as? Date,
              let endDate = record[CKField.Challenge.endDate] as? Date else { return nil }
        
        self.init(
            id: id,
            title: title,
            description: description,
            type: ChallengeType(rawValue: type) ?? .daily,
            category: record[CKField.Challenge.category] as? String ?? "cooking",
            difficulty: DifficultyLevel(rawValue: record[CKField.Challenge.difficulty] as? Int ?? 1) ?? .easy,
            points: record[CKField.Challenge.points] as? Int ?? 0,
            coins: record[CKField.Challenge.coins] as? Int ?? 0,
            startDate: startDate,
            endDate: endDate,
            requirements: [],
            currentProgress: 0,
            isCompleted: false,
            isActive: (record[CKField.Challenge.isActive] as? Int ?? 0) == 1,
            participants: record[CKField.Challenge.participantCount] as? Int ?? 0,
            completions: record[CKField.Challenge.completionCount] as? Int ?? 0,
            imageURL: record[CKField.Challenge.imageURL] as? String,
            isPremium: (record[CKField.Challenge.isPremium] as? Int ?? 0) == 1
        )
    }
    
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