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
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var gamificationManager = GamificationManager()

    // Use the shared singleton instances, managed by @StateObject, to ensure
    // SwiftUI observes changes and triggers view updates.
    @StateObject private var socialShareManager = SocialShareManager.shared
    @StateObject private var cloudKitSyncService = CloudKitSyncService.shared
    @StateObject private var cloudKitDataManager = CloudKitDataManager.shared

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
        
        // Initialize social media SDKs
        SDKInitializer.initializeSDKs()
        SDKInitializer.verifyURLSchemes()
        
        KeychainManager.shared.ensureAPIKeyExists()
        NetworkManager.shared.configure()
        deviceManager.checkDeviceStatus()
        
        Task {
            _ = await ChallengeNotificationManager.shared.requestNotificationPermission()
        }
        
        Task {
            let sessionID = cloudKitDataManager.startAppSession()
            appState.currentSessionID = sessionID
            
            try? await cloudKitDataManager.registerDevice()
            await cloudKitDataManager.performFullSync()
            cloudKitDataManager.trackScreenView("AppLaunch")
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
