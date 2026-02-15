import XCTest
import SwiftUI
import UIKit
@testable import SnapChef

final class NotificationPolicyTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testNormalizedMonthlyTimeUsesFallbackWhenOutsideWindow() {
        let result = NotificationPolicyDebug.normalizedMonthlyTime(
            preferredHour: 23,
            preferredMinute: 45,
            preferredWindowStartHour: 9,
            preferredWindowEndHour: 18,
            fallbackHour: 10,
            fallbackMinute: 30
        )

        XCTAssertEqual(result.hour, 10)
        XCTAssertEqual(result.minute, 30)
    }

    func testNormalizedMonthlyTimeClampsMinuteWhenInsideWindow() {
        let result = NotificationPolicyDebug.normalizedMonthlyTime(
            preferredHour: 11,
            preferredMinute: 74,
            preferredWindowStartHour: 9,
            preferredWindowEndHour: 18,
            fallbackHour: 10,
            fallbackMinute: 30
        )

        XCTAssertEqual(result.hour, 11)
        XCTAssertEqual(result.minute, 59)
    }

    func testNextMonthlyScheduleDateUsesCurrentMonthWhenStillInFuture() {
        let now = utcCalendar.date(from: DateComponents(
            year: 2026,
            month: 2,
            day: 1,
            hour: 9,
            minute: 0
        ))!

        let result = NotificationPolicyDebug.nextMonthlyScheduleDate(
            now: now,
            calendar: utcCalendar,
            preferredHour: 12,
            preferredMinute: 15,
            monthlyScheduleDay: 1,
            monthlyScheduleHour: 10,
            monthlyScheduleMinute: 30,
            preferredWindowStartHour: 9,
            preferredWindowEndHour: 18,
            quietHoursEnabled: true,
            quietHoursStart: 22,
            quietHoursEnd: 8
        )

        let components = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 15)
    }

    func testNextMonthlyScheduleDateRollsToNextMonthWhenCurrentMonthPassed() {
        let now = utcCalendar.date(from: DateComponents(
            year: 2026,
            month: 2,
            day: 1,
            hour: 13,
            minute: 0
        ))!

        let result = NotificationPolicyDebug.nextMonthlyScheduleDate(
            now: now,
            calendar: utcCalendar,
            preferredHour: 12,
            preferredMinute: 15,
            monthlyScheduleDay: 1,
            monthlyScheduleHour: 10,
            monthlyScheduleMinute: 30,
            preferredWindowStartHour: 9,
            preferredWindowEndHour: 18,
            quietHoursEnabled: true,
            quietHoursStart: 22,
            quietHoursEnd: 8
        )

        let components = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 15)
    }

    func testNextMonthlyScheduleDateAdjustsOutOfQuietHours() {
        let now = utcCalendar.date(from: DateComponents(
            year: 2026,
            month: 2,
            day: 1,
            hour: 9,
            minute: 0
        ))!

        let result = NotificationPolicyDebug.nextMonthlyScheduleDate(
            now: now,
            calendar: utcCalendar,
            preferredHour: 7,
            preferredMinute: 20,
            monthlyScheduleDay: 1,
            monthlyScheduleHour: 10,
            monthlyScheduleMinute: 30,
            preferredWindowStartHour: 6,
            preferredWindowEndHour: 18,
            quietHoursEnabled: true,
            quietHoursStart: 22,
            quietHoursEnd: 8
        )

        let components = utcCalendar.dateComponents([.hour, .minute], from: result)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 30)
    }

    func testNotificationCategoryChallengeActionsExcludeSnooze() {
        let ids = NotificationCategory.challengeReminder.actions.map(\.identifier)
        XCTAssertTrue(ids.contains("VIEW_CHALLENGE"))
        XCTAssertFalse(ids.contains("SNOOZE_REMINDER"))
    }

    func testQuietHoursHelperHandlesOvernightWindow() {
        XCTAssertTrue(NotificationPolicyDebug.isInQuietHours(hour: 23, quietHoursStart: 22, quietHoursEnd: 8))
        XCTAssertTrue(NotificationPolicyDebug.isInQuietHours(hour: 7, quietHoursStart: 22, quietHoursEnd: 8))
        XCTAssertFalse(NotificationPolicyDebug.isInQuietHours(hour: 14, quietHoursStart: 22, quietHoursEnd: 8))
    }

    func testMonthBucketOverloadDetectionRespectsCap() {
        let janA = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 10, minute: 0))!
        let janB = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 20, hour: 12, minute: 30))!
        let feb = utcCalendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 9, minute: 15))!

        let overload = NotificationPolicyDebug.firstMonthlyOverload(
            for: [janA, janB, feb],
            maxPerMonth: 1,
            calendar: utcCalendar
        )

        XCTAssertEqual(overload?.key, "2026-1")
        XCTAssertEqual(overload?.count, 2)
    }

    func testMonthBucketOverloadDetectionReturnsNilWhenWithinCap() {
        let jan = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 10, minute: 0))!
        let feb = utcCalendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 9, minute: 15))!

        let overload = NotificationPolicyDebug.firstMonthlyOverload(
            for: [jan, feb],
            maxPerMonth: 1,
            calendar: utcCalendar
        )

        XCTAssertNil(overload)
    }

    func testCanScheduleMonthlyNotificationBlocksWhenPendingAlreadyAtCap() {
        let target = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 10, minute: 30))!
        let pendingA = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 11, minute: 0))!

        let canSchedule = NotificationPolicyDebug.canScheduleMonthlyNotification(
            targetDate: target,
            reservedDate: nil,
            pendingDates: [pendingA],
            maxPerMonth: 1,
            calendar: utcCalendar
        )

        XCTAssertFalse(canSchedule)
    }

    func testCanScheduleMonthlyNotificationBlocksWhenReservationMatchesMonth() {
        let target = utcCalendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 10, minute: 30))!
        let reserved = utcCalendar.date(from: DateComponents(year: 2026, month: 4, day: 6, hour: 14, minute: 0))!

        let canSchedule = NotificationPolicyDebug.canScheduleMonthlyNotification(
            targetDate: target,
            reservedDate: reserved,
            pendingDates: [],
            maxPerMonth: 1,
            calendar: utcCalendar
        )

        XCTAssertFalse(canSchedule)
    }

    func testCanScheduleMonthlyNotificationAllowsWhenReservationDifferentMonthAndPendingBelowCap() {
        let target = utcCalendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10, minute: 30))!
        let reserved = utcCalendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 10, minute: 30))!
        let pendingOtherMonth = utcCalendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 10, minute: 30))!

        let canSchedule = NotificationPolicyDebug.canScheduleMonthlyNotification(
            targetDate: target,
            reservedDate: reserved,
            pendingDates: [pendingOtherMonth],
            maxPerMonth: 1,
            calendar: utcCalendar
        )

        XCTAssertTrue(canSchedule)
    }

    func testTransactionalCriticalPolicyEnforcesMonthlyCap() {
        XCTAssertTrue(NotificationDeliveryPolicy.transactionalCritical.enforcesMonthlyCap)
        XCTAssertTrue(NotificationDeliveryPolicy.transactionalCritical.enforcesOneShotDelivery)
    }
    
    func testMonthlyAndTransactionalPoliciesEnforceMonthlyCap() {
        XCTAssertTrue(NotificationDeliveryPolicy.monthlyEngagement.enforcesMonthlyCap)
        XCTAssertTrue(NotificationDeliveryPolicy.transactionalNudge.enforcesMonthlyCap)
        XCTAssertTrue(NotificationDeliveryPolicy.transactionalCritical.enforcesMonthlyCap)
        XCTAssertTrue(NotificationDeliveryPolicy.transactional.enforcesMonthlyCap)
    }
}

final class GrowthLoopManagerTests: XCTestCase {
    private enum Keys {
        static let waitingGameVariant = "growth_waiting_game_variant"
        static let recipeWaitLatencyEwma = "growth_recipe_wait_latency_ewma"
        static let recipeWaitLatencySamples = "growth_recipe_wait_latency_samples"
        static let experimentGroup = "growth_experiment_group"
        static let remotePayloadJSON = "growth_remote_config_payload_json"
        static let waitingVariantOverride = "growth_waiting_game_variant_override"
        static let waitingSingleThreshold = "growth_waiting_game_single_threshold"
        static let waitingDualThreshold = "growth_waiting_game_dual_threshold"
        static let waitingDelayMultiplier = "growth_waiting_game_delay_multiplier"
        static let waitingAdaptiveBlend = "growth_waiting_game_adaptive_blend"
        static let cameraMotionMultiplier = "growth_camera_motion_multiplier"
        static let cameraScanCycleBaseDuration = "growth_camera_scan_cycle_base_duration"
    }

    private let defaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        defaults.removeObject(forKey: Keys.waitingGameVariant)
        defaults.removeObject(forKey: Keys.recipeWaitLatencyEwma)
        defaults.removeObject(forKey: Keys.recipeWaitLatencySamples)
        defaults.removeObject(forKey: Keys.experimentGroup)
        defaults.removeObject(forKey: Keys.remotePayloadJSON)
        defaults.removeObject(forKey: Keys.waitingVariantOverride)
        defaults.removeObject(forKey: Keys.waitingSingleThreshold)
        defaults.removeObject(forKey: Keys.waitingDualThreshold)
        defaults.removeObject(forKey: Keys.waitingDelayMultiplier)
        defaults.removeObject(forKey: Keys.waitingAdaptiveBlend)
        defaults.removeObject(forKey: Keys.cameraMotionMultiplier)
        defaults.removeObject(forKey: Keys.cameraScanCycleBaseDuration)
    }

    override func tearDown() {
        defaults.removeObject(forKey: Keys.waitingGameVariant)
        defaults.removeObject(forKey: Keys.recipeWaitLatencyEwma)
        defaults.removeObject(forKey: Keys.recipeWaitLatencySamples)
        defaults.removeObject(forKey: Keys.experimentGroup)
        defaults.removeObject(forKey: Keys.remotePayloadJSON)
        defaults.removeObject(forKey: Keys.waitingVariantOverride)
        defaults.removeObject(forKey: Keys.waitingSingleThreshold)
        defaults.removeObject(forKey: Keys.waitingDualThreshold)
        defaults.removeObject(forKey: Keys.waitingDelayMultiplier)
        defaults.removeObject(forKey: Keys.waitingAdaptiveBlend)
        defaults.removeObject(forKey: Keys.cameraMotionMultiplier)
        defaults.removeObject(forKey: Keys.cameraScanCycleBaseDuration)
        super.tearDown()
    }

    func testEstimatedLatencyDefaultsWhenUnset() async {
        let latency = await MainActor.run {
            GrowthLoopManager.shared.estimatedRecipeWaitLatency
        }

        XCTAssertEqual(latency, 7.0, accuracy: 0.001)
    }

    func testAutoStartDisabledForFastBackends() async {
        defaults.set(2.2, forKey: Keys.recipeWaitLatencyEwma)

        let singlePhoto = await MainActor.run {
            GrowthLoopManager.shared.shouldAutoStartWaitingGame(hasBothPhotos: false)
        }
        let bothPhotos = await MainActor.run {
            GrowthLoopManager.shared.shouldAutoStartWaitingGame(hasBothPhotos: true)
        }

        XCTAssertFalse(singlePhoto)
        XCTAssertFalse(bothPhotos)
    }

    func testAdaptiveDelayStaysWithinBounds() async {
        defaults.set("quick", forKey: Keys.waitingGameVariant)
        defaults.set(12.0, forKey: Keys.recipeWaitLatencyEwma)
        defaults.set(6, forKey: Keys.recipeWaitLatencySamples)

        let singlePhotoDelay = await MainActor.run {
            GrowthLoopManager.shared.waitingGameAutoStartDelay(hasBothPhotos: false)
        }
        let bothPhotosDelay = await MainActor.run {
            GrowthLoopManager.shared.waitingGameAutoStartDelay(hasBothPhotos: true)
        }

        XCTAssertTrue(singlePhotoDelay >= 1.4 && singlePhotoDelay <= 6.8)
        XCTAssertTrue(bothPhotosDelay >= 1.9 && bothPhotosDelay <= 7.6)
    }

    func testWaitingGameVariantSupportsRemoteOverride() async {
        defaults.set("quick", forKey: Keys.waitingGameVariant)
        defaults.set("immersive", forKey: Keys.waitingVariantOverride)

        let variant = await MainActor.run {
            GrowthLoopManager.shared.waitingGameVariant
        }

        XCTAssertEqual(variant.rawValue, "immersive")
    }

    func testSingleThresholdCanBeRemoteTuned() async {
        defaults.set(2.4, forKey: Keys.recipeWaitLatencyEwma)
        defaults.set(2.0, forKey: Keys.waitingSingleThreshold)

        let shouldAutoStart = await MainActor.run {
            GrowthLoopManager.shared.shouldAutoStartWaitingGame(hasBothPhotos: false)
        }

        XCTAssertTrue(shouldAutoStart)
    }

    func testCameraMotionMultiplierAffectsCameraTiming() {
        defaults.set(1.5, forKey: Keys.cameraMotionMultiplier)

        let baseSeconds = MotionTuning.seconds(1.0)
        let cameraSeconds = MotionTuning.cameraSeconds(1.0)

        XCTAssertGreaterThan(cameraSeconds, baseSeconds)
    }

    func testBootstrapAppliesJSONPayloadOverrides() {
        defaults.set(
            "{\"growth_waiting_game_single_threshold\":2.1,\"growth_waiting_game_delay_multiplier\":0.82}",
            forKey: Keys.remotePayloadJSON
        )

        GrowthRemoteConfig.shared.bootstrap()

        XCTAssertEqual(GrowthRemoteConfig.shared.waitingGameSinglePhotoThreshold, 2.1, accuracy: 0.001)
        XCTAssertEqual(GrowthRemoteConfig.shared.waitingGameDelayMultiplier, 0.82, accuracy: 0.001)
    }
}

final class SocialShareManagerTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let referralCodeKey = "growth_referral_code"

    override func setUp() {
        super.setUp()
        defaults.set("REF12345", forKey: referralCodeKey)
        ShareMomentumStore.clear()
        ViralMilestoneTracker.reset()
        ViralCoachMarksProgress.reset()
    }

    override func tearDown() {
        defaults.removeObject(forKey: referralCodeKey)
        ShareMomentumStore.clear()
        ViralMilestoneTracker.reset()
        ViralCoachMarksProgress.reset()
        super.tearDown()
    }

    func testAppendReferralCodeAddsRefWhenMissing() async {
        let base = URL(string: "https://snapchef.app/challenge/ch_001")!

        let updated = await MainActor.run {
            SocialShareManager.shared.appendReferralCode(to: base)
        }

        let components = URLComponents(url: updated, resolvingAgainstBaseURL: false)
        let ref = components?.queryItems?.first(where: { $0.name == "ref" })?.value

        XCTAssertEqual(ref, "REF12345")
        XCTAssertEqual(components?.path, "/challenge/ch_001")
    }

    func testAppendReferralCodeDoesNotDuplicateExistingRef() async {
        let original = URL(string: "https://snapchef.app/challenge/ch_001?ref=EXISTING&src=share")!

        let updated = await MainActor.run {
            SocialShareManager.shared.appendReferralCode(to: original)
        }

        let components = URLComponents(url: updated, resolvingAgainstBaseURL: false)
        let refs = components?.queryItems?.filter { $0.name == "ref" } ?? []

        XCTAssertEqual(refs.count, 1)
        XCTAssertEqual(refs.first?.value, "EXISTING")
    }

    func testGenerateChallengeInviteLinkIncludesChallengePathAndRef() async {
        let url = await MainActor.run {
            SocialShareManager.shared.generateChallengeInviteLink(challengeID: "challenge_abc")
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.host, "snapchef.app")
        XCTAssertEqual(components?.path, "/challenge/challenge_abc")
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "ref" })?.value, "REF12345")
    }

    func testInviteCenterSnapshotReturnsCodeAndURLWhenUnauthenticated() async {
        let result = await SocialShareManager.shared.fetchInviteCenterSnapshot()

        XCTAssertEqual(result.referralCode, "REF12345")
        XCTAssertTrue(result.inviteURL.absoluteString.contains("ref=REF12345"))
        XCTAssertFalse(result.isAuthenticated)
        XCTAssertEqual(result.totalConversions, 0)
        XCTAssertEqual(result.pendingRewards, 0)
        XCTAssertEqual(result.claimedRewards, 0)
    }

    func testShareMomentumStoreReturnsRecentShare() {
        ShareMomentumStore.record(platform: "TikTok", at: Date())
        let latest = ShareMomentumStore.latest(maxAge: 600)

        XCTAssertEqual(latest?.platform, "TikTok")
        XCTAssertNotNil(latest?.sharedAt)
    }

    func testShareMomentumStoreExpiresStaleShare() {
        let staleDate = Date().addingTimeInterval(-2_000)
        ShareMomentumStore.record(platform: "Instagram", at: staleDate)
        let latest = ShareMomentumStore.latest(maxAge: 300)

        XCTAssertNil(latest)
    }

    func testViralFunnelProgressTracksNextMilestone() {
        let progress = ViralFunnelProgress(conversions: 4)

        XCTAssertEqual(progress.achievedMilestone, 3)
        XCTAssertEqual(progress.nextMilestone, 5)
        XCTAssertEqual(progress.conversionsToNext, 1)
        XCTAssertTrue(progress.progressToNext > 0)
        XCTAssertTrue(progress.progressToNext < 1)
    }

    func testViralFunnelProgressHandlesTopTier() {
        let progress = ViralFunnelProgress(conversions: 120)

        XCTAssertEqual(progress.nextMilestone, nil)
        XCTAssertEqual(progress.conversionsToNext, 0)
        XCTAssertEqual(progress.progressToNext, 1, accuracy: 0.001)
        XCTAssertEqual(progress.goalTitle, "Top funnel tier reached")
    }

    func testViralMilestoneTrackerUnlocksOncePerMilestone() {
        XCTAssertNil(ViralMilestoneTracker.unlockedMilestone(for: 0))
        XCTAssertEqual(ViralMilestoneTracker.unlockedMilestone(for: 1), 1)
        XCTAssertNil(ViralMilestoneTracker.unlockedMilestone(for: 2))
        XCTAssertEqual(ViralMilestoneTracker.unlockedMilestone(for: 3), 3)
        XCTAssertNil(ViralMilestoneTracker.unlockedMilestone(for: 3))
    }

    func testViralMilestoneTrackerResetAllowsReplay() {
        XCTAssertEqual(ViralMilestoneTracker.unlockedMilestone(for: 5), 5)
        XCTAssertNil(ViralMilestoneTracker.unlockedMilestone(for: 5))

        ViralMilestoneTracker.reset()

        XCTAssertEqual(ViralMilestoneTracker.unlockedMilestone(for: 5), 5)
    }

    func testViralCoachMarksProgressRequiresMomentum() {
        XCTAssertFalse(ViralCoachMarksProgress.shouldPresent(hasMomentum: false))
        XCTAssertTrue(ViralCoachMarksProgress.shouldPresent(hasMomentum: true))
    }

    func testViralCoachMarksProgressStopsAfterCompletionUntilReset() {
        XCTAssertTrue(ViralCoachMarksProgress.shouldPresent(hasMomentum: true))

        ViralCoachMarksProgress.markCompleted()

        XCTAssertFalse(ViralCoachMarksProgress.shouldPresent(hasMomentum: true))

        ViralCoachMarksProgress.reset()

        XCTAssertTrue(ViralCoachMarksProgress.shouldPresent(hasMomentum: true))
    }
}

@MainActor
final class RootTabWiringTests: XCTestCase {
    private struct CameraToResultsHarness: View {
        @State private var showResults = false
        let recipe: Recipe

        var body: some View {
            Group {
                if showResults {
                    RecipeResultsView(
                        recipes: [recipe],
                        ingredients: [
                            IngredientAPI(
                                name: "Avocado",
                                quantity: "1",
                                unit: "piece",
                                category: "Produce",
                                freshness: "Fresh",
                                location: "Fridge"
                            )
                        ],
                        capturedImage: UIImage(systemName: "fork.knife"),
                        isPresented: .constant(true)
                    )
                } else {
                    CameraView(selectedTab: .constant(1))
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    showResults = true
                }
            }
        }
    }

    private func makeMockRecipe(name: String = "Studio Bowl") -> Recipe {
        Recipe(
            id: UUID(),
            ownerID: "test-user",
            name: name,
            description: "A polished test recipe",
            ingredients: [
                Ingredient(
                    id: UUID(),
                    name: "Avocado",
                    quantity: "1",
                    unit: "piece",
                    isAvailable: true
                )
            ],
            instructions: ["Slice", "Plate", "Serve"],
            cookTime: 10,
            prepTime: 5,
            servings: 2,
            difficulty: .easy,
            nutrition: Nutrition(calories: 320, protein: 8, carbs: 22, fat: 20, fiber: 7, sugar: 3, sodium: 180),
            imageURL: nil,
            createdAt: Date(),
            tags: ["quick", "healthy"],
            dietaryInfo: DietaryInfo(isVegetarian: true, isVegan: false, isGlutenFree: true, isDairyFree: true),
            isDetectiveRecipe: true,
            cookingTechniques: ["Slicing"],
            flavorProfile: FlavorProfile(sweet: 2, salty: 3, sour: 1, bitter: 1, umami: 4),
            secretIngredients: ["Lime zest"],
            proTips: ["Serve chilled"],
            visualClues: ["Vibrant green"],
            shareCaption: "Studio test plate"
        )
    }

    private func host<Content: View>(_ view: Content) {
        let controller = UIHostingController(rootView: view)
        XCTAssertNotNil(controller.view)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    func testMainTabViewLoadsWithAppEnvironment() {
        host(
            MainTabView()
                .environmentObject(AppState())
                .environmentObject(UnifiedAuthManager.shared)
                .environmentObject(DeviceManager())
                .environmentObject(GamificationManager())
                .environmentObject(SocialShareManager.shared)
                .environmentObject(CloudKitService.shared)
                .environmentObject(CloudKitDataManager.shared)
                .environmentObject(NotificationManager.shared)
        )
    }

    func testAppTabDefinitionsRemainDeterministic() {
        XCTAssertEqual(AppTab.allCases.map(\.rawValue), [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(AppTab.allCases.map(\.tabBarTitle), ["Home", "Snap", "Detective", "Recipes", "Feed", "Profile"])
        XCTAssertEqual(Set(AppTab.allCases.map(\.icon)).count, AppTab.allCases.count)
        XCTAssertEqual(AppTab.allCases.map(\.momentTitle), ["Home", "Snap Time", "Detective Mode", "Recipes", "Social Feed", "Profile"])
    }

    func testOnlyCameraAndDetectiveRequireCameraPermission() {
        for tab in AppTab.allCases {
            switch tab {
            case .camera, .detective:
                XCTAssertTrue(tab.requiresCameraPermission, "\(tab) should require camera permission")
            default:
                XCTAssertFalse(tab.requiresCameraPermission, "\(tab) should not require camera permission")
            }
        }
    }

    func testRootTabsInitializeIndependently() {
        host(
            HomeView()
                .environmentObject(AppState())
                .environmentObject(DeviceManager())
                .environmentObject(CloudKitDataManager.shared)
        )

        host(
            CameraView(selectedTab: .constant(1))
                .environmentObject(AppState())
                .environmentObject(DeviceManager())
                .environmentObject(CloudKitDataManager.shared)
        )

        host(
            DetectiveView()
                .environmentObject(AppState())
        )

        host(
            RecipesView(selectedTab: .constant(3))
                .environmentObject(AppState())
        )

        host(
            SocialFeedView()
                .environmentObject(AppState())
                .environmentObject(UnifiedAuthManager.shared)
        )

        host(
            ProfileView()
                .environmentObject(AppState())
                .environmentObject(UnifiedAuthManager.shared)
                .environmentObject(DeviceManager())
                .environmentObject(GamificationManager())
        )
    }

    func testMainTabViewHandlesGlobalNotificationsWithoutCrashing() {
        let root = MainTabView()
            .environmentObject(AppState())
            .environmentObject(UnifiedAuthManager.shared)
            .environmentObject(DeviceManager())
            .environmentObject(GamificationManager())
            .environmentObject(SocialShareManager.shared)
            .environmentObject(CloudKitService.shared)
            .environmentObject(CloudKitDataManager.shared)
            .environmentObject(NotificationManager.shared)

        let controller = UIHostingController(rootView: root)
        XCTAssertNotNil(controller.view)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        NotificationCenter.default.post(
            name: .snapchefRecipeGenerated,
            object: nil,
            userInfo: ["count": 3]
        )
        NotificationCenter.default.post(
            name: .snapchefShareCompleted,
            object: nil,
            userInfo: ["platform": "TikTok"]
        )
        NotificationCenter.default.post(
            name: .snapchefNotificationTapped,
            object: nil,
            userInfo: ["categoryIdentifier": NotificationCategory.streakReminder.rawValue]
        )

        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view)
    }

    func testMainTabViewHandlesAllNudgerCategoriesWithoutCrashing() {
        let root = MainTabView()
            .environmentObject(AppState())
            .environmentObject(UnifiedAuthManager.shared)
            .environmentObject(DeviceManager())
            .environmentObject(GamificationManager())
            .environmentObject(SocialShareManager.shared)
            .environmentObject(CloudKitService.shared)
            .environmentObject(CloudKitDataManager.shared)
            .environmentObject(NotificationManager.shared)

        let controller = UIHostingController(rootView: root)
        XCTAssertNotNil(controller.view)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let categories = [
            NotificationCategory.streakReminder.rawValue,
            NotificationCategory.challengeReminder.rawValue,
            NotificationCategory.newChallenge.rawValue,
            NotificationCategory.teamChallenge.rawValue,
            NotificationCategory.leaderboardUpdate.rawValue,
            "unknown_category"
        ]

        for category in categories {
            NotificationCenter.default.post(
                name: .snapchefNotificationTapped,
                object: nil,
                userInfo: ["categoryIdentifier": category]
            )
        }

        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view)
    }

    func testMainTabViewHandlesNavigateToTabNotificationsWithoutCrashing() {
        let root = MainTabView()
            .environmentObject(AppState())
            .environmentObject(UnifiedAuthManager.shared)
            .environmentObject(DeviceManager())
            .environmentObject(GamificationManager())
            .environmentObject(SocialShareManager.shared)
            .environmentObject(CloudKitService.shared)
            .environmentObject(CloudKitDataManager.shared)
            .environmentObject(NotificationManager.shared)

        let controller = UIHostingController(rootView: root)
        XCTAssertNotNil(controller.view)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        for tab in AppTab.allCases {
            NotificationCenter.default.post(
                name: .snapchefNavigateToTab,
                object: nil,
                userInfo: ["tab": tab.rawValue]
            )
        }
        NotificationCenter.default.post(
            name: .snapchefNavigateToTab,
            object: nil,
            userInfo: ["tab": 999]
        )

        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view)
    }

    func testCameraToResultsHarnessRendersTransitionPath() {
        let root = CameraToResultsHarness(recipe: makeMockRecipe())
            .environmentObject(AppState())
            .environmentObject(DeviceManager())
            .environmentObject(CloudKitDataManager.shared)
            .environmentObject(UnifiedAuthManager.shared)
            .environmentObject(GamificationManager())

        let controller = UIHostingController(rootView: root)
        XCTAssertNotNil(controller.view)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view)
    }
}

final class ProductionGuardrailTests: XCTestCase {
    func testInternalTestCaptureIsDisabledByDefault() {
        let enabled = CameraView.shouldEnableInternalTestCapture(
            arguments: [],
            environment: [:],
            isDebugBuild: true
        )
        XCTAssertFalse(enabled)
    }

    func testInternalTestCaptureRequiresLaunchArgumentInDebugBuild() {
        let enabled = CameraView.shouldEnableInternalTestCapture(
            arguments: ["--snapchef-enable-test-capture"],
            environment: [:],
            isDebugBuild: true
        )
        XCTAssertFalse(enabled)
    }

    func testInternalTestCaptureLaunchArgumentAndEnvBackwardCompatibility() {
        let enabled = CameraView.shouldEnableInternalTestCapture(
            arguments: ["--snapchef-enable-test-capture"],
            environment: ["SNAPCHEF_ENABLE_TEST_CAPTURE": "1"],
            isDebugBuild: true
        )
        XCTAssertFalse(enabled)
    }

    func testInternalTestCaptureIgnoresEnvFlagWithoutLaunchArgument() {
        let enabled = CameraView.shouldEnableInternalTestCapture(
            arguments: [],
            environment: ["SNAPCHEF_ENABLE_TEST_CAPTURE": "1"],
            isDebugBuild: true
        )
        XCTAssertFalse(enabled)
    }

    func testInternalTestCaptureAlwaysDisabledOutsideDebugBuild() {
        let enabled = CameraView.shouldEnableInternalTestCapture(
            arguments: ["--snapchef-enable-test-capture"],
            environment: ["SNAPCHEF_ENABLE_TEST_CAPTURE": "1"],
            isDebugBuild: false
        )
        XCTAssertFalse(enabled)
    }

    func testAPIErrorMessageParsesJSONPayloadForUserFacingMessage() {
        let error = SnapChefError.apiError("{\"detail\":\"Invalid or missing X-App-API-Key header\"}", statusCode: 401)
        XCTAssertEqual(error.userFriendlyMessage, "Service authentication is invalid. Please try again shortly.")
    }

    func testAPIErrorMessageUsesServerMessageWhenStatusUnknown() {
        let error = SnapChefError.apiError("{\"message\":\"Chef backend warming up\"}", statusCode: 418)
        XCTAssertEqual(error.userFriendlyMessage, "Chef backend warming up")
    }

    func testOnlyCameraAndDetectiveTabsRequireCameraPermission() {
        let requiringPermission = AppTab.allCases.filter(\.requiresCameraPermission)
        XCTAssertEqual(Set(requiringPermission), Set([.camera, .detective]))
    }

    func testAppTabRawValuesRemainStable() {
        XCTAssertEqual(AppTab.home.rawValue, 0)
        XCTAssertEqual(AppTab.camera.rawValue, 1)
        XCTAssertEqual(AppTab.detective.rawValue, 2)
        XCTAssertEqual(AppTab.recipes.rawValue, 3)
        XCTAssertEqual(AppTab.socialFeed.rawValue, 4)
        XCTAssertEqual(AppTab.profile.rawValue, 5)
    }
}
