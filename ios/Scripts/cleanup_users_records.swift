#!/usr/bin/env swift

import Foundation
import CloudKit

// This script will DELETE only the incorrect "Users" records from CloudKit
// while keeping the correct "User" records

class CloudKitUsersCleanup {
    let container = CKContainer.default()
    let database: CKDatabase
    
    // Set to true to actually delete (false for dry run)
    let performDelete = false // CHANGE TO true TO ACTUALLY DELETE
    
    init() {
        self.database = container.publicCloudDatabase
        
        if !performDelete {
            print("⚠️ DRY RUN MODE - No data will be deleted")
            print("Set performDelete = true to actually delete data")
        } else {
            print("🚨 WARNING: This will DELETE all 'Users' records (the wrong type)")
            print("This will KEEP all 'User' records (the correct type)")
            print("Press Ctrl+C to cancel, or wait 5 seconds to continue...")
            Thread.sleep(forTimeInterval: 5)
        }
    }
    
    func cleanupWrongUserRecords() async {
        print("\n📊 Starting cleanup of incorrect 'Users' records...")
        
        // First, let's count both types
        print("\n📈 Checking current state:")
        let usersCount = await countRecords(ofType: "Users")
        let userCount = await countRecords(ofType: "User")
        
        print("  - Found \(usersCount) 'Users' records (WRONG - will be deleted)")
        print("  - Found \(userCount) 'User' records (CORRECT - will be kept)")
        
        if usersCount > 0 {
            print("\n🗑️ Deleting all 'Users' records...")
            await deleteAllRecords(ofType: "Users")
        } else {
            print("\n✅ No 'Users' records found - nothing to clean up!")
        }
        
        print("\n✅ Cleanup complete!")
        print("  - 'User' records remain: \(userCount)")
    }
    
    func countRecords(ofType recordType: String) async -> Int {
        var count = 0
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            do {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                
                let (matchResults, nextCursor) = try await database.records(
                    matching: query,
                    desiredKeys: [],
                    resultsLimit: 100,
                    continuingMatchFrom: cursor
                )
                
                count += matchResults.count
                cursor = nextCursor
                
            } catch {
                print("  ❌ Error counting \(recordType): \(error)")
                break
            }
        } while cursor != nil
        
        return count
    }
    
    func deleteAllRecords(ofType recordType: String) async {
        var deletedCount = 0
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            do {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                
                let (matchResults, nextCursor) = try await database.records(
                    matching: query,
                    desiredKeys: [],
                    resultsLimit: 50,
                    continuingMatchFrom: cursor
                )
                
                let recordIDs = matchResults.compactMap { result -> CKRecord.ID? in
                    guard case .success(let record) = result.1 else { return nil }
                    return record.recordID
                }
                
                if !recordIDs.isEmpty {
                    if performDelete {
                        // Actually delete the records
                        for recordID in recordIDs {
                            do {
                                _ = try await database.deleteRecord(withID: recordID)
                                deletedCount += 1
                                print("  Deleted: \(recordID.recordName)")
                            } catch {
                                print("  ❌ Failed to delete \(recordID.recordName): \(error)")
                            }
                        }
                    } else {
                        print("  [DRY RUN] Would delete \(recordIDs.count) records")
                        deletedCount += recordIDs.count
                    }
                }
                
                cursor = nextCursor
                
                // Small delay to avoid rate limiting
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
            } catch {
                print("  ❌ Error querying \(recordType): \(error)")
                break
            }
        } while cursor != nil
        
        if performDelete {
            print("  ✅ Deleted \(deletedCount) \(recordType) records")
        } else {
            print("  📊 [DRY RUN] Would delete \(deletedCount) \(recordType) records")
        }
    }
}

// Run the cleanup
Task {
    let cleanup = CloudKitUsersCleanup()
    await cleanup.cleanupWrongUserRecords()
    exit(0)
}

// Keep the script running
RunLoop.main.run()