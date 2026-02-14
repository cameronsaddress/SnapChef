import Foundation
import CloudKit
import SwiftUI
import Combine
import UIKit
import AuthenticationServices

enum CloudKitServiceError: LocalizedError {
    case cloudKitUnavailable(operation: String)

    var errorDescription: String? {
        switch self {
        case .cloudKitUnavailable(let operation):
            return "CloudKit is unavailable for \(operation)."
        }
    }
}

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
    private let container: CKContainer?
    private let publicDatabase: CKDatabase?
    private let privateDatabase: CKDatabase?
    let cloudKitActor = CloudKitActor()
    
    // MARK: - Service Modules
    private var authModule: AuthModule?
    private var recipeModule: RecipeModule?
    private var userModule: UserModule?
    private var challengeModule: ChallengeModule?
    private var dataModule: DataModule?
    private var streakModule: StreakModule?
    private var syncModule: SyncModule?
    
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
    private var didBootstrap = false
    
    // MARK: - Initialization
    private init() {
        if Self.isRunningTests {
            self.container = nil
            self.publicDatabase = nil
            self.privateDatabase = nil
            return
        }
        CloudKitRuntimeSupport.logDiagnosticsIfNeeded()
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement,
              let container = CloudKitRuntimeSupport.makeContainer() else {
            self.container = nil
            self.publicDatabase = nil
            self.privateDatabase = nil
            print("⚠️ CloudKitService running in local-only mode: CloudKit modules not initialized")
            return
        }

        self.container = container
        self.publicDatabase = container.publicCloudDatabase
        self.privateDatabase = container.privateCloudDatabase
        
        // Initialize modules
        self.authModule = AuthModule(container: container, publicDB: container.publicCloudDatabase, privateDB: container.privateCloudDatabase, parent: self)
        self.recipeModule = RecipeModule(container: container, publicDB: container.publicCloudDatabase, privateDB: container.privateCloudDatabase, parent: self)
        self.userModule = UserModule(container: container, publicDB: container.publicCloudDatabase, privateDB: container.privateCloudDatabase, parent: self)
        self.challengeModule = ChallengeModule(container: container, publicDB: container.publicCloudDatabase, privateDB: container.privateCloudDatabase, parent: self)
        self.dataModule = DataModule(container: container, publicDB: container.publicCloudDatabase, privateDB: container.privateCloudDatabase, parent: self)
        self.streakModule = StreakModule(container: container, publicDB: container.publicCloudDatabase, privateDB: container.privateCloudDatabase, parent: self)
        self.syncModule = SyncModule(container: container, publicDB: container.publicCloudDatabase, privateDB: container.privateCloudDatabase, parent: self)
        
        setupModuleBindings()
    }

    private func requireModule<T>(_ module: T?, operation: String) throws -> T {
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            throw CloudKitServiceError.cloudKitUnavailable(operation: operation)
        }
        guard let module else {
            throw CloudKitServiceError.cloudKitUnavailable(operation: operation)
        }
        return module
    }

    private func setupModuleBindings() {
        guard let recipeModule else { return }

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
    
    // MARK: - Bootstrap

    /// Lazily bootstraps CloudKit modules that may trigger iCloud system prompts.
    ///
    /// Calling `CKContainer.accountStatus` / subscription setup can cause iOS to display
    /// Apple Account/iCloud verification prompts. We keep startup "quiet" and only bootstrap
    /// once the user has explicitly authenticated or entered CloudKit-required flows.
    func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true

        authModule?.checkAuthStatus()
        setupSubscriptions()
    }

    // MARK: - Subscriptions
    private func setupSubscriptions() {
        syncModule?.setupSubscriptions()
    }
}

// MARK: - Authentication Module Access
extension CloudKitService {
    
    // Authentication methods
    func signInWithApple(authorization: ASAuthorization) async throws {
        let authModule = try requireModule(authModule, operation: "signInWithApple")
        try await authModule.signInWithApple(authorization: authorization)
    }
    
    func signInWithFacebook(userID: String, email: String?, name: String?, profileImageURL: String?) async throws {
        let authModule = try requireModule(authModule, operation: "signInWithFacebook")
        try await authModule.signInWithFacebook(userID: userID, email: email, name: name, profileImageURL: profileImageURL)
    }
    
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let authModule = try requireModule(authModule, operation: "checkUsernameAvailability")
        return try await authModule.checkUsernameAvailability(username)
    }
    
    func setUsername(_ username: String) async throws {
        let authModule = try requireModule(authModule, operation: "setUsername")
        try await authModule.setUsername(username)
    }
    
    func signOut() {
        authModule?.signOut()
    }
    
    func updateUserStats(_ updates: UserStatUpdates) async throws {
        let authModule = try requireModule(authModule, operation: "updateUserStats")
        try await authModule.updateUserStats(updates)
    }
    
    func isAuthRequiredFor(feature: AuthRequiredFeature) -> Bool {
        guard let authModule else { return false }
        return authModule.isAuthRequiredFor(feature: feature)
    }
    
    func promptAuthForFeature(_ feature: AuthRequiredFeature) {
        authModule?.promptAuthForFeature(feature)
    }
    
    // Social methods
    func followUser(_ userID: String) async throws {
        let authModule = try requireModule(authModule, operation: "followUser")
        try await authModule.followUser(userID)
    }
    
    func unfollowUser(_ userID: String) async throws {
        let authModule = try requireModule(authModule, operation: "unfollowUser")
        try await authModule.unfollowUser(userID)
    }
    
    func isFollowing(_ userID: String) async throws -> Bool {
        let authModule = try requireModule(authModule, operation: "isFollowing")
        return try await authModule.isFollowing(userID)
    }
    
    func updateRecipeCounts() async {
        await authModule?.updateRecipeCounts()
    }
    
    func updateSocialCounts() async {
        await authModule?.updateSocialCounts()
    }
    
    func refreshCurrentUser() async {
        await authModule?.refreshCurrentUser()
    }
    
    func searchUsers(query: String) async throws -> [CloudKitUser] {
        let authModule = try requireModule(authModule, operation: "searchUsers")
        return try await authModule.searchUsers(query: query)
    }
    
    func getSuggestedUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        let authModule = try requireModule(authModule, operation: "getSuggestedUsers")
        return try await authModule.getSuggestedUsers(limit: limit)
    }
    
    func getTrendingUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        let authModule = try requireModule(authModule, operation: "getTrendingUsers")
        return try await authModule.getTrendingUsers(limit: limit)
    }
    
    func getVerifiedUsers(limit: Int = 20) async throws -> [CloudKitUser] {
        let authModule = try requireModule(authModule, operation: "getVerifiedUsers")
        return try await authModule.getVerifiedUsers(limit: limit)
    }
}

// MARK: - Recipe Module Access
extension CloudKitService {
    
    // Recipe management
    func uploadRecipe(_ recipe: Recipe, fromLLM: Bool = false, beforePhoto: UIImage? = nil) async throws -> String {
        let recipeModule = try requireModule(recipeModule, operation: "uploadRecipe")
        return try await recipeModule.uploadRecipe(recipe, fromLLM: fromLLM, beforePhoto: beforePhoto)
    }
    
    func fetchRecipe(by recipeID: String) async throws -> Recipe {
        let recipeModule = try requireModule(recipeModule, operation: "fetchRecipe")
        return try await recipeModule.fetchRecipe(by: recipeID)
    }
    
    func recipeExists(with recipeID: String) async -> Bool {
        guard let recipeModule else { return false }
        return await recipeModule.recipeExists(with: recipeID)
    }
    
    func existingRecipeID(name: String, description: String) async -> String? {
        guard let recipeModule else { return nil }
        return await recipeModule.existingRecipeID(name: name, description: description)
    }
    
    func fetchRecipes(by recipeIDs: [String]) async throws -> [Recipe] {
        let recipeModule = try requireModule(recipeModule, operation: "fetchRecipes")
        return try await recipeModule.fetchRecipes(by: recipeIDs)
    }
    
    func updateAfterPhoto(for recipeID: String, afterPhoto: UIImage) async throws {
        let recipeModule = try requireModule(recipeModule, operation: "updateAfterPhoto")
        try await recipeModule.updateAfterPhoto(for: recipeID, afterPhoto: afterPhoto)
    }
    
    func fetchRecipePhotos(for recipeID: String) async throws -> (before: UIImage?, after: UIImage?) {
        let recipeModule = try requireModule(recipeModule, operation: "fetchRecipePhotos")
        return try await recipeModule.fetchRecipePhotos(for: recipeID)
    }
    
    // User recipe management
    func addRecipeToUserProfile(_ recipeID: String, type: RecipeListType) async throws {
        let recipeModule = try requireModule(recipeModule, operation: "addRecipeToUserProfile")
        try await recipeModule.addRecipeToUserProfile(recipeID, type: type)
    }
    
    func removeRecipeFromUserProfile(_ recipeID: String, type: RecipeListType) async throws {
        let recipeModule = try requireModule(recipeModule, operation: "removeRecipeFromUserProfile")
        try await recipeModule.removeRecipeFromUserProfile(recipeID, type: type)
    }
    
    func getUserSavedRecipes() async throws -> [Recipe] {
        let recipeModule = try requireModule(recipeModule, operation: "getUserSavedRecipes")
        return try await recipeModule.getUserSavedRecipes()
    }
    
    func getUserCreatedRecipes() async throws -> [Recipe] {
        let recipeModule = try requireModule(recipeModule, operation: "getUserCreatedRecipes")
        return try await recipeModule.getUserCreatedRecipes()
    }
    
    func getUserFavoritedRecipes() async throws -> [Recipe] {
        let recipeModule = try requireModule(recipeModule, operation: "getUserFavoritedRecipes")
        return try await recipeModule.getUserFavoritedRecipes()
    }
    
    func loadUserRecipeReferences() async {
        recipeModule?.loadUserRecipeReferences()
    }
    
    // Recipe search and sharing
    func searchRecipes(query: String, limit: Int = 20) async throws -> [Recipe] {
        let recipeModule = try requireModule(recipeModule, operation: "searchRecipes")
        return try await recipeModule.searchRecipes(query: query, limit: limit)
    }
    
    func generateShareLink(for recipeID: String) -> URL {
        guard let recipeModule else { return URL(string: "https://snapchef.app")! }
        return recipeModule.generateShareLink(for: recipeID)
    }
    
    func handleRecipeShareLink(_ url: URL) async throws -> Recipe {
        let recipeModule = try requireModule(recipeModule, operation: "handleRecipeShareLink")
        return try await recipeModule.handleRecipeShareLink(url)
    }
    
    // Sync methods
    func fetchMissingRecipes(localRecipeIDs: Set<String>) async throws -> [Recipe] {
        let recipeModule = try requireModule(recipeModule, operation: "fetchMissingRecipes")
        return try await recipeModule.fetchMissingRecipes(localRecipeIDs: localRecipeIDs)
    }
    
    func performBackgroundSync(localRecipeIDs: Set<String>? = nil) {
        recipeModule?.performBackgroundSync(localRecipeIDs: localRecipeIDs)
    }
    
    func isCacheUpToDate() async throws -> Bool {
        let recipeModule = try requireModule(recipeModule, operation: "isCacheUpToDate")
        return try await recipeModule.isCacheUpToDate()
    }
    
    func getSyncStats() async throws -> SyncStats {
        let recipeModule = try requireModule(recipeModule, operation: "getSyncStats")
        return try await recipeModule.getSyncStats()
    }
    
    func performIntelligentSync() async throws -> SyncResult {
        let recipeModule = try requireModule(recipeModule, operation: "performIntelligentSync")
        return try await recipeModule.performIntelligentSync()
    }
}

// MARK: - User Module Access
extension CloudKitService {
    
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let userModule = try requireModule(userModule, operation: "isUsernameAvailable")
        return try await userModule.isUsernameAvailable(username)
    }
    
    func saveUserProfile(username: String, profileImage: UIImage?) async throws {
        let userModule = try requireModule(userModule, operation: "saveUserProfile")
        try await userModule.saveUserProfile(username: username, profileImage: profileImage)
    }
    
    func fetchUserProfile(userID: String) async throws -> CKRecord? {
        let userModule = try requireModule(userModule, operation: "fetchUserProfile(userID:)")
        return try await userModule.fetchUserProfile(userID: userID)
    }
    
    func fetchUserProfile(username: String) async throws -> CKRecord? {
        let userModule = try requireModule(userModule, operation: "fetchUserProfile(username:)")
        return try await userModule.fetchUserProfile(username: username)
    }
    
    func updateProfileImage(_ image: UIImage) async throws {
        let userModule = try requireModule(userModule, operation: "updateProfileImage")
        try await userModule.updateProfileImage(image)
    }
    
    func updateBio(_ bio: String) async throws {
        let userModule = try requireModule(userModule, operation: "updateBio")
        try await userModule.updateBio(bio)
    }
    
    func incrementRecipesShared() async throws {
        let userModule = try requireModule(userModule, operation: "incrementRecipesShared")
        try await userModule.incrementRecipesShared()
    }
    
    func updatePoints(_ points: Int) async throws {
        let userModule = try requireModule(userModule, operation: "updatePoints")
        try await userModule.updatePoints(points)
    }
    
    func searchUserProfiles(query: String) async throws -> [CloudKitUserProfile] {
        let userModule = try requireModule(userModule, operation: "searchUserProfiles")
        return try await userModule.searchUsers(query: query)
    }
}

// MARK: - Challenge Module Access
extension CloudKitService {
    
    func uploadChallenge(_ challenge: Challenge) async throws -> String {
        let challengeModule = try requireModule(challengeModule, operation: "uploadChallenge")
        return try await challengeModule.uploadChallenge(challenge)
    }
    
    func syncChallenges() async {
        await syncModule?.syncChallenges()
        await challengeModule?.syncChallenges()
    }
    
    func updateUserProgress(challengeID: String, progress: Double) async throws {
        let challengeModule = try requireModule(challengeModule, operation: "updateUserProgress")
        try await challengeModule.updateUserProgress(challengeID: challengeID, progress: progress)
    }
    
    func getUserChallengeProgress() async throws -> [CloudKitUserChallenge] {
        let challengeModule = try requireModule(challengeModule, operation: "getUserChallengeProgress")
        return try await challengeModule.getUserChallengeProgress()
    }
    
    func createTeam(name: String, description: String, challengeID: String) async throws -> CloudKitTeam {
        let challengeModule = try requireModule(challengeModule, operation: "createTeam")
        return try await challengeModule.createTeam(name: name, description: description, challengeID: challengeID)
    }
    
    func joinTeam(inviteCode: String) async throws -> CloudKitTeam {
        let challengeModule = try requireModule(challengeModule, operation: "joinTeam")
        return try await challengeModule.joinTeam(inviteCode: inviteCode)
    }
    
    func updateTeamPoints(teamID: String, additionalPoints: Int) async throws {
        let challengeModule = try requireModule(challengeModule, operation: "updateTeamPoints")
        try await challengeModule.updateTeamPoints(teamID: teamID, additionalPoints: additionalPoints)
    }
    
    func getTeamLeaderboard(challengeID: String) async throws -> [CloudKitTeam] {
        let challengeModule = try requireModule(challengeModule, operation: "getTeamLeaderboard")
        return try await challengeModule.getTeamLeaderboard(challengeID: challengeID)
    }
    
    func trackAchievement(type: String, name: String, description: String) async throws {
        let challengeModule = try requireModule(challengeModule, operation: "trackAchievement")
        try await challengeModule.trackAchievement(type: type, name: name, description: description)
    }
    
    func updateLeaderboard(points: Int) async throws {
        let challengeModule = try requireModule(challengeModule, operation: "updateLeaderboard")
        try await challengeModule.updateLeaderboard(points: points)
    }
}

// MARK: - Data Module Access
extension CloudKitService {
    
    func syncUserPreferences() async throws {
        let dataModule = try requireModule(dataModule, operation: "syncUserPreferences")
        try await dataModule.syncUserPreferences()
    }
    
    func fetchUserPreferences() async throws -> FoodPreferences? {
        let dataModule = try requireModule(dataModule, operation: "fetchUserPreferences")
        return try await dataModule.fetchUserPreferences()
    }
    
    func trackCameraSession(_ session: CameraSessionData) async {
        await dataModule?.trackCameraSession(session)
    }
    
    func trackRecipeGeneration(_ data: RecipeGenerationData) async {
        await dataModule?.trackRecipeGeneration(data)
    }
    
    func startAppSession() -> String {
        if let dataModule {
            return dataModule.startAppSession()
        }
        return UUID().uuidString
    }
    
    func endAppSession() async {
        await dataModule?.endAppSession()
    }
    
    func trackScreenView(_ screen: String) {
        dataModule?.trackScreenView(screen)
    }
    
    func trackFeatureUse(_ feature: String) {
        dataModule?.trackFeatureUse(feature)
    }
    
    func trackSearch(_ query: String, type: String, results: Int) async {
        await dataModule?.trackSearch(query, type: type, results: results)
    }
    
    func logError(_ error: CloudKitAppError) async {
        await dataModule?.logError(error)
    }
    
    func registerDevice() async throws {
        let dataModule = try requireModule(dataModule, operation: "registerDevice")
        try await dataModule.registerDevice()
    }
    
    func triggerManualSync() async {
        await dataModule?.triggerManualSync()
    }
    
    func performFullSync() async {
        await dataModule?.performFullSync()
    }
}

// MARK: - Streak Module Access
extension CloudKitService {
    
    func updateStreak(_ streak: StreakData) async {
        await streakModule?.updateStreak(streak)
    }
    
    func recordStreakBreak(_ history: StreakHistory) async {
        await streakModule?.recordStreakBreak(history)
    }
    
    func recordAchievement(_ achievement: StreakAchievement) async {
        await streakModule?.recordAchievement(achievement)
    }
    
    func syncStreaks() async -> [StreakType: StreakData] {
        guard let streakModule else { return [:] }
        return await streakModule.syncStreaks()
    }
    
    func getStreakLeaderboard(type: StreakType, limit: Int = 100) async -> [(userID: String, streak: Int, username: String)] {
        guard let streakModule else { return [] }
        return await streakModule.getStreakLeaderboard(type: type, limit: limit)
    }
}

// MARK: - Sync Module Access
extension CloudKitService {
    
    func uploadRecipeForSharing(_ recipe: Recipe, imageData: Data? = nil) async throws -> String {
        let syncModule = try requireModule(syncModule, operation: "uploadRecipeForSharing")
        return try await syncModule.uploadRecipe(recipe, imageData: imageData)
    }
    
    func fetchSharedRecipe(by recordID: String) async throws -> (Recipe, CKRecord) {
        let syncModule = try requireModule(syncModule, operation: "fetchSharedRecipe")
        return try await syncModule.fetchRecipe(by: recordID)
    }
    
    func likeRecipe(_ recipeID: String, recipeOwnerID: String) async throws {
        let syncModule = try requireModule(syncModule, operation: "likeRecipe(owner)")
        try await syncModule.likeRecipe(recipeID, recipeOwnerID: recipeOwnerID)
    }
    
    func likeRecipe(recipeID: String) async throws {
        let syncModule = try requireModule(syncModule, operation: "likeRecipe")
        try await syncModule.likeRecipe(recipeID)
    }
    
    func unlikeRecipe(_ recipeID: String) async throws {
        let syncModule = try requireModule(syncModule, operation: "unlikeRecipe")
        try await syncModule.unlikeRecipe(recipeID)
    }
    
    func unlikeRecipe(recipeID: String) async throws {
        let syncModule = try requireModule(syncModule, operation: "unlikeRecipe(legacy)")
        try await syncModule.unlikeRecipe(recipeID)
    }
    
    func isRecipeLiked(_ recipeID: String) async throws -> Bool {
        let syncModule = try requireModule(syncModule, operation: "isRecipeLiked")
        return try await syncModule.isRecipeLiked(recipeID)
    }
    
    func getRecipeLikeCount(_ recipeID: String) async throws -> Int {
        let syncModule = try requireModule(syncModule, operation: "getRecipeLikeCount")
        return try await syncModule.getRecipeLikeCount(recipeID)
    }
    
    func getLikeCount(for recipeID: String) async -> Int {
        guard let syncModule else { return 0 }
        return (try? await syncModule.getRecipeLikeCount(recipeID)) ?? 0
    }
    
    func fetchUserLikedRecipes() async -> [String] {
        guard let syncModule else { return [] }
        return (try? await syncModule.fetchUserLikedRecipeIDs()) ?? []
    }
    
    func batchFetchLikeCounts(for recipeIDs: [String]) async -> [String: Int] {
        var counts: [String: Int] = [:]
        guard let syncModule else { return counts }
        for recipeID in recipeIDs {
            counts[recipeID] = (try? await syncModule.getRecipeLikeCount(recipeID)) ?? 0
        }
        
        return counts
    }
    
    /// Syncs the like count for a recipe by counting RecipeLike records
    /// This method can be used for data consistency and recovery
    func syncRecipeLikeCount(_ recipeID: String) async {
        await syncModule?.syncRecipeLikeCount(recipeID)
    }
    
    func createActivity(type: String, actorID: String,
                       targetUserID: String? = nil,
                       recipeID: String? = nil, recipeName: String? = nil,
                       challengeID: String? = nil, challengeName: String? = nil) async throws {
        let syncModule = try requireModule(syncModule, operation: "createActivity")
        try await syncModule.createActivity(type: type, actorID: actorID,
                                            targetUserID: targetUserID,
                                            recipeID: recipeID, recipeName: recipeName,
                                            challengeID: challengeID, challengeName: challengeName)
    }
    
    func fetchActivityFeed(for userID: String, limit: Int = 20) async throws -> [CKRecord] {
        let syncModule = try requireModule(syncModule, operation: "fetchActivityFeed")
        return try await syncModule.fetchActivityFeed(for: userID, limit: limit)
    }
    
    func markActivityAsRead(_ activityID: String) async throws {
        let syncModule = try requireModule(syncModule, operation: "markActivityAsRead")
        try await syncModule.markActivityAsRead(activityID)
    }
    
    func addComment(recipeID: String, content: String, parentCommentID: String? = nil) async throws {
        let syncModule = try requireModule(syncModule, operation: "addComment")
        try await syncModule.addComment(recipeID: recipeID, content: content, parentCommentID: parentCommentID)
    }
    
    func fetchComments(for recipeID: String, limit: Int = 50) async throws -> [CKRecord] {
        let syncModule = try requireModule(syncModule, operation: "fetchComments")
        return try await syncModule.fetchComments(for: recipeID, limit: limit)
    }
    
    func deleteComment(_ commentID: String) async throws {
        let syncModule = try requireModule(syncModule, operation: "deleteComment")
        try await syncModule.deleteComment(commentID)
    }
    
    func likeComment(_ commentID: String) async throws {
        let syncModule = try requireModule(syncModule, operation: "likeComment")
        try await syncModule.likeComment(commentID)
    }
    
    func unlikeComment(_ commentID: String) async throws {
        let syncModule = try requireModule(syncModule, operation: "unlikeComment")
        try await syncModule.unlikeComment(commentID)
    }
    
    func isCommentLiked(_ commentID: String) async throws -> Bool {
        let syncModule = try requireModule(syncModule, operation: "isCommentLiked")
        return try await syncModule.isCommentLiked(commentID)
    }
    
    func triggerChallengeSync() async {
        await syncModule?.triggerChallengeSync()
    }
    
    func syncUserProgress() async {
        await syncModule?.syncUserProgress()
    }
    
    func fetchSocialRecipeFeed(lastDate: Date? = nil, limit: Int = 20) async throws -> [SocialRecipeCard] {
        let syncModule = try requireModule(syncModule, operation: "fetchSocialRecipeFeed")
        return try await syncModule.fetchSocialRecipeFeed(lastDate: lastDate, limit: limit)
    }
    
    func submitChallengeProof(challengeID: String, proofImage: UIImage, notes: String? = nil) async throws {
        let syncModule = try requireModule(syncModule, operation: "submitChallengeProof")
        try await syncModule.submitChallengeProof(challengeID: challengeID, proofImage: proofImage, notes: notes)
    }
    
    func updateLeaderboardEntry(for userID: String, points: Int, challengesCompleted: Int) async throws {
        let syncModule = try requireModule(syncModule, operation: "updateLeaderboardEntry")
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
        get { authModule?.authCompletionHandler }
        set { authModule?.authCompletionHandler = newValue }
    }
    
    var showAuthSheet: Bool {
        get { authModule?.showAuthSheet ?? false }
        set { authModule?.showAuthSheet = newValue }
    }
    
    var showUsernameSelection: Bool {
        get { authModule?.showUsernameSelection ?? false }
        set { authModule?.showUsernameSelection = newValue }
    }
    
    var showError: Bool {
        get { authModule?.showError ?? false }
        set { authModule?.showError = newValue }
    }
    
    var errorMessage: String {
        get { authModule?.errorMessage ?? "" }
        set { authModule?.errorMessage = newValue }
    }
    
    var isLoading: Bool {
        get { authModule?.isLoading ?? false }
        set { authModule?.isLoading = newValue }
    }
    
    var cachedRecipes: [String: Recipe] {
        recipeModule?.cachedRecipes ?? [:]
    }
    
    var activeChallenges: [Challenge] {
        challengeModule?.activeChallenges ?? []
    }
    
    var userChallenges: [CloudKitUserChallenge] {
        challengeModule?.userChallenges ?? []
    }
    
    var teams: [CloudKitTeam] {
        challengeModule?.teams ?? []
    }
    
    var syncErrors: [String] {
        dataModule?.syncErrors ?? []
    }
}
