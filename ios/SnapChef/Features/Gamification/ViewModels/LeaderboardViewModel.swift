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
        currentUserRank = entries.firstIndex(where: { $0.isCurrentUser })
    }

    func uploadMockData() async {
        // Create some mock leaderboard entries for testing
        let mockUsers = [
            ("ChefMaster2000", 15_420, 5),
            ("CookingNinja", 12_350, 4),
            ("RecipeKing", 10_200, 4),
            ("FoodieQueen", 8_900, 3),
            ("KitchenHero", 7_650, 3),
            ("SnapChefPro", 6_200, 2),
            ("CulinaryArtist", 5_100, 2),
            ("HomeCook123", 4_300, 2),
            ("RecipeLover", 3_200, 1),
            ("NewChef", 1_500, 1)
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
