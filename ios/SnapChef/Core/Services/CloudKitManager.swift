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
    private let participantRecordType = "ChallengeParticipant"
    private let progressRecordType = "ChallengeProgress"
    
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
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        challengeSubscription.notificationInfo = notificationInfo
        
        publicDatabase.save(challengeSubscription) { subscription, error in
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
            
            // Update Core Data with fetched challenges
            // TODO: Uncomment when Core Data entities are properly generated
            // try await updateCoreDataChallenges(challenges)
            
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
    
    /// Update Core Data with CloudKit records
    // TODO: Uncomment when Core Data entities are properly generated
    /*
    private func updateCoreDataChallenges(_ records: [CKRecord]) async throws {
        let context = PersistenceController.shared.container.viewContext
        
        for record in records {
            // Check if challenge already exists
            let fetchRequest: NSFetchRequest<ChallengeEntity> = ChallengeEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", record.recordID.recordName)
            
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
            recordType: participantRecordType,
            predicate: NSPredicate(format: "userId == %@", getUserId())
        )
        
        let progressQuery = CKQuery(
            recordType: progressRecordType,
            predicate: NSPredicate(format: "userId == %@", getUserId())
        )
        
        // Fetch and update participant data
        let participantRecords = try await privateDatabase.records(matching: participantQuery).0
        // TODO: Uncomment when Core Data entities are properly generated
        // try await updateCoreDataParticipants(participantRecords.compactMap { try? $0.1.get() })
        
        // Fetch and update progress data
        let progressRecords = try await privateDatabase.records(matching: progressQuery).0
        // TODO: Uncomment when Core Data entities are properly generated
        // try await updateCoreDataProgress(progressRecords.compactMap { try? $0.1.get() })
    }
    
    // MARK: - Upload Operations
    
    /// Upload challenge progress to CloudKit
    // TODO: Uncomment when Core Data entities are properly generated
    /*
    func uploadChallengeProgress(_ progress: ChallengeProgressEntity) async throws {
        let record = CKRecord(recordType: progressRecordType)
        record["challengeId"] = progress.challenge?.id?.uuidString
        record["userId"] = getUserId()
        record["progressValue"] = progress.progressValue
        record["action"] = progress.action
        record["timestamp"] = progress.timestamp
        
        if let metadata = progress.metadata {
            record["metadata"] = metadata
        }
        
        try await privateDatabase.save(record)
    }
    */
    
    /// Upload challenge participation
    func uploadChallengeParticipation(challengeId: UUID, userId: String) async throws {
        let record = CKRecord(recordType: participantRecordType)
        record["challengeId"] = challengeId.uuidString
        record["userId"] = userId
        record["joinedAt"] = Date()
        
        try await privateDatabase.save(record)
        
        // Also increment participant count in public database
        await incrementParticipantCount(for: challengeId)
    }
    
    /// Mark challenge as completed for user
    func uploadChallengeCompletion(challengeId: UUID, userId: String, score: Int) async throws {
        // Find existing participant record
        let predicate = NSPredicate(
            format: "challengeId == %@ AND userId == %@",
            challengeId.uuidString, userId
        )
        let query = CKQuery(recordType: participantRecordType, predicate: predicate)
        
        let results = try await privateDatabase.records(matching: query).0
        guard let (_, result) = results.first,
              let record = try? result.get() else {
            throw CloudKitError.recordNotFound
        }
        
        record["completedAt"] = Date()
        record["score"] = score
        
        try await privateDatabase.save(record)
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
    
    // TODO: Uncomment when Core Data entities are properly generated
    /*
    private func updateCoreDataParticipants(_ records: [CKRecord]) async throws {
        let context = PersistenceController.shared.container.viewContext
        
        for record in records {
            let fetchRequest: NSFetchRequest<ChallengeParticipantEntity> = ChallengeParticipantEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", record.recordID.recordName)
            
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
            fetchRequest.predicate = NSPredicate(format: "id == %@", record.recordID.recordName)
            
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
    
    // MARK: - Team Methods
    
    func saveTeam(_ team: Team) async throws {
        let record = CKRecord(recordType: "Team")
        record["name"] = team.name
        record["description"] = team.description
        record["imageIcon"] = team.imageIcon
        record["color"] = team.color
        record["captain"] = team.captain
        record["members"] = team.members
        record["totalPoints"] = team.totalPoints
        record["weeklyPoints"] = team.weeklyPoints
        record["weeklyGoal"] = team.weeklyGoal
        record["isPublic"] = team.isPublic
        record["joinCode"] = team.joinCode
        record["maxMembers"] = team.maxMembers
        record["completedChallenges"] = team.completedChallenges
        record["createdAt"] = team.createdAt
        record["region"] = team.region
        
        _ = try await publicDatabase.save(record)
    }
    
    func updateTeam(_ team: Team) async throws {
        // Fetch existing record
        let recordID = CKRecord.ID(recordName: team.id.uuidString)
        let record = try await publicDatabase.record(for: recordID)
        
        // Update fields
        record["name"] = team.name
        record["description"] = team.description
        record["members"] = team.members
        record["totalPoints"] = team.totalPoints
        record["weeklyPoints"] = team.weeklyPoints
        record["captain"] = team.captain
        
        _ = try await publicDatabase.save(record)
    }
    
    func fetchTeamByCode(_ code: String) async throws -> [Team] {
        let predicate = NSPredicate(format: "joinCode == %@", code)
        let query = CKQuery(recordType: "Team", predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let teams = result.matchResults.compactMap { _, result in
            try? result.get()
        }.compactMap { record in
            teamFromRecord(record)
        }
        
        return teams
    }
    
    func searchTeams(query: String, region: String?) async throws -> [Team] {
        var predicate: NSPredicate
        
        if !query.isEmpty {
            predicate = NSPredicate(format: "name CONTAINS[cd] %@ AND isPublic == true", query)
        } else {
            predicate = NSPredicate(format: "isPublic == true")
        }
        
        let ckQuery = CKQuery(recordType: "Team", predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "weeklyPoints", ascending: false)]
        
        let result = try await publicDatabase.records(matching: ckQuery)
        let teams = result.matchResults.compactMap { _, result in
            try? result.get()
        }.compactMap { record in
            teamFromRecord(record)
        }
        
        return teams
    }
    
    func sendTeamChatMessage(_ message: TeamChatMessage) async throws {
        let record = CKRecord(recordType: "TeamChat")
        record["teamId"] = message.teamId.uuidString
        record["senderId"] = message.senderId
        record["senderName"] = message.senderName
        record["message"] = message.message
        record["timestamp"] = message.timestamp
        
        _ = try await publicDatabase.save(record)
    }
    
    private func teamFromRecord(_ record: CKRecord) -> Team? {
        guard let name = record["name"] as? String,
              let description = record["description"] as? String,
              let imageIcon = record["imageIcon"] as? String,
              let color = record["color"] as? String,
              let captain = record["captain"] as? String,
              let members = record["members"] as? [String],
              let totalPoints = record["totalPoints"] as? Int,
              let weeklyPoints = record["weeklyPoints"] as? Int,
              let weeklyGoal = record["weeklyGoal"] as? Int,
              let isPublic = record["isPublic"] as? Bool,
              let joinCode = record["joinCode"] as? String,
              let maxMembers = record["maxMembers"] as? Int,
              let completedChallenges = record["completedChallenges"] as? Int,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }
        
        return Team(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            description: description,
            imageIcon: imageIcon,
            color: color,
            captain: captain,
            members: members,
            totalPoints: totalPoints,
            weeklyPoints: weeklyPoints,
            weeklyGoal: weeklyGoal,
            activeChallenges: record["activeChallenges"] as? [String] ?? [],
            achievements: [],
            isPublic: isPublic,
            joinCode: joinCode,
            maxMembers: maxMembers,
            completedChallenges: completedChallenges,
            createdAt: createdAt,
            region: record["region"] as? String
        )
    }
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

