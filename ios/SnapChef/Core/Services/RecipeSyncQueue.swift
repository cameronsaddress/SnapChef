//
//  RecipeSyncQueue.swift
//  SnapChef
//
//  Bridge between LocalRecipeStorage and CloudKitSyncEngine
//  Provides backward compatibility for existing code
//

import Foundation
import UIKit

@MainActor
final class RecipeSyncQueue {
    static let shared = RecipeSyncQueue()
    
    // This struct needs to be Codable for PersistentSyncQueue
    struct SyncOperation: Codable {
        let recipeId: String
        let type: String
        let timestamp: Date
    }
    
    private init() {}
    
    // MARK: - Public Methods for LocalRecipeStorage Compatibility
    
    func queueSave(_ recipe: Recipe, beforePhoto: UIImage? = nil) async {
        print("📤 RecipeSyncQueue: Queueing save for recipe: \(recipe.name)")
        
        // Delegate to CloudKitSyncEngine
        CloudKitSyncEngine.shared.queueRecipeForSync(recipe, image: beforePhoto)
    }
    
    func queueUnsave(_ recipeId: UUID) async {
        print("🗑 RecipeSyncQueue: Queueing unsave for recipe: \(recipeId)")
        
        // Delegate to CloudKitSyncEngine
        CloudKitSyncEngine.shared.queueRecipeForDeletion(recipeId)
    }
    
    func requeue(_ operation: SyncOperation) async {
        print("🔄 RecipeSyncQueue: Requeuing operation for recipe: \(operation.recipeId)")
        
        // Convert to proper format and requeue
        if operation.type == "save" {
            // Try to get the recipe from LocalRecipeManager
            if let recipeUUID = UUID(uuidString: operation.recipeId),
               let recipe = LocalRecipeManager.shared.allRecipes.first(where: { $0.id == recipeUUID }) {
                CloudKitSyncEngine.shared.queueRecipeForSync(recipe)
            }
        } else if operation.type == "unsave" {
            if let recipeUUID = UUID(uuidString: operation.recipeId) {
                CloudKitSyncEngine.shared.queueRecipeForDeletion(recipeUUID)
            }
        }
    }
    
    // MARK: - Sync Status
    
    func getPendingOperationsCount() -> Int {
        return CloudKitSyncEngine.shared.getPendingSyncCount()
    }
    
    func processPendingSync() async {
        await CloudKitSyncEngine.shared.processPendingSync()
    }
}