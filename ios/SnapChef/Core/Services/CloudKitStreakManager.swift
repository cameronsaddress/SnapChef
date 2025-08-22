import Foundation
import CloudKit

/// CloudKit manager for streak synchronization
@MainActor
class CloudKitStreakManager: ObservableObject {
    static let shared = CloudKitStreakManager()

    private let container = CKContainer(identifier: "iCloud.com.snapchefapp.app")
    private let publicDB: CKDatabase
    private let privateDB: CKDatabase

    private init() {
        self.publicDB = container.publicCloudDatabase
        self.privateDB = container.privateCloudDatabase
    }

    // MARK: - Streak Management

    /// Update streak data in CloudKit
    func updateStreak(_ streak: StreakData) async {
        let recordID = CKRecord.ID(recordName: "streak_\(streak.type.rawValue)_\(getCurrentUserID())")

        let record: CKRecord
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logFetchStart(recordType: "UserStreak", database: privateDB.debugName)
        
        do {
            record = try await privateDB.record(for: recordID)
            let fetchDuration = Date().timeIntervalSince(startTime)
            logger.logFetchSuccess(recordType: "UserStreak", recordCount: 1, database: privateDB.debugName, duration: fetchDuration)
        } catch {
            let fetchDuration = Date().timeIntervalSince(startTime)
            logger.logFetchFailure(recordType: "UserStreak", database: privateDB.debugName, error: error, duration: fetchDuration)
            record = CKRecord(recordType: "UserStreak", recordID: recordID)
        }

        record["userID"] = getCurrentUserID()
        record["streakType"] = streak.type.rawValue
        record["currentStreak"] = Int64(streak.currentStreak)
        record["longestStreak"] = Int64(streak.longestStreak)
        record["lastActivityDate"] = streak.lastActivityDate
        record["streakStartDate"] = streak.streakStartDate
        record["totalDaysActive"] = Int64(streak.totalDaysActive)
        record["frozenUntil"] = streak.frozenUntil
        record["insuranceActive"] = streak.insuranceActive ? 1 : 0
        record["multiplier"] = streak.multiplier

        let saveStartTime = Date()
        logger.logSaveStart(recordType: "UserStreak", database: privateDB.debugName)
        
        do {
            _ = try await privateDB.save(record)
            let saveDuration = Date().timeIntervalSince(saveStartTime)
            logger.logSaveSuccess(recordType: "UserStreak", recordID: recordID.recordName, database: privateDB.debugName, duration: saveDuration)
            print("✅ Streak synced to CloudKit")
        } catch {
            let saveDuration = Date().timeIntervalSince(saveStartTime)
            logger.logSaveFailure(recordType: "UserStreak", database: privateDB.debugName, error: error, duration: saveDuration)
            print("❌ Failed to sync streak: \(error)")
        }
    }

    /// Record streak break in history
    func recordStreakBreak(_ history: StreakHistory) async {
        let record = CKRecord(recordType: "StreakHistory")

        record["userID"] = getCurrentUserID()
        record["streakType"] = history.type.rawValue
        record["streakLength"] = Int64(history.streakLength)
        record["startDate"] = history.startDate
        record["endDate"] = history.endDate
        record["breakReason"] = history.breakReason?.rawValue ?? ""
        record["restored"] = history.wasRestored ? 1 : 0

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: "StreakHistory", database: privateDB.debugName)
        
        do {
            _ = try await privateDB.save(record)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: "StreakHistory", recordID: record.recordID.recordName, database: privateDB.debugName, duration: duration)
            print("📝 Streak break recorded")
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: "StreakHistory", database: privateDB.debugName, error: error, duration: duration)
            print("❌ Failed to record streak break: \(error)")
        }
    }

    /// Record achievement unlock
    func recordAchievement(_ achievement: StreakAchievement) async {
        let record = CKRecord(recordType: "StreakAchievement")

        record["userID"] = getCurrentUserID()
        record["achievementType"] = achievement.type.rawValue
        record["unlockedAt"] = achievement.unlockedAt
        record["streakLength"] = Int64(achievement.milestoneDays)
        record["rewardsClaimed"] = achievement.rewardsClaimed ? 1 : 0
        record["badgeIcon"] = achievement.milestoneBadge

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: "StreakAchievement", database: publicDB.debugName)
        
        do {
            _ = try await publicDB.save(record)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: "StreakAchievement", recordID: record.recordID.recordName, database: publicDB.debugName, duration: duration)
            print("🏆 Achievement recorded")
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: "StreakAchievement", database: publicDB.debugName, error: error, duration: duration)
            print("❌ Failed to record achievement: \(error)")
        }
    }

    /// Sync all streaks from CloudKit
    func syncStreaks() async -> [StreakType: StreakData] {
        let userID = getCurrentUserID()

        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "UserStreak", predicate: predicate)

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logQueryStart(query: query, database: privateDB.debugName)
        
        do {
            let (matchResults, _) = try await privateDB.records(matching: query)
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: matchResults.count, database: privateDB.debugName, duration: duration)

            var streaks: [StreakType: StreakData] = [:]
            for (_, result) in matchResults {
                if let record = try? result.get(),
                   let typeString = record["streakType"] as? String,
                   let type = StreakType(rawValue: typeString) {
                    var streak = StreakData(type: type)
                    streak.currentStreak = Int(record["currentStreak"] as? Int64 ?? 0)
                    streak.longestStreak = Int(record["longestStreak"] as? Int64 ?? 0)
                    streak.lastActivityDate = record["lastActivityDate"] as? Date ?? Date.distantPast
                    streak.streakStartDate = record["streakStartDate"] as? Date ?? Date()
                    streak.totalDaysActive = Int(record["totalDaysActive"] as? Int64 ?? 0)
                    streak.frozenUntil = record["frozenUntil"] as? Date
                    streak.insuranceActive = (record["insuranceActive"] as? Int64 ?? 0) == 1
                    streak.multiplier = record["multiplier"] as? Double ?? 1.0

                    streaks[type] = streak
                }
            }

            return streaks
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: privateDB.debugName, error: error, duration: duration)
            print("❌ Failed to sync streaks: \(error)")
            return [:]
        }
    }

    // Team streak functionality has been removed

    /// Get streak leaderboard
    func getStreakLeaderboard(type: StreakType, limit: Int = 100) async -> [(userID: String, streak: Int, username: String)] {
        let predicate = NSPredicate(format: "streakType == %@", type.rawValue)
        let query = CKQuery(recordType: "UserStreak", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "currentStreak", ascending: false)]

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logQueryStart(query: query, database: publicDB.debugName)
        
        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: limit)
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: matchResults.count, database: publicDB.debugName, duration: duration)

            var leaderboard: [(userID: String, streak: Int, username: String)] = []
            for (_, result) in matchResults {
                if let record = try? result.get(),
                   let userID = record["userID"] as? String {
                    let streak = Int(record["currentStreak"] as? Int64 ?? 0)
                    let username = await getUserName(userID: userID)
                    leaderboard.append((userID, streak, username))
                }
            }

            return leaderboard
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: publicDB.debugName, error: error, duration: duration)
            print("❌ Failed to get leaderboard: \(error)")
            return []
        }
    }

    // MARK: - Helper Methods

    private func getCurrentUserID() -> String {
        UserDefaults.standard.string(forKey: "currentUserID") ?? UUID().uuidString
    }

    private func getUserName(userID: String) async -> String {
        // Fetch username from User record
        let recordID = CKRecord.ID(recordName: userID)

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logFetchStart(recordType: "User", database: publicDB.debugName)
        
        do {
            let record = try await publicDB.record(for: recordID)
            let duration = Date().timeIntervalSince(startTime)
            logger.logFetchSuccess(recordType: "User", recordCount: 1, database: publicDB.debugName, duration: duration)
            return record["displayName"] as? String ?? "Unknown Chef"
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logFetchFailure(recordType: "User", database: publicDB.debugName, error: error, duration: duration)
            return "Unknown Chef"
        }
    }
}
