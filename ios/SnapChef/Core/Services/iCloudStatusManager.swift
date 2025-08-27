//
//  iCloudStatusManager.swift
//  SnapChef
//
//  Created on August 27, 2025
//  Manages iCloud account status checking and prompting
//

import Foundation
import CloudKit
import SwiftUI
import Combine

/// Manages iCloud account status and provides intelligent prompting
@MainActor
final class iCloudStatusManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = iCloudStatusManager()
    
    // MARK: - Published Properties
    
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var shouldShowiCloudPrompt = false
    @Published var hasCheckediCloudToday = false
    @Published var iCloudPromptContext: PromptContext?
    @Published var lastPromptDate: Date?
    @Published var promptDismissCount = 0
    @Published var hasSetupiCloud = false
    
    // MARK: - Types
    
    enum PromptContext {
        case appLaunch
        case afterOnboarding
        case beforeRecipeSave
        case beforeVideoShare
        case beforeChallengeJoin
        case reengagement(daysSinceInstall: Int)
        
        var title: String {
            switch self {
            case .appLaunch:
                return "Welcome to SnapChef! ☁️"
            case .afterOnboarding:
                return "One More Step to Get Started"
            case .beforeRecipeSave:
                return "Save Your Recipes Forever"
            case .beforeVideoShare:
                return "Share Your Creations"
            case .beforeChallengeJoin:
                return "Join the Community"
            case .reengagement(let days):
                return days > 7 ? "Don't Lose Your Progress!" : "Secure Your Recipes"
            }
        }
        
        var message: String {
            switch self {
            case .appLaunch:
                return "Sign in to iCloud to backup your recipes and sync across all your devices."
            case .afterOnboarding:
                return "To save your recipes and join challenges, you'll need to sign in to iCloud on this device."
            case .beforeRecipeSave:
                return "iCloud keeps your recipes safe and syncs them across all your Apple devices."
            case .beforeVideoShare:
                return "Sign in to iCloud to share your recipe videos with the SnapChef community."
            case .beforeChallengeJoin:
                return "Challenges require iCloud to track your progress and compete with other chefs."
            case .reengagement(let days):
                return "You've been using SnapChef for \(days) days! Sign in to iCloud to never lose your recipes."
            }
        }
        
        var benefits: [String] {
            switch self {
            case .appLaunch, .afterOnboarding:
                return [
                    "Automatic backup of all recipes",
                    "Sync across iPhone, iPad, and Mac",
                    "Never lose your cooking history",
                    "Join cooking challenges"
                ]
            case .beforeRecipeSave:
                return [
                    "Access recipes on all devices",
                    "Automatic backup",
                    "Share with friends"
                ]
            case .beforeVideoShare:
                return [
                    "Share to SnapChef community",
                    "Track views and likes",
                    "Go viral with your recipes"
                ]
            case .beforeChallengeJoin:
                return [
                    "Compete with other chefs",
                    "Win badges and rewards",
                    "Track your progress"
                ]
            case .reengagement:
                return [
                    "Keep your recipes forever",
                    "Access from any device",
                    "Join the community"
                ]
            }
        }
        
        var priority: Int {
            switch self {
            case .afterOnboarding: return 5
            case .beforeRecipeSave: return 4
            case .beforeVideoShare, .beforeChallengeJoin: return 3
            case .reengagement: return 2
            case .appLaunch: return 1
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
    private let checkInterval: TimeInterval = 86400 // 24 hours
    private let promptCooldown: TimeInterval = 21600 // 6 hours
    private var checkTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        loadSavedState()
        startMonitoring()
        checkInitialStatus()
    }
    
    // MARK: - Public Methods
    
    /// Check iCloud status and show prompt if needed
    func checkiCloudStatus(context: PromptContext? = nil) async {
        do {
            accountStatus = try await container.accountStatus()
            
            switch accountStatus {
            case .available:
                hasSetupiCloud = true
                shouldShowiCloudPrompt = false
                print("✅ iCloud is available and signed in")
                
            case .noAccount:
                hasSetupiCloud = false
                if shouldPromptUser(for: context ?? .appLaunch) {
                    iCloudPromptContext = context ?? .appLaunch
                    shouldShowiCloudPrompt = true
                    lastPromptDate = Date()
                    saveState()
                }
                print("⚠️ No iCloud account configured")
                
            case .restricted:
                print("🚫 iCloud is restricted on this device")
                hasSetupiCloud = false
                
            case .temporarilyUnavailable:
                print("⏳ iCloud is temporarily unavailable")
                // Don't change hasSetupiCloud, might be temporary
                
            case .couldNotDetermine:
                print("❓ Could not determine iCloud status")
                
            @unknown default:
                print("❓ Unknown iCloud status")
            }
            
        } catch {
            print("❌ Error checking iCloud status: \(error)")
            accountStatus = .couldNotDetermine
        }
    }
    
    /// Check if user should be prompted based on context and history
    func shouldPromptUser(for context: PromptContext) -> Bool {
        // Never prompt if user has dismissed too many times
        guard promptDismissCount < 3 else { return false }
        
        // Check cooldown period
        if let lastPrompt = lastPromptDate {
            let timeSinceLastPrompt = Date().timeIntervalSince(lastPrompt)
            guard timeSinceLastPrompt > promptCooldown else { return false }
        }
        
        // Context-specific rules
        switch context {
        case .appLaunch:
            // Only show on app launch if it's been 24+ hours
            return !hasCheckediCloudToday
            
        case .afterOnboarding:
            // Always show after onboarding (high priority)
            return true
            
        case .beforeRecipeSave, .beforeVideoShare, .beforeChallengeJoin:
            // Show for feature access (medium priority)
            return true
            
        case .reengagement(let days):
            // Show reengagement after certain days
            return days >= 3 && promptDismissCount < 2
        }
    }
    
    /// Open Settings app to iCloud sign-in
    func openiCloudSettings() {
        // Try to open iCloud settings directly
        if let url = URL(string: "App-prefs:CASTLE") {
            UIApplication.shared.open(url) { success in
                if !success {
                    // Fallback to general settings
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            }
        }
    }
    
    /// Handle user dismissing the prompt
    func dismissPrompt(permanently: Bool = false) {
        shouldShowiCloudPrompt = false
        promptDismissCount += 1
        
        if permanently {
            promptDismissCount = 99 // Effectively disable future prompts
        }
        
        saveState()
    }
    
    /// Reset prompt history (for testing or after successful setup)
    func resetPromptHistory() {
        promptDismissCount = 0
        lastPromptDate = nil
        hasCheckediCloudToday = false
        saveState()
    }
    
    // MARK: - Private Methods
    
    private func checkInitialStatus() {
        Task {
            await checkiCloudStatus(context: .appLaunch)
            hasCheckediCloudToday = true
            saveState()
        }
    }
    
    private func startMonitoring() {
        // Check iCloud status periodically
        checkTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
            Task {
                await self.checkiCloudStatus()
            }
        }
        
        // Listen for app becoming active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                Task {
                    // Check when app becomes active (user might have set up iCloud)
                    await self.checkiCloudStatus()
                }
            }
            .store(in: &cancellables)
        
        // Reset daily check at midnight
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           let midnight = calendar.dateComponents([.year, .month, .day], from: tomorrow).date {
            
            let timeToMidnight = midnight.timeIntervalSince(Date())
            Timer.scheduledTimer(withTimeInterval: timeToMidnight, repeats: false) { _ in
                Task { @MainActor in
                    self.hasCheckediCloudToday = false
                    self.saveState()
                    self.startDailyTimer()
                }
            }
        }
    }
    
    private func startDailyTimer() {
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            Task { @MainActor in
                self.hasCheckediCloudToday = false
                self.saveState()
            }
        }
    }
    
    private func loadSavedState() {
        let defaults = UserDefaults.standard
        hasCheckediCloudToday = defaults.bool(forKey: "hasCheckediCloudToday")
        promptDismissCount = defaults.integer(forKey: "iCloudPromptDismissCount")
        hasSetupiCloud = defaults.bool(forKey: "hasSetupiCloud")
        
        if let lastPromptTimestamp = defaults.object(forKey: "lastiCloudPromptDate") as? TimeInterval {
            lastPromptDate = Date(timeIntervalSince1970: lastPromptTimestamp)
        }
        
        // Check if it's a new day
        if let lastCheckDate = defaults.object(forKey: "lastiCloudCheckDate") as? Date {
            if !Calendar.current.isDateInToday(lastCheckDate) {
                hasCheckediCloudToday = false
            }
        }
    }
    
    private func saveState() {
        let defaults = UserDefaults.standard
        defaults.set(hasCheckediCloudToday, forKey: "hasCheckediCloudToday")
        defaults.set(promptDismissCount, forKey: "iCloudPromptDismissCount")
        defaults.set(hasSetupiCloud, forKey: "hasSetupiCloud")
        defaults.set(Date(), forKey: "lastiCloudCheckDate")
        
        if let lastPrompt = lastPromptDate {
            defaults.set(lastPrompt.timeIntervalSince1970, forKey: "lastiCloudPromptDate")
        }
    }
}

// MARK: - Analytics Extension

extension iCloudStatusManager {
    func trackPromptShown(context: PromptContext) {
        // Track analytics
        print("📊 iCloud prompt shown - Context: \(context)")
    }
    
    func trackPromptAction(action: String, context: PromptContext) {
        print("📊 iCloud prompt action: \(action) - Context: \(context)")
    }
    
    func trackiCloudSetupComplete() {
        print("📊 iCloud setup completed successfully")
        hasSetupiCloud = true
        resetPromptHistory()
    }
}