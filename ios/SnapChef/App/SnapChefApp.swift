import SwiftUI

@main
struct SnapChefApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var gamificationManager = GamificationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authManager)
                .environmentObject(deviceManager)
                .environmentObject(gamificationManager)
                .preferredColorScheme(.dark) // Force dark mode
                .onAppear {
                    setupApp()
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
}