import Foundation
import CloudKit
import SwiftUI

/// CloudKit Challenge Manager - Syncs challenges and team data
@MainActor
class CloudKitChallengeManager: ObservableObject {
    static let shared = CloudKitChallengeManager()

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        NSClassFromString("XCTestCase") != nil
    }

    private lazy var container: CKContainer? = {
        guard cloudKitEnabled else { return nil }
        return CloudKitRuntimeSupport.makeContainer()
    }()

    private var publicDB: CKDatabase? {
        container?.publicCloudDatabase
    }

    private var privateDB: CKDatabase? {
        container?.privateCloudDatabase
    }

    @Published var activeChallenges: [Challenge] = []
    @Published var userChallenges: [CloudKitUserChallenge] = []
    @Published var teams: [CloudKitTeam] = []

    private var cloudKitEnabled: Bool {
        CloudKitRuntimeSupport.hasCloudKitEntitlement
    }

    private func requireCloudKitEnabled(for operation: String) throws {
        guard cloudKitEnabled else {
            print("⚠️ CloudKitChallengeManager.\(operation): CloudKit unavailable in this runtime")
            throw CloudKitTeamError.cloudKitUnavailable
        }
    }

    private func requirePublicDB(for operation: String) throws -> CKDatabase {
        try requireCloudKitEnabled(for: operation)
        guard let publicDB else {
            throw CloudKitTeamError.cloudKitUnavailable
        }
        return publicDB
    }

    private func requirePrivateDB(for operation: String) throws -> CKDatabase {
        try requireCloudKitEnabled(for: operation)
        guard let privateDB else {
            throw CloudKitTeamError.cloudKitUnavailable
        }
        return privateDB
    }

    private init() {
        guard !Self.isRunningTests else { return }
        guard cloudKitEnabled else {
            print("⚠️ CloudKitChallengeManager running in local-only mode: challenge sync disabled")
            return
        }
        Task {
            await syncChallenges()
        }
    }

    // MARK: - Challenge Management

    /// Upload a challenge to CloudKit
    func uploadChallenge(_ challenge: Challenge) async throws -> String {
        let publicDB = try requirePublicDB(for: "uploadChallenge")

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: "Challenge", database: publicDB.debugName)
        
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
        record["badgeID"] = ""  // Badge system not yet implemented
        record["teamBased"] = 0  // Team challenges handled separately
        record["minTeamSize"] = Int64(1)
        record["maxTeamSize"] = Int64(5)

        do {
            let savedRecord = try await publicDB.save(record)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: "Challenge", recordID: savedRecord.recordID.recordName, database: publicDB.debugName, duration: duration)
            return savedRecord.recordID.recordName
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: "Challenge", database: publicDB.debugName, error: error, duration: duration)
            throw error
        }
    }

    /// Sync all active challenges from CloudKit
    func syncChallenges() async {
        guard cloudKitEnabled else { return }
        guard let publicDB = try? requirePublicDB(for: "syncChallenges") else { return }
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        
        let predicate = NSPredicate(format: "isActive == 1")
        let query = CKQuery(recordType: "Challenge", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: true)]
        
        logger.logQueryStart(query: query, database: publicDB.debugName)
        
        do {
            let (matchResults, _) = try await publicDB.records(matching: query)

            var challenges: [Challenge] = []
            for (_, result) in matchResults {
                if let record = try? result.get(),
                   let challenge = parseChallengeFromRecord(record) {
                    challenges.append(challenge)
                }
            }

            await MainActor.run {
                self.activeChallenges = challenges
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: challenges.count, database: publicDB.debugName, duration: duration)
            print("✅ Synced \(challenges.count) active challenges from CloudKit")
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: publicDB.debugName, error: error, duration: duration)
            print("❌ Failed to sync challenges: \(error)")
        }
    }

    // MARK: - User Challenge Progress

    /// Track user's challenge progress
    func updateUserProgress(challengeID: String, progress: Double) async throws {
        let privateDB = try requirePrivateDB(for: "updateUserProgress")

        guard let userID = getCurrentUserID() else { return }
        
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        let recordID = CKRecord.ID(recordName: "\(userID)_\(challengeID)")
        
        logger.logFetchStart(recordType: "UserChallenge", database: privateDB.debugName)

        let record: CKRecord
        do {
            record = try await privateDB.record(for: recordID)
            let duration = Date().timeIntervalSince(startTime)
            logger.logFetchSuccess(recordType: "UserChallenge", recordCount: 1, database: privateDB.debugName, duration: duration)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logFetchFailure(recordType: "UserChallenge", database: privateDB.debugName, error: error, duration: duration)
            
            // Create new progress record
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

            // Award points and coins
            if let challenge = activeChallenges.first(where: { $0.id == challengeID }) {
                record["earnedPoints"] = Int64(challenge.points)
                record["earnedCoins"] = Int64(challenge.coins)

                // Update challenge completion count
                await incrementChallengeCompletions(challengeID)
            }
        }

        let saveStartTime = Date()
        logger.logSaveStart(recordType: "UserChallenge", database: privateDB.debugName)
        
        do {
            _ = try await privateDB.save(record)
            let duration = Date().timeIntervalSince(saveStartTime)
            logger.logSaveSuccess(recordType: "UserChallenge", recordID: recordID.recordName, database: privateDB.debugName, duration: duration)
            print("✅ Updated progress for challenge \(challengeID): \(progress * 100)%")
        } catch {
            let duration = Date().timeIntervalSince(saveStartTime)
            logger.logSaveFailure(recordType: "UserChallenge", database: privateDB.debugName, error: error, duration: duration)
            throw error
        }
    }

    /// Get user's challenge progress
    func getUserChallengeProgress() async throws -> [CloudKitUserChallenge] {
        guard cloudKitEnabled else { return [] }
        let privateDB = try requirePrivateDB(for: "getUserChallengeProgress")

        guard let userID = getCurrentUserID() else { return [] }
        
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()

        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "UserChallenge", predicate: predicate)
        
        logger.logQueryStart(query: query, database: privateDB.debugName)

        do {
            let (matchResults, _) = try await privateDB.records(matching: query)

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

            await MainActor.run {
                self.userChallenges = userChallenges
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: userChallenges.count, database: privateDB.debugName, duration: duration)
            return userChallenges
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: privateDB.debugName, error: error, duration: duration)
            throw error
        }
    }

    // MARK: - Team Management

    /// Create a new team
    func createTeam(name: String, description: String, challengeID: String) async throws -> CloudKitTeam {
        let publicDB = try requirePublicDB(for: "createTeam")

        guard let userID = getCurrentUserID() else { throw CloudKitTeamError.notAuthenticated }
        
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: "Team", database: publicDB.debugName)

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

        do {
            let savedRecord = try await publicDB.save(record)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: "Team", recordID: savedRecord.recordID.recordName, database: publicDB.debugName, duration: duration)
            
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

            await MainActor.run {
                self.teams.append(team)
            }

            return team
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: "Team", database: publicDB.debugName, error: error, duration: duration)
            throw error
        }
    }

    /// Join a team
    func joinTeam(inviteCode: String) async throws -> CloudKitTeam {
        let publicDB = try requirePublicDB(for: "joinTeam")

        guard let userID = getCurrentUserID() else { throw CloudKitTeamError.notAuthenticated }
        
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()

        let predicate = NSPredicate(format: "inviteCode == %@", inviteCode)
        let query = CKQuery(recordType: "Team", predicate: predicate)
        
        logger.logQueryStart(query: query, database: publicDB.debugName)

        do {
            let (matchResults, _) = try await publicDB.records(matching: query)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: matchResults.count, database: publicDB.debugName, duration: duration)

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
            
            let saveStartTime = Date()
            logger.logSaveStart(recordType: "Team", database: publicDB.debugName)
            
            do {
                _ = try await publicDB.save(record)
                let saveDuration = Date().timeIntervalSince(saveStartTime)
                logger.logSaveSuccess(recordType: "Team", recordID: record.recordID.recordName, database: publicDB.debugName, duration: saveDuration)
                
                let team = parseTeamFromRecord(record)

                await MainActor.run {
                    if let index = self.teams.firstIndex(where: { $0.id == team.id }) {
                        self.teams[index] = team
                    } else {
                        self.teams.append(team)
                    }
                }

                return team
            } catch {
                let saveDuration = Date().timeIntervalSince(saveStartTime)
                logger.logSaveFailure(recordType: "Team", database: publicDB.debugName, error: error, duration: saveDuration)
                throw error
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: publicDB.debugName, error: error, duration: duration)
            throw error
        }
    }

    /// Update team points
    func updateTeamPoints(teamID: String, additionalPoints: Int) async throws {
        let publicDB = try requirePublicDB(for: "updateTeamPoints")

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        let recordID = CKRecord.ID(recordName: teamID)
        
        logger.logFetchStart(recordType: "Team", database: publicDB.debugName)
        
        do {
            let record = try await publicDB.record(for: recordID)
            let fetchDuration = Date().timeIntervalSince(startTime)
            logger.logFetchSuccess(recordType: "Team", recordCount: 1, database: publicDB.debugName, duration: fetchDuration)
            
            let currentPoints = Int(record["totalPoints"] as? Int64 ?? 0)
            record["totalPoints"] = Int64(currentPoints + additionalPoints)
            
            let saveStartTime = Date()
            logger.logSaveStart(recordType: "Team", database: publicDB.debugName)
            
            do {
                _ = try await publicDB.save(record)
                let saveDuration = Date().timeIntervalSince(saveStartTime)
                logger.logSaveSuccess(recordType: "Team", recordID: recordID.recordName, database: publicDB.debugName, duration: saveDuration)
                
                // Send notification to team members
                await notifyTeamMembers(teamID: teamID, message: "Your team earned \(additionalPoints) points!")
            } catch {
                let saveDuration = Date().timeIntervalSince(saveStartTime)
                logger.logSaveFailure(recordType: "Team", database: publicDB.debugName, error: error, duration: saveDuration)
                throw error
            }
        } catch {
            let fetchDuration = Date().timeIntervalSince(startTime)
            logger.logFetchFailure(recordType: "Team", database: publicDB.debugName, error: error, duration: fetchDuration)
            throw error
        }
    }

    /// Get team leaderboard
    func getTeamLeaderboard(challengeID: String) async throws -> [CloudKitTeam] {
        let publicDB = try requirePublicDB(for: "getTeamLeaderboard")

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        
        let predicate = NSPredicate(format: "challengeID == %@", CKRecord.Reference(recordID: CKRecord.ID(recordName: challengeID), action: .none))
        let query = CKQuery(recordType: "Team", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "totalPoints", ascending: false)]
        
        logger.logQueryStart(query: query, database: publicDB.debugName)

        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 100)

            var teams: [CloudKitTeam] = []
            for (_, result) in matchResults {
                if let record = try? result.get() {
                    teams.append(parseTeamFromRecord(record))
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: teams.count, database: publicDB.debugName, duration: duration)
            return teams
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: publicDB.debugName, error: error, duration: duration)
            throw error
        }
    }

    // MARK: - Awards and Metrics

    /// Track achievement earned
    func trackAchievement(type: String, name: String, description: String) async throws {
        let privateDB = try requirePrivateDB(for: "trackAchievement")

        guard let userID = getCurrentUserID() else { return }
        
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: "Achievement", database: privateDB.debugName)

        let record = CKRecord(recordType: "Achievement")
        record["id"] = UUID().uuidString
        record["userID"] = userID
        record["type"] = type
        record["name"] = name
        record["description"] = description
        record["earnedAt"] = Date()
        record["rarity"] = calculateRarity(type: type)

        do {
            _ = try await privateDB.save(record)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: "Achievement", recordID: record.recordID.recordName, database: privateDB.debugName, duration: duration)
            print("✅ Achievement tracked: \(name)")
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: "Achievement", database: privateDB.debugName, error: error, duration: duration)
            throw error
        }
    }

    /// Update leaderboard
    func updateLeaderboard(points: Int) async throws {
        let publicDB = try requirePublicDB(for: "updateLeaderboard")

        guard let userID = getCurrentUserID(),
              let userName = UnifiedAuthManager.shared.currentUser?.displayName else { return }
        
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        let recordID = CKRecord.ID(recordName: "leaderboard_\(userID)")
        
        logger.logFetchStart(recordType: "Leaderboard", database: publicDB.debugName)

        let record: CKRecord
        do {
            record = try await publicDB.record(for: recordID)
            let fetchDuration = Date().timeIntervalSince(startTime)
            logger.logFetchSuccess(recordType: "Leaderboard", recordCount: 1, database: publicDB.debugName, duration: fetchDuration)
        } catch {
            let fetchDuration = Date().timeIntervalSince(startTime)
            logger.logFetchFailure(recordType: "Leaderboard", database: publicDB.debugName, error: error, duration: fetchDuration)
            
            record = CKRecord(recordType: "Leaderboard", recordID: recordID)
            record["userID"] = userID
            record["userName"] = userName
        }

        let currentPoints = Int(record["totalPoints"] as? Int64 ?? 0)
        record["totalPoints"] = Int64(currentPoints + points)
        record["lastUpdated"] = Date()

        // Update weekly/monthly points
        let weeklyPoints = Int(record["weeklyPoints"] as? Int64 ?? 0)
        record["weeklyPoints"] = Int64(weeklyPoints + points)

        let monthlyPoints = Int(record["monthlyPoints"] as? Int64 ?? 0)
        record["monthlyPoints"] = Int64(monthlyPoints + points)
        
        let saveStartTime = Date()
        logger.logSaveStart(recordType: "Leaderboard", database: publicDB.debugName)
        
        do {
            _ = try await publicDB.save(record)
            let saveDuration = Date().timeIntervalSince(saveStartTime)
            logger.logSaveSuccess(recordType: "Leaderboard", recordID: recordID.recordName, database: publicDB.debugName, duration: saveDuration)
            print("✅ Leaderboard updated with \(points) points")
        } catch {
            let saveDuration = Date().timeIntervalSince(saveStartTime)
            logger.logSaveFailure(recordType: "Leaderboard", database: publicDB.debugName, error: error, duration: saveDuration)
            throw error
        }
    }

    // MARK: - Helper Methods

    private func getCurrentUserID() -> String? {
        return UserDefaults.standard.string(forKey: "currentUserID")
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
        return String((0..<6).compactMap { _ in letters.randomElement() })
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
        guard let publicDB = try? requirePublicDB(for: "incrementChallengeCompletions") else {
            return
        }

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        let recordID = CKRecord.ID(recordName: challengeID)
        
        logger.logFetchStart(recordType: "Challenge", database: publicDB.debugName)
        
        do {
            let record = try await publicDB.record(for: recordID)
            let fetchDuration = Date().timeIntervalSince(startTime)
            logger.logFetchSuccess(recordType: "Challenge", recordCount: 1, database: publicDB.debugName, duration: fetchDuration)
            
            let currentCount = record["completionCount"] as? Int64 ?? 0
            record["completionCount"] = currentCount + 1
            
            let saveStartTime = Date()
            logger.logSaveStart(recordType: "Challenge", database: publicDB.debugName)
            
            do {
                _ = try await publicDB.save(record)
                let saveDuration = Date().timeIntervalSince(saveStartTime)
                logger.logSaveSuccess(recordType: "Challenge", recordID: recordID.recordName, database: publicDB.debugName, duration: saveDuration)
            } catch {
                let saveDuration = Date().timeIntervalSince(saveStartTime)
                logger.logSaveFailure(recordType: "Challenge", database: publicDB.debugName, error: error, duration: saveDuration)
                print("Failed to increment challenge completions: \(error)")
            }
        } catch {
            let fetchDuration = Date().timeIntervalSince(startTime)
            logger.logFetchFailure(recordType: "Challenge", database: publicDB.debugName, error: error, duration: fetchDuration)
            print("Failed to increment challenge completions: \(error)")
        }
    }

    private func notifyTeamMembers(teamID: String, message: String) async {
        guard cloudKitEnabled else { return }

        // Implementation for team notifications
        // This would integrate with push notifications
        print("📢 Team notification: \(message)")
    }
}

// MARK: - Data Models

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

enum CloudKitTeamError: LocalizedError {
    case notAuthenticated
    case invalidInviteCode
    case alreadyMember
    case teamFull
    case cloudKitUnavailable

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
        case .cloudKitUnavailable:
            return "Cloud features are unavailable on this build/runtime."
        }
    }
}
