import Foundation
import CloudKit

private let userProfileDebugLoggingEnabled = false

private func userProfileDebugLog(_ message: @autoclosure () -> String) {
#if DEBUG
    guard userProfileDebugLoggingEnabled else { return }
    Swift.print(message())
#endif
}

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
    private let cloudKitUserManager = CloudKitUserManager.shared
    private lazy var database: CKDatabase? = {
        CloudKitRuntimeSupport.makeContainer()?.publicCloudDatabase
    }()

    func loadUserProfile(userID: String) async {
        let normalizedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedUserID.isEmpty else {
            isLoading = false
            userProfile = nil
            userRecipes = []
            achievements = []
            dynamicStats = nil
            totalLikes = 0
            totalCookingTime = 0
            return
        }

        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            isLoading = false
            userProfile = nil
            userRecipes = []
            achievements = []
            dynamicStats = nil
            totalLikes = 0
            totalCookingTime = 0
            return
        }

        // Avoid triggering iCloud system prompts when the device isn't signed into iCloud.
        guard FileManager.default.ubiquityIdentityToken != nil else {
            isLoading = false
            userProfile = nil
            userRecipes = []
            achievements = []
            dynamicStats = nil
            totalLikes = 0
            totalCookingTime = 0
            return
        }

        isLoading = true
        userProfileDebugLog("🔍 DEBUG UserProfile: Starting loadUserProfile for userID: '\(normalizedUserID)'")
        userProfileDebugLog("🔍 DEBUG UserProfile: UserID length: \(normalizedUserID.count)")
        userProfileDebugLog("🔍 DEBUG UserProfile: UserID contains non-ASCII: \(normalizedUserID.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil)")

        do {
            // Try to load user profile from UserProfile record type first
            if let userProfileRecord = try await cloudKitUserManager.fetchUserProfile(userID: normalizedUserID) {
                userProfileDebugLog("✅ DEBUG UserProfile: Found UserProfile record for userID: '\(normalizedUserID)'")
                userProfileDebugLog("🔍 DEBUG UserProfile: UserProfile record ID: \(userProfileRecord.recordID.recordName)")
                // Convert UserProfile record to CloudKitUser for compatibility
                self.userProfile = UserProfileConverter.convertUserProfileToCloudKitUser(userProfileRecord)
                
                // Check if following
                if cloudKitAuth.isAuthenticated {
                    userProfileDebugLog("🔍 DEBUG UserProfile: Checking follow status for userID: '\(normalizedUserID)'")
                    self.isFollowing = await checkIfFollowing(userID: normalizedUserID)
                }

                // Load user's recipes
                userProfileDebugLog("🔍 DEBUG UserProfile: About to load recipes for userID: '\(normalizedUserID)'")
                await loadUserRecipes(userID: normalizedUserID)

                // Update social counts for accurate display
                userProfileDebugLog("🔍 DEBUG UserProfile: Updating social counts for accurate display")
                await cloudKitAuth.updateSocialCounts()

                // Load and apply dynamic stats first
                userProfileDebugLog("🔍 DEBUG UserProfile: About to load user stats for userID: '\(normalizedUserID)'")
                await loadUserStats(userID: normalizedUserID)
                
                // Load achievements after stats are calculated
                userProfileDebugLog("🔍 DEBUG UserProfile: About to load achievements")
                loadAchievements()
            } else {
                userProfileDebugLog("⚠️ DEBUG UserProfile: UserProfile record not found, trying User record type for userID: '\(normalizedUserID)'")
                // Fallback: Try to load from User record type directly by record ID
                await loadFromUserRecordType(userID: normalizedUserID)
            }
        } catch {
            userProfileDebugLog("❌ DEBUG UserProfile: Failed to load user profile from UserProfile: \(error)")
            userProfileDebugLog("❌ DEBUG UserProfile: Error type: \(type(of: error))")
            // Fallback: Try to load from User record type directly
            await loadFromUserRecordType(userID: normalizedUserID)
        }

        userProfileDebugLog("🔍 DEBUG UserProfile: Finished loadUserProfile for userID: '\(normalizedUserID)'")
        isLoading = false
    }
    
    private func loadFromUserRecordType(userID: String) async {
        let normalizedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedUserID.isEmpty else {
            return
        }
        guard let database else { return }

        let canonicalUserID: String = {
            if normalizedUserID.hasPrefix("user_") {
                return String(normalizedUserID.dropFirst(5))
            }
            return normalizedUserID
        }()

        let recordNamesToTry: [String] = {
            var names: [String] = []
            names.append("user_\(canonicalUserID)")
            names.append(canonicalUserID)
            if normalizedUserID != canonicalUserID && normalizedUserID != "user_\(canonicalUserID)" {
                names.append(normalizedUserID)
            }
            var seen = Set<String>()
            return names.filter { seen.insert($0).inserted }
        }()

        userProfileDebugLog("🔄 DEBUG UserProfile: Attempting to load from User record type with ID: '\(normalizedUserID)'")
        var userRecord: CKRecord?
        for recordName in recordNamesToTry {
            do {
                let recordID = CKRecord.ID(recordName: recordName)
                userProfileDebugLog("🔍 DEBUG UserProfile: Trying recordID: \(recordID.recordName)")
                userRecord = try await database.record(for: recordID)
                break
            } catch {
                continue
            }
        }

        guard let userRecord else {
            userProfileDebugLog("❌ DEBUG UserProfile: Could not fetch User record for userID '\(normalizedUserID)'")
            return
        }

        userProfileDebugLog("✅ DEBUG UserProfile: Found User record for userID: '\(normalizedUserID)'")
        userProfileDebugLog("🔍 DEBUG UserProfile: User record ID: \(userRecord.recordID.recordName)")
        self.userProfile = CloudKitUser(from: userRecord)

        // Check if following
        if cloudKitAuth.isAuthenticated {
            userProfileDebugLog("🔍 DEBUG UserProfile: Checking follow status for userID: '\(normalizedUserID)'")
            self.isFollowing = await checkIfFollowing(userID: canonicalUserID)
        }

        // Load user's recipes
        userProfileDebugLog("🔍 DEBUG UserProfile: About to load recipes from User record fallback for userID: '\(normalizedUserID)'")
        await loadUserRecipes(userID: canonicalUserID)

        // Load and apply dynamic stats first
        userProfileDebugLog("🔍 DEBUG UserProfile: About to load user stats from User record fallback for userID: '\(normalizedUserID)'")
        await loadUserStats(userID: canonicalUserID)

        // Load achievements after stats are calculated
        userProfileDebugLog("🔍 DEBUG UserProfile: About to load achievements from User record fallback")
        loadAchievements()
    }

    func toggleFollow(userID: String) async {
        let normalizedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedUserID.isEmpty else { return }

        isLoadingFollow = true

        do {
            if isFollowing {
                try await cloudKitAuth.unfollowUser(userID: normalizedUserID)
                isFollowing = false
            } else {
                try await cloudKitAuth.followUser(userID: normalizedUserID)
                isFollowing = true
            }
        } catch {
            userProfileDebugLog("Failed to toggle follow: \(error)")
        }

        isLoadingFollow = false
    }

    private func loadUserRecipes(userID: String) async {
        guard let database else { return }
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
            userProfileDebugLog("✅ Loaded \(recipes.count) recipes for profile user \(userID)")
        } catch {
            userProfileDebugLog("❌ Failed to load user recipes for \(userID): \(error)")
        }
    }

    private func loadAchievements() {
        userProfileDebugLog("🔍 DEBUG UserProfile: Starting loadAchievements")
        
        // Calculate achievements based on user data - these update dynamically
        let recipeCount = userRecipes.count
        let followerCount = userProfile?.followerCount ?? 0
        let isVerified = userProfile?.isVerified ?? false
        let challengesCompleted = userProfile?.challengesCompleted ?? 0
        
        userProfileDebugLog("🔍 DEBUG UserProfile: Achievement calculation data:")
        userProfileDebugLog("  - Recipe count: \(recipeCount)")
        userProfileDebugLog("  - Follower count: \(followerCount)")
        userProfileDebugLog("  - Is verified: \(isVerified)")
        userProfileDebugLog("  - Challenges completed: \(challengesCompleted)")
        userProfileDebugLog("  - Total likes: \(totalLikes)")
        userProfileDebugLog("  - UserID from profile: \(userProfile?.recordID ?? "nil")")
        
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
        userProfileDebugLog("✅ DEBUG UserProfile: Loaded \(unlockedCount) unlocked achievements out of \(achievements.count) total")
        userProfileDebugLog("🔍 DEBUG UserProfile: Unlocked achievements: \(achievements.filter { $0.isUnlocked }.map { $0.title }.joined(separator: ", "))")
    }

    private func calculateStats(userID: String) async {
        // Calculate total likes from all user's recipes (not just the ones in view)
        await calculateTotalLikes(userID: userID)

        // Calculate total cooking time based on recipe cooking times
        await calculateTotalCookingTime(userID: userID)
    }
    
    private func calculateTotalLikes(userID: String) async {
        guard let database else {
            let fallbackLikes = userRecipes.reduce(0) { $0 + $1.likeCount }
            self.totalLikes = fallbackLikes
            userProfileDebugLog("⚠️ CloudKit unavailable - falling back to local like count for \(userID): \(fallbackLikes)")
            return
        }
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
        } catch {
            // Fallback to recipes already loaded
            let fallbackLikes = userRecipes.reduce(0) { $0 + $1.likeCount }
            self.totalLikes = fallbackLikes
            userProfileDebugLog("⚠️ Falling back to local like count for \(userID): \(fallbackLikes)")
        }
    }
    
    private func calculateTotalCookingTime(userID: String) async {
        guard let database else {
            self.totalCookingTime = userRecipes.count * 30
            return
        }
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
            userProfileDebugLog("❌ Failed to calculate cooking time: \(error)")
            // Fallback calculation
            self.totalCookingTime = userRecipes.count * 30
        }
    }
    
    /// Load comprehensive user stats from CloudKit
    func loadUserStats(userID: String) async {
        userProfileDebugLog("🔍 DEBUG UserProfile: Starting loadUserStats for userID: '\(userID)'")
        isLoadingStats = true
        
        do {
            userProfileDebugLog("🔍 DEBUG UserProfile: Fetching user stats from CloudKitUserManager...")
            let stats = try await cloudKitUserManager.getUserStats(for: userID)
            self.dynamicStats = stats
            userProfileDebugLog("🔍 DEBUG UserProfile: Retrieved stats - followers: \(stats.followerCount), following: \(stats.followingCount), recipes: \(stats.recipeCount), streak: \(stats.currentStreak)")
            
            // Calculate challenges completed from UserChallenge records
            userProfileDebugLog("🔍 DEBUG UserProfile: Calculating challenges completed...")
            let challengesCompleted = await calculateChallengesCompleted(userID: userID)
            
            // Calculate total points from user profile and any additional sources
            userProfileDebugLog("🔍 DEBUG UserProfile: Calculating total points...")
            let totalPoints = await calculateTotalPoints(userID: userID)
            
            // Update the user profile with dynamic stats if we have it
            if var profile = self.userProfile {
                userProfileDebugLog("🔍 DEBUG UserProfile: Updating profile with dynamic stats...")
                profile.followerCount = stats.followerCount
                profile.followingCount = stats.followingCount
                profile.recipesCreated = stats.recipeCount  // Fixed: Using recipesCreated instead of recipesShared
                profile.currentStreak = stats.currentStreak
                profile.challengesCompleted = challengesCompleted
                profile.totalPoints = totalPoints
                self.userProfile = profile
                userProfileDebugLog("✅ DEBUG UserProfile: Updated profile with dynamic stats - followers: \(stats.followerCount), following: \(stats.followingCount), recipes: \(stats.recipeCount), challenges: \(challengesCompleted), points: \(totalPoints)")
            } else {
                userProfileDebugLog("⚠️ DEBUG UserProfile: No user profile to update with dynamic stats")
            }
            
            // Calculate additional stats for display
            userProfileDebugLog("🔍 DEBUG UserProfile: Calculating additional stats...")
            await calculateStats(userID: userID)
            
        } catch {
            userProfileDebugLog("❌ DEBUG UserProfile: Failed to load user stats: \(error)")
            userProfileDebugLog("❌ DEBUG UserProfile: Error type: \(type(of: error))")
            userProfileDebugLog("❌ DEBUG UserProfile: UserID that failed: '\(userID)'")
        }
        
        userProfileDebugLog("🔍 DEBUG UserProfile: Finished loadUserStats for userID: '\(userID)'")
        isLoadingStats = false
    }
    
    /// Calculate challenges completed for a user
    private func calculateChallengesCompleted(userID: String) async -> Int {
        guard let database else { return 0 }
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@", 
                                  CKField.UserChallenge.userID, userID,
                                  CKField.UserChallenge.status, "completed")
        let query = CKQuery(recordType: CloudKitConfig.userChallengeRecordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            let challengeCount = results.matchResults.count
            
            return challengeCount
        } catch {
            userProfileDebugLog("❌ Failed to calculate completed challenges for \(userID): \(error)")
            return 0
        }
    }
    
    /// Calculate total points for a user
    private func calculateTotalPoints(userID: String) async -> Int {
        userProfileDebugLog("🔍 DEBUG UserProfile: Starting calculateTotalPoints for userID: '\(userID)'")
        
        // First try to get points from user profile
        do {
            userProfileDebugLog("🔍 DEBUG UserProfile: Fetching user profile for points calculation...")
            if let userProfileRecord = try await cloudKitUserManager.fetchUserProfile(userID: userID) {
                let profilePoints = userProfileRecord["totalPoints"] as? Int ?? 0
                userProfileDebugLog("🔍 DEBUG UserProfile: Profile points: \(profilePoints)")
                
                // Also calculate points from completed challenges
                userProfileDebugLog("🔍 DEBUG UserProfile: Calculating points from challenges...")
                let challengePoints = await calculatePointsFromChallenges(userID: userID)
                
                let finalPoints = max(profilePoints, challengePoints)
                userProfileDebugLog("✅ DEBUG UserProfile: Total points calculation - Profile: \(profilePoints), Challenges: \(challengePoints), Final: \(finalPoints)")
                return finalPoints
            } else {
                userProfileDebugLog("⚠️ DEBUG UserProfile: No user profile record found for points calculation")
            }
        } catch {
            userProfileDebugLog("❌ DEBUG UserProfile: Failed to get profile points: \(error)")
            userProfileDebugLog("❌ DEBUG UserProfile: Error type: \(type(of: error))")
            userProfileDebugLog("❌ DEBUG UserProfile: UserID that failed: '\(userID)'")
        }
        
        userProfileDebugLog("🔍 DEBUG UserProfile: Returning 0 points for userID: '\(userID)'")
        return 0
    }
    
    /// Calculate points earned from challenges
    private func calculatePointsFromChallenges(userID: String) async -> Int {
        guard let database else { return 0 }
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
            userProfileDebugLog("❌ Failed to calculate challenge points for \(userID): \(error)")
            return 0
        }
    }
    
    /// Check if current user is following the target user
    private func checkIfFollowing(userID: String) async -> Bool {
        let normalizedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedUserID.isEmpty else {
            return false
        }
        guard let database else { return false }

        userProfileDebugLog("🔍 DEBUG UserProfile: Starting checkIfFollowing for userID: '\(normalizedUserID)'")
        
        guard let currentUserID = try? await cloudKitUserManager.getCurrentUserID() else {
            userProfileDebugLog("⚠️ DEBUG UserProfile: Could not get current user ID for follow check")
            return false
        }
        
        userProfileDebugLog("🔍 DEBUG UserProfile: Current user ID: '\(currentUserID)', Target user ID: '\(normalizedUserID)'")
        
        guard currentUserID != normalizedUserID else {
            userProfileDebugLog("🔍 DEBUG UserProfile: Current user is same as target user, not following self")
            return false
        }
        
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@ AND %K == %d",
                                  CKField.Follow.followerID, currentUserID,
                                  CKField.Follow.followingID, normalizedUserID,
                                  CKField.Follow.isActive, 1)
        userProfileDebugLog("🔍 DEBUG UserProfile: Follow check predicate: \(predicate)")
        
        let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
        userProfileDebugLog("🔍 DEBUG UserProfile: Follow query record type: \(CloudKitConfig.followRecordType)")
        
        do {
            userProfileDebugLog("🔍 DEBUG UserProfile: Executing follow check query...")
            let results = try await database.records(matching: query)
            let isFollowing = !results.matchResults.isEmpty
            userProfileDebugLog("✅ DEBUG UserProfile: Follow check result: \(isFollowing) (found \(results.matchResults.count) follow records)")
            return isFollowing
        } catch {
            userProfileDebugLog("❌ DEBUG UserProfile: Error checking follow status: \(error)")
            userProfileDebugLog("❌ DEBUG UserProfile: Error type: \(type(of: error))")
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

    private lazy var database: CKDatabase? = {
        CloudKitRuntimeSupport.makeContainer()?.publicCloudDatabase
    }()

    func loadUsers(userID: String, mode: FollowListView.FollowMode) async {
        let normalizedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedUserID.isEmpty else {
            users = []
            isLoading = false
            return
        }

        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            users = []
            isLoading = false
            return
        }
        guard let database else {
            users = []
            isLoading = false
            return
        }

        isLoading = true

        let predicate: NSPredicate
        switch mode {
        case .followers:
            predicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                  CKField.Follow.followingID, normalizedUserID,
                                  CKField.Follow.isActive, 1)
        case .following:
            predicate = NSPredicate(format: "%K == %@ AND %K == %d",
                                  CKField.Follow.followerID, normalizedUserID,
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
            userProfileDebugLog("Failed to load follow list: \(error)")
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
                userProfileDebugLog("Failed to load user \(userID): \(error)")
            }
        }

        self.users = loadedUsers
    }
}

// MARK: - User Profile Converter
struct UserProfileConverter {
    /// Convert UserProfile record to CloudKitUser format
    static func convertUserProfileToCloudKitUser(_ record: CKRecord) -> CloudKitUser {
        userProfileDebugLog("🔍 DEBUG UserProfile: Starting UserProfile to CloudKitUser conversion")
        userProfileDebugLog("🔍 DEBUG UserProfile: Source record ID: \(record.recordID.recordName)")
        userProfileDebugLog("🔍 DEBUG UserProfile: Source record type: \(record.recordType)")
        
        // Extract data from UserProfile record
        let sourceUsername = record["username"] as? String
        let sourceDisplayName = record["displayName"] as? String
        let sourceTotalPoints = record["totalPoints"] as? Int ?? 0
        let sourceRecipesShared = record["recipesShared"] as? Int ?? 0
        let sourceFollowersCount = record["followersCount"] as? Int ?? 0
        let sourceFollowingCount = record["followingCount"] as? Int ?? 0
        let sourceIsVerified = record["isVerified"] as? Bool ?? false
        
        userProfileDebugLog("🔍 DEBUG UserProfile: Source data:")
        userProfileDebugLog("  - Username: '\(sourceUsername ?? "nil")'")
        userProfileDebugLog("  - Display name: '\(sourceDisplayName ?? "nil")'")
        userProfileDebugLog("  - Total points: \(sourceTotalPoints)")
        userProfileDebugLog("  - Recipes shared: \(sourceRecipesShared)")
        userProfileDebugLog("  - Followers count: \(sourceFollowersCount)")
        userProfileDebugLog("  - Following count: \(sourceFollowingCount)")
        userProfileDebugLog("  - Is verified: \(sourceIsVerified)")
        
        // Create CloudKitUser using the record directly
        let convertedUser = CloudKitUser(from: record)
        
        userProfileDebugLog("✅ DEBUG UserProfile: Converted CloudKitUser:")
        userProfileDebugLog("  - ID: '\(convertedUser.recordID ?? "nil")'")
        userProfileDebugLog("  - Username: '\(convertedUser.username ?? "nil")'")
        userProfileDebugLog("  - Display name: '\(convertedUser.displayName)'")
        userProfileDebugLog("  - Total points: \(convertedUser.totalPoints)")
        userProfileDebugLog("  - Recipes shared: \(convertedUser.recipesShared)")
        
        return convertedUser
    }
}
