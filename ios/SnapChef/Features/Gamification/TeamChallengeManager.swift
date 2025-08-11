import Foundation
import SwiftUI
import CloudKit

// MARK: - Team Errors
enum TeamError: LocalizedError {
    case noTeam
    case teamFull
    case teamNotFound
    case invalidJoinCode
    case notCaptain
    case alreadyInTeam
    
    var errorDescription: String? {
        switch self {
        case .noTeam:
            return "You are not currently in a team"
        case .teamFull:
            return "This team is full"
        case .teamNotFound:
            return "Team not found"
        case .invalidJoinCode:
            return "Invalid team join code"
        case .notCaptain:
            return "Only the team captain can perform this action"
        case .alreadyInTeam:
            return "You are already in a team"
        }
    }
}

// MARK: - Team Model
struct Team: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var imageIcon: String
    var color: String
    var captain: String // User ID
    var members: [String] // User IDs
    var totalPoints: Int
    var weeklyPoints: Int
    var weeklyGoal: Int
    var activeChallenges: [String] // Challenge IDs
    var achievements: [TeamAchievement]
    var isPublic: Bool
    var joinCode: String
    var maxMembers: Int
    var completedChallenges: Int
    var createdAt: Date
    var region: String?
    
    var isFull: Bool {
        members.count >= maxMembers
    }
    
    var memberCount: Int {
        members.count
    }
}

// MARK: - Team Member
struct TeamMember: Identifiable, Codable {
    let id: UUID
    let userId: String
    let username: String
    let avatar: String
    var role: TeamRole
    var points: Int
    var joinedAt: Date
    var lastActive: Date
}

enum TeamRole: String, Codable, CaseIterable {
    case captain = "Captain"
    case coCaptain = "Co-Captain"
    case member = "Member"
    
    var icon: String {
        switch self {
        case .captain: return "crown.fill"
        case .coCaptain: return "star.circle.fill"
        case .member: return "person.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .captain: return Color(hex: "#ffd700")
        case .coCaptain: return Color(hex: "#c0c0c0")
        case .member: return Color(hex: "#667eea")
        }
    }
}

// MARK: - Team Achievement
struct TeamAchievement: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let unlockedAt: Date
}

// MARK: - Team Challenge
struct TeamChallenge: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let requirement: TeamChallengeRequirement
    let reward: TeamChallengeReward
    let startDate: Date
    let endDate: Date
    var progress: Double
    var participatingTeams: Int
    var leaderboard: [TeamLeaderboardEntry]
}

struct TeamChallengeRequirement {
    let type: RequirementType
    let target: Int
    let current: Int
    
    enum RequirementType {
        case totalRecipes
        case uniqueRecipes
        case totalPoints
        case memberParticipation
        case dailyStreak
    }
}

struct TeamChallengeReward {
    let teamPoints: Int
    let memberPoints: Int
    let badge: String?
    let title: String?
    let unlockable: String?
}

struct TeamLeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let team: Team
    let score: Int
    let progress: Double
}

// MARK: - Team Invitation
struct TeamInvitation: Identifiable {
    let id: UUID
    let teamId: UUID
    let teamName: String
    let invitedBy: String
    let invitedAt: Date
    let expiresAt: Date
    let message: String?
    
    var isExpired: Bool {
        Date() > expiresAt
    }
}

// MARK: - Team Challenge Manager
@MainActor
class TeamChallengeManager: ObservableObject {
    static let shared = TeamChallengeManager()
    
    @Published var currentTeam: Team?
    @Published var availableTeams: [Team] = []
    @Published var publicTeams: [Team] = []
    @Published var topTeams: [Team] = []
    @Published var activeTeamChallenges: [Challenge] = []
    @Published var teamChallenges: [TeamChallenge] = []
    @Published var pendingInvitations: [TeamInvitation] = []
    @Published var teamChat: [TeamChatMessage] = []
    @Published var isLoadingTeams = false
    
    private lazy var cloudKitManager = CloudKitManager.shared
    private lazy var notificationManager = ChallengeNotificationManager.shared
    
    private init() {
        loadMockData()
    }
    
    // MARK: - Team Management
    
    func createTeam(name: String, description: String, icon: String, color: Color, isPrivate: Bool, weeklyGoal: Int) async throws -> Team {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? "default-user"
        
        let team = Team(
            id: UUID(),
            name: name,
            description: description,
            imageIcon: icon,
            color: color.toHex() ?? "#667eea",
            captain: userId,
            members: [userId],
            totalPoints: 0,
            weeklyPoints: 0,
            weeklyGoal: weeklyGoal,
            activeChallenges: [],
            achievements: [],
            isPublic: !isPrivate,
            joinCode: generateJoinCode(),
            maxMembers: 20,
            completedChallenges: 0,
            createdAt: Date(),
            region: Locale.current.region?.identifier
        )
        
        // Save to CloudKit
        try await cloudKitManager.saveTeam(team)
        
        await MainActor.run {
            self.currentTeam = team
        }
        
        return team
    }
    
    private func generateJoinCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    func joinTeam(_ teamId: UUID) async throws {
        guard let team = publicTeams.first(where: { $0.id == teamId }) else {
            throw TeamError.teamNotFound
        }
        
        guard !team.isFull else {
            throw TeamError.teamFull
        }
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? "default-user"
        
        var updatedTeam = team
        updatedTeam.members.append(userId)
        
        // Update in CloudKit
        try await cloudKitManager.updateTeam(updatedTeam)
        
        await MainActor.run {
            self.currentTeam = updatedTeam
            
            // Remove from available teams
            self.publicTeams.removeAll { $0.id == team.id }
        }
    }
    
    func joinTeamWithCode(_ code: String) async throws {
        // Find team with matching code
        let teams = try await cloudKitManager.fetchTeamByCode(code.uppercased())
        
        guard let team = teams.first else {
            throw TeamError.invalidJoinCode
        }
        
        guard !team.isFull else {
            throw TeamError.teamFull
        }
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? "default-user"
        
        var updatedTeam = team
        updatedTeam.members.append(userId)
        
        // Update in CloudKit
        try await cloudKitManager.updateTeam(updatedTeam)
        
        await MainActor.run {
            self.currentTeam = updatedTeam
        }
    }
    
    func leaveCurrentTeam() async throws {
        guard let team = currentTeam else { return }
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? "default-user"
        
        var updatedTeam = team
        updatedTeam.members.removeAll { $0 == userId }
        
        // If user was captain, assign new captain
        if team.captain == userId && !updatedTeam.members.isEmpty {
            updatedTeam.captain = updatedTeam.members.first!
        }
        
        // Update in CloudKit
        try await cloudKitManager.updateTeam(updatedTeam)
        
        await MainActor.run {
            self.currentTeam = nil
        }
    }
    
    // MARK: - Team Challenges
    
    func joinTeamChallenge(_ challenge: TeamChallenge) async throws {
        guard let team = currentTeam else {
            throw TeamError.noTeam
        }
        
        // Add challenge to team's active challenges
        var updatedTeam = team
        updatedTeam.activeChallenges.append(challenge.id.uuidString)
        
        try await cloudKitManager.updateTeam(updatedTeam)
        
        await MainActor.run {
            self.currentTeam = updatedTeam
        }
    }
    
    func updateTeamChallengeProgress(_ challengeId: UUID, action: String, points: Int) {
        guard let team = currentTeam else { return }
        
        // Update challenge progress
        if let index = teamChallenges.firstIndex(where: { $0.id == challengeId }) {
            var challenge = teamChallenges[index]
            
            // Update based on requirement type
            switch challenge.requirement.type {
            case .totalPoints:
                challenge.progress = min(1.0, Double(points) / Double(challenge.requirement.target))
            case .totalRecipes:
                let current = challenge.requirement.current + 1
                challenge.progress = min(1.0, Double(current) / Double(challenge.requirement.target))
            default:
                break
            }
            
            teamChallenges[index] = challenge
            
            // Check if completed
            if challenge.progress >= 1.0 {
                completeTeamChallenge(challenge)
            }
        }
        
        // Update team points
        Task {
            var updatedTeam = team
            updatedTeam.weeklyPoints += points
            updatedTeam.totalPoints += points
            
            try? await cloudKitManager.updateTeam(updatedTeam)
            
            await MainActor.run {
                self.currentTeam = updatedTeam
            }
        }
    }
    
    private func completeTeamChallenge(_ challenge: TeamChallenge) {
        guard let team = currentTeam else { return }
        
        // Award rewards to all team members
        let reward = challenge.reward
        
        // Notify team members
        notificationManager.notifyTeamChallengeComplete(
            teamName: team.name,
            challengeName: challenge.title,
            reward: reward
        )
        
        // Add achievement
        let achievement = TeamAchievement(
            id: UUID(),
            name: challenge.title,
            description: "Completed \(challenge.title) with your team",
            icon: "trophy.fill",
            unlockedAt: Date()
        )
        
        Task {
            var updatedTeam = team
            updatedTeam.achievements.append(achievement)
            
            try? await cloudKitManager.updateTeam(updatedTeam)
            
            await MainActor.run {
                self.currentTeam = updatedTeam
            }
        }
    }
    
    // MARK: - Invitations
    
    func inviteToTeam(username: String, message: String?) async throws {
        guard let team = currentTeam else {
            throw TeamError.noTeam
        }
        
        let invitation = TeamInvitation(
            id: UUID(),
            teamId: team.id,
            teamName: team.name,
            invitedBy: UserDefaults.standard.string(forKey: "username") ?? "A player",
            invitedAt: Date(),
            expiresAt: Date().addingTimeInterval(604800), // 7 days
            message: message
        )
        
        // Save invitation to CloudKit
        // TODO: Implement team invitation in CloudKit
        print("Sending team invitation to \(username)")
        
        // Send notification
        notificationManager.notifyTeamChallengeInvite(
            from: invitation.invitedBy,
            teamName: team.name,
            challengeName: "team challenges"
        )
    }
    
    func acceptInvitation(_ invitation: TeamInvitation) async throws {
        // Find team
        // TODO: Implement fetchTeam in CloudKit
        guard let team = publicTeams.first(where: { $0.id == invitation.teamId }) else {
            throw TeamError.teamNotFound
        }
        
        // Join team
        try await joinTeam(invitation.teamId)
        
        // Remove invitation
        await MainActor.run {
            self.pendingInvitations.removeAll { $0.id == invitation.id }
        }
    }
    
    func declineInvitation(_ invitation: TeamInvitation) {
        pendingInvitations.removeAll { $0.id == invitation.id }
    }
    
    // MARK: - Team Discovery
    
    func searchTeams(query: String = "", region: String? = nil) async {
        await MainActor.run {
            isLoadingTeams = true
        }
        
        do {
            let teams = try await cloudKitManager.searchTeams(query: query, region: region)
            
            await MainActor.run {
                self.availableTeams = teams.filter { !$0.isFull && $0.isPublic }
                self.isLoadingTeams = false
            }
        } catch {
            print("Error searching teams: \(error)")
            await MainActor.run {
                self.isLoadingTeams = false
            }
        }
    }
    
    // MARK: - Team Chat
    
    func sendTeamMessage(_ message: String) {
        guard let team = currentTeam else { return }
        
        let chatMessage = TeamChatMessage(
            id: UUID(),
            teamId: team.id,
            senderId: UserDefaults.standard.string(forKey: "userId") ?? "default-user",
            senderName: UserDefaults.standard.string(forKey: "username") ?? "Player",
            message: message,
            timestamp: Date()
        )
        
        teamChat.append(chatMessage)
        
        // Save to CloudKit
        Task {
            try? await cloudKitManager.sendTeamChatMessage(chatMessage)
        }
    }
    
    // MARK: - Mock Data
    
    private func loadMockData() {
        // Mock team challenges
        teamChallenges = [
            TeamChallenge(
                id: UUID(),
                title: "Weekend Warriors",
                description: "Cook 100 recipes as a team this weekend",
                requirement: TeamChallengeRequirement(
                    type: .totalRecipes,
                    target: 100,
                    current: 45
                ),
                reward: TeamChallengeReward(
                    teamPoints: 5000,
                    memberPoints: 250,
                    badge: "Weekend Warriors",
                    title: "Weekend Warrior",
                    unlockable: "Team theme"
                ),
                startDate: Date(),
                endDate: Date().addingTimeInterval(172800), // 2 days
                progress: 0.45,
                participatingTeams: 128,
                leaderboard: []
            ),
            TeamChallenge(
                id: UUID(),
                title: "Global Cook-Off",
                description: "Compete against teams worldwide for the most points",
                requirement: TeamChallengeRequirement(
                    type: .totalPoints,
                    target: 50000,
                    current: 28500
                ),
                reward: TeamChallengeReward(
                    teamPoints: 10000,
                    memberPoints: 500,
                    badge: "Global Champions",
                    title: "World Class",
                    unlockable: "Exclusive recipes"
                ),
                startDate: Date(),
                endDate: Date().addingTimeInterval(604800), // 7 days
                progress: 0.57,
                participatingTeams: 512,
                leaderboard: []
            )
        ]
        
        // Mock available teams
        publicTeams = [
            Team(
                id: UUID(),
                name: "Kitchen Ninjas",
                description: "Fast cooking enthusiasts",
                imageIcon: "🥷",
                color: "#000000",
                captain: "captain1",
                members: ["captain1", "member1", "member2", "member3", "member4"],
                totalPoints: 125000,
                weeklyPoints: 8500,
                weeklyGoal: 10000,
                activeChallenges: [],
                achievements: [],
                isPublic: true,
                joinCode: "NINJA1",
                maxMembers: 20,
                completedChallenges: 45,
                createdAt: Date().addingTimeInterval(-2592000),
                region: "US"
            ),
            Team(
                id: UUID(),
                name: "Flavor Explorers",
                description: "Discovering new tastes together",
                imageIcon: "🧭",
                color: "#667eea",
                captain: "captain2",
                members: ["captain2", "member5", "member6"],
                totalPoints: 98000,
                weeklyPoints: 6200,
                weeklyGoal: 8000,
                activeChallenges: [],
                achievements: [],
                isPublic: true,
                joinCode: "EXPLOR",
                maxMembers: 15,
                completedChallenges: 32,
                createdAt: Date().addingTimeInterval(-5184000),
                region: "UK"
            )
        ]
        
        // Mock top teams for leaderboard
        topTeams = publicTeams.sorted { $0.weeklyPoints > $1.weeklyPoints }
    }
    
    private func generateMockMembers(count: Int) -> [TeamMember] {
        var members: [TeamMember] = []
        let usernames = ["ChefPro", "CookMaster", "RecipeKing", "FlavorQueen", "SpiceWizard", "KitchenHero", "FoodNinja", "MealMagic"]
        
        for i in 0..<count {
            members.append(
                TeamMember(
                    id: UUID(),
                    userId: "user\(i)",
                    username: "\(usernames.randomElement()!)\(i)",
                    avatar: "person.circle.fill",
                    role: i == 0 ? .coCaptain : .member,
                    points: Int.random(in: 1000...10000),
                    joinedAt: Date().addingTimeInterval(Double(-i * 86400)),
                    lastActive: Date().addingTimeInterval(Double(-i * 3600))
                )
            )
        }
        
        return members
    }
}

// MARK: - Team Chat Message
struct TeamChatMessage: Identifiable {
    let id: UUID
    let teamId: UUID
    let senderId: String
    let senderName: String
    let message: String
    let timestamp: Date
}


// MARK: - Notification Manager Extension
extension ChallengeNotificationManager {
    func notifyTeamChallengeComplete(teamName: String, challengeName: String, reward: TeamChallengeReward) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Team Challenge Complete! 🎊"
        content.body = "Your team \"\(teamName)\" completed \(challengeName)! Everyone earned \(reward.memberPoints) points!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("celebration.wav"))
        
        let request = UNNotificationRequest(
            identifier: "team_challenge_complete_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        Task.detached {
            let center = UNUserNotificationCenter.current()
            try? await center.add(request)
        }
    }
}