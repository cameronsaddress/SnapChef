//
//  ShareService.swift
//  SnapChef
//
//  TikTok Viral Content Generation - Complete ShareService Implementation
//  Following EXACT specifications from TIKTOK_VIRAL_COMPLETE_REQUIREMENTS.md
//

import SwiftUI
import UIKit
import CloudKit
import Photos

// Import TikTok SDK components
#if canImport(TikTokOpenSDKCore)
import TikTokOpenSDKCore
#endif

#if canImport(TikTokOpenShareSDK)
import TikTokOpenShareSDK
#endif

// MARK: - Share Type
public enum ShareType {
    case recipe(Recipe)
    case challenge(Challenge)
    case achievement(String)
    case profile
    case teamInvite(teamName: String, joinCode: String)
}

// MARK: - Share Content
public struct ShareContent {
    let type: ShareType
    let beforeImage: UIImage?
    let afterImage: UIImage?
    let text: String
    let hashtags: [String]
    var deepLink: URL?

    // Helper for TikTok video generation
    func toRenderInputs() -> (recipe: ViralRecipe, media: MediaBundle)? {
        guard case .recipe(let recipe) = type,
              let beforeImage = beforeImage else { return nil }

        let viralRecipe = ViralRecipe(
            title: recipe.name,
            hook: "Fridge chaos → \(recipe.name) in \(recipe.prepTime + recipe.cookTime) min",
            steps: recipe.instructions.map { ViralRecipe.Step($0) },
            timeMinutes: recipe.prepTime + recipe.cookTime,
            costDollars: nil,
            calories: nil,  // Recipe doesn't have calories property
            ingredients: recipe.ingredients.map { $0.name }  // Convert Ingredient objects to strings
        )

        let media = MediaBundle(
            beforeFridge: beforeImage,
            afterFridge: beforeImage, // Use same image if no after
            cookedMeal: afterImage ?? beforeImage,
            brollClips: [],
            musicURL: Bundle.main.url(forResource: "Mixdown", withExtension: "mp3")
        )

        return (recipe: viralRecipe, media: media)
    }

    init(type: ShareType, beforeImage: UIImage? = nil, afterImage: UIImage? = nil) {
        self.type = type
        self.beforeImage = beforeImage
        self.afterImage = afterImage

        // Generate content based on type
        switch type {
        case .recipe(let recipe):
            self.text = """
            🔥 MY FRIDGE CHALLENGE 🔥
            I just turned these random ingredients into \(recipe.name)!
            ⏱ Ready in just \(recipe.prepTime + recipe.cookTime) minutes
            """
            self.hashtags = ["SnapChef", "FridgeChallenge", "HomeCooking", recipe.difficulty.rawValue + "Recipe"]
            self.deepLink = URL(string: "snapchef://recipe/\(recipe.id)")

        case .challenge(let challenge):
            self.text = """
            🏆 CHALLENGE COMPLETED 🏆
            Just crushed the "\(challenge.title)" challenge on SnapChef!
            """
            self.hashtags = ["SnapChef", "CookingChallenge", "ChefLife"]
            self.deepLink = URL(string: "snapchef://challenge/\(challenge.id)")

        case .achievement(let badge):
            self.text = """
            🎯 NEW ACHIEVEMENT UNLOCKED 🎯
            Just earned the \(badge) badge on SnapChef!
            """
            self.hashtags = ["SnapChef", "Achievement", "CookingGoals"]
            self.deepLink = URL(string: "snapchef://achievements")

        case .profile:
            self.text = """
            👨‍🍳 Check out my SnapChef profile!
            Follow me for amazing recipes and cooking challenges.
            """
            self.hashtags = ["SnapChef", "FollowMe", "ChefProfile"]
            self.deepLink = URL(string: "snapchef://profile")

        case .teamInvite(let teamName, let joinCode):
            self.text = """
            🏆 Join my SnapChef team!
            Team: \(teamName)
            Code: \(joinCode)

            Let's compete together in cooking challenges!
            """
            self.hashtags = ["SnapChef", "TeamChallenge", "CookingTeam"]
            self.deepLink = URL(string: "snapchef://team/join/\(joinCode)")
        }
    }
}

// MARK: - Share Platform Extended
enum SharePlatformType: String, CaseIterable {
    case tiktok = "TikTok"
    case instagram = "Instagram"
    case instagramStory = "Story"
    case twitter = "X"
    case facebook = "Facebook"
    case whatsapp = "WhatsApp"
    case messages = "Messages"
    case copy = "Copy Link"
    case more = "More"

    var icon: String {
        switch self {
        case .tiktok: return "music.note"
        case .instagram: return "camera.fill"
        case .instagramStory: return "camera.circle.fill"
        case .twitter: return "bubble.left.fill"
        case .facebook: return "person.2.fill"
        case .whatsapp: return "bubble.left.and.bubble.right.fill"
        case .messages: return "message.fill"
        case .copy: return "doc.on.doc.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }

    var brandColor: Color {
        switch self {
        case .tiktok: return Color(hex: "#000000")
        case .instagram, .instagramStory: return Color(hex: "#E4405F")
        case .twitter: return Color(hex: "#1DA1F2")
        case .facebook: return Color(hex: "#1877F2")
        case .whatsapp: return Color(hex: "#25D366")
        case .messages: return Color(hex: "#43e97b")
        case .copy: return Color(hex: "#667eea")
        case .more: return Color.gray
        }
    }

    var urlScheme: String? {
        switch self {
        case .tiktok: return "tiktok://"
        case .instagram: return "instagram://"
        case .instagramStory: return "instagram-stories://"
        case .twitter: return "twitter://"
        case .facebook: return "fb://"
        case .whatsapp: return "whatsapp://"
        case .messages, .copy, .more: return nil
        }
    }

    @MainActor
    var isAvailable: Bool {
        guard let scheme = urlScheme,
              let url = URL(string: scheme) else {
            return true // Always available for system functions
        }
        return UIApplication.shared.canOpenURL(url)
    }
}

// MARK: - Share Service
@MainActor
class ShareService: ObservableObject {
    static let shared = ShareService()

    @Published var isProcessing = false
    @Published var showSharePopup = false
    @Published var currentContent: ShareContent?
    @Published var selectedPlatform: SharePlatformType?
    @Published var shareProgress: Double = 0
    @Published var errorMessage: String?

    private let cloudKitSync = CloudKitSyncService.shared
    private let socialShareManager = SocialShareManager.shared
    // private let analytics = AnalyticsManager.shared // Commented out until AnalyticsManager is ready

    private init() {}

    // MARK: - Create Share Content with CloudKit Photos

    /// Create share content with photos fetched from CloudKit
    func createShareContentWithPhotos(for recipe: Recipe) async throws -> ShareContent {
        // Fetch photos from CloudKit
        let photos = try await CloudKitRecipeManager.shared.fetchRecipePhotos(for: recipe.id.uuidString)

        // Create share content with the fetched photos
        return ShareContent(
            type: .recipe(recipe),
            beforeImage: photos.before,
            afterImage: photos.after
        )
    }

    // MARK: - Public Methods

    func shareContent(_ content: ShareContent, from viewController: UIViewController? = nil) {
        currentContent = content
        showSharePopup = true
    }

    func share(to platform: SharePlatformType) async {
        guard var content = currentContent else { return }

        selectedPlatform = platform
        isProcessing = true
        shareProgress = 0
        errorMessage = nil

        do {
            // Track share initiation
            trackShareInitiated(platform: platform, content: content)

            // Upload to CloudKit if needed
            if let deepLink = await uploadContentToCloudKit(&content) {
                content.deepLink = deepLink
            }

            // Platform-specific sharing
            switch platform {
            case .tiktok:
                try await shareToTikTok(content)
            case .instagram:
                try await shareToInstagram(content, asStory: false)
            case .instagramStory:
                try await shareToInstagram(content, asStory: true)
            case .twitter:
                try await shareToTwitter(content)
            case .facebook:
                try await shareToFacebook(content)
            case .whatsapp:
                try await shareToWhatsApp(content)
            case .messages:
                try await shareToMessages(content)
            case .copy:
                copyToClipboard(content)
            case .more:
                showSystemShareSheet(content)
            }

            // Award rewards
            awardShareRewards(platform: platform)

            // Track success
            trackShareCompleted(platform: platform, content: content)
        } catch {
            errorMessage = error.localizedDescription
            trackShareFailed(platform: platform, error: error)
        }

        isProcessing = false
        shareProgress = 1.0
    }

    // MARK: - Platform Implementations

    private func shareToTikTok(_ content: ShareContent) async throws {
        // The TikTokShareView will handle everything
        // This method is not called when using platform-specific views
        // It's only here as a fallback

        // Check if TikTok is installed
        guard SharePlatformType.tiktok.isAvailable else {
            // Fallback to web
            if let webURL = URL(string: "https://www.tiktok.com") {
                await UIApplication.shared.open(webURL)
                return
            }
            throw ShareError.appNotInstalled("TikTok")
        }

        // This path should not be reached since BrandedSharePopup
        // shows TikTokShareView for TikTok platform
        print("⚠️ Direct TikTok share called - should use TikTokShareView instead")
    }

    private func shareToInstagram(_ content: ShareContent, asStory: Bool) async throws {
        guard SharePlatformType.instagram.isAvailable else {
            // Fallback to web
            if let webURL = URL(string: "https://www.instagram.com") {
                await UIApplication.shared.open(webURL)
                return
            }
            throw ShareError.appNotInstalled("Instagram")
        }

        if asStory {
            // Share to Instagram Stories
            try await shareToInstagramStory(content)
        } else {
            // Deep link to Instagram with clipboard content
            UIPasteboard.general.string = formatTextForPlatform(content, platform: .instagram)

            if let url = URL(string: "instagram://camera") {
                await UIApplication.shared.open(url)
            }
        }
    }

    private func shareToInstagramStory(_ content: ShareContent) async throws {
        // Prepare sticker image
        guard let stickerImage = content.afterImage ?? content.beforeImage else {
            throw ShareError.missingImage
        }

        guard let stickerData = stickerImage.pngData() else {
            throw ShareError.imageProcessingFailed
        }

        // Create pasteboard items
        let pasteboardItems: [[String: Any]] = [[
            "com.instagram.sharedSticker.stickerImage": stickerData,
            "com.instagram.sharedSticker.backgroundTopColor": "#667eea",
            "com.instagram.sharedSticker.backgroundBottomColor": "#764ba2"
        ]]

        // Set pasteboard options
        let pasteboardOptions = [
            UIPasteboard.OptionsKey.expirationDate: Date().addingTimeInterval(300)
        ]

        // Set items to pasteboard
        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)

        // Open Instagram Stories
        if let url = URL(string: "instagram-stories://share") {
            await UIApplication.shared.open(url)
        }
    }

    private func shareToTwitter(_ content: ShareContent) async throws {
        let fullText = formatTextForPlatform(content, platform: .twitter)
        let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Try native app first
        if let url = URL(string: "twitter://post?message=\(encodedText)"),
           UIApplication.shared.canOpenURL(url) {
            await UIApplication.shared.open(url)
        } else if let webURL = URL(string: "https://twitter.com/intent/tweet?text=\(encodedText)") {
            await UIApplication.shared.open(webURL)
        }
    }

    private func shareToFacebook(_ content: ShareContent) async throws {
        let fullText = formatTextForPlatform(content, platform: .facebook)
        let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Try native app first with deep link
        if SharePlatformType.facebook.isAvailable {
            var urlString = "fb://publish/profile/me"
            if let deepLink = content.deepLink {
                let encodedLink = deepLink.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                urlString = "fb://publish/?link=\(encodedLink)&quote=\(encodedText)"
            }

            if let url = URL(string: urlString) {
                await UIApplication.shared.open(url)
                return
            }
        }

        // Fallback to web
        if let webURL = URL(string: "https://www.facebook.com/sharer/sharer.php?u=https://snapchef.app&quote=\(encodedText)") {
            await UIApplication.shared.open(webURL)
        }
    }

    private func shareToWhatsApp(_ content: ShareContent) async throws {
        let fullText = formatTextForPlatform(content, platform: .whatsapp)
        let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "whatsapp://send?text=\(encodedText)") {
            await UIApplication.shared.open(url)
        }
    }

    private func shareToMessages(_ content: ShareContent) async throws {
        // This would open the MessageShareView
        NotificationCenter.default.post(
            name: Notification.Name("OpenMessageShare"),
            object: nil,
            userInfo: ["content": content]
        )
    }

    private func copyToClipboard(_ content: ShareContent) {
        let fullText = formatTextForPlatform(content, platform: .copy)
        UIPasteboard.general.string = fullText

        // Show toast notification
        NotificationCenter.default.post(
            name: Notification.Name("ShowToast"),
            object: nil,
            userInfo: ["message": "Link copied to clipboard!"]
        )
    }

    private func showSystemShareSheet(_ content: ShareContent) {
        var items: [Any] = []

        // Add text
        items.append(formatTextForPlatform(content, platform: .more))

        // Add images
        if let image = content.afterImage ?? content.beforeImage {
            items.append(image)
        }

        // Add URL
        if let url = content.deepLink {
            items.append(url)
        }

        // Use the new ShareSheetPresenter to avoid conflicts
        ShareSheetPresenter.shared.present(items: items)
    }

    // MARK: - Helper Methods

    private func formatTextForPlatform(_ content: ShareContent, platform: SharePlatformType) -> String {
        var text = content.text

        // Add hashtags
        let hashtagString = content.hashtags.map { "#\($0)" }.joined(separator: " ")

        // Platform-specific formatting
        switch platform {
        case .twitter:
            // Twitter has character limit
            text = String(text.prefix(200))
            text += "\n\n\(hashtagString)"

        case .instagram, .instagramStory:
            text += "\n\n\(hashtagString)"
            text += "\n\n📱 Get SnapChef and join the challenge!"

        default:
            text += "\n\n\(hashtagString)"
            if let url = content.deepLink {
                text += "\n\n🔗 \(url.absoluteString)"
            }
        }

        return text
    }

    private func uploadContentToCloudKit(_ content: inout ShareContent) async -> URL? {
        // Upload content to CloudKit and return shareable URL
        // This would integrate with CloudKitSyncService
        return nil // Placeholder
    }

    private func awardShareRewards(platform: SharePlatformType) {
        // Award Chef Coins for sharing
        ChefCoinsManager.shared.awardSocialCoins(action: .share)

        // Track share streak
        Task {
            await StreakManager.shared.recordActivity(for: .socialShare)
        }

        // Update challenge progress
        ChallengeProgressTracker.shared.trackAction(.recipeShared, metadata: [
            "platform": platform.rawValue
        ])
    }

    // MARK: - Analytics

    private func trackShareInitiated(platform: SharePlatformType, content: ShareContent) {
        // Analytics tracking for share events
        let eventData: [String: Any] = [
            "platform": platform.rawValue,
            "content_type": String(describing: content),
            "timestamp": Date(),
            "user_id": UserDefaults.standard.string(forKey: "userId") ?? "anonymous"
        ]

        // Log to console for development/debugging
        print("📊 Share initiated: \(platform.rawValue) - \(eventData)")

        // Store analytics data locally for potential future upload
        storeAnalyticsEvent("share_initiated", data: eventData)
    }

    private func trackShareCompleted(platform: SharePlatformType, content: ShareContent) {
        // Analytics tracking for successful shares
        let eventData: [String: Any] = [
            "platform": platform.rawValue,
            "content_type": String(describing: content),
            "timestamp": Date(),
            "user_id": UserDefaults.standard.string(forKey: "userId") ?? "anonymous",
            "success": true
        ]

        // Log to console for development/debugging
        print("📊 Share completed: \(platform.rawValue) - \(eventData)")

        // Store analytics data locally for potential future upload
        storeAnalyticsEvent("share_completed", data: eventData)
    }

    private func trackShareFailed(platform: SharePlatformType, error: Error) {
        // Analytics tracking for failed shares
        let eventData: [String: Any] = [
            "platform": platform.rawValue,
            "error": error.localizedDescription,
            "timestamp": Date(),
            "user_id": UserDefaults.standard.string(forKey: "userId") ?? "anonymous",
            "success": false
        ]

        // Log to console for development/debugging
        print("📊 Share failed: \(platform.rawValue) - \(eventData)")

        // Store analytics data locally for potential future upload
        storeAnalyticsEvent("share_failed", data: eventData)
    }

    // MARK: - Local Analytics Storage

    private func storeAnalyticsEvent(_ eventName: String, data: [String: Any]) {
        // Store analytics events locally for potential future upload to analytics service
        var events = UserDefaults.standard.array(forKey: "analytics_events") as? [[String: Any]] ?? []

        var eventWithName = data
        eventWithName["event_name"] = eventName
        events.append(eventWithName)

        // Keep only last 1000 events to prevent excessive storage
        if events.count > 1_000 {
            events = Array(events.suffix(1_000))
        }

        UserDefaults.standard.set(events, forKey: "analytics_events")
    }
}

// MARK: - Share Errors (EXACT SPECIFICATION)
enum ShareError: Error, LocalizedError {
    case photoAccessDenied
    case saveFailed
    case fetchFailed
    case tiktokNotInstalled
    case shareFailed(String)
    case appNotInstalled(String)
    case missingImage
    case imageProcessingFailed
    case networkError
    case unknown

    var errorDescription: String? {
        switch self {
        case .photoAccessDenied:
            return "Photo library access denied. Please enable it in Settings."
        case .saveFailed:
            return "Failed to save video to Photos"
        case .fetchFailed:
            return "Failed to fetch PHAssets from photo library"
        case .tiktokNotInstalled:
            return "TikTok is not installed on this device"
        case .shareFailed(let message):
            return "Share failed: \(message)"
        case .appNotInstalled(let app):
            return "\(app) is not installed on this device"
        case .missingImage:
            return "No image available to share"
        case .imageProcessingFailed:
            return "Failed to process image for sharing"
        case .networkError:
            return "Network error occurred"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
