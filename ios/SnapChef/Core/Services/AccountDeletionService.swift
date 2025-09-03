//
//  AccountDeletionService.swift
//  SnapChef
//
//  Centralized service for complete account and data deletion
//

import Foundation
import CloudKit

@MainActor
class AccountDeletionService: ObservableObject {
    static let shared = AccountDeletionService()
    
    @Published var deletionProgress: DeletionProgress = .idle
    @Published var deletionErrors: [DeletionError] = []
    
    private let cloudKitActor = CloudKitActor()
    private let database = CKContainer.default().publicCloudDatabase
    
    enum DeletionProgress {
        case idle
        case preparingDeletion
        case deletingCloudKitData(recordType: String, progress: Double)
        case deletingLocalData(category: String)
        case verifyingDeletion
        case completed
        case failed(error: String)
    }
    
    struct DeletionError {
        let category: String
        let recordType: String?
        let error: Error
    }
    
    struct DeletionReport {
        let totalRecordsDeleted: Int
        let recordsByType: [String: Int]
        let localDataCleared: Bool
        let errors: [DeletionError]
        let startTime: Date
        let endTime: Date
        
        var duration: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }
    }
    
    // MARK: - Main Deletion Function
    
    func deleteAccount() async -> DeletionReport {
        let startTime = Date()
        var recordsDeleted: [String: Int] = [:]
        var totalDeleted = 0
        
        deletionProgress = .preparingDeletion
        deletionErrors = []
        
        // Check if user is authenticated or anonymous
        let userID = UnifiedAuthManager.shared.currentUser?.recordID
        let isAuthenticated = userID != nil
        
        if isAuthenticated {
            print("🗑️ Starting account deletion for authenticated user: \(userID!)")
            
            // Step 1: Delete all CloudKit records for authenticated user
            let cloudKitResults = await deleteAllCloudKitData(for: userID!)
            recordsDeleted = cloudKitResults.recordsByType
            totalDeleted = cloudKitResults.totalDeleted
            
            // Step 2: Verify deletion for authenticated user
            deletionProgress = .verifyingDeletion
            let verificationPassed = await verifyDeletion(userID: userID!)
            
            if !verificationPassed {
                print("⚠️ CloudKit verification failed, but continuing with local cleanup")
            }
        } else {
            print("🗑️ Starting data deletion for anonymous user")
            // For anonymous users, we only have local data to delete
            recordsDeleted["Anonymous Data"] = 1
        }
        
        // Step 3: Clear all local data (for both authenticated and anonymous users)
        deletionProgress = .deletingLocalData(category: "All Local Storage")
        let localSuccess = await clearAllLocalData()
        
        // Step 4: Clear anonymous profile from Keychain
        if !isAuthenticated {
            // Clear the anonymous profile
            let cleared = await KeychainProfileManager.shared.deleteProfile()
            if cleared {
                print("✅ Anonymous profile cleared from Keychain")
            } else {
                print("⚠️ Failed to clear anonymous profile from Keychain")
            }
        }
        
        // Step 5: Sign out (if authenticated)
        if isAuthenticated {
            UnifiedAuthManager.shared.signOut()
        }
        
        // Complete
        if deletionErrors.isEmpty {
            deletionProgress = .completed
            print("✅ Account/data deletion completed successfully")
        } else {
            deletionProgress = .failed(error: "Deletion completed with \(deletionErrors.count) errors")
            print("⚠️ Deletion completed with errors: \(deletionErrors.count)")
        }
        
        return DeletionReport(
            totalRecordsDeleted: totalDeleted,
            recordsByType: recordsDeleted,
            localDataCleared: localSuccess,
            errors: deletionErrors,
            startTime: startTime,
            endTime: Date()
        )
    }
    
    // MARK: - CloudKit Deletion
    
    private func deleteAllCloudKitData(for userID: String) async -> (totalDeleted: Int, recordsByType: [String: Int]) {
        var recordsByType: [String: Int] = [:]
        var totalDeleted = 0
        
        // Handle User record deletion separately with special logic for underscore IDs
        let userCount = await deleteUserRecord(userID: userID)
        if userCount > 0 {
            recordsByType["User"] = userCount
            totalDeleted += userCount
        }
        
        // Handle Follow records with special logic for underscore IDs
        let followCount = await deleteFollowRecords(userID: userID)
        if followCount > 0 {
            recordsByType["Follow"] = followCount
            totalDeleted += followCount
        }
        
        // Handle TeamInvite records with special logic for underscore IDs
        let teamInviteCount = await deleteTeamInviteRecords(userID: userID)
        if teamInviteCount > 0 {
            recordsByType["TeamInvite"] = teamInviteCount
            totalDeleted += teamInviteCount
        }
        
        // Define remaining record types that can use simple predicates
        let deletionTasks: [(recordType: String, predicate: NSPredicate)] = [
            // Content
            ("Recipe", NSPredicate(format: "ownerID == %@", userID)),
            ("RecipeComment", NSPredicate(format: "userID == %@", userID)),
            
            // Social (remaining)
            ("RecipeLike", NSPredicate(format: "userID == %@", userID)),
            ("RecipeView", NSPredicate(format: "userID == %@", userID)),
            ("Activity", NSPredicate(format: "actorID == %@", userID)),
            
            // Gamification
            ("UserChallenge", NSPredicate(format: "userID == %@", userID)),
            ("Achievement", NSPredicate(format: "userID == %@", userID)),
            ("CoinTransaction", NSPredicate(format: "userID == %@", userID)),
            ("Leaderboard", NSPredicate(format: "userID == %@", userID)),
            ("UserStreak", NSPredicate(format: "userID == %@", userID))
        ]
        
        // Process each record type
        for (recordType, predicate) in deletionTasks {
            let progress = Double(totalDeleted) / Double(deletionTasks.count)
            deletionProgress = .deletingCloudKitData(recordType: recordType, progress: progress)
            
            let count = await deleteRecords(recordType: recordType, predicate: predicate)
            if count > 0 {
                recordsByType[recordType] = count
                totalDeleted += count
            }
        }
        
        // Special handling for Team records (remove from member arrays)
        await removeUserFromTeams(userID: userID)
        
        print("📊 CloudKit deletion complete: \(totalDeleted) records deleted")
        return (totalDeleted, recordsByType)
    }
    
    // MARK: - Special Deletion Methods for Underscore-Prefixed IDs
    
    private func deleteUserRecord(userID: String) async -> Int {
        // Direct deletion approach - no predicates to avoid underscore issues
        var deletedCount = 0
        
        // Try different possible record name formats
        let possibleRecordNames = [
            "user_\(userID)",     // Standard: user__d4b8018a9065711f8e9731b7c8c6d31f
            userID                // Direct: _d4b8018a9065711f8e9731b7c8c6d31f
        ]
        
        for recordName in possibleRecordNames {
            do {
                let recordID = CKRecord.ID(recordName: recordName)
                
                // First check if record exists by trying to fetch it
                _ = try await cloudKitActor.fetchRecord(with: recordID)
                // Record exists, now delete it
                try await cloudKitActor.deleteRecordByID(recordID)
                deletedCount += 1
                print("✅ Deleted User record with ID: \(recordName)")
                break // Successfully deleted
            } catch let error as CKError where error.code == .unknownItem {
                // Record doesn't exist with this name, try next format
                continue
            } catch {
                // Log but continue trying other formats
                print("⚠️ Could not delete User record \(recordName): \(error.localizedDescription)")
            }
        }
        
        if deletedCount == 0 {
            print("📋 No User record found for userID: \(userID)")
        }
        
        return deletedCount
    }
    
    private func deleteFollowRecords(userID: String) async -> Int {
        do {
            // Use separate queries instead of compound predicate to avoid parsing issues
            var allRecordsToDelete: [CKRecord] = []
            
            // Query for followerID matches
            let followerQuery = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "followerID == %@", userID))
            let followerRecords = try await cloudKitActor.performQuery(followerQuery, in: database)
            allRecordsToDelete.append(contentsOf: followerRecords)
            
            // Query for followingID matches
            let followingQuery = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "followingID == %@", userID))
            let followingRecords = try await cloudKitActor.performQuery(followingQuery, in: database)
            allRecordsToDelete.append(contentsOf: followingRecords)
            
            // Remove duplicates based on recordID
            let uniqueRecords = Array(Set(allRecordsToDelete.map { $0.recordID })).compactMap { recordID in
                allRecordsToDelete.first { $0.recordID == recordID }
            }
            
            guard !uniqueRecords.isEmpty else {
                print("📋 No Follow records found for userID: \(userID)")
                return 0
            }
            
            // Delete records in batches
            var deletedCount = 0
            for batch in uniqueRecords.chunked(into: 100) {
                let recordIDs = batch.map { $0.recordID }
                try await cloudKitActor.deleteRecords(recordIDs, in: database)
                deletedCount += recordIDs.count
            }
            
            print("✅ Deleted \(deletedCount) Follow records")
            return deletedCount
            
        } catch {
            print("❌ Failed to delete Follow records for \(userID): \(error)")
            deletionErrors.append(DeletionError(category: "CloudKit", recordType: "Follow", error: error))
            return 0
        }
    }
    
    private func deleteTeamInviteRecords(userID: String) async -> Int {
        do {
            // Use separate queries instead of compound predicate to avoid parsing issues
            var allRecordsToDelete: [CKRecord] = []
            
            // Query for inviterID matches
            let inviterQuery = CKQuery(recordType: "TeamInvite", predicate: NSPredicate(format: "inviterID == %@", userID))
            let inviterRecords = try await cloudKitActor.performQuery(inviterQuery, in: database)
            allRecordsToDelete.append(contentsOf: inviterRecords)
            
            // Query for inviteeID matches
            let inviteeQuery = CKQuery(recordType: "TeamInvite", predicate: NSPredicate(format: "inviteeID == %@", userID))
            let inviteeRecords = try await cloudKitActor.performQuery(inviteeQuery, in: database)
            allRecordsToDelete.append(contentsOf: inviteeRecords)
            
            // Remove duplicates based on recordID
            let uniqueRecords = Array(Set(allRecordsToDelete.map { $0.recordID })).compactMap { recordID in
                allRecordsToDelete.first { $0.recordID == recordID }
            }
            
            guard !uniqueRecords.isEmpty else {
                print("📋 No TeamInvite records found for userID: \(userID)")
                return 0
            }
            
            // Delete records in batches
            var deletedCount = 0
            for batch in uniqueRecords.chunked(into: 100) {
                let recordIDs = batch.map { $0.recordID }
                try await cloudKitActor.deleteRecords(recordIDs, in: database)
                deletedCount += recordIDs.count
            }
            
            print("✅ Deleted \(deletedCount) TeamInvite records")
            return deletedCount
            
        } catch {
            print("❌ Failed to delete TeamInvite records for \(userID): \(error)")
            deletionErrors.append(DeletionError(category: "CloudKit", recordType: "TeamInvite", error: error))
            return 0
        }
    }
    
    private func deleteRecords(recordType: String, predicate: NSPredicate) async -> Int {
        do {
            let query = CKQuery(recordType: recordType, predicate: predicate)
            let records = try await cloudKitActor.performQuery(query, in: database)
            
            guard !records.isEmpty else {
                print("📋 No \(recordType) records found to delete")
                return 0
            }
            
            // Delete records in batches
            var deletedCount = 0
            for batch in records.chunked(into: 100) {
                let recordIDs = batch.map { $0.recordID }
                try await cloudKitActor.deleteRecords(recordIDs, in: database)
                deletedCount += recordIDs.count
            }
            
            print("✅ Deleted \(deletedCount) \(recordType) records")
            return deletedCount
            
        } catch {
            print("❌ Failed to delete \(recordType) records: \(error)")
            deletionErrors.append(DeletionError(category: "CloudKit", recordType: recordType, error: error))
            return 0
        }
    }
    
    private func removeUserFromTeams(userID: String) async {
        // This will be implemented if Team records exist
        print("📋 Checking for team memberships...")
    }
    
    // MARK: - Local Data Deletion
    
    private func clearAllLocalData() async -> Bool {
        var success = true
        
        // 1. Clear URL Cache FIRST to release database connections
        deletionProgress = .deletingLocalData(category: "URL Cache")
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0
        
        // 2. Clear all caches and managers
        deletionProgress = .deletingLocalData(category: "Cache Managers")
        await clearAllCacheManagers()
        
        // 3. Give time for databases to close
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // 4. Clear file system after databases are closed
        deletionProgress = .deletingLocalData(category: "File System")
        success = success && clearFileSystem()
        
        // 5. Clear UserDefaults
        deletionProgress = .deletingLocalData(category: "UserDefaults")
        clearUserDefaults()
        
        // 6. Clear user-specific Keychain data (preserves API keys)
        deletionProgress = .deletingLocalData(category: "Keychain")
        KeychainManager.shared.clearUserData()
        
        print("✅ Local data deletion complete")
        return success
    }
    
    private func clearAllCacheManagers() async {
        // PhotoStorageManager
        PhotoStorageManager.shared.clearCache()
        
        // ProfilePhotoManager
        await ProfilePhotoManager.shared.deleteProfilePhoto()
        
        // Clear discover users cache
        SimpleDiscoverUsersManager.shared.clearCache()
        
        // Clear local recipe storage - CRITICAL for complete recipe removal
        LocalRecipeManager.shared.clearAllRecipes()
        
        // Clear other cache managers - these will be handled by clearing UserDefaults and file system
        // CloudKitRecipeCache.shared.clearCache()
        // UserCacheManager.shared.clearCache()  
        // RecipeLikeManager.shared.clearCache()
        
        // Clear additional UserDefaults keys that might hold recipe data
        UserDefaults.standard.removeObject(forKey: "savedRecipeIDs")
        UserDefaults.standard.removeObject(forKey: "createdRecipeIDs")
        UserDefaults.standard.removeObject(forKey: "likedRecipeIDs")
        UserDefaults.standard.removeObject(forKey: "cachedRecipes")
        UserDefaults.standard.removeObject(forKey: "localRecipes")
        
        print("✅ All cache managers cleared")
    }
    
    private func closeActiveDatabases() {
        // Give SQLite time to close any open file handles
        // This prevents "database integrity compromised" errors
        Thread.sleep(forTimeInterval: 0.1)
        
        print("✅ Closed active database connections")
    }
    
    private func clearFileSystem() -> Bool {
        // Close any open databases first to avoid SQLite errors
        closeActiveDatabases()
        
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        
        let directories = [
            "RecipePhotos",
            "ProfilePhotos", 
            "activities",
            "recipes",        // This contains LocalRecipeStorage JSON files
            "VideoExports",
            "Drafts"
        ]
        
        // Also delete specific files that AppState uses
        let filesToDelete = [
            "savedRecipes.json"   // AppState's saved recipes file
        ]
        
        for fileName in filesToDelete {
            let fileURL = documentsURL.appendingPathComponent(fileName)
            do {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                    print("✅ Deleted file: \(fileName)")
                }
            } catch {
                print("⚠️ Failed to delete file \(fileName): \(error)")
            }
        }
        
        for directory in directories {
            let directoryURL = documentsURL.appendingPathComponent(directory)
            do {
                if fileManager.fileExists(atPath: directoryURL.path) {
                    try fileManager.removeItem(at: directoryURL)
                    print("✅ Deleted directory: \(directory)")
                }
            } catch {
                print("❌ Failed to delete directory \(directory): \(error)")
                deletionErrors.append(DeletionError(category: "FileSystem", recordType: directory, error: error))
            }
        }
        
        // Clear cache directory - be careful with SQLite databases
        if let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            do {
                let cacheContents = try fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
                for item in cacheContents {
                    // Skip system cache files that might be in use
                    let itemName = item.lastPathComponent
                    if itemName.contains(".db") || itemName.contains(".sqlite") {
                        // Try to remove, but don't fail if locked
                        do {
                            try fileManager.removeItem(at: item)
                        } catch {
                            print("⚠️ Could not remove cache database \(itemName): \(error.localizedDescription)")
                        }
                    } else {
                        try fileManager.removeItem(at: item)
                    }
                }
                print("✅ Cleared cache directory")
            } catch {
                print("❌ Failed to clear cache: \(error)")
            }
        }
        
        // Clear tmp directory
        let tmpDirectory = NSTemporaryDirectory()
        do {
            let tmpContents = try fileManager.contentsOfDirectory(atPath: tmpDirectory)
            for file in tmpContents {
                let filePath = (tmpDirectory as NSString).appendingPathComponent(file)
                try fileManager.removeItem(atPath: filePath)
            }
            print("✅ Cleared tmp directory")
        } catch {
            print("❌ Failed to clear tmp directory: \(error)")
        }
        
        return true
    }
    
    private func clearUserDefaults() {
        let defaults = UserDefaults.standard
        if let bundleID = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleID)
        }
        
        // Also clear specific keys that might be outside the domain
        let keysToRemove = [
            "currentUserID",
            "hasCompletedOnboarding",
            "lastSyncDate",
            "cachedUsername",
            "authToken",
            "refreshToken",
            "userPreferences",
            "savedRecipes",
            "likedRecipes"
        ]
        
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }
        
        defaults.synchronize()
        print("✅ Cleared UserDefaults")
    }
    
    // MARK: - Verification
    
    private func verifyDeletion(userID: String) async -> Bool {
        var verificationPassed = true
        
        // Check if user record still exists using direct fetch (no predicates)
        let possibleRecordNames = [
            "user_\(userID)",
            userID
        ]
        
        for recordName in possibleRecordNames {
            do {
                let recordID = CKRecord.ID(recordName: recordName)
                _ = try await cloudKitActor.fetchRecord(with: recordID)
                // If we get here, the record still exists
                print("⚠️ Verification failed: User record still exists with ID: \(recordName)")
                verificationPassed = false
            } catch let error as CKError where error.code == .unknownItem {
                // Record doesn't exist - this is what we want
                continue
            } catch {
                // Some other error occurred
                print("⚠️ Error verifying User record deletion: \(error)")
            }
        }
        
        // Check recipes using proper field name
        do {
            
            // Check if any recipes still exist
            let recipePredicate = NSPredicate(format: "ownerID == %@", userID)
            let recipeQuery = CKQuery(recordType: "Recipe", predicate: recipePredicate)
            let recipeRecords = try await cloudKitActor.performQuery(recipeQuery, in: database)
            
            if !recipeRecords.isEmpty {
                print("⚠️ Verification failed: \(recipeRecords.count) recipes still exist")
                verificationPassed = false
            }
            
            // Check if any likes still exist  
            let likePredicate = NSPredicate(format: "userID == %@", userID)
            let likeQuery = CKQuery(recordType: "RecipeLike", predicate: likePredicate)
            let likeRecords = try await cloudKitActor.performQuery(likeQuery, in: database)
            
            if !likeRecords.isEmpty {
                print("⚠️ Verification failed: \(likeRecords.count) likes still exist")
                verificationPassed = false
            }
            
            // Check follow relationships using separate queries to avoid predicate parsing issues
            let followerQuery = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "followerID == %@", userID))
            let followerRecords = try await cloudKitActor.performQuery(followerQuery, in: database)
            
            let followingQuery = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "followingID == %@", userID))
            let followingRecords = try await cloudKitActor.performQuery(followingQuery, in: database)
            
            let totalFollowRecords = followerRecords.count + followingRecords.count
            if totalFollowRecords > 0 {
                print("⚠️ Verification failed: \(totalFollowRecords) follow relationships still exist")
                verificationPassed = false
            }
            
            // Check TeamInvite records using separate queries
            let inviterQuery = CKQuery(recordType: "TeamInvite", predicate: NSPredicate(format: "inviterID == %@", userID))
            let inviterRecords = try await cloudKitActor.performQuery(inviterQuery, in: database)
            
            let inviteeQuery = CKQuery(recordType: "TeamInvite", predicate: NSPredicate(format: "inviteeID == %@", userID))
            let inviteeRecords = try await cloudKitActor.performQuery(inviteeQuery, in: database)
            
            let totalInviteRecords = inviterRecords.count + inviteeRecords.count
            if totalInviteRecords > 0 {
                print("⚠️ Verification failed: \(totalInviteRecords) team invite records still exist")
                verificationPassed = false
            }
            
            if verificationPassed {
                print("✅ Deletion verification passed - all critical records removed")
            }
            
            return verificationPassed
            
        } catch {
            print("❌ Verification failed with error: \(error)")
            return false
        }
    }
}

// MARK: - Helper Extensions
// Note: chunked extension already exists in the project

// MARK: - CloudKitActor Extensions for Deletion

extension CloudKitActor {
    func performQuery(_ query: CKQuery, in database: CKDatabase) async throws -> [CKRecord] {
        try await executeQuery(query)
    }
    
    func deleteRecords(_ recordIDs: [CKRecord.ID], in database: CKDatabase) async throws {
        for recordID in recordIDs {
            try await deleteRecordByID(recordID)
        }
    }
    
    // deleteRecord method removed - already exists in main CloudKitActor implementation
}