import Foundation
import CloudKit
import SwiftUI
import Combine
import UIKit

/// Data module for CloudKit operations
/// Handles app analytics, preferences, and data sync
@MainActor
final class DataModule: ObservableObject {
    
    // MARK: - Properties
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private weak var parent: CloudKitService?
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [String] = []
    
    private var dataCache = DataCache()
    
    // MARK: - Initialization
    init(container: CKContainer, publicDB: CKDatabase, privateDB: CKDatabase, parent: CloudKitService) {
        self.container = container
        self.publicDatabase = publicDB
        self.privateDatabase = privateDB
        self.parent = parent
    }
    
    // MARK: - User Preferences Sync
    func syncUserPreferences() async throws {
        guard let userID = getCurrentUserID() else { return }
        
        let preferences = loadLocalPreferences()
        
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
            _ = try await privateDatabase.save(record)
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
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            
            // Get the first (most recent) match
            guard let firstResult = matchResults.first,
                  let record = try? firstResult.1.get() else { return nil }
            
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
            
            saveLocalPreferences(preferences)
            return preferences
        } catch {
            print("❌ Failed to fetch preferences: \(error)")
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
        
        Task {
            do {
                _ = try await privateDatabase.save(record)
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
        record["preferencesJSON"] = data.preferencesJSON
        record["generationTime"] = data.generationTime
        record["quality"] = data.quality
        record["timestamp"] = Date()
        
        Task {
            do {
                _ = try await privateDatabase.save(record)
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
                _ = try await privateDatabase.save(record)
                print("📱 App session tracked: \(duration)s")
            } catch {
                print("Failed to track app session: \(error)")
            }
        }
        
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
                _ = try await privateDatabase.save(record)
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
                _ = try await privateDatabase.save(record)
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
            _ = try await privateDatabase.save(record)
            print("📱 Device registered: \(deviceID)")
        } catch {
            throw error
        }
    }
    
    // MARK: - Manual Sync
    func triggerManualSync() async {
        await performFullSync()
    }
    
    func performFullSync() async {
        isSyncing = true
        
        do {
            try await syncUserPreferences()
            _ = try await fetchUserPreferences()
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
        // Try both keys for compatibility
        if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
            return userID
        }
        return UserDefaults.standard.string(forKey: "currentUserRecordID")
    }
    
    private func getDeviceInfo() -> String {
        return "\(UIDevice.current.model) - iOS \(UIDevice.current.systemVersion)"
    }
    
    private func loadLocalPreferences() -> FoodPreferences {
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