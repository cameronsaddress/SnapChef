import SwiftUI
import Combine
import CloudKit

@MainActor
final class AppState: ObservableObject {
    @Published var isFirstLaunch: Bool
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var error: AppError?
    @Published var selectedRecipe: Recipe?
    @Published var recentRecipes: [Recipe] = []
    @Published var freeUsesRemaining: Int = 10 // For testing
    @Published var subscriptionManager = SubscriptionManager.shared
    @Published var allRecipes: [Recipe] = []
    @Published var savedRecipes: [Recipe] = []
    @Published var savedRecipesWithPhotos: [SavedRecipe] = []
    @Published var favoritedRecipeIds: Set<UUID> = []
    @Published var totalLikes: Int = 0
    @Published var totalShares: Int = 0
    @Published var totalSnapsTaken: Int = 0
    @Published var userJoinDate: Date = Date()
    
    // Challenge System State
    @Published var gamificationManager = GamificationManager.shared
    @Published var challengeGenerator = ChallengeGenerator()
    @Published var challengeProgressTracker = ChallengeProgressTracker.shared
    @Published var challengeService = ChallengeService.shared
    @Published var activeChallenge: Challenge?
    @Published var showChallengeCompletion: Bool = false
    @Published var pendingChallengeRewards: [ChallengeReward] = []
    
    // CloudKit Session Tracking
    @Published var currentSessionID: String = ""
    
    private let userDefaults = UserDefaults.standard
    private let firstLaunchKey = "hasLaunchedBefore"
    private let userJoinDateKey = "userJoinDate"
    private let savedRecipesKey = "savedRecipesWithPhotos"
    private let favoritedRecipesKey = "favoritedRecipeIds"
    private let totalSnapsTakenKey = "totalSnapsTaken"
    
    init() {
        self.isFirstLaunch = !userDefaults.bool(forKey: firstLaunchKey)
        
        // Load or set user join date
        if let joinDate = userDefaults.object(forKey: userJoinDateKey) as? Date {
            self.userJoinDate = joinDate
        } else {
            userDefaults.set(Date(), forKey: userJoinDateKey)
        }
        
        // Load saved recipes
        loadSavedRecipes()
        
        // Load favorited recipe IDs
        if let favoritedData = userDefaults.data(forKey: favoritedRecipesKey),
           let favoritedIds = try? JSONDecoder().decode(Set<UUID>.self, from: favoritedData) {
            self.favoritedRecipeIds = favoritedIds
        }
        
        // Load total snaps taken
        self.totalSnapsTaken = userDefaults.integer(forKey: totalSnapsTakenKey)
        
        // Initialize challenge system
        initializeChallengeSystem()
        
        // DEBUG: Clear recipes for testing - remove this in production
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            clearAllRecipes()
        }
        #endif
    }
    
    func completeOnboarding() {
        userDefaults.set(true, forKey: firstLaunchKey)
        isFirstLaunch = false
    }
    
    func updateFreeUses(_ remaining: Int) {
        freeUsesRemaining = remaining
    }
    
    func addRecentRecipe(_ recipe: Recipe) {
        recentRecipes.insert(recipe, at: 0)
        if recentRecipes.count > 10 {
            recentRecipes.removeLast()
        }
        
        // Also add to all recipes
        allRecipes.insert(recipe, at: 0)
    }
    
    func toggleRecipeSave(_ recipe: Recipe) {
        if let index = savedRecipes.firstIndex(where: { $0.id == recipe.id }) {
            savedRecipes.remove(at: index)
        } else {
            savedRecipes.append(recipe)
        }
    }
    
    func incrementShares() {
        totalShares += 1
        
        // Update CloudKit user profile if authenticated
        if CloudKitAuthManager.shared.isAuthenticated {
            Task {
                do {
                    if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
                        let profileID = CKRecord.ID(recordName: "profile_\(userID)")
                        let container = CKContainer(identifier: "iCloud.com.snapchefapp.app")
                        let privateDB = container.privateCloudDatabase
                        
                        let profileRecord = try await privateDB.record(for: profileID)
                        let currentShares = profileRecord["recipesShared"] as? Int64 ?? 0
                        profileRecord["recipesShared"] = currentShares + 1
                        
                        _ = try await privateDB.save(profileRecord)
                        print("✅ Updated share count in CloudKit")
                    }
                } catch {
                    print("❌ Failed to update share count in CloudKit: \(error)")
                }
            }
        }
    }
    
    func incrementLikes() {
        totalLikes += 1
    }
    
    func incrementSnapsTaken() {
        totalSnapsTaken += 1
        userDefaults.set(totalSnapsTaken, forKey: totalSnapsTakenKey)
    }
    
    func clearError() {
        error = nil
    }
    
    func toggleFavorite(_ recipeId: UUID) {
        let wasAdded: Bool
        if favoritedRecipeIds.contains(recipeId) {
            favoritedRecipeIds.remove(recipeId)
            wasAdded = false
        } else {
            favoritedRecipeIds.insert(recipeId)
            wasAdded = true
        }
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(favoritedRecipeIds) {
            userDefaults.set(encoded, forKey: favoritedRecipesKey)
        }
        
        // Sync with CloudKit if authenticated
        if CloudKitAuthManager.shared.isAuthenticated {
            Task {
                do {
                    if wasAdded {
                        try await CloudKitRecipeManager.shared.addRecipeToUserProfile(
                            recipeId.uuidString,
                            type: .favorited
                        )
                    } else {
                        try await CloudKitRecipeManager.shared.removeRecipeFromUserProfile(
                            recipeId.uuidString,
                            type: .favorited
                        )
                    }
                    print("✅ Synced favorite status to CloudKit")
                } catch {
                    print("❌ Failed to sync favorite to CloudKit: \(error)")
                }
            }
        }
    }
    
    func isFavorited(_ recipeId: UUID) -> Bool {
        return favoritedRecipeIds.contains(recipeId)
    }
    
    func saveRecipeWithPhotos(_ recipe: Recipe, beforePhoto: UIImage?, afterPhoto: UIImage?) {
        let savedRecipe = SavedRecipe(recipe: recipe, beforePhoto: beforePhoto, afterPhoto: afterPhoto)
        savedRecipesWithPhotos.append(savedRecipe)
        saveToDisk()
        
        // Also update the simple lists
        if !savedRecipes.contains(where: { $0.id == recipe.id }) {
            savedRecipes.append(recipe)
        }
    }
    
    func deleteRecipe(_ recipe: Recipe) {
        // Remove from all arrays
        recentRecipes.removeAll { $0.id == recipe.id }
        savedRecipes.removeAll { $0.id == recipe.id }
        allRecipes.removeAll { $0.id == recipe.id }
        savedRecipesWithPhotos.removeAll { $0.recipe.id == recipe.id }
        
        // Save changes to disk
        saveToDisk()
    }
    
    func clearAllRecipes() {
        recentRecipes.removeAll()
        savedRecipes.removeAll()
        allRecipes.removeAll()
        savedRecipesWithPhotos.removeAll()
        favoritedRecipeIds.removeAll()
        
        // Clear from disk
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let filePath = documentsPath.appendingPathComponent("savedRecipes.json")
        try? FileManager.default.removeItem(at: filePath)
        
        // Clear from UserDefaults
        userDefaults.removeObject(forKey: "hasSavedRecipes")
        userDefaults.removeObject(forKey: favoritedRecipesKey)
    }
    
    private func loadSavedRecipes() {
        // Load from documents directory instead of UserDefaults
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let filePath = documentsPath.appendingPathComponent("savedRecipes.json")
        
        if let data = try? Data(contentsOf: filePath),
           let decoded = try? JSONDecoder().decode([SavedRecipe].self, from: data) {
            savedRecipesWithPhotos = decoded
            savedRecipes = decoded.map { $0.recipe }
            allRecipes = decoded.map { $0.recipe }
        } else {
            // Try to migrate from old UserDefaults storage
            if let data = userDefaults.data(forKey: savedRecipesKey),
               let decoded = try? JSONDecoder().decode([SavedRecipe].self, from: data) {
                savedRecipesWithPhotos = decoded
                savedRecipes = decoded.map { $0.recipe }
                allRecipes = decoded.map { $0.recipe }
                
                // Save to new location and remove from UserDefaults
                saveToDisk()
                userDefaults.removeObject(forKey: savedRecipesKey)
            }
        }
    }
    
    private func saveToDisk() {
        // Save to documents directory instead of UserDefaults to avoid size limits
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let filePath = documentsPath.appendingPathComponent("savedRecipes.json")
        
        if let encoded = try? JSONEncoder().encode(savedRecipesWithPhotos) {
            try? encoded.write(to: filePath)
            
            // Save just a flag in UserDefaults to indicate we have saved recipes
            userDefaults.set(true, forKey: "hasSavedRecipes")
        }
    }
    
    // MARK: - Challenge System Methods
    
    @MainActor
    private func initializeChallengeSystem() {
        // Start challenge generation
        challengeGenerator.scheduleAutomaticGeneration()
        
        // Start real-time sync
        challengeService.startRealtimeSync()
        
        // Generate initial challenges if none exist
        if gamificationManager.activeChallenges.isEmpty {
            generateInitialChallenges()
        }
        
        // Observe challenge completions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChallengeCompleted),
            name: Notification.Name("ChallengeCompleted"),
            object: nil
        )
    }
    
    @MainActor
    private func generateInitialChallenges() {
        // Generate daily challenge
        let dailyChallenge = challengeGenerator.generateDailyChallenge()
        gamificationManager.saveChallenge(dailyChallenge)
        
        // Generate weekly challenge
        let weeklyChallenge = challengeGenerator.generateWeeklyChallenge()
        gamificationManager.saveChallenge(weeklyChallenge)
        
        // Generate community challenge
        let communityChallenge = challengeGenerator.generateCommunityChallenge()
        gamificationManager.saveChallenge(communityChallenge)
        
        // Check for special events
        if let specialChallenge = challengeGenerator.generateSpecialEventChallenge() {
            gamificationManager.saveChallenge(specialChallenge)
        }
    }
    
    @objc private func handleChallengeCompleted(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let reward = userInfo["reward"] as? ChallengeReward {
            pendingChallengeRewards.append(reward)
            showChallengeCompletion = true
        }
    }
    
    func selectChallenge(_ challenge: Challenge) {
        activeChallenge = challenge
        challengeProgressTracker.startTracking(challenge: challenge)
        gamificationManager.joinChallenge(challenge)
    }
    
    func trackRecipeCreated(_ recipe: Recipe) {
        // Increment recipe count
        addRecentRecipe(recipe)
        
        // Track for challenges
        challengeProgressTracker.handleRecipeCreated(recipe)
        
        // Track in gamification manager
        gamificationManager.trackRecipeCreated(recipe)
    }
    
    func claimPendingRewards() {
        for reward in pendingChallengeRewards {
            // Award points
            if reward.points > 0 {
                gamificationManager.awardPoints(reward.points, reason: "Challenge completion")
            }
            
            // Award badge
            if let badge = reward.badge {
                gamificationManager.awardBadge(badge)
            }
        }
        
        pendingChallengeRewards.removeAll()
        showChallengeCompletion = false
    }
}

enum AppError: LocalizedError {
    case networkError(String)
    case authenticationError(String)
    case apiError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .authenticationError(let message):
            return "Authentication Error: \(message)"
        case .apiError(let message):
            return "API Error: \(message)"
        case .unknown(let message):
            return "Error: \(message)"
        }
    }
}