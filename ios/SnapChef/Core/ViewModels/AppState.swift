import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var isFirstLaunch: Bool
    @Published var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var error: AppError?
    @Published var selectedRecipe: Recipe?
    @Published var recentRecipes: [Recipe] = []
    @Published var freeUsesRemaining: Int = 3
    
    private let userDefaults = UserDefaults.standard
    private let firstLaunchKey = "hasLaunchedBefore"
    
    init() {
        self.isFirstLaunch = !userDefaults.bool(forKey: firstLaunchKey)
    }
    
    func completeOnboarding() {
        userDefaults.set(true, forKey: firstLaunchKey)
        isFirstLaunch = false
    }
    
    func updateFreeUses(_ remaining: Int) {
        freeUsesRemaining = remaining
    }
    
    func addRecentRecipe(_ recipe: Recipe) {
        recentRecipes.insert(recipe, at: 0)
        if recentRecipes.count > 10 {
            recentRecipes.removeLast()
        }
    }
    
    func clearError() {
        error = nil
    }
}

enum AppError: LocalizedError {
    case networkError(String)
    case authenticationError(String)
    case apiError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .authenticationError(let message):
            return "Authentication Error: \(message)"
        case .apiError(let message):
            return "API Error: \(message)"
        case .unknown(let message):
            return "Error: \(message)"
        }
    }
}