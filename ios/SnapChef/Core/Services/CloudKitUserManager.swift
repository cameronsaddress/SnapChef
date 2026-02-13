import Foundation
import CloudKit
import UIKit

@MainActor
class CloudKitUserManager: ObservableObject {
    static let shared = CloudKitUserManager()

    private lazy var container: CKContainer? = {
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else { return nil }
        return CloudKitRuntimeSupport.makeContainer()
    }()

    private lazy var database: CKDatabase? = {
        container?.publicCloudDatabase
    }()

    // Record type and field names
    private let userRecordType = CloudKitConfig.userRecordType

    // Use CKField.User for consistency with the rest of the app

    private init() {
        if !CloudKitRuntimeSupport.hasCloudKitEntitlement {
            print("⚠️ CloudKitUserManager running in local-only mode: CloudKit disabled")
        }
    }

    private func requireContainer(for operation: String) throws -> CKContainer {
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            print("⚠️ CloudKitUserManager.\(operation): CloudKit unavailable in this runtime")
            throw CloudKitUserError.notAuthenticated
        }
        guard let container else {
            throw CloudKitUserError.notAuthenticated
        }
        return container
    }

    private func requireDatabase(for operation: String) throws -> CKDatabase {
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            print("⚠️ CloudKitUserManager.\(operation): CloudKit unavailable in this runtime")
            throw CloudKitUserError.notAuthenticated
        }
        guard let database else {
            throw CloudKitUserError.notAuthenticated
        }
        return database
    }

    // MARK: - Username Availability

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let database = try requireDatabase(for: "isUsernameAvailable")
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        
        let predicate = NSPredicate(format: "\(CKField.User.username) == %@", username.lowercased())
        let query = CKQuery(recordType: userRecordType, predicate: predicate)
        
        logger.logQueryStart(query: query, database: database.debugName)

        do {
            let results = try await database.records(matching: query)
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: results.matchResults.count, database: database.debugName, duration: duration)
            return results.matchResults.isEmpty
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: database.debugName, error: error, duration: duration)
            print("Error checking username availability: \(error)")
            throw error
        }
    }

    // MARK: - Save User Profile

    func saveUserProfile(username: String, profileImage: UIImage?) async throws {
        let database = try requireDatabase(for: "saveUserProfile")
        guard let userID = try await getCurrentUserID() else {
            throw CloudKitUserError.notAuthenticated
        }

        let canonicalRecordID = CKRecord.ID(recordName: "user_\(userID)")
        let record: CKRecord
        do {
            record = try await database.record(for: canonicalRecordID)
        } catch let ckError as CKError where ckError.code == .unknownItem {
            record = CKRecord(recordType: userRecordType, recordID: canonicalRecordID)
        } catch {
            // Fall back to legacy lookup before creating a duplicate user record.
            if let legacyRecord = try? await fetchUserProfile(userID: userID) {
                record = legacyRecord
            } else {
                record = CKRecord(recordType: userRecordType, recordID: canonicalRecordID)
            }
        }

        // Set fields
        record[CKField.User.username] = username.lowercased()
        record[CKField.User.userID] = userID
        record[CKField.User.displayName] = username
        record[CKField.User.createdAt] = record[CKField.User.createdAt] ?? Date()
        record[CKField.User.lastActiveAt] = Date()

        // Handle profile image - User record uses profileImageURL (STRING)
        // For now, we'll skip profile image upload and implement it later
        // TODO: Implement image upload to CloudKit assets and set profileImageURL

        // Initialize counters if missing (avoid schema-type mismatches).
        if record[CKField.User.totalPoints] == nil {
            record[CKField.User.totalPoints] = Int64(0)
        }
        if record[CKField.User.recipesShared] == nil {
            record[CKField.User.recipesShared] = Int64(0)
        }
        if record[CKField.User.followerCount] == nil {
            record[CKField.User.followerCount] = Int64(0)
        }
        if record[CKField.User.followingCount] == nil {
            record[CKField.User.followingCount] = Int64(0)
        }
        if record[CKField.User.isVerified] == nil {
            record[CKField.User.isVerified] = Int64(0)
        }
        if record[CKField.User.subscriptionTier] == nil {
            record[CKField.User.subscriptionTier] = "free"
        }

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: userRecordType, database: database.debugName)
        
        do {
            _ = try await database.save(record)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: userRecordType, recordID: record.recordID.recordName, database: database.debugName, duration: duration)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: userRecordType, database: database.debugName, error: error, duration: duration)
            throw error
        }
    }

    // MARK: - Fetch User Profile

    func fetchUserProfile(userID: String) async throws -> CKRecord? {
        let database = try requireDatabase(for: "fetchUserProfile(userID:)")
        let trimmed = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawID = trimmed.hasPrefix("user_") ? String(trimmed.dropFirst(5)) : trimmed

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()

        // Fast-path: canonical record id format used throughout the app.
        let recordID = CKRecord.ID(recordName: "user_\(rawID)")
        do {
            let record = try await database.record(for: recordID)
            let duration = Date().timeIntervalSince(startTime)
            logger.logFetchSuccess(recordType: userRecordType, recordCount: 1, database: database.debugName, duration: duration)
            return record
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // Fall through to legacy query path.
        } catch {
            // Fall through to legacy query path (record might exist under a different ID).
        }

        let predicate = NSPredicate(format: "%K == %@", CKField.User.userID, rawID)
        let query = CKQuery(recordType: userRecordType, predicate: predicate)
        
        logger.logQueryStart(query: query, database: database.debugName)

        do {
            let results = try await database.records(matching: query)
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: results.matchResults.count, database: database.debugName, duration: duration)
            
            if let firstResult = results.matchResults.first {
                switch firstResult.1 {
                case .success(let record):
                    return record
                case .failure:
                    return nil
                }
            }
            return nil
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: database.debugName, error: error, duration: duration)
            throw error
        }
    }

    func fetchUserProfile(username: String) async throws -> CKRecord? {
        let database = try requireDatabase(for: "fetchUserProfile(username:)")
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        
        let predicate = NSPredicate(format: "\(CKField.User.username) == %@", username.lowercased())
        let query = CKQuery(recordType: userRecordType, predicate: predicate)
        
        logger.logQueryStart(query: query, database: database.debugName)

        do {
            let results = try await database.records(matching: query)
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: results.matchResults.count, database: database.debugName, duration: duration)
            
            if let firstResult = results.matchResults.first {
                switch firstResult.1 {
                case .success(let record):
                    return record
                case .failure:
                    return nil
                }
            }
            return nil
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: database.debugName, error: error, duration: duration)
            print("Error fetching user profile by username: \(error)")
            throw error
        }
    }

    // MARK: - Update Profile

    func updateProfileImage(_ image: UIImage) async throws {
        let database = try requireDatabase(for: "updateProfileImage")
        guard let userID = try await getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }

        let _ = try await createImageAsset(from: image)
        // TODO: Upload image and set profile[CKField.User.profileImageURL] = imageURL
        profile[CKField.User.lastActiveAt] = Date()

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: userRecordType, database: database.debugName)
        
        do {
            _ = try await database.save(profile)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: userRecordType, recordID: profile.recordID.recordName, database: database.debugName, duration: duration)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: userRecordType, database: database.debugName, error: error, duration: duration)
            throw error
        }
    }

    func updateBio(_ bio: String) async throws {
        let database = try requireDatabase(for: "updateBio")
        guard let userID = try await getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }

        profile["bio"] = bio
        profile[CKField.User.lastActiveAt] = Date()

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: userRecordType, database: database.debugName)
        
        do {
            _ = try await database.save(profile)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: userRecordType, recordID: profile.recordID.recordName, database: database.debugName, duration: duration)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: userRecordType, database: database.debugName, error: error, duration: duration)
            throw error
        }
    }

    // MARK: - Profile Stats

    func incrementRecipesShared() async throws {
        let database = try requireDatabase(for: "incrementRecipesShared")
        guard let userID = try await getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }

        let currentCount = profile[CKField.User.recipesShared] as? Int ?? 0
        profile[CKField.User.recipesShared] = currentCount + 1
        profile[CKField.User.lastActiveAt] = Date()

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: userRecordType, database: database.debugName)
        
        do {
            _ = try await database.save(profile)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: userRecordType, recordID: profile.recordID.recordName, database: database.debugName, duration: duration)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: userRecordType, database: database.debugName, error: error, duration: duration)
            throw error
        }
    }

    func updatePoints(_ points: Int) async throws {
        let database = try requireDatabase(for: "updatePoints")
        guard let userID = try await getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }

        profile[CKField.User.totalPoints] = points
        profile[CKField.User.lastActiveAt] = Date()

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: userRecordType, database: database.debugName)
        
        do {
            _ = try await database.save(profile)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: userRecordType, recordID: profile.recordID.recordName, database: database.debugName, duration: duration)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: userRecordType, database: database.debugName, error: error, duration: duration)
            throw error
        }
    }

    // MARK: - Helper Methods

    func getCurrentUserID() async throws -> String? {
        let container = try requireContainer(for: "getCurrentUserID")
        do {
            let userRecordID = try await container.userRecordID()
            return userRecordID.recordName
        } catch {
            print("Error getting user ID: \(error)")
            return nil
        }
    }

    private func createImageAsset(from image: UIImage) async throws -> CKAsset {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw CloudKitUserError.invalidData
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        try imageData.write(to: tempURL)

        return CKAsset(fileURL: tempURL)
    }

    // MARK: - Search Users

    func searchUsers(query: String) async throws -> [CloudKitUserProfile] {
        let database = try requireDatabase(for: "searchUsers")
        let predicate = NSPredicate(format: "\(CKField.User.username) CONTAINS[cd] %@ OR \(CKField.User.displayName) CONTAINS[cd] %@", query, query)
        let ckQuery = CKQuery(recordType: userRecordType, predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: CKField.User.totalPoints, ascending: false)]

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logQueryStart(query: ckQuery, database: database.debugName)
        
        do {
            let results = try await database.records(matching: ckQuery)
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: ckQuery, resultCount: results.matchResults.count, database: database.debugName, duration: duration)
            
            return results.matchResults.compactMap { _, result in
                switch result {
                case .success(let record):
                    return CloudKitUserProfile(from: record)
                case .failure:
                    return nil
                }
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: ckQuery, database: database.debugName, error: error, duration: duration)
            print("Error searching users: \(error)")
            throw error
        }
    }

    // MARK: - Dynamic Stats Methods
    
    /// Fetch user by UID to get username for recipe tiles
    func fetchUserByUID(_ uid: String) async throws -> CloudKitUserProfile? {
        guard let record = try await fetchUserProfile(userID: uid) else {
            return nil
        }
        return CloudKitUserProfile(from: record)
    }
    
    /// Get follower count for a user
    func getFollowerCount(for userID: String) async throws -> Int {
        let database = try requireDatabase(for: "getFollowerCount")
        let predicate = NSPredicate(format: "\(CKField.Follow.followingID) == %@ AND \(CKField.Follow.isActive) == %d", userID, 1)
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logQueryStart(query: query, database: database.debugName)
        
        do {
            let results = try await database.records(matching: query)
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: results.matchResults.count, database: database.debugName, duration: duration)
            return results.matchResults.count
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: database.debugName, error: error, duration: duration)
            print("Error fetching follower count: \(error)")
            throw error
        }
    }
    
    /// Get following count for a user
    func getFollowingCount(for userID: String) async throws -> Int {
        let database = try requireDatabase(for: "getFollowingCount")
        let predicate = NSPredicate(format: "\(CKField.Follow.followerID) == %@ AND \(CKField.Follow.isActive) == %d", userID, 1)
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logQueryStart(query: query, database: database.debugName)
        
        do {
            let results = try await database.records(matching: query)
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: results.matchResults.count, database: database.debugName, duration: duration)
            return results.matchResults.count
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: database.debugName, error: error, duration: duration)
            print("Error fetching following count: \(error)")
            throw error
        }
    }
    
    /// Get recipe count for a user
    func getRecipeCount(for userID: String) async throws -> Int {
        let database = try requireDatabase(for: "getRecipeCount")
        let predicate = NSPredicate(format: "\(CKField.Recipe.ownerID) == %@ AND \(CKField.Recipe.isPublic) == %d", userID, 1)
        let query = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: predicate)
        
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logQueryStart(query: query, database: database.debugName)
        
        do {
            let results = try await database.records(matching: query)
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: results.matchResults.count, database: database.debugName, duration: duration)
            return results.matchResults.count
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: database.debugName, error: error, duration: duration)
            print("Error fetching recipe count: \(error)")
            throw error
        }
    }
    
    /// Get user achievements (badges earned)
    func getUserAchievements(for userID: String) async throws -> [CloudKitAchievement] {
        let database = try requireDatabase(for: "getUserAchievements")
        let predicate = NSPredicate(format: "%K == %@", CKField.Achievement.userID, userID)
        let query = CKQuery(recordType: CloudKitConfig.achievementRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.Achievement.earnedAt, ascending: false)]
        
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logQueryStart(query: query, database: database.debugName)
        
        do {
            let results = try await database.records(matching: query)
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: results.matchResults.count, database: database.debugName, duration: duration)
            
            return results.matchResults.compactMap { _, result in
                switch result {
                case .success(let record):
                    return CloudKitAchievement(from: record)
                case .failure:
                    return nil
                }
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: database.debugName, error: error, duration: duration)
            print("Error fetching user achievements: \(error)")
            throw error
        }
    }
    
    /// Update follower/following counts in user profile for performance
    func updateFollowerCounts(userID: String, followerCount: Int, followingCount: Int) async throws {
        let database = try requireDatabase(for: "updateFollowerCounts")
        guard let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }
        
        profile[CKField.User.followerCount] = followerCount
        profile[CKField.User.followingCount] = followingCount
        profile[CKField.User.lastActiveAt] = Date()
        
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: userRecordType, database: database.debugName)
        
        do {
            _ = try await database.save(profile)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: userRecordType, recordID: profile.recordID.recordName, database: database.debugName, duration: duration)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: userRecordType, database: database.debugName, error: error, duration: duration)
            throw error
        }
    }
    
    /// Update recipe count in user profile for performance
    func updateRecipeCount(userID: String, recipeCount: Int) async throws {
        let database = try requireDatabase(for: "updateRecipeCount")
        guard let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }
        
        profile[CKField.User.recipesShared] = recipeCount
        profile[CKField.User.lastActiveAt] = Date()
        
        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: userRecordType, database: database.debugName)
        
        do {
            _ = try await database.save(profile)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: userRecordType, recordID: profile.recordID.recordName, database: database.debugName, duration: duration)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: userRecordType, database: database.debugName, error: error, duration: duration)
            throw error
        }
    }
    
    /// Calculate current recipe creation streak based on consecutive days
    func calculateRecipeStreak(for userID: String) async throws -> Int {
        let database = try requireDatabase(for: "calculateRecipeStreak")
        let predicate = NSPredicate(format: "\(CKField.Recipe.ownerID) == %@", userID)
        let query = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.Recipe.createdAt, ascending: false)]
        
        do {
            let results = try await database.records(matching: query)
            var recipeDates: [Date] = []
            
            for (_, result) in results.matchResults {
                switch result {
                case .success(let record):
                    if let createdAt = record[CKField.Recipe.createdAt] as? Date {
                        recipeDates.append(createdAt)
                    }
                case .failure:
                    continue
                }
            }
            
            return calculateStreakFromDates(recipeDates)
        } catch {
            print("Error calculating recipe streak: \(error)")
            throw error
        }
    }
    
    /// Helper method to calculate streak from recipe creation dates
    private func calculateStreakFromDates(_ dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today
        
        // Group dates by day
        let datesToDays = Set(dates.map { calendar.startOfDay(for: $0) })
        
        // Check backwards from today
        while streak < 365 { // Limit check to last 365 days
            if datesToDays.contains(checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if streak > 0 {
                // If we've started counting and there's a gap, stop
                break
            } else {
                // If we haven't found any recipes yet, keep looking back
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                
                // Stop if we've gone back more than 30 days without finding anything
                if calendar.dateComponents([.day], from: checkDate, to: today).day ?? 0 > 30 {
                    break
                }
            }
        }
        
        return streak
    }
    
    /// Get comprehensive user stats including dynamic counts
    func getUserStats(for userID: String) async throws -> UserStats {
        async let followerCount = getFollowerCount(for: userID)
        async let followingCount = getFollowingCount(for: userID)
        async let recipeCount = getRecipeCount(for: userID)
        async let achievements = getUserAchievements(for: userID)
        async let streak = calculateRecipeStreak(for: userID)
        
        let stats = try await UserStats(
            followerCount: followerCount,
            followingCount: followingCount,
            recipeCount: recipeCount,
            achievementCount: achievements.count,
            currentStreak: streak
        )
        
        return stats
    }
}

// MARK: - UserStats Model

struct UserStats {
    let followerCount: Int
    let followingCount: Int
    let recipeCount: Int
    let achievementCount: Int
    let currentStreak: Int
}

// MARK: - CloudKitUserProfile Model

public struct CloudKitUserProfile {
    let recordID: CKRecord.ID
    let username: String
    let userID: String
    let displayName: String
    let bio: String?
    let profileImageURL: String?
    let createdAt: Date
    let lastActiveAt: Date
    let isVerified: Bool
    let subscriptionTier: String
    let totalPoints: Int
    let recipesShared: Int
    let followerCount: Int
    let followingCount: Int

    init?(from record: CKRecord) {
        func intValue(forKey key: String) -> Int {
            if let value = record[key] as? Int64 { return Int(value) }
            if let value = record[key] as? Int { return value }
            if let value = record[key] as? NSNumber { return value.intValue }
            return 0
        }

        func int64Value(forKey key: String) -> Int64 {
            if let value = record[key] as? Int64 { return value }
            if let value = record[key] as? Int { return Int64(value) }
            if let value = record[key] as? NSNumber { return value.int64Value }
            return 0
        }

        let recordName = record.recordID.recordName
        let derivedUserIDFromRecordName: String = {
            if recordName.hasPrefix("user_") {
                return String(recordName.dropFirst(5))
            }
            return recordName
        }()

        let storedUserID = (record[CKField.User.userID] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedUserID = (storedUserID?.isEmpty == false) ? storedUserID! : derivedUserIDFromRecordName

        let storedUsername = (record[CKField.User.username] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let storedDisplayName = (record[CKField.User.displayName] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedDisplayName: String = {
            if let storedDisplayName, !storedDisplayName.isEmpty { return storedDisplayName }
            if let storedUsername, !storedUsername.isEmpty { return storedUsername }
            return "Chef"
        }()

        let resolvedUsername: String = {
            if let storedUsername, !storedUsername.isEmpty { return storedUsername.lowercased() }

            let base = resolvedDisplayName
                .lowercased()
                .replacingOccurrences(of: #"[^a-z0-9_-]+"#, with: "", options: .regularExpression)
            if base.count >= 3 {
                return base
            }

            let suffix = String(resolvedUserID.suffix(4))
            return "chef\(suffix)"
        }()

        self.recordID = record.recordID
        self.username = resolvedUsername
        self.userID = resolvedUserID
        self.displayName = resolvedDisplayName
        self.bio = record[CKField.User.bio] as? String

        // User record type uses profileImageURL (STRING) not profileImageAsset (ASSET)
        self.profileImageURL = record[CKField.User.profileImageURL] as? String

        self.createdAt = record[CKField.User.createdAt] as? Date ?? Date()
        self.lastActiveAt = record[CKField.User.lastActiveAt] as? Date ?? Date()

        let verifiedFlag = int64Value(forKey: CKField.User.isVerified)
        self.isVerified = verifiedFlag == 1 || (record[CKField.User.isVerified] as? Bool == true)
        self.subscriptionTier = (record[CKField.User.subscriptionTier] as? String) ?? "free"
        self.totalPoints = intValue(forKey: CKField.User.totalPoints)
        self.recipesShared = intValue(forKey: CKField.User.recipesShared)
        self.followerCount = intValue(forKey: CKField.User.followerCount)
        self.followingCount = intValue(forKey: CKField.User.followingCount)
    }
}

// MARK: - CloudKitAchievement Model

struct CloudKitAchievement {
    let recordID: CKRecord.ID
    let id: String
    let userID: String
    let type: String
    let name: String
    let description: String
    let iconName: String
    let earnedAt: Date
    let rarity: String
    let associatedChallengeID: String?

    init?(from record: CKRecord) {
        guard let id = record["id"] as? String,
              let userID = record["userID"] as? String,
              let type = record["type"] as? String,
              let name = record["name"] as? String,
              let description = record["description"] as? String,
              let iconName = record["iconName"] as? String,
              let earnedAt = record["earnedAt"] as? Date,
              let rarity = record["rarity"] as? String else {
            return nil
        }

        self.recordID = record.recordID
        self.id = id
        self.userID = userID
        self.type = type
        self.name = name
        self.description = description
        self.iconName = iconName
        self.earnedAt = earnedAt
        self.rarity = rarity
        self.associatedChallengeID = record["associatedChallengeID"] as? String
    }
}

// MARK: - CloudKit User Errors

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
