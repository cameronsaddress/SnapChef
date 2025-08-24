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
        }
    }

    // MARK: - App Setup Functions

    private func setupApp() {
        configureNavigationBar()
        configureTableView()
        configureWindow()

        // Check CloudKit environment (determined by Xcode build configuration)
        detectCloudKitEnvironment()

        // Set default LLM provider to Gemini if not already set
        if UserDefaults.standard.object(forKey: "SelectedLLMProvider") == nil {
            UserDefaults.standard.set("gemini", forKey: "SelectedLLMProvider")
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
            print("📱 Notification permission granted: \(granted)")
            
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

            // Sync CloudKit photos to PhotoStorageManager
            await syncCloudKitPhotosToStorage()
            
            // MIGRATION: Run CloudKit data migration (Remove after successful run)
            // Uncomment the line below to run the migration ONCE
            // await CloudKitMigration.shared.runFullMigration()
            
            // MIGRATION NOTES: 
            // - Follow record IDs were successfully normalized (removed user_ prefix)
            // - Cannot update followerCount/followingCount - fields not in production schema
            // - Username generation needs different approach for production
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
    
    // MARK: - API Key Configuration
    
    private func setupAPIKeyIfNeeded() {
        // Force update the API key to ensure we have the correct one
        // The storeAPIKey function now handles deletion internally
        
        // For production app, we need a secure API key that matches the server's APP_API_KEY
        // This key should be coordinated with the server deployment
        // Using the correct API key for the render server
        let apiKey = "5380e4b60818cf237678fccfd4b8f767d1c94"
        
        // Store the API key securely in Keychain
        KeychainManager.shared.storeAPIKey(apiKey)
        print("🔑 API key configured and stored in Keychain: \(apiKey.prefix(10))...")
        print("🔑 API key length: \(apiKey.count) characters")
        
        // Verify it was stored successfully
        if let storedKey = KeychainManager.shared.getAPIKey() {
            print("✅ API key verification successful: \(storedKey.prefix(10))...")
        } else {
            print("❌ Failed to verify API key storage")
        }
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
