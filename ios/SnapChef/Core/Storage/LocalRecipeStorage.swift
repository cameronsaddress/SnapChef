import Foundation
import SwiftUI

/// Local-first storage for recipe save states
/// Provides instant UI updates with background CloudKit sync
@MainActor
class LocalRecipeStorage: ObservableObject {
    static let shared = LocalRecipeStorage()
    
    // UserDefaults keys
    private let savedRecipeIdsKey = "saved_recipe_ids_v2"
    private let createdRecipeIdsKey = "created_recipe_ids_v2"
    
    // Published for UI updates
    @Published var savedRecipeIds: Set<String> = []
    @Published var createdRecipeIds: Set<String> = []
    
    // File storage
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var recipesDirectory: URL { 
        documentsDirectory.appendingPathComponent("recipes")
    }
    
    private init() {
        loadFromUserDefaults()
        createRecipesDirectoryIfNeeded()
    }
    
    private func loadFromUserDefaults() {
        if let savedIds = UserDefaults.standard.array(forKey: savedRecipeIdsKey) as? [String] {
            savedRecipeIds = Set(savedIds)
            print("📱 LocalRecipeStorage: Loaded \(savedRecipeIds.count) saved recipe IDs from UserDefaults")
        }
        if let createdIds = UserDefaults.standard.array(forKey: createdRecipeIdsKey) as? [String] {
            createdRecipeIds = Set(createdIds)
        }
    }
    
    private func createRecipesDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: recipesDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create recipes directory: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Instantly save a recipe locally with optional image
    func saveRecipe(_ recipe: Recipe, capturedImage: UIImage? = nil) {
        // 1. Update local state immediately
        objectWillChange.send()  // Trigger UI update
        savedRecipeIds.insert(recipe.id.uuidString)
        persistToUserDefaults()
        
        // 2. Save recipe to file system
        saveRecipeToFile(recipe)
        
        // 3. Store photo if provided
        if let image = capturedImage {
            PhotoStorageManager.shared.storePhotos(
                fridgePhoto: image,
                mealPhoto: nil,
                for: recipe.id
            )
        }
        
        // 4. Queue for background CloudKit sync
        Task {
            await RecipeSyncQueue.shared.queueSave(recipe, beforePhoto: capturedImage)
        }
        
        print("💾 LocalRecipeStorage: Recipe '\(recipe.name)' saved locally (instant)")
    }
    
    /// Instantly unsave a recipe locally
    func unsaveRecipe(_ recipeId: UUID) {
        // 1. Update local state immediately
        objectWillChange.send()  // Trigger UI update
        savedRecipeIds.remove(recipeId.uuidString)
        persistToUserDefaults()
        
        // 2. Remove photos
        PhotoStorageManager.shared.removePhotos(for: [recipeId])
        
        // 3. Queue for background CloudKit sync
        Task {
            await RecipeSyncQueue.shared.queueUnsave(recipeId)
        }
        
        print("🗑 LocalRecipeStorage: Recipe \(recipeId) unsaved locally (instant)")
    }
    
    /// Check if a recipe is saved (instant lookup)
    func isRecipeSaved(_ recipeId: UUID) -> Bool {
        return savedRecipeIds.contains(recipeId.uuidString)
    }
    
    /// Mark a recipe as created by this user
    func markRecipeCreated(_ recipeId: UUID) {
        createdRecipeIds.insert(recipeId.uuidString)
        persistToUserDefaults()
    }
    
    /// Check if a recipe was created by this user
    func isRecipeCreated(_ recipeId: UUID) -> Bool {
        return createdRecipeIds.contains(recipeId.uuidString)
    }
    
    // MARK: - File Operations
    
    private func saveRecipeToFile(_ recipe: Recipe) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(recipe)
            let fileURL = recipesDirectory.appendingPathComponent("\(recipe.id.uuidString).json")
            try data.write(to: fileURL, options: .atomic)
            print("📄 Recipe saved to file: \(recipe.id.uuidString).json")
        } catch {
            print("❌ Failed to save recipe to file: \(error)")
        }
    }
    
    func loadRecipeFromFile(_ recipeId: String) -> Recipe? {
        let fileURL = recipesDirectory.appendingPathComponent("\(recipeId).json")
        
        guard let data = try? Data(contentsOf: fileURL),
              let recipe = try? JSONDecoder().decode(Recipe.self, from: data) else {
            return nil
        }
        
        return recipe
    }
    
    // MARK: - Persistence
    
    private func persistToUserDefaults() {
        UserDefaults.standard.set(Array(savedRecipeIds), forKey: savedRecipeIdsKey)
        UserDefaults.standard.set(Array(createdRecipeIds), forKey: createdRecipeIdsKey)
    }
    
    // MARK: - Migration Support
    
    /// Migrate existing saved recipes to local storage
    func migrateFromAppState(_ savedRecipes: [Recipe]) {
        print("🔄 Migrating \(savedRecipes.count) recipes to local storage...")
        
        for recipe in savedRecipes {
            // Add to saved set
            savedRecipeIds.insert(recipe.id.uuidString)
            
            // Save to file
            saveRecipeToFile(recipe)
        }
        
        persistToUserDefaults()
        print("✅ Migration complete: \(savedRecipeIds.count) recipes in local storage")
    }
    
    /// Get all saved recipe IDs
    func getAllSavedRecipeIds() -> [String] {
        return Array(savedRecipeIds)
    }
}