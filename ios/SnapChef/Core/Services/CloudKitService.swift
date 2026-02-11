import Foundation
import CloudKit
import SwiftUI
import Combine
import UIKit
import AuthenticationServices

/// Unified CloudKit Service that consolidates all CloudKit operations
/// Replaces: CloudKitManager, CloudKitAuthManager, CloudKitRecipeManager, 
/// CloudKitUserManager, CloudKitChallengeManager, CloudKitDataManager, CloudKitStreakManager
@MainActor
final class CloudKitService: ObservableObject {
    
    // MARK: - Singleton
    static let shared: CloudKitService = {
        let instance = CloudKitService()
        return instance
    }()
    
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        NSClassFromString("XCTestCase") != nil
    }

    // MARK: - Core Properties
    private lazy var container: CKContainer = {
        CKContainer(identifier: CloudKitConfig.containerIdentifier)
    }()
    private lazy var publicDatabase: CKDatabase = {
        container.publicCloudDatabase
    }()
    private lazy var privateDatabase: CKDatabase = {
        container.privateCloudDatabase
    }()
    let cloudKitActor = CloudKitActor()
    
    // MARK: - Service Modules
    private var authModule: AuthModule!
    private var recipeModule: RecipeModule!
    private var userModule: UserModule!
    private var challengeModule: ChallengeModule!
    private var dataModule: DataModule!
    private var streakModule: StreakModule!
    private var syncModule: SyncModule!
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var currentUser: CloudKitUser?
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    @Published var userSavedRecipeIDs: Set<String> = []
    @Published var userCreatedRecipeIDs: Set<String> = []
    @Published var userFavoritedRecipeIDs: Set<String> = []
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        guard !Self.isRunningTests else { return }
        
        // Initialize modules
        self.authModule = AuthModule(container: container, publicDB: publicDatabase, privateDB: privateDatabase, parent: self)
        self.recipeModule = RecipeModule(container: container, publicDB: publicDatabase, privateDB: privateDatabase, parent: self)
        self.userModule = UserModule(container: container, publicDB: publicDatabase, privateDB: privateDatabase, parent: self)
        self.challengeModule = ChallengeModule(container: container, publicDB: publicDatabase, privateDB: privateDatabase, parent: self)
        self.dataModule = DataModule(container: container, publicDB: publicDatabase, privateDB: privateDatabase, parent: self)
        self.streakModule = StreakModule(container: container, publicDB: publicDatabase, privateDB: privateDatabase, parent: self)
        self.syncModule = SyncModule(container: container, publicDB: publicDatabase, privateDB: privateDatabase, parent: self)
        
        setupModuleBindings()
        if CloudKitRuntimeSupport.hasCloudKitEntitlement {
            setupInitialConfiguration()
        } else {
            print("⚠️ CloudKitService startup configuration skipped: missing iCloud CloudKit entitlement")
        }
    }
    
    private func setupModuleBindings() {
        recipeModule.$userSavedRecipeIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ids in
                self?.userSavedRecipeIDs = ids
            }
            .store(in: &cancellables)
        
        recipeModule.$userCreatedRecipeIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ids in
                self?.userCreatedRecipeIDs = ids
            }
            .store(in: &cancellables)
        
        recipeModule.$userFavoritedRecipeIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ids in
                self?.userFavoritedRecipeIDs = ids
            }
            .store(in: &cancellables)
    }
    
    private func setupInitialConfiguration() {
        authModule.checkAuthStatus()
        setupSubscriptions()
        checkAccountStatus()
    }
    
    // MARK: - Account Status
    private func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.syncError = error
                    print("CloudKit account status error: \(error)")
                    return
                }
                
                switch status {
                case .available:
                    print("CloudKit account available")
                case .noAccount:
                    print("No CloudKit account")
                case .restricted:
                    print("CloudKit access restricted")
                case .couldNotDetermine:
                    print("Could not determine CloudKit status")
                case .temporarilyUnavailable:
                    print("CloudKit temporarily unavailable")
                @unknown default:
                    print("Unknown CloudKit status")
                }
            }
        }
    }
    
    // MARK: - Subscriptions
    private func setupSubscriptions() {
        syncModule.setupSubscriptions()
    }
}

// MARK: - Authentication Module Access
extension CloudKitService {
    
    // Authentication methods
    func signInWithApple(authorization: ASAuthorization) async throws {
        try await authModule.signInWithApple(authorization: authorization)
    }
    
    func signInWithFacebook(userID: String, email: String?, name: String?, profileImageURL: String?) async throws {
        try await authModule.signInWithFacebook(userID: userID, email: email, name: name, profileImageURL: profileImageURL)
    }
    
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        return try await authModule.checkUsernameAvailability(username)
    }
    
    func setUsername(_ username: String) async throws {
        try await authModule.setUsername(username)
    }
    
    func signOut() {
        authModule.signOut()
    }
    
    func updateUserStats(_ updates: UserStatUpdates) async throws {
        try await authModule.updateUserStats(updates)
    }
    
    func isAuthRequiredFor(feature: AuthRequiredFeature) -> Bool {
        return authModule.isAuthRequiredFor(feature: feature)
    }
    
    func promptAuthForFeature(_ feature: AuthRequiredFeature) {
        authModule.promptAuthForFeature(feature)
    }
    
    // Social methods
    func followUser(_ userID: String) async throws {
        try await authModule.followUser(userID)
    }
    
    func unfollowUser(_ userID: String) async throws {
        try await authModule.unfollowUser(userID)
    }
    
    func isFollowing(_ userID: String) async throws -> Bool {
        return try await authModule.isFollowing(userID)
    }
    
    func updateRecipeCounts() async {
        await authModule.updateRecipeCounts()
    }
    
    func updateSocialCounts() async {
        await authModule.updateSocialCounts()
    }
    
    func refreshCurrentUser() async {
        await authModule.refreshCurrentUser()
    }
    
    func searchUsers(query: String) async throws -> [CloudKitUser] {
        return try await authModule.searchUsers(query: query)
    }
    
    func getSuggestedUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        return try await authModule.getSuggestedUsers(limit: limit)
    }
    
    func getTrendingUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        return try await authModule.getTrendingUsers(limit: limit)
    }
    
    func getVerifiedUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        return try await authModule.getVerifiedUsers(limit: limit)
    }
}

// MARK: - Recipe Module Access
extension CloudKitService {
    
    // Recipe management
    func uploadRecipe(_ recipe: Recipe, fromLLM: Bool = false, beforePhoto: UIImage? = nil) async throws -> String {
        return try await recipeModule.uploadRecipe(recipe, fromLLM: fromLLM, beforePhoto: beforePhoto)
    }
    
    func fetchRecipe(by recipeID: String) async throws -> Recipe {
        return try await recipeModule.fetchRecipe(by: recipeID)
    }
    
    func recipeExists(with recipeID: String) async -> Bool {
        return await recipeModule.recipeExists(with: recipeID)
    }
    
    func existingRecipeID(name: String, description: String) async -> String? {
        return await recipeModule.existingRecipeID(name: name, description: description)
    }
    
    func fetchRecipes(by recipeIDs: [String]) async throws -> [Recipe] {
        return try await recipeModule.fetchRecipes(by: recipeIDs)
    }
    
    func updateAfterPhoto(for recipeID: String, afterPhoto: UIImage) async throws {
        try await recipeModule.updateAfterPhoto(for: recipeID, afterPhoto: afterPhoto)
    }
    
    func fetchRecipePhotos(for recipeID: String) async throws -> (before: UIImage?, after: UIImage?) {
        return try await recipeModule.fetchRecipePhotos(for: recipeID)
    }
    
    // User recipe management
    func addRecipeToUserProfile(_ recipeID: String, type: RecipeListType) async throws {
        try await recipeModule.addRecipeToUserProfile(recipeID, type: type)
    }
    
    func removeRecipeFromUserProfile(_ recipeID: String, type: RecipeListType) async throws {
        try await recipeModule.removeRecipeFromUserProfile(recipeID, type: type)
    }
    
    func getUserSavedRecipes() async throws -> [Recipe] {
        return try await recipeModule.getUserSavedRecipes()
    }
    
    func getUserCreatedRecipes() async throws -> [Recipe] {
        return try await recipeModule.getUserCreatedRecipes()
    }
    
    func getUserFavoritedRecipes() async throws -> [Recipe] {
        return try await recipeModule.getUserFavoritedRecipes()
    }
    
    func loadUserRecipeReferences() async {
        recipeModule.loadUserRecipeReferences()
    }
    
    // Recipe search and sharing
    func searchRecipes(query: String, limit: Int = 20) async throws -> [Recipe] {
        return try await recipeModule.searchRecipes(query: query, limit: limit)
    }
    
    func generateShareLink(for recipeID: String) -> URL {
        return recipeModule.generateShareLink(for: recipeID)
    }
    
    func handleRecipeShareLink(_ url: URL) async throws -> Recipe {
        return try await recipeModule.handleRecipeShareLink(url)
    }
    
    // Sync methods
    func fetchMissingRecipes(localRecipeIDs: Set<String>) async throws -> [Recipe] {
        return try await recipeModule.fetchMissingRecipes(localRecipeIDs: localRecipeIDs)
    }
    
    func performBackgroundSync(localRecipeIDs: Set<String>? = nil) {
        recipeModule.performBackgroundSync(localRecipeIDs: localRecipeIDs)
    }
    
    func isCacheUpToDate() async throws -> Bool {
        return try await recipeModule.isCacheUpToDate()
    }
    
    func getSyncStats() async throws -> SyncStats {
        return try await recipeModule.getSyncStats()
    }
    
    func performIntelligentSync() async throws -> SyncResult {
        return try await recipeModule.performIntelligentSync()
    }
}

// MARK: - User Module Access
extension CloudKitService {
    
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        return try await userModule.isUsernameAvailable(username)
    }
    
    func saveUserProfile(username: String, profileImage: UIImage?) async throws {
        try await userModule.saveUserProfile(username: username, profileImage: profileImage)
    }
    
    func fetchUserProfile(userID: String) async throws -> CKRecord? {
        return try await userModule.fetchUserProfile(userID: userID)
    }
    
    func fetchUserProfile(username: String) async throws -> CKRecord? {
        return try await userModule.fetchUserProfile(username: username)
    }
    
    func updateProfileImage(_ image: UIImage) async throws {
        try await userModule.updateProfileImage(image)
    }
    
    func updateBio(_ bio: String) async throws {
        try await userModule.updateBio(bio)
    }
    
    func incrementRecipesShared() async throws {
        try await userModule.incrementRecipesShared()
    }
    
    func updatePoints(_ points: Int) async throws {
        try await userModule.updatePoints(points)
    }
    
    func searchUserProfiles(query: String) async throws -> [CloudKitUserProfile] {
        return try await userModule.searchUsers(query: query)
    }
}

// MARK: - Challenge Module Access
extension CloudKitService {
    
    func uploadChallenge(_ challenge: Challenge) async throws -> String {
        return try await challengeModule.uploadChallenge(challenge)
    }
    
    func syncChallenges() async {
        await syncModule.syncChallenges()
        await challengeModule.syncChallenges()
    }
    
    func updateUserProgress(challengeID: String, progress: Double) async throws {
        try await challengeModule.updateUserProgress(challengeID: challengeID, progress: progress)
    }
    
    func getUserChallengeProgress() async throws -> [CloudKitUserChallenge] {
        return try await challengeModule.getUserChallengeProgress()
    }
    
    func createTeam(name: String, description: String, challengeID: String) async throws -> CloudKitTeam {
        return try await challengeModule.createTeam(name: name, description: description, challengeID: challengeID)
    }
    
    func joinTeam(inviteCode: String) async throws -> CloudKitTeam {
        return try await challengeModule.joinTeam(inviteCode: inviteCode)
    }
    
    func updateTeamPoints(teamID: String, additionalPoints: Int) async throws {
        try await challengeModule.updateTeamPoints(teamID: teamID, additionalPoints: additionalPoints)
    }
    
    func getTeamLeaderboard(challengeID: String) async throws -> [CloudKitTeam] {
        return try await challengeModule.getTeamLeaderboard(challengeID: challengeID)
    }
    
    func trackAchievement(type: String, name: String, description: String) async throws {
        try await challengeModule.trackAchievement(type: type, name: name, description: description)
    }
    
    func updateLeaderboard(points: Int) async throws {
        try await challengeModule.updateLeaderboard(points: points)
    }
}

// MARK: - Data Module Access
extension CloudKitService {
    
    func syncUserPreferences() async throws {
        try await dataModule.syncUserPreferences()
    }
    
    func fetchUserPreferences() async throws -> FoodPreferences? {
        return try await dataModule.fetchUserPreferences()
    }
    
    func trackCameraSession(_ session: CameraSessionData) async {
        await dataModule.trackCameraSession(session)
    }
    
    func trackRecipeGeneration(_ data: RecipeGenerationData) async {
        await dataModule.trackRecipeGeneration(data)
    }
    
    func startAppSession() -> String {
        return dataModule.startAppSession()
    }
    
    func endAppSession() async {
        await dataModule.endAppSession()
    }
    
    func trackScreenView(_ screen: String) {
        dataModule.trackScreenView(screen)
    }
    
    func trackFeatureUse(_ feature: String) {
        dataModule.trackFeatureUse(feature)
    }
    
    func trackSearch(_ query: String, type: String, results: Int) async {
        await dataModule.trackSearch(query, type: type, results: results)
    }
    
    func logError(_ error: CloudKitAppError) async {
        await dataModule.logError(error)
    }
    
    func registerDevice() async throws {
        try await dataModule.registerDevice()
    }
    
    func triggerManualSync() async {
        await dataModule.triggerManualSync()
    }
    
    func performFullSync() async {
        await dataModule.performFullSync()
    }
}

// MARK: - Streak Module Access
extension CloudKitService {
    
    func updateStreak(_ streak: StreakData) async {
        await streakModule.updateStreak(streak)
    }
    
    func recordStreakBreak(_ history: StreakHistory) async {
        await streakModule.recordStreakBreak(history)
    }
    
    func recordAchievement(_ achievement: StreakAchievement) async {
        await streakModule.recordAchievement(achievement)
    }
    
    func syncStreaks() async -> [StreakType: StreakData] {
        return await streakModule.syncStreaks()
    }
    
    func getStreakLeaderboard(type: StreakType, limit: Int = 100) async -> [(userID: String, streak: Int, username: String)] {
        return await streakModule.getStreakLeaderboard(type: type, limit: limit)
    }
}

// MARK: - Sync Module Access
extension CloudKitService {
    
    func uploadRecipeForSharing(_ recipe: Recipe, imageData: Data? = nil) async throws -> String {
        return try await syncModule.uploadRecipe(recipe, imageData: imageData)
    }
    
    func fetchSharedRecipe(by recordID: String) async throws -> (Recipe, CKRecord) {
        return try await syncModule.fetchRecipe(by: recordID)
    }
    
    func likeRecipe(_ recipeID: String, recipeOwnerID: String) async throws {
        try await syncModule.likeRecipe(recipeID, recipeOwnerID: recipeOwnerID)
    }
    
    func likeRecipe(recipeID: String) async throws {
        try await syncModule.likeRecipe(recipeID)
    }
    
    func unlikeRecipe(_ recipeID: String) async throws {
        try await syncModule.unlikeRecipe(recipeID)
    }
    
    func unlikeRecipe(recipeID: String) async throws {
        try await syncModule.unlikeRecipe(recipeID)
    }
    
    func isRecipeLiked(_ recipeID: String) async throws -> Bool {
        return try await syncModule.isRecipeLiked(recipeID)
    }
    
    func getRecipeLikeCount(_ recipeID: String) async throws -> Int {
        return try await syncModule.getRecipeLikeCount(recipeID)
    }
    
    func getLikeCount(for recipeID: String) async -> Int {
        return (try? await syncModule.getRecipeLikeCount(recipeID)) ?? 0
    }
    
    func fetchUserLikedRecipes() async -> [String] {
        return (try? await syncModule.fetchUserLikedRecipeIDs()) ?? []
    }
    
    func batchFetchLikeCounts(for recipeIDs: [String]) async -> [String: Int] {
        var counts: [String: Int] = [:]
        for recipeID in recipeIDs {
            counts[recipeID] = (try? await syncModule.getRecipeLikeCount(recipeID)) ?? 0
        }
        
        return counts
    }
    
    /// Syncs the like count for a recipe by counting RecipeLike records
    /// This method can be used for data consistency and recovery
    func syncRecipeLikeCount(_ recipeID: String) async {
        await syncModule.syncRecipeLikeCount(recipeID)
    }
    
    func createActivity(type: String, actorID: String,
                       targetUserID: String? = nil,
                       recipeID: String? = nil, recipeName: String? = nil,
                       challengeID: String? = nil, challengeName: String? = nil) async throws {
        try await syncModule.createActivity(type: type, actorID: actorID,
                                          targetUserID: targetUserID,
                                          recipeID: recipeID, recipeName: recipeName,
                                          challengeID: challengeID, challengeName: challengeName)
    }
    
    func fetchActivityFeed(for userID: String, limit: Int = 20) async throws -> [CKRecord] {
        return try await syncModule.fetchActivityFeed(for: userID, limit: limit)
    }
    
    func markActivityAsRead(_ activityID: String) async throws {
        try await syncModule.markActivityAsRead(activityID)
    }
    
    func addComment(recipeID: String, content: String, parentCommentID: String? = nil) async throws {
        try await syncModule.addComment(recipeID: recipeID, content: content, parentCommentID: parentCommentID)
    }
    
    func fetchComments(for recipeID: String, limit: Int = 50) async throws -> [CKRecord] {
        return try await syncModule.fetchComments(for: recipeID, limit: limit)
    }
    
    func deleteComment(_ commentID: String) async throws {
        try await syncModule.deleteComment(commentID)
    }
    
    func likeComment(_ commentID: String) async throws {
        try await syncModule.likeComment(commentID)
    }
    
    func unlikeComment(_ commentID: String) async throws {
        try await syncModule.unlikeComment(commentID)
    }
    
    func isCommentLiked(_ commentID: String) async throws -> Bool {
        return try await syncModule.isCommentLiked(commentID)
    }
    
    func triggerChallengeSync() async {
        await syncModule.triggerChallengeSync()
    }
    
    func syncUserProgress() async {
        await syncModule.syncUserProgress()
    }
    
    func fetchSocialRecipeFeed(lastDate: Date? = nil, limit: Int = 20) async throws -> [SocialRecipeCard] {
        return try await syncModule.fetchSocialRecipeFeed(lastDate: lastDate, limit: limit)
    }
    
    func submitChallengeProof(challengeID: String, proofImage: UIImage, notes: String? = nil) async throws {
        try await syncModule.submitChallengeProof(challengeID: challengeID, proofImage: proofImage, notes: notes)
    }
    
    func updateLeaderboardEntry(for userID: String, points: Int, challengesCompleted: Int) async throws {
        try await syncModule.updateLeaderboardEntry(for: userID, points: points, challengesCompleted: challengesCompleted)
    }
}

// MARK: - Helper Types and Extensions
extension CloudKitService {
    
    /// Get current user ID from various sources
    private func getCurrentUserID() -> String? {
        // Try both keys for compatibility
        if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
            return userID
        }
        return UserDefaults.standard.string(forKey: "currentUserRecordID")
    }
}

// MARK: - Public Properties Access
extension CloudKitService {
    
    var authCompletionHandler: (() -> Void)? {
        get { authModule.authCompletionHandler }
        set { authModule.authCompletionHandler = newValue }
    }
    
    var showAuthSheet: Bool {
        get { authModule.showAuthSheet }
        set { authModule.showAuthSheet = newValue }
    }
    
    var showUsernameSelection: Bool {
        get { authModule.showUsernameSelection }
        set { authModule.showUsernameSelection = newValue }
    }
    
    var showError: Bool {
        get { authModule.showError }
        set { authModule.showError = newValue }
    }
    
    var errorMessage: String {
        get { authModule.errorMessage }
        set { authModule.errorMessage = newValue }
    }
    
    var isLoading: Bool {
        get { authModule.isLoading }
        set { authModule.isLoading = newValue }
    }
    
    var cachedRecipes: [String: Recipe] {
        recipeModule.cachedRecipes
    }
    
    var activeChallenges: [Challenge] {
        challengeModule.activeChallenges
    }
    
    var userChallenges: [CloudKitUserChallenge] {
        challengeModule.userChallenges
    }
    
    var teams: [CloudKitTeam] {
        challengeModule.teams
    }
    
    var syncErrors: [String] {
        dataModule.syncErrors
    }
}
