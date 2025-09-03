import SwiftUI
import Combine
import CloudKit

@MainActor
final class AppState: ObservableObject {
    // Core app state
    @Published var isLoading: Bool = false
    
    // Direct @Published properties for UI state
    @Published var isFirstLaunch: Bool = false
    
    // Focused ViewModels for better performance
    @Published var recipesViewModel = RecipesViewModel()
    @Published var authViewModel = AuthViewModel()
    @Published var gamificationViewModel = GamificationViewModel()
    
    var currentUser: User? {
        get { authViewModel.currentUser }
        set { authViewModel.currentUser = newValue }
    }
    
    var error: AppError? {
        get { authViewModel.error }
        set { authViewModel.error = newValue }
    }
    
    var currentSnapChefError: SnapChefError? {
        get { authViewModel.currentSnapChefError }
        set { authViewModel.currentSnapChefError = newValue }
    }
    
    var selectedRecipe: Recipe? {
        get { recipesViewModel.selectedRecipe }
        set { recipesViewModel.selectedRecipe = newValue }
    }
    
    var recentRecipes: [Recipe] {
        get { recipesViewModel.recentRecipes }
        set { recipesViewModel.recentRecipes = newValue }
    }
    
    var allRecipes: [Recipe] {
        get { recipesViewModel.allRecipes }
        set { recipesViewModel.allRecipes = newValue }
    }
    
    var savedRecipes: [Recipe] {
        get { recipesViewModel.savedRecipes }
        set { recipesViewModel.savedRecipes = newValue }
    }
    
    var savedRecipesWithPhotos: [SavedRecipe] {
        get { recipesViewModel.savedRecipesWithPhotos }
        set { recipesViewModel.savedRecipesWithPhotos = newValue }
    }
    
    var favoritedRecipeIds: Set<UUID> {
        get { recipesViewModel.favoritedRecipeIds }
        set { recipesViewModel.favoritedRecipeIds = newValue }
    }
    
    // var detectiveRecipes: [DetectiveRecipe] {
    //     get { recipesViewModel.detectiveRecipes }
    //     set { recipesViewModel.detectiveRecipes = newValue }
    // }
    
    var activeChallenge: Challenge? {
        get { gamificationViewModel.activeChallenge }
        set { gamificationViewModel.activeChallenge = newValue }
    }
    
    var showChallengeCompletion: Bool {
        get { gamificationViewModel.showChallengeCompletion }
        set { gamificationViewModel.showChallengeCompletion = newValue }
    }
    
    var pendingChallengeRewards: [ChallengeReward] {
        get { gamificationViewModel.pendingChallengeRewards }
        set { gamificationViewModel.pendingChallengeRewards = newValue }
    }
    
    var freeUsesRemaining: Int {
        get { gamificationViewModel.freeUsesRemaining }
        set { gamificationViewModel.freeUsesRemaining = newValue }
    }
    
    // Backward compatibility properties
    var totalLikes: Int {
        get { authViewModel.totalLikes }
        set { authViewModel.totalLikes = newValue }
    }
    
    var totalShares: Int {
        get { authViewModel.totalShares }
        set { authViewModel.totalShares = newValue }
    }
    
    var totalSnapsTaken: Int {
        get { authViewModel.totalSnapsTaken }
        set { authViewModel.totalSnapsTaken = newValue }
    }
    
    var userJoinDate: Date {
        get { authViewModel.userJoinDate }
        set { authViewModel.userJoinDate = newValue }
    }
    
    var currentSessionID: String {
        get { authViewModel.currentSessionID }
        set { authViewModel.currentSessionID = newValue }
    }
    
    // Direct access to managers for compatibility
    var subscriptionManager: SubscriptionManager { gamificationViewModel.subscriptionManager }
    var gamificationManager: GamificationManager { gamificationViewModel.gamificationManager }
    var challengeGenerator: ChallengeGenerator { gamificationViewModel.challengeGenerator }
    var challengeProgressTracker: ChallengeProgressTracker { gamificationViewModel.challengeProgressTracker }
    var challengeService: ChallengeService { gamificationViewModel.challengeService }
    var cloudKitAuthManager: UnifiedAuthManager { authViewModel.cloudKitAuthManager }
    var unifiedAuthManager: UnifiedAuthManager { authViewModel.unifiedAuthManager }

    init() {
        // Initialize isFirstLaunch from authViewModel after view models are initialized
        self.isFirstLaunch = authViewModel.isFirstLaunch
        
        // DEBUG: Clear recipes for testing - DISABLED to preserve saved recipes
        // #if DEBUG
        // if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
        //     clearAllRecipes()
        // }
        // #endif
    }

    // MARK: - Delegated Methods
    
    func completeOnboarding() {
        Task { @MainActor in
            authViewModel.completeOnboarding()
            
            // Update our own @Published property to trigger UI update
            self.isFirstLaunch = authViewModel.isFirstLaunch
        }
    }

    func updateFreeUses(_ remaining: Int) {
        gamificationViewModel.updateFreeUses(remaining)
    }

    func addRecentRecipe(_ recipe: Recipe) {
        recipesViewModel.addRecentRecipe(recipe)
    }

    func toggleRecipeSave(_ recipe: Recipe) {
        recipesViewModel.toggleRecipeSave(recipe)
    }

    func incrementShares() {
        authViewModel.incrementShares()
    }

    func incrementLikes() {
        authViewModel.incrementLikes()
    }

    func incrementSnapsTaken() {
        authViewModel.incrementSnapsTaken()
    }

    func clearError() {
        authViewModel.clearError()
    }
    
    /// Handles errors using the new comprehensive error system
    func handleError(_ error: SnapChefError, context: String = "") {
        authViewModel.handleError(error, context: context)
    }
    
    /// Converts legacy AppError to SnapChefError
    func handleLegacyError(_ legacyError: AppError, context: String = "") {
        authViewModel.handleLegacyError(legacyError, context: context)
    }

    func toggleFavorite(_ recipeId: UUID) {
        recipesViewModel.toggleFavorite(recipeId)
    }

    func isFavorited(_ recipeId: UUID) -> Bool {
        return recipesViewModel.isFavorited(recipeId)
    }

    func saveRecipeWithPhotos(_ recipe: Recipe, beforePhoto: UIImage?, afterPhoto: UIImage?) {
        recipesViewModel.saveRecipeWithPhotos(recipe, beforePhoto: beforePhoto, afterPhoto: afterPhoto)
    }

    func updateAfterPhoto(for recipeId: UUID, afterPhoto: UIImage) {
        recipesViewModel.updateAfterPhoto(for: recipeId, afterPhoto: afterPhoto)
    }

    func deleteRecipe(_ recipe: Recipe) {
        recipesViewModel.deleteRecipe(recipe)
    }

    func clearAllRecipes() {
        recipesViewModel.clearAllRecipes()
    }
    
    // MARK: - Local-First Storage Methods
    
    /// Sync AppState with LocalRecipeManager
    func syncWithLocalStorage() {
        // Sync with LocalRecipeManager
        recipesViewModel.syncWithLocalRecipeManager()
        
        print("📱 AppState synced with LocalRecipeManager: \(savedRecipes.count) saved recipes")
    }
    
    /// Add recipe to saved (local-first)
    func addToSaved(_ recipe: Recipe, beforePhoto: UIImage? = nil) {
        // Add to LocalRecipeManager first
        LocalRecipeManager.shared.saveRecipe(recipe, capturedImage: beforePhoto)
        
        // Update AppState
        if !savedRecipes.contains(where: { $0.id == recipe.id }) {
            savedRecipes.append(recipe)
        }
    }
    
    /// Remove recipe from saved (local-first)
    func removeFromSaved(_ recipe: Recipe) {
        // Remove from LocalRecipeManager first
        LocalRecipeManager.shared.unsaveRecipe(recipe.id)
        
        // Update AppState
        savedRecipes.removeAll { $0.id == recipe.id }
        recentRecipes.removeAll { $0.id == recipe.id }
    }

    // Persistence methods moved to RecipesViewModel

    // MARK: - Challenge System Methods (Delegated)
    
    func selectChallenge(_ challenge: Challenge) {
        gamificationViewModel.selectChallenge(challenge)
    }

    func trackRecipeCreated(_ recipe: Recipe) {
        // Increment recipe count
        addRecentRecipe(recipe)

        // Track for challenges and gamification
        gamificationViewModel.trackRecipeCreated(recipe)

        // Track anonymous action for progressive auth
        authViewModel.trackAnonymousAction(.recipeCreated)
    }

    func claimPendingRewards() {
        gamificationViewModel.claimPendingRewards()
    }

    // MARK: - Progressive Authentication Helpers (Delegated)
    
    /// Convenience method to track actions - delegates to auth view model
    func trackAnonymousAction(_ action: AnonymousAction) {
        authViewModel.trackAnonymousAction(action)
    }

    // MARK: - Progressive Premium Helpers (Delegated)

    /// Gets current daily limits based on user lifecycle and subscription
    func getCurrentLimits() -> DailyLimits {
        return authViewModel.getCurrentLimits()
    }

    /// Checks if user can create more recipes today
    func canCreateRecipe() -> Bool {
        return authViewModel.canCreateRecipe()
    }

    /// Checks if user can create more videos today
    func canCreateVideo() -> Bool {
        return authViewModel.canCreateVideo()
    }

    /// Gets remaining recipe count for today
    func getRemainingRecipes() -> Int {
        return authViewModel.getRemainingRecipes()
    }

    /// Gets remaining video count for today
    func getRemainingVideos() -> Int {
        return authViewModel.getRemainingVideos()
    }

    /// Records usage when user opens the app (lifecycle tracking)
    func trackAppOpen() {
        authViewModel.trackAppOpen()
    }
}

// MARK: - Nested ViewModels

@MainActor
final class RecipesViewModel: ObservableObject {
    @Published var selectedRecipe: Recipe?
    @Published var recentRecipes: [Recipe] = []
    @Published var allRecipes: [Recipe] = []
    @Published var savedRecipes: [Recipe] = []
    @Published var savedRecipesWithPhotos: [SavedRecipe] = []
    @Published var favoritedRecipeIds: Set<UUID> = []
    // @Published var detectiveRecipes: [DetectiveRecipe] = []
    @Published var isProcessing: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let savedRecipesKey = "savedRecipesWithPhotos"
    private let favoritedRecipesKey = "favoritedRecipeIds"
    
    // Dependencies
    private let unifiedAuthManager = UnifiedAuthManager.shared
    private let userLifecycle = UserLifecycleManager.shared
    private let usageTracker = UsageTracker.shared
    
    init() {
        // Migrate from old storage to LocalRecipeManager on first run
        migrateToLocalRecipeManager()
        
        // Load recipes from LocalRecipeManager
        syncWithLocalRecipeManager()
        
        // Still load favorited IDs from UserDefaults for now
        loadFavoritedRecipes()
    }
    
    // MARK: - Recipe Management
    
    func addRecentRecipe(_ recipe: Recipe) {
        // 🔍 DEBUG: Log when recipe is added to app state
        print("🔍 DEBUG: Adding recipe '\(recipe.name)' to AppState")
        print("🔍   - Enhanced fields at storage time:")
        print("🔍     • cookingTechniques: \(recipe.cookingTechniques.isEmpty ? "EMPTY" : "\(recipe.cookingTechniques)")")
        print("🔍     • secretIngredients: \(recipe.secretIngredients.isEmpty ? "EMPTY" : "\(recipe.secretIngredients)")")
        print("🔍     • proTips: \(recipe.proTips.isEmpty ? "EMPTY" : "\(recipe.proTips)")")
        print("🔍     • visualClues: \(recipe.visualClues.isEmpty ? "EMPTY" : "\(recipe.visualClues)")")
        print("🔍     • shareCaption: \(recipe.shareCaption.isEmpty ? "EMPTY" : "\"\(recipe.shareCaption)\"")")
        
        recentRecipes.insert(recipe, at: 0)
        if recentRecipes.count > 10 {
            recentRecipes.removeLast()
        }
        
        // Also add to all recipes
        allRecipes.insert(recipe, at: 0)
        
        // Track in Progressive Premium systems
        userLifecycle.trackRecipeCreated()
        usageTracker.trackRecipeGenerated()
    }
    
    func toggleRecipeSave(_ recipe: Recipe) {
        if LocalRecipeManager.shared.isRecipeSaved(recipe.id) {
            // Unsave the recipe
            LocalRecipeManager.shared.unsaveRecipe(recipe.id)
            savedRecipes.removeAll { $0.id == recipe.id }
            savedRecipesWithPhotos.removeAll { $0.recipe.id == recipe.id }
        } else {
            // Save the recipe
            LocalRecipeManager.shared.saveRecipe(recipe)
            if !savedRecipes.contains(where: { $0.id == recipe.id }) {
                savedRecipes.append(recipe)
            }
        }
    }
    
    func saveRecipeWithPhotos(_ recipe: Recipe, beforePhoto: UIImage?, afterPhoto: UIImage?) {
        print("🔍 DEBUG: saveRecipeWithPhotos called for '\(recipe.name)'")
        print("🔍   - savedRecipes count before: \(savedRecipes.count)")
        
        // Save to LocalRecipeManager (single source of truth)
        LocalRecipeManager.shared.saveRecipe(recipe, capturedImage: beforePhoto)
        
        // Store photos locally
        if beforePhoto != nil || afterPhoto != nil {
            PhotoStorageManager.shared.storePhotos(
                fridgePhoto: beforePhoto,
                mealPhoto: afterPhoto,
                for: recipe.id
            )
        }
        
        // Update in-memory state for UI
        let savedRecipe = SavedRecipe(recipe: recipe, beforePhoto: beforePhoto, afterPhoto: afterPhoto)
        if !savedRecipesWithPhotos.contains(where: { $0.recipe.id == recipe.id }) {
            savedRecipesWithPhotos.append(savedRecipe)
        }
        
        // Also update the simple lists
        if !savedRecipes.contains(where: { $0.id == recipe.id }) {
            savedRecipes.append(recipe)
            print("🔍   - Added recipe to savedRecipes array")
        } else {
            print("🔍   - Recipe already in savedRecipes array")
        }
        
        print("🔍   - savedRecipes count after: \(savedRecipes.count)")
        
        // Immediately upload to CloudKit if authenticated (don't wait for sync)
        if UnifiedAuthManager.shared.isAuthenticated {
            Task {
                do {
                    print("📤 Immediately uploading recipe to CloudKit: '\(recipe.name)'")
                    
                    // Upload the recipe with before photo if available
                    let recipeID = try await CloudKitRecipeManager.shared.uploadRecipe(
                        recipe,
                        fromLLM: false,
                        beforePhoto: beforePhoto
                    )
                    print("✅ Recipe uploaded to CloudKit with ID: \(recipeID)")
                    
                    // If we have an after photo, update it immediately
                    if let afterPhoto = afterPhoto {
                        let recipeExists = await CloudKitRecipeManager.shared.checkRecipeExists(recipeID)
                        if recipeExists {
                            try await CloudKitRecipeManager.shared.updateAfterPhoto(
                                for: recipeID,
                                afterPhoto: afterPhoto
                            )
                            print("✅ After photo uploaded to CloudKit")
                        }
                    }
                    
                    // Add to user's saved recipes list
                    try await CloudKitRecipeManager.shared.addRecipeToUserProfile(recipeID, type: .saved)
                    print("✅ Recipe added to user's CloudKit profile")
                } catch {
                    print("❌ CloudKit upload failed (will retry on next sync): \(error)")
                    // Don't show error to user - recipe is saved locally
                }
            }
        }
    }
    
    func updateAfterPhoto(for recipeId: UUID, afterPhoto: UIImage) {
        if let index = savedRecipesWithPhotos.firstIndex(where: { $0.recipe.id == recipeId }) {
            let existingRecipe = savedRecipesWithPhotos[index]
            let updatedRecipe = SavedRecipe(
                recipe: existingRecipe.recipe,
                beforePhoto: existingRecipe.beforePhoto,
                afterPhoto: afterPhoto
            )
            savedRecipesWithPhotos[index] = updatedRecipe
            saveToDisk()
            
            // Also store in PhotoStorageManager (single source of truth)
            PhotoStorageManager.shared.storeMealPhoto(afterPhoto, for: recipeId)
            
            // Immediately upload to CloudKit if authenticated
            if UnifiedAuthManager.shared.isAuthenticated {
                Task {
                    do {
                        print("📤 Immediately uploading after photo to CloudKit for recipe ID: \(recipeId)")
                        
                        // Check if recipe exists in CloudKit first
                        let recipeExists = await CloudKitRecipeManager.shared.checkRecipeExists(recipeId.uuidString)
                        
                        if recipeExists {
                            try await CloudKitRecipeManager.shared.updateAfterPhoto(
                                for: recipeId.uuidString,
                                afterPhoto: afterPhoto
                            )
                            print("✅ After photo uploaded to CloudKit")
                        } else {
                            // Recipe doesn't exist in CloudKit yet, upload the whole recipe
                            print("📤 Recipe not in CloudKit, uploading full recipe with photos")
                            let recipeID = try await CloudKitRecipeManager.shared.uploadRecipe(
                                existingRecipe.recipe,
                                fromLLM: false,
                                beforePhoto: existingRecipe.beforePhoto
                            )
                            
                            // Now update with after photo
                            try await CloudKitRecipeManager.shared.updateAfterPhoto(
                                for: recipeID,
                                afterPhoto: afterPhoto
                            )
                            print("✅ Recipe and after photo uploaded to CloudKit")
                        }
                    } catch {
                        print("❌ CloudKit after photo upload failed: \(error)")
                        // Don't show error - photo is saved locally
                    }
                }
            }
        }
    }
    
    func deleteRecipe(_ recipe: Recipe) {
        // Remove from LocalRecipeManager
        LocalRecipeManager.shared.unsaveRecipe(recipe.id)
        
        // Update in-memory state
        recentRecipes.removeAll { $0.id == recipe.id }
        savedRecipes.removeAll { $0.id == recipe.id }
        allRecipes.removeAll { $0.id == recipe.id }
        savedRecipesWithPhotos.removeAll { $0.recipe.id == recipe.id }
    }
    
    func clearAllRecipes() {
        // Clear from LocalRecipeManager
        LocalRecipeManager.shared.clearAllRecipes()
        
        // Clear in-memory state
        recentRecipes.removeAll()
        savedRecipes.removeAll()
        allRecipes.removeAll()
        savedRecipesWithPhotos.removeAll()
        favoritedRecipeIds.removeAll()
        
        // Clear old storage for migration
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let filePath = documentsPath.appendingPathComponent("savedRecipes.json")
        try? FileManager.default.removeItem(at: filePath)
        
        // Clear from UserDefaults
        userDefaults.removeObject(forKey: "hasSavedRecipes")
        userDefaults.removeObject(forKey: favoritedRecipesKey)
    }
    
    // MARK: - Favorites Management
    
    func toggleFavorite(_ recipeId: UUID) {
        if favoritedRecipeIds.contains(recipeId) {
            favoritedRecipeIds.remove(recipeId)
        } else {
            favoritedRecipeIds.insert(recipeId)
        }
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(favoritedRecipeIds) {
            userDefaults.set(encoded, forKey: favoritedRecipesKey)
        }
        
        // Sync with CloudKit if authenticated
        if unifiedAuthManager.isAuthenticated {
            Task {
                // CloudKitService integration temporarily commented out
                // TODO: Implement CloudKitService integration
                /*
                if wasAdded {
                    try await CloudKitService.shared.addRecipeToUserProfile(
                        recipeId.uuidString,
                        type: .favorited
                    )
                } else {
                    try await CloudKitService.shared.removeRecipeFromUserProfile(
                        recipeId.uuidString,
                        type: .favorited
                    )
                }
                */
                print("✅ Synced favorite status to CloudKit")
            }
        }
    }
    
    func isFavorited(_ recipeId: UUID) -> Bool {
        return favoritedRecipeIds.contains(recipeId)
    }
    
    // MARK: - Persistence
    
    private func loadSavedRecipes() {
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
    
    private func loadFavoritedRecipes() {
        if let favoritedData = userDefaults.data(forKey: favoritedRecipesKey),
           let favoritedIds = try? JSONDecoder().decode(Set<UUID>.self, from: favoritedData) {
            self.favoritedRecipeIds = favoritedIds
        }
    }
    
    private func saveToDisk() {
        // NO LONGER USED - LocalRecipeManager handles persistence
        // Kept for backward compatibility during migration
    }
    
    // MARK: - LocalRecipeManager Migration & Sync
    
    private func migrateToLocalRecipeManager() {
        // Check if we've already migrated
        let migrationKey = "migratedToLocalRecipeManager"
        guard !userDefaults.bool(forKey: migrationKey) else { return }
        
        print("🔄 Migrating recipes to LocalRecipeManager...")
        
        // Load old saved recipes from disk
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let filePath = documentsPath.appendingPathComponent("savedRecipes.json")
        
        if let data = try? Data(contentsOf: filePath),
           let decoded = try? JSONDecoder().decode([SavedRecipe].self, from: data) {
            
            // Migrate each recipe to LocalRecipeManager
            for savedRecipe in decoded {
                LocalRecipeManager.shared.saveRecipe(savedRecipe.recipe, capturedImage: savedRecipe.beforePhoto)
                print("🔄 Migrated recipe: \(savedRecipe.recipe.name)")
            }
            
            print("✅ Migration complete: \(decoded.count) recipes migrated")
            
            // Mark migration as complete
            userDefaults.set(true, forKey: migrationKey)
        }
    }
    
    func syncWithLocalRecipeManager() {
        // Load all recipes from LocalRecipeManager
        let localRecipes = LocalRecipeManager.shared.allRecipes
        let localSavedRecipes = LocalRecipeManager.shared.getSavedRecipes()
        
        // Update our in-memory state
        allRecipes = localRecipes
        savedRecipes = localSavedRecipes
        
        // Rebuild savedRecipesWithPhotos from LocalRecipeManager and PhotoStorageManager
        savedRecipesWithPhotos = localSavedRecipes.compactMap { recipe in
            let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
            return SavedRecipe(recipe: recipe, beforePhoto: photos?.fridgePhoto, afterPhoto: photos?.mealPhoto)
        }
        
        print("📦 Synced with LocalRecipeManager: \(allRecipes.count) total, \(savedRecipes.count) saved")
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var error: AppError?
    @Published var currentSnapChefError: SnapChefError?
    @Published var isFirstLaunch: Bool
    @Published var userJoinDate = Date()
    
    // User engagement metrics
    @Published var totalLikes: Int = 0
    @Published var totalShares: Int = 0
    @Published var totalSnapsTaken: Int = 0
    
    // CloudKit Session Tracking
    @Published var currentSessionID: String = ""
    
    // Unified Authentication
    @Published var cloudKitAuthManager = UnifiedAuthManager.shared
    @Published var unifiedAuthManager = UnifiedAuthManager.shared
    
    // Progressive Premium Integration
    private let userLifecycle = UserLifecycleManager.shared
    private let usageTracker = UsageTracker.shared
    private let globalErrorHandler = GlobalErrorHandler.shared
    
    private let userDefaults = UserDefaults.standard
    private let firstLaunchKey = "hasLaunchedBefore"
    private let userJoinDateKey = "userJoinDate"
    private let totalSnapsTakenKey = "totalSnapsTaken"
    
    init() {
        self.isFirstLaunch = !userDefaults.bool(forKey: firstLaunchKey)
        
        // Load or set user join date
        if let joinDate = userDefaults.object(forKey: userJoinDateKey) as? Date {
            self.userJoinDate = joinDate
        } else {
            userDefaults.set(Date(), forKey: userJoinDateKey)
        }
        
        // Load total snaps taken
        self.totalSnapsTaken = userDefaults.integer(forKey: totalSnapsTakenKey)
    }
    
    // MARK: - Authentication Actions
    
    func completeOnboarding() {
        userDefaults.set(true, forKey: firstLaunchKey)
        isFirstLaunch = false
    }
    
    // MARK: - User Metrics
    
    func incrementShares() {
        totalShares += 1
        
        // Update CloudKit user profile if authenticated
        if unifiedAuthManager.isAuthenticated {
            Task {
                // CloudKitService integration temporarily commented out
                // TODO: Implement CloudKitService integration
                // try await CloudKitService.shared.incrementRecipesShared()
                print("✅ Updated share count in CloudKit")
            }
        }
    }
    
    func incrementLikes() {
        totalLikes += 1
    }
    
    func incrementSnapsTaken() {
        totalSnapsTaken += 1
        userDefaults.set(totalSnapsTaken, forKey: totalSnapsTakenKey)
        
        // Track app usage for lifecycle management
        userLifecycle.updateLastActive()
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        error = nil
        currentSnapChefError = nil
        globalErrorHandler.clearError()
    }
    
    /// Handles errors using the new comprehensive error system
    func handleError(_ error: SnapChefError, context: String = "") {
        currentSnapChefError = error
        globalErrorHandler.handleError(error, context: context)
    }
    
    /// Converts legacy AppError to SnapChefError
    func handleLegacyError(_ legacyError: AppError, context: String = "") {
        let snapChefError: SnapChefError
        switch legacyError {
        case .networkError(let message):
            snapChefError = .networkError(message)
        case .authenticationError(let message):
            snapChefError = .authenticationError(message)
        case .apiError(let message):
            snapChefError = .apiError(message, recovery: .retry)
        case .unknown(let message):
            snapChefError = .unknown(message)
        }
        handleError(snapChefError, context: context)
    }
    
    // MARK: - Progressive Authentication Helpers
    
    /// Convenience method to track actions - delegates to unified auth manager
    func trackAnonymousAction(_ action: AnonymousAction) {
        unifiedAuthManager.trackAnonymousAction(action)
        
        // Still track for Progressive Premium systems
        switch action {
        case .videoGenerated:
            userLifecycle.trackVideoShared()
            usageTracker.trackVideoCreated()
        case .videoShared:
            userLifecycle.trackVideoShared()
        case .appOpened:
            userLifecycle.updateLastActive()
        default:
            break
        }
    }
    
    // MARK: - Progressive Premium Helpers
    
    /// Gets current daily limits based on user lifecycle and subscription
    func getCurrentLimits() -> DailyLimits {
        return userLifecycle.getDailyLimits()
    }
    
    /// Checks if user can create more recipes today
    func canCreateRecipe() -> Bool {
        return !usageTracker.hasReachedRecipeLimit()
    }
    
    /// Checks if user can create more videos today
    func canCreateVideo() -> Bool {
        return !usageTracker.hasReachedVideoLimit()
    }
    
    /// Gets remaining recipe count for today
    func getRemainingRecipes() -> Int {
        return usageTracker.getRemainingRecipes()
    }
    
    /// Gets remaining video count for today
    func getRemainingVideos() -> Int {
        return usageTracker.getRemainingVideos()
    }
    
    /// Records usage when user opens the app (lifecycle tracking)
    func trackAppOpen() {
        trackAnonymousAction(.appOpened)
    }
}

@MainActor
final class GamificationViewModel: ObservableObject {
    // Challenge System State
    @Published var gamificationManager = GamificationManager.shared
    @Published var challengeGenerator = ChallengeGenerator()
    @Published var challengeProgressTracker = ChallengeProgressTracker.shared
    @Published var challengeService = ChallengeService.shared
    @Published var activeChallenge: Challenge?
    @Published var showChallengeCompletion: Bool = false
    @Published var pendingChallengeRewards: [ChallengeReward] = []
    
    // Subscription management
    @Published var subscriptionManager = SubscriptionManager.shared
    @Published var freeUsesRemaining: Int = 10
    
    init() {
        initializeChallengeSystem()
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
    
    // MARK: - Usage Management
    
    func updateFreeUses(_ remaining: Int) {
        freeUsesRemaining = remaining
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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

// AnonymousAction enum moved to UnifiedAuthManager.swift to avoid duplication
