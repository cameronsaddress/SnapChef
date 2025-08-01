import Foundation
import CloudKit
import Combine

@MainActor
class CloudKitSyncService: ObservableObject {
    static let shared = CloudKitSyncService()
    
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    
    @Published var isSyncing = false
    @Published var syncError: Error?
    @Published var lastSyncDate: Date?
    
    private var cancellables = Set<AnyCancellable>()
    private var syncQueue = DispatchQueue(label: "com.snapchef.cloudkit.sync", qos: .background)
    
    private init() {
        container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
        publicDatabase = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase
        
        setupSubscriptions()
        checkiCloudStatus()
    }
    
    // MARK: - iCloud Status
    private func checkiCloudStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    print("✅ iCloud available")
                    self?.setupInitialSync()
                case .noAccount:
                    print("❌ No iCloud account")
                case .restricted:
                    print("⚠️ iCloud restricted")
                case .temporarilyUnavailable:
                    print("⏳ iCloud temporarily unavailable")
                case .couldNotDetermine:
                    print("❓ Could not determine iCloud status")
                @unknown default:
                    print("❓ Unknown iCloud status")
                }
            }
        }
    }
    
    // MARK: - Initial Setup
    private func setupInitialSync() {
        Task {
            await syncChallenges()
            await syncUserProgress()
            await syncLeaderboard()
        }
    }
    
    // MARK: - Subscriptions
    private func setupSubscriptions() {
        // Subscribe to challenge updates
        let challengePredicate = NSPredicate(value: true)
        let challengeSubscription = CKQuerySubscription(
            recordType: CloudKitConfig.challengeRecordType,
            predicate: challengePredicate,
            subscriptionID: CloudKitConfig.challengeUpdatesSubscription,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        challengeSubscription.notificationInfo = notificationInfo
        
        publicDatabase.save(challengeSubscription) { _, error in
            if let error = error {
                print("❌ Failed to create challenge subscription: \(error)")
            } else {
                print("✅ Challenge subscription created")
            }
        }
    }
    
    // MARK: - Sync Operations
    func syncChallenges() async {
        await MainActor.run { isSyncing = true }
        
        do {
            // Query active challenges
            let predicate = CloudKitConfig.activeChallengePredicate()
            let query = CKQuery(recordType: CloudKitConfig.challengeRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: CKField.Challenge.startDate, ascending: false)]
            
            let results = try await publicDatabase.records(matching: query)
            
            var challenges: [Challenge] = []
            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    if let challenge = Challenge(from: record) {
                        challenges.append(challenge)
                    }
                }
            }
            
            // Update local storage
            await MainActor.run {
                GamificationManager.shared.updateChallenges(challenges)
                lastSyncDate = Date()
                isSyncing = false
            }
            
            print("✅ Synced \(challenges.count) challenges")
            
        } catch {
            await MainActor.run {
                syncError = error
                isSyncing = false
            }
            print("❌ Failed to sync challenges: \(error)")
        }
    }
    
    func syncUserProgress() async {
        guard let userID = AuthenticationManager().currentUser?.id else { return }
        
        do {
            // Query user's challenge progress
            let predicate = NSPredicate(format: "%K == %@", CKField.UserChallenge.userID, userID)
            let query = CKQuery(recordType: CloudKitConfig.userChallengeRecordType, predicate: predicate)
            
            let results = try await privateDatabase.records(matching: query)
            
            var userChallenges: [UserChallenge] = []
            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    userChallenges.append(UserChallenge(from: record))
                }
            }
            
            // Update local storage
            await MainActor.run {
                GamificationManager.shared.syncUserChallenges(userChallenges)
            }
            
            print("✅ Synced \(userChallenges.count) user challenges")
            
        } catch {
            print("❌ Failed to sync user progress: \(error)")
        }
    }
    
    func syncLeaderboard() async {
        do {
            // Query top 100 global leaderboard
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: CloudKitConfig.leaderboardRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: CKField.Leaderboard.totalPoints, ascending: false)]
            
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = 100
            
            var leaderboardEntries: [LeaderboardEntry] = []
            
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    // Use LeaderboardEntry directly
                }
            }
            
            operation.queryResultBlock = { result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        print("✅ Synced \(leaderboardEntries.count) leaderboard entries")
                        // Update UI with leaderboard data
                    case .failure(let error):
                        print("❌ Failed to sync leaderboard: \(error)")
                    }
                }
            }
            
            publicDatabase.add(operation)
        }
    }
    
    // MARK: - Save Operations
    func saveUserChallenge(_ userChallenge: UserChallenge) async throws {
        // Moved to CloudKitManager
        try await CloudKitManager.shared.saveUserChallenge(userChallenge)
    }
    
    func joinTeam(teamID: String, userID: String) async throws {
        // Fetch team record
        let recordID = CKRecord.ID(recordName: teamID)
        let teamRecord = try await publicDatabase.record(for: recordID)
        
        // Add user to team members
        var memberIDs = (teamRecord[CKField.Team.memberIDs] as? [String]) ?? []
        if !memberIDs.contains(userID) {
            memberIDs.append(userID)
            teamRecord[CKField.Team.memberIDs] = memberIDs
            
            _ = try await publicDatabase.save(teamRecord)
            print("✅ Joined team successfully")
        }
    }
    
    func createTeam(_ team: Team) async throws -> Team {
        // Moved to CloudKitManager
        try await CloudKitManager.shared.saveTeam(team)
        print("✅ Created team: \(team.name)")
        return team
    }
    
    func updateLeaderboardEntry(for userID: String, points: Int, challengesCompleted: Int) async throws {
        let recordID = CKRecord.ID(recordName: userID)
        
        do {
            // Try to fetch existing record
            let record = try await publicDatabase.record(for: recordID)
            record[CKField.Leaderboard.totalPoints] = (record[CKField.Leaderboard.totalPoints] as? Int ?? 0) + points
            record[CKField.Leaderboard.challengesCompleted] = challengesCompleted
            record[CKField.Leaderboard.lastUpdated] = Date()
            
            _ = try await publicDatabase.save(record)
            
        } catch {
            // Create new record if doesn't exist
            let newRecord = CKRecord(recordType: CloudKitConfig.leaderboardRecordType, recordID: recordID)
            newRecord[CKField.Leaderboard.userID] = userID
            newRecord[CKField.Leaderboard.totalPoints] = points
            newRecord[CKField.Leaderboard.challengesCompleted] = challengesCompleted
            newRecord[CKField.Leaderboard.lastUpdated] = Date()
            
            _ = try await publicDatabase.save(newRecord)
        }
        
        print("✅ Updated leaderboard entry")
    }
}

// MARK: - CloudKit Model Extensions

extension Challenge {
    init?(from record: CKRecord) {
        guard let id = record["id"] as? String,
              let title = record["title"] as? String,
              let description = record["description"] as? String,
              let typeRaw = record["type"] as? String,
              let type = ChallengeType(rawValue: typeRaw),
              let category = record["category"] as? String,
              let difficultyInt = record["difficulty"] as? Int64,
              let difficulty = DifficultyLevel(rawValue: Int(difficultyInt)),
              let points = record["points"] as? Int64,
              let coins = record["coins"] as? Int64,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date,
              let isActiveInt = record["isActive"] as? Int64,
              let isPremiumInt = record["isPremium"] as? Int64,
              let participantCount = record["participantCount"] as? Int64,
              let completionCount = record["completionCount"] as? Int64 else {
            return nil
        }
        
        var requirements: [String] = []
        if let requirementsData = record["requirements"] as? String,
           let data = Data(base64Encoded: requirementsData),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            requirements = decoded
        }
        
        self.init(
            id: id,
            title: title,
            description: description,
            type: type,
            category: category,
            difficulty: difficulty,
            points: Int(points),
            coins: Int(coins),
            startDate: startDate,
            endDate: endDate,
            requirements: requirements,
            currentProgress: 0,
            isCompleted: false,
            isActive: isActiveInt == 1,
            isJoined: false,
            participants: Int(participantCount),
            completions: Int(completionCount),
            imageURL: record["imageURL"] as? String,
            isPremium: isPremiumInt == 1
        )
    }
}




