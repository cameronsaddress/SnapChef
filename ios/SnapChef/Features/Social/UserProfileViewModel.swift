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
        print("🔍 Loading user profile for userID: \(userID)")

        do {
            // Try to load user profile from UserProfile record type first
            if let userProfileRecord = try await cloudKitUserManager.fetchUserProfile(userID: userID) {
                print("✅ Found UserProfile record for userID: \(userID)")
                // Convert UserProfile record to CloudKitUser for compatibility
                self.userProfile = UserProfileConverter.convertUserProfileToCloudKitUser(userProfileRecord)
                
                // Check if following
                if cloudKitAuth.isAuthenticated {
                    self.isFollowing = await checkIfFollowing(userID: userID)
                }

                // Load user's recipes
                await loadUserRecipes(userID: userID)

                // Load and apply dynamic stats first
                await loadUserStats(userID: userID)
                
                // Load achievements after stats are calculated
                loadAchievements()
            } else {
                print("⚠️ UserProfile record not found, trying User record type for userID: \(userID)")
                // Fallback: Try to load from User record type directly by record ID
                await loadFromUserRecordType(userID: userID)
            }
        } catch {
            print("❌ Failed to load user profile from UserProfile: \(error)")
            // Fallback: Try to load from User record type directly
            await loadFromUserRecordType(userID: userID)
        }

        isLoading = false
    }
    
    private func loadFromUserRecordType(userID: String) async {
        do {
            print("🔄 Attempting to load from User record type with ID: \(userID)")
            let recordID = CKRecord.ID(recordName: userID)
            let userRecord = try await database.record(for: recordID)
            
            print("✅ Found User record for userID: \(userID)")
            self.userProfile = CloudKitUser(from: userRecord)
            
            // Check if following
            if cloudKitAuth.isAuthenticated {
                self.isFollowing = await checkIfFollowing(userID: userID)
            }

            // Load user's recipes
            await loadUserRecipes(userID: userID)

            // Load and apply dynamic stats first
            await loadUserStats(userID: userID)
            
            // Load achievements after stats are calculated
            loadAchievements()
        } catch {
            print("❌ Failed to load from User record type: \(error)")
            print("❌ This might be due to record ID format mismatch or record not existing")
        }
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
        // Calculate achievements based on user data - these update dynamically
        let recipeCount = userRecipes.count
        let followerCount = userProfile?.followerCount ?? 0
        let isVerified = userProfile?.isVerified ?? false
        let challengesCompleted = userProfile?.challengesCompleted ?? 0
        
        achievements = [
            UserAchievement(id: "first_recipe", title: "First Recipe", icon: "🍳", isUnlocked: recipeCount >= 1),
            UserAchievement(id: "recipe_explorer", title: "Explorer", icon: "🧭", isUnlocked: recipeCount >= 10),
            UserAchievement(id: "master_chef", title: "Master Chef", icon: "👨‍🍳", isUnlocked: recipeCount >= 50),
            UserAchievement(id: "social_butterfly", title: "Social", icon: "🦋", isUnlocked: followerCount >= 10),
            UserAchievement(id: "trendsetter", title: "Trendsetter", icon: "✨", isUnlocked: totalLikes >= 100),
            UserAchievement(id: "challenger", title: "Challenger", icon: "🏆", isUnlocked: challengesCompleted >= 5),
            UserAchievement(id: "verified", title: "Verified", icon: "✅", isUnlocked: isVerified)
        ]
        
        print("✅ UserProfileViewModel: Loaded \(achievements.filter { $0.isUnlocked }.count) unlocked achievements for user")
    }

    private func calculateStats(userID: String) async {
        // Calculate total likes from all user's recipes (not just the ones in view)
        await calculateTotalLikes(userID: userID)

        // Calculate total cooking time based on recipe cooking times
        await calculateTotalCookingTime(userID: userID)
    }
    
    private func calculateTotalLikes(userID: String) async {
        let predicate = NSPredicate(format: "%K == %@", CKField.Recipe.ownerID, userID)
        let query = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            var totalLikes = 0
            
            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    let likeCount = Int(record[CKField.Recipe.likeCount] as? Int64 ?? 0)
                    totalLikes += likeCount
                }
            }
            
            self.totalLikes = totalLikes
            print("✅ UserProfileViewModel: Calculated total likes: \(totalLikes) for user \(userID)")
        } catch {
            print("❌ Failed to calculate total likes: \(error)")
            // Fallback to recipes already loaded
            self.totalLikes = userRecipes.reduce(0) { $0 + $1.likeCount }
        }
    }
    
    private func calculateTotalCookingTime(userID: String) async {
        let predicate = NSPredicate(format: "%K == %@", CKField.Recipe.ownerID, userID)
        let query = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            var totalTime = 0
            
            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    let cookingTime = Int(record[CKField.Recipe.cookingTime] as? Int64 ?? 30) // Default 30 mins
                    totalTime += cookingTime
                }
            }
            
            self.totalCookingTime = totalTime
        } catch {
            print("❌ Failed to calculate cooking time: \(error)")
            // Fallback calculation
            self.totalCookingTime = userRecipes.count * 30
        }
    }
    
    /// Load comprehensive user stats from CloudKit
    func loadUserStats(userID: String) async {
        isLoadingStats = true
        
        do {
            let stats = try await cloudKitUserManager.getUserStats(for: userID)
            self.dynamicStats = stats
            
            // Calculate challenges completed from UserChallenge records
            let challengesCompleted = await calculateChallengesCompleted(userID: userID)
            
            // Calculate total points from user profile and any additional sources
            let totalPoints = await calculateTotalPoints(userID: userID)
            
            // Update the user profile with dynamic stats if we have it
            if var profile = self.userProfile {
                profile.followerCount = stats.followerCount
                profile.followingCount = stats.followingCount
                profile.recipesShared = stats.recipeCount
                profile.currentStreak = stats.currentStreak
                profile.challengesCompleted = challengesCompleted
                profile.totalPoints = totalPoints
                self.userProfile = profile
                print("✅ UserProfileViewModel: Updated profile with dynamic stats - followers: \(stats.followerCount), following: \(stats.followingCount), recipes: \(stats.recipeCount), challenges: \(challengesCompleted), points: \(totalPoints)")
            }
            
            // Calculate additional stats for display
            await calculateStats(userID: userID)
            
        } catch {
            print("❌ UserProfileViewModel: Failed to load user stats: \(error)")
        }
        
        isLoadingStats = false
    }
    
    /// Calculate challenges completed for a user
    private func calculateChallengesCompleted(userID: String) async -> Int {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@", 
                                  CKField.UserChallenge.userID, userID,
                                  CKField.UserChallenge.status, "completed")
        let query = CKQuery(recordType: CloudKitConfig.userChallengeRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            return results.matchResults.count
        } catch {
            print("❌ Failed to calculate challenges completed: \(error)")
            return 0
        }
    }
    
    /// Calculate total points for a user
    private func calculateTotalPoints(userID: String) async -> Int {
        // First try to get points from user profile
        do {
            if let userProfileRecord = try await cloudKitUserManager.fetchUserProfile(userID: userID) {
                let profilePoints = userProfileRecord["totalPoints"] as? Int ?? 0
                
                // Also calculate points from completed challenges
                let challengePoints = await calculatePointsFromChallenges(userID: userID)
                
                return max(profilePoints, challengePoints) // Use the higher value
            }
        } catch {
            print("❌ Failed to get profile points: \(error)")
        }
        
        return 0
    }
    
    /// Calculate points earned from challenges
    private func calculatePointsFromChallenges(userID: String) async -> Int {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@", 
                                  CKField.UserChallenge.userID, userID,
                                  CKField.UserChallenge.status, "completed")
        let query = CKQuery(recordType: CloudKitConfig.userChallengeRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            var totalPoints = 0
            
            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    let earnedPoints = Int(record[CKField.UserChallenge.earnedPoints] as? Int64 ?? 0)
                    totalPoints += earnedPoints
                }
            }
            
            return totalPoints
        } catch {
            print("❌ Failed to calculate points from challenges: \(error)")
            return 0
        }
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

    func calculateLevel(points: Int) -> Int {
        return min(1 + (points / 1_000), 99) // Level up every 1000 points
    }

    func levelProgress(points: Int) -> Double {
        guard points >= 0 else { return 0.0 }
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
        let cloudKitUserManager = CloudKitUserManager.shared

        for userID in userIDs {
            do {
                // Load from UserProfile record type instead of User
                if let userProfileRecord = try await cloudKitUserManager.fetchUserProfile(userID: userID) {
                    let user = UserProfileConverter.convertUserProfileToCloudKitUser(userProfileRecord)
                    loadedUsers.append(user)
                }
            } catch {
                print("Failed to load user \(userID): \(error)")
            }
        }

        self.users = loadedUsers
    }
}

// MARK: - User Profile Converter
struct UserProfileConverter {
    /// Convert UserProfile record to CloudKitUser format
    static func convertUserProfileToCloudKitUser(_ record: CKRecord) -> CloudKitUser {
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
        
        // Set default values for other fields that will be updated dynamically
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
}
