import SwiftUI
import UIKit
import Social
import UserNotifications
import Photos

// MARK: - Notification Category
enum NotificationCategory: String {
    case newChallenge = "NEW_CHALLENGE"
    case challengeReminder = "CHALLENGE_REMINDER"
    case challengeCompleted = "CHALLENGE_COMPLETED"
}

// MARK: - Challenge Sharing Manager
@MainActor
class ChallengeSharingManager: ObservableObject {
    static let shared = ChallengeSharingManager()
    
    @Published var isGeneratingShare = false
    @Published var generatedShareImage: UIImage?
    @Published var shareProgress: Double = 0
    
    private lazy var gamificationManager = GamificationManager.shared
    
    // Social Platform Types
    enum SocialPlatform: String, CaseIterable {
        case instagram = "Instagram"
        case twitter = "Twitter"
        case facebook = "Facebook"
        case snapchat = "Snapchat"
        case tiktok = "TikTok"
        case general = "Share"
        
        var icon: String {
            switch self {
            case .instagram: return "camera.fill"
            case .twitter: return "bird.fill"
            case .facebook: return "f.circle.fill"
            case .snapchat: return "ghost.fill"
            case .tiktok: return "music.note"
            case .general: return "square.and.arrow.up"
            }
        }
        
        var color: Color {
            switch self {
            case .instagram: return Color(hex: "#E4405F")
            case .twitter: return Color(hex: "#1DA1F2")
            case .facebook: return Color(hex: "#1877F2")
            case .snapchat: return Color(hex: "#FFFC00")
            case .tiktok: return Color(hex: "#000000")
            case .general: return Color(hex: "#667eea")
            }
        }
        
        var hashtagSuggestions: [String] {
            switch self {
            case .instagram:
                return ["#SnapChefChallenge", "#CookingChallenge", "#FoodieChallenge", "#HomeCooking", "#RecipeChallenge"]
            case .twitter:
                return ["#SnapChef", "#CookingChallenge", "#FoodTwitter", "#RecipeOfTheDay"]
            case .facebook:
                return ["#SnapChefChallenge", "#CookingAtHome", "#RecipeShare", "#FoodChallenge"]
            case .snapchat:
                return ["SnapChefWin", "CookingChallenge", "FoodSnap"]
            case .tiktok:
                return ["#SnapChefChallenge", "#CookingChallenge", "#FoodTok", "#RecipeChallenge", "#CookWithMe"]
            case .general:
                return ["#SnapChef", "#CookingChallenge", "#FoodChallenge"]
            }
        }
    }
    
    // Share Content Types
    enum ShareContentType {
        case challengeComplete(Challenge)
        case levelUp(Int)
        case streakMilestone(Int)
        case leaderboardRank(Int, LeaderboardScope)
        case badgeUnlocked(GameBadge)
        case weeklyStats
        
        enum LeaderboardScope {
            case weekly, monthly, allTime
        }
    }
    
    private init() {}
    
    // MARK: - Share Generation
    
    func generateShareContent(
        type: ShareContentType,
        platform: SocialPlatform,
        customMessage: String? = nil
    ) async -> (image: UIImage?, text: String) {
        await MainActor.run {
            isGeneratingShare = true
            shareProgress = 0
        }
        
        let shareView = createShareView(for: type, platform: platform)
        let shareText = generateShareText(for: type, platform: platform, customMessage: customMessage)
        
        // Render the view to an image
        let renderer = ImageRenderer(content: shareView)
        renderer.scale = 3.0 // High quality
        
        let image = renderer.uiImage
        
        await MainActor.run {
            generatedShareImage = image
            isGeneratingShare = false
            shareProgress = 1.0
        }
        
        // Track share analytics
        trackShareAnalytics(type: type, platform: platform)
        
        return (image, shareText)
    }
    
    // MARK: - Share View Creation
    
    @ViewBuilder
    private func createShareView(for type: ShareContentType, platform: SocialPlatform) -> some View {
        ZStack {
            // Background
            ShareBackgroundView(platform: platform)
            
            // Content
            switch type {
            case .challengeComplete(let challenge):
                ChallengeCompleteShareView(challenge: challenge, platform: platform)
                
            case .levelUp(let level):
                LevelUpShareView(level: level, platform: platform)
                
            case .streakMilestone(let days):
                StreakMilestoneShareView(days: days, platform: platform)
                
            case .leaderboardRank(let rank, let scope):
                LeaderboardRankShareView(rank: rank, scope: scope, platform: platform)
                
            case .badgeUnlocked(let badge):
                BadgeUnlockedShareView(badge: badge, platform: platform)
                
            case .weeklyStats:
                WeeklyStatsShareView(stats: gamificationManager.userStats, platform: platform)
            }
        }
        .frame(width: 1080, height: 1920) // Instagram story size
    }
    
    // MARK: - Share Text Generation
    
    private func generateShareText(
        for type: ShareContentType,
        platform: SocialPlatform,
        customMessage: String?
    ) -> String {
        var text = ""
        
        // Add custom message if provided
        if let customMessage = customMessage {
            text = customMessage + "\n\n"
        }
        
        // Generate type-specific text
        switch type {
        case .challengeComplete(let challenge):
            text += "🎉 Challenge Complete! I just finished \"\(challenge.title)\" and earned \(challenge.points) points! 🔥\n\n"
            
        case .levelUp(let level):
            text += "🆙 LEVEL UP! Just reached Level \(level) on SnapChef! 🎊\n\n"
            
        case .streakMilestone(let days):
            text += "🔥 \(days)-DAY STREAK! I've been cooking with SnapChef for \(days) days straight! 💪\n\n"
            
        case .leaderboardRank(let rank, let scope):
            let scopeText = scope == .weekly ? "this week" : scope == .monthly ? "this month" : "all-time"
            text += "🏆 Ranked #\(rank) \(scopeText) on SnapChef! Think you can beat me? 😎\n\n"
            
        case .badgeUnlocked(let badge):
            text += "🏅 New Badge Unlocked: \(badge.name)! \(badge.description) ✨\n\n"
            
        case .weeklyStats:
            let stats = gamificationManager.userStats
            text += """
            📊 My SnapChef Weekly Stats:
            • Level \(stats.level) Chef
            • \(stats.recipesCreated) Recipes Created
            • \(stats.currentStreak) Day Streak
            • \(stats.challengesCompleted) Challenges Completed
            
            """
        }
        
        // Add call to action
        text += "Join me on SnapChef and start your cooking journey! 👨‍🍳\n\n"
        
        // Add platform-specific hashtags
        let hashtags = platform.hashtagSuggestions.joined(separator: " ")
        text += hashtags
        
        return text
    }
    
    // MARK: - Social Platform Integration
    
    func shareToSocialPlatform(
        _ platform: SocialPlatform,
        image: UIImage?,
        text: String,
        url: URL? = nil,
        from viewController: UIViewController
    ) {
        switch platform {
        case .instagram:
            shareToInstagram(image: image, from: viewController)
        case .twitter:
            shareToTwitter(text: text, image: image, url: url, from: viewController)
        case .facebook:
            shareToFacebook(text: text, image: image, url: url, from: viewController)
        case .snapchat:
            shareToSnapchat(image: image, from: viewController)
        case .tiktok:
            shareToTikTok(image: image, from: viewController)
        case .general:
            showGeneralShareSheet(items: [text, image].compactMap { $0 }, from: viewController)
        }
        
        // Award social sharing points
        awardSocialSharingPoints(platform: platform)
    }
    
    private func shareToInstagram(image: UIImage?, from viewController: UIViewController) {
        guard let image = image else { return }
        
        // Save to camera roll with permission handling
        saveImageToPhotoLibrary(image)
        
        // Open Instagram
        if let instagramURL = URL(string: "instagram://library?LocalIdentifier=\(UUID().uuidString)") {
            if UIApplication.shared.canOpenURL(instagramURL) {
                UIApplication.shared.open(instagramURL)
            } else {
                showAlert(title: "Instagram Not Installed", message: "Please install Instagram to share directly.", on: viewController)
            }
        }
    }
    
    private func shareToTwitter(text: String, image: UIImage?, url: URL?, from viewController: UIViewController) {
        if SLComposeViewController.isAvailable(forServiceType: SLServiceTypeTwitter) {
            if let twitterVC = SLComposeViewController(forServiceType: SLServiceTypeTwitter) {
                twitterVC.setInitialText(text)
                if let image = image {
                    twitterVC.add(image)
                }
                if let url = url {
                    twitterVC.add(url)
                }
                viewController.present(twitterVC, animated: true)
            }
        } else {
            // Fallback to Twitter app or web
            let twitterText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let twitterURL = URL(string: "twitter://post?message=\(twitterText)") {
                if UIApplication.shared.canOpenURL(twitterURL) {
                    UIApplication.shared.open(twitterURL)
                } else if let webURL = URL(string: "https://twitter.com/intent/tweet?text=\(twitterText)") {
                    UIApplication.shared.open(webURL)
                }
            }
        }
    }
    
    private func shareToFacebook(text: String, image: UIImage?, url: URL?, from viewController: UIViewController) {
        if SLComposeViewController.isAvailable(forServiceType: SLServiceTypeFacebook) {
            if let facebookVC = SLComposeViewController(forServiceType: SLServiceTypeFacebook) {
                facebookVC.setInitialText(text)
                if let image = image {
                    facebookVC.add(image)
                }
                if let url = url {
                    facebookVC.add(url)
                }
                viewController.present(facebookVC, animated: true)
            }
        } else {
            showGeneralShareSheet(items: [text, image].compactMap { $0 }, from: viewController)
        }
    }
    
    private func shareToSnapchat(image: UIImage?, from viewController: UIViewController) {
        guard let image = image else { return }
        
        // Save to camera roll with permission handling
        saveImageToPhotoLibrary(image)
        
        // Open Snapchat
        if let snapchatURL = URL(string: "snapchat://") {
            if UIApplication.shared.canOpenURL(snapchatURL) {
                UIApplication.shared.open(snapchatURL)
            } else {
                showAlert(title: "Snapchat Not Installed", message: "Please install Snapchat to share directly.", on: viewController)
            }
        }
    }
    
    private func shareToTikTok(image: UIImage?, from viewController: UIViewController) {
        guard let image = image else { return }
        
        // Save to camera roll with permission handling
        saveImageToPhotoLibrary(image)
        
        // Open TikTok
        if let tiktokURL = URL(string: "tiktok://") {
            if UIApplication.shared.canOpenURL(tiktokURL) {
                UIApplication.shared.open(tiktokURL)
            } else {
                showAlert(title: "TikTok Not Installed", message: "Please install TikTok to share directly.", on: viewController)
            }
        }
    }
    
    private func showGeneralShareSheet(items: [Any], from viewController: UIViewController) {
        let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // For iPad
        if let popover = activityController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityController, animated: true)
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) {
        // Check current authorization status first
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            // Already have permission, save the image
            PHPhotoLibrary.shared().performChanges({
                _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if !success {
                    print("Failed to save challenge image: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
            
        case .notDetermined:
            // Need to request permission
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    PHPhotoLibrary.shared().performChanges({
                        _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }) { success, error in
                        if !success {
                            print("Failed to save challenge image: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                }
            }
            
        case .denied, .restricted:
            print("Photo library access denied for challenge sharing")
            
        @unknown default:
            print("Unknown photo library authorization status")
        }
    }
    
    private func showAlert(title: String, message: String, on viewController: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
    
    // MARK: - Friend Challenge System
    
    func createFriendChallenge(
        challengeType: String,
        friendUsername: String,
        stakes: Int,
        duration: TimeInterval
    ) async throws {
        // Create a custom challenge for friends
        let challenge = Challenge(
            title: "Friend Challenge: \(challengeType)",
            description: "Challenge between you and \(friendUsername)",
            type: .special,
            points: stakes,
            coins: stakes / 10,
            endDate: Date().addingTimeInterval(duration),
            requirements: ["Complete within time limit"],
            currentProgress: 0,
            participants: 2
        )
        
        // Save to CloudKit and notify friend
        try await CloudKitManager.shared.createFriendChallenge(challenge, withFriend: friendUsername)
        
        // Send notification
        ChallengeNotificationManager.shared.notifyFriendChallengeInvite(
            from: UserDefaults.standard.string(forKey: "username") ?? "A friend",
            challengeName: challengeType
        )
    }
    
    // MARK: - Analytics & Rewards
    
    private func awardSocialSharingPoints(platform: SocialPlatform) {
        // Award points for sharing
        let points = platform == .general ? 10 : 25
        gamificationManager.awardPoints(points, reason: "Shared on \(platform.rawValue)")
        
        // Update sharing stats
        let sharesCount = UserDefaults.standard.integer(forKey: "socialShares") + 1
        UserDefaults.standard.set(sharesCount, forKey: "socialShares")
        
        // Check for sharing achievements
        switch sharesCount {
        case 1:
            gamificationManager.awardBadge("First Share")
        case 10:
            gamificationManager.awardBadge("Social Butterfly")
        case 50:
            gamificationManager.awardBadge("Influencer")
        case 100:
            gamificationManager.awardBadge("Social Media Master")
        default:
            break
        }
    }
    
    private func trackShareAnalytics(type: ShareContentType, platform: SocialPlatform) {
        // Track share event
        var eventParams: [String: Any] = [
            "platform": platform.rawValue,
            "timestamp": Date()
        ]
        
        switch type {
        case .challengeComplete(let challenge):
            eventParams["type"] = "challenge_complete"
            eventParams["challenge_name"] = challenge.title
        case .levelUp(let level):
            eventParams["type"] = "level_up"
            eventParams["level"] = level
        case .streakMilestone(let days):
            eventParams["type"] = "streak_milestone"
            eventParams["days"] = days
        case .leaderboardRank(let rank, _):
            eventParams["type"] = "leaderboard_rank"
            eventParams["rank"] = rank
        case .badgeUnlocked(let badge):
            eventParams["type"] = "badge_unlocked"
            eventParams["badge_name"] = badge.name
        case .weeklyStats:
            eventParams["type"] = "weekly_stats"
        }
        
        // Send to analytics service
        // TODO: Add analytics when AnalyticsService is available
        // AnalyticsService.shared.trackEvent("social_share", parameters: eventParams)
    }
}

// MARK: - Share View Components

struct ShareBackgroundView: View {
    let platform: ChallengeSharingManager.SocialPlatform
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(hex: "#667eea"),
                    Color(hex: "#764ba2"),
                    platform.color
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Pattern overlay
            GeometryReader { geometry in
                ForEach(0..<30) { _ in
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: CGFloat.random(in: 50...150))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                }
            }
        }
    }
}

struct ChallengeCompleteShareView: View {
    let challenge: Challenge
    let platform: ChallengeSharingManager.SocialPlatform
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Trophy icon
            Image(systemName: "trophy.fill")
                .font(.system(size: 120))
                .foregroundColor(.yellow)
                .shadow(color: .black.opacity(0.3), radius: 20)
            
            // Challenge title
            Text("CHALLENGE COMPLETE!")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(challenge.title)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Reward
            VStack(spacing: 16) {
                Text("Earned")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("\(challenge.points) Points")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
            }
            
            Spacer()
            
            // App branding
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                
                Text("SnapChef")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 80)
        }
    }
}

struct LevelUpShareView: View {
    let level: Int
    let platform: ChallengeSharingManager.SocialPlatform
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Level badge
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.yellow, Color.orange],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .shadow(color: .yellow.opacity(0.5), radius: 30)
                
                VStack(spacing: 8) {
                    Text("LEVEL")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(level)")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            
            Text("LEVEL UP!")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            // App branding
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                
                Text("SnapChef")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 80)
        }
    }
}

struct StreakMilestoneShareView: View {
    let days: Int
    let platform: ChallengeSharingManager.SocialPlatform
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Flame icon
            Image(systemName: "flame.fill")
                .font(.system(size: 120))
                .foregroundColor(.orange)
                .shadow(color: .orange.opacity(0.5), radius: 30)
            
            // Streak count
            VStack(spacing: 16) {
                Text("\(days)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("DAY STREAK")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Text("On Fire! 🔥")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
            
            Spacer()
            
            // App branding
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                
                Text("SnapChef")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 80)
        }
    }
}

struct LeaderboardRankShareView: View {
    let rank: Int
    let scope: ChallengeSharingManager.ShareContentType.LeaderboardScope
    let platform: ChallengeSharingManager.SocialPlatform
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Rank display
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                    .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 30)
                
                VStack(spacing: 8) {
                    Text("#\(rank)")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(scopeText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            Text("LEADERBOARD")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            // App branding
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                
                Text("SnapChef")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 80)
        }
    }
    
    var scopeText: String {
        switch scope {
        case .weekly: return "THIS WEEK"
        case .monthly: return "THIS MONTH"
        case .allTime: return "ALL TIME"
        }
    }
}



struct BadgeUnlockedShareView: View {
    let badge: GameBadge
    let platform: ChallengeSharingManager.SocialPlatform
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Badge icon
            ZStack {
                Circle()
                    .fill(badge.rarity.color)
                    .frame(width: 180, height: 180)
                    .shadow(color: badge.rarity.color.opacity(0.5), radius: 30)
                
                Image(systemName: badge.icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)
            }
            
            // Badge info
            VStack(spacing: 16) {
                Text("NEW BADGE")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(badge.name)
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Text(badge.rarity.rawValue.uppercased())
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(badge.rarity.color)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white)
                    )
            }
            
            Spacer()
            
            // App branding
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                
                Text("SnapChef")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 80)
        }
    }
}

struct WeeklyStatsShareView: View {
    let stats: UserGameStats
    let platform: ChallengeSharingManager.SocialPlatform
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Text("WEEKLY STATS")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            // Stats grid
            VStack(spacing: 30) {
                HStack(spacing: 40) {
                    StatCard(icon: "star.fill", value: "\(stats.level)", label: "Level")
                    StatCard(icon: "flame.fill", value: "\(stats.currentStreak)", label: "Streak")
                }
                
                HStack(spacing: 40) {
                    StatCard(icon: "fork.knife", value: "\(stats.recipesCreated)", label: "Recipes")
                    StatCard(icon: "trophy.fill", value: "\(stats.challengesCompleted)", label: "Challenges")
                }
            }
            
            // Total points
            VStack(spacing: 8) {
                Text("\(stats.totalPoints)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                
                Text("TOTAL POINTS")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // App branding
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                
                Text("SnapChef")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 80)
        }
        .padding(.horizontal, 40)
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.white)
            
            Text(value)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(width: 150)
    }
}

// MARK: - CloudKit Manager Extension
extension CloudKitManager {
    func createFriendChallenge(_ challenge: Challenge, withFriend username: String) async throws {
        // Implementation would create challenge in CloudKit and notify friend
        print("Creating friend challenge with \(username)")
    }
}

// MARK: - Notification Manager Extension
extension ChallengeNotificationManager {
    func notifyFriendChallengeInvite(from userName: String, challengeName: String) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Challenge Invite! ⚔️"
        content.body = "\(userName) challenged you to \(challengeName)! Are you ready?"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.newChallenge.rawValue
        
        let request = UNNotificationRequest(
            identifier: "friend_challenge_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        Task.detached {
            let center = UNUserNotificationCenter.current()
            try? await center.add(request)
        }
    }
}