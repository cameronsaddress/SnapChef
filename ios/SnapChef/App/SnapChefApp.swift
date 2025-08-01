import SwiftUI

@main
struct SnapChefApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var gamificationManager = GamificationManager()
    @StateObject private var socialShareManager = SocialShareManager.shared
    @StateObject private var cloudKitSync = CloudKitSyncService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authManager)
                .environmentObject(deviceManager)
                .environmentObject(gamificationManager)
                .environmentObject(socialShareManager)
                .preferredColorScheme(.dark) // Force dark mode
                .onAppear {
                    setupApp()
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .sheet(isPresented: $socialShareManager.showRecipeFromDeepLink) {
                    DeepLinkRecipeView()
                        .environmentObject(socialShareManager)
                        .environmentObject(cloudKitSync)
                }
        }
    }
    
    private func setupApp() {
        // Configure appearance
        configureNavigationBar()
        configureTableView()
        configureWindow()
        
        // Ensure API key is securely stored in Keychain
        KeychainManager.shared.ensureAPIKeyExists()
        
        // Initialize services
        NetworkManager.shared.configure()
        
        // Check device fingerprint
        deviceManager.checkDeviceStatus()
        
        // Setup notifications for challenges
        Task {
            _ = await ChallengeNotificationManager.shared.requestNotificationPermission()
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
        // Make table views transparent
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        
        // Make collection views transparent
        UICollectionView.appearance().backgroundColor = .clear
    }
    
    private func configureWindow() {
        // Configure scroll view appearances
        UIScrollView.appearance().backgroundColor = .clear
    }
    
    private func handleIncomingURL(_ url: URL) {
        if socialShareManager.handleIncomingURL(url) {
            // URL was handled successfully
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
    @State private var showRecipeDetail = false
    
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
                    // Recipe loaded successfully - show detail view
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