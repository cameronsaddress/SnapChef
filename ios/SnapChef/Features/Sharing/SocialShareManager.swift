import Foundation
import SwiftUI
import Photos
import AVFoundation
import CloudKit

struct ShareMomentumSnapshot: Equatable {
    let platform: String
    let sharedAt: Date
}

struct ViralFunnelProgress: Equatable {
    static let milestones: [Int] = [1, 3, 5, 8, 12, 20, 35, 50]

    let conversions: Int
    let achievedMilestone: Int
    let nextMilestone: Int?
    let progressToNext: Double
    let conversionsToNext: Int

    init(conversions: Int) {
        let safeConversions = max(0, conversions)
        self.conversions = safeConversions
        self.achievedMilestone = Self.milestones.last(where: { safeConversions >= $0 }) ?? 0
        self.nextMilestone = Self.milestones.first(where: { safeConversions < $0 })

        if let nextMilestone {
            let prior = Self.milestones.last(where: { $0 < nextMilestone }) ?? 0
            let span = max(nextMilestone - prior, 1)
            let advanced = safeConversions - prior
            self.progressToNext = min(max(Double(advanced) / Double(span), 0), 1)
            self.conversionsToNext = max(nextMilestone - safeConversions, 0)
        } else {
            self.progressToNext = 1
            self.conversionsToNext = 0
        }
    }

    var goalTitle: String {
        if let nextMilestone {
            return "Goal: \(nextMilestone) conversions"
        }
        return "Top funnel tier reached"
    }

    var goalSubtitle: String {
        if let nextMilestone {
            return "\(conversionsToNext) more to hit \(nextMilestone)"
        }
        return "Maintain momentum and compound rewards"
    }
}

enum ViralMilestoneTracker {
    private static let unlockedMilestoneKey = "growth_viral_last_unlocked_milestone"

    static func unlockedMilestone(for conversions: Int) -> Int? {
        let achieved = ViralFunnelProgress(conversions: conversions).achievedMilestone
        guard achieved > 0 else { return nil }

        let lastUnlocked = UserDefaults.standard.integer(forKey: unlockedMilestoneKey)
        guard achieved > lastUnlocked else { return nil }

        UserDefaults.standard.set(achieved, forKey: unlockedMilestoneKey)
        return achieved
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: unlockedMilestoneKey)
    }
}

enum ShareMomentumStore {
    private enum Keys {
        static let platform = "growth_share_momentum_platform"
        static let sharedAt = "growth_share_momentum_shared_at"
    }

    static func record(platform: String, at date: Date = Date()) {
        let sanitized = platform.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return }
        UserDefaults.standard.set(sanitized, forKey: Keys.platform)
        UserDefaults.standard.set(date, forKey: Keys.sharedAt)
    }

    static func latest(maxAge: TimeInterval = 60 * 60 * 24) -> ShareMomentumSnapshot? {
        guard let platform = UserDefaults.standard.string(forKey: Keys.platform),
              let sharedAt = UserDefaults.standard.object(forKey: Keys.sharedAt) as? Date else {
            return nil
        }
        guard Date().timeIntervalSince(sharedAt) <= maxAge else {
            clear()
            return nil
        }
        return ShareMomentumSnapshot(platform: platform, sharedAt: sharedAt)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: Keys.platform)
        UserDefaults.standard.removeObject(forKey: Keys.sharedAt)
    }
}

enum ViralCoachMarksProgress {
    private static let completedKey = "growth_viral_coach_completed"

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static func shouldPresent(hasMomentum: Bool) -> Bool {
        hasMomentum && !isCompleted
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: completedKey)
    }
}

@MainActor
class SocialShareManager: ObservableObject {
    static let shared = SocialShareManager()
    
    @Published var isSharing = false
    @Published var shareResult: ShareResult?
    @Published var showRecipeFromDeepLink = false
    @Published var pendingRecipe: Recipe?
    @Published var pendingDeepLink: DeepLinkType?
    @Published var latestReferralCode: String?
    
    private let userDefaults = UserDefaults.standard
    
    private enum ReferralKeys {
        static let code = "growth_referred_by_code"
        static let firstSeenAt = "growth_referred_first_seen_at"
        static let sourceURL = "growth_referred_source_url"
        static let openCount = "growth_referred_open_count"
        static let conversionAt = "growth_referred_conversion_at"
        static let conversionRewarded = "growth_referred_conversion_rewarded"
        static let lastHandledURL = "growth_referred_last_handled_url"
        static let lastValidatedAt = "growth_referred_last_validated_at"
    }

    private enum GrowthKeys {
        static let referralCode = "growth_referral_code"
    }

    private enum ReferralRewardConfig {
        static let inviteeBonusCoins = 40
        static let referrerBonusCoins = 55
        static let cloudKitRecordType = "ReferralConversion"
        static let fieldReferralCode = "referralCode"
        static let fieldInvitedUserID = "invitedUserID"
        static let fieldConvertedAt = "convertedAt"
        static let fieldReferrerRewardClaimed = "referrerRewardClaimed"
        static let fieldReferrerRewardedAt = "referrerRewardedAt"
        static let fieldReferrerUserID = "referrerUserID"
    }

    private let referralCodeLength = 8
    private let referralConversionWindowDays = 14
    private let cloudKitContainerID = "iCloud.com.snapchefapp.app"

    private init() {}
    
    enum ShareResult {
        case success(String)
        case failure(Error)
    }
    
    enum SharePlatform {
        case instagram
        case tiktok
        case twitter
        case messages
        case general
    }
    
    enum DeepLinkType {
        case recipe(String)
        case challenge(String)
        case invite(String)
    }

    struct InviteCenterSnapshot {
        let referralCode: String
        let inviteURL: URL
        let totalConversions: Int
        let pendingRewards: Int
        let claimedRewards: Int
        let pendingCoins: Int
        let earnedCoins: Int
        let inviteeAppliedCode: String?
        let inviteeOpenCount: Int
        let isAuthenticated: Bool
        let sourceError: String?
    }
    
    // MARK: - Public Interface
    
    func shareRecipe(_ recipe: Recipe, image: UIImage?, platform: SharePlatform) async {
        isSharing = true
        defer { isSharing = false }
        
        do {
            switch platform {
            case .instagram:
                try await shareToInstagram(recipe: recipe, image: image)
            case .tiktok:
                try await shareToTikTok(recipe: recipe, image: image)
            case .twitter:
                try await shareToTwitter(recipe: recipe, image: image)
            case .messages:
                try await shareToMessages(recipe: recipe, image: image)
            case .general:
                try await shareGeneral(recipe: recipe, image: image)
            }
            
            shareResult = .success("Successfully shared to \(platform)")
            ShareMomentumStore.record(platform: platformDisplayName(platform))
            NotificationCenter.default.post(
                name: .snapchefShareCompleted,
                object: nil,
                userInfo: ["platform": platformDisplayName(platform)]
            )
        } catch {
            shareResult = .failure(error)
        }
    }

    func currentReferralCode() -> String {
        if let cached = userDefaults.string(forKey: GrowthKeys.referralCode), !cached.isEmpty {
            return cached
        }

        let seed = userDefaults.string(forKey: "currentUserID")
            ?? userDefaults.string(forKey: "userId")
            ?? UIDevice.current.identifierForVendor?.uuidString
            ?? UUID().uuidString

        let sanitized = seed
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        let code = String(sanitized.prefix(referralCodeLength))
        userDefaults.set(code, forKey: GrowthKeys.referralCode)
        return code
    }

    func referralInviteURL() -> URL {
        let code = currentReferralCode()
        return URL(string: "https://snapchef.app/invite?ref=\(code)") ?? URL(string: "https://snapchef.app")!
    }

    func appendReferralCode(to url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        var queryItems = components.queryItems ?? []
        let hasRef = queryItems.contains(where: {
            let key = $0.name.lowercased()
            return key == "ref" || key == "code"
        })
        if !hasRef {
            queryItems.append(URLQueryItem(name: "ref", value: currentReferralCode()))
            components.queryItems = queryItems
        }
        return components.url ?? url
    }

    func generateChallengeInviteLink(challengeID: String) -> URL {
        let base = URL(string: "https://snapchef.app/challenge/\(challengeID)") ?? URL(string: "https://snapchef.app/challenge")!
        return appendReferralCode(to: base)
    }

    func fetchInviteCenterSnapshot() async -> InviteCenterSnapshot {
        let code = currentReferralCode()
        let inviteURL = referralInviteURL()
        let inviteeAppliedCode = userDefaults.string(forKey: ReferralKeys.code)
        let inviteeOpenCount = userDefaults.integer(forKey: ReferralKeys.openCount)
        let isAuthenticated = UnifiedAuthManager.shared.isAuthenticated

        guard isAuthenticated else {
            return InviteCenterSnapshot(
                referralCode: code,
                inviteURL: inviteURL,
                totalConversions: 0,
                pendingRewards: 0,
                claimedRewards: 0,
                pendingCoins: 0,
                earnedCoins: 0,
                inviteeAppliedCode: inviteeAppliedCode,
                inviteeOpenCount: inviteeOpenCount,
                isAuthenticated: false,
                sourceError: nil
            )
        }

        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else {
            return InviteCenterSnapshot(
                referralCode: code,
                inviteURL: inviteURL,
                totalConversions: 0,
                pendingRewards: 0,
                claimedRewards: 0,
                pendingCoins: 0,
                earnedCoins: 0,
                inviteeAppliedCode: inviteeAppliedCode,
                inviteeOpenCount: inviteeOpenCount,
                isAuthenticated: true,
                sourceError: "CloudKit unavailable in this build."
            )
        }

        let currentUserID = currentAuthenticatedUserID()
        guard let container = CloudKitRuntimeSupport.makeContainer(identifier: cloudKitContainerID) else {
            return InviteCenterSnapshot(
                referralCode: code,
                inviteURL: inviteURL,
                totalConversions: 0,
                pendingRewards: 0,
                claimedRewards: 0,
                pendingCoins: 0,
                earnedCoins: 0,
                inviteeAppliedCode: inviteeAppliedCode,
                inviteeOpenCount: inviteeOpenCount,
                isAuthenticated: true,
                sourceError: "CloudKit container unavailable in this build."
            )
        }
        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(format: "%K == %@", ReferralRewardConfig.fieldReferralCode, code)
        let query = CKQuery(recordType: ReferralRewardConfig.cloudKitRecordType, predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 400)
            var totalConversions = 0
            var claimedRewards = 0
            var pendingRewards = 0

            for (_, result) in results {
                guard let record = try? result.get() else { continue }

                let invitedUserID = record[ReferralRewardConfig.fieldInvitedUserID] as? String ?? ""
                if let currentUserID, invitedUserID == currentUserID {
                    continue
                }

                let isClaimed = (record[ReferralRewardConfig.fieldReferrerRewardClaimed] as? Int64 ?? 0) == 1
                if isClaimed {
                    let rewardedUser = record[ReferralRewardConfig.fieldReferrerUserID] as? String
                    if rewardedUser == nil || rewardedUser == currentUserID {
                        claimedRewards += 1
                        totalConversions += 1
                    }
                } else {
                    pendingRewards += 1
                    totalConversions += 1
                }
            }

            return InviteCenterSnapshot(
                referralCode: code,
                inviteURL: inviteURL,
                totalConversions: totalConversions,
                pendingRewards: pendingRewards,
                claimedRewards: claimedRewards,
                pendingCoins: pendingRewards * ReferralRewardConfig.referrerBonusCoins,
                earnedCoins: claimedRewards * ReferralRewardConfig.referrerBonusCoins,
                inviteeAppliedCode: inviteeAppliedCode,
                inviteeOpenCount: inviteeOpenCount,
                isAuthenticated: true,
                sourceError: nil
            )
        } catch {
            return InviteCenterSnapshot(
                referralCode: code,
                inviteURL: inviteURL,
                totalConversions: 0,
                pendingRewards: 0,
                claimedRewards: 0,
                pendingCoins: 0,
                earnedCoins: 0,
                inviteeAppliedCode: inviteeAppliedCode,
                inviteeOpenCount: inviteeOpenCount,
                isAuthenticated: true,
                sourceError: error.localizedDescription
            )
        }
    }
    
    // MARK: - Platform-Specific Sharing
    
    private func shareToInstagram(recipe: Recipe, image: UIImage?) async throws {
        guard let image = image else {
            throw ShareError.missingImage
        }
        
        // Save image to photo library first
        try await saveImageToPhotoLibrary(image)
        
        // Open Instagram if available
        if let instagramURL = URL(string: "instagram://app") {
            if UIApplication.shared.canOpenURL(instagramURL) {
                await UIApplication.shared.open(instagramURL)
            } else {
                throw ShareError.appNotInstalled("Instagram")
            }
        }
    }
    
    private func shareToTikTok(recipe: Recipe, image: UIImage?) async throws {
        guard let image = image else {
            throw ShareError.missingImage
        }
        
        // Save image to photo library first
        try await saveImageToPhotoLibrary(image)
        
        // Open TikTok if available
        if let tiktokURL = URL(string: "tiktok://") {
            if UIApplication.shared.canOpenURL(tiktokURL) {
                await UIApplication.shared.open(tiktokURL)
            } else {
                throw ShareError.appNotInstalled("TikTok")
            }
        }
    }
    
    private func shareToTwitter(recipe: Recipe, image: UIImage?) async throws {
        let text = generateShareText(for: recipe)
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let twitterURL = URL(string: "twitter://post?message=\(encodedText)") {
            if UIApplication.shared.canOpenURL(twitterURL) {
                await UIApplication.shared.open(twitterURL)
            } else if let webURL = URL(string: "https://twitter.com/intent/tweet?text=\(encodedText)") {
                await UIApplication.shared.open(webURL)
            }
        }
    }
    
    private func shareToMessages(recipe: Recipe, image: UIImage?) async throws {
        let text = generateShareText(for: recipe)
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let messagesURL = URL(string: "sms:&body=\(encodedText)") {
            await UIApplication.shared.open(messagesURL)
        }
    }
    
    private func shareGeneral(recipe: Recipe, image: UIImage?) async throws {
        // This will trigger the system share sheet
        // Implementation depends on the calling view
    }
    
    // MARK: - Helper Methods
    
    private func generateShareText(for recipe: Recipe) -> String {
        return "Check out this amazing recipe I found on SnapChef: \(recipe.name)! 🍽️ #SnapChef #Recipe"
    }

    private func platformDisplayName(_ platform: SharePlatform) -> String {
        switch platform {
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .twitter: return "X"
        case .messages: return "Messages"
        case .general: return "Share Sheet"
        }
    }
    
    // MARK: - Deep Link Handling
    
    func handleIncomingURL(_ url: URL) -> Bool {
        var didHandle = false

        if let referralCode = extractReferralCode(from: url) {
            recordReferralOpen(referralCode: referralCode, sourceURL: url.absoluteString)
            pendingDeepLink = .invite(referralCode)
            didHandle = true
        }

        if let tab = extractTabDestination(from: url) {
            NotificationCenter.default.post(
                name: .snapchefNavigateToTab,
                object: nil,
                userInfo: ["tab": tab.rawValue]
            )
            didHandle = true
        }

        if let challengeID = extractChallengeID(from: url) {
            pendingDeepLink = .challenge(challengeID)
            didHandle = true
            Task { @MainActor in
                await handleChallengeDeepLink(challengeID)
            }
            return true
        }
        
        if let recipeID = extractRecipeID(from: url) {
            pendingDeepLink = .recipe(recipeID)
            showRecipeFromDeepLink = true
            return true
        }
        
        return didHandle
    }
    
    func resolvePendingDeepLink() {
        // This would typically fetch the recipe from CloudKit or the server
        // For now, just hide the sheet
        showRecipeFromDeepLink = false
        pendingRecipe = nil
        pendingDeepLink = nil
    }
    
    func markReferralConversionIfEligible() {
        guard UnifiedAuthManager.shared.isAuthenticated else { return }
        guard let code = trustedReferralCodeForConversion() else { return }
        guard userDefaults.object(forKey: ReferralKeys.conversionAt) == nil else { return }
        
        let conversionDate = Date()
        userDefaults.set(conversionDate, forKey: ReferralKeys.conversionAt)
        
        let sourceURL = userDefaults.string(forKey: ReferralKeys.sourceURL) ?? "unknown"
        let openCount = userDefaults.integer(forKey: ReferralKeys.openCount)
        
        AnalyticsManager.shared.logEvent(
            "referral_attributed_conversion",
            parameters: [
                "ref_code": code,
                "source_url": sourceURL,
                "open_count": openCount
            ]
        )

        if !userDefaults.bool(forKey: ReferralKeys.conversionRewarded) {
            ChefCoinsManager.shared.earnCoins(
                ReferralRewardConfig.inviteeBonusCoins,
                reason: "Referral Welcome Bonus",
                isBonus: true
            )
            userDefaults.set(true, forKey: ReferralKeys.conversionRewarded)
            NotificationCenter.default.post(
                name: Notification.Name("ShowToast"),
                object: nil,
                userInfo: ["message": "Referral bonus unlocked: +\(ReferralRewardConfig.inviteeBonusCoins) Chef Coins"]
            )
        }

        Task { @MainActor in
            await upsertReferralConversionRecord(referralCode: code, convertedAt: conversionDate)
            await claimReferrerRewardsIfEligible()
        }
    }

    func claimReferrerRewardsIfEligible() async {
        guard UnifiedAuthManager.shared.isAuthenticated else { return }
        guard let currentUserID = currentAuthenticatedUserID() else { return }
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else { return }

        let code = currentReferralCode()
        guard let container = CloudKitRuntimeSupport.makeContainer(identifier: cloudKitContainerID) else { return }
        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %d",
            ReferralRewardConfig.fieldReferralCode,
            code,
            ReferralRewardConfig.fieldReferrerRewardClaimed,
            0
        )
        let query = CKQuery(recordType: ReferralRewardConfig.cloudKitRecordType, predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 30)
            var claimedCount = 0

            for (_, result) in results {
                guard let record = try? result.get() else { continue }
                let invitedUserID = record[ReferralRewardConfig.fieldInvitedUserID] as? String ?? ""

                // Defensive guard against any malformed self-attribution.
                if invitedUserID == currentUserID {
                    continue
                }

                record[ReferralRewardConfig.fieldReferrerRewardClaimed] = Int64(1)
                record[ReferralRewardConfig.fieldReferrerRewardedAt] = Date()
                record[ReferralRewardConfig.fieldReferrerUserID] = currentUserID

                do {
                    _ = try await publicDB.save(record)
                    claimedCount += 1
                } catch {
                    print("⚠️ Failed to persist referrer reward claim: \(error)")
                }
            }

            guard claimedCount > 0 else { return }

            let totalCoins = claimedCount * ReferralRewardConfig.referrerBonusCoins
            ChefCoinsManager.shared.earnCoins(
                totalCoins,
                reason: "Invite conversion reward (\(claimedCount)x)",
                isBonus: true
            )

            NotificationCenter.default.post(
                name: Notification.Name("ShowToast"),
                object: nil,
                userInfo: ["message": "Invite rewards unlocked: +\(totalCoins) Chef Coins"]
            )

            AnalyticsManager.shared.logEvent(
                "referrer_rewards_claimed",
                parameters: [
                    "ref_code": code,
                    "conversions": claimedCount,
                    "coins": totalCoins
                ]
            )
        } catch {
            print("⚠️ Unable to claim referrer rewards: \(error)")
        }
    }
    
    // MARK: - Universal Link Generation
    
    func generateUniversalLink(for recipe: Recipe, cloudKitRecordID: String?) -> URL {
        let baseURL = "https://snapchef.app/recipe"
        let urlString: String
        if let recordID = cloudKitRecordID {
            urlString = "\(baseURL)/\(recordID)"
        } else {
            urlString = "\(baseURL)/\(recipe.id.uuidString)"
        }
        if let url = URL(string: urlString) {
            return url
        } else if let fallbackURL = URL(string: baseURL) {
            return fallbackURL
        } else {
            // Final fallback to snapchef.com
            return URL(string: "https://snapchef.com")!
        }
    }

    // MARK: - Referral Parsing

    private func extractTabDestination(from url: URL) -> AppTab? {
        let scheme = (url.scheme ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let host = (url.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if scheme == "snapchef" {
            switch host {
            case "home":
                return .home
            case "camera", "snap":
                return .camera
            case "detective":
                return .detective
            case "recipes":
                return .recipes
            case "feed", "social", "community":
                return .socialFeed
            case "profile", "me":
                return .profile
            default:
                return nil
            }
        }

        // Support universal links when Associated Domains are enabled.
        if scheme == "https",
           host == "snapchef.app" || host == "www.snapchef.app" {
            let pathParts = url.pathComponents
                .filter { $0 != "/" }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

            guard let first = pathParts.first else { return .home }
            switch first {
            case "home":
                return .home
            case "camera", "snap":
                return .camera
            case "detective":
                return .detective
            case "recipes":
                return .recipes
            case "feed", "social", "community":
                return .socialFeed
            case "profile", "me":
                return .profile
            case "leaderboard":
                // Leaderboard lives inside the challenges area; route to Profile for now.
                return .profile
            default:
                return nil
            }
        }

        return nil
    }
    
    private func extractRecipeID(from url: URL) -> String? {
        let pathParts = url.pathComponents.filter { $0 != "/" }
        
        if url.scheme == "snapchef", url.host == "recipe", let last = pathParts.last, !last.isEmpty {
            return last
        }
        
        if url.host == "snapchef.app",
           pathParts.count >= 2,
           pathParts[0].lowercased() == "recipe" {
            let recipeID = pathParts[1]
            return recipeID.isEmpty ? nil : recipeID
        }
        
        return nil
    }

    private func extractChallengeID(from url: URL) -> String? {
        let pathParts = url.pathComponents.filter { $0 != "/" }

        if url.scheme == "snapchef",
           url.host == "challenge",
           let last = pathParts.last,
           !last.isEmpty {
            return last
        }

        let host = (url.host ?? "").lowercased()
        if (host == "snapchef.app" || host == "www.snapchef.app"),
           pathParts.count >= 2,
           pathParts[0].lowercased() == "challenge" {
            let challengeID = pathParts[1]
            return challengeID.isEmpty ? nil : challengeID
        }

        return nil
    }
    
    private func extractReferralCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        let queryItems = components.queryItems ?? []
        let refValue = queryItems.first { $0.name.lowercased() == "ref" || $0.name.lowercased() == "code" }?.value
        
        let pathParts = url.pathComponents.filter { $0 != "/" }
        let isInvitePath = pathParts.first?.lowercased() == "invite"
            || (pathParts.count >= 2 && pathParts[0].lowercased() == "team" && pathParts[1].lowercased() == "join")
        
        let isInviteHost = (components.host ?? "").lowercased() == "invite"
        let hasReferralQuery = refValue != nil
        let isKnownScheme = (components.scheme ?? "").lowercased() == "snapchef"
            || (components.scheme ?? "").lowercased() == "https"
        
        guard isKnownScheme else { return nil }
        guard isInvitePath || isInviteHost || hasReferralQuery else { return nil }
        
        let codeCandidate = refValue ?? pathParts.last
        guard let codeCandidate, !codeCandidate.isEmpty else { return nil }
        
        let normalized = codeCandidate
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard isValidReferralCode(normalized) else { return nil }
        return normalized
    }
    
    private func recordReferralOpen(referralCode: String, sourceURL: String) {
        guard isValidReferralCode(referralCode) else { return }
        let ownCode = currentReferralCode().uppercased()
        guard referralCode != ownCode else {
            AnalyticsManager.shared.logEvent(
                "referral_self_link_opened",
                parameters: ["ref_code": referralCode]
            )
            return
        }
        
        let lastURL = userDefaults.string(forKey: ReferralKeys.lastHandledURL)
        if lastURL == sourceURL {
            // De-duplicate repeated open callbacks for same URL.
            return
        }
        
        userDefaults.set(sourceURL, forKey: ReferralKeys.lastHandledURL)
        
        if userDefaults.string(forKey: ReferralKeys.code) != referralCode {
            userDefaults.set(referralCode, forKey: ReferralKeys.code)
            userDefaults.set(Date(), forKey: ReferralKeys.firstSeenAt)
            userDefaults.removeObject(forKey: ReferralKeys.conversionAt)
            userDefaults.removeObject(forKey: ReferralKeys.conversionRewarded)
            userDefaults.set(0, forKey: ReferralKeys.openCount)
        }
        
        let openCount = userDefaults.integer(forKey: ReferralKeys.openCount) + 1
        userDefaults.set(openCount, forKey: ReferralKeys.openCount)
        userDefaults.set(sourceURL, forKey: ReferralKeys.sourceURL)
        userDefaults.set(Date(), forKey: ReferralKeys.lastValidatedAt)
        latestReferralCode = referralCode
        
        AnalyticsManager.shared.logEvent(
            "referral_attributed_open",
            parameters: [
                "ref_code": referralCode,
                "source_url": sourceURL,
                "open_count": openCount
            ]
        )
        
        NotificationCenter.default.post(
            name: Notification.Name("ReferralAttributionUpdated"),
            object: nil,
            userInfo: [
                "ref_code": referralCode,
                "open_count": openCount
            ]
        )
        NotificationCenter.default.post(
            name: Notification.Name("ShowToast"),
            object: nil,
            userInfo: ["message": "Invite applied: \(referralCode)"]
        )
    }

    private func isValidReferralCode(_ code: String) -> Bool {
        guard code.count == referralCodeLength else { return false }
        for scalar in code.unicodeScalars {
            let isDigit = scalar.value >= 48 && scalar.value <= 57
            let isUpper = scalar.value >= 65 && scalar.value <= 90
            if !isDigit && !isUpper {
                return false
            }
        }
        return true
    }

    private func isTrustedReferralSourceURL(_ sourceURL: String) -> Bool {
        guard let url = URL(string: sourceURL),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        let scheme = (components.scheme ?? "").lowercased()
        let host = (components.host ?? "").lowercased()
        if scheme == "snapchef" {
            return true
        }
        if scheme == "https" && (host == "snapchef.app" || host == "www.snapchef.app") {
            return true
        }
        return false
    }

    private func trustedReferralCodeForConversion() -> String? {
        guard let code = userDefaults.string(forKey: ReferralKeys.code), isValidReferralCode(code) else {
            return nil
        }
        let ownCode = currentReferralCode().uppercased()
        guard code != ownCode else {
            AnalyticsManager.shared.logEvent(
                "referral_conversion_rejected",
                parameters: [
                    "reason": "self_referral",
                    "ref_code": code
                ]
            )
            return nil
        }
        guard let firstSeenAt = userDefaults.object(forKey: ReferralKeys.firstSeenAt) as? Date else {
            return nil
        }
        let validUntil = Calendar.current.date(byAdding: .day, value: referralConversionWindowDays, to: firstSeenAt) ?? firstSeenAt
        guard validUntil >= Date() else {
            AnalyticsManager.shared.logEvent(
                "referral_conversion_rejected",
                parameters: [
                    "reason": "expired_attribution_window",
                    "ref_code": code
                ]
            )
            return nil
        }
        let openCount = userDefaults.integer(forKey: ReferralKeys.openCount)
        guard openCount > 0 else { return nil }
        let sourceURL = userDefaults.string(forKey: ReferralKeys.sourceURL) ?? ""
        guard isTrustedReferralSourceURL(sourceURL) else {
            AnalyticsManager.shared.logEvent(
                "referral_conversion_rejected",
                parameters: [
                    "reason": "untrusted_source",
                    "ref_code": code
                ]
            )
            return nil
        }
        return code
    }

    private func currentAuthenticatedUserID() -> String? {
        if let userID = UnifiedAuthManager.shared.currentUser?.recordID, !userID.isEmpty {
            return userID
        }
        if let fallback = userDefaults.string(forKey: "currentUserID"), !fallback.isEmpty {
            return fallback
        }
        return nil
    }

    private func upsertReferralConversionRecord(referralCode: String, convertedAt: Date) async {
        guard let invitedUserID = currentAuthenticatedUserID() else { return }
        guard CloudKitRuntimeSupport.hasCloudKitEntitlement else { return }

        guard let container = CloudKitRuntimeSupport.makeContainer(identifier: cloudKitContainerID) else { return }
        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(
            format: "%K == %@ AND %K == %@",
            ReferralRewardConfig.fieldReferralCode,
            referralCode,
            ReferralRewardConfig.fieldInvitedUserID,
            invitedUserID
        )
        let query = CKQuery(recordType: ReferralRewardConfig.cloudKitRecordType, predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            let record: CKRecord
            if let (_, result) = results.first, let existing = try? result.get() {
                record = existing
            } else {
                record = CKRecord(recordType: ReferralRewardConfig.cloudKitRecordType)
            }

            record[ReferralRewardConfig.fieldReferralCode] = referralCode
            record[ReferralRewardConfig.fieldInvitedUserID] = invitedUserID
            record[ReferralRewardConfig.fieldConvertedAt] = convertedAt
            if record[ReferralRewardConfig.fieldReferrerRewardClaimed] == nil {
                record[ReferralRewardConfig.fieldReferrerRewardClaimed] = Int64(0)
            }

            _ = try await publicDB.save(record)
        } catch {
            print("⚠️ Failed to upsert referral conversion record: \(error)")
        }
    }

    private func handleChallengeDeepLink(_ challengeID: String) async {
        AnalyticsManager.shared.logEvent(
            "challenge_deep_link_opened",
            parameters: ["challenge_id": challengeID]
        )

        guard UnifiedAuthManager.shared.isAuthenticated else {
            NotificationCenter.default.post(
                name: Notification.Name("ShowToast"),
                object: nil,
                userInfo: ["message": "Sign in to join this challenge."]
            )
            return
        }

        let retryDelays: [UInt64] = [0, 800_000_000, 2_000_000_000]
        for delay in retryDelays {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }

            if let challenge = GamificationManager.shared.getChallenge(by: challengeID) {
                if !GamificationManager.shared.isChallengeJoined(challengeID) {
                    GamificationManager.shared.joinChallenge(challenge)
                    NotificationCenter.default.post(
                        name: Notification.Name("ShowToast"),
                        object: nil,
                        userInfo: ["message": "Joined challenge: \(challenge.title)"]
                    )
                    AnalyticsManager.shared.logEvent(
                        "challenge_deep_link_joined",
                        parameters: ["challenge_id": challengeID]
                    )
                } else {
                    NotificationCenter.default.post(
                        name: Notification.Name("ShowToast"),
                        object: nil,
                        userInfo: ["message": "Challenge already joined."]
                    )
                }
                return
            }
        }

        await GamificationManager.shared.syncChallengesFromCloudKit()
        if let challenge = GamificationManager.shared.getChallenge(by: challengeID) {
            if !GamificationManager.shared.isChallengeJoined(challengeID) {
                GamificationManager.shared.joinChallenge(challenge)
                NotificationCenter.default.post(
                    name: Notification.Name("ShowToast"),
                    object: nil,
                    userInfo: ["message": "Joined challenge: \(challenge.title)"]
                )
            }
            return
        }

        NotificationCenter.default.post(
            name: Notification.Name("ShowToast"),
            object: nil,
            userInfo: ["message": "Challenge link received. Open Challenges to join."]
        )
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? ShareError.saveFailed)
                }
            }
        }
    }
    
    // MARK: - Photo Library Permission
    
    func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
