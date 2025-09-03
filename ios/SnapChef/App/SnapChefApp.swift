//
//  SnapChefApp.swift
//  SnapChef
//
//  Created by Apple on 2024-07-25.
//

import SwiftUI
import CloudKit
import Combine

@main
struct SnapChefApp: App {
    // Connect the UIKit AppDelegate for TikTok SDK
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Create new instances for @StateObject to manage their lifecycle.
    @StateObject private var appState = AppState()
    @StateObject private var authManager = UnifiedAuthManager.shared
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var gamificationManager = GamificationManager()

    // Use the shared singleton instances, managed by @StateObject, to ensure
    // SwiftUI observes changes and triggers view updates.
    @StateObject private var socialShareManager = SocialShareManager.shared
    @StateObject private var cloudKitSyncService = CloudKitSyncService.shared
    @StateObject private var cloudKitDataManager = CloudKitDataManager.shared
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject all dependencies into the environment.
                .environmentObject(appState)
                .environmentObject(authManager)
                .environmentObject(deviceManager)
                .environmentObject(gamificationManager)
                .environmentObject(socialShareManager)
                .environmentObject(cloudKitSyncService)
                .environmentObject(cloudKitDataManager)
                .environmentObject(notificationManager)

                .preferredColorScheme(.dark)

                .onAppear {
                    setupApp()
                }

                .onOpenURL { url in
                    handleIncomingURL(url)
                }

                // The sheet is now presented using the singleton's property, and
                // its environment objects are passed down from SnapChefApp,
                // ensuring consistency.
                .sheet(isPresented: $socialShareManager.showRecipeFromDeepLink) {
                    DeepLinkRecipeView()
                        // These are the instances managed by this App struct.
                        .environmentObject(socialShareManager)
                        .environmentObject(cloudKitSyncService)
                }

                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    Task {
                        await cloudKitDataManager.endAppSession()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    Task {
                        await cloudKitDataManager.endAppSession()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Memory management will be handled by item count limits, not time-based clearing
                    // Tasks will be properly cancelled in managers
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task { @MainActor in
                        // Preload fresh data when coming to foreground
                        if UnifiedAuthManager.shared.isAuthenticated {
                            await ActivityFeedManager.shared.preloadInBackground()
                            await SimpleDiscoverUsersManager.shared.loadUsers(for: .suggested)
                        }
                    }
                }
        }
    }

    // MARK: - App Setup Functions

    private func setupApp() {
        configureNavigationBar()
        configureTableView()
        configureWindow()
        configureImageCache()

        // Check CloudKit environment (determined by Xcode build configuration)
        detectCloudKitEnvironment()

        // Set default LLM provider to Gemini if not already set
        if UserDefaults.standard.object(forKey: "SelectedLLMProvider") == nil {
            UserDefaults.standard.set("gemini", forKey: "SelectedLLMProvider")
        }
        
        // Preload social feed after 2 seconds if authenticated
        // Using shared singleton to ensure data is available to views
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Check authentication status
            if UnifiedAuthManager.shared.isAuthenticated {
                print("🚀 Starting background social feed preload...")
                print("   - User authenticated: ✓")
                print("   - Preloading into shared singleton instance")
                
                // Use the shared singleton instance
                await ActivityFeedManager.shared.preloadInBackground()
                
                print("✅ Social feed preload complete")
                print("   - Activities loaded: \(ActivityFeedManager.shared.activities.count)")
            } else {
                print("⏸️ Skipping social feed preload - user not authenticated")
            }
        }
        
        // Preload discover users after 3 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            // Check authentication status
            if UnifiedAuthManager.shared.isAuthenticated {
                print("🚀 Starting background discover users preload...")
                print("   - User authenticated: ✓")
                print("   - Preloading into shared singleton instance")
                
                // Use the shared singleton instance
                await SimpleDiscoverUsersManager.shared.loadUsers(for: .suggested)
                
                print("✅ Discover users preload complete")
                print("   - Users loaded: \(SimpleDiscoverUsersManager.shared.users.count)")
            } else {
                print("⏸️ Skipping discover users preload - user not authenticated")
            }
        }

        // Initialize social media SDKs
        SDKInitializer.initializeSDKs()
        SDKInitializer.verifyURLSchemes()

        // Configure API key for development/production
        print("🚀 App initialization: Setting up API key...")
        setupAPIKeyIfNeeded()
        print("🚀 App initialization: API key setup complete")
        
        KeychainManager.shared.ensureAPIKeyExists()
        NetworkManager.shared.configure()
        deviceManager.checkDeviceStatus()

        // Initialize notification system with comprehensive spam prevention
        Task {
            let granted = await notificationManager.requestNotificationPermission()
            // print("📱 Notification permission granted: \(granted)")
            
            if granted {
                // Setup default notifications (with limits and controls)
                notificationManager.scheduleDailyStreakReminder()
                notificationManager.scheduleJoinedChallengeReminders()
                print("✅ Notification system initialized with spam prevention")
            }
        }

        Task {
            let sessionID = cloudKitDataManager.startAppSession()
            appState.currentSessionID = sessionID

            try? await cloudKitDataManager.registerDevice()
            // Removed automatic sync on app launch - only sync when user visits recipe views
            cloudKitDataManager.trackScreenView("AppLaunch")
            
            // Initialize CloudKit authentication managers
            await initializeAuthentication()
            
            // Wait for authentication to fully complete (up to 2 seconds)
            var authCheckAttempts = 0
            while authCheckAttempts < 20 && !UnifiedAuthManager.shared.isAuthenticated {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                authCheckAttempts += 1
            }
            
            if UnifiedAuthManager.shared.isAuthenticated {
                print("✅ Authentication confirmed, proceeding with CloudKit operations")
            } else {
                print("⚠️ Authentication not completed after 2 seconds, proceeding anyway")
            }
            
            // Initialize RecipeLikeManager to load user's liked recipes
            if UnifiedAuthManager.shared.isAuthenticated {
                await RecipeLikeManager.shared.loadUserLikes()
                print("✅ RecipeLikeManager initialized with user's liked recipes")
            }
            
            // Check iCloud status for progressive auth
            await iCloudStatusManager.shared.checkiCloudStatus()
            
            // Track daily app usage and update streak
            if UnifiedAuthManager.shared.isAuthenticated {
                await trackDailyAppUsage()
            }

            // Sync CloudKit photos to PhotoStorageManager (only if authenticated)
            if UnifiedAuthManager.shared.isAuthenticated {
                await syncCloudKitPhotosToStorage()
            } else {
                print("⚠️ Skipping CloudKit photo sync - user not authenticated")
            }
            
            // MIGRATION: Run CloudKit data migration (Remove after successful run)
            // Uncomment the line below to run the migration ONCE
            // await CloudKitMigration.shared.runFullMigration()
            
            // MIGRATION NOTES: 
            // - Follow record IDs were successfully normalized (removed user_ prefix)
            // - Cannot update followerCount/followingCount - fields not in production schema
            // - Username generation needs different approach for production
            
            // LOCAL-FIRST MIGRATION: Migrate existing saved recipes to local storage
            await migrateToLocalFirstStorage()
            
            // Retry any failed sync operations from last session
            await PersistentSyncQueue.shared.retryAllFailedOperations()
        }
    }

    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    private func configureTableView() {
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
    }

    private func configureWindow() {
        UIScrollView.appearance().backgroundColor = .clear
    }
    
    private func configureImageCache() {
        // Configure URLCache for better image caching
        let memoryCapacity = 50 * 1024 * 1024 // 50 MB
        let diskCapacity = 200 * 1024 * 1024 // 200 MB
        let cache = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "ImageCache"
        )
        URLCache.shared = cache
        
        // Configure URL session for image loading
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        print("📸 Image cache configured: \(memoryCapacity / 1024 / 1024)MB memory, \(diskCapacity / 1024 / 1024)MB disk")
    }

    private func handleIncomingURL(_ url: URL) {
        // First check if it's an SDK callback
        if SDKInitializer.handleOpenURL(url) {
            return
        }

        // Otherwise handle as a deep link
        if socialShareManager.handleIncomingURL(url) {
            socialShareManager.resolvePendingDeepLink()
        }
    }

    /// Initialize authentication systems
    private func initializeAuthentication() async {
        print("🔐 Initializing authentication systems...")
        
        // Check if user was previously authenticated using the existing auth manager
        // Note: checkAuthStatus() is called automatically in AuthenticationManager's init
        
        // The AuthenticationManager handles authentication flows
        // and will restore authentication state if the user was previously signed in
        
        print("🔐 Authentication initialization completed")
    }
    
    @MainActor
    private func trackDailyAppUsage() async {
        // print("📅 Tracking daily app usage for streak...")
        
        // Check if authenticated
        guard authManager.isAuthenticated, let currentUser = authManager.currentUser else {
            print("⚠️ User not authenticated, skipping streak update")
            return
        }
        
        // Check last app open date
        let lastOpenKey = "lastAppOpenDate"
        let lastOpenDate = UserDefaults.standard.object(forKey: lastOpenKey) as? Date
        let today = Calendar.current.startOfDay(for: Date())
        
        // If we haven't opened the app today, update the streak
        if lastOpenDate == nil || !Calendar.current.isDate(lastOpenDate!, inSameDayAs: today) {
            print("🔥 New day detected, updating streak...")
            
            // Calculate new streak
            var newStreak = currentUser.currentStreak
            
            if let lastOpen = lastOpenDate {
                let daysSinceLastOpen = Calendar.current.dateComponents([.day], from: lastOpen, to: today).day ?? 0
                
                if daysSinceLastOpen == 1 {
                    // Consecutive day - increment streak
                    newStreak += 1
                    print("✅ Consecutive day! Streak increased to \(newStreak)")
                } else if daysSinceLastOpen > 1 {
                    // Streak broken - reset to 1
                    newStreak = 1
                    print("❌ Streak broken. Reset to 1 day")
                }
            } else {
                // First time tracking - start at 1
                newStreak = 1
                print("🎉 Starting streak tracking at 1 day")
            }
            
            // Update UserDefaults
            UserDefaults.standard.set(today, forKey: lastOpenKey)
            
            // Update CloudKit User record
            let updates = UserStatUpdates(
                currentStreak: newStreak,
                longestStreak: max(newStreak, currentUser.longestStreak)
            )
            
            do {
                try await authManager.updateUserStats(updates)
                print("✅ Streak updated in CloudKit to \(newStreak) days")
                
                // Refresh current user data to reflect the update
                await authManager.refreshCurrentUser()
            } catch {
                print("❌ Failed to update streak in CloudKit: \(error)")
            }
            
            // Also update StreakManager for gamification
            await StreakManager.shared.recordActivity(for: .dailySnap)
        } else {
            print("✅ Already opened app today, streak maintained at \(currentUser.currentStreak) days")
            
            // Sync existing streak from StreakManager if CloudKit shows 0
            if currentUser.currentStreak == 0 {
                await syncStreakFromManager()
            }
        }
    }
    
    @MainActor
    private func syncStreakFromManager() async {
        print("🔄 Syncing streak from StreakManager to CloudKit...")
        
        // Get the daily snap streak from StreakManager
        let streakManager = StreakManager.shared
        if let dailyStreak = streakManager.currentStreaks[.dailySnap] {
            let currentStreak = dailyStreak.currentStreak
            let longestStreak = dailyStreak.longestStreak
            
            if currentStreak > 0 {
                print("📊 Found existing streak in StreakManager: \(currentStreak) days")
                
                let updates = UserStatUpdates(
                    currentStreak: currentStreak,
                    longestStreak: longestStreak
                )
                
                do {
                    try await authManager.updateUserStats(updates)
                    print("✅ Synced streak to CloudKit: \(currentStreak) days")
                    await authManager.refreshCurrentUser()
                } catch {
                    print("❌ Failed to sync streak to CloudKit: \(error)")
                }
            }
        }
    }
    
    @MainActor
    private func syncCloudKitPhotosToStorage() async {
        print("📸 Starting CloudKit photo sync to PhotoStorageManager...")

        // Get all CloudKit recipes
        let cloudKitRecipes = await CloudKitRecipeCache.shared.getRecipes(forceRefresh: false)

        print("📸 Found \(cloudKitRecipes.count) CloudKit recipes to check for photos")

        // Fetch photos for recipes that don't have them in PhotoStorageManager
        for recipe in cloudKitRecipes {
            // Check if we already have photos in PhotoStorageManager
            if PhotoStorageManager.shared.hasCompletePhotos(for: recipe.id) {
                print("📸 Recipe \(recipe.name) already has complete photos in storage")
                continue
            }

            // Fetch photos from CloudKit
            do {
                let photos = try await CloudKitRecipeManager.shared.fetchRecipePhotos(for: recipe.id.uuidString)

                // Store in PhotoStorageManager if we got any photos
                if photos.before != nil || photos.after != nil {
                    PhotoStorageManager.shared.storePhotos(
                        fridgePhoto: photos.before,
                        mealPhoto: photos.after,
                        for: recipe.id
                    )
                    print("✅ Synced photos for recipe: \(recipe.name)")
                    print("    - Before: \(photos.before != nil ? "✓" : "✗")")
                    print("    - After: \(photos.after != nil ? "✓" : "✗")")
                }
            } catch {
                print("❌ Failed to sync photos for recipe \(recipe.name): \(error)")
            }
        }

        print("✅ CloudKit photo sync completed")
    }
    
    // MARK: - CloudKit Environment Detection
    
    private func detectCloudKitEnvironment() {
        // The CloudKit environment is determined by Xcode's build configuration
        // Debug builds use Development, Release/TestFlight/App Store use Production
        
        let container = CKContainer(identifier: "iCloud.com.snapchefapp.app")
        
        // Check account status to verify CloudKit is available
        container.accountStatus { status, error in
            var environmentString = ""
            
            // Determine environment based on build configuration
            #if DEBUG
                environmentString = "🔧 CloudKit Environment: DEVELOPMENT"
                print("════════════════════════════════════════════════")
                print(environmentString)
                print("   Container: iCloud.com.snapchefapp.app")
                print("   Build Config: Debug")
                print("   Note: Using CloudKit Development database")
                print("════════════════════════════════════════════════")
            #else
                environmentString = "🚀 CloudKit Environment: PRODUCTION"
                print("════════════════════════════════════════════════")
                print(environmentString)
                print("   Container: iCloud.com.snapchefapp.app")
                print("   Build Config: Release/Archive")
                print("   Note: Using CloudKit Production database")
                print("════════════════════════════════════════════════")
            #endif
            
            // Also show account status
            switch status {
            case .available:
                print("✅ CloudKit Account: Available")
            case .noAccount:
                print("⚠️ CloudKit Account: No iCloud account")
            case .restricted:
                print("⚠️ CloudKit Account: Restricted")
            case .couldNotDetermine:
                print("❌ CloudKit Account: Could not determine")
                if let error = error {
                    print("   Error: \(error.localizedDescription)")
                }
            case .temporarilyUnavailable:
                print("⚠️ CloudKit Account: Temporarily unavailable")
            @unknown default:
                print("❓ CloudKit Account: Unknown status")
            }
            
            print("════════════════════════════════════════════════")
        }
    }
    
    // MARK: - Local-First Migration
    
    private func migrateToLocalFirstStorage() async {
        let migrationKey = "local_first_migration_completed_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { 
            print("✅ Local-first migration already completed")
            return 
        }
        
        print("🔄 Starting migration to local-first storage...")
        
        // Migrate existing saved recipes to local storage
        await MainActor.run {
            let localStorage = LocalRecipeStorage.shared
            let savedCount = appState.savedRecipes.count
            
            if savedCount > 0 {
                localStorage.migrateFromAppState(appState.savedRecipes)
                print("✅ Migrated \(savedCount) recipes to local-first storage")
            } else {
                print("ℹ️ No saved recipes to migrate")
            }
            
            // Sync AppState with local storage
            appState.syncWithLocalStorage()
        }
        
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("✅ Local-first migration completed")
    }
    
    // MARK: - API Key Configuration
    
    private func setupAPIKeyIfNeeded() {
        // Check if API key already exists in Keychain
        if let existingKey = KeychainManager.shared.getAPIKey(), !existingKey.isEmpty {
            print("🔑 API key already configured in Keychain")
            return
        }
        
        // Get API key from build configuration
        var apiKey: String = ""
        
        #if DEBUG
        // For development: Try environment variable first, then Info.plist
        if let envKey = ProcessInfo.processInfo.environment["SNAPCHEF_API_KEY"], !envKey.isEmpty {
            apiKey = envKey
            print("🔑 Using API key from environment variable")
        } else if let plistKey = Bundle.main.object(forInfoDictionaryKey: "SNAPCHEF_API_KEY") as? String, !plistKey.isEmpty {
            apiKey = plistKey
            print("🔑 Using API key from Info.plist")
        } else {
            print("⚠️ WARNING: No API key found. Server calls will fail.")
            print("📋 Set SNAPCHEF_API_KEY environment variable in Xcode scheme")
            print("   1. Edit Scheme → Run → Arguments → Environment Variables")
            print("   2. Add SNAPCHEF_API_KEY with your API key value")
            return
        }
        #else
        // For production: Must come from Info.plist (injected at build time)
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "SNAPCHEF_API_KEY") as? String, !plistKey.isEmpty {
            apiKey = plistKey
            print("🔑 Using API key from build configuration")
        } else {
            print("❌ CRITICAL: No API key found in production build")
            // In production, we should have a fallback or show maintenance mode
            return
        }
        #endif
        
        // Validate API key format before storing
        guard validateAPIKeyFormat(apiKey) else {
            print("❌ Invalid API key format detected")
            return
        }
        
        // Store in Keychain for secure access
        KeychainManager.shared.storeAPIKey(apiKey)
        print("🔑 API key stored in Keychain: \(apiKey.prefix(10))...")
        
        // Verify storage
        if let storedKey = KeychainManager.shared.getAPIKey() {
            print("✅ API key verification successful")
        } else {
            print("❌ Failed to verify API key storage")
        }
    }
    
    private func validateAPIKeyFormat(_ key: String) -> Bool {
        // Basic validation: not empty, reasonable length, no spaces, not a placeholder
        let isValid = !key.isEmpty &&
                     key.count >= 20 &&
                     key.count <= 100 &&
                     !key.contains(" ") &&
                     !key.contains("your-api-key-here") &&
                     !key.contains("YOUR_API_KEY")
        
        if !isValid {
            print("⚠️ API key validation failed: Invalid format")
        }
        
        return isValid
    }
}

// MARK: - Deep Link Recipe View
struct DeepLinkRecipeView: View {
    @EnvironmentObject var socialShareManager: SocialShareManager
    @EnvironmentObject var cloudKitSync: CloudKitSyncService
    @Environment(\.dismiss) var dismiss

    @State private var recipe: Recipe?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Loading recipe...")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)

                        Text("Oops!")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        Text(errorMessage)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Close") {
                            dismiss()
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#667eea"))
                        .foregroundColor(.white)
                        .cornerRadius(25)
                    }
                } else if let recipe = recipe {
                    RecipeDetailView(recipe: recipe)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .task {
            await loadRecipeFromDeepLink()
        }
    }

    private func loadRecipeFromDeepLink() async {
        guard case .recipe(let recipeID) = socialShareManager.pendingDeepLink else {
            errorMessage = "Invalid recipe link"
            isLoading = false
            return
        }

        do {
            let (fetchedRecipe, _) = try await cloudKitSync.fetchRecipe(by: recipeID)
            recipe = fetchedRecipe
            isLoading = false
        } catch {
            errorMessage = "Could not load this recipe. It may have been removed or you may not have permission to view it."
            isLoading = false
            print("Failed to load recipe: \(error)")
        }
    }
}
