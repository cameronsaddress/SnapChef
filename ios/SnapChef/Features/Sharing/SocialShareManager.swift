import SwiftUI
import UIKit

struct SocialShareManager {
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
        text += "📱 Turn your fridge into a feast with AI\n\n"
        
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
}

// Helper to get the current view controller
extension View {
    func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
}