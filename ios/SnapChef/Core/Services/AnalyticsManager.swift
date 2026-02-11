import Foundation
import CloudKit

@MainActor
class AnalyticsManager {
    static let shared = AnalyticsManager()

    private let highSignalEvents: Set<String> = [
        "waiting_game_shown",
        "waiting_game_manual_start",
        "waiting_game_auto_start",
        "waiting_game_dismissed",
        "viral_prompt_shown",
        "viral_cta_tapped",
        "viral_share_completed_external",
        "referral_attributed_open",
        "referral_attributed_conversion"
    ]

    private init() {}

    func initialize() {
        #if DEBUG
        print("Analytics initialized in debug mode")
        #else
        // Initialize Firebase Analytics or other analytics service
        // FirebaseApp.configure()
        #endif
    }

    func logEvent(_ event: String, parameters: [String: Any]? = nil) {
        #if DEBUG
        print("Analytics Event: \(event)")
        if let parameters = parameters {
            print("Parameters: \(parameters)")
        }
        #endif

        // Route high-signal events into session-level CloudKit analytics.
        if highSignalEvents.contains(event) {
            CloudKitDataManager.shared.trackFeatureUse(event)
        }

        #if !DEBUG
        // Log to analytics service
        // Analytics.logEvent(event, parameters: parameters)
        #endif
    }

    func setUserProperty(_ value: String?, forName name: String) {
        #if DEBUG
        print("Analytics User Property: \(name) = \(value ?? "nil")")
        #else
        // Set user property in analytics service
        // Analytics.setUserProperty(value, forName: name)
        #endif
    }

    func logScreen(_ screenName: String, screenClass: String? = nil) {
        #if DEBUG
        print("Analytics Screen View: \(screenName)")
        #else
        // Log screen view
        // Analytics.logEvent(AnalyticsEventScreenView, parameters: [
        //     AnalyticsParameterScreenName: screenName,
        //     AnalyticsParameterScreenClass: screenClass ?? screenName
        // ])
        #endif
    }
}

/// Remote-tunable growth configuration and stable A/B assignment.
/// Values default to safe production behavior and can be overridden via UserDefaults.
final class GrowthRemoteConfig: @unchecked Sendable {
    static let shared = GrowthRemoteConfig()

    enum ExperimentGroup: String, CaseIterable {
        case control
        case speed
        case cinematic
    }

    struct Diagnostics {
        let experimentGroup: ExperimentGroup
        let waitingVariantOverride: String?
        let source: String
        let hasCachedPayload: Bool
        let lastFetchAttempt: Date?
        let lastSuccessfulFetch: Date?
        let lastFetchError: String?
    }

    private enum Keys {
        static let experimentGroup = "growth_experiment_group"
        static let remotePayloadJSON = "growth_remote_config_payload_json"
        static let activeConfigSource = "growth_remote_config_active_source"
        static let lastFetchAttempt = "growth_remote_config_last_fetch_attempt"
        static let lastFetchSuccess = "growth_remote_config_last_fetch_success"
        static let lastFetchError = "growth_remote_config_last_fetch_error"

        static let waitingVariantOverride = "growth_waiting_game_variant_override"
        static let waitingSingleThreshold = "growth_waiting_game_single_threshold"
        static let waitingDualThreshold = "growth_waiting_game_dual_threshold"
        static let waitingDelayMultiplier = "growth_waiting_game_delay_multiplier"
        static let waitingAdaptiveBlend = "growth_waiting_game_adaptive_blend"

        static let cameraMotionMultiplier = "growth_camera_motion_multiplier"
        static let cameraScanCycleBaseDuration = "growth_camera_scan_cycle_base_duration"
    }

    private let userDefaults = UserDefaults.standard

    private init() {}

    func bootstrap() {
        _ = experimentGroup
        if userDefaults.string(forKey: Keys.activeConfigSource) == nil {
            userDefaults.set("defaults", forKey: Keys.activeConfigSource)
        }
        let appliedCachedPayload = applyPayloadOverridesIfPresent()
        if appliedCachedPayload, userDefaults.string(forKey: Keys.activeConfigSource) == "defaults" {
            userDefaults.set("cached_payload", forKey: Keys.activeConfigSource)
        }
    }

    func refreshFromCloudKit() async {
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            userDefaults.set(Date(), forKey: Keys.lastFetchAttempt)
            userDefaults.set("CloudKit entitlement unavailable in runtime build", forKey: Keys.lastFetchError)
            return
        }

        userDefaults.set(Date(), forKey: Keys.lastFetchAttempt)

        let publicDatabase = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase
        let candidateRecordIDs = [
            CKRecord.ID(recordName: "growth_remote_config"),
            CKRecord.ID(recordName: "growth-config"),
            CKRecord.ID(recordName: "snapchef_growth_config")
        ]
        var failureNotes: [String] = []

        for recordID in candidateRecordIDs {
            do {
                let record = try await publicDatabase.record(for: recordID)
                ingest(record: record, sourceRecordID: recordID.recordName)
                userDefaults.set(Date(), forKey: Keys.lastFetchSuccess)
                userDefaults.removeObject(forKey: Keys.lastFetchError)
                return
            } catch let ckError as CKError where ckError.code == .unknownItem {
                failureNotes.append("\(recordID.recordName): missing")
                continue
            } catch {
                failureNotes.append("\(recordID.recordName): \(error.localizedDescription)")
                #if DEBUG
                print("⚠️ Growth remote config fetch failed (\(recordID.recordName)): \(error)")
                #endif
                continue
            }
        }

        let fallbackMessage: String
        if failureNotes.isEmpty {
            fallbackMessage = "No growth config records found"
        } else {
            fallbackMessage = failureNotes.joined(separator: " | ")
        }
        userDefaults.set(fallbackMessage, forKey: Keys.lastFetchError)
    }

    var experimentGroup: ExperimentGroup {
        if let stored = userDefaults.string(forKey: Keys.experimentGroup),
           let existing = ExperimentGroup(rawValue: stored) {
            return existing
        }

        let random = ExperimentGroup.allCases.randomElement() ?? .control
        userDefaults.set(random.rawValue, forKey: Keys.experimentGroup)
        return random
    }

    var waitingGameVariantOverrideRawValue: String? {
        guard let raw = userDefaults.string(forKey: Keys.waitingVariantOverride)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !raw.isEmpty else {
            return nil
        }
        return raw
    }

    var waitingGameSinglePhotoThreshold: TimeInterval {
        let fallback: TimeInterval
        switch experimentGroup {
        case .control:
            fallback = 3.4
        case .speed:
            fallback = 3.0
        case .cinematic:
            fallback = 3.8
        }
        return boundedDouble(
            forKey: Keys.waitingSingleThreshold,
            fallback: fallback,
            range: 1.0...20.0
        )
    }

    var waitingGameDualPhotoThreshold: TimeInterval {
        let fallback: TimeInterval
        switch experimentGroup {
        case .control:
            fallback = 4.0
        case .speed:
            fallback = 3.6
        case .cinematic:
            fallback = 4.4
        }
        return boundedDouble(
            forKey: Keys.waitingDualThreshold,
            fallback: fallback,
            range: 1.0...25.0
        )
    }

    var waitingGameDelayMultiplier: Double {
        let fallback: Double
        switch experimentGroup {
        case .control:
            fallback = 1.0
        case .speed:
            fallback = 0.9
        case .cinematic:
            fallback = 1.12
        }
        return boundedDouble(
            forKey: Keys.waitingDelayMultiplier,
            fallback: fallback,
            range: 0.55...1.8
        )
    }

    /// Weight assigned to adaptive backend latency when blending with static variant bias.
    var waitingGameAdaptiveBlendWeight: Double {
        let fallback: Double
        switch experimentGroup {
        case .control:
            fallback = 0.7
        case .speed:
            fallback = 0.74
        case .cinematic:
            fallback = 0.64
        }
        return boundedDouble(
            forKey: Keys.waitingAdaptiveBlend,
            fallback: fallback,
            range: 0.0...1.0
        )
    }

    /// Camera-only multiplier used by MotionTuning.cameraSeconds(_:).
    var cameraMotionMultiplier: Double {
        let fallback: Double
        switch experimentGroup {
        case .control:
            fallback = 1.0
        case .speed:
            fallback = 0.9
        case .cinematic:
            fallback = 1.08
        }
        return boundedDouble(
            forKey: Keys.cameraMotionMultiplier,
            fallback: fallback,
            range: 0.55...1.8
        )
    }

    /// Base camera scan cycle duration before device-profile speed normalization.
    var cameraScanCycleBaseDuration: Double {
        let fallback: Double
        switch experimentGroup {
        case .control:
            fallback = 2.0
        case .speed:
            fallback = 1.7
        case .cinematic:
            fallback = 2.35
        }
        return boundedDouble(
            forKey: Keys.cameraScanCycleBaseDuration,
            fallback: fallback,
            range: 0.8...5.0
        )
    }

    var diagnostics: Diagnostics {
        Diagnostics(
            experimentGroup: experimentGroup,
            waitingVariantOverride: waitingGameVariantOverrideRawValue,
            source: userDefaults.string(forKey: Keys.activeConfigSource) ?? "defaults",
            hasCachedPayload: userDefaults.string(forKey: Keys.remotePayloadJSON)?.isEmpty == false,
            lastFetchAttempt: userDefaults.object(forKey: Keys.lastFetchAttempt) as? Date,
            lastSuccessfulFetch: userDefaults.object(forKey: Keys.lastFetchSuccess) as? Date,
            lastFetchError: userDefaults.string(forKey: Keys.lastFetchError)
        )
    }

    /// Applies whitelisted remote values. Intended for future server-delivered configs.
    func apply(overrides: [String: Any]) {
        let allowedKeys: Set<String> = [
            Keys.experimentGroup,
            Keys.waitingVariantOverride,
            Keys.waitingSingleThreshold,
            Keys.waitingDualThreshold,
            Keys.waitingDelayMultiplier,
            Keys.waitingAdaptiveBlend,
            Keys.cameraMotionMultiplier,
            Keys.cameraScanCycleBaseDuration
        ]

        for (key, value) in overrides where allowedKeys.contains(key) {
            if let stringValue = value as? String {
                userDefaults.set(stringValue, forKey: key)
            } else if let intValue = value as? Int {
                userDefaults.set(Double(intValue), forKey: key)
            } else if let doubleValue = value as? Double {
                userDefaults.set(doubleValue, forKey: key)
            } else if let floatValue = value as? Float {
                userDefaults.set(Double(floatValue), forKey: key)
            } else if let boolValue = value as? Bool {
                userDefaults.set(boolValue, forKey: key)
            }
        }
    }

    @discardableResult
    private func applyPayloadOverridesIfPresent() -> Bool {
        guard let payload = userDefaults.string(forKey: Keys.remotePayloadJSON),
              let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        apply(overrides: json)
        return true
    }

    private func ingest(record: CKRecord, sourceRecordID: String) {
        var overrides: [String: Any] = [:]
        let allKeys = Set(record.allKeys())
        let directKeys: [String] = [
            Keys.experimentGroup,
            Keys.waitingVariantOverride,
            Keys.waitingSingleThreshold,
            Keys.waitingDualThreshold,
            Keys.waitingDelayMultiplier,
            Keys.waitingAdaptiveBlend,
            Keys.cameraMotionMultiplier,
            Keys.cameraScanCycleBaseDuration
        ]

        for key in directKeys where allKeys.contains(key) {
            if let value = record[key] {
                overrides[key] = value
            }
        }

        let payloadLoaded: Bool
        if let payload = payloadString(from: record) {
            userDefaults.set(payload, forKey: Keys.remotePayloadJSON)
            payloadLoaded = true
        } else {
            payloadLoaded = false
        }

        if !overrides.isEmpty {
            apply(overrides: overrides)
        }
        let appliedPayload = applyPayloadOverridesIfPresent()
        if payloadLoaded || appliedPayload {
            userDefaults.set("cloudkit_payload:\(sourceRecordID)", forKey: Keys.activeConfigSource)
        } else if !overrides.isEmpty {
            userDefaults.set("cloudkit_fields:\(sourceRecordID)", forKey: Keys.activeConfigSource)
        } else {
            userDefaults.set("cloudkit_empty:\(sourceRecordID)", forKey: Keys.activeConfigSource)
        }
    }

    private func payloadString(from record: CKRecord) -> String? {
        let payloadCandidates = [
            Keys.remotePayloadJSON,
            "growthPayloadJSON",
            "payloadJSON",
            "payload"
        ]

        for key in payloadCandidates {
            if let payload = record[key] as? String, !payload.isEmpty {
                return payload
            }
        }

        return nil
    }

    private func boundedDouble(
        forKey key: String,
        fallback: Double,
        range: ClosedRange<Double>
    ) -> Double {
        guard let number = userDefaults.object(forKey: key) as? NSNumber else {
            return fallback
        }
        return min(max(number.doubleValue, range.lowerBound), range.upperBound)
    }
}

/// Tracks growth-loop interactions used by waiting-game and viral prompts.
@MainActor
final class GrowthLoopManager {
    static let shared = GrowthLoopManager()

    enum WaitingGameVariant: String, CaseIterable {
        case quick
        case balanced
        case immersive

        var autoStartDelay: TimeInterval {
            switch self {
            case .quick:
                return 2.5
            case .balanced:
                return 4.0
            case .immersive:
                return 5.5
            }
        }
    }

    private enum Keys {
        static let waitingGameVariant = "growth_waiting_game_variant"
        static let recipeWaitLatencyEwma = "growth_recipe_wait_latency_ewma"
        static let recipeWaitLatencySamples = "growth_recipe_wait_latency_samples"
    }

    private let userDefaults = UserDefaults.standard
    private let remoteConfig = GrowthRemoteConfig.shared
    private let defaultRecipeWaitLatency: TimeInterval = 7.0
    private let latencyEwmaWeight = 0.35
    private let minLatencySample: TimeInterval = 0.8
    private let maxLatencySample: TimeInterval = 90.0
    private var recipeWaitStartedAt: Date?

    private init() {}

    var waitingGameVariant: WaitingGameVariant {
        if let override = remoteConfig.waitingGameVariantOverrideRawValue,
           let variant = WaitingGameVariant(rawValue: override) {
            return variant
        }

        if let stored = userDefaults.string(forKey: Keys.waitingGameVariant),
           let variant = WaitingGameVariant(rawValue: stored) {
            return variant
        }

        let assigned = WaitingGameVariant.allCases.randomElement() ?? .balanced
        userDefaults.set(assigned.rawValue, forKey: Keys.waitingGameVariant)
        return assigned
    }

    var estimatedRecipeWaitLatency: TimeInterval {
        let stored = userDefaults.double(forKey: Keys.recipeWaitLatencyEwma)
        return stored > 0 ? stored : defaultRecipeWaitLatency
    }

    var recipeWaitSampleCount: Int {
        userDefaults.integer(forKey: Keys.recipeWaitLatencySamples)
    }

    func markRecipeWaitStarted() {
        recipeWaitStartedAt = Date()
    }

    func markRecipeWaitFinished() {
        guard let startedAt = recipeWaitStartedAt else { return }
        recipeWaitStartedAt = nil
        let sample = Date().timeIntervalSince(startedAt)
        guard sample >= minLatencySample else { return }

        let clamped = min(max(sample, minLatencySample), maxLatencySample)
        let previous = userDefaults.double(forKey: Keys.recipeWaitLatencyEwma)
        let updated = previous > 0
            ? ((clamped * latencyEwmaWeight) + (previous * (1 - latencyEwmaWeight)))
            : clamped

        userDefaults.set(updated, forKey: Keys.recipeWaitLatencyEwma)
        userDefaults.set(recipeWaitSampleCount + 1, forKey: Keys.recipeWaitLatencySamples)
    }

    func resetRecipeWaitMeasurement() {
        recipeWaitStartedAt = nil
    }

    func shouldAutoStartWaitingGame(hasBothPhotos: Bool) -> Bool {
        let threshold: TimeInterval = hasBothPhotos
            ? remoteConfig.waitingGameDualPhotoThreshold
            : remoteConfig.waitingGameSinglePhotoThreshold
        return estimatedRecipeWaitLatency >= threshold
    }

    func waitingGameAutoStartDelay(hasBothPhotos: Bool) -> TimeInterval {
        let floor: TimeInterval = hasBothPhotos ? 1.9 : 1.4
        let ceiling: TimeInterval = hasBothPhotos ? 7.6 : 6.8
        let adaptiveCore = min(max(estimatedRecipeWaitLatency * 0.52, floor), ceiling)
        let variantBias = hasBothPhotos ? waitingGameVariant.autoStartDelay + 0.35 : waitingGameVariant.autoStartDelay
        let adaptiveWeight = remoteConfig.waitingGameAdaptiveBlendWeight
        let blended = (adaptiveCore * adaptiveWeight) + (variantBias * (1 - adaptiveWeight))
        let tunedDelay = blended * remoteConfig.waitingGameDelayMultiplier
        return min(max(tunedDelay, floor), ceiling)
    }

    func trackWaitingGameShown(hasBothPhotos: Bool) {
        AnalyticsManager.shared.logEvent(
            "waiting_game_shown",
            parameters: [
                "variant": waitingGameVariant.rawValue,
                "experiment_group": remoteConfig.experimentGroup.rawValue,
                "has_both_photos": hasBothPhotos,
                "estimated_wait_seconds": roundedTenths(estimatedRecipeWaitLatency),
                "latency_samples": recipeWaitSampleCount,
                "auto_start_enabled": shouldAutoStartWaitingGame(hasBothPhotos: hasBothPhotos),
                "single_threshold": roundedTenths(remoteConfig.waitingGameSinglePhotoThreshold),
                "dual_threshold": roundedTenths(remoteConfig.waitingGameDualPhotoThreshold)
            ]
        )
    }

    func trackWaitingGameManualStart() {
        AnalyticsManager.shared.logEvent(
            "waiting_game_manual_start",
            parameters: [
                "variant": waitingGameVariant.rawValue,
                "experiment_group": remoteConfig.experimentGroup.rawValue
            ]
        )
    }

    func trackWaitingGameAutoStart() {
        AnalyticsManager.shared.logEvent(
            "waiting_game_auto_start",
            parameters: [
                "variant": waitingGameVariant.rawValue,
                "experiment_group": remoteConfig.experimentGroup.rawValue
            ]
        )
    }

    func trackWaitingGameDismissed() {
        AnalyticsManager.shared.logEvent(
            "waiting_game_dismissed",
            parameters: [
                "variant": waitingGameVariant.rawValue,
                "experiment_group": remoteConfig.experimentGroup.rawValue
            ]
        )
    }

    func trackViralPromptShown(recipeCount: Int) {
        AnalyticsManager.shared.logEvent(
            "viral_prompt_shown",
            parameters: [
                "variant": waitingGameVariant.rawValue,
                "experiment_group": remoteConfig.experimentGroup.rawValue,
                "recipe_count": recipeCount
            ]
        )
    }

    func trackViralCTATapped(recipeID: UUID) {
        AnalyticsManager.shared.logEvent(
            "viral_cta_tapped",
            parameters: [
                "variant": waitingGameVariant.rawValue,
                "experiment_group": remoteConfig.experimentGroup.rawValue,
                "recipe_id": recipeID.uuidString
            ]
        )
    }

    private func roundedTenths(_ value: TimeInterval) -> Double {
        (value * 10).rounded() / 10
    }
}
