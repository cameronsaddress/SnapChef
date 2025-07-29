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
    @Published var allRecipes: [Recipe] = []
    @Published var savedRecipes: [Recipe] = []
    @Published var totalLikes: Int = 0
    @Published var totalShares: Int = 0
    @Published var userJoinDate: Date = Date()
    
    private let userDefaults = UserDefaults.standard
    private let firstLaunchKey = "hasLaunchedBefore"
    private let userJoinDateKey = "userJoinDate"
    
    init() {
        self.isFirstLaunch = !userDefaults.bool(forKey: firstLaunchKey)
        
        // Load or set user join date
        if let joinDate = userDefaults.object(forKey: userJoinDateKey) as? Date {
            self.userJoinDate = joinDate
        } else {
            userDefaults.set(Date(), forKey: userJoinDateKey)
        }
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
        
        // Also add to all recipes
        allRecipes.insert(recipe, at: 0)
    }
    
    func toggleRecipeSave(_ recipe: Recipe) {
        if let index = savedRecipes.firstIndex(where: { $0.id == recipe.id }) {
            savedRecipes.remove(at: index)
        } else {
            savedRecipes.append(recipe)
        }
    }
    
    func incrementShares() {
        totalShares += 1
    }
    
    func incrementLikes() {
        totalLikes += 1
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