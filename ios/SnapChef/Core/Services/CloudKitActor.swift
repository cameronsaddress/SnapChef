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
    private let containerIdentifier: String

    private lazy var container: CKContainer? = {
        CloudKitRuntimeSupport.makeContainer(identifier: containerIdentifier)
    }()

    private var database: CKDatabase? {
        container?.publicCloudDatabase
    }

    private func unavailableRuntimeError(for operation: String) -> Error {
        NSError(
            domain: "CloudKitRuntimeSupport",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "CloudKit unavailable for \(operation) in current runtime."
            ]
        )
    }

    private func requireDatabase(for operation: String) throws -> CKDatabase {
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            throw unavailableRuntimeError(for: operation)
        }
        guard let database else {
            throw unavailableRuntimeError(for: operation)
        }
        return database
    }

    private func requireContainer(for operation: String) throws -> CKContainer {
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            throw unavailableRuntimeError(for: operation)
        }
        guard let container else {
            throw unavailableRuntimeError(for: operation)
        }
        return container
    }
    
    init(containerIdentifier: String = CloudKitConfig.containerIdentifier) {
        self.containerIdentifier = containerIdentifier
    }
    
    // MARK: - Record Operations
    
    /// Fetch a single record by ID using operation-based API to avoid dispatch queue issues
    func fetchRecord(with id: CKRecord.ID) async throws -> CKRecord {
        let database = try requireDatabase(for: "fetchRecord")
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
        let database = try requireDatabase(for: "saveRecord")
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
    func deleteRecordByID(_ id: CKRecord.ID) async throws {
        let database = try requireDatabase(for: "deleteRecordByID")
        try await database.deleteRecord(withID: id)
    }
    
    // MARK: - Query Operations
    
    /// Execute a query using operation-based API to avoid dispatch queue issues
    func executeQuery(_ query: CKQuery, in zone: CKRecordZone.ID? = nil) async throws -> [CKRecord] {
        let database = try requireDatabase(for: "executeQuery")
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(query: query)
            var records: [CKRecord] = []
            let recordsLock = NSLock()
            
            // Critical: Prevent double-resume which causes crashes
            var hasResumed = false
            let resumeLock = NSLock()
            
            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    recordsLock.lock()
                    records.append(record)
                    recordsLock.unlock()
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
        let database = try requireDatabase(for: "executeQuery(desiredKeys:resultsLimit:)")
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(query: query)
            var records: [CKRecord] = []
            let recordsLock = NSLock()
            
            // Critical: Prevent double-resume which causes crashes
            var hasResumed = false
            let resumeLock = NSLock()
            
            operation.desiredKeys = desiredKeys
            operation.resultsLimit = resultsLimit
            
            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    recordsLock.lock()
                    records.append(record)
                    recordsLock.unlock()
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
        let database = try requireDatabase(for: "modifyRecords")
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
        for (recordID, result) in deleteResults {
            if case .success = result {
                deletedIDs.append(recordID)
            }
        }
        
        return (savedRecords, deletedIDs)
    }
    
    // MARK: - Subscription Operations
    
    /// Create a subscription
    func createSubscription(_ subscription: CKSubscription) async throws -> CKSubscription {
        let database = try requireDatabase(for: "createSubscription")
        return try await database.save(subscription)
    }
    
    /// Delete a subscription
    func deleteSubscription(with id: CKSubscription.ID) async throws {
        let database = try requireDatabase(for: "deleteSubscription")
        try await database.deleteSubscription(withID: id)
    }
    
    // MARK: - User Operations
    
    /// Fetch the current user record ID
    func fetchUserRecordID() async throws -> CKRecord.ID {
        let container = try requireContainer(for: "fetchUserRecordID")
        return try await container.userRecordID()
    }
    
    /// Check if user is signed into iCloud
    func checkAccountStatus() async throws -> CKAccountStatus {
        let container = try requireContainer(for: "checkAccountStatus")
        return try await container.accountStatus()
    }
}

// MARK: - Convenience Extensions

extension CloudKitActor {
    /// Fetch user record by user ID
    func fetchUserRecord(userID: String) async throws -> CKRecord {
        // Check if userID already has "user_" prefix
        let recordName = userID.hasPrefix("user_") ? userID : "user_\(userID)"
        let recordID = CKRecord.ID(recordName: recordName)
        return try await fetchRecord(with: recordID)
    }
    
    /// Count records matching a query
    func countRecords(matching query: CKQuery) async throws -> Int {
        let records = try await executeQuery(query, desiredKeys: nil, resultsLimit: 1000)
        return records.count
    }
    
    /// Fetch Follow records for social counts
    func fetchFollowCounts(for userID: String) async throws -> (followers: Int, following: Int) {
        // Follow records use the userID directly without any prefix
        // UserProfileView confirms this works correctly
        
        print("🔍 DEBUG fetchFollowCounts:")
        print("   Input userID: \(userID)")
        
        // Query for followers (people who follow this user)
        let followerPredicate = NSPredicate(format: "followingID == %@ AND isActive == 1", userID)
        let followerQuery = CKQuery(recordType: "Follow", predicate: followerPredicate)
        let followers = try await executeQuery(followerQuery, desiredKeys: ["followerID"])
        print("   Followers found: \(followers.count)")
        
        // Query for following (people this user follows)  
        let followingPredicate = NSPredicate(format: "followerID == %@ AND isActive == 1", userID)
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
