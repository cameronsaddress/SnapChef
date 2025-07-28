import SwiftUI

@main
struct SnapChefApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var deviceManager = DeviceManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authManager)
                .environmentObject(deviceManager)
                .preferredColorScheme(.light)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Configure appearance
        configureNavigationBar()
        
        // Initialize services
        NetworkManager.shared.configure()
        
        // Check device fingerprint
        deviceManager.checkDeviceStatus()
        
        // Setup analytics
        // AnalyticsManager.shared.initialize() // TODO: Add AnalyticsManager.swift to Xcode project
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
}