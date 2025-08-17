import Foundation
import CloudKit
import SwiftUI

/// Challenge module for CloudKit operations
/// Handles challenges, teams, achievements, and leaderboards
@MainActor
final class ChallengeModule: ObservableObject {
    
    // MARK: - Properties
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private weak var parent: CloudKitService?
    
    @Published var activeChallenges: [Challenge] = []
    @Published var userChallenges: [CloudKitUserChallenge] = []
    @Published var teams: [CloudKitTeam] = []
    
    // MARK: - Initialization
    init(container: CKContainer, publicDB: CKDatabase, privateDB: CKDatabase, parent: CloudKitService) {
        self.container = container
        self.publicDatabase = publicDB
        self.privateDatabase = privateDB
        self.parent = parent
        
        Task {
            await syncChallenges()
        }
    }
    
    // MARK: - Challenge Management
    func uploadChallenge(_ challenge: Challenge) async throws -> String {
        let record = CKRecord(recordType: "Challenge", recordID: CKRecord.ID(recordName: challenge.id))
        
        record["id"] = challenge.id
        record["title"] = challenge.title
        record["description"] = challenge.description
        record["type"] = challenge.type.rawValue
        record["category"] = challenge.category
        record["difficulty"] = Int64(challenge.difficulty.rawValue)
        record["points"] = Int64(challenge.points)
        record["coins"] = Int64(challenge.coins)
        record["requirements"] = try JSONEncoder().encode(challenge.requirements).base64EncodedString()
        record["startDate"] = challenge.startDate
        record["endDate"] = challenge.endDate
        record["isActive"] = challenge.isActive ? 1 : 0
        record["isPremium"] = challenge.isPremium ? 1 : 0
        record["participantCount"] = Int64(challenge.participants)
        record["completionCount"] = Int64(challenge.completions)
        record["imageURL"] = challenge.imageURL ?? ""
        record["badgeID"] = ""
        record["teamBased"] = 0
        record["minTeamSize"] = Int64(1)
        record["maxTeamSize"] = Int64(5)
        
        let savedRecord = try await publicDatabase.save(record)
        return savedRecord.recordID.recordName
    }
    
    func syncChallenges() async {
        do {
            let predicate = NSPredicate(format: "isActive == 1")
            let query = CKQuery(recordType: "Challenge", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: true)]
            
            let (matchResults, _) = try await publicDatabase.records(matching: query)
            
            var challenges: [Challenge] = []
            for (_, result) in matchResults {
                if let record = try? result.get(),
                   let challenge = parseChallengeFromRecord(record) {
                    challenges.append(challenge)
                }
            }
            
            self.activeChallenges = challenges
            print("✅ Synced \(challenges.count) active challenges from CloudKit")
        } catch {
            print("❌ Failed to sync challenges: \(error)")
        }
    }
    
    // MARK: - User Challenge Progress
    func updateUserProgress(challengeID: String, progress: Double) async throws {
        guard let userID = getCurrentUserID() else { return }
        
        let recordID = CKRecord.ID(recordName: "\(userID)_\(challengeID)")
        
        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "UserChallenge", recordID: recordID)
            record["userID"] = userID
            record["challengeID"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: challengeID), action: .none)
            record["status"] = "in_progress"
            record["startedAt"] = Date()
        }
        
        record["progress"] = progress
        
        if progress >= 1.0 {
            record["status"] = "completed"
            record["completedAt"] = Date()
            
            if let challenge = activeChallenges.first(where: { $0.id == challengeID }) {
                record["earnedPoints"] = Int64(challenge.points)
                record["earnedCoins"] = Int64(challenge.coins)
                await incrementChallengeCompletions(challengeID)
            }
        }
        
        _ = try await privateDatabase.save(record)
        print("✅ Updated progress for challenge \(challengeID): \(progress * 100)%")
    }
    
    func getUserChallengeProgress() async throws -> [CloudKitUserChallenge] {
        guard let userID = getCurrentUserID() else { return [] }
        
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "UserChallenge", predicate: predicate)
        
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        var userChallenges: [CloudKitUserChallenge] = []
        for (_, result) in matchResults {
            if let record = try? result.get() {
                let userChallenge = CloudKitUserChallenge(
                    userID: record["userID"] as? String ?? "",
                    challengeID: (record["challengeID"] as? CKRecord.Reference)?.recordID.recordName ?? "",
                    status: record["status"] as? String ?? "pending",
                    progress: record["progress"] as? Double ?? 0,
                    startedAt: record["startedAt"] as? Date,
                    completedAt: record["completedAt"] as? Date,
                    earnedPoints: Int(record["earnedPoints"] as? Int64 ?? 0),
                    earnedCoins: Int(record["earnedCoins"] as? Int64 ?? 0)
                )
                userChallenges.append(userChallenge)
            }
        }
        
        self.userChallenges = userChallenges
        return userChallenges
    }
    
    // MARK: - Team Management
    func createTeam(name: String, description: String, challengeID: String) async throws -> CloudKitTeam {
        guard let userID = getCurrentUserID() else { throw CloudKitTeamError.notAuthenticated }
        
        let teamID = UUID().uuidString
        let record = CKRecord(recordType: "Team", recordID: CKRecord.ID(recordName: teamID))
        
        record["id"] = teamID
        record["name"] = name
        record["description"] = description
        record["captainID"] = userID
        record["memberIDs"] = [userID]
        record["challengeID"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: challengeID), action: .none)
        record["totalPoints"] = Int64(0)
        record["createdAt"] = Date()
        record["inviteCode"] = generateInviteCode()
        record["isPublic"] = 1
        record["maxMembers"] = Int64(5)
        
        _ = try await publicDatabase.save(record)
        
        let team = CloudKitTeam(
            id: teamID,
            name: name,
            description: description,
            captainID: userID,
            memberIDs: [userID],
            challengeID: challengeID,
            totalPoints: 0,
            createdAt: Date(),
            inviteCode: record["inviteCode"] as? String ?? "",
            isPublic: true,
            maxMembers: 5
        )
        
        self.teams.append(team)
        return team
    }
    
    func joinTeam(inviteCode: String) async throws -> CloudKitTeam {
        guard let userID = getCurrentUserID() else { throw CloudKitTeamError.notAuthenticated }
        
        let predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
        let query = CKQuery(recordType: "Team", predicate: predicate)
        
        let (matchResults, _) = try await publicDatabase.records(matching: query)
        
        guard let record = try? matchResults.first?.1.get() else {
            throw CloudKitTeamError.invalidInviteCode
        }
        
        var memberIDs = (record["memberIDs"] as? [String]) ?? []
        let maxMembers = Int(record["maxMembers"] as? Int64 ?? 5)
        
        guard !memberIDs.contains(userID) else {
            throw CloudKitTeamError.alreadyMember
        }
        
        guard memberIDs.count < maxMembers else {
            throw CloudKitTeamError.teamFull
        }
        
        memberIDs.append(userID)
        record["memberIDs"] = memberIDs
        
        _ = try await publicDatabase.save(record)
        
        let team = parseTeamFromRecord(record)
        
        if let index = self.teams.firstIndex(where: { $0.id == team.id }) {
            self.teams[index] = team
        } else {
            self.teams.append(team)
        }
        
        return team
    }
    
    func updateTeamPoints(teamID: String, additionalPoints: Int) async throws {
        let recordID = CKRecord.ID(recordName: teamID)
        let record = try await publicDatabase.record(for: recordID)
        
        let currentPoints = Int(record["totalPoints"] as? Int64 ?? 0)
        record["totalPoints"] = Int64(currentPoints + additionalPoints)
        
        _ = try await publicDatabase.save(record)
        await notifyTeamMembers(teamID: teamID, message: "Your team earned \(additionalPoints) points!")
    }
    
    func getTeamLeaderboard(challengeID: String) async throws -> [CloudKitTeam] {
        let predicate = NSPredicate(format: "challengeID == %@", CKRecord.Reference(recordID: CKRecord.ID(recordName: challengeID), action: .none))
        let query = CKQuery(recordType: "Team", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "totalPoints", ascending: false)]
        
        let (matchResults, _) = try await publicDatabase.records(matching: query, resultsLimit: 100)
        
        var teams: [CloudKitTeam] = []
        for (_, result) in matchResults {
            if let record = try? result.get() {
                teams.append(parseTeamFromRecord(record))
            }
        }
        
        return teams
    }
    
    // MARK: - Awards and Metrics
    func trackAchievement(type: String, name: String, description: String) async throws {
        guard let userID = getCurrentUserID() else { return }
        
        let record = CKRecord(recordType: "Achievement")
        record["id"] = UUID().uuidString
        record["userID"] = userID
        record["type"] = type
        record["name"] = name
        record["description"] = description
        record["earnedAt"] = Date()
        record["rarity"] = calculateRarity(type: type)
        
        _ = try await privateDatabase.save(record)
        print("✅ Achievement tracked: \(name)")
    }
    
    func updateLeaderboard(points: Int) async throws {
        guard let userID = getCurrentUserID(),
              let userName = parent?.currentUser?.displayName else { return }
        
        let recordID = CKRecord.ID(recordName: "leaderboard_\(userID)")
        
        let record: CKRecord
        do {
            record = try await publicDatabase.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "Leaderboard", recordID: recordID)
            record["userID"] = userID
            record["userName"] = userName
        }
        
        let currentPoints = Int(record["totalPoints"] as? Int64 ?? 0)
        record["totalPoints"] = Int64(currentPoints + points)
        record["lastUpdated"] = Date()
        
        let weeklyPoints = Int(record["weeklyPoints"] as? Int64 ?? 0)
        record["weeklyPoints"] = Int64(weeklyPoints + points)
        
        let monthlyPoints = Int(record["monthlyPoints"] as? Int64 ?? 0)
        record["monthlyPoints"] = Int64(monthlyPoints + points)
        
        _ = try await publicDatabase.save(record)
        print("✅ Leaderboard updated with \(points) points")
    }
    
    // MARK: - Helper Methods
    private func getCurrentUserID() -> String? {
        // Try both keys for compatibility
        if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
            return userID
        }
        return UserDefaults.standard.string(forKey: "currentUserRecordID")
    }
    
    private func parseChallengeFromRecord(_ record: CKRecord) -> Challenge? {
        guard let id = record["id"] as? String,
              let title = record["title"] as? String,
              let description = record["description"] as? String else {
            return nil
        }
        
        let requirements: [String] = (try? JSONDecoder().decode([String].self, from: Data(base64Encoded: record["requirements"] as? String ?? "") ?? Data())) ?? []
        
        return Challenge(
            id: id,
            title: title,
            description: description,
            type: ChallengeType(rawValue: record["type"] as? String ?? "") ?? .daily,
            category: record["category"] as? String ?? "cooking",
            difficulty: DifficultyLevel(rawValue: Int(record["difficulty"] as? Int64 ?? 2)) ?? .medium,
            points: Int(record["points"] as? Int64 ?? 0),
            coins: Int(record["coins"] as? Int64 ?? 0),
            startDate: record["startDate"] as? Date ?? Date(),
            endDate: record["endDate"] as? Date ?? Date(),
            requirements: requirements,
            currentProgress: 0,
            isCompleted: false,
            isActive: record["isActive"] as? Int64 == 1,
            isJoined: false,
            participants: Int(record["participantCount"] as? Int64 ?? 0),
            completions: Int(record["completionCount"] as? Int64 ?? 0),
            imageURL: record["imageURL"] as? String,
            isPremium: record["isPremium"] as? Int64 == 1
        )
    }
    
    private func parseTeamFromRecord(_ record: CKRecord) -> CloudKitTeam {
        return CloudKitTeam(
            id: record["id"] as? String ?? "",
            name: record["name"] as? String ?? "",
            description: record["description"] as? String ?? "",
            captainID: record["captainID"] as? String ?? "",
            memberIDs: record["memberIDs"] as? [String] ?? [],
            challengeID: (record["challengeID"] as? CKRecord.Reference)?.recordID.recordName ?? "",
            totalPoints: Int(record["totalPoints"] as? Int64 ?? 0),
            createdAt: record["createdAt"] as? Date ?? Date(),
            inviteCode: record["inviteCode"] as? String ?? "",
            isPublic: record["isPublic"] as? Int64 == 1,
            maxMembers: Int(record["maxMembers"] as? Int64 ?? 5)
        )
    }
    
    private func generateInviteCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
    
    private func calculateRarity(type: String) -> String {
        switch type {
        case "first_recipe", "first_challenge":
            return "common"
        case "streak_7", "challenges_10":
            return "rare"
        case "streak_30", "challenges_50":
            return "epic"
        case "streak_100", "challenges_100":
            return "legendary"
        default:
            return "common"
        }
    }
    
    private func incrementChallengeCompletions(_ challengeID: String) async {
        do {
            let recordID = CKRecord.ID(recordName: challengeID)
            let record = try await publicDatabase.record(for: recordID)
            let currentCount = record["completionCount"] as? Int64 ?? 0
            record["completionCount"] = currentCount + 1
            _ = try await publicDatabase.save(record)
        } catch {
            print("Failed to increment challenge completions: \(error)")
        }
    }
    
    private func notifyTeamMembers(teamID: String, message: String) async {
        print("📢 Team notification: \(message)")
    }
}