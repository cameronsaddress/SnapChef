//
//  DataMigrator.swift
//  SnapChef
//
//  Comprehensive data migration from old storage systems to LocalRecipeManager
//

import Foundation
import SwiftUI

@MainActor
final class DataMigrator {
    static let shared = DataMigrator()
    
    private let migrationKeys = [
        "migratedToLocalRecipeManager": "v1_local_recipe_manager",
        "migratedLocalRecipeStorage": "v1_local_recipe_storage", 
        "migratedCloudKitCache": "v1_cloudkit_cache"
    ]
    
    private init() {}
    
    // MARK: - Main Migration Function
    
    func performMigrationIfNeeded() async {
        print("🔄 DataMigrator: Checking for pending migrations...")
        
        // 1. Migrate from savedRecipes.json
        if !UserDefaults.standard.bool(forKey: migrationKeys["migratedToLocalRecipeManager"]!) {
            await migrateFromSavedRecipesJSON()
        }
        
        // 2. Migrate from LocalRecipeStorage if it exists
        if !UserDefaults.standard.bool(forKey: migrationKeys["migratedLocalRecipeStorage"]!) {
            await migrateFromLocalRecipeStorage()
        }
        
        // 3. Migrate from CloudKitRecipeCache
        if !UserDefaults.standard.bool(forKey: migrationKeys["migratedCloudKitCache"]!) {
            await migrateFromCloudKitCache()
        }
        
        print("✅ DataMigrator: All migrations complete")
    }
    
    // MARK: - Migration from savedRecipes.json
    
    private func migrateFromSavedRecipesJSON() async {
        print("📁 Migrating from savedRecipes.json...")
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let filePath = documentsPath.appendingPathComponent("savedRecipes.json")
        
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            print("ℹ️ No savedRecipes.json found, skipping migration")
            UserDefaults.standard.set(true, forKey: migrationKeys["migratedToLocalRecipeManager"]!)
            return
        }
        
        do {
            let data = try Data(contentsOf: filePath)
            let savedRecipes = try JSONDecoder().decode([SavedRecipe].self, from: data)
            
            // Migrate each recipe to LocalRecipeManager
            var migratedCount = 0
            var skippedCount = 0
            
            for savedRecipe in savedRecipes {
                // Check if recipe already exists in LocalRecipeManager
                let recipeExists = LocalRecipeManager.shared.allRecipes.contains { $0.id == savedRecipe.recipe.id }
                
                if !recipeExists {
                    LocalRecipeManager.shared.saveRecipe(savedRecipe.recipe, capturedImage: savedRecipe.beforePhoto)
                    migratedCount += 1
                    print("  ✓ Migrated: \(savedRecipe.recipe.name)")
                } else if !LocalRecipeManager.shared.isRecipeSaved(savedRecipe.recipe.id) {
                    // Recipe exists but not marked as saved, mark it as saved
                    LocalRecipeManager.shared.saveRecipe(savedRecipe.recipe, capturedImage: savedRecipe.beforePhoto)
                    migratedCount += 1
                    print("  ✓ Updated save status: \(savedRecipe.recipe.name)")
                } else {
                    skippedCount += 1
                    print("  ⏭ Already exists: \(savedRecipe.recipe.name)")
                }
            }
            
            print("✅ Migration complete: \(migratedCount) migrated, \(skippedCount) already existed (total: \(savedRecipes.count))")
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationKeys["migratedToLocalRecipeManager"]!)
            
            // Optionally remove the old file after successful migration
            // try? FileManager.default.removeItem(at: filePath)
            
        } catch {
            print("❌ Failed to migrate from savedRecipes.json: \(error)")
        }
    }
    
    // MARK: - Migration from LocalRecipeStorage
    
    private func migrateFromLocalRecipeStorage() async {
        print("📁 Migrating from LocalRecipeStorage...")
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let recipesDir = documentsPath.appendingPathComponent("recipes")
        
        guard FileManager.default.fileExists(atPath: recipesDir.path) else {
            print("ℹ️ No LocalRecipeStorage directory found, skipping migration")
            UserDefaults.standard.set(true, forKey: migrationKeys["migratedLocalRecipeStorage"]!)
            return
        }
        
        do {
            let recipeFiles = try FileManager.default.contentsOfDirectory(at: recipesDir, includingPropertiesForKeys: nil)
            let jsonFiles = recipeFiles.filter { $0.pathExtension == "json" }
            
            var migratedCount = 0
            for file in jsonFiles {
                do {
                    let data = try Data(contentsOf: file)
                    let recipe = try JSONDecoder().decode(Recipe.self, from: data)
                    
                    // Check if recipe already exists in LocalRecipeManager
                    if !LocalRecipeManager.shared.isRecipeSaved(recipe.id) {
                        // Try to get the photo from PhotoStorageManager
                        let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
                        LocalRecipeManager.shared.saveRecipe(recipe, capturedImage: photos?.fridgePhoto)
                        migratedCount += 1
                        print("  ✓ Migrated: \(recipe.name)")
                    }
                } catch {
                    print("  ⚠️ Failed to migrate recipe from \(file.lastPathComponent): \(error)")
                }
            }
            
            print("✅ Migrated \(migratedCount)/\(jsonFiles.count) recipes from LocalRecipeStorage")
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationKeys["migratedLocalRecipeStorage"]!)
            
        } catch {
            print("❌ Failed to read LocalRecipeStorage directory: \(error)")
        }
    }
    
    // MARK: - Migration from CloudKitRecipeCache
    
    private func migrateFromCloudKitCache() async {
        print("📁 Migrating from CloudKitRecipeCache...")
        
        // Check if CloudKitRecipeCache has any cached recipes
        let cacheKey = "cloudkit_cached_recipes"
        
        guard let cachedData = UserDefaults.standard.data(forKey: cacheKey) else {
            print("ℹ️ No CloudKitRecipeCache found, skipping migration")
            UserDefaults.standard.set(true, forKey: migrationKeys["migratedCloudKitCache"]!)
            return
        }
        
        do {
            let cachedRecipes = try JSONDecoder().decode([Recipe].self, from: cachedData)
            
            var migratedCount = 0
            for recipe in cachedRecipes {
                // Check if recipe already exists in LocalRecipeManager
                if !LocalRecipeManager.shared.isRecipeSaved(recipe.id) {
                    // Try to get the photo from PhotoStorageManager
                    let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
                    LocalRecipeManager.shared.saveRecipe(recipe, capturedImage: photos?.fridgePhoto)
                    migratedCount += 1
                    print("  ✓ Migrated: \(recipe.name)")
                }
            }
            
            print("✅ Migrated \(migratedCount)/\(cachedRecipes.count) recipes from CloudKitRecipeCache")
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationKeys["migratedCloudKitCache"]!)
            
            // Clear the old cache
            UserDefaults.standard.removeObject(forKey: cacheKey)
            
        } catch {
            print("❌ Failed to migrate from CloudKitRecipeCache: \(error)")
        }
    }
    
    // MARK: - Cleanup Old Storage
    
    func cleanupOldStorageAfterMigration() {
        print("🧹 Cleaning up old storage systems...")
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Remove old storage files/directories
        let oldPaths = [
            documentsPath.appendingPathComponent("savedRecipes.json"),
            documentsPath.appendingPathComponent("recipes"),  // LocalRecipeStorage directory
            documentsPath.appendingPathComponent("CloudKitCache")
        ]
        
        for path in oldPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                do {
                    try FileManager.default.removeItem(at: path)
                    print("  ✓ Removed: \(path.lastPathComponent)")
                } catch {
                    print("  ⚠️ Failed to remove \(path.lastPathComponent): \(error)")
                }
            }
        }
        
        // Clear old UserDefaults keys
        let oldKeys = [
            "savedRecipesWithPhotos",
            "cloudkit_cached_recipes",
            "local_recipe_storage_ids",
            "hasSavedRecipes"
        ]
        
        for key in oldKeys {
            if UserDefaults.standard.object(forKey: key) != nil {
                UserDefaults.standard.removeObject(forKey: key)
                print("  ✓ Cleared UserDefaults key: \(key)")
            }
        }
        
        print("✅ Cleanup complete")
    }
    
    // MARK: - Verification
    
    func verifyMigration() -> (success: Bool, report: String) {
        let localRecipeCount = LocalRecipeManager.shared.allRecipes.count
        let savedRecipeCount = LocalRecipeManager.shared.getSavedRecipes().count
        
        var report = """
        📊 Migration Verification Report:
        --------------------------------
        Total recipes in LocalRecipeManager: \(localRecipeCount)
        Saved recipes: \(savedRecipeCount)
        
        Migration Status:
        """
        
        for (key, value) in migrationKeys {
            let status = UserDefaults.standard.bool(forKey: value) ? "✅" : "❌"
            report += "\n  \(status) \(key)"
        }
        
        let success = localRecipeCount > 0 || savedRecipeCount == 0
        
        report += "\n\nOverall Status: \(success ? "✅ Success" : "⚠️ Needs Review")"
        
        return (success, report)
    }
}