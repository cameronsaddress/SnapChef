//
//  CloudKitActor.swift
//  SnapChef
//
//  Created to handle CloudKit operations in a Swift 6 compliant way
//

import CloudKit
import Foundation

/// Actor that handles all CloudKit operations in a thread-safe manner
/// This prevents dispatch queue assertion failures by ensuring consistent execution context
actor CloudKitActor {
    private let database: CKDatabase
    private let container: CKContainer
    
    init(containerIdentifier: String = CloudKitConfig.containerIdentifier) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.publicCloudDatabase
    }
    
    // MARK: - Record Operations
    
    /// Fetch a single record by ID using operation-based API to avoid dispatch queue issues
    func fetchRecord(with id: CKRecord.ID) async throws -> CKRecord {
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchRecordsOperation(recordIDs: [id])
            
            // Critical: Prevent double-resume which causes crashes
            var hasResumed = false
            let resumeLock = NSLock()
            
            operation.perRecordResultBlock = { recordID, result in
                resumeLock.lock()
                defer { resumeLock.unlock() }
                
                guard !hasResumed else {
                    print("⚠️ CloudKitActor: Prevented double-resume in fetchRecord for \(recordID.recordName)")
                    return
                }
                hasResumed = true
                
                switch result {
                case .success(let record):
                    continuation.resume(returning: record)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            operation.qualityOfService = .userInitiated
            database.add(operation)
        }
    }
    
    /// Save a single record using operation-based API to avoid dispatch queue issues
    func saveRecord(_ record: CKRecord) async throws -> CKRecord {
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            
            // Critical: Prevent double-resume which causes crashes
            var hasResumed = false
            let resumeLock = NSLock()
            
            operation.perRecordSaveBlock = { recordID, result in
                resumeLock.lock()
                defer { resumeLock.unlock() }
                
                guard !hasResumed else {
                    print("⚠️ CloudKitActor: Prevented double-resume in saveRecord for \(recordID.recordName)")
                    return
                }
                hasResumed = true
                
                switch result {
                case .success(let savedRecord):
                    continuation.resume(returning: savedRecord)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            operation.qualityOfService = .userInitiated
            operation.savePolicy = .changedKeys
            database.add(operation)
        }
    }
    
    /// Delete a record by ID
    func deleteRecord(with id: CKRecord.ID) async throws {
        try await database.deleteRecord(withID: id)
    }
    
    // MARK: - Query Operations
    
    /// Execute a query using operation-based API to avoid dispatch queue issues
    func executeQuery(_ query: CKQuery, in zone: CKRecordZone.ID? = nil) async throws -> [CKRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(query: query)
            var records: [CKRecord] = []
            
            // Critical: Prevent double-resume which causes crashes
            var hasResumed = false
            let resumeLock = NSLock()
            
            operation.recordMatchedBlock = { _, result in
                // Don't need lock here as we're just appending to array
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure:
                    break // Skip failed records
                }
            }
            
            operation.queryResultBlock = { result in
                resumeLock.lock()
                defer { resumeLock.unlock() }
                
                guard !hasResumed else {
                    print("⚠️ CloudKitActor: Prevented double-resume in executeQuery")
                    return
                }
                hasResumed = true
                
                switch result {
                case .success:
                    continuation.resume(returning: records)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            operation.qualityOfService = .userInitiated
            if let zone = zone {
                operation.zoneID = zone
            }
            database.add(operation)
        }
    }
    
    /// Execute a query with desired keys using operation-based API
    func executeQuery(_ query: CKQuery, desiredKeys: [String]?, resultsLimit: Int = CKQueryOperation.maximumResults) async throws -> [CKRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(query: query)
            var records: [CKRecord] = []
            
            // Critical: Prevent double-resume which causes crashes
            var hasResumed = false
            let resumeLock = NSLock()
            
            operation.desiredKeys = desiredKeys
            operation.resultsLimit = resultsLimit
            
            operation.recordMatchedBlock = { _, result in
                // Don't need lock here as we're just appending to array
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure:
                    break // Skip failed records
                }
            }
            
            operation.queryResultBlock = { result in
                resumeLock.lock()
                defer { resumeLock.unlock() }
                
                guard !hasResumed else {
                    print("⚠️ CloudKitActor: Prevented double-resume in executeQuery with desiredKeys")
                    return
                }
                hasResumed = true
                
                switch result {
                case .success:
                    continuation.resume(returning: records)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            operation.qualityOfService = .userInitiated
            database.add(operation)
        }
    }
    
    // MARK: - Batch Operations
    
    /// Modify multiple records at once
    func modifyRecords(recordsToSave: [CKRecord]?, recordIDsToDelete: [CKRecord.ID]?) async throws -> ([CKRecord], [CKRecord.ID]) {
        let (saveResults, deleteResults) = try await database.modifyRecords(
            saving: recordsToSave ?? [],
            deleting: recordIDsToDelete ?? []
        )
        
        var savedRecords: [CKRecord] = []
        for (_, result) in saveResults {
            if case .success(let record) = result {
                savedRecords.append(record)
            }
        }
        
        var deletedIDs: [CKRecord.ID] = []
        for (_, result) in deleteResults {
            if case .success = result {
                // Record was deleted successfully
                if let id = recordIDsToDelete?.first(where: { _ in true }) {
                    deletedIDs.append(id)
                }
            }
        }
        
        return (savedRecords, deletedIDs)
    }
    
    // MARK: - Subscription Operations
    
    /// Create a subscription
    func createSubscription(_ subscription: CKSubscription) async throws -> CKSubscription {
        return try await database.save(subscription)
    }
    
    /// Delete a subscription
    func deleteSubscription(with id: CKSubscription.ID) async throws {
        try await database.deleteSubscription(withID: id)
    }
    
    // MARK: - User Operations
    
    /// Fetch the current user record ID
    func fetchUserRecordID() async throws -> CKRecord.ID {
        return try await container.userRecordID()
    }
    
    /// Check if user is signed into iCloud
    func checkAccountStatus() async throws -> CKAccountStatus {
        return try await container.accountStatus()
    }
}

// MARK: - Convenience Extensions

extension CloudKitActor {
    /// Fetch user record by user ID (without "user_" prefix)
    func fetchUserRecord(userID: String) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: "user_\(userID)")
        return try await fetchRecord(with: recordID)
    }
    
    /// Count records matching a query
    func countRecords(matching query: CKQuery) async throws -> Int {
        let records = try await executeQuery(query, desiredKeys: nil, resultsLimit: 1000)
        return records.count
    }
    
    /// Fetch Follow records for social counts
    func fetchFollowCounts(for userID: String) async throws -> (followers: Int, following: Int) {
        // The userID passed in is the internal CloudKit ID (like "_abc123")
        // Follow records use "user_" prefix, so it becomes "user__abc123"
        let followRecordID = userID.hasPrefix("user_") ? userID : "user_\(userID)"
        
        print("🔍 DEBUG fetchFollowCounts:")
        print("   Input userID: \(userID)")
        print("   Follow record ID: \(followRecordID)")
        
        // Query for followers (people who follow this user)
        let followerPredicate = NSPredicate(format: "followingID == %@ AND isActive == 1", followRecordID)
        let followerQuery = CKQuery(recordType: "Follow", predicate: followerPredicate)
        let followers = try await executeQuery(followerQuery, desiredKeys: ["followerID"])
        print("   Followers found: \(followers.count)")
        
        // Query for following (people this user follows)  
        let followingPredicate = NSPredicate(format: "followerID == %@ AND isActive == 1", followRecordID)
        let followingQuery = CKQuery(recordType: "Follow", predicate: followingPredicate)
        let following = try await executeQuery(followingQuery, desiredKeys: ["followingID"])
        print("   Following found: \(following.count)")
        
        return (followers.count, following.count)
    }
    
    /// Fetch recipe count for a user
    func fetchRecipeCount(for userID: String) async throws -> Int {
        let recipePredicate = NSPredicate(format: "%K == %@", CKField.Recipe.ownerID, userID)
        let recipeQuery = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: recipePredicate)
        let recipes = try await executeQuery(recipeQuery, desiredKeys: nil)
        return recipes.count
    }
    
    /// Execute a query and return results matching format (for compatibility)
    func executeQueryWithResults(_ query: CKQuery) async throws -> (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?) {
        let records = try await executeQuery(query)
        let matchResults = records.map { record in
            (record.recordID, Result<CKRecord, Error>.success(record))
        }
        return (matchResults: matchResults, queryCursor: nil)
    }
}