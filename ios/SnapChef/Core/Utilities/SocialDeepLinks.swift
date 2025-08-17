import Foundation
import UIKit

enum SocialPlatform: String, CaseIterable {
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case twitter = "X (Twitter)"
    case facebook = "Facebook"
    case whatsapp = "WhatsApp"

    var urlScheme: String {
        switch self {
        case .instagram: return "instagram://user?username="
        case .tiktok: return "tiktok://user?username="
        case .twitter: return "twitter://user?screen_name="
        case .facebook: return "fb://profile/"
        case .whatsapp: return "whatsapp://send?text="
        }
    }

    var webURL: String {
        switch self {
        case .instagram: return "https://instagram.com/"
        case .tiktok: return "https://tiktok.com/@"
        case .twitter: return "https://twitter.com/"
        case .facebook: return "https://facebook.com/"
        case .whatsapp: return "https://wa.me/?text="
        }
    }

    var icon: String {
        switch self {
        case .instagram: return "camera"
        case .tiktok: return "music.note"
        case .twitter: return "bubble.left"
        case .facebook: return "person.2"
        case .whatsapp: return "message"
        }
    }
}

class SocialDeepLinks {
    static let shared = SocialDeepLinks()

    private init() {}

    // MARK: - Open User Profile

    func openUserProfile(platform: SocialPlatform, username: String) {
        let cleanUsername = username.replacingOccurrences(of: "@", with: "")

        // Try native app first
        if let appURL = URL(string: platform.urlScheme + cleanUsername),
           UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = URL(string: platform.webURL + cleanUsername) {
            // Fallback to web
            UIApplication.shared.open(webURL)
        }
    }

    // MARK: - Share Content

    func shareRecipe(_ recipe: String, hashtags: [String] = ["SnapChef", "HomeCooking"]) {
        let text = recipe + "\n\n" + hashtags.map { "#\($0)" }.joined(separator: " ")
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let shareOptions: [(SocialPlatform, String)] = [
            (.instagram, "instagram://library?AssetPath=\(encodedText)"),
            (.tiktok, "tiktok://publish?text=\(encodedText)"),
            (.twitter, "twitter://post?message=\(encodedText)"),
            (.facebook, "fb://publish/profile/me?text=\(encodedText)"),
            (.whatsapp, "whatsapp://send?text=\(encodedText)")
        ]

        // Show share sheet with available apps
        showShareSheet(with: shareOptions, text: text)
    }

    func shareChallenge(_ challenge: String, inviteCode: String? = nil) {
        var text = "Join me in the \(challenge) challenge on SnapChef! 🎯"
        if let code = inviteCode {
            text += "\n\nUse code: \(code)"
        }
        text += "\n\n#SnapChef #CookingChallenge #FoodChallenge"

        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let shareOptions: [(SocialPlatform, String)] = [
            (.instagram, "instagram://library?AssetPath=\(encodedText)"),
            (.tiktok, "tiktok://publish?text=\(encodedText)"),
            (.twitter, "twitter://post?message=\(encodedText)"),
            (.facebook, "fb://publish/profile/me?text=\(encodedText)"),
            (.whatsapp, "whatsapp://send?text=\(encodedText)")
        ]

        showShareSheet(with: shareOptions, text: text)
    }

    // MARK: - Story Sharing

    func shareToInstagramStory(image: UIImage, stickerImage: UIImage? = nil) {
        guard let imageData = image.pngData() else { return }

        let pasteboardItems: [[String: Any]] = [
            ["com.instagram.sharedSticker.backgroundImage": imageData]
        ]

        if let stickerData = stickerImage?.pngData() {
            var items = pasteboardItems[0]
            items["com.instagram.sharedSticker.stickerImage"] = stickerData
        }

        UIPasteboard.general.setItems(pasteboardItems, options: [:])

        if let storiesURL = URL(string: "instagram-stories://share"),
           UIApplication.shared.canOpenURL(storiesURL) {
            UIApplication.shared.open(storiesURL)
        }
    }

    func shareToTikTok(videoURL: URL) {
        // TikTok requires video content
        let shareURL = "tiktok://publish?video_path=\(videoURL.absoluteString)"

        if let url = URL(string: shareURL),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Helper Methods

    private func showShareSheet(with options: [(SocialPlatform, String)], text: String) {
        var availableOptions: [URL] = []

        for (platform, urlString) in options {
            if let url = URL(string: urlString),
               UIApplication.shared.canOpenURL(url) {
                availableOptions.append(url)
            } else if let webURL = URL(string: platform.webURL + text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
                availableOptions.append(webURL)
            }
        }

        // If we have options, show the first one (in a real app, you'd show a menu)
        if let firstOption = availableOptions.first {
            UIApplication.shared.open(firstOption)
        } else {
            // Fallback to system share sheet
            shareViaSystemSheet(text: text)
        }
    }

    private func shareViaSystemSheet(text: String) {
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Check App Availability

    func isAppInstalled(_ platform: SocialPlatform) -> Bool {
        if let url = URL(string: platform.urlScheme) {
            return UIApplication.shared.canOpenURL(url)
        }
        return false
    }

    func availableSocialApps() -> [SocialPlatform] {
        return SocialPlatform.allCases.filter { isAppInstalled($0) }
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

struct SocialShareButton: View {
    let platform: SocialPlatform
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: platform.icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(platform.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.3))
            )
        }
    }
}

struct SocialShareMenu: View {
    let text: String
    let image: UIImage?
    @State private var showingShareSheet = false

    var body: some View {
        Menu {
            ForEach(SocialDeepLinks.shared.availableSocialApps(), id: \.self) { platform in
                Button(action: {
                    shareToSocial(platform)
                }) {
                    Label(platform.rawValue, systemImage: platform.icon)
                }
            }

            Divider()

            Button(action: {
                showingShareSheet = true
            }) {
                Label("More Options", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [text, image].compactMap { $0 })
        }
    }

    private func shareToSocial(_ platform: SocialPlatform) {
        switch platform {
        case .instagram:
            if let image = image {
                SocialDeepLinks.shared.shareToInstagramStory(image: image)
            }
        default:
            SocialDeepLinks.shared.shareRecipe(text)
        }
    }
}
