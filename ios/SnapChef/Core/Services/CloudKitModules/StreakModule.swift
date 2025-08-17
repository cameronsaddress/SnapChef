import Foundation
import CloudKit

/// Streak module for CloudKit operations
/// Handles streak tracking and leaderboards
@MainActor
final class StreakModule: ObservableObject {
    
    // MARK: - Properties
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private weak var parent: CloudKitService?
    
    // MARK: - Initialization
    init(container: CKContainer, publicDB: CKDatabase, privateDB: CKDatabase, parent: CloudKitService) {
        self.container = container
        self.publicDatabase = publicDB
        self.privateDatabase = privateDB
        self.parent = parent
    }
    
    // MARK: - Streak Management
    func updateStreak(_ streak: StreakData) async {
        let recordID = CKRecord.ID(recordName: "streak_\(streak.type.rawValue)_\(getCurrentUserID())")
        
        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
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
        
        do {
            _ = try await privateDatabase.save(record)
            print("✅ Streak synced to CloudKit")
        } catch {
            print("❌ Failed to sync streak: \(error)")
        }
    }
    
    func recordStreakBreak(_ history: StreakHistory) async {
        let record = CKRecord(recordType: "StreakHistory")
        
        record["userID"] = getCurrentUserID()
        record["streakType"] = history.type.rawValue
        record["streakLength"] = Int64(history.streakLength)
        record["startDate"] = history.startDate
        record["endDate"] = history.endDate
        record["breakReason"] = history.breakReason?.rawValue ?? ""
        record["restored"] = history.wasRestored ? 1 : 0
        
        do {
            _ = try await privateDatabase.save(record)
            print("📝 Streak break recorded")
        } catch {
            print("❌ Failed to record streak break: \(error)")
        }
    }
    
    func recordAchievement(_ achievement: StreakAchievement) async {
        let record = CKRecord(recordType: "StreakAchievement")
        
        record["userID"] = getCurrentUserID()
        record["achievementType"] = achievement.type.rawValue
        record["unlockedAt"] = achievement.unlockedAt
        record["streakLength"] = Int64(achievement.milestoneDays)
        record["rewardsClaimed"] = achievement.rewardsClaimed ? 1 : 0
        record["badgeIcon"] = achievement.milestoneBadge
        
        do {
            _ = try await publicDatabase.save(record)
            print("🏆 Achievement recorded")
        } catch {
            print("❌ Failed to record achievement: \(error)")
        }
    }
    
    func syncStreaks() async -> [StreakType: StreakData] {
        let userID = getCurrentUserID()
        
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "UserStreak", predicate: predicate)
        
        do {
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            
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
            print("❌ Failed to sync streaks: \(error)")
            return [:]
        }
    }
    
    func getStreakLeaderboard(type: StreakType, limit: Int = 100) async -> [(userID: String, streak: Int, username: String)] {
        let predicate = NSPredicate(format: "streakType == %@", type.rawValue)
        let query = CKQuery(recordType: "UserStreak", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "currentStreak", ascending: false)]
        
        do {
            let (matchResults, _) = try await publicDatabase.records(matching: query, resultsLimit: limit)
            
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
            print("❌ Failed to get leaderboard: \(error)")
            return []
        }
    }
    
    // MARK: - Helper Methods
    private func getCurrentUserID() -> String {
        // Try both keys for compatibility
        if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
            return userID
        }
        return UserDefaults.standard.string(forKey: "currentUserRecordID") ?? UUID().uuidString
    }
    
    private func getUserName(userID: String) async -> String {
        let recordID = CKRecord.ID(recordName: userID)
        
        do {
            let record = try await publicDatabase.record(for: recordID)
            return record["displayName"] as? String ?? "Unknown Chef"
        } catch {
            return "Unknown Chef"
        }
    }
}