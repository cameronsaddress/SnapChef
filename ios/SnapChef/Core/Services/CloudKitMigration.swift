import Foundation
import CloudKit

/// Utility class for migrating and fixing CloudKit data
@MainActor
class CloudKitMigration {
    static let shared = CloudKitMigration()
    private let database = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase
    
    private init() {}
    
    /// Migrate all Follow records to ensure consistent ID format and update user counts
    func migrateFollowRecordsAndUpdateCounts() async {
        print("🔄 Starting CloudKit Follow records migration and count update...")
        
        do {
            // Step 1: Fetch all Follow records
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "Follow", predicate: predicate)
            let results = try await database.records(matching: query)
            
            var recordsToUpdate: [CKRecord] = []
            var followCounts: [String: (followers: Int, following: Int)] = [:]
            
            print("📊 Found \(results.matchResults.count) Follow records to process")
            
            // Step 2: Process each Follow record
            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    var needsUpdate = false
                    let isActive = record["isActive"] as? Int64 ?? 1
                    
                    // Skip inactive records
                    if isActive != 1 {
                        continue
                    }
                    
                    // Get current IDs
                    var followerID = record["followerID"] as? String ?? ""
                    var followingID = record["followingID"] as? String ?? ""
                    
                    // Normalize IDs - remove "user_" prefix if present
                    // We want IDs stored without prefix in Follow records
                    if !followerID.isEmpty && followerID.hasPrefix("user_") {
                        let normalizedFollowerID = String(followerID.dropFirst(5))
                        record["followerID"] = normalizedFollowerID
                        print("  📝 Normalizing followerID: \(followerID) -> \(normalizedFollowerID)")
                        followerID = normalizedFollowerID
                        needsUpdate = true
                    }
                    
                    // Normalize followingID
                    if !followingID.isEmpty && followingID.hasPrefix("user_") {
                        let normalizedFollowingID = String(followingID.dropFirst(5))
                        record["followingID"] = normalizedFollowingID
                        print("  📝 Normalizing followingID: \(followingID) -> \(normalizedFollowingID)")
                        followingID = normalizedFollowingID
                        needsUpdate = true
                    }
                    
                    if needsUpdate {
                        recordsToUpdate.append(record)
                    }
                    
                    // Count followers and following for each user
                    // Use normalized IDs for counting
                    
                    // Increment following count for follower
                    if !followerID.isEmpty {
                        var counts = followCounts[followerID] ?? (followers: 0, following: 0)
                        counts.following += 1
                        followCounts[followerID] = counts
                    }
                    
                    // Increment follower count for following
                    if !followingID.isEmpty {
                        var counts = followCounts[followingID] ?? (followers: 0, following: 0)
                        counts.followers += 1
                        followCounts[followingID] = counts
                    }
                }
            }
            
            // Step 3: Update Follow records if needed
            if !recordsToUpdate.isEmpty {
                print("📤 Updating \(recordsToUpdate.count) Follow records with corrected IDs...")
                for record in recordsToUpdate {
                    do {
                        _ = try await database.save(record)
                        print("  ✅ Updated Follow record: \(record.recordID.recordName)")
                    } catch {
                        print("  ❌ Failed to update Follow record: \(error)")
                    }
                }
            }
            
            // Step 4: Update User records with correct counts
            print("📊 Updating counts for \(followCounts.count) users...")
            for (userID, counts) in followCounts {
                await updateUserCounts(userID: userID, followerCount: counts.followers, followingCount: counts.following)
            }
            
            print("✅ Migration completed successfully!")
            
        } catch {
            print("❌ Migration failed: \(error)")
        }
    }
    
    /// Update a specific user's follower and following counts
    private func updateUserCounts(userID: String, followerCount: Int, followingCount: Int) async {
        do {
            // Fetch the user record
            let recordID = CKRecord.ID(recordName: userID)
            let userRecord = try await database.record(for: recordID)
            
            // Update counts
            let currentFollowers = Int(userRecord[CKField.User.followerCount] as? Int64 ?? 0)
            let currentFollowing = Int(userRecord[CKField.User.followingCount] as? Int64 ?? 0)
            
            if currentFollowers != followerCount || currentFollowing != followingCount {
                userRecord[CKField.User.followerCount] = Int64(followerCount)
                userRecord[CKField.User.followingCount] = Int64(followingCount)
                
                _ = try await database.save(userRecord)
                print("  ✅ Updated user \(userID): Followers \(currentFollowers) -> \(followerCount), Following \(currentFollowing) -> \(followingCount)")
            } else {
                print("  ⏭️ User \(userID) counts already correct: Followers \(followerCount), Following \(followingCount)")
            }
        } catch {
            print("  ❌ Failed to update user \(userID): \(error)")
        }
    }
    
    /// Recalculate and update all user social counts based on Follow records
    func recalculateAllUserCounts() async {
        print("🔄 Recalculating all user social counts...")
        
        do {
            // Get all users
            let userPredicate = NSPredicate(value: true)
            let userQuery = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: userPredicate)
            let userResults = try await database.records(matching: userQuery)
            
            print("📊 Found \(userResults.matchResults.count) users to update")
            
            for (_, result) in userResults.matchResults {
                if case .success(let userRecord) = result {
                    let fullRecordName = userRecord.recordID.recordName
                    // Normalize the ID (remove "user_" prefix if present)
                    let userID = fullRecordName.hasPrefix("user_") ? String(fullRecordName.dropFirst(5)) : fullRecordName
                    print("  🔄 Updating counts for user: \(userID)")
                    
                    // Count followers (people following this user) - use normalized ID
                    let followerPredicate = NSPredicate(format: "followingID == %@ AND isActive == 1", userID)
                    let followerQuery = CKQuery(recordType: "Follow", predicate: followerPredicate)
                    let followerResults = try await database.records(matching: followerQuery)
                    let followerCount = followerResults.matchResults.count
                    
                    // Count following (people this user follows) - use normalized ID
                    let followingPredicate = NSPredicate(format: "followerID == %@ AND isActive == 1", userID)
                    let followingQuery = CKQuery(recordType: "Follow", predicate: followingPredicate)
                    let followingResults = try await database.records(matching: followingQuery)
                    let followingCount = followingResults.matchResults.count
                    
                    // Update user record
                    userRecord[CKField.User.followerCount] = Int64(followerCount)
                    userRecord[CKField.User.followingCount] = Int64(followingCount)
                    
                    _ = try await database.save(userRecord)
                    print("    ✅ Updated: Followers: \(followerCount), Following: \(followingCount)")
                }
            }
            
            print("✅ All user counts updated successfully!")
            
        } catch {
            print("❌ Failed to recalculate counts: \(error)")
        }
    }
    
    /// Generate usernames for users who don't have one
    func generateMissingUsernames() async {
        print("🔄 Generating usernames for users without them...")
        
        do {
            // Fetch users without usernames
            let predicate = NSPredicate(format: "username == nil OR username == %@", "")
            let query = CKQuery(recordType: CloudKitConfig.userRecordType, predicate: predicate)
            let results = try await database.records(matching: query)
            
            print("📊 Found \(results.matchResults.count) users without usernames")
            
            for (_, result) in results.matchResults {
                if case .success(let userRecord) = result {
                    let recordID = userRecord.recordID.recordName
                    let normalizedID = recordID.hasPrefix("user_") ? String(recordID.dropFirst(5)) : recordID
                    
                    // Generate username from email or recordID
                    var generatedUsername: String
                    
                    if let email = userRecord[CKField.User.email] as? String,
                       !email.isEmpty,
                       let emailPrefix = email.split(separator: "@").first {
                        // Use email prefix
                        generatedUsername = String(emailPrefix).lowercased()
                            .replacingOccurrences(of: ".", with: "")
                            .replacingOccurrences(of: "_", with: "")
                            .replacingOccurrences(of: "-", with: "")
                    } else if let displayName = userRecord[CKField.User.displayName] as? String,
                              !displayName.isEmpty,
                              displayName != "Anonymous Chef" {
                        // Use display name
                        generatedUsername = displayName.lowercased()
                            .replacingOccurrences(of: " ", with: "")
                            .replacingOccurrences(of: ".", with: "")
                            .replacingOccurrences(of: "_", with: "")
                    } else {
                        // Use record ID suffix
                        let idSuffix = String(normalizedID.suffix(6))
                        generatedUsername = "user\(idSuffix)"
                    }
                    
                    // Ensure uniqueness by adding random numbers if needed
                    if generatedUsername.count < 3 {
                        generatedUsername = "chef" + String(Int.random(in: 10000...99999))
                    }
                    
                    // Update the record
                    userRecord[CKField.User.username] = generatedUsername
                    
                    // If displayName is missing or "Anonymous Chef", update it too
                    let currentDisplayName = userRecord[CKField.User.displayName] as? String
                    if currentDisplayName == nil || currentDisplayName == "Anonymous Chef" || currentDisplayName!.isEmpty {
                        userRecord[CKField.User.displayName] = generatedUsername.capitalized
                    }
                    
                    _ = try await database.save(userRecord)
                    print("  ✅ Generated username '\(generatedUsername)' for user \(normalizedID)")
                }
            }
            
            print("✅ Username generation complete!")
            
        } catch {
            print("❌ Failed to generate usernames: \(error)")
        }
    }
    
    /// Run all migration tasks
    func runFullMigration() async {
        print("🚀 Starting full CloudKit migration...")
        
        // 1. Fix Follow records and update counts
        await migrateFollowRecordsAndUpdateCounts()
        
        // 2. Recalculate all user counts
        await recalculateAllUserCounts()
        
        // 3. Generate missing usernames
        await generateMissingUsernames()
        
        print("✅ Full migration complete!")
    }
}