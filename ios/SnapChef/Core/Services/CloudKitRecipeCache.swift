//
//  CloudKitRecipeCache.swift
//  SnapChef
//
//  DEPRECATED: Use LocalRecipeManager instead
//  This file is kept for backward compatibility during migration
//  Will be removed in a future update
//
//  Created on 1/13/2025
//  Manages local caching of CloudKit recipes to prevent redundant downloads
//

import Foundation
import SwiftUI

/// Simple struct to hold recipe owner information for caching
struct RecipeOwnerInfo: Codable {
    let ownerID: String
    let ownerName: String
    
    init(ownerID: String, ownerName: String) {
        self.ownerID = ownerID
        self.ownerName = ownerName
    }
}

/// Manages local caching of CloudKit recipes to prevent redundant downloads
@MainActor
class CloudKitRecipeCache: ObservableObject {
    static let shared = CloudKitRecipeCache()

    // Cache storage
    @Published var cachedRecipes: [Recipe] = []
    @Published var lastFetchDate: Date?
    @Published var isLoading = false
    
    // Owner information cache - maps recipe ID to creator info
    private var recipeOwnerCache: [String: RecipeOwnerInfo] = [:]

    // User defaults keys
    private let lastFetchKey = "CloudKitRecipesLastFetch"
    private let cachedRecipesKey = "CloudKitCachedRecipes"
    private let recipeFetchInterval: TimeInterval = 86400 * 365 // Never auto-refresh - only fetch missing recipes
    
    // Enhanced caching
    private let cacheVersion = "v2" // Increment when cache structure changes
    private let maxCacheSize = 500 // Maximum recipes to cache
    private let maxCacheAge: TimeInterval = 86400 // 24 hours
    
    // Memory cache for faster access
    private var memoryCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 100 // Keep 100 recipes in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        return cache
    }()

    // Track which recipe IDs we already have locally
    private var localRecipeIDs: Set<UUID> = []

    private let cloudKitManager = CloudKitRecipeManager.shared
    private let authManager = UnifiedAuthManager.shared

    private init() {
        loadCachedData()
    }

    // MARK: - Public Methods

    /// Get recipes with intelligent caching - only fetches missing recipes
    func getRecipes(forceRefresh: Bool = false) async -> [Recipe] {
        // If we have cached recipes, ALWAYS use them unless force refresh
        // This ensures local-first approach works even when not authenticated
        if !cachedRecipes.isEmpty && !forceRefresh {
            print("📱 CloudKitCache: Using cached recipes (count: \(cachedRecipes.count)) - never re-downloading existing recipes")
            return cachedRecipes
        }
        
        // If not authenticated and need to fetch, return local cache or empty
        guard authManager.isAuthenticated else {
            if !cachedRecipes.isEmpty {
                print("📱 CloudKitCache: User not authenticated, returning \(cachedRecipes.count) locally cached recipes")
                return cachedRecipes
            } else {
                print("📱 CloudKitCache: User not authenticated and no local cache, returning empty")
                return []
            }
        }

        // Only fetch if cache is empty or force refresh requested
        if cachedRecipes.isEmpty {
            print("📱 CloudKitCache: Cache is empty, fetching recipes from CloudKit...")
        } else if forceRefresh {
            print("📱 CloudKitCache: Force refresh requested, checking for new recipes...")
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
                print("✅ CloudKitCache: Added \(newRecipes.count) new recipes, total: \(cachedRecipes.count)")
            } else {
                print("✅ CloudKitCache: No new recipes found")
            }

            // Update last fetch date
            lastFetchDate = Date()
            UserDefaults.standard.set(lastFetchDate, forKey: lastFetchKey)
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
        recipeOwnerCache.removeAll()
        lastFetchDate = nil

        UserDefaults.standard.removeObject(forKey: cachedRecipesKey)
        UserDefaults.standard.removeObject(forKey: lastFetchKey)
        UserDefaults.standard.removeObject(forKey: "CloudKitRecipeOwnerCache")

        print("🗑️ CloudKitCache: Cache cleared")
    }
    
    /// Force refresh recipes from CloudKit (user-initiated)
    func forceRefreshFromCloudKit() async {
        print("🔄 User-initiated force refresh from CloudKit")
        
        // Clear cache timestamp to force refresh
        lastFetchDate = nil
        
        // Fetch fresh data
        _ = await getRecipes(forceRefresh: true)
    }

    /// Add a single recipe to the cache
    func addRecipeToCache(_ recipe: Recipe, ownerID: String = "", ownerName: String = "") {
        if !localRecipeIDs.contains(recipe.id) {
            cachedRecipes.append(recipe)
            localRecipeIDs.insert(recipe.id)
            
            // Store owner information if provided
            if !ownerID.isEmpty {
                recipeOwnerCache[recipe.id.uuidString] = RecipeOwnerInfo(ownerID: ownerID, ownerName: ownerName)
            }
            
            saveToCache()
            print("➕ CloudKitCache: Added recipe to cache: \(recipe.name) by \(ownerName.isEmpty ? "Unknown" : ownerName)")
        }
    }

    /// Remove a recipe from the cache
    func removeRecipeFromCache(_ recipeID: UUID) {
        cachedRecipes.removeAll { $0.id == recipeID }
        localRecipeIDs.remove(recipeID)
        recipeOwnerCache.removeValue(forKey: recipeID.uuidString)
        saveToCache()
        print("➖ CloudKitCache: Removed recipe from cache")
    }

    // MARK: - Private Methods

    private func shouldFetchFromCloudKit() -> Bool {
        // Only fetch if cache is completely empty
        if cachedRecipes.isEmpty {
            print("📱 CloudKitCache: Cache is empty, will fetch from CloudKit")
            return true
        }
        
        // Never auto-refresh if we have cached recipes
        print("📱 CloudKitCache: Have \(cachedRecipes.count) cached recipes - not fetching")
        return false
    }

    private func fetchNewRecipesOnly() async throws -> [Recipe] {
        print("📱 CloudKitCache: Fetching only new recipes from CloudKit...")

        // FIXED: Only fetch created recipes (which are ALL user's recipes by ownerID)
        // This prevents double fetching since getUserCreatedRecipes already gets all recipes
        // where the user is the owner, which includes both created and saved recipes
        let createdRecipes = try await cloudKitManager.getUserCreatedRecipes()

        // Filter out recipes we already have locally
        let newRecipes = createdRecipes.filter { recipe in
            !localRecipeIDs.contains(recipe.id)
        }

        print("📱 CloudKitCache: Found \(newRecipes.count) new recipes out of \(createdRecipes.count) total")

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
        }
        
        // Save owner information cache
        if let ownerData = try? JSONEncoder().encode(recipeOwnerCache) {
            UserDefaults.standard.set(ownerData, forKey: "CloudKitRecipeOwnerCache")
        }
        
        print("💾 CloudKitCache: Saved \(cachedRecipes.count) recipes to local cache")
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
        
        // Load owner information cache
        if let ownerData = UserDefaults.standard.data(forKey: "CloudKitRecipeOwnerCache"),
           let decoded = try? JSONDecoder().decode([String: RecipeOwnerInfo].self, from: ownerData) {
            recipeOwnerCache = decoded
            print("📱 CloudKitCache: Loaded owner info for \(recipeOwnerCache.count) recipes")
        }

        if let lastFetch = lastFetchDate {
            let timeSince = Date().timeIntervalSince(lastFetch)
            print("📱 CloudKitCache: Last fetch was \(Int(timeSince))s ago")
        }
    }
    
    // MARK: - Owner Information Methods
    
    /// Get owner information for a recipe
    func getRecipeOwner(recipeID: String) -> RecipeOwnerInfo? {
        return recipeOwnerCache[recipeID]
    }
    
    /// Get owner name for a recipe by Recipe object
    func getRecipeOwnerName(for recipe: Recipe) -> String {
        if let ownerInfo = recipeOwnerCache[recipe.id.uuidString] {
            return ownerInfo.ownerName.isEmpty ? "Anonymous Chef" : ownerInfo.ownerName
        }
        
        // If no owner info cached, check if it's current user's recipe
        if let currentUser = UnifiedAuthManager.shared.currentUser {
            return currentUser.username ?? currentUser.displayName
        }
        
        return "Me"
    }
}

// Note: Recipe already conforms to Codable in Recipe.swift
// We don't need to re-implement it here
