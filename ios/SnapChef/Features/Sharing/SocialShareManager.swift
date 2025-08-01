import Foundation
import SwiftUI
import UIKit

// MARK: - Social Platform
enum SocialPlatform: String, CaseIterable {
    case tiktok = "TikTok"
    case instagram = "Instagram"
    case twitter = "Twitter"
    case facebook = "Facebook"
    case messages = "Messages"
    
    var icon: String {
        switch self {
        case .tiktok: return "music.note"
        case .instagram: return "camera"
        case .twitter: return "bird"
        case .facebook: return "f.circle"
        case .messages: return "message"
        }
    }
    
    var color: Color {
        switch self {
        case .tiktok: return Color(hex: "#000000")
        case .instagram: return Color(hex: "#E4405F")
        case .twitter: return Color(hex: "#1DA1F2")
        case .facebook: return Color(hex: "#1877F2")
        case .messages: return Color(hex: "#43e97b")
        }
    }
    
    var urlScheme: String? {
        switch self {
        case .tiktok: return "tiktok://"
        case .instagram: return "instagram://"
        case .twitter: return "twitter://"
        case .facebook: return "fb://"
        case .messages: return nil
        }
    }
}

// MARK: - Social Share Manager
@MainActor
class SocialShareManager: ObservableObject {
    static let shared = SocialShareManager()
    
    @Published var isSharing = false
    @Published var shareProgress: Double = 0
    @Published var pendingDeepLink: DeepLink?
    @Published var showRecipeFromDeepLink = false
    
    private let baseURL = "https://snapchef.app"
    private let appStoreURL = "https://apps.apple.com/app/snapchef/id1234567890" // TODO: Update with real App Store ID
    @Published var lastSharePlatform: SocialPlatform?
    @Published var shareCount = 0
    
    private init() {}
    
    // Check if platform is available
    func isPlatformAvailable(_ platform: SocialPlatform) -> Bool {
        guard let urlScheme = platform.urlScheme,
              let url = URL(string: urlScheme) else {
            return platform == .messages // Messages is always available
        }
        return UIApplication.shared.canOpenURL(url)
    }
    
    // Share to specific platform
    func share(image: UIImage, text: String, recipe: Recipe, to platform: SocialPlatform) async throws {
        isSharing = true
        shareProgress = 0
        
        // Simulate progress
        for i in 0...10 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await MainActor.run {
                shareProgress = Double(i) / 10.0
            }
        }
        
        // Platform-specific sharing
        switch platform {
        case .tiktok:
            try await shareToTikTok(image: image, text: text, recipe: recipe)
        case .instagram:
            try await shareToInstagram(image: image, text: text, recipe: recipe)
        case .twitter:
            try await shareToTwitter(text: text, recipe: recipe)
        case .facebook:
            try await shareToFacebook(image: image, text: text, recipe: recipe)
        case .messages:
            try await shareToMessages(image: image, text: text, recipe: recipe)
        }
        
        // Update stats
        lastSharePlatform = platform
        shareCount += 1
        isSharing = false
        
        // Track share analytics
        trackShare(platform: platform, recipe: recipe)
    }
    
    // Legacy support for SharePlatform enum
    static func shareToSocial(platform: SharePlatform, recipe: Recipe, message: String, from viewController: UIViewController) {
        let shareText = formatShareText(for: platform, recipe: recipe, message: message)
        let hashtags = getHashtags(for: platform)
        
        switch platform {
        case .tiktok:
            shareToTikTok(text: shareText, hashtags: hashtags, from: viewController)
        case .instagram:
            shareToInstagram(text: shareText, hashtags: hashtags, from: viewController)
        case .twitter:
            shareToTwitter(text: shareText, hashtags: hashtags, from: viewController)
        case .copy:
            UIPasteboard.general.string = shareText
        }
    }
    
    private static func formatShareText(for platform: SharePlatform, recipe: Recipe, message: String) -> String {
        var text = ""
        
        if !message.isEmpty {
            text += "\(message)\n\n"
        }
        
        text += "🍳 Just made \(recipe.name) with @SnapChef!\n"
        text += "⏱ Only \(recipe.cookTime + recipe.prepTime) minutes\n"
        text += "📱 AI-powered recipes from what you already have\n\n"
        
        if platform != .twitter { // Twitter has character limit
            text += "Get the app: snapchef.app"
        }
        
        return text
    }
    
    private static func getHashtags(for platform: SharePlatform) -> [String] {
        let baseHashtags = ["SnapChef", "AIRecipes", "HomeCooking", "FoodHack", "SmartCooking"]
        
        switch platform {
        case .tiktok:
            return baseHashtags + ["FoodTok", "CookingHacks", "RecipeOfTheDay", "TikTokFood"]
        case .instagram:
            return baseHashtags + ["InstaFood", "FoodStagram", "RecipeReels", "CookingReels"]
        case .twitter:
            return Array(baseHashtags.prefix(3)) // Fewer hashtags for Twitter
        case .copy:
            return baseHashtags
        }
    }
    
    private static func shareToTikTok(text: String, hashtags: [String], from viewController: UIViewController) {
        // TikTok doesn't have a direct share API, so we'll use the system share sheet
        // with a note to open TikTok
        let hashtagString = hashtags.map { "#\($0)" }.joined(separator: " ")
        let fullText = "\(text)\n\n\(hashtagString)\n\n📸 Take a photo of your finished dish and share on TikTok!"
        
        showShareSheet(
            items: [fullText],
            applicationActivities: nil,
            from: viewController,
            completion: {
                // Optionally try to open TikTok
                if let url = URL(string: "tiktok://"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
        )
    }
    
    private static func shareToInstagram(text: String, hashtags: [String], from viewController: UIViewController) {
        let hashtagString = hashtags.map { "#\($0)" }.joined(separator: " ")
        let fullText = "\(text)\n\n\(hashtagString)"
        
        // Copy text to clipboard for easy paste
        UIPasteboard.general.string = fullText
        
        // Show share sheet with instruction
        showShareSheet(
            items: [fullText, "📸 Text copied! Take a photo of your dish and paste this caption in Instagram"],
            applicationActivities: nil,
            from: viewController,
            completion: {
                // Try to open Instagram
                if let url = URL(string: "instagram://camera"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else if let url = URL(string: "instagram://"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
        )
    }
    
    private static func shareToTwitter(text: String, hashtags: [String], from viewController: UIViewController) {
        let hashtagString = hashtags.map { "#\($0)" }.joined(separator: " ")
        let tweetText = "\(text) \(hashtagString)"
        
        // Try Twitter app first, then web
        let twitterURL = "twitter://post?text=\(tweetText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        let twitterWebURL = "https://twitter.com/intent/tweet?text=\(tweetText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: twitterURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: twitterWebURL) {
            UIApplication.shared.open(url)
        } else {
            // Fallback to share sheet
            showShareSheet(items: [tweetText], applicationActivities: nil, from: viewController)
        }
    }
    
    private static func showShareSheet(
        items: [Any],
        applicationActivities: [UIActivity]?,
        from viewController: UIViewController,
        completion: (() -> Void)? = nil
    ) {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: applicationActivities
        )
        
        // For iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        activityViewController.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                completion?()
            }
        }
        
        viewController.present(activityViewController, animated: true)
    }
    
    // MARK: - Enhanced Platform Specific Methods
    
    private func shareToTikTok(image: UIImage, text: String, recipe: Recipe) async throws {
        // Save image temporarily
        let imageData = image.jpegData(compressionQuality: 0.9)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("snapchef_share.jpg")
        try imageData?.write(to: tempURL)
        
        // Create TikTok share URL with hashtags
        _ = "#FridgeChallenge #SnapChef #CookingMagic #\(recipe.difficulty.rawValue)Recipe"
        
        // Note: Real TikTok integration would use their SDK
        // For now, open the app with a deep link
        if let url = URL(string: "tiktok://") {
            await UIApplication.shared.open(url)
        }
    }
    
    private func shareToInstagram(image: UIImage, text: String, recipe: Recipe) async throws {
        // Instagram Stories sharing
        guard let imageData = image.pngData() else { return }
        
        let pasteboardItems: [[String: Any]] = [
            [
                "com.instagram.sharedSticker.stickerImage": imageData,
                "com.instagram.sharedSticker.backgroundTopColor": "#667eea",
                "com.instagram.sharedSticker.backgroundBottomColor": "#764ba2"
            ]
        ]
        
        let pasteboardOptions = [
            UIPasteboard.OptionsKey.expirationDate: Date().addingTimeInterval(300)
        ]
        
        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)
        
        if let url = URL(string: "instagram-stories://share") {
            await UIApplication.shared.open(url)
        }
    }
    
    private func shareToTwitter(text: String, recipe: Recipe) async throws {
        let tweetText = "\(text)\n\nMade with @SnapChef 🔥"
        let encodedText = tweetText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "twitter://post?message=\(encodedText)") {
            await UIApplication.shared.open(url)
        } else if let webURL = URL(string: "https://twitter.com/intent/tweet?text=\(encodedText)") {
            await UIApplication.shared.open(webURL)
        }
    }
    
    private func shareToFacebook(image: UIImage, text: String, recipe: Recipe) async throws {
        // Facebook sharing would use their SDK
        // For now, just open the app
        if let url = URL(string: "fb://") {
            await UIApplication.shared.open(url)
        }
    }
    
    private func shareToMessages(image: UIImage, text: String, recipe: Recipe) async throws {
        // This would be handled by the share sheet
        // Just marking as complete for now
    }
    
    // MARK: - Analytics
    
    private func trackShare(platform: SocialPlatform, recipe: Recipe) {
        // Track sharing analytics
        print("Tracked share: \(platform.rawValue) - \(recipe.name)")
        
        // Would send to analytics service
        // Analytics.track("recipe_shared", properties: [
        //     "platform": platform.rawValue,
        //     "recipe_id": recipe.id,
        //     "recipe_name": recipe.name,
        //     "difficulty": recipe.difficulty.rawValue
        // ])
    }
    
    // MARK: - Share Incentives
    
    func calculateShareRewards() -> ShareReward {
        let multiplier = min(shareCount / 10 + 1, 5) // Max 5x multiplier
        let points = 50 * multiplier
        
        return ShareReward(
            points: points,
            multiplier: multiplier,
            nextMilestone: (shareCount / 10 + 1) * 10,
            badge: getBadgeForShareCount(shareCount)
        )
    }
    
    private func getBadgeForShareCount(_ count: Int) -> String? {
        switch count {
        case 1: return "First Share! 🎉"
        case 5: return "Social Butterfly 🦋"
        case 10: return "Influencer Status 📱"
        case 25: return "Viral Chef 🔥"
        case 50: return "Share Master 👑"
        case 100: return "Legendary Sharer 🏆"
        default: return nil
        }
    }
    
    // MARK: - Deep Link Types
    enum DeepLink {
        case recipe(String)
        case profile(String)
        case challenge(String)
        
        var path: String {
            switch self {
            case .recipe(let id):
                return "recipe/\(id)"
            case .profile(let id):
                return "profile/\(id)"
            case .challenge(let id):
                return "challenge/\(id)"
            }
        }
    }
    
    // MARK: - URL Generation
    
    func generateRecipeShareURL(recipeID: String) -> URL {
        let deepLinkPath = DeepLink.recipe(recipeID).path
        let urlString = "\(baseURL)/\(deepLinkPath)"
        return URL(string: urlString)!
    }
    
    func generateUniversalLink(for recipe: Recipe, cloudKitRecordID: String) -> URL {
        let urlString = "\(baseURL)/recipe/\(cloudKitRecordID)"
        return URL(string: urlString)!
    }
    
    // MARK: - URL Handling
    
    func handleIncomingURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return false
        }
        
        // Handle different URL schemes
        if url.scheme == "snapchef" {
            return handleCustomSchemeURL(components)
        } else if url.host == "snapchef.app" {
            return handleUniversalLink(components)
        }
        
        return false
    }
    
    private func handleCustomSchemeURL(_ components: URLComponents) -> Bool {
        guard let host = components.host else { return false }
        
        switch host {
        case "recipe":
            if let recipeID = components.path.split(separator: "/").last {
                pendingDeepLink = .recipe(String(recipeID))
                showRecipeFromDeepLink = true
                return true
            }
        case "profile":
            if let userID = components.path.split(separator: "/").last {
                pendingDeepLink = .profile(String(userID))
                return true
            }
        case "challenge":
            if let challengeID = components.path.split(separator: "/").last {
                pendingDeepLink = .challenge(String(challengeID))
                return true
            }
        default:
            break
        }
        
        return false
    }
    
    private func handleUniversalLink(_ components: URLComponents) -> Bool {
        let pathComponents = components.path.split(separator: "/").map(String.init)
        
        guard pathComponents.count >= 2 else { return false }
        
        switch pathComponents[0] {
        case "recipe":
            pendingDeepLink = .recipe(pathComponents[1])
            showRecipeFromDeepLink = true
            return true
        case "profile":
            pendingDeepLink = .profile(pathComponents[1])
            return true
        case "challenge":
            pendingDeepLink = .challenge(pathComponents[1])
            return true
        default:
            return false
        }
    }
    
    func resolvePendingDeepLink() {
        guard let deepLink = pendingDeepLink else { return }
        
        switch deepLink {
        case .recipe(let recipeID):
            print("Opening recipe: \(recipeID)")
        case .profile(let userID):
            print("Opening profile: \(userID)")
        case .challenge(let challengeID):
            print("Opening challenge: \(challengeID)")
        }
        
        pendingDeepLink = nil
    }
}

// MARK: - Share Reward Model
struct ShareReward {
    let points: Int
    let multiplier: Int
    let nextMilestone: Int
    let badge: String?
}

