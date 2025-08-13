//
//  CloudKitRecipeCache.swift
//  SnapChef
//
//  Created on 1/13/2025
//  Manages local caching of CloudKit recipes to prevent redundant downloads
//

import Foundation
import SwiftUI

/// Manages local caching of CloudKit recipes to prevent redundant downloads
@MainActor
class CloudKitRecipeCache: ObservableObject {
    static let shared = CloudKitRecipeCache()
    
    // Cache storage
    @Published var cachedRecipes: [Recipe] = []
    @Published var lastFetchDate: Date?
    @Published var isLoading = false
    
    // User defaults keys
    private let lastFetchKey = "CloudKitRecipesLastFetch"
    private let cachedRecipesKey = "CloudKitCachedRecipes"
    private let recipeFetchInterval: TimeInterval = 300 // 5 minutes
    
    // Track which recipe IDs we already have locally
    private var localRecipeIDs: Set<UUID> = []
    
    private let cloudKitManager = CloudKitRecipeManager.shared
    private let authManager = CloudKitAuthManager.shared
    
    private init() {
        loadCachedData()
    }
    
    // MARK: - Public Methods
    
    /// Get recipes with intelligent caching - only fetches missing recipes
    func getRecipes(forceRefresh: Bool = false) async -> [Recipe] {
        // If not authenticated, return empty
        guard authManager.isAuthenticated else {
            print("📱 CloudKitCache: User not authenticated, returning empty recipes")
            return []
        }
        
        // Check if we need to refresh
        let shouldRefresh = forceRefresh || shouldFetchFromCloudKit()
        
        if !shouldRefresh && !cachedRecipes.isEmpty {
            print("📱 CloudKitCache: Using cached recipes (count: \(cachedRecipes.count))")
            return cachedRecipes
        }
        
        // If already loading, wait for current load to complete
        if isLoading {
            print("📱 CloudKitCache: Already loading, waiting for completion...")
            // Wait a bit for the current load to complete
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            return cachedRecipes
        }
        
        isLoading = true
        
        do {
            // Fetch only new recipes that we don't have locally
            let newRecipes = try await fetchNewRecipesOnly()
            
            // Merge with existing cached recipes
            if !newRecipes.isEmpty {
                mergeRecipes(newRecipes)
                saveToCache()
            }
            
            // Update last fetch date
            lastFetchDate = Date()
            UserDefaults.standard.set(lastFetchDate, forKey: lastFetchKey)
            
            print("✅ CloudKitCache: Updated cache with \(newRecipes.count) new recipes, total: \(cachedRecipes.count)")
            
        } catch {
            print("❌ CloudKitCache: Failed to fetch recipes: \(error)")
        }
        
        isLoading = false
        return cachedRecipes
    }
    
    /// Clear the cache and force a fresh fetch
    func clearCache() {
        cachedRecipes.removeAll()
        localRecipeIDs.removeAll()
        lastFetchDate = nil
        
        UserDefaults.standard.removeObject(forKey: cachedRecipesKey)
        UserDefaults.standard.removeObject(forKey: lastFetchKey)
        
        print("🗑️ CloudKitCache: Cache cleared")
    }
    
    /// Add a single recipe to the cache
    func addRecipeToCache(_ recipe: Recipe) {
        if !localRecipeIDs.contains(recipe.id) {
            cachedRecipes.append(recipe)
            localRecipeIDs.insert(recipe.id)
            saveToCache()
            print("➕ CloudKitCache: Added recipe to cache: \(recipe.name)")
        }
    }
    
    /// Remove a recipe from the cache
    func removeRecipeFromCache(_ recipeID: UUID) {
        cachedRecipes.removeAll { $0.id == recipeID }
        localRecipeIDs.remove(recipeID)
        saveToCache()
        print("➖ CloudKitCache: Removed recipe from cache")
    }
    
    // MARK: - Private Methods
    
    private func shouldFetchFromCloudKit() -> Bool {
        // If we've never fetched, we should fetch
        guard let lastFetch = lastFetchDate else {
            print("📱 CloudKitCache: No previous fetch date, will fetch from CloudKit")
            return true
        }
        
        // Check if enough time has passed since last fetch
        let timeSinceLastFetch = Date().timeIntervalSince(lastFetch)
        let shouldFetch = timeSinceLastFetch > recipeFetchInterval
        
        if shouldFetch {
            print("📱 CloudKitCache: \(Int(timeSinceLastFetch))s since last fetch, will refresh (threshold: \(Int(recipeFetchInterval))s)")
        } else {
            print("📱 CloudKitCache: Only \(Int(timeSinceLastFetch))s since last fetch, using cache")
        }
        
        return shouldFetch
    }
    
    private func fetchNewRecipesOnly() async throws -> [Recipe] {
        print("📱 CloudKitCache: Fetching only new recipes from CloudKit...")
        
        // Get all recipe IDs from CloudKit
        let savedRecipes = try await cloudKitManager.getUserSavedRecipes()
        let createdRecipes = try await cloudKitManager.getUserCreatedRecipes()
        
        // Combine all recipes
        let allCloudKitRecipes = savedRecipes + createdRecipes
        
        // Filter out recipes we already have locally
        let newRecipes = allCloudKitRecipes.filter { recipe in
            !localRecipeIDs.contains(recipe.id)
        }
        
        print("📱 CloudKitCache: Found \(newRecipes.count) new recipes out of \(allCloudKitRecipes.count) total")
        
        return newRecipes
    }
    
    private func mergeRecipes(_ newRecipes: [Recipe]) {
        for recipe in newRecipes {
            if !localRecipeIDs.contains(recipe.id) {
                cachedRecipes.append(recipe)
                localRecipeIDs.insert(recipe.id)
            }
        }
        
        // Sort by creation date (newest first)
        cachedRecipes.sort { $0.createdAt > $1.createdAt }
    }
    
    private func saveToCache() {
        // Save recipes to UserDefaults (or could use Core Data for larger datasets)
        if let encoded = try? JSONEncoder().encode(cachedRecipes) {
            UserDefaults.standard.set(encoded, forKey: cachedRecipesKey)
            print("💾 CloudKitCache: Saved \(cachedRecipes.count) recipes to local cache")
        }
    }
    
    private func loadCachedData() {
        // Load last fetch date
        lastFetchDate = UserDefaults.standard.object(forKey: lastFetchKey) as? Date
        
        // Load cached recipes
        if let data = UserDefaults.standard.data(forKey: cachedRecipesKey),
           let decoded = try? JSONDecoder().decode([Recipe].self, from: data) {
            cachedRecipes = decoded
            localRecipeIDs = Set(decoded.map { $0.id })
            print("📱 CloudKitCache: Loaded \(cachedRecipes.count) recipes from local cache")
        }
        
        if let lastFetch = lastFetchDate {
            let timeSince = Date().timeIntervalSince(lastFetch)
            print("📱 CloudKitCache: Last fetch was \(Int(timeSince))s ago")
        }
    }
}

// Note: Recipe already conforms to Codable in Recipe.swift
// We don't need to re-implement it here