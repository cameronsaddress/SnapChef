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
    @Published var savedRecipesWithPhotos: [SavedRecipe] = []
    @Published var totalLikes: Int = 0
    @Published var totalShares: Int = 0
    @Published var userJoinDate: Date = Date()
    
    private let userDefaults = UserDefaults.standard
    private let firstLaunchKey = "hasLaunchedBefore"
    private let userJoinDateKey = "userJoinDate"
    private let savedRecipesKey = "savedRecipesWithPhotos"
    
    init() {
        self.isFirstLaunch = !userDefaults.bool(forKey: firstLaunchKey)
        
        // Load or set user join date
        if let joinDate = userDefaults.object(forKey: userJoinDateKey) as? Date {
            self.userJoinDate = joinDate
        } else {
            userDefaults.set(Date(), forKey: userJoinDateKey)
        }
        
        // Load saved recipes
        loadSavedRecipes()
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
    
    func saveRecipeWithPhotos(_ recipe: Recipe, beforePhoto: UIImage?, afterPhoto: UIImage?) {
        let savedRecipe = SavedRecipe(recipe: recipe, beforePhoto: beforePhoto, afterPhoto: afterPhoto)
        savedRecipesWithPhotos.append(savedRecipe)
        saveToDisk()
        
        // Also update the simple lists
        if !savedRecipes.contains(where: { $0.id == recipe.id }) {
            savedRecipes.append(recipe)
        }
    }
    
    private func loadSavedRecipes() {
        // Load from documents directory instead of UserDefaults
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let filePath = documentsPath.appendingPathComponent("savedRecipes.json")
        
        if let data = try? Data(contentsOf: filePath),
           let decoded = try? JSONDecoder().decode([SavedRecipe].self, from: data) {
            savedRecipesWithPhotos = decoded
            savedRecipes = decoded.map { $0.recipe }
            allRecipes = decoded.map { $0.recipe }
        } else {
            // Try to migrate from old UserDefaults storage
            if let data = userDefaults.data(forKey: savedRecipesKey),
               let decoded = try? JSONDecoder().decode([SavedRecipe].self, from: data) {
                savedRecipesWithPhotos = decoded
                savedRecipes = decoded.map { $0.recipe }
                allRecipes = decoded.map { $0.recipe }
                
                // Save to new location and remove from UserDefaults
                saveToDisk()
                userDefaults.removeObject(forKey: savedRecipesKey)
            }
        }
    }
    
    private func saveToDisk() {
        // Save to documents directory instead of UserDefaults to avoid size limits
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let filePath = documentsPath.appendingPathComponent("savedRecipes.json")
        
        if let encoded = try? JSONEncoder().encode(savedRecipesWithPhotos) {
            try? encoded.write(to: filePath)
            
            // Save just a flag in UserDefaults to indicate we have saved recipes
            userDefaults.set(true, forKey: "hasSavedRecipes")
        }
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