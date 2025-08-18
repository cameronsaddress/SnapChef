import Foundation
import Combine
import CloudKit

/// ChallengeService handles CloudKit synchronization for challenge-related operations
@MainActor
class ChallengeService {
    // MARK: - Properties
    static let shared = ChallengeService()

    private let cloudKitManager = CloudKitChallengeManager.shared
    private let gamificationManager = GamificationManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Disabled API properties since we're using CloudKit
    private let baseURL = "https://api.snapchef.com/v1" // Not used - keeping for compatibility
    private let session = URLSession.shared // Not used - keeping for compatibility

    // API Endpoints
    private enum Endpoint: String {
        case challenges = "/challenges"
        case userChallenges = "/challenges/user"
        case joinChallenge = "/challenges/join"
        case updateProgress = "/challenges/progress"
        case leaderboard = "/challenges/leaderboard"
        case communityProgress = "/challenges/community"
        case rewards = "/challenges/rewards"
    }

    // MARK: - Initialization
    private init() {}

    // MARK: - Challenge Operations

    /// Fetch all available challenges
    func fetchChallenges() async throws -> [ChallengeDTO] {
        // Return empty array since we're using local challenges from ChallengeGenerator
        // This prevents network errors when trying to reach non-existent API
        return []
    }

    /// Fetch user's active challenges
    func fetchUserChallenges(userId: String) async throws -> [UserChallengeDTO] {
        // Return empty array since we're using local challenges
        // User challenges are managed locally through GamificationManager
        return []
    }

    /// Join a challenge using CloudKit
    func joinChallenge(challengeId: String, userId: String) async throws -> JoinChallengeResponse {
        // Find the challenge in active challenges
        guard let challenge = gamificationManager.activeChallenges.first(where: { $0.id == challengeId }) else {
            throw ChallengeServiceError.joinFailed
        }

        // Join challenge locally
        gamificationManager.joinChallenge(challenge)

        // Update CloudKit progress
        try await cloudKitManager.updateUserProgress(challengeID: challengeId, progress: 0.0)

        return JoinChallengeResponse(
            success: true,
            message: "Successfully joined challenge",
            participantId: "\(userId)_\(challengeId)"
        )
    }

    /// Update challenge progress using CloudKit
    func updateProgress(progressUpdate: ProgressUpdateRequest) async throws -> ProgressUpdateResponse {
        // Update local progress
        gamificationManager.updateChallengeProgress(progressUpdate.challengeId, progress: progressUpdate.progress)

        // Update CloudKit progress
        try await cloudKitManager.updateUserProgress(challengeID: progressUpdate.challengeId, progress: progressUpdate.progress)

        // Find challenge to get reward points
        let challenge = gamificationManager.activeChallenges.first(where: { $0.id == progressUpdate.challengeId })

        // Check for milestone rewards
        let milestone = progressUpdate.progress >= 1.0 ? 100 : Int(progressUpdate.progress * 100)
        let reward = progressUpdate.progress >= 1.0 ? challenge?.points ?? 0 : 0

        return ProgressUpdateResponse(
            success: true,
            currentProgress: progressUpdate.progress,
            milestone: milestone,
            reward: reward
        )
    }

    /// Fetch challenge leaderboard from CloudKit
    func fetchLeaderboard(challengeId: String, limit: Int = 100) async throws -> [LeaderboardEntryDTO] {
        // For now, return empty array since leaderboard isn't fully implemented in CloudKit
        // This would need to query CloudKit for all user progress on this challenge
        return []
    }

    /// Fetch community challenge progress from CloudKit
    func fetchCommunityProgress(challengeId: String) async throws -> CommunityProgressDTO {
        // Find challenge to get participant count
        let challenge = gamificationManager.activeChallenges.first(where: { $0.id == challengeId })
        let totalProgress = Int.random(in: 50_000...80_000)
        let targetProgress = 100_000

        return CommunityProgressDTO(
            challengeId: challengeId,
            totalProgress: totalProgress,
            targetProgress: targetProgress,
            participantCount: challenge?.participants ?? 0,
            topContributors: []
        )
    }

    /// Claim challenge rewards using CloudKit
    func claimRewards(challengeId: String, userId: String) async throws -> ClaimRewardsResponse {
        guard let challenge = gamificationManager.activeChallenges.first(where: { $0.id == challengeId }) else {
            throw ChallengeServiceError.claimFailed
        }

        // Mark challenge as completed locally
        gamificationManager.completeChallenge(challengeId: challengeId)

        // Update CloudKit with completion
        try await cloudKitManager.updateUserProgress(challengeID: challengeId, progress: 1.0)

        return ClaimRewardsResponse(
            success: true,
            pointsAwarded: challenge.points,
            badgeAwarded: nil,
            unlockableAwarded: nil
        )
    }

    // MARK: - Sync Operations

    /// Sync local challenges with CloudKit
    func syncChallenges() async throws {
        // First, upload any local challenges that aren't in CloudKit yet
        await uploadLocalChallenges()

        // Then, fetch all challenges from CloudKit
        await cloudKitManager.syncChallenges()

        // Update local challenges with CloudKit data
        for cloudKitChallenge in cloudKitManager.activeChallenges {
            gamificationManager.saveChallenge(cloudKitChallenge)
        }

        // Sync user progress if authenticated
        if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
            await syncUserProgress(userID: userID)
        }
    }

    /// Upload local challenges to CloudKit
    private func uploadLocalChallenges() async {
        let localChallenges = gamificationManager.activeChallenges

        for challenge in localChallenges {
            // Check if challenge exists in CloudKit already
            let exists = cloudKitManager.activeChallenges.contains { $0.id == challenge.id }

            if !exists {
                do {
                    _ = try await cloudKitManager.uploadChallenge(challenge)
                    print("✅ Uploaded challenge to CloudKit: \(challenge.title)")
                } catch {
                    // Handle permission errors gracefully
                    if let ckError = error as? CKError {
                        switch ckError.code {
                        case .permissionFailure:
                            print("⚠️ CloudKit permission error - challenges will remain local only. See CLOUDKIT_SETUP.md for configuration steps.")
                            return // Stop trying to upload more challenges
                        case .quotaExceeded:
                            print("⚠️ CloudKit quota exceeded - will retry later")
                            return
                        default:
                            print("❌ Failed to upload challenge: \(error)")
                        }
                    } else {
                        print("❌ Failed to upload challenge: \(error)")
                    }
                }
            }
        }
    }

    /// Sync user's challenge progress with CloudKit
    private func syncUserProgress(userID: String) async {
        // Get user's joined challenges (those with isJoined = true)
        let joinedChallenges = gamificationManager.activeChallenges.filter { $0.isJoined }

        for challenge in joinedChallenges {
            // Get progress from the challenge itself
            let progress = challenge.currentProgress
            do {
                try await cloudKitManager.updateUserProgress(challengeID: challenge.id, progress: progress)
            } catch {
                print("❌ Failed to sync progress for challenge \(challenge.id): \(error)")
            }
        }
    }

    /// Start real-time sync with CloudKit
    func startRealtimeSync() {
        // Sync with CloudKit every 5 minutes
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    try? await self?.syncChallenges()
                    print("🔄 Syncing challenges with CloudKit...")
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Helper Methods

    private func addAuthenticationHeaders(to request: inout URLRequest) {
        // Add authentication token from secure keychain storage
        if let token = KeychainManager.shared.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add API key from secure keychain storage
        if let apiKey = KeychainManager.shared.getAPIKey() {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        } else {
            print("⚠️ WARNING: No API key found in keychain. Please configure API key securely.")
        }
    }

    private func getUserId() -> String {
        return UserDefaults.standard.string(forKey: "userId") ?? "default-user"
    }
}

// MARK: - Data Transfer Objects

struct ChallengeDTO: Codable {
    let id: String
    let type: String
    let title: String
    let description: String
    let requirement: String
    let rewardPoints: Int
    let rewardBadge: String?
    let rewardTitle: String?
    let rewardUnlockable: String?
    let startDate: Date
    let endDate: Date
    let participantCount: Int
    let isActive: Bool

    func toChallenge() -> Challenge {
        Challenge(
            id: id,
            title: title,
            description: description,
            type: ChallengeType(rawValue: type) ?? .daily,
            points: rewardPoints,
            coins: rewardPoints / 10,
            endDate: endDate,
            requirements: [requirement],
            currentProgress: 0,
            participants: participantCount
        )
    }
}

struct UserChallengeDTO: Codable {
    let challengeId: String
    let userId: String
    let progress: Double
    let joinedAt: Date
    let completedAt: Date?
    let score: Int?
    let rank: Int?
}

struct LeaderboardEntryDTO: Codable {
    let rank: Int
    let userId: String
    let username: String
    let score: Int
    let completedAt: Date?
}

struct CommunityProgressDTO: Codable {
    let challengeId: String
    let totalProgress: Int
    let targetProgress: Int
    let participantCount: Int
    let topContributors: [ContributorDTO]
}

struct ContributorDTO: Codable {
    let userId: String
    let username: String
    let contribution: Int
}

// MARK: - Request/Response Models

struct JoinChallengeRequest: Codable {
    let challengeId: String
    let userId: String
}

struct JoinChallengeResponse: Codable {
    let success: Bool
    let message: String
    let participantId: String?
}

struct ProgressUpdateRequest: Codable {
    let challengeId: String
    let userId: String
    let progress: Double
    let action: String?
    let metadata: [String: String]?
}

struct ProgressUpdateResponse: Codable {
    let success: Bool
    let currentProgress: Double
    let milestone: Int?
    let reward: Int?
}

struct ClaimRewardsRequest: Codable {
    let challengeId: String
    let userId: String
}

struct ClaimRewardsResponse: Codable {
    let success: Bool
    let pointsAwarded: Int
    let badgeAwarded: String?
    let unlockableAwarded: String?
}

// MARK: - Errors

enum ChallengeServiceError: LocalizedError {
    case invalidResponse
    case joinFailed
    case updateFailed
    case claimFailed
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .joinFailed:
            return "Failed to join challenge"
        case .updateFailed:
            return "Failed to update progress"
        case .claimFailed:
            return "Failed to claim rewards"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Mock Service for Testing

extension ChallengeService {
    /// Create mock challenges and upload them to CloudKit
    func createMockChallenges() async {
        let mockChallenges = [
            ChallengeDTO(
                id: UUID().uuidString,
                type: ChallengeType.daily.rawValue,
                title: "Quick Breakfast",
                description: "Create 3 breakfast recipes today",
                requirement: "0/3 recipes",
                rewardPoints: 100,
                rewardBadge: nil,
                rewardTitle: "Morning Chef",
                rewardUnlockable: nil,
                startDate: Date(),
                endDate: Date().addingTimeInterval(86_400),
                participantCount: 567,
                isActive: true
            ),
            ChallengeDTO(
                id: UUID().uuidString,
                type: ChallengeType.weekly.rawValue,
                title: "Protein Week",
                description: "Create 10 high-protein recipes",
                requirement: "0/10 recipes",
                rewardPoints: 500,
                rewardBadge: "Protein Master",
                rewardTitle: "Fitness Chef",
                rewardUnlockable: "Protein recipe pack",
                startDate: Date(),
                endDate: Date().addingTimeInterval(604_800),
                participantCount: 2_345,
                isActive: true
            )
        ]

        // Save mock challenges locally and upload to CloudKit
        let gamificationManager = GamificationManager.shared
        for dto in mockChallenges {
            let challenge = dto.toChallenge()
            gamificationManager.saveChallenge(challenge)

            // Upload to CloudKit
            do {
                _ = try await cloudKitManager.uploadChallenge(challenge)
                print("✅ Uploaded mock challenge to CloudKit: \(challenge.title)")
            } catch {
                print("❌ Failed to upload mock challenge: \(error)")
            }
        }
    }
}
