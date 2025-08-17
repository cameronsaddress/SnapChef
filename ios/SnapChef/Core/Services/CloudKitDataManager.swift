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

    private let container = CKContainer(identifier: "iCloud.com.snapchefapp.app")
    private let publicDB: CKDatabase
    private let privateDB: CKDatabase

    // Published properties for dynamic UI updates
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [String] = []

    // Cache for offline access
    private var dataCache = DataCache()
    private var syncQueue = DispatchQueue(label: "com.snapchef.cloudkit.sync", qos: .background)

    private init() {
        self.publicDB = container.publicCloudDatabase
        self.privateDB = container.privateCloudDatabase
        setupSubscriptions()
        // Removed automatic periodic sync - only sync when needed
    }

    // MARK: - User Preferences Sync

    func syncUserPreferences() async throws {
        guard let userID = getCurrentUserID() else { return }

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

        do {
            _ = try await privateDB.save(record)
            print("✅ Preferences synced to CloudKit")
        } catch {
            syncErrors.append("Failed to sync preferences: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchUserPreferences() async throws -> FoodPreferences? {
        guard let userID = getCurrentUserID() else { return nil }

        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "FoodPreference", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "lastUpdated", ascending: false)]

        do {
            let (matchResults, _) = try await privateDB.records(matching: query)
            guard let recordResult = matchResults.first?.1,
                  let record = try? recordResult.get() else { return nil }

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
        } catch {
            print("❌ Failed to fetch preferences: \(error)")
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
            do {
                _ = try await privateDB.save(record)
                print("📸 Camera session tracked")
            } catch {
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
            do {
                _ = try await privateDB.save(record)
                print("🍳 Recipe generation tracked")
            } catch {
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
            do {
                _ = try await privateDB.save(record)
                print("📱 App session tracked: \(duration)s")
            } catch {
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
            do {
                _ = try await privateDB.save(record)
            } catch {
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
            do {
                _ = try await privateDB.save(record)
                print("🚨 Error logged: \(error.type)")
            } catch {
                print("Failed to log error: \(error)")
            }
        }
    }

    // MARK: - Device Sync

    func registerDevice() async throws {
        guard let userID = getCurrentUserID() else { return }

        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        let record = CKRecord(recordType: "DeviceSync")
        record["userID"] = userID
        record["deviceID"] = deviceID
        record["deviceName"] = UIDevice.current.name
        record["deviceType"] = UIDevice.current.model
        record["osVersion"] = UIDevice.current.systemVersion
        record["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        record["lastSync"] = Date()

        do {
            _ = try await privateDB.save(record)
            print("📱 Device registered: \(deviceID)")
        } catch {
            throw error
        }
    }

    // MARK: - Real-time Subscriptions

    private func setupSubscriptions() {
        // Subscribe to preference changes
        let preferencePredicate = NSPredicate(format: "userID == %@", getCurrentUserID() ?? "")
        let preferenceSubscription = CKQuerySubscription(
            recordType: "FoodPreference",
            predicate: preferencePredicate,
            options: [.firesOnRecordUpdate, .firesOnRecordCreation]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        preferenceSubscription.notificationInfo = notificationInfo

        privateDB.save(preferenceSubscription) { _, error in
            if let error = error {
                print("Failed to setup subscription: \(error)")
            } else {
                print("✅ Subscribed to preference updates")
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
