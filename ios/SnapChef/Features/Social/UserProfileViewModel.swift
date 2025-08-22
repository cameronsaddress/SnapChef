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

    private let cloudKitAuth = UnifiedAuthManager.shared
    private let cloudKitSync = CloudKitSyncService.shared
    private let cloudKitUserManager = CloudKitUserManager.shared
    private let database = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase

    func loadUserProfile(userID: String) async {
        isLoading = true
        print("🔍 DEBUG UserProfile: Starting loadUserProfile for userID: '\(userID)'")
        print("🔍 DEBUG UserProfile: UserID length: \(userID.count)")
        print("🔍 DEBUG UserProfile: UserID contains non-ASCII: \(userID.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil)")

        do {
            // Try to load user profile from UserProfile record type first
            if let userProfileRecord = try await cloudKitUserManager.fetchUserProfile(userID: userID) {
                print("✅ DEBUG UserProfile: Found UserProfile record for userID: '\(userID)'")
                print("🔍 DEBUG UserProfile: UserProfile record ID: \(userProfileRecord.recordID.recordName)")
                // Convert UserProfile record to CloudKitUser for compatibility
                self.userProfile = UserProfileConverter.convertUserProfileToCloudKitUser(userProfileRecord)
                
                // Check if following
                if cloudKitAuth.isAuthenticated {
                    print("🔍 DEBUG UserProfile: Checking follow status for userID: '\(userID)'")
                    self.isFollowing = await checkIfFollowing(userID: userID)
                }

                // Load user's recipes
                print("🔍 DEBUG UserProfile: About to load recipes for userID: '\(userID)'")
                await loadUserRecipes(userID: userID)

                // Load and apply dynamic stats first
                print("🔍 DEBUG UserProfile: About to load user stats for userID: '\(userID)'")
                await loadUserStats(userID: userID)
                
                // Load achievements after stats are calculated
                print("🔍 DEBUG UserProfile: About to load achievements")
                loadAchievements()
            } else {
                print("⚠️ DEBUG UserProfile: UserProfile record not found, trying User record type for userID: '\(userID)'")
                // Fallback: Try to load from User record type directly by record ID
                await loadFromUserRecordType(userID: userID)
            }
        } catch {
            print("❌ DEBUG UserProfile: Failed to load user profile from UserProfile: \(error)")
            print("❌ DEBUG UserProfile: Error type: \(type(of: error))")
            // Fallback: Try to load from User record type directly
            await loadFromUserRecordType(userID: userID)
        }

        print("🔍 DEBUG UserProfile: Finished loadUserProfile for userID: '\(userID)'")
        isLoading = false
    }
    
    private func loadFromUserRecordType(userID: String) async {
        do {
            print("🔄 DEBUG UserProfile: Attempting to load from User record type with ID: '\(userID)'")
            let recordID = CKRecord.ID(recordName: userID)
            print("🔍 DEBUG UserProfile: Created recordID: \(recordID)")
            let userRecord = try await database.record(for: recordID)
            
            print("✅ DEBUG UserProfile: Found User record for userID: '\(userID)'")
            print("🔍 DEBUG UserProfile: User record ID: \(userRecord.recordID.recordName)")
            self.userProfile = CloudKitUser(from: userRecord)
            
            // Check if following
            if cloudKitAuth.isAuthenticated {
                print("🔍 DEBUG UserProfile: Checking follow status for userID: '\(userID)'")
                self.isFollowing = await checkIfFollowing(userID: userID)
            }

            // Load user's recipes
            print("🔍 DEBUG UserProfile: About to load recipes from User record fallback for userID: '\(userID)'")
            await loadUserRecipes(userID: userID)

            // Load and apply dynamic stats first
            print("🔍 DEBUG UserProfile: About to load user stats from User record fallback for userID: '\(userID)'")
            await loadUserStats(userID: userID)
            
            // Load achievements after stats are calculated
            print("🔍 DEBUG UserProfile: About to load achievements from User record fallback")
            loadAchievements()
        } catch {
            print("❌ DEBUG UserProfile: Failed to load from User record type: \(error)")
            print("❌ DEBUG UserProfile: Error type: \(type(of: error))")
            print("❌ DEBUG UserProfile: This might be due to record ID format mismatch or record not existing")
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
        print("🔍 DEBUG UserProfile: Starting loadUserRecipes for userID: '\(userID)'")
        
        let predicate = NSPredicate(format: "%K == %@", CKField.Recipe.ownerID, userID)
        print("🔍 DEBUG UserProfile: Recipe query predicate: \(predicate)")
        print("🔍 DEBUG UserProfile: Recipe field being queried: '\(CKField.Recipe.ownerID)'")
        print("🔍 DEBUG UserProfile: UserID being searched: '\(userID)'")
        
        let query = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: CKField.Recipe.createdAt, ascending: false)]
        print("🔍 DEBUG UserProfile: Query record type: \(CloudKitConfig.recipeRecordType)")

        do {
            print("🔍 DEBUG UserProfile: Executing recipe query...")
            let results = try await database.records(matching: query)
            print("🔍 DEBUG UserProfile: Query completed, processing results...")
            print("🔍 DEBUG UserProfile: Total match results: \(results.matchResults.count)")
            
            var recipes: [RecipeData] = []
            var successCount = 0
            var errorCount = 0

            for (recordID, result) in results.matchResults {
                print("🔍 DEBUG UserProfile: Processing result for record: \(recordID)")
                if case .success(let record) = result {
                    successCount += 1
                    let ownerID = record[CKField.Recipe.ownerID] as? String ?? "Unknown"
                    print("🔍 DEBUG UserProfile: Recipe \(record.recordID.recordName) has ownerID: '\(ownerID)'")
                    
                    let recipe = RecipeData(
                        id: record.recordID.recordName,
                        title: record[CKField.Recipe.title] as? String ?? "Untitled",
                        imageURL: record[CKField.Recipe.imageURL] as? String,
                        likeCount: Int(record[CKField.Recipe.likeCount] as? Int64 ?? 0),
                        createdAt: record[CKField.Recipe.createdAt] as? Date ?? Date()
                    )
                    recipes.append(recipe)
                    print("🔍 DEBUG UserProfile: Added recipe: '\(recipe.title)' with \(recipe.likeCount) likes")
                } else if case .failure(let error) = result {
                    errorCount += 1
                    print("❌ DEBUG UserProfile: Failed to process record \(recordID): \(error)")
                }
            }

            print("🔍 DEBUG UserProfile: Recipe processing complete - Success: \(successCount), Errors: \(errorCount)")
            print("🔍 DEBUG UserProfile: Final recipes array count: \(recipes.count)")
            
            self.userRecipes = recipes
            print("✅ DEBUG UserProfile: Set userRecipes with \(recipes.count) recipes for userID: '\(userID)'")
        } catch {
            print("❌ DEBUG UserProfile: Failed to load user recipes: \(error)")
            print("❌ DEBUG UserProfile: Error type: \(type(of: error))")
            print("❌ DEBUG UserProfile: UserID that failed: '\(userID)'")
        }
    }

    private func loadAchievements() {
        print("🔍 DEBUG UserProfile: Starting loadAchievements")
        
        // Calculate achievements based on user data - these update dynamically
        let recipeCount = userRecipes.count
        let followerCount = userProfile?.followerCount ?? 0
        let isVerified = userProfile?.isVerified ?? false
        let challengesCompleted = userProfile?.challengesCompleted ?? 0
        
        print("🔍 DEBUG UserProfile: Achievement calculation data:")
        print("  - Recipe count: \(recipeCount)")
        print("  - Follower count: \(followerCount)")
        print("  - Is verified: \(isVerified)")
        print("  - Challenges completed: \(challengesCompleted)")
        print("  - Total likes: \(totalLikes)")
        print("  - UserID from profile: \(userProfile?.recordID ?? "nil")")
        
        achievements = [
            UserAchievement(id: "first_recipe", title: "First Recipe", icon: "🍳", isUnlocked: recipeCount >= 1),
            UserAchievement(id: "recipe_explorer", title: "Explorer", icon: "🧭", isUnlocked: recipeCount >= 10),
            UserAchievement(id: "master_chef", title: "Master Chef", icon: "👨‍🍳", isUnlocked: recipeCount >= 50),
            UserAchievement(id: "social_butterfly", title: "Social", icon: "🦋", isUnlocked: followerCount >= 10),
            UserAchievement(id: "trendsetter", title: "Trendsetter", icon: "✨", isUnlocked: totalLikes >= 100),
            UserAchievement(id: "challenger", title: "Challenger", icon: "🏆", isUnlocked: challengesCompleted >= 5),
            UserAchievement(id: "verified", title: "Verified", icon: "✅", isUnlocked: isVerified)
        ]
        
        let unlockedCount = achievements.filter { $0.isUnlocked }.count
        print("✅ DEBUG UserProfile: Loaded \(unlockedCount) unlocked achievements out of \(achievements.count) total")
        print("🔍 DEBUG UserProfile: Unlocked achievements: \(achievements.filter { $0.isUnlocked }.map { $0.title }.joined(separator: ", "))")
    }

    private func calculateStats(userID: String) async {
        // Calculate total likes from all user's recipes (not just the ones in view)
        await calculateTotalLikes(userID: userID)

        // Calculate total cooking time based on recipe cooking times
        await calculateTotalCookingTime(userID: userID)
    }
    
    private func calculateTotalLikes(userID: String) async {
        print("🔍 DEBUG UserProfile: Starting calculateTotalLikes for userID: '\(userID)'")
        
        let predicate = NSPredicate(format: "%K == %@", CKField.Recipe.ownerID, userID)
        print("🔍 DEBUG UserProfile: Total likes predicate: \(predicate)")
        print("🔍 DEBUG UserProfile: Using field: '\(CKField.Recipe.ownerID)' with userID: '\(userID)'")
        
        let query = CKQuery(recordType: CloudKitConfig.recipeRecordType, predicate: predicate)
        
        do {
            print("🔍 DEBUG UserProfile: Executing total likes query...")
            let results = try await database.records(matching: query)
            print("🔍 DEBUG UserProfile: Total likes query returned \(results.matchResults.count) results")
            
            var totalLikes = 0
            var processedRecipes = 0
            
            for (recordID, result) in results.matchResults {
                if case .success(let record) = result {
                    processedRecipes += 1
                    let likeCount = Int(record[CKField.Recipe.likeCount] as? Int64 ?? 0)
                    let recipeOwnerID = record[CKField.Recipe.ownerID] as? String ?? "Unknown"
                    print("🔍 DEBUG UserProfile: Recipe \(recordID) (owner: '\(recipeOwnerID)') has \(likeCount) likes")
                    totalLikes += likeCount
                }
            }
            
            print("🔍 DEBUG UserProfile: Processed \(processedRecipes) recipes for total likes calculation")
            print("✅ DEBUG UserProfile: Calculated total likes: \(totalLikes) for userID: '\(userID)'")
            
            self.totalLikes = totalLikes
        } catch {
            print("❌ DEBUG UserProfile: Failed to calculate total likes: \(error)")
            print("❌ DEBUG UserProfile: Error type: \(type(of: error))")
            print("❌ DEBUG UserProfile: UserID that failed: '\(userID)'")
            
            // Fallback to recipes already loaded
            let fallbackLikes = userRecipes.reduce(0) { $0 + $1.likeCount }
            self.totalLikes = fallbackLikes
            print("🔍 DEBUG UserProfile: Using fallback total likes: \(fallbackLikes) from \(userRecipes.count) loaded recipes")
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
        print("🔍 DEBUG UserProfile: Starting loadUserStats for userID: '\(userID)'")
        isLoadingStats = true
        
        do {
            print("🔍 DEBUG UserProfile: Fetching user stats from CloudKitUserManager...")
            let stats = try await cloudKitUserManager.getUserStats(for: userID)
            self.dynamicStats = stats
            print("🔍 DEBUG UserProfile: Retrieved stats - followers: \(stats.followerCount), following: \(stats.followingCount), recipes: \(stats.recipeCount), streak: \(stats.currentStreak)")
            
            // Calculate challenges completed from UserChallenge records
            print("🔍 DEBUG UserProfile: Calculating challenges completed...")
            let challengesCompleted = await calculateChallengesCompleted(userID: userID)
            
            // Calculate total points from user profile and any additional sources
            print("🔍 DEBUG UserProfile: Calculating total points...")
            let totalPoints = await calculateTotalPoints(userID: userID)
            
            // Update the user profile with dynamic stats if we have it
            if var profile = self.userProfile {
                print("🔍 DEBUG UserProfile: Updating profile with dynamic stats...")
                profile.followerCount = stats.followerCount
                profile.followingCount = stats.followingCount
                profile.recipesShared = stats.recipeCount
                profile.currentStreak = stats.currentStreak
                profile.challengesCompleted = challengesCompleted
                profile.totalPoints = totalPoints
                self.userProfile = profile
                print("✅ DEBUG UserProfile: Updated profile with dynamic stats - followers: \(stats.followerCount), following: \(stats.followingCount), recipes: \(stats.recipeCount), challenges: \(challengesCompleted), points: \(totalPoints)")
            } else {
                print("⚠️ DEBUG UserProfile: No user profile to update with dynamic stats")
            }
            
            // Calculate additional stats for display
            print("🔍 DEBUG UserProfile: Calculating additional stats...")
            await calculateStats(userID: userID)
            
        } catch {
            print("❌ DEBUG UserProfile: Failed to load user stats: \(error)")
            print("❌ DEBUG UserProfile: Error type: \(type(of: error))")
            print("❌ DEBUG UserProfile: UserID that failed: '\(userID)'")
        }
        
        print("🔍 DEBUG UserProfile: Finished loadUserStats for userID: '\(userID)'")
        isLoadingStats = false
    }
    
    /// Calculate challenges completed for a user
    private func calculateChallengesCompleted(userID: String) async -> Int {
        print("🔍 DEBUG UserProfile: Starting calculateChallengesCompleted for userID: '\(userID)'")
        
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@", 
                                  CKField.UserChallenge.userID, userID,
                                  CKField.UserChallenge.status, "completed")
        print("🔍 DEBUG UserProfile: Challenges predicate: \(predicate)")
        print("🔍 DEBUG UserProfile: Using userID field: '\(CKField.UserChallenge.userID)' with value: '\(userID)'")
        print("🔍 DEBUG UserProfile: Using status field: '\(CKField.UserChallenge.status)' with value: 'completed'")
        
        let query = CKQuery(recordType: CloudKitConfig.userChallengeRecordType, predicate: predicate)
        print("🔍 DEBUG UserProfile: Query record type: \(CloudKitConfig.userChallengeRecordType)")
        
        do {
            print("🔍 DEBUG UserProfile: Executing challenges query...")
            let results = try await database.records(matching: query)
            let challengeCount = results.matchResults.count
            print("✅ DEBUG UserProfile: Found \(challengeCount) completed challenges for userID: '\(userID)'")
            
            // Log details of each challenge found
            for (recordID, result) in results.matchResults {
                if case .success(let record) = result {
                    let challengeUserID = record[CKField.UserChallenge.userID] as? String ?? "Unknown"
                    let status = record[CKField.UserChallenge.status] as? String ?? "Unknown"
                    print("🔍 DEBUG UserProfile: Challenge \(recordID) - userID: '\(challengeUserID)', status: '\(status)'")
                }
            }
            
            return challengeCount
        } catch {
            print("❌ DEBUG UserProfile: Failed to calculate challenges completed: \(error)")
            print("❌ DEBUG UserProfile: Error type: \(type(of: error))")
            print("❌ DEBUG UserProfile: UserID that failed: '\(userID)'")
            return 0
        }
    }
    
    /// Calculate total points for a user
    private func calculateTotalPoints(userID: String) async -> Int {
        print("🔍 DEBUG UserProfile: Starting calculateTotalPoints for userID: '\(userID)'")
        
        // First try to get points from user profile
        do {
            print("🔍 DEBUG UserProfile: Fetching user profile for points calculation...")
            if let userProfileRecord = try await cloudKitUserManager.fetchUserProfile(userID: userID) {
                let profilePoints = userProfileRecord["totalPoints"] as? Int ?? 0
                print("🔍 DEBUG UserProfile: Profile points: \(profilePoints)")
                
                // Also calculate points from completed challenges
                print("🔍 DEBUG UserProfile: Calculating points from challenges...")
                let challengePoints = await calculatePointsFromChallenges(userID: userID)
                
                let finalPoints = max(profilePoints, challengePoints)
                print("✅ DEBUG UserProfile: Total points calculation - Profile: \(profilePoints), Challenges: \(challengePoints), Final: \(finalPoints)")
                return finalPoints
            } else {
                print("⚠️ DEBUG UserProfile: No user profile record found for points calculation")
            }
        } catch {
            print("❌ DEBUG UserProfile: Failed to get profile points: \(error)")
            print("❌ DEBUG UserProfile: Error type: \(type(of: error))")
            print("❌ DEBUG UserProfile: UserID that failed: '\(userID)'")
        }
        
        print("🔍 DEBUG UserProfile: Returning 0 points for userID: '\(userID)'")
        return 0
    }
    
    /// Calculate points earned from challenges
    private func calculatePointsFromChallenges(userID: String) async -> Int {
        print("🔍 DEBUG UserProfile: Starting calculatePointsFromChallenges for userID: '\(userID)'")
        
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@", 
                                  CKField.UserChallenge.userID, userID,
                                  CKField.UserChallenge.status, "completed")
        print("🔍 DEBUG UserProfile: Challenge points predicate: \(predicate)")
        print("🔍 DEBUG UserProfile: Using userID field: '\(CKField.UserChallenge.userID)' with value: '\(userID)'")
        
        let query = CKQuery(recordType: CloudKitConfig.userChallengeRecordType, predicate: predicate)
        print("🔍 DEBUG UserProfile: Challenge points query record type: \(CloudKitConfig.userChallengeRecordType)")
        
        do {
            print("🔍 DEBUG UserProfile: Executing challenge points query...")
            let results = try await database.records(matching: query)
            print("🔍 DEBUG UserProfile: Challenge points query returned \(results.matchResults.count) results")
            
            var totalPoints = 0
            var processedChallenges = 0
            
            for (recordID, result) in results.matchResults {
                if case .success(let record) = result {
                    processedChallenges += 1
                    let earnedPoints = Int(record[CKField.UserChallenge.earnedPoints] as? Int64 ?? 0)
                    let challengeUserID = record[CKField.UserChallenge.userID] as? String ?? "Unknown"
                    let status = record[CKField.UserChallenge.status] as? String ?? "Unknown"
                    print("🔍 DEBUG UserProfile: Challenge \(recordID) - userID: '\(challengeUserID)', status: '\(status)', points: \(earnedPoints)")
                    totalPoints += earnedPoints
                }
            }
            
            print("🔍 DEBUG UserProfile: Processed \(processedChallenges) challenges")
            print("✅ DEBUG UserProfile: Calculated \(totalPoints) total points from challenges for userID: '\(userID)'")
            
            return totalPoints
        } catch {
            print("❌ DEBUG UserProfile: Failed to calculate points from challenges: \(error)")
            print("❌ DEBUG UserProfile: Error type: \(type(of: error))")
            print("❌ DEBUG UserProfile: UserID that failed: '\(userID)'")
            return 0
        }
    }
    
    /// Check if current user is following the target user
    private func checkIfFollowing(userID: String) async -> Bool {
        print("🔍 DEBUG UserProfile: Starting checkIfFollowing for userID: '\(userID)'")
        
        guard let currentUserID = try? await cloudKitUserManager.getCurrentUserID() else {
            print("⚠️ DEBUG UserProfile: Could not get current user ID for follow check")
            return false
        }
        
        print("🔍 DEBUG UserProfile: Current user ID: '\(currentUserID)', Target user ID: '\(userID)'")
        
        guard currentUserID != userID else {
            print("🔍 DEBUG UserProfile: Current user is same as target user, not following self")
            return false
        }
        
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@ AND %K == %d",
                                  CKField.Follow.followerID, currentUserID,
                                  CKField.Follow.followingID, userID,
                                  CKField.Follow.isActive, 1)
        print("🔍 DEBUG UserProfile: Follow check predicate: \(predicate)")
        
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        print("🔍 DEBUG UserProfile: Follow query record type: \(CloudKitConfig.followRecordType)")
        
        do {
            print("🔍 DEBUG UserProfile: Executing follow check query...")
            let results = try await database.records(matching: query)
            let isFollowing = !results.matchResults.isEmpty
            print("✅ DEBUG UserProfile: Follow check result: \(isFollowing) (found \(results.matchResults.count) follow records)")
            return isFollowing
        } catch {
            print("❌ DEBUG UserProfile: Error checking follow status: \(error)")
            print("❌ DEBUG UserProfile: Error type: \(type(of: error))")
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
        print("🔍 DEBUG UserProfile: Starting UserProfile to CloudKitUser conversion")
        print("🔍 DEBUG UserProfile: Source record ID: \(record.recordID.recordName)")
        print("🔍 DEBUG UserProfile: Source record type: \(record.recordType)")
        
        // Extract data from UserProfile record
        let sourceUsername = record["username"] as? String
        let sourceDisplayName = record["displayName"] as? String
        let sourceTotalPoints = record["totalPoints"] as? Int ?? 0
        let sourceRecipesShared = record["recipesShared"] as? Int ?? 0
        let sourceFollowersCount = record["followersCount"] as? Int ?? 0
        let sourceFollowingCount = record["followingCount"] as? Int ?? 0
        let sourceIsVerified = record["isVerified"] as? Bool ?? false
        let sourceUserID = record["userID"] as? String ?? record.recordID.recordName
        let sourceBio = record["bio"] as? String ?? ""
        let sourceCreatedAt = record["createdAt"] as? Date ?? Date()
        let sourceUpdatedAt = record["updatedAt"] as? Date ?? Date()
        
        // Get profile image URL
        let profileImageURL: String?
        if let imageAsset = record["profileImageAsset"] as? CKAsset {
            profileImageURL = imageAsset.fileURL?.absoluteString
        } else {
            profileImageURL = nil
        }
        
        print("🔍 DEBUG UserProfile: Source data:")
        print("  - Username: '\(sourceUsername ?? "nil")'")
        print("  - Display name: '\(sourceDisplayName ?? "nil")'")
        print("  - Total points: \(sourceTotalPoints)")
        print("  - Recipes shared: \(sourceRecipesShared)")
        print("  - Followers count: \(sourceFollowersCount)")
        print("  - Following count: \(sourceFollowingCount)")
        print("  - Is verified: \(sourceIsVerified)")
        
        // Create CloudKitUser using the record directly
        let convertedUser = CloudKitUser(from: record)
        
        print("✅ DEBUG UserProfile: Converted CloudKitUser:")
        print("  - ID: '\(convertedUser.recordID ?? "nil")'")
        print("  - Username: '\(convertedUser.username ?? "nil")'")
        print("  - Display name: '\(convertedUser.displayName)'")
        print("  - Total points: \(convertedUser.totalPoints)")
        print("  - Recipes shared: \(convertedUser.recipesShared)")
        
        return convertedUser
    }
}
