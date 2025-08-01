import Foundation
import Combine

/// ChallengeService handles API communication for challenge-related operations
class ChallengeService {
    
    // MARK: - Properties
    static let shared = ChallengeService()
    
    private let baseURL = "https://api.snapchef.com/v1"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
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
        let url = URL(string: baseURL + Endpoint.challenges.rawValue)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthenticationHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ChallengeServiceError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ChallengeDTO].self, from: data)
    }
    
    /// Fetch user's active challenges
    func fetchUserChallenges(userId: String) async throws -> [UserChallengeDTO] {
        let url = URL(string: baseURL + Endpoint.userChallenges.rawValue + "/\(userId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthenticationHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ChallengeServiceError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([UserChallengeDTO].self, from: data)
    }
    
    /// Join a challenge
    func joinChallenge(challengeId: String, userId: String) async throws -> JoinChallengeResponse {
        let url = URL(string: baseURL + Endpoint.joinChallenge.rawValue)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthenticationHeaders(to: &request)
        
        let body = JoinChallengeRequest(challengeId: challengeId, userId: userId)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ChallengeServiceError.joinFailed
        }
        
        return try JSONDecoder().decode(JoinChallengeResponse.self, from: data)
    }
    
    /// Update challenge progress
    func updateProgress(progressUpdate: ProgressUpdateRequest) async throws -> ProgressUpdateResponse {
        let url = URL(string: baseURL + Endpoint.updateProgress.rawValue)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthenticationHeaders(to: &request)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(progressUpdate)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ChallengeServiceError.updateFailed
        }
        
        return try JSONDecoder().decode(ProgressUpdateResponse.self, from: data)
    }
    
    /// Fetch challenge leaderboard
    func fetchLeaderboard(challengeId: String, limit: Int = 100) async throws -> [LeaderboardEntryDTO] {
        var components = URLComponents(string: baseURL + Endpoint.leaderboard.rawValue + "/\(challengeId)")!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        addAuthenticationHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ChallengeServiceError.invalidResponse
        }
        
        return try JSONDecoder().decode([LeaderboardEntryDTO].self, from: data)
    }
    
    /// Fetch community challenge progress
    func fetchCommunityProgress(challengeId: String) async throws -> CommunityProgressDTO {
        let url = URL(string: baseURL + Endpoint.communityProgress.rawValue + "/\(challengeId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthenticationHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ChallengeServiceError.invalidResponse
        }
        
        return try JSONDecoder().decode(CommunityProgressDTO.self, from: data)
    }
    
    /// Claim challenge rewards
    func claimRewards(challengeId: String, userId: String) async throws -> ClaimRewardsResponse {
        let url = URL(string: baseURL + Endpoint.rewards.rawValue + "/claim")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthenticationHeaders(to: &request)
        
        let body = ClaimRewardsRequest(challengeId: challengeId, userId: userId)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ChallengeServiceError.claimFailed
        }
        
        return try JSONDecoder().decode(ClaimRewardsResponse.self, from: data)
    }
    
    // MARK: - Sync Operations
    
    /// Sync local challenges with server
    func syncChallenges() async throws {
        // Fetch latest challenges from server
        let serverChallenges = try await fetchChallenges()
        
        // Convert to local Challenge objects and save
        await MainActor.run {
            let gamificationManager = GamificationManager.shared
            
            for dto in serverChallenges {
                let challenge = dto.toChallenge()
                gamificationManager.saveChallenge(challenge)
            }
        }
        
        // Sync user progress
        let userId = getUserId()
        let userChallenges = try await fetchUserChallenges(userId: userId)
        
        await MainActor.run {
            let gamificationManager = GamificationManager.shared
            for userChallenge in userChallenges {
                gamificationManager.updateChallengeProgress(
                    UUID(uuidString: userChallenge.challengeId) ?? UUID(),
                    progress: userChallenge.progress
                )
            }
        }
    }
    
    /// Start real-time sync
    func startRealtimeSync() {
        Timer.publish(every: 300, on: .main, in: .common) // Sync every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    try? await self?.syncChallenges()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    
    private func addAuthenticationHeaders(to request: inout URLRequest) {
        // Add authentication token
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add API key
        request.setValue("YOUR_API_KEY", forHTTPHeaderField: "X-API-Key")
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
            type: ChallengeType(rawValue: type) ?? .daily,
            title: title,
            description: description,
            requirement: requirement,
            reward: ChallengeReward(
                points: rewardPoints,
                badge: rewardBadge,
                title: rewardTitle,
                unlockable: rewardUnlockable
            ),
            endDate: endDate,
            participants: participantCount,
            progress: 0,
            isCompleted: false
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
    /// Create mock challenges for testing when API is not available
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
                endDate: Date().addingTimeInterval(86400),
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
                endDate: Date().addingTimeInterval(604800),
                participantCount: 2345,
                isActive: true
            )
        ]
        
        // Save mock challenges
        await MainActor.run {
            let gamificationManager = GamificationManager.shared
            for dto in mockChallenges {
                let challenge = dto.toChallenge()
                gamificationManager.saveChallenge(challenge)
            }
        }
    }
}