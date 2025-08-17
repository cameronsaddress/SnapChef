//
//  CloudKitRecipeWithPhotos.swift
//  SnapChef
//
//  Helper to fetch and cache CloudKit recipes with their photos
//

import Foundation
import SwiftUI
import UIKit

/// Wrapper for CloudKit recipes with their photos cached locally
struct CloudKitRecipeWithPhotos: Codable {
    let recipe: Recipe
    let beforePhotoData: Data?
    let afterPhotoData: Data?
    let fetchedAt: Date
    
    init(recipe: Recipe, beforePhoto: UIImage?, afterPhoto: UIImage?) {
        self.recipe = recipe
        self.beforePhotoData = beforePhoto?.jpegData(compressionQuality: 0.8)
        self.afterPhotoData = afterPhoto?.jpegData(compressionQuality: 0.8)
        self.fetchedAt = Date()
    }
    
    var beforePhoto: UIImage? {
        guard let data = beforePhotoData else { return nil }
        return UIImage(data: data)
    }
    
    var afterPhoto: UIImage? {
        guard let data = afterPhotoData else { return nil }
        return UIImage(data: data)
    }
}

/// Extension to fetch CloudKit recipes with photos and add them to app state
extension CloudKitRecipeManager {
    
    /// Fetch recipe with photos and store in app state
    @MainActor
    func fetchRecipeWithPhotosForAppState(recipeID: String, appState: AppState) async {
        do {
            print("🎬 Fetching CloudKit photos for recipe: \(recipeID)")
            
            // Fetch the photos from CloudKit
            let photos = try await fetchRecipePhotos(for: recipeID)
            
            // Find the recipe in app state - check both recent and saved recipes
            var foundRecipe: Recipe?
            
            // Check recent recipes
            if let recipe = appState.recentRecipes.first(where: { $0.id.uuidString == recipeID }) {
                foundRecipe = recipe
            }
            // Check saved recipes if not found in recent
            else if let recipe = appState.savedRecipes.first(where: { $0.id.uuidString == recipeID }) {
                foundRecipe = recipe
            }
            
            if let recipe = foundRecipe {
                // Store photos in PhotoStorageManager (single source of truth)
                PhotoStorageManager.shared.storePhotos(
                    fridgePhoto: photos.before,
                    mealPhoto: photos.after,
                    for: recipe.id
                )
                print("✅ Stored CloudKit photos in PhotoStorageManager for recipe: \(recipe.name)")
                print("    - Before photo: \(photos.before != nil ? "✓" : "✗")")
                print("    - After photo: \(photos.after != nil ? "✓" : "✗")")
                
                // Check if this recipe already exists in savedRecipesWithPhotos
                if !appState.savedRecipesWithPhotos.contains(where: { $0.recipe.id == recipe.id }) {
                    // Add to savedRecipesWithPhotos so it's available for video generation
                    appState.saveRecipeWithPhotos(recipe, beforePhoto: photos.before, afterPhoto: photos.after)
                    print("✅ Added CloudKit recipe with photos to app state: \(recipe.name)")
                } else {
                    // Update existing entry with CloudKit photos if they're missing
                    if let index = appState.savedRecipesWithPhotos.firstIndex(where: { $0.recipe.id == recipe.id }) {
                        let existing = appState.savedRecipesWithPhotos[index]
                        
                        // Only update if we have new photos that were missing
                        if existing.afterPhoto == nil && photos.after != nil {
                            // Use the public updateAfterPhoto method
                            appState.updateAfterPhoto(for: recipe.id, afterPhoto: photos.after!)
                            print("✅ Updated CloudKit recipe with after photo: \(recipe.name)")
                        }
                        
                        // If before photo is missing and we have it from CloudKit, we need to re-save
                        if existing.beforePhoto == nil && photos.before != nil {
                            // Remove and re-add with both photos
                            appState.savedRecipesWithPhotos.removeAll { $0.recipe.id == recipe.id }
                            appState.saveRecipeWithPhotos(recipe, beforePhoto: photos.before, afterPhoto: photos.after ?? existing.afterPhoto)
                            print("✅ Updated CloudKit recipe with before photo: \(recipe.name)")
                        }
                    }
                }
            }
        } catch {
            print("❌ Failed to fetch CloudKit photos for recipe \(recipeID): \(error)")
        }
    }
    
    /// Batch fetch photos for multiple recipes
    @MainActor
    func fetchPhotosForRecipes(_ recipes: [Recipe], appState: AppState) async {
        print("🎬 Batch fetching photos for \(recipes.count) CloudKit recipes...")
        
        // Use TaskGroup for parallel fetching
        await withTaskGroup(of: Void.self) { group in
            for recipe in recipes {
                group.addTask {
                    await self.fetchRecipeWithPhotosForAppState(recipeID: recipe.id.uuidString, appState: appState)
                }
            }
        }
        
        print("✅ Completed batch photo fetch for \(recipes.count) recipes")
    }
}
