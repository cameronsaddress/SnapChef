import Foundation
import CloudKit
import UIKit

/// User module for CloudKit operations
/// Handles user profile management and operations
@MainActor
final class UserModule: ObservableObject {
    
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
    
    // MARK: - Username Availability
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let predicate = NSPredicate(format: "username == %@", username.lowercased())
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        
        do {
            let results = try await publicDatabase.records(matching: query)
            return results.matchResults.isEmpty
        } catch {
            print("Error checking username availability: \(error)")
            throw error
        }
    }
    
    // MARK: - Save User Profile
    func saveUserProfile(username: String, profileImage: UIImage?) async throws {
        guard let userID = getCurrentUserID() else {
            throw CloudKitUserError.notAuthenticated
        }
        
        // Check if profile already exists
        let existingProfile = try? await fetchUserProfile(userID: userID)
        
        let record = existingProfile ?? CKRecord(recordType: "UserProfile")
        
        // Set fields
        record["username"] = username.lowercased()
        record["userID"] = userID
        record["displayName"] = username
        record["createdAt"] = record["createdAt"] ?? Date()
        record["updatedAt"] = Date()
        
        // Handle profile image
        if let image = profileImage {
            let imageAsset = try await createImageAsset(from: image)
            record["profileImageAsset"] = imageAsset
        }
        
        // Initialize counters if new profile
        if existingProfile == nil {
            record["totalPoints"] = 0
            record["recipesShared"] = 0
            record["followersCount"] = 0
            record["followingCount"] = 0
            record["isVerified"] = false
            record["isPremium"] = false
        }
        
        do {
            _ = try await publicDatabase.save(record)
            print("Successfully saved user profile for username: \(username)")
        } catch {
            print("Error saving user profile: \(error)")
            throw error
        }
    }
    
    // MARK: - Fetch User Profile
    func fetchUserProfile(userID: String) async throws -> CKRecord? {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        
        do {
            let results = try await publicDatabase.records(matching: query)
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
        let predicate = NSPredicate(format: "username == %@", username.lowercased())
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        
        do {
            let results = try await publicDatabase.records(matching: query)
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
        guard let userID = getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }
        
        let imageAsset = try await createImageAsset(from: image)
        profile["profileImageAsset"] = imageAsset
        profile["updatedAt"] = Date()
        
        _ = try await publicDatabase.save(profile)
    }
    
    func updateBio(_ bio: String) async throws {
        guard let userID = getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }
        
        profile["bio"] = bio
        profile["updatedAt"] = Date()
        
        _ = try await publicDatabase.save(profile)
    }
    
    // MARK: - Profile Stats
    func incrementRecipesShared() async throws {
        guard let userID = getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }
        
        let currentCount = profile["recipesShared"] as? Int ?? 0
        profile["recipesShared"] = currentCount + 1
        profile["updatedAt"] = Date()
        
        _ = try await publicDatabase.save(profile)
    }
    
    func updatePoints(_ points: Int) async throws {
        guard let userID = getCurrentUserID(),
              let profile = try await fetchUserProfile(userID: userID) else {
            throw CloudKitUserError.notAuthenticated
        }
        
        profile["totalPoints"] = points
        profile["updatedAt"] = Date()
        
        _ = try await publicDatabase.save(profile)
    }
    
    // MARK: - Helper Methods
    private func getCurrentUserID() -> String? {
        // Try both keys for compatibility
        if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
            return userID
        }
        return UserDefaults.standard.string(forKey: "currentUserRecordID")
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
        let predicate = NSPredicate(format: "username CONTAINS[cd] %@ OR displayName CONTAINS[cd] %@", query, query)
        let ckQuery = CKQuery(recordType: "UserProfile", predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "totalPoints", ascending: false)]
        
        do {
            let results = try await publicDatabase.records(matching: ckQuery)
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
}