import Foundation
import CloudKit
import UIKit

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
            throw CloudKitError.notAuthenticated
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
            return results.matchResults.first?.0.1
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
            return results.matchResults.first?.0.1
        } catch {
            print("Error fetching user profile by username: \(error)")
            throw error
        }
    }
    
    // MARK: - Update Profile
    
    func updateProfileImage(_ image: UIImage) async throws {
        guard let userID = try await getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitError.notAuthenticated
        }
        
        let imageAsset = try await createImageAsset(from: image)
        profile[UserProfileFields.profileImageAsset] = imageAsset
        profile[UserProfileFields.updatedAt] = Date()
        
        _ = try await database.save(profile)
    }
    
    func updateBio(_ bio: String) async throws {
        guard let userID = try await getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitError.notAuthenticated
        }
        
        profile[UserProfileFields.bio] = bio
        profile[UserProfileFields.updatedAt] = Date()
        
        _ = try await database.save(profile)
    }
    
    // MARK: - Profile Stats
    
    func incrementRecipesShared() async throws {
        guard let userID = try await getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitError.notAuthenticated
        }
        
        let currentCount = profile[UserProfileFields.recipesShared] as? Int ?? 0
        profile[UserProfileFields.recipesShared] = currentCount + 1
        profile[UserProfileFields.updatedAt] = Date()
        
        _ = try await database.save(profile)
    }
    
    func updatePoints(_ points: Int) async throws {
        guard let userID = try await getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitError.notAuthenticated
        }
        
        profile[UserProfileFields.totalPoints] = points
        profile[UserProfileFields.updatedAt] = Date()
        
        _ = try await database.save(profile)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserID() async throws -> String? {
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
            throw CloudKitError.invalidData
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        try imageData.write(to: tempURL)
        
        return CKAsset(fileURL: tempURL)
    }
    
    // MARK: - Search Users
    
    func searchUsers(query: String) async throws -> [UserProfile] {
        let predicate = NSPredicate(format: "\(UserProfileFields.username) CONTAINS[cd] %@ OR \(UserProfileFields.displayName) CONTAINS[cd] %@", query, query)
        let ckQuery = CKQuery(recordType: userProfileRecordType, predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: UserProfileFields.totalPoints, ascending: false)]
        
        do {
            let results = try await database.records(matching: ckQuery)
            return results.matchResults.compactMap { _, record in
                UserProfile(from: record)
            }
        } catch {
            print("Error searching users: \(error)")
            throw error
        }
    }
}

// MARK: - UserProfile Model

struct UserProfile {
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

// MARK: - CloudKit Errors

enum CloudKitError: LocalizedError {
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