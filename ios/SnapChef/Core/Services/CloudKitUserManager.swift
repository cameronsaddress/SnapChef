import Foundation
import CloudKit
import UIKit

@MainActor
class CloudKitUserManager: ObservableObject {
    static let shared = CloudKitUserManager()

    private let container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
    private let database = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase

    // Record type and field names
    private let userProfileRecordType = "UserProfile"

    private struct UserProfileFields {
        static let username = "username"
        static let userID = "userID"
        static let profileImageAsset = "profileImageAsset"
        static let displayName = "displayName"
        static let bio = "bio"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let isVerified = "isVerified"
        static let isPremium = "isPremium"
        static let totalPoints = "totalPoints"
        static let recipesShared = "recipesShared"
        static let followersCount = "followersCount"
        static let followingCount = "followingCount"
    }

    private init() {}

    // MARK: - Username Availability

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let predicate = NSPredicate(format: "\(UserProfileFields.username) == %@", username.lowercased())
        let query = CKQuery(recordType: userProfileRecordType, predicate: predicate)

        do {
            let results = try await database.records(matching: query)
            return results.matchResults.isEmpty
        } catch {
            print("Error checking username availability: \(error)")
            throw error
        }
    }

    // MARK: - Save User Profile

    func saveUserProfile(username: String, profileImage: UIImage?) async throws {
        guard let userID = try await getCurrentUserID() else {
            throw CloudKitUserError.notAuthenticated
        }

        // Check if profile already exists
        let existingProfile = try? await fetchUserProfile(userID: userID)

        let record = existingProfile ?? CKRecord(recordType: userProfileRecordType)

        // Set fields
        record[UserProfileFields.username] = username.lowercased()
        record[UserProfileFields.userID] = userID
        record[UserProfileFields.displayName] = username
        record[UserProfileFields.createdAt] = record[UserProfileFields.createdAt] ?? Date()
        record[UserProfileFields.updatedAt] = Date()

        // Handle profile image
        if let image = profileImage {
            let imageAsset = try await createImageAsset(from: image)
            record[UserProfileFields.profileImageAsset] = imageAsset
        }

        // Initialize counters if new profile
        if existingProfile == nil {
            record[UserProfileFields.totalPoints] = 0
            record[UserProfileFields.recipesShared] = 0
            record[UserProfileFields.followersCount] = 0
            record[UserProfileFields.followingCount] = 0
            record[UserProfileFields.isVerified] = false
            record[UserProfileFields.isPremium] = false
        }

        do {
            _ = try await database.save(record)
            print("Successfully saved user profile for username: \(username)")
        } catch {
            print("Error saving user profile: \(error)")
            throw error
        }
    }

    // MARK: - Fetch User Profile

    func fetchUserProfile(userID: String) async throws -> CKRecord? {
        let predicate = NSPredicate(format: "\(UserProfileFields.userID) == %@", userID)
        let query = CKQuery(recordType: userProfileRecordType, predicate: predicate)

        do {
            let results = try await database.records(matching: query)
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
            print("Error fetching user profile: \(error)")
            throw error
        }
    }

    func fetchUserProfile(username: String) async throws -> CKRecord? {
        let predicate = NSPredicate(format: "\(UserProfileFields.username) == %@", username.lowercased())
        let query = CKQuery(recordType: userProfileRecordType, predicate: predicate)

        do {
            let results = try await database.records(matching: query)
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
            print("Error fetching user profile by username: \(error)")
            throw error
        }
    }

    // MARK: - Update Profile

    func updateProfileImage(_ image: UIImage) async throws {
        guard let userID = try await getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }

        let imageAsset = try await createImageAsset(from: image)
        profile[UserProfileFields.profileImageAsset] = imageAsset
        profile[UserProfileFields.updatedAt] = Date()

        _ = try await database.save(profile)
    }

    func updateBio(_ bio: String) async throws {
        guard let userID = try await getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }

        profile[UserProfileFields.bio] = bio
        profile[UserProfileFields.updatedAt] = Date()

        _ = try await database.save(profile)
    }

    // MARK: - Profile Stats

    func incrementRecipesShared() async throws {
        guard let userID = try await getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }

        let currentCount = profile[UserProfileFields.recipesShared] as? Int ?? 0
        profile[UserProfileFields.recipesShared] = currentCount + 1
        profile[UserProfileFields.updatedAt] = Date()

        _ = try await database.save(profile)
    }

    func updatePoints(_ points: Int) async throws {
        guard let userID = try await getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }

        profile[UserProfileFields.totalPoints] = points
        profile[UserProfileFields.updatedAt] = Date()

        _ = try await database.save(profile)
    }

    // MARK: - Helper Methods

    func getCurrentUserID() async throws -> String? {
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
        let predicate = NSPredicate(format: "\(UserProfileFields.username) CONTAINS[cd] %@ OR \(UserProfileFields.displayName) CONTAINS[cd] %@", query, query)
        let ckQuery = CKQuery(recordType: userProfileRecordType, predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: UserProfileFields.totalPoints, ascending: false)]

        do {
            let results = try await database.records(matching: ckQuery)
            return results.matchResults.compactMap { _, result in
                switch result {
                case .success(let record):
                    return CloudKitUserProfile(from: record)
                case .failure:
                    return nil
                }
            }
        } catch {
            print("Error searching users: \(error)")
            throw error
        }
    }

    // MARK: - Dynamic Stats Methods
    
    /// Fetch user by UID to get username for recipe tiles
    func fetchUserByUID(_ uid: String) async throws -> CloudKitUserProfile? {
        let predicate = NSPredicate(format: "\(UserProfileFields.userID) == %@", uid)
        let query = CKQuery(recordType: userProfileRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            if let firstResult = results.matchResults.first {
                switch firstResult.1 {
                case .success(let record):
                    return CloudKitUserProfile(from: record)
                case .failure:
                    return nil
                }
            }
            return nil
        } catch {
            print("Error fetching user by UID: \(error)")
            throw error
        }
    }
    
    /// Get follower count for a user
    func getFollowerCount(for userID: String) async throws -> Int {
        let predicate = NSPredicate(format: "\(CKField.Follow.followingID) == %@ AND \(CKField.Follow.isActive) == %d", userID, 1)
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            return results.matchResults.count
        } catch {
            print("Error fetching follower count: \(error)")
            throw error
        }
    }
    
    /// Get following count for a user
    func getFollowingCount(for userID: String) async throws -> Int {
        let predicate = NSPredicate(format: "\(CKField.Follow.followerID) == %@ AND \(CKField.Follow.isActive) == %d", userID, 1)
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            return results.matchResults.count
        } catch {
            print("Error fetching following count: \(error)")
            throw error
        }
    }
    
    /// Get recipe count for a user
    func getRecipeCount(for userID: String) async throws -> Int {
        let predicate = NSPredicate(format: "\(CKField.Recipe.ownerID) == %@ AND \(CKField.Recipe.isPublic) == %d", userID, 1)
        let query = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            return results.matchResults.count
        } catch {
            print("Error fetching recipe count: \(error)")
            throw error
        }
    }
    
    /// Get user achievements (badges earned)
    func getUserAchievements(for userID: String) async throws -> [CloudKitAchievement] {
        let predicate = NSPredicate(format: "%K == %@", CKField.Achievement.userID, userID)
        let query = CKQuery(recordType: CloudKitConfig.achievementRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.Achievement.earnedAt, ascending: false)]
        
        do {
            let results = try await database.records(matching: query)
            return results.matchResults.compactMap { _, result in
                switch result {
                case .success(let record):
                    return CloudKitAchievement(from: record)
                case .failure:
                    return nil
                }
            }
        } catch {
            print("Error fetching user achievements: \(error)")
            throw error
        }
    }
    
    /// Update follower/following counts in user profile for performance
    func updateFollowerCounts(userID: String, followerCount: Int, followingCount: Int) async throws {
        guard let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }
        
        profile[UserProfileFields.followersCount] = followerCount
        profile[UserProfileFields.followingCount] = followingCount
        profile[UserProfileFields.updatedAt] = Date()
        
        _ = try await database.save(profile)
    }
    
    /// Update recipe count in user profile for performance
    func updateRecipeCount(userID: String, recipeCount: Int) async throws {
        guard let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }
        
        profile[UserProfileFields.recipesShared] = recipeCount
        profile[UserProfileFields.updatedAt] = Date()
        
        _ = try await database.save(profile)
    }
    
    /// Calculate current recipe creation streak based on consecutive days
    func calculateRecipeStreak(for userID: String) async throws -> Int {
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
