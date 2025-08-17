import Foundation
import CloudKit

/// Lightweight analytics tracking for CloudKit
/// Only tracks high-value, low-storage events
class CloudKitAnalytics {
    static let shared = CloudKitAnalytics()
    private let container = CKContainer(identifier: "iCloud.com.snapchefapp.app")
    private let database = CKContainer(identifier: "iCloud.com.snapchefapp.app").publicCloudDatabase

    // Batch events to reduce API calls
    private var eventQueue: [AnalyticsEvent] = []
    private let batchSize = 20
    private var batchTimer: Timer?

    private init() {
        setupBatchTimer()
    }

    // MARK: - Navigation Tracking (Lightweight)

    func trackScreenView(_ screenName: String) {
        // Only track main screens, not every view
        let mainScreens = ["Home", "Camera", "Recipes", "Feed", "Profile", "ChallengeHub"]
        guard mainScreens.contains(screenName) else { return }

        let event = AnalyticsEvent(
            eventType: "screen_view",
            eventName: screenName,
            timestamp: Date()
        )
        queueEvent(event)
    }

    // MARK: - Feature Usage Tracking

    func trackFeatureUsage(_ feature: String, details: [String: Any]? = nil) {
        // Track important feature usage
        let importantFeatures = [
            "recipe_generated",
            "challenge_joined",
            "recipe_shared",
            "achievement_earned",
            "premium_feature_used"
        ]

        guard importantFeatures.contains(feature) else { return }

        let event = AnalyticsEvent(
            eventType: "feature_usage",
            eventName: feature,
            eventData: details,
            timestamp: Date()
        )
        queueEvent(event)
    }

    // MARK: - User Preferences Sync

    func syncUserPreferences(_ preferences: UserPreferences) async throws {
        guard let userID = UserDefaults.standard.string(forKey: "currentUserID") else { return }

        let record = CKRecord(recordType: "UserPreferences")
        record["userID"] = userID
        record["dietaryRestrictions"] = preferences.dietaryRestrictions
        record["cuisinePreferences"] = preferences.cuisinePreferences
        record["difficultyPreference"] = preferences.difficultyPreference
        record["cookingTimePreference"] = preferences.cookingTimePreference
        record["aiModelPreference"] = preferences.aiModelPreference
        record["notificationSettings"] = preferences.notificationSettings
        record["themePreference"] = preferences.themePreference
        record["lastUpdated"] = Date()

        do {
            _ = try await database.save(record)
            print("✅ User preferences synced to CloudKit")
        } catch {
            print("❌ Failed to sync preferences: \(error)")
            throw error
        }
    }

    func fetchUserPreferences() async throws -> UserPreferences? {
        guard let userID = UserDefaults.standard.string(forKey: "currentUserID") else { return nil }

        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "UserPreferences", predicate: predicate)

        do {
            let results = try await database.records(matching: query)
            guard let record = results.matchResults.first?.0,
                  let fetchedRecord = try? results.matchResults.first?.1.get() else {
                return nil
            }

            return UserPreferences(from: fetchedRecord)
        } catch {
            print("❌ Failed to fetch preferences: \(error)")
            throw error
        }
    }

    // MARK: - Social Share Tracking

    func trackSocialShare(platform: String, contentType: String, contentID: String?) async {
        let record = CKRecord(recordType: "SocialShare")
        record["userID"] = UserDefaults.standard.string(forKey: "currentUserID") ?? "anonymous"
        record["platform"] = platform
        record["contentType"] = contentType
        record["contentID"] = contentID
        record["sharedAt"] = Date()

        // Fire and forget - don't wait for response
        Task {
            do {
                _ = try await database.save(record)
                print("📊 Social share tracked: \(platform)")
            } catch {
                print("Failed to track share: \(error)")
            }
        }
    }

    // MARK: - Batch Processing

    private func queueEvent(_ event: AnalyticsEvent) {
        eventQueue.append(event)

        // Send immediately if batch is full
        if eventQueue.count >= batchSize {
            Task {
                await sendBatch()
            }
        }
    }

    private func setupBatchTimer() {
        // Send events every 30 seconds if any are queued
        batchTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            if !self.eventQueue.isEmpty {
                Task {
                    await self.sendBatch()
                }
            }
        }
    }

    private func sendBatch() async {
        guard !eventQueue.isEmpty else { return }

        let eventsToSend = eventQueue
        eventQueue.removeAll()

        // Create records for batch save
        let records = eventsToSend.map { event in
            let record = CKRecord(recordType: "AnalyticsEvent")
            record["userID"] = UserDefaults.standard.string(forKey: "currentUserID") ?? "anonymous"
            record["eventType"] = event.eventType
            record["eventName"] = event.eventName
            record["eventData"] = event.eventData?.jsonString
            record["timestamp"] = event.timestamp
            record["sessionID"] = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            record["platform"] = "iOS"
            record["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            return record
        }

        // Batch save
        do {
            let operation = CKModifyRecordsOperation(recordsToSave: records)
            operation.savePolicy = .allKeys
            operation.qualityOfService = .background

            database.add(operation)
            print("📊 Sent \(records.count) analytics events")
        } catch {
            print("Failed to send analytics batch: \(error)")
        }
    }
}

// MARK: - Models

struct AnalyticsEvent {
    let eventType: String
    let eventName: String
    var eventData: [String: Any]?
    let timestamp: Date
}

struct UserPreferences: Codable {
    var dietaryRestrictions: [String] = []
    var cuisinePreferences: [String] = []
    var difficultyPreference: String = "medium"
    var cookingTimePreference: String = "30 mins"
    var aiModelPreference: String = "gpt-4"
    var notificationSettings: String = "all"
    var themePreference: String = "auto"

    init() {}

    init(from record: CKRecord) {
        self.dietaryRestrictions = record["dietaryRestrictions"] as? [String] ?? []
        self.cuisinePreferences = record["cuisinePreferences"] as? [String] ?? []
        self.difficultyPreference = record["difficultyPreference"] as? String ?? "medium"
        self.cookingTimePreference = record["cookingTimePreference"] as? String ?? "30 mins"
        self.aiModelPreference = record["aiModelPreference"] as? String ?? "gpt-4"
        self.notificationSettings = record["notificationSettings"] as? String ?? "all"
        self.themePreference = record["themePreference"] as? String ?? "auto"
    }
}

// MARK: - Extensions

extension Dictionary where Key == String, Value == Any {
    var jsonString: String? {
        guard let data = try? JSONSerialization.data(withJSONObject: self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}
