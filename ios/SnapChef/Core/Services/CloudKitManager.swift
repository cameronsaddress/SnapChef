import Foundation
import CloudKit
import CoreData
import Combine

/// CloudKitManager handles synchronization between Core Data and CloudKit for challenge data
@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    // MARK: - Properties
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase
    private var subscriptions = Set<AnyCancellable>()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?

    // Record types
    private let challengeRecordType = "Challenge"
    private let userChallengeRecordType = "UserChallenge"
    private let teamRecordType = "Team"
    private let teamMessageRecordType = "TeamMessage"
    private let leaderboardRecordType = "Leaderboard"
    private let achievementRecordType = "Achievement"
    private let coinTransactionRecordType = "CoinTransaction"

    // MARK: - Initialization
    private init() {
        // Initialize CloudKit container with the app's bundle identifier
        self.container = CKContainer(identifier: "iCloud.com.snapchefapp.app")
        self.privateDatabase = container.privateCloudDatabase
        self.publicDatabase = container.publicCloudDatabase

        setupSubscriptions()
        checkAccountStatus()
    }

    // MARK: - Account Status
    private func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.syncError = error
                    print("CloudKit account status error: \(error)")
                    return
                }

                switch status {
                case .available:
                    print("CloudKit account available")
                    self?.setupCloudKitSchema()
                case .noAccount:
                    print("No CloudKit account")
                case .restricted:
                    print("CloudKit access restricted")
                case .couldNotDetermine:
                    print("Could not determine CloudKit status")
                case .temporarilyUnavailable:
                    print("CloudKit temporarily unavailable")
                @unknown default:
                    print("Unknown CloudKit status")
                }
            }
        }
    }

    // MARK: - Schema Setup
    private func setupCloudKitSchema() {
        // This would typically be done in CloudKit Dashboard, but we'll define the schema here for reference
        Task {
            do {
                // Create zone for private data
                let zoneID = CKRecordZone.ID(zoneName: "ChallengesZone", ownerName: CKCurrentUserDefaultName)
                let zone = CKRecordZone(zoneID: zoneID)

                try await privateDatabase.save(zone)
                print("CloudKit zone created successfully")
            } catch {
                print("Error creating CloudKit zone: \(error)")
            }
        }
    }

    // MARK: - Subscriptions
    private func setupSubscriptions() {
        // Subscribe to challenge changes
        let challengePredicate = NSPredicate(value: true)
        let challengeSubscription = CKQuerySubscription(
            recordType: challengeRecordType,
            predicate: challengePredicate,
            subscriptionID: "challenge-updates-subscription",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        challengeSubscription.notificationInfo = notificationInfo

        publicDatabase.save(challengeSubscription) { _, error in
            if let error = error {
                print("Error creating challenge subscription: \(error)")
            } else {
                print("Challenge subscription created successfully")
            }
        }
    }

    // MARK: - Sync Operations

    /// Sync all challenges from CloudKit to Core Data
    func syncChallenges() async throws {
        await MainActor.run { isSyncing = true }

        do {
            // Fetch all public challenges
            let challenges = try await fetchPublicChallenges()

            // Core Data integration disabled - using CloudKit direct storage
            // Challenge data is stored directly in CloudKit without local Core Data cache
            print("📦 Fetched \(challenges.count) challenges from CloudKit")

            // Sync user's private challenge data
            try await syncPrivateChallengeData()

            await MainActor.run {
                lastSyncDate = Date()
                isSyncing = false
            }
        } catch {
            await MainActor.run {
                syncError = error
                isSyncing = false
            }
            throw error
        }
    }

    /// Fetch all public challenges from CloudKit
    private func fetchPublicChallenges() async throws -> [CKRecord] {
        let query = CKQuery(recordType: challengeRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let (results, nextCursor) = try await publicDatabase.records(
                matching: query,
                inZoneWith: nil,
                desiredKeys: nil,
                resultsLimit: 100
            )

            let records = results.compactMap { try? $0.1.get() }
            allRecords.append(contentsOf: records)
            cursor = nextCursor
        } while cursor != nil

        return allRecords
    }

    /// Core Data integration commented out - using CloudKit direct storage
    // Core Data entities not configured for production - using CloudKit as primary storage
    /*
    private func updateCoreDataChallenges(_ records: [CKRecord]) async throws {
        let context = PersistenceController.shared.container.viewContext
        
        for record in records {
            // Check if challenge already exists
            let fetchRequest: NSFetchRequest<ChallengeEntity> = ChallengeEntity.fetchRequest()
            // Use id field for predicate instead of recordName (which isn't queryable)
            if let entityID = record["id"] as? String {
                fetchRequest.predicate = NSPredicate(format: "id == %@", entityID)
            } else {
                fetchRequest.predicate = NSPredicate(format: "id == %@", record.recordID.recordName)
            }
            
            let existingChallenges = try context.fetch(fetchRequest)
            let challenge = existingChallenges.first ?? ChallengeEntity(context: context)
            
            // Update challenge properties
            challenge.id = UUID(uuidString: record.recordID.recordName)
            challenge.title = record["title"] as? String
            challenge.challengeDescription = record["description"] as? String
            challenge.type = record["type"] as? String
            challenge.requirement = record["requirement"] as? String
            challenge.startDate = record["startDate"] as? Date
            challenge.endDate = record["endDate"] as? Date
            challenge.isActive = record["isActive"] as? Bool ?? true
            challenge.participantCount = record["participantCount"] as? Int32 ?? 0
            challenge.updatedAt = record.modificationDate
            
            // Create or update reward
            if let rewardPoints = record["rewardPoints"] as? Int32 {
                let reward = challenge.reward ?? ChallengeRewardEntity(context: context)
                reward.points = rewardPoints
                reward.badgeName = record["rewardBadge"] as? String
                reward.title = record["rewardTitle"] as? String
                reward.unlockableContent = record["rewardUnlockable"] as? String
                challenge.reward = reward
            }
        }
        
        try context.save()
    }
    */

    /// Sync user's private challenge data (progress, participation)
    private func syncPrivateChallengeData() async throws {
        // Fetch user's challenge participation and progress
        let participantQuery = CKQuery(
            recordType: userChallengeRecordType,
            predicate: NSPredicate(format: "userID == %@", getUserId())
        )

        let progressQuery = CKQuery(
            recordType: userChallengeRecordType,
            predicate: NSPredicate(format: "userID == %@", getUserId())
        )

        // Fetch participant data from CloudKit (no Core Data cache)
        let participantRecords = try await privateDatabase.records(matching: participantQuery).0
        print("📦 Fetched \(participantRecords.count) participant records from CloudKit")

        // Fetch progress data from CloudKit (no Core Data cache)
        let progressRecords = try await privateDatabase.records(matching: progressQuery).0
        print("📦 Fetched \(progressRecords.count) progress records from CloudKit")
    }

    // MARK: - Challenge Operations

    /// Create or update a challenge in CloudKit
    func saveChallenge(_ challenge: Challenge) async throws {
        let record = CKRecord(recordType: challengeRecordType)
        record["id"] = challenge.id
        record["title"] = challenge.title
        record["description"] = challenge.description
        record["type"] = challenge.type.rawValue
        record["category"] = challenge.category
        record["difficulty"] = Int64(challenge.difficulty.rawValue)
        record["points"] = Int64(challenge.points)
        record["coins"] = Int64(challenge.coins)
        record["requirements"] = try? JSONEncoder().encode(challenge.requirements).base64EncodedString()
        record["startDate"] = challenge.startDate
        record["endDate"] = challenge.endDate
        record["isActive"] = Int64(challenge.isActive ? 1 : 0)
        record["isPremium"] = Int64(challenge.isPremium ? 1 : 0)
        record["participantCount"] = Int64(challenge.participants)
        record["completionCount"] = Int64(challenge.completions)
        record["imageURL"] = challenge.imageURL
        record["teamBased"] = Int64(0)  // Currently no team-based challenges

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: challengeRecordType, database: publicDatabase.debugName)
        
        _ = try await publicDatabase.save(record)
        let duration = Date().timeIntervalSince(startTime)
        logger.logSaveSuccess(recordType: challengeRecordType, recordID: record.recordID.recordName, database: publicDatabase.debugName, duration: duration)
    }

    /// Create or update user challenge participation
    func saveUserChallenge(_ userChallenge: UserChallenge) async throws {
        let record = CKRecord(recordType: userChallengeRecordType)
        record["userID"] = userChallenge.userID

        // Create reference to challenge
        let challengeRecordID = CKRecord.ID(recordName: userChallenge.challengeID)
        record["challengeID"] = CKRecord.Reference(recordID: challengeRecordID, action: .none)

        record["status"] = userChallenge.status
        record["progress"] = userChallenge.progress
        record["startedAt"] = userChallenge.startedAt
        record["completedAt"] = userChallenge.completedAt
        record["earnedPoints"] = Int64(userChallenge.earnedPoints)
        record["earnedCoins"] = Int64(userChallenge.earnedCoins)
        record["proofImageURL"] = userChallenge.proofImageURL
        record["notes"] = userChallenge.notes
        record["teamID"] = userChallenge.teamID

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: userChallengeRecordType, database: privateDatabase.debugName)
        
        _ = try await privateDatabase.save(record)
        let duration = Date().timeIntervalSince(startTime)
        logger.logSaveSuccess(recordType: userChallengeRecordType, recordID: record.recordID.recordName, database: privateDatabase.debugName, duration: duration)
    }

    /// Update or create leaderboard entry
    func updateLeaderboardEntry(for userID: String, points: Int, challengesCompleted: Int) async throws {
        // Check if entry exists
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: leaderboardRecordType, predicate: predicate)

        let results = try await publicDatabase.records(matching: query).0
        let record: CKRecord

        if let (_, result) = results.first,
           let existingRecord = try? result.get() {
            record = existingRecord
            // Update existing record
            let currentTotal = (record["totalPoints"] as? Int64 ?? 0)
            record["totalPoints"] = currentTotal + Int64(points)
            record["challengesCompleted"] = Int64(challengesCompleted)
        } else {
            // Create new record
            record = CKRecord(recordType: leaderboardRecordType)
            record["userID"] = userID
            record["userName"] = "Chef\(userID.prefix(6))"  // Default username
            record["avatarURL"] = ""
            record["totalPoints"] = Int64(points)
            record["weeklyPoints"] = Int64(points)  // Reset weekly
            record["monthlyPoints"] = Int64(points) // Reset monthly
            record["challengesCompleted"] = Int64(challengesCompleted)
            record["currentStreak"] = Int64(0)
            record["longestStreak"] = Int64(0)
            if #available(iOS 16, *) {
                record["region"] = Locale.current.region?.identifier
            } else {
                record["region"] = Locale.current.regionCode
            }
        }

        record["lastUpdated"] = Date()
        
        let saveLogger = CloudKitDebugLogger.shared
        let saveStartTime = Date()
        saveLogger.logSaveStart(recordType: leaderboardRecordType, database: publicDatabase.debugName)
        
        _ = try await publicDatabase.save(record)
        let saveDuration = Date().timeIntervalSince(saveStartTime)
        saveLogger.logSaveSuccess(recordType: leaderboardRecordType, recordID: record.recordID.recordName, database: publicDatabase.debugName, duration: saveDuration)
    }

    /// Save achievement earned by user
    func saveAchievement(_ achievement: Achievement) async throws {
        let record = CKRecord(recordType: achievementRecordType)
        record["id"] = achievement.id
        record["userID"] = achievement.userID
        record["type"] = achievement.type
        record["name"] = achievement.name
        record["description"] = achievement.description
        record["iconName"] = achievement.iconName
        record["earnedAt"] = achievement.earnedAt
        record["rarity"] = achievement.rarity
        record["associatedChallengeID"] = achievement.associatedChallengeID

        _ = try await privateDatabase.save(record)
    }

    /// Save coin transaction
    func saveCoinTransaction(_ transaction: CoinTransaction) async throws {
        let record = CKRecord(recordType: coinTransactionRecordType)
        record["userID"] = transaction.userID
        record["amount"] = Int64(transaction.amount)
        record["type"] = transaction.type
        record["reason"] = transaction.reason
        record["timestamp"] = transaction.timestamp
        record["balance"] = Int64(transaction.balance)
        record["challengeID"] = transaction.challengeID
        record["itemPurchased"] = transaction.itemPurchased

        _ = try await privateDatabase.save(record)
    }

    // MARK: - Fetch Operations

    /// Fetch leaderboard entries
    func fetchLeaderboard(limit: Int = 100, timeframe: LeaderboardTimeframe = .allTime) async throws -> [LeaderboardEntry] {
        let sortKey = timeframe == .weekly ? "weeklyPoints" : timeframe == .monthly ? "monthlyPoints" : "totalPoints"
        let query = CKQuery(recordType: leaderboardRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: false)]

        var entries: [LeaderboardEntry] = []
        let (results, _) = try await publicDatabase.records(matching: query, resultsLimit: limit)

        for (index, result) in results.enumerated() {
            if let record = try? result.1.get() {
                entries.append(LeaderboardEntry(
                    rank: index + 1,
                    username: record["userName"] as? String ?? "Unknown",
                    avatar: record["avatarURL"] as? String ?? "person.circle.fill",
                    points: Int(record[sortKey] as? Int64 ?? 0),
                    level: Int((record["totalPoints"] as? Int64 ?? 0) / 1_000) + 1,
                    country: record["region"] as? String,
                    isCurrentUser: record["userID"] as? String == getUserId()
                ))
            }
        }

        return entries
    }

    // MARK: - Helper Methods

    private func getUserId() -> String {
        // In a real app, this would return the actual user ID
        // For now, using a placeholder
        return UserDefaults.standard.string(forKey: "userId") ?? "default-user"
    }

    private func incrementParticipantCount(for challengeId: UUID) async {
        do {
            let recordID = CKRecord.ID(recordName: challengeId.uuidString)
            let record = try await publicDatabase.record(for: recordID)

            let currentCount = record["participantCount"] as? Int ?? 0
            record["participantCount"] = currentCount + 1

            try await publicDatabase.save(record)
        } catch {
            print("Error incrementing participant count: \(error)")
        }
    }

    // Core Data integration commented out - using CloudKit direct storage
    /*
    private func updateCoreDataParticipants(_ records: [CKRecord]) async throws {
        let context = PersistenceController.shared.container.viewContext
        
        for record in records {
            let fetchRequest: NSFetchRequest<ChallengeParticipantEntity> = ChallengeParticipantEntity.fetchRequest()
            // Use id field for predicate instead of recordName (which isn't queryable)
            if let entityID = record["id"] as? String {
                fetchRequest.predicate = NSPredicate(format: "id == %@", entityID)
            } else {
                fetchRequest.predicate = NSPredicate(format: "id == %@", record.recordID.recordName)
            }
            
            let existingParticipants = try context.fetch(fetchRequest)
            let participant = existingParticipants.first ?? ChallengeParticipantEntity(context: context)
            
            participant.id = UUID(uuidString: record.recordID.recordName)
            participant.userId = record["userId"] as? String
            participant.joinedAt = record["joinedAt"] as? Date
            participant.completedAt = record["completedAt"] as? Date
            participant.score = record["score"] as? Int32 ?? 0
            participant.rank = record["rank"] as? Int32 ?? 0
        }
        
        try context.save()
    }
    
    private func updateCoreDataProgress(_ records: [CKRecord]) async throws {
        let context = PersistenceController.shared.container.viewContext
        
        for record in records {
            let fetchRequest: NSFetchRequest<ChallengeProgressEntity> = ChallengeProgressEntity.fetchRequest()
            // Use id field for predicate instead of recordName (which isn't queryable)
            if let entityID = record["id"] as? String {
                fetchRequest.predicate = NSPredicate(format: "id == %@", entityID)
            } else {
                fetchRequest.predicate = NSPredicate(format: "id == %@", record.recordID.recordName)
            }
            
            let existingProgress = try context.fetch(fetchRequest)
            let progress = existingProgress.first ?? ChallengeProgressEntity(context: context)
            
            progress.id = UUID(uuidString: record.recordID.recordName)
            progress.userId = record["userId"] as? String
            progress.progressValue = record["progressValue"] as? Double ?? 0
            progress.action = record["action"] as? String
            progress.timestamp = record["timestamp"] as? Date
            progress.metadata = record["metadata"] as? Data
        }
        
        try context.save()
    }
    */
    }

// MARK: - CloudKit Models

enum LeaderboardTimeframe {
    case weekly
    case monthly
    case allTime
}

// MARK: - CloudKit Errors
enum CloudKitError: LocalizedError {
    case recordNotFound
    case invalidData
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .recordNotFound:
            return "Record not found in CloudKit"
        case .invalidData:
            return "Invalid data format"
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        }
    }
}
