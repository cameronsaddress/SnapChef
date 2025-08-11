import SwiftUI
import Combine
import CloudKit

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var entries: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUserRank: Int?
    
    private let cloudKitManager = CloudKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe leaderboard updates from GamificationManager
        GamificationManager.shared.$globalLeaderboard
            .receive(on: DispatchQueue.main)
            .sink { [weak self] leaderboard in
                self?.entries = leaderboard
                self?.updateCurrentUserRank()
            }
            .store(in: &cancellables)
    }
    
    func refreshLeaderboard(timeframe: LeaderboardTimeframe) {
        Task {
            await loadLeaderboard(timeframe: timeframe)
        }
    }
    
    @MainActor
    private func loadLeaderboard(timeframe: LeaderboardTimeframe) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch from CloudKit
            let cloudKitEntries = try await cloudKitManager.fetchLeaderboard(
                limit: 100,
                timeframe: timeframe
            )
            
            // Update entries
            self.entries = cloudKitEntries
            
            // Update GamificationManager
            if timeframe == .allTime {
                GamificationManager.shared.globalLeaderboard = cloudKitEntries
            } else if timeframe == .weekly {
                GamificationManager.shared.weeklyLeaderboard = cloudKitEntries
            }
            
            updateCurrentUserRank()
            
        } catch {
            errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
            print("❌ Leaderboard error: \(error)")
        }
        
        isLoading = false
    }
    
    private func updateCurrentUserRank() {
        guard let currentUserId = AuthenticationManager().currentUser?.id else { return }
        
        currentUserRank = entries.firstIndex(where: { $0.isCurrentUser }) ?? nil
    }
    
    func uploadMockData() async {
        // Create some mock leaderboard entries for testing
        let mockUsers = [
            ("ChefMaster2000", 15420, 5),
            ("CookingNinja", 12350, 4),
            ("RecipeKing", 10200, 4),
            ("FoodieQueen", 8900, 3),
            ("KitchenHero", 7650, 3),
            ("SnapChefPro", 6200, 2),
            ("CulinaryArtist", 5100, 2),
            ("HomeCook123", 4300, 2),
            ("RecipeLover", 3200, 1),
            ("NewChef", 1500, 1)
        ]
        
        for (index, userData) in mockUsers.enumerated() {
            do {
                try await cloudKitManager.updateLeaderboardEntry(
                    for: "mock_user_\(index)",
                    points: userData.1,
                    challengesCompleted: userData.2
                )
                print("✅ Created mock user: \(userData.0)")
            } catch {
                print("❌ Failed to create mock user: \(error)")
            }
        }
    }
}