import Foundation
import CloudKit

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var userProfile: CloudKitUser?
    @Published var isLoading = false
    @Published var isFollowing = false
    @Published var isLoadingFollow = false
    @Published var isLoadingStats = false
    @Published var userRecipes: [RecipeData] = []
    @Published var achievements: [UserAchievement] = []
    @Published var totalLikes = 0
    @Published var totalCookingTime = 0
    @Published var dynamicStats: UserStats?

    private let cloudKitAuth = CloudKitAuthManager.shared
    private let cloudKitSync = CloudKitSyncService.shared
    private let cloudKitUserManager = CloudKitUserManager.shared
    private let database = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase

    func loadUserProfile(userID: String) async {
        isLoading = true

        do {
            // Load user profile
            let record = try await database.record(for: CKRecord.ID(recordName: userID))
            self.userProfile = CloudKitUser(from: record)

            // Check if following
            if cloudKitAuth.isAuthenticated {
                self.isFollowing = await cloudKitAuth.isFollowing(userID: userID)
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
                try await cloudKitAuth.unfollowUser(userID: userID)
                isFollowing = false
            } else {
                try await cloudKitAuth.followUser(userID: userID)
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
    
    /// Load comprehensive user stats from CloudKit
    func loadUserStats(userID: String) async {
        isLoadingStats = true
        
        do {
            let stats = try await cloudKitUserManager.getUserStats(for: userID)
            self.dynamicStats = stats
            
            // Update the user profile with dynamic stats if we have it
            if var profile = self.userProfile {
                profile.followerCount = stats.followerCount
                profile.followingCount = stats.followingCount
                profile.recipesShared = stats.recipeCount
                profile.currentStreak = stats.currentStreak
                self.userProfile = profile
                print("✅ UserProfileViewModel: Updated profile with dynamic stats - followers: \(stats.followerCount), following: \(stats.followingCount), recipes: \(stats.recipeCount)")
            }
        } catch {
            print("❌ UserProfileViewModel: Failed to load user stats: \(error)")
        }
        
        isLoadingStats = false
    }
    
    /// Check if current user is following the target user
    private func checkIfFollowing(userID: String) async -> Bool {
        guard let currentUserID = try? await cloudKitUserManager.getCurrentUserID(),
              currentUserID != userID else {
            return false
        }
        
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@ AND %K == %d",
                                  CKField.Follow.followerID, currentUserID,
                                  CKField.Follow.followingID, userID,
                                  CKField.Follow.isActive, 1)
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            return !results.matchResults.isEmpty
        } catch {
            print("❌ Error checking follow status: \(error)")
            return false
        }
    }
    
    /// Convert UserProfile record to CloudKitUser format
    private func convertUserProfileToCloudKitUser(_ record: CKRecord) -> CloudKitUser {
        // Create a new record with User record type fields mapped from UserProfile
        let userRecord = CKRecord(recordType: "User", recordID: record.recordID)
        
        // Map UserProfile fields to User fields
        userRecord[CKField.User.username] = record["username"] as? String
        userRecord[CKField.User.displayName] = record["displayName"] as? String ?? record["username"] as? String ?? "Anonymous Chef"
        userRecord[CKField.User.email] = "" // Not stored in UserProfile
        userRecord[CKField.User.profileImageURL] = (record["profileImageAsset"] as? CKAsset)?.fileURL?.absoluteString
        userRecord[CKField.User.totalPoints] = Int64(record["totalPoints"] as? Int ?? 0)
        userRecord[CKField.User.recipesShared] = Int64(record["recipesShared"] as? Int ?? 0)
        userRecord[CKField.User.followerCount] = Int64(record["followersCount"] as? Int ?? 0)
        userRecord[CKField.User.followingCount] = Int64(record["followingCount"] as? Int ?? 0)
        userRecord[CKField.User.isVerified] = Int64((record["isVerified"] as? Bool ?? false) ? 1 : 0)
        userRecord[CKField.User.createdAt] = record["createdAt"] as? Date ?? Date()
        userRecord[CKField.User.lastLoginAt] = record["updatedAt"] as? Date ?? Date()
        userRecord[CKField.User.lastActiveAt] = record["updatedAt"] as? Date ?? Date()
        
        // Set default values for other fields
        userRecord[CKField.User.authProvider] = "cloudkit"
        userRecord[CKField.User.currentStreak] = Int64(0)
        userRecord[CKField.User.longestStreak] = Int64(0)
        userRecord[CKField.User.challengesCompleted] = Int64(0)
        userRecord[CKField.User.recipesCreated] = Int64(record["recipesShared"] as? Int ?? 0)
        userRecord[CKField.User.coinBalance] = Int64(0)
        userRecord[CKField.User.isProfilePublic] = Int64(1)
        userRecord[CKField.User.showOnLeaderboard] = Int64(1)
        userRecord[CKField.User.subscriptionTier] = "free"
        
        return CloudKitUser(from: userRecord)
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
