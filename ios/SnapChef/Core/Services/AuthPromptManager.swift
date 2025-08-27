//
//  AuthPromptManager.swift
//  SnapChef
//
//  Created on August 27, 2025
//  Main orchestrator for progressive authentication prompts
//

import SwiftUI
import Combine
import CloudKit

@MainActor
class AuthPromptManager: ObservableObject {
    static let shared = AuthPromptManager()
    
    // MARK: - Published Properties
    @Published var shouldShowPrompt = false
    @Published var currentPrompt: AuthPrompt?
    @Published var isShowingPrompt = false
    
    // MARK: - Private Properties
    private var promptQueue: [AuthPrompt] = []
    private var promptCooldown: Date?
    private let cooldownDuration: TimeInterval = 86400 // 24 hours
    private var hasShownInSession = false
    
    // MARK: - Models
    
    struct AuthPrompt: Identifiable {
        let id = UUID()
        let context: PromptContext
        let priority: Priority
        let timing: PromptTiming
        let content: PromptContent
        
        enum Priority: Int, Comparable {
            case low = 0
            case medium = 1
            case high = 2
            case critical = 3
            
            static func < (lhs: Priority, rhs: Priority) -> Bool {
                return lhs.rawValue < rhs.rawValue
            }
        }
    }
    
    enum PromptContext {
        case firstRecipeSuccess
        case viralContentCreated
        case dailyLimitReached
        case featureDiscovery(feature: String)
        case reengagement(day: Int)
        case shareIntent
        case challengeInterest
        case socialExploration
        case iCloudSetup
    }
    
    struct PromptContent {
        let title: String
        let message: String
        let benefits: [String]
        let primaryAction: String
        let secondaryAction: String
        let visualStyle: VisualStyle
        let icon: String?
        
        enum VisualStyle {
            case celebration
            case exciting
            case informative
            case urgent
            case friendly
        }
    }
    
    enum PromptTiming {
        case immediate
        case delayed(seconds: Double)
        case nextSession
    }
    
    enum DismissAction {
        case later
        case never
        case swipedAway
        case completed
    }
    
    // MARK: - Initialization
    
    private init() {
        loadPromptHistory()
    }
    
    // MARK: - Public Methods
    
    func evaluatePromptConditions(profile: AnonymousUserProfile) -> AuthPrompt? {
        // Don't show if user is already authenticated
        guard !UnifiedAuthManager.shared.isAuthenticated else { return nil }
        
        // Check cooldown
        if let cooldown = promptCooldown, Date() < cooldown {
            return nil
        }
        
        // Check if we've already shown a prompt this session
        if hasShownInSession {
            return nil
        }
        
        // Check for first recipe success
        if profile.recipesCreatedCount == 1 && !hasShownPrompt(for: .firstRecipeSuccess, in: profile) {
            return createPrompt(for: .firstRecipeSuccess, profile: profile)
        }
        
        // Check for viral content creation
        if profile.videosGeneratedCount >= 1 && profile.videosSharedCount >= 1 && !hasShownPrompt(for: .viralContentCreated, in: profile) {
            return createPrompt(for: .viralContentCreated, profile: profile)
        }
        
        // Check for reengagement
        let daysSinceFirstLaunch = Calendar.current.dateComponents([.day], from: profile.firstLaunchDate, to: Date()).day ?? 0
        if daysSinceFirstLaunch >= 3 && profile.appOpenCount >= 5 && !hasShownPrompt(for: .reengagement(day: daysSinceFirstLaunch), in: profile) {
            return createPrompt(for: .reengagement(day: daysSinceFirstLaunch), profile: profile)
        }
        
        // Check for challenge interest
        if profile.challengesViewed >= 3 && !hasShownPrompt(for: .challengeInterest, in: profile) {
            return createPrompt(for: .challengeInterest, profile: profile)
        }
        
        // Check for social exploration
        if profile.socialFeaturesExplored >= 5 && !hasShownPrompt(for: .socialExploration, in: profile) {
            return createPrompt(for: .socialExploration, profile: profile)
        }
        
        return nil
    }
    
    func showPrompt(_ prompt: AuthPrompt) {
        guard !isShowingPrompt else { return }
        
        currentPrompt = prompt
        hasShownInSession = true
        
        switch prompt.timing {
        case .immediate:
            isShowingPrompt = true
            shouldShowPrompt = true
        case .delayed(let seconds):
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
                self?.isShowingPrompt = true
                self?.shouldShowPrompt = true
            }
        case .nextSession:
            // Queue for next session
            promptQueue.append(prompt)
        }
        
        // Track analytics
        AuthenticationAnalytics.trackPromptShown(context: prompt.context)
    }
    
    func dismissPrompt(action: DismissAction) {
        isShowingPrompt = false
        shouldShowPrompt = false
        
        guard let prompt = currentPrompt else { return }
        
        switch action {
        case .later:
            // Set cooldown
            promptCooldown = Date().addingTimeInterval(cooldownDuration)
            savePromptEvent(context: prompt.context, action: "dismissed")
        case .never:
            // Mark as never ask
            savePromptEvent(context: prompt.context, action: "never")
            markNeverAsk(for: prompt.context)
        case .swipedAway:
            // Light dismissal, shorter cooldown
            promptCooldown = Date().addingTimeInterval(cooldownDuration / 2)
            savePromptEvent(context: prompt.context, action: "swiped")
        case .completed:
            // User authenticated!
            savePromptEvent(context: prompt.context, action: "completed")
        }
        
        // Track analytics
        AuthenticationAnalytics.trackPromptAction(action: action, context: prompt.context)
        
        currentPrompt = nil
    }
    
    func scheduleReengagementPrompt() {
        // Schedule a notification for tomorrow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 86400, repeats: false)
        let content = UNMutableNotificationContent()
        content.title = "Your recipes are waiting! 🍳"
        content.body = "Come back to create more amazing dishes with SnapChef"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "reengagement_prompt", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Private Methods
    
    private func createPrompt(for context: PromptContext, profile: AnonymousUserProfile) -> AuthPrompt {
        let content = AuthPromptContentFactory.createContent(for: context, profile: profile)
        let priority = getPriority(for: context)
        let timing = getTiming(for: context)
        
        return AuthPrompt(
            context: context,
            priority: priority,
            timing: timing,
            content: content
        )
    }
    
    private func getPriority(for context: PromptContext) -> AuthPrompt.Priority {
        switch context {
        case .iCloudSetup:
            return .critical
        case .dailyLimitReached:
            return .high
        case .firstRecipeSuccess, .viralContentCreated:
            return .medium
        case .reengagement, .challengeInterest, .socialExploration:
            return .low
        default:
            return .low
        }
    }
    
    private func getTiming(for context: PromptContext) -> PromptTiming {
        switch context {
        case .iCloudSetup, .dailyLimitReached:
            return .immediate
        case .firstRecipeSuccess, .viralContentCreated:
            return .delayed(seconds: 2.0)
        default:
            return .delayed(seconds: 1.0)
        }
    }
    
    private func hasShownPrompt(for context: PromptContext, in profile: AnonymousUserProfile) -> Bool {
        return profile.authPromptHistory.contains { event in
            event.context == contextToString(context)
        }
    }
    
    private func contextToString(_ context: PromptContext) -> String {
        switch context {
        case .firstRecipeSuccess: return "first_recipe"
        case .viralContentCreated: return "viral_content"
        case .dailyLimitReached: return "daily_limit"
        case .featureDiscovery(let feature): return "feature_\(feature)"
        case .reengagement(let day): return "reengagement_\(day)"
        case .shareIntent: return "share_intent"
        case .challengeInterest: return "challenge_interest"
        case .socialExploration: return "social_exploration"
        case .iCloudSetup: return "icloud_setup"
        }
    }
    
    private func savePromptEvent(context: PromptContext, action: String) {
        guard var profile = KeychainProfileManager.shared.loadProfile() else { return }
        
        let event = AnonymousUserProfile.AuthPromptEvent(
            date: Date(),
            context: contextToString(context),
            action: action
        )
        
        profile.authPromptHistory.append(event)
        
        if action == "completed" {
            profile.authenticationState = .authenticated
        } else if action == "never" {
            profile.authenticationState = .neverAsk
        } else if action == "dismissed" || action == "swiped" {
            profile.authenticationState = .dismissed
        }
        
        _ = KeychainProfileManager.shared.saveProfile(profile)
    }
    
    private func markNeverAsk(for context: PromptContext) {
        UserDefaults.standard.set(true, forKey: "never_ask_\(contextToString(context))")
    }
    
    private func loadPromptHistory() {
        if let cooldownDate = UserDefaults.standard.object(forKey: "auth_prompt_cooldown") as? Date {
            promptCooldown = cooldownDate
        }
    }
}

// MARK: - Authentication Analytics

struct AuthenticationAnalytics {
    static func trackPromptShown(context: AuthPromptManager.PromptContext) {
        // Track with your analytics provider
        print("📊 Auth prompt shown: \(context)")
    }
    
    static func trackPromptAction(action: AuthPromptManager.DismissAction, context: AuthPromptManager.PromptContext) {
        // Track with your analytics provider
        print("📊 Auth prompt action: \(action) for context: \(context)")
    }
    
    static func trackAuthenticationComplete(method: String, timeToAuth: TimeInterval) {
        // Track with your analytics provider
        print("📊 Authentication completed: \(method) in \(timeToAuth) seconds")
    }
}

// MARK: - Auth Prompt Content Factory

struct AuthPromptContentFactory {
    static func createContent(for context: AuthPromptManager.PromptContext, profile: AnonymousUserProfile) -> AuthPromptManager.PromptContent {
        switch context {
        case .firstRecipeSuccess:
            return AuthPromptManager.PromptContent(
                title: "Save Your Recipe Forever! ☁️",
                message: "Great job on your first recipe! Sign in to backup and access on all devices.",
                benefits: [
                    "Never lose your recipes",
                    "Access from any device",
                    "Share with friends"
                ],
                primaryAction: "Sign in with Apple",
                secondaryAction: "Maybe Later",
                visualStyle: .celebration,
                icon: "checkmark.seal.fill"
            )
            
        case .viralContentCreated:
            return AuthPromptManager.PromptContent(
                title: "Your Video is Ready to Go Viral! 🎬",
                message: "Sign in to share with the community and track your views.",
                benefits: [
                    "Share to the community",
                    "Track views and likes",
                    "Join viral challenges"
                ],
                primaryAction: "Sign in & Share",
                secondaryAction: "Skip for Now",
                visualStyle: .exciting,
                icon: "video.fill"
            )
            
        case .dailyLimitReached:
            return AuthPromptManager.PromptContent(
                title: "You've Reached Your Daily Limit 🎯",
                message: "Sign in to unlock unlimited recipes and premium features!",
                benefits: [
                    "Unlimited recipe generation",
                    "Premium features",
                    "No more waiting"
                ],
                primaryAction: "Unlock Premium",
                secondaryAction: "I'll Wait",
                visualStyle: .urgent,
                icon: "lock.open.fill"
            )
            
        case .reengagement(let days):
            return AuthPromptManager.PromptContent(
                title: "Welcome Back, Chef! 👨‍🍳",
                message: "You've been cooking with us for \(days) days! Don't lose your progress.",
                benefits: [
                    "Keep your \(profile.recipesCreatedCount) recipes safe",
                    "Continue your streak",
                    "Unlock new features"
                ],
                primaryAction: "Sign in to Continue",
                secondaryAction: "Not Now",
                visualStyle: .friendly,
                icon: "person.crop.circle.badge.checkmark"
            )
            
        case .challengeInterest:
            return AuthPromptManager.PromptContent(
                title: "Join Cooking Challenges! 🏆",
                message: "Compete with other chefs and win rewards!",
                benefits: [
                    "Compete in daily challenges",
                    "Win badges and rewards",
                    "Climb the leaderboard"
                ],
                primaryAction: "Sign in to Compete",
                secondaryAction: "Maybe Later",
                visualStyle: .exciting,
                icon: "trophy.fill"
            )
            
        case .socialExploration:
            return AuthPromptManager.PromptContent(
                title: "Join Our Community! 🌟",
                message: "Connect with fellow food lovers and share your creations.",
                benefits: [
                    "Follow your favorite chefs",
                    "Share your recipes",
                    "Get inspired daily"
                ],
                primaryAction: "Join Community",
                secondaryAction: "Browse Anonymously",
                visualStyle: .friendly,
                icon: "person.3.fill"
            )
            
        case .iCloudSetup:
            return AuthPromptManager.PromptContent(
                title: "Enable iCloud to Continue 📱",
                message: "SnapChef needs iCloud to save your recipes and sync across devices.",
                benefits: [
                    "Automatic backup",
                    "Sync across devices",
                    "Never lose your data"
                ],
                primaryAction: "Set Up iCloud",
                secondaryAction: "Learn More",
                visualStyle: .informative,
                icon: "icloud.fill"
            )
            
        default:
            return AuthPromptManager.PromptContent(
                title: "Unlock Full Experience! 🚀",
                message: "Sign in to save your progress and unlock all features.",
                benefits: [
                    "Save all your recipes",
                    "Join the community",
                    "Unlock premium features"
                ],
                primaryAction: "Sign in",
                secondaryAction: "Later",
                visualStyle: .informative,
                icon: "star.fill"
            )
        }
    }
}