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
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        NSClassFromString("XCTestCase") != nil
    }

    // Connect the UIKit AppDelegate for TikTok SDK
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Create new instances for @StateObject to manage their lifecycle.
    @StateObject private var appState = AppState()
    @StateObject private var authManager = UnifiedAuthManager.shared
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var gamificationManager = GamificationManager()
    @StateObject private var authPromptTrigger = AuthPromptTrigger.shared

    // Use the shared singleton instances, managed by @StateObject, to ensure
    // SwiftUI observes changes and triggers view updates.
    @StateObject private var socialShareManager = SocialShareManager.shared
    // CloudKit can SIGTRAP at initialization on Simulator in certain signing/entitlement states.
    // Avoid eagerly creating CloudKit singletons at app launch; inject them only when runtime is enabled.
    @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var cloudKitDataManager = CloudKitDataManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var hasCompletedInitialSetup = false

    private var cloudKitRuntimeEnabled: Bool {
        CloudKitRuntimeSupport.hasCloudKitEntitlement
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject all dependencies into the environment.
                .environmentObject(appState)
                .environmentObject(authManager)
                .environmentObject(deviceManager)
                .environmentObject(gamificationManager)
                .environmentObject(socialShareManager)
                .environmentObject(cloudKitService)
                .environmentObject(cloudKitDataManager)
                .environmentObject(notificationManager)

                .preferredColorScheme(.dark)

                .onAppear {
                    guard !Self.isRunningTests else { return }
                    guard !hasCompletedInitialSetup else { return }
                    hasCompletedInitialSetup = true
                    setupApp()
                }

                .onOpenURL { url in
                    handleIncomingURL(url)
                }

                .sheet(isPresented: $authPromptTrigger.shouldShowPrompt) {
                    ProgressiveAuthPrompt()
                }

                // The sheet is now presented using the singleton's property, and
                // its environment objects are passed down from SnapChefApp,
                // ensuring consistency.
                .sheet(isPresented: $socialShareManager.showRecipeFromDeepLink) {
                    DeepLinkRecipeView()
                        // These are the instances managed by this App struct.
                        .environmentObject(socialShareManager)
                        .environmentObject(cloudKitService)
                }

                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    guard cloudKitRuntimeEnabled else { return }
                    Task {
                        await cloudKitDataManager.endAppSession()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    guard cloudKitRuntimeEnabled else { return }
                    Task {
                        await cloudKitDataManager.endAppSession()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Memory management will be handled by item count limits, not time-based clearing
                    // Tasks will be properly cancelled in managers
                }
                .onChange(of: authManager.isAuthenticated) { isAuthenticated in
                    guard cloudKitRuntimeEnabled else { return }
                    guard isAuthenticated else { return }
                    Task { @MainActor in
                        cloudKitService.bootstrapIfNeeded()
                        socialShareManager.markReferralConversionIfEligible()
                        await socialShareManager.claimReferrerRewardsIfEligible()
                        await cloudKitDataManager.ensureSubscriptionsConfigured()
                    }
                    Task {
                        await GrowthRemoteConfig.shared.refreshFromCloudKit()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task { @MainActor in
                        await notificationManager.bootstrapMonthlyScheduleIfAuthorized()

                        // Preload fresh data when coming to foreground
                        if cloudKitRuntimeEnabled, UnifiedAuthManager.shared.isAuthenticated {
                            cloudKitService.bootstrapIfNeeded()
                            await cloudKitDataManager.ensureSubscriptionsConfigured()
                            await ActivityFeedManager.shared.preloadInBackground()
                            await SimpleDiscoverUsersManager.shared.loadUsers(for: .suggested)
                            await socialShareManager.claimReferrerRewardsIfEligible()
                        }
                    }
                    Task {
                        if cloudKitRuntimeEnabled, UnifiedAuthManager.shared.isAuthenticated {
                            await GrowthRemoteConfig.shared.refreshFromCloudKit()
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
        GrowthRemoteConfig.shared.bootstrap()
        // Keep startup quiet: avoid CloudKit fetches until the user authenticates.

        // CloudKit environment logging can trigger iCloud system prompts (account status checks).
        // Keep app startup quiet; developers can enable explicitly when debugging.
        #if DEBUG
        if cloudKitRuntimeEnabled,
           ProcessInfo.processInfo.environment["SNAPCHEF_DEBUG_CLOUDKIT_ENV"] == "1" {
            detectCloudKitEnvironment()
        }
        #endif

        // Set default LLM provider to Gemini if not already set
        if UserDefaults.standard.object(forKey: "SelectedLLMProvider") == nil {
            UserDefaults.standard.set("gemini", forKey: "SelectedLLMProvider")
        }
        
        // Preload social feed after 2 seconds if authenticated
        // Using shared singleton to ensure data is available to views
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Check authentication status
            if cloudKitRuntimeEnabled, UnifiedAuthManager.shared.isAuthenticated {
                AppLog.debug(AppLog.app, "Starting background social feed preload")
                
                // Use the shared singleton instance
                await ActivityFeedManager.shared.preloadInBackground()
                
                AppLog.debug(
                    AppLog.app,
                    "Social feed preload complete (activities=\(ActivityFeedManager.shared.activities.count))"
                )
            } else {
                AppLog.debug(AppLog.app, "Skipping social feed preload (unauthenticated)")
            }
        }
        
        // Preload discover users after 3 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            // Check authentication status
            if cloudKitRuntimeEnabled, UnifiedAuthManager.shared.isAuthenticated {
                AppLog.debug(AppLog.app, "Starting background discover users preload")
                
                // Use the shared singleton instance
                await SimpleDiscoverUsersManager.shared.loadUsers(for: .suggested)
                
                AppLog.debug(
                    AppLog.app,
                    "Discover users preload complete (users=\(SimpleDiscoverUsersManager.shared.users.count))"
                )
            } else {
                AppLog.debug(AppLog.app, "Skipping discover users preload (unauthenticated)")
            }
        }

        // Initialize social media SDKs
        SDKInitializer.initializeSDKs()
        SDKInitializer.verifyURLSchemes()

        // Configure API key for development/production
        AppLog.debug(AppLog.app, "App initialization: setting up API key")
        setupAPIKeyIfNeeded()
        AppLog.debug(AppLog.app, "App initialization: API key setup complete")
        
        KeychainManager.shared.ensureAPIKeyExists()
        NetworkManager.shared.configure()
        Task {
            let backendHealthy = await NetworkManager.shared.checkServerHealth()
            if backendHealthy {
                AppLog.debug(AppLog.network, "Backend health check succeeded")
            } else {
                AppLog.warning(AppLog.network, "Backend health check failed; requests will retry with backoff")
            }
        }
        deviceManager.checkDeviceStatus()

        // Initialize notification system without launch-time permission prompt.
        Task {
            await notificationManager.bootstrapMonthlyScheduleIfAuthorized()
            AppLog.debug(AppLog.notifications, "Notification system bootstrap complete")
        }

        Task {
            let sessionID = cloudKitDataManager.startAppSession()
            appState.currentSessionID = sessionID

            guard cloudKitRuntimeEnabled else {
                AppLog.warning(AppLog.cloudKit, "CloudKit runtime disabled; running local-only startup flow")
                await migrateToLocalFirstStorage()
                return
            }

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
                AppLog.debug(AppLog.auth, "Authentication confirmed; proceeding with CloudKit operations")
                socialShareManager.markReferralConversionIfEligible()
                await socialShareManager.claimReferrerRewardsIfEligible()
                await cloudKitDataManager.ensureSubscriptionsConfigured()
            } else {
                AppLog.debug(AppLog.auth, "Authentication not completed after 2 seconds; proceeding anyway")
            }
            
            // Initialize RecipeLikeManager to load user's liked recipes
            if UnifiedAuthManager.shared.isAuthenticated {
                await RecipeLikeManager.shared.loadUserLikes()
                AppLog.debug(AppLog.app, "RecipeLikeManager initialized with user's liked recipes")
            }
            
            // Intentionally avoid iCloud/CloudKit account status checks on app launch.
            // These can trigger intrusive system prompts ("Apple Account Verification").
            
            // Track daily app usage and update streak
            if UnifiedAuthManager.shared.isAuthenticated {
                await trackDailyAppUsage()
            }

            // Sync CloudKit photos to PhotoStorageManager (only if authenticated)
            if UnifiedAuthManager.shared.isAuthenticated {
                await syncCloudKitPhotosToStorage()
            } else {
                AppLog.debug(AppLog.cloudKit, "Skipping CloudKit photo sync (unauthenticated)")
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
            
            // Retry pending sync operations from last session.
            await CloudKitSyncEngine.shared.processPendingSync()
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
        
        AppLog.debug(
            AppLog.persistence,
            "Image cache configured: \(memoryCapacity / 1024 / 1024)MB memory, \(diskCapacity / 1024 / 1024)MB disk"
        )
    }

    private func handleIncomingURL(_ url: URL) {
        // First check if it's an SDK callback
        if SDKInitializer.handleOpenURL(url) {
            return
        }

        // Otherwise handle as a deep link
        _ = socialShareManager.handleIncomingURL(url)
    }

    /// Initialize authentication systems
    private func initializeAuthentication() async {
        AppLog.debug(AppLog.auth, "Initializing authentication systems")
        
        // Check if user was previously authenticated using the existing auth manager
        // Note: checkAuthStatus() is called automatically in AuthenticationManager's init
        
        // The AuthenticationManager handles authentication flows
        // and will restore authentication state if the user was previously signed in
        
        AppLog.debug(AppLog.auth, "Authentication initialization completed")
    }
    
    @MainActor
    private func trackDailyAppUsage() async {
        // print("📅 Tracking daily app usage for streak...")
        
        // Check if authenticated
        guard authManager.isAuthenticated, let currentUser = authManager.currentUser else {
            AppLog.debug(AppLog.auth, "User not authenticated; skipping streak update")
            return
        }
        
        // Check last app open date
        let lastOpenKey = "lastAppOpenDate"
        let lastOpenDate = UserDefaults.standard.object(forKey: lastOpenKey) as? Date
        let today = Calendar.current.startOfDay(for: Date())
        
        // If we haven't opened the app today, update the streak
        if lastOpenDate == nil || !Calendar.current.isDate(lastOpenDate!, inSameDayAs: today) {
            AppLog.debug(AppLog.app, "New day detected; updating streak")
            
            // Calculate new streak
            var newStreak = currentUser.currentStreak
            
            if let lastOpen = lastOpenDate {
                let daysSinceLastOpen = Calendar.current.dateComponents([.day], from: lastOpen, to: today).day ?? 0
                
                if daysSinceLastOpen == 1 {
                    // Consecutive day - increment streak
                    newStreak += 1
                    AppLog.debug(AppLog.app, "Consecutive day; streak increased to \(newStreak)")
                } else if daysSinceLastOpen > 1 {
                    // Streak broken - reset to 1
                    newStreak = 1
                    AppLog.debug(AppLog.app, "Streak broken; reset to 1 day")
                }
            } else {
                // First time tracking - start at 1
                newStreak = 1
                AppLog.debug(AppLog.app, "Starting streak tracking at 1 day")
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
                AppLog.debug(AppLog.cloudKit, "Streak updated in CloudKit to \(newStreak) days")
                
                // Refresh current user data to reflect the update
                await authManager.refreshCurrentUser()
            } catch {
                AppLog.error(AppLog.cloudKit, "Failed to update streak in CloudKit: \(error.localizedDescription)")
            }
            
            // Also update StreakManager for gamification
            await StreakManager.shared.recordActivity(for: .dailySnap)
        } else {
            AppLog.debug(AppLog.app, "Already opened app today; streak maintained at \(currentUser.currentStreak) days")
            
            // Sync existing streak from StreakManager if CloudKit shows 0
            if currentUser.currentStreak == 0 {
                await syncStreakFromManager()
            }
        }
    }
    
    @MainActor
    private func syncStreakFromManager() async {
        AppLog.debug(AppLog.cloudKit, "Syncing streak from StreakManager to CloudKit")
        
        // Get the daily snap streak from StreakManager
        let streakManager = StreakManager.shared
        if let dailyStreak = streakManager.currentStreaks[.dailySnap] {
            let currentStreak = dailyStreak.currentStreak
            let longestStreak = dailyStreak.longestStreak
            
            if currentStreak > 0 {
                AppLog.debug(AppLog.app, "Found streak in StreakManager (\(currentStreak) days)")
                
                let updates = UserStatUpdates(
                    currentStreak: currentStreak,
                    longestStreak: longestStreak
                )
                
                do {
                    try await authManager.updateUserStats(updates)
                    AppLog.debug(AppLog.cloudKit, "Synced streak to CloudKit (\(currentStreak) days)")
                    await authManager.refreshCurrentUser()
                } catch {
                    AppLog.error(AppLog.cloudKit, "Failed to sync streak to CloudKit: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @MainActor
    private func syncCloudKitPhotosToStorage() async {
        AppLog.debug(AppLog.cloudKit, "Starting CloudKit photo sync to PhotoStorageManager")

        // Get all CloudKit recipes
        let cloudKitRecipes = await CloudKitRecipeCache.shared.getRecipes(forceRefresh: false)

        AppLog.debug(AppLog.cloudKit, "Found \(cloudKitRecipes.count) CloudKit recipes to check for photos")

        // Fetch photos for recipes that don't have them in PhotoStorageManager
        var syncedCount = 0
        for recipe in cloudKitRecipes {
            // Check if we already have photos in PhotoStorageManager
            if PhotoStorageManager.shared.hasCompletePhotos(for: recipe.id) {
                continue
            }

            // Fetch photos from CloudKit
            do {
                let photos = try await CloudKitService.shared.fetchRecipePhotos(for: recipe.id.uuidString)

                // Store in PhotoStorageManager if we got any photos
                if photos.before != nil || photos.after != nil {
                    PhotoStorageManager.shared.storePhotos(
                        fridgePhoto: photos.before,
                        mealPhoto: photos.after,
                        for: recipe.id
                    )
                    syncedCount += 1
                }
            } catch {
                AppLog.debug(AppLog.cloudKit, "Failed to sync recipe photos: \(error.localizedDescription)")
            }
        }

        AppLog.debug(AppLog.cloudKit, "CloudKit photo sync completed (synced=\(syncedCount))")
    }
    
    // MARK: - CloudKit Environment Detection
    
    private func detectCloudKitEnvironment() {
        guard cloudKitRuntimeEnabled else { return }
        // The CloudKit environment is determined by Xcode's build configuration:
        // Debug builds use Development, Release/TestFlight/App Store use Production.
        //
        // IMPORTANT: Avoid calling `CKContainer.accountStatus` here. It can trigger iCloud system
        // prompts, which we explicitly avoid during normal app startup.

        var environmentString = ""

        #if DEBUG
        environmentString = "🔧 CloudKit Environment: DEVELOPMENT"
        #else
        environmentString = "🚀 CloudKit Environment: PRODUCTION"
        #endif

        let tokenPresent = FileManager.default.ubiquityIdentityToken != nil

        AppLog.debug(AppLog.cloudKit, environmentString)
        AppLog.debug(AppLog.cloudKit, "Container: \(CloudKitRuntimeSupport.resolvedContainerIdentifier)")
        AppLog.debug(AppLog.cloudKit, "iCloud Identity Token: \(tokenPresent ? "present" : "missing")")
        AppLog.debug(AppLog.cloudKit, "UnifiedAuth: \(UnifiedAuthManager.shared.isAuthenticated ? "authenticated" : "guest")")
    }
    
    // MARK: - Local-First Migration
    
    private func migrateToLocalFirstStorage() async {
        let migrationKey = "local_first_migration_completed_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { 
            AppLog.debug(AppLog.persistence, "Local-first migration already completed")
            return 
        }
        
        AppLog.debug(AppLog.persistence, "Starting migration to local-first storage")
        
        // Perform comprehensive data migration
        await DataMigrator.shared.performMigrationIfNeeded()
        
        // Sync AppState with LocalRecipeManager
        await MainActor.run {
            appState.syncWithLocalStorage()
            
            let savedCount = appState.savedRecipes.count
            if savedCount > 0 {
                AppLog.debug(AppLog.persistence, "Found \(savedCount) recipes in LocalRecipeManager")
            } else {
                AppLog.debug(AppLog.persistence, "No saved recipes found")
            }
        }
        
        // Verify migration
        let (success, report) = DataMigrator.shared.verifyMigration()
        AppLog.debug(AppLog.persistence, report)
        
        if !success {
            AppLog.warning(AppLog.persistence, "Migration verification failed; check the report")
        }
        
        UserDefaults.standard.set(true, forKey: migrationKey)
        AppLog.debug(AppLog.persistence, "Local-first migration completed")
    }
    
    // MARK: - API Key Configuration
    
    private func setupAPIKeyIfNeeded() {
        let existingKey = KeychainManager.shared.getAPIKey()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let configuredEntry = snapChefResolvedConfiguredAPIKey()

        if let configuredEntry {
            let configuredKey = configuredEntry.value
            guard validateAPIKeyFormat(configuredKey) else {
                AppLog.error(AppLog.network, "Invalid API key format detected in configuration")
                return
            }

            AppLog.debug(AppLog.network, "Using API key from \(configuredEntry.source) \(configuredEntry.name)")

            if existingKey != configuredKey {
                let didPersist = KeychainManager.shared.storeAPIKey(configuredKey)
                if didPersist {
                    AppLog.debug(AppLog.network, existingKey == nil ? "API key stored in Keychain" : "API key updated in Keychain")
                } else {
                    AppLog.warning(AppLog.network, "Keychain persistence unavailable; using \(configuredEntry.source) \(configuredEntry.name) for runtime credentials")
                }
            } else {
                AppLog.debug(AppLog.network, "API key already configured")
            }

            if KeychainManager.shared.getAPIKey() != nil {
                AppLog.debug(AppLog.network, "API key verification successful")
            } else {
                AppLog.error(AppLog.network, "Failed to verify API key storage")
            }
            return
        }

        if let existingKey, validateAPIKeyFormat(existingKey) {
            AppLog.debug(AppLog.network, "Using existing API key from Keychain")
            return
        }

        #if !DEBUG
        AppLog.error(AppLog.network, "CRITICAL: No API key found in production build")
        #endif
        AppLog.warning(AppLog.network, "No valid API key found. Server calls will fail.")
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
            AppLog.debug(AppLog.network, "API key validation failed: invalid format")
        }
        
        return isValid
    }
}

// MARK: - Deep Link Recipe View
struct DeepLinkRecipeView: View {
    @EnvironmentObject var socialShareManager: SocialShareManager
    @EnvironmentObject var cloudKitSync: CloudKitService
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
            let fetchedRecipe = try await cloudKitSync.fetchRecipe(by: recipeID)
            recipe = fetchedRecipe
            isLoading = false
        } catch {
            errorMessage = "Could not load this recipe. It may have been removed or you may not have permission to view it."
            isLoading = false
            AppLog.warning(AppLog.share, "Failed to load recipe deep link: \(error.localizedDescription)")
        }
    }
}
