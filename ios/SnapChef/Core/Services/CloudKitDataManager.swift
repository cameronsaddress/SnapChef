import Foundation
import CloudKit
import SwiftUI
import Combine

/// Comprehensive CloudKit data manager for full app synchronization
@MainActor
final class CloudKitDataManager: ObservableObject {
    // Fix for Swift concurrency issue with @MainActor singletons
    static let shared: CloudKitDataManager = {
        let instance = CloudKitDataManager()
        return instance
    }()

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        NSClassFromString("XCTestCase") != nil
    }

    private lazy var container: CKContainer? = {
        CloudKitRuntimeSupport.makeContainer()
    }()

    private func requirePublicDB(for operation: String) throws -> CKDatabase {
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            throw SnapChefError.syncError("CloudKit unavailable for \(operation)")
        }
        guard let container else {
            throw SnapChefError.syncError("CloudKit container unavailable for \(operation)")
        }
        return container.publicCloudDatabase
    }

    private func requirePrivateDB(for operation: String) throws -> CKDatabase {
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            throw SnapChefError.syncError("CloudKit unavailable for \(operation)")
        }
        guard let container else {
            throw SnapChefError.syncError("CloudKit container unavailable for \(operation)")
        }
        return container.privateCloudDatabase
    }

    // Published properties for dynamic UI updates
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [String] = []

    // Cache for offline access
    private var dataCache = DataCache()
    private var syncQueue = DispatchQueue(label: "com.snapchef.cloudkit.sync", qos: .background)
    private let userDefaults = UserDefaults.standard
    private let subscriptionSetupKeyPrefix = "cloudkit_subscription_setup_v2_"

    private init() {
        guard !Self.isRunningTests else { return }
        CloudKitRuntimeSupport.logDiagnosticsIfNeeded()
        if CloudKitRuntimeSupport.hasCloudKitEntitlement {
            Task { @MainActor in
                await ensureSubscriptionsConfigured()
            }
        } else {
            print("⚠️ CloudKitDataManager subscription bootstrap skipped: missing iCloud CloudKit entitlement")
        }
        // Removed automatic periodic sync - only sync when needed
    }

    // MARK: - User Preferences Sync

    func syncUserPreferences() async throws {
        guard let userID = getCurrentUserID() else { return }
        let privateDB = try requirePrivateDB(for: "syncUserPreferences")

        // Load from UserDefaults
        let preferences = loadLocalPreferences()

        // Create/Update CloudKit record
        let record = CKRecord(recordType: "FoodPreference")
        record["userID"] = userID
        record["dietaryRestrictions"] = preferences.dietaryRestrictions
        record["allergies"] = preferences.allergies
        record["favoriteCuisines"] = preferences.favoriteCuisines
        record["dislikedIngredients"] = preferences.dislikedIngredients
        record["cookingSkillLevel"] = preferences.cookingSkillLevel
        record["preferredCookTime"] = preferences.preferredCookTime
        record["kitchenTools"] = preferences.kitchenTools
        record["mealPlanningGoals"] = preferences.mealPlanningGoals
        record["lastUpdated"] = Date()

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: "FoodPreference", database: privateDB.debugName)
        
        do {
            _ = try await saveRecordWithRetry(record: record, database: privateDB, maxRetries: 2)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: "FoodPreference", recordID: record.recordID.recordName, database: privateDB.debugName, duration: duration)
            print("✅ Preferences synced to CloudKit")
        } catch let error as CKError {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: "FoodPreference", database: privateDB.debugName, error: error, duration: duration)
            let snapChefError = CloudKitErrorHandler.snapChefError(from: error)
            let errorMessage = "Failed to sync preferences: \(snapChefError.userFriendlyMessage)"
            syncErrors.append(errorMessage)
            ErrorAnalytics.logError(snapChefError, context: "user_preferences_sync")
            throw snapChefError
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: "FoodPreference", database: privateDB.debugName, error: error, duration: duration)
            let errorMessage = "Failed to sync preferences: \(error.localizedDescription)"
            syncErrors.append(errorMessage)
            let snapChefError = SnapChefError.syncError(errorMessage)
            ErrorAnalytics.logError(snapChefError, context: "user_preferences_sync_unexpected")
            throw snapChefError
        }
    }

    func fetchUserPreferences() async throws -> FoodPreferences? {
        guard let userID = getCurrentUserID() else { return nil }
        let privateDB = try requirePrivateDB(for: "fetchUserPreferences")

        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "FoodPreference", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "lastUpdated", ascending: false)]

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logQueryStart(query: query, database: privateDB.debugName)
        
        do {
            let (matchResults, _) = try await fetchRecordsWithRetry(query: query, database: privateDB, maxRetries: 2)
            let duration = Date().timeIntervalSince(startTime)
            logger.logQuerySuccess(query: query, resultCount: matchResults.count, database: privateDB.debugName, duration: duration)
            
            guard let recordResult = matchResults.first?.1,
                  let record = try? recordResult.get() else { 
                print("No preferences found in CloudKit, returning local cache")
                return loadLocalPreferences()
            }

            let preferences = FoodPreferences(
                dietaryRestrictions: record["dietaryRestrictions"] as? [String] ?? [],
                allergies: record["allergies"] as? [String] ?? [],
                favoriteCuisines: record["favoriteCuisines"] as? [String] ?? [],
                dislikedIngredients: record["dislikedIngredients"] as? [String] ?? [],
                cookingSkillLevel: record["cookingSkillLevel"] as? String ?? "intermediate",
                preferredCookTime: record["preferredCookTime"] as? Int ?? 30,
                kitchenTools: record["kitchenTools"] as? [String] ?? [],
                mealPlanningGoals: record["mealPlanningGoals"] as? String ?? ""
            )

            // Update local cache
            saveLocalPreferences(preferences)

            return preferences
        } catch let error as CKError {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: privateDB.debugName, error: error, duration: duration)
            let snapChefError = CloudKitErrorHandler.snapChefError(from: error)
            print("❌ Failed to fetch preferences: \(snapChefError.userFriendlyMessage)")
            ErrorAnalytics.logError(snapChefError, context: "user_preferences_fetch")
            // Return cached version on CloudKit errors
            return loadLocalPreferences()
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logQueryFailure(query: query, database: privateDB.debugName, error: error, duration: duration)
            print("❌ Failed to fetch preferences: \(error.localizedDescription)")
            let snapChefError = SnapChefError.syncError("Failed to fetch preferences: \(error.localizedDescription)")
            ErrorAnalytics.logError(snapChefError, context: "user_preferences_fetch_unexpected")
            // Return cached version
            return loadLocalPreferences()
        }
    }

    // MARK: - Camera Session Tracking

    func trackCameraSession(_ session: CameraSessionData) async {
        guard let userID = getCurrentUserID() else { return }

        let record = CKRecord(recordType: "CameraSession")
        record["userID"] = userID
        record["sessionID"] = session.sessionID
        record["captureType"] = session.captureType
        record["flashEnabled"] = session.flashEnabled ? 1 : 0
        record["ingredientsDetected"] = session.ingredientsDetected
        record["recipesGenerated"] = session.recipesGenerated
        record["aiModel"] = session.aiModel
        record["processingTime"] = session.processingTime
        record["timestamp"] = Date()

        // Fire and forget
        Task {
            guard let privateDB = try? requirePrivateDB(for: "trackCameraSession") else { return }
            let logger = CloudKitDebugLogger.shared
            let startTime = Date()
            logger.logSaveStart(recordType: "CameraSession", database: privateDB.debugName)
            
            do {
                _ = try await privateDB.save(record)
                let duration = Date().timeIntervalSince(startTime)
                logger.logSaveSuccess(recordType: "CameraSession", recordID: record.recordID.recordName, database: privateDB.debugName, duration: duration)
                print("📸 Camera session tracked")
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                logger.logSaveFailure(recordType: "CameraSession", database: privateDB.debugName, error: error, duration: duration)
                print("Failed to track camera session: \(error)")
            }
        }
    }

    // MARK: - Recipe Generation Tracking

    func trackRecipeGeneration(_ data: RecipeGenerationData) async {
        guard let userID = getCurrentUserID() else { return }

        let record = CKRecord(recordType: "RecipeGeneration")
        record["userID"] = userID
        record["sessionID"] = data.sessionID
        record["recipeData"] = try? JSONEncoder().encode(data.recipe).base64EncodedString()
        record["ingredients"] = data.ingredients
        record["preferences"] = data.preferencesJSON
        record["generationTime"] = data.generationTime
        record["quality"] = data.quality
        record["timestamp"] = Date()

        Task {
            guard let privateDB = try? requirePrivateDB(for: "trackRecipeGeneration") else { return }
            let logger = CloudKitDebugLogger.shared
            let startTime = Date()
            logger.logSaveStart(recordType: "RecipeGeneration", database: privateDB.debugName)
            
            do {
                _ = try await privateDB.save(record)
                let duration = Date().timeIntervalSince(startTime)
                logger.logSaveSuccess(recordType: "RecipeGeneration", recordID: record.recordID.recordName, database: privateDB.debugName, duration: duration)
                print("🍳 Recipe generation tracked")
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                logger.logSaveFailure(recordType: "RecipeGeneration", database: privateDB.debugName, error: error, duration: duration)
                print("Failed to track recipe generation: \(error)")
            }
        }
    }

    // MARK: - App Session Tracking

    func startAppSession() -> String {
        let sessionID = UUID().uuidString
        UserDefaults.standard.set(sessionID, forKey: "currentSessionID")
        UserDefaults.standard.set(Date(), forKey: "sessionStartTime")
        UserDefaults.standard.set([String](), forKey: "sessionScreens")
        UserDefaults.standard.set([String](), forKey: "sessionFeatures")
        return sessionID
    }

    func endAppSession() async {
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else { return }
        guard let userID = getCurrentUserID(),
              let sessionID = UserDefaults.standard.string(forKey: "currentSessionID"),
              let startTime = UserDefaults.standard.object(forKey: "sessionStartTime") as? Date else { return }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let screens = UserDefaults.standard.stringArray(forKey: "sessionScreens") ?? []
        let features = UserDefaults.standard.stringArray(forKey: "sessionFeatures") ?? []

        let record = CKRecord(recordType: "AppSession")
        record["userID"] = userID
        record["sessionID"] = sessionID
        record["startTime"] = startTime
        record["endTime"] = endTime
        record["duration"] = duration
        record["screensViewed"] = screens
        record["featuresUsed"] = features
        record["recipesCreated"] = UserDefaults.standard.integer(forKey: "sessionRecipesCreated")
        record["challengesJoined"] = UserDefaults.standard.integer(forKey: "sessionChallengesJoined")
        record["deviceInfo"] = getDeviceInfo()
        record["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        Task {
            guard let privateDB = try? requirePrivateDB(for: "endAppSession") else { return }
            let logger = CloudKitDebugLogger.shared
            let startTime = Date()
            logger.logSaveStart(recordType: "AppSession", database: privateDB.debugName)
            
            do {
                _ = try await privateDB.save(record)
                let logDuration = Date().timeIntervalSince(startTime)
                logger.logSaveSuccess(recordType: "AppSession", recordID: record.recordID.recordName, database: privateDB.debugName, duration: logDuration)
                print("📱 App session tracked: \(duration)s")
            } catch {
                let logDuration = Date().timeIntervalSince(startTime)
                logger.logSaveFailure(recordType: "AppSession", database: privateDB.debugName, error: error, duration: logDuration)
                print("Failed to track app session: \(error)")
            }
        }

        // Clear session data
        UserDefaults.standard.removeObject(forKey: "currentSessionID")
        UserDefaults.standard.removeObject(forKey: "sessionStartTime")
    }

    func trackScreenView(_ screen: String) {
        var screens = UserDefaults.standard.stringArray(forKey: "sessionScreens") ?? []
        if !screens.contains(screen) {
            screens.append(screen)
            UserDefaults.standard.set(screens, forKey: "sessionScreens")
        }
    }

    func trackFeatureUse(_ feature: String) {
        var features = UserDefaults.standard.stringArray(forKey: "sessionFeatures") ?? []
        if !features.contains(feature) {
            features.append(feature)
            UserDefaults.standard.set(features, forKey: "sessionFeatures")
        }
    }

    // MARK: - Search History

    func trackSearch(_ query: String, type: String, results: Int) async {
        guard let userID = getCurrentUserID() else { return }

        let record = CKRecord(recordType: "SearchHistory")
        record["userID"] = userID
        record["searchQuery"] = query
        record["searchType"] = type
        record["resultsCount"] = results
        record["timestamp"] = Date()

        Task {
            guard let privateDB = try? requirePrivateDB(for: "trackSearch") else { return }
            let logger = CloudKitDebugLogger.shared
            let startTime = Date()
            logger.logSaveStart(recordType: "SearchHistory", database: privateDB.debugName)
            
            do {
                _ = try await privateDB.save(record)
                let duration = Date().timeIntervalSince(startTime)
                logger.logSaveSuccess(recordType: "SearchHistory", recordID: record.recordID.recordName, database: privateDB.debugName, duration: duration)
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                logger.logSaveFailure(recordType: "SearchHistory", database: privateDB.debugName, error: error, duration: duration)
                print("Failed to track search: \(error)")
            }
        }
    }

    // MARK: - Error Logging

    func logError(_ error: CloudKitAppError) async {
        guard let userID = getCurrentUserID() else { return }

        let record = CKRecord(recordType: "ErrorLog")
        record["userID"] = userID
        record["errorType"] = error.type
        record["errorMessage"] = error.message
        record["stackTrace"] = error.stackTrace
        record["context"] = error.context
        record["severity"] = error.severity
        record["timestamp"] = Date()
        record["resolved"] = 0

        Task {
            guard let privateDB = try? requirePrivateDB(for: "logError") else { return }
            let logger = CloudKitDebugLogger.shared
            let startTime = Date()
            logger.logSaveStart(recordType: "ErrorLog", database: privateDB.debugName)
            
            do {
                _ = try await privateDB.save(record)
                let duration = Date().timeIntervalSince(startTime)
                logger.logSaveSuccess(recordType: "ErrorLog", recordID: record.recordID.recordName, database: privateDB.debugName, duration: duration)
                print("🚨 Error logged: \(error.type)")
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                logger.logSaveFailure(recordType: "ErrorLog", database: privateDB.debugName, error: error, duration: duration)
                print("Failed to log error: \(error)")
            }
        }
    }

    // MARK: - Device Sync

    func registerDevice() async throws {
        guard let userID = getCurrentUserID() else { return }
        let privateDB = try requirePrivateDB(for: "registerDevice")

        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        let record = CKRecord(recordType: "DeviceSync")
        record["userID"] = userID
        record["deviceID"] = deviceID
        record["deviceName"] = UIDevice.current.name
        record["deviceType"] = UIDevice.current.model
        record["osVersion"] = UIDevice.current.systemVersion
        record["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        record["lastSync"] = Date()

        let logger = CloudKitDebugLogger.shared
        let startTime = Date()
        logger.logSaveStart(recordType: "DeviceSync", database: privateDB.debugName)
        
        do {
            _ = try await privateDB.save(record)
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveSuccess(recordType: "DeviceSync", recordID: record.recordID.recordName, database: privateDB.debugName, duration: duration)
            print("📱 Device registered: \(deviceID)")
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logSaveFailure(recordType: "DeviceSync", database: privateDB.debugName, error: error, duration: duration)
            throw error
        }
    }

    // MARK: - Real-time Subscriptions

    func ensureSubscriptionsConfigured() async {
        guard let userID = getCurrentUserID(), !userID.isEmpty else {
            return
        }

        let setupKey = "\(subscriptionSetupKeyPrefix)\(userID)"
        if userDefaults.bool(forKey: setupKey) {
            return
        }

        let status = await cloudKitAccountStatus()
        guard status == .available else {
            print("⏭️ Skipping CloudKit subscription setup - account unavailable (\(status.rawValue))")
            return
        }

        let didSucceed = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            setupSubscriptions(for: userID) { success in
                continuation.resume(returning: success)
            }
        }

        if didSucceed {
            userDefaults.set(true, forKey: setupKey)
        }
    }

    private func cloudKitAccountStatus() async -> CKAccountStatus {
        guard let container else {
            return .couldNotDetermine
        }
        return await withCheckedContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    print("⚠️ CloudKit account status check failed: \(error)")
                }
                continuation.resume(returning: status)
            }
        }
    }

    private func setupSubscriptions(for userID: String, completion: @escaping @Sendable (Bool) -> Void) {
        guard let privateDB = try? requirePrivateDB(for: "setupSubscriptions") else {
            completion(false)
            return
        }
        // Subscribe to preference changes
        let preferencePredicate = NSPredicate(format: "userID == %@", userID)
        let preferenceSubscription = CKQuerySubscription(
            recordType: "FoodPreference",
            predicate: preferencePredicate,
            subscriptionID: "preference-updates-subscription",
            options: [.firesOnRecordUpdate, .firesOnRecordCreation]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        preferenceSubscription.notificationInfo = notificationInfo

        let privateDatabaseName = privateDB.debugName
        privateDB.save(preferenceSubscription) { subscription, error in
            let logger = CloudKitDebugLogger.shared
            if let error = error {
                logger.logSubscriptionFailed(
                    subscriptionID: "preference-updates-subscription",
                    recordType: "FoodPreference",
                    database: privateDatabaseName,
                    error: error
                )
                print("Failed to setup subscription: \(error)")
                completion(false)
            } else {
                logger.logSubscriptionCreated(
                    subscriptionID: "preference-updates-subscription",
                    recordType: "FoodPreference",
                    database: privateDatabaseName
                )
                print("✅ Subscribed to preference updates")
                completion(true)
            }
        }
    }

    // MARK: - Manual Sync (Only when needed)

    /// Trigger manual sync - should only be called when:
    /// - User visits RecipeBookView
    /// - User pulls to refresh
    /// - User explicitly saves a new recipe
    func triggerManualSync() async {
        await performFullSync()
    }

    func performFullSync() async {
        isSyncing = true

        do {
            // Sync preferences
            try await syncUserPreferences()
            _ = try await fetchUserPreferences()

            // Register device
            try await registerDevice()

            lastSyncDate = Date()
            print("✅ Manual sync completed")
        } catch {
            syncErrors.append("Sync failed: \(error.localizedDescription)")
        }

        isSyncing = false
    }

    // MARK: - Helper Methods

    private func getCurrentUserID() -> String? {
        return UserDefaults.standard.string(forKey: "currentUserID")
    }

    private func getDeviceInfo() -> String {
        return "\(UIDevice.current.model) - iOS \(UIDevice.current.systemVersion)"
    }

    private func loadLocalPreferences() -> FoodPreferences {
        // Load from UserDefaults
        return FoodPreferences(
            dietaryRestrictions: UserDefaults.standard.stringArray(forKey: "dietaryRestrictions") ?? [],
            allergies: UserDefaults.standard.stringArray(forKey: "allergies") ?? [],
            favoriteCuisines: UserDefaults.standard.stringArray(forKey: "favoriteCuisines") ?? [],
            dislikedIngredients: UserDefaults.standard.stringArray(forKey: "dislikedIngredients") ?? [],
            cookingSkillLevel: UserDefaults.standard.string(forKey: "cookingSkillLevel") ?? "intermediate",
            preferredCookTime: UserDefaults.standard.integer(forKey: "preferredCookTime"),
            kitchenTools: UserDefaults.standard.stringArray(forKey: "kitchenTools") ?? [],
            mealPlanningGoals: UserDefaults.standard.string(forKey: "mealPlanningGoals") ?? ""
        )
    }

    private func saveLocalPreferences(_ preferences: FoodPreferences) {
        UserDefaults.standard.set(preferences.dietaryRestrictions, forKey: "dietaryRestrictions")
        UserDefaults.standard.set(preferences.allergies, forKey: "allergies")
        UserDefaults.standard.set(preferences.favoriteCuisines, forKey: "favoriteCuisines")
        UserDefaults.standard.set(preferences.dislikedIngredients, forKey: "dislikedIngredients")
        UserDefaults.standard.set(preferences.cookingSkillLevel, forKey: "cookingSkillLevel")
        UserDefaults.standard.set(preferences.preferredCookTime, forKey: "preferredCookTime")
        UserDefaults.standard.set(preferences.kitchenTools, forKey: "kitchenTools")
        UserDefaults.standard.set(preferences.mealPlanningGoals, forKey: "mealPlanningGoals")
    }
    
    // MARK: - CloudKit Retry Helpers
    
    /// Retry helper for CloudKit record saves
    private func saveRecordWithRetry(record: CKRecord, database: CKDatabase, maxRetries: Int) async throws {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                _ = try await database.save(record)
                if attempt > 0 {
                    print("✅ CloudKit data save succeeded on attempt \(attempt + 1)")
                }
                return
            } catch let error as CKError {
                lastError = error
                
                // Don't retry on certain errors
                switch error.code {
                case .notAuthenticated, .permissionFailure, .quotaExceeded:
                    throw error
                case .zoneBusy, .serviceUnavailable, .requestRateLimited:
                    // These are retryable
                    if attempt < maxRetries - 1 {
                        let delay = calculateDataBackoffDelay(attempt: attempt)
                        print("⏳ CloudKit data save failed (attempt \(attempt + 1)), retrying in \(delay)s: \(error.localizedDescription)")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    throw error
                default:
                    // For other errors, retry once
                    if attempt < maxRetries - 1 {
                        let delay = calculateDataBackoffDelay(attempt: attempt)
                        print("⏳ CloudKit data save error (attempt \(attempt + 1)), retrying in \(delay)s: \(error.localizedDescription)")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    throw error
                }
            } catch {
                lastError = error
                // Non-CloudKit errors generally shouldn't be retried
                throw error
            }
        }
        
        throw lastError ?? SnapChefError.syncError("CloudKit data save failed after all retries")
    }
    
    /// Retry helper for CloudKit record fetches
    private func fetchRecordsWithRetry(query: CKQuery, database: CKDatabase, maxRetries: Int) async throws -> (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?) {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let result = try await database.records(matching: query)
                if attempt > 0 {
                    print("✅ CloudKit data fetch succeeded on attempt \(attempt + 1)")
                }
                return result
            } catch let error as CKError {
                lastError = error
                
                // Don't retry on certain errors
                switch error.code {
                case .notAuthenticated, .permissionFailure:
                    throw error
                case .zoneBusy, .serviceUnavailable, .requestRateLimited, .networkFailure:
                    // These are retryable
                    if attempt < maxRetries - 1 {
                        let delay = calculateDataBackoffDelay(attempt: attempt)
                        print("⏳ CloudKit data fetch failed (attempt \(attempt + 1)), retrying in \(delay)s: \(error.localizedDescription)")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    throw error
                default:
                    throw error
                }
            } catch {
                lastError = error
                throw error
            }
        }
        
        throw lastError ?? SnapChefError.syncError("CloudKit data fetch failed after all retries")
    }
    
    /// Calculate exponential backoff delay for data operations
    private func calculateDataBackoffDelay(attempt: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 0.5
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0.1...0.2) * exponentialDelay
        let maxDelay: TimeInterval = 8.0 // Cap at 8 seconds for data operations
        return min(exponentialDelay + jitter, maxDelay)
    }
}

// MARK: - Data Models

struct FoodPreferences: Codable {
    var dietaryRestrictions: [String]
    var allergies: [String]
    var favoriteCuisines: [String]
    var dislikedIngredients: [String]
    var cookingSkillLevel: String
    var preferredCookTime: Int
    var kitchenTools: [String]
    var mealPlanningGoals: String
}

struct CameraSessionData {
    let sessionID: String
    let captureType: String
    let flashEnabled: Bool
    let ingredientsDetected: [String]
    let recipesGenerated: Int
    let aiModel: String
    let processingTime: Double
}

struct RecipeGenerationData {
    let sessionID: String
    let recipe: Recipe
    let ingredients: [String]
    let preferencesJSON: String
    let generationTime: Double
    let quality: String
}

struct CloudKitAppError {
    let type: String
    let message: String
    let stackTrace: String?
    let context: String?
    let severity: String
}

// MARK: - Data Cache

private class DataCache {
    var preferences: FoodPreferences?
    var recentSearches: [String] = []
    var errorLogs: [CloudKitAppError] = []

    func clear() {
        preferences = nil
        recentSearches.removeAll()
        errorLogs.removeAll()
    }
}
