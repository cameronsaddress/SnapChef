#!/usr/bin/env swift

import Foundation
import CloudKit

// DANGER: This script will DELETE ALL DATA from CloudKit production
// Make sure you really want to do this!

class CloudKitDataDeleter {
    let container = CKContainer.default()
    let database: CKDatabase
    let batchSize = 400 // CloudKit limit per operation
    
    // Set to true to actually delete (false for dry run)
    let performDelete = false // CHANGE TO true TO ACTUALLY DELETE
    
    init(useProduction: Bool = true) {
        // Use production or development database
        self.database = useProduction ? container.publicCloudDatabase : container.publicCloudDatabase
        
        if !performDelete {
            print("⚠️ DRY RUN MODE - No data will be deleted")
            print("Set performDelete = true to actually delete data")
        } else {
            print("🚨 DANGER: This will DELETE ALL DATA from CloudKit!")
            print("Press Ctrl+C to cancel, or wait 5 seconds to continue...")
            Thread.sleep(forTimeInterval: 5)
        }
    }
    
    func deleteAllData() async {
        print("\n📊 Starting CloudKit data deletion...")
        
        // List of all record types in your schema
        let recordTypes = [
            "User",
            "Recipe",
            "Activity",
            "Challenge",
            "ChallengeProgress",
            "Achievement",
            "Leaderboard",
            "RecipeLike",
            "Team",
            "TeamMessage"
            // "UserProfile" removed - not a valid record type, use "User" instead
        ]
        
        for recordType in recordTypes {
            print("\n🗑️ Processing record type: \(recordType)")
            await deleteAllRecords(ofType: recordType)
        }
        
        print("\n✅ Deletion process complete!")
    }
    
    func deleteAllRecords(ofType recordType: String) async {
        var deletedCount = 0
        var hasMore = true
        
        while hasMore {
            do {
                // Query for records
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                query.resultsLimit = batchSize
                
                let (results, cursor) = try await database.records(matching: query)
                let records = results.compactMap { try? $0.1.get() }
                
                if records.isEmpty {
                    print("  No records found for \(recordType)")
                    hasMore = false
                    break
                }
                
                // Delete records in batches
                let recordIDs = records.map { $0.recordID }
                
                if performDelete {
                    // Actually delete the records
                    let deleteOperation = CKModifyRecordsOperation(
                        recordsToSave: nil,
                        recordIDsToDelete: recordIDs
                    )
                    
                    deleteOperation.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            print("  ✅ Deleted batch of \(recordIDs.count) records")
                        case .failure(let error):
                            print("  ❌ Error deleting batch: \(error)")
                        }
                    }
                    
                    database.add(deleteOperation)
                    
                    // Wait a bit to avoid rate limiting
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                } else {
                    print("  [DRY RUN] Would delete \(recordIDs.count) records")
                }
                
                deletedCount += records.count
                
                // Check if there are more records
                hasMore = (cursor != nil)
                
            } catch {
                print("  ❌ Error querying \(recordType): \(error)")
                hasMore = false
            }
        }
        
        if performDelete {
            print("  📊 Total deleted: \(deletedCount) \(recordType) records")
        } else {
            print("  📊 [DRY RUN] Would delete: \(deletedCount) \(recordType) records")
        }
    }
}

// Run the deletion
Task {
    let deleter = CloudKitDataDeleter(useProduction: true)
    await deleter.deleteAllData()
    exit(0)
}

// Keep the script running
RunLoop.main.run()