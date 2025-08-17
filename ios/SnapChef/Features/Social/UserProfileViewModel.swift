import Foundation
import CloudKit

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var userProfile: CloudKitUser?
    @Published var isLoading = false
    @Published var isFollowing = false
    @Published var isLoadingFollow = false
    @Published var userRecipes: [RecipeData] = []
    @Published var achievements: [UserAchievement] = []
    @Published var totalLikes = 0
    @Published var totalCookingTime = 0

    private let cloudKitAuth = CloudKitAuthManager.shared
    private let cloudKitSync = CloudKitSyncService.shared
    private let database = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase

    func loadUserProfile(userID: String) async {
        isLoading = true

        do {
            // Load user profile
            let record = try await database.record(for: CKRecord.ID(recordName: userID))
            self.userProfile = CloudKitUser(from: record)

            // Check if following
            if cloudKitAuth.isAuthenticated {
                self.isFollowing = try await cloudKitAuth.isFollowing(userID)
            }

            // Load user's recipes
            await loadUserRecipes(userID: userID)

            // Load achievements
            loadAchievements()

            // Calculate stats
            await calculateStats(userID: userID)
        } catch {
            print("Failed to load user profile: \(error)")
        }

        isLoading = false
    }

    func toggleFollow(userID: String) async {
        isLoadingFollow = true

        do {
            if isFollowing {
                try await cloudKitAuth.unfollowUser(userID)
                isFollowing = false
            } else {
                try await cloudKitAuth.followUser(userID)
                isFollowing = true
            }
        } catch {
            print("Failed to toggle follow: \(error)")
        }

        isLoadingFollow = false
    }

    private func loadUserRecipes(userID: String) async {
        let predicate = NSPredicate(format: "%K == %@", CKField.Recipe.ownerID, userID)
        let query = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.Recipe.createdAt, ascending: false)]

        do {
            let results = try await database.records(matching: query)
            var recipes: [RecipeData] = []

            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    let recipe = RecipeData(
                        id: record.recordID.recordName,
                        title: record[CKField.Recipe.title] as? String ?? "Untitled",
                        imageURL: record[CKField.Recipe.imageURL] as? String,
                        likeCount: Int(record[CKField.Recipe.likeCount] as? Int64 ?? 0),
                        createdAt: record[CKField.Recipe.createdAt] as? Date ?? Date()
                    )
                    recipes.append(recipe)
                }
            }

            self.userRecipes = recipes
        } catch {
            print("Failed to load user recipes: \(error)")
        }
    }

    private func loadAchievements() {
        // Sample achievements - in a real app, these would be calculated based on user data
        achievements = [
            UserAchievement(id: "first_recipe", title: "First Recipe", icon: "🍳", isUnlocked: userRecipes.count >= 1),
            UserAchievement(id: "recipe_explorer", title: "Explorer", icon: "🧭", isUnlocked: userRecipes.count >= 10),
            UserAchievement(id: "master_chef", title: "Master Chef", icon: "👨‍🍳", isUnlocked: userRecipes.count >= 50),
            UserAchievement(id: "social_butterfly", title: "Social", icon: "🦋", isUnlocked: userProfile?.followerCount ?? 0 >= 10),
            UserAchievement(id: "trendsetter", title: "Trendsetter", icon: "✨", isUnlocked: totalLikes >= 100),
            UserAchievement(id: "verified", title: "Verified", icon: "✅", isUnlocked: userProfile?.isVerified ?? false)
        ]
    }

    private func calculateStats(userID: String) async {
        // Calculate total likes from all recipes
        totalLikes = userRecipes.reduce(0) { $0 + $1.likeCount }

        // Calculate total cooking time (mock data for now)
        totalCookingTime = userRecipes.count * 45 // Average 45 mins per recipe
    }

    func calculateLevel(points: Int) -> Int {
        return min(1 + (points / 1_000), 99) // Level up every 1000 points
    }

    func levelProgress(points: Int) -> Double {
        let currentLevelPoints = (points % 1_000)
        return Double(currentLevelPoints) / 1_000.0
    }

    func pointsToNextLevel(points: Int) -> Int {
        return 1_000 - (points % 1_000)
    }
}

// MARK: - Follow List View Model
@MainActor
class FollowListViewModel: ObservableObject {
    @Published var users: [CloudKitUser] = []
    @Published var isLoading = false

    private let database = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase

    func loadUsers(userID: String, mode: FollowListView.FollowMode) async {
        isLoading = true

        let predicate: NSPredicate
        switch mode {
        case .followers:
            predicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                  CKField.Follow.followingID, userID,
                                  CKField.Follow.isActive, 1)
        case .following:
            predicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                  CKField.Follow.followerID, userID,
                                  CKField.Follow.isActive, 1)
        }

        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)

        do {
            let results = try await database.records(matching: query)
            var userIDs: [String] = []

            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    let userID = mode == .followers ?
                        record[CKField.Follow.followerID] as? String :
                        record[CKField.Follow.followingID] as? String

                    if let userID = userID {
                        userIDs.append(userID)
                    }
                }
            }

            // Load user details for each ID
            await loadUserDetails(userIDs: userIDs)
        } catch {
            print("Failed to load follow list: \(error)")
        }

        isLoading = false
    }

    private func loadUserDetails(userIDs: [String]) async {
        var loadedUsers: [CloudKitUser] = []

        for userID in userIDs {
            do {
                let record = try await database.record(for: CKRecord.ID(recordName: userID))
                let user = CloudKitUser(from: record)
                loadedUsers.append(user)
            } catch {
                print("Failed to load user \(userID): \(error)")
            }
        }

        self.users = loadedUsers
    }
}
