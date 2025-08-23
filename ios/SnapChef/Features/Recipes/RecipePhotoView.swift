//
//  RecipePhotoView.swift
//  SnapChef
//
//  A reusable before/after photo view for recipe cards
//

import SwiftUI
import CloudKit

struct RecipePhotoView: View {
    let recipe: Recipe
    let width: CGFloat?
    let height: CGFloat
    let showLabels: Bool

    @State private var beforePhoto: UIImage?
    @State private var afterPhoto: UIImage?
    @State private var isLoadingPhotos = true
    @State private var showingAfterPhotoCapture = false
    @State private var isFetchingFromCloudKit = false
    @State private var hasAppeared = false
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    @EnvironmentObject var appState: AppState
    
    // OPTIMIZATION: Cache photos locally to prevent repeated PhotoStorageManager queries
    @State private var cachedStoredPhotos: PhotoStorageManager.RecipePhotos?
    @State private var cachedSavedRecipe: SavedRecipe?
    @State private var lastCacheUpdate = Date()
    
    // Singleton for tracking active fetch requests to prevent duplicates
    private static let fetchCoordinator = PhotoFetchCoordinator()

    init(recipe: Recipe, width: CGFloat? = nil, height: CGFloat = 100, showLabels: Bool = true) {
        self.recipe = recipe
        self.width = width
        self.height = height
        self.showLabels = showLabels
    }

    // OPTIMIZATION: Use cached values to prevent repeated expensive lookups
    private var storedPhotos: PhotoStorageManager.RecipePhotos? {
        // Return cached value without state modification during view updates
        return cachedStoredPhotos
    }
    
    // MARK: - Safe cache refresh methods
    private func refreshCacheIfNeeded() async {
        let now = Date()
        if cachedStoredPhotos == nil || now.timeIntervalSince(lastCacheUpdate) > 5.0 {
            await refreshCache()
        }
    }
    
    private func refreshCache() async {
        cachedStoredPhotos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
        lastCacheUpdate = Date()
    }

    private var savedRecipe: SavedRecipe? {
        // Return cached value without state modification
        return cachedSavedRecipe
    }

    private var displayBeforePhoto: UIImage? {
        // OPTIMIZATION: Use PhotoStorageManager as primary source for instant display
        if let storedPhoto = storedPhotos?.fridgePhoto {
            return storedPhoto
        }
        
        // Legacy fallback to appState for immediate display of older recipes
        if let legacyPhoto = savedRecipe?.beforePhoto {
            // Trigger migration only if not already done or in progress
            triggerPhotoMigrationIfNeeded()
            return legacyPhoto
        }
        
        // Fall back to CloudKit photo (slower, loaded asynchronously)
        return beforePhoto
    }

    private var displayAfterPhoto: UIImage? {
        // Cache refresh is handled in displayBeforePhoto to avoid duplicate calls
        
        // OPTIMIZATION: Use PhotoStorageManager as primary source for instant display
        if let storedPhoto = storedPhotos?.mealPhoto {
            return storedPhoto
        }
        
        // Legacy fallback to appState for immediate display of older recipes
        if let legacyPhoto = savedRecipe?.afterPhoto {
            // Migration is handled centrally in triggerPhotoMigrationIfNeeded
            return legacyPhoto
        }
        
        // Fall back to CloudKit photo (slower, loaded asynchronously)
        return afterPhoto
    }

    private var halfWidth: CGFloat? {
        guard let width = width else { return nil }
        return width / 2
    }

    var body: some View {
        ZStack {
            // Background gradient as fallback
            backgroundGradient

            // Photo content
            HStack(spacing: 0) {
                // Before (Fridge) Photo - Left Side
                beforePhotoView
                    .frame(width: halfWidth, height: height)
                    .clipped()
                    .overlay(photoOverlay)
                    .overlay(beforeLabel)

                // Divider line
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1)

                // After (Meal) Photo - Right Side
                Button(action: handleAfterPhotoTap) {
                    afterPhotoView
                        .frame(width: halfWidth, height: height)
                        .clipped()
                        .overlay(afterPhotoOverlay)
                        .overlay(afterLabel)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Loading indicator
            if isLoadingPhotos {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }
        }
        .frame(width: width, height: height)
        .task {
            // OPTIMIZATION: Prevent multiple onAppear calls and coordinate fetch requests
            guard !hasAppeared else { 
                // View reappeared - refresh cache and update loading state
                await refreshCacheIfNeeded()
                isLoadingPhotos = displayBeforePhoto == nil || displayAfterPhoto == nil
                return 
            }
            hasAppeared = true
            
            // Force cache refresh on first appear - safe async update
            await refreshCache()
            cachedSavedRecipe = appState.savedRecipesWithPhotos.first(where: { $0.recipe.id == recipe.id })
            
            // OPTIMIZATION: Only load from CloudKit if no local photos exist AND not already fetching
            if (displayBeforePhoto == nil || displayAfterPhoto == nil) && !isFetchingFromCloudKit {
                // Check if another instance is already fetching this recipe
                if !RecipePhotoView.fetchCoordinator.isAlreadyFetching(recipe.id) {
                    loadPhotosFromCloudKit()
                } else {
                    // Another instance is fetching - wait for completion
                    listenForFetchCompletion()
                }
            } else {
                // We have local photos, so we're not loading
                isLoadingPhotos = false
            }
        }
        .fullScreenCover(isPresented: $showingAfterPhotoCapture) {
            AfterPhotoCaptureView(
                afterPhoto: $afterPhoto,
                recipeID: recipe.id.uuidString
            )
            .onDisappear {
                if let photo = afterPhoto {
                    // Save the after photo to PhotoStorageManager (single source of truth)
                    PhotoStorageManager.shared.storeMealPhoto(photo, for: recipe.id)
                    // Also update appState for backwards compatibility
                    appState.updateAfterPhoto(for: recipe.id, afterPhoto: photo)
                }
            }
        }
    }

    // MARK: - View Builders

    private var backgroundGradient: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "#667eea"),
                        Color(hex: "#764ba2")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var beforePhotoView: some View {
        Group {
            if let photo = displayBeforePhoto {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                beforePhotoPlaceholder
            }
        }
    }

    private var beforePhotoPlaceholder: some View {
        VStack {
            Image(systemName: "refrigerator")
                .font(.system(size: max(height * 0.25, 20)))  // Ensure minimum size
                .foregroundColor(.white.opacity(0.5))
            if showLabels {
                Text("Fridge")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
    }

    private var afterPhotoView: some View {
        Group {
            if let photo = displayAfterPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                afterPhotoPlaceholder
            }
        }
    }

    private var afterPhotoPlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "camera.fill")
                .font(.system(size: max(height * 0.2, 16)))  // Ensure minimum size
                .foregroundColor(.white.opacity(0.7))
            if showLabels {
                Text("Take Photo")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.1))
        .overlay(pulsingBorder)
    }

    private var pulsingBorder: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(Color.white.opacity(0.3), lineWidth: 1)
            .scaleEffect(1.02)
            .opacity(0.5)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: true)
    }

    private var photoOverlay: some View {
        Rectangle()
            .fill(Color.black.opacity(0.2))
    }

    private var afterPhotoOverlay: some View {
        Group {
            if displayAfterPhoto != nil {
                Rectangle()
                    .fill(Color.black.opacity(0.2))
            }
        }
    }

    private var beforeLabel: some View {
        Group {
            if showLabels && displayBeforePhoto != nil {
                VStack {
                    Spacer()
                    labelBadge(text: "BEFORE")
                        .padding(.bottom, 4)
                }
            }
        }
    }

    private var afterLabel: some View {
        Group {
            if showLabels && displayAfterPhoto != nil {
                VStack {
                    Spacer()
                    labelBadge(text: "AFTER")
                        .padding(.bottom, 4)
                }
            }
        }
    }

    private func labelBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.6))
            )
    }

    // MARK: - Actions

    private func handleAfterPhotoTap() {
        if displayAfterPhoto == nil {
            showingAfterPhotoCapture = true
        }
    }

    private func loadPhotosFromCloudKit() {
        // Prevent duplicate fetches
        guard !isFetchingFromCloudKit else { return }
        
        // Register this fetch to prevent other instances from duplicating
        RecipePhotoView.fetchCoordinator.startFetch(for: recipe.id)
        
        // OPTIMIZATION: Load photos in low priority background task
        Task(priority: .background) {
            await MainActor.run {
                self.isFetchingFromCloudKit = true
            }
            
            do {
                print("📸 RecipePhotoView: Loading photos from CloudKit for recipe \(recipe.id)")
                let photos = try await cloudKitRecipeManager.fetchRecipePhotos(for: recipe.id.uuidString)

                // Only update if we don't already have these photos locally
                if photos.before != nil && self.displayBeforePhoto == nil {
                    self.beforePhoto = photos.before
                }
                if photos.after != nil && self.displayAfterPhoto == nil {
                    self.afterPhoto = photos.after
                }

                // Store CloudKit photos in PhotoStorageManager (single source of truth)
                if photos.before != nil || photos.after != nil {
                    PhotoStorageManager.shared.storePhotos(
                        fridgePhoto: photos.before,
                        mealPhoto: photos.after,
                        for: recipe.id
                    )
                    print("📸 RecipePhotoView: Stored CloudKit photos in PhotoStorageManager for recipe \(recipe.id)")
                    
                    // Refresh cache after storing new photos
                    await self.refreshCache()
                }

                self.isLoadingPhotos = false
                self.isFetchingFromCloudKit = false
                
                // Notify coordinator that fetch is complete
                RecipePhotoView.fetchCoordinator.completeFetch(for: recipe.id, photos: photos)
            } catch {
                print("⚠️ RecipePhotoView: Failed to load photos from CloudKit: \(error)")
                self.isLoadingPhotos = false
                self.isFetchingFromCloudKit = false
                
                // Notify coordinator that fetch failed
                RecipePhotoView.fetchCoordinator.failFetch(for: recipe.id, error: error)
            }
        }
    }
    
    /// Listen for fetch completion from another instance
    private func listenForFetchCompletion() {
        RecipePhotoView.fetchCoordinator.onFetchComplete(for: recipe.id) { photos in
            Task { @MainActor in
                // Update photos if we received them
                if let photos = photos {
                    if photos.before != nil && self.displayBeforePhoto == nil {
                        self.beforePhoto = photos.before
                    }
                    if photos.after != nil && self.displayAfterPhoto == nil {
                        self.afterPhoto = photos.after
                    }
                    
                    // Refresh cache
                    await self.refreshCache()
                }
                
                self.isLoadingPhotos = false
            }
        }
    }
    
    /// Trigger photo migration only if needed (prevents duplicates)
    private func triggerPhotoMigrationIfNeeded() {
        guard let savedRecipe = savedRecipe,
              savedRecipe.beforePhoto != nil || savedRecipe.afterPhoto != nil else {
            return
        }
        
        // Check if migration is needed and start it
        if PhotoMigrationCoordinator.shared.startMigration(for: recipe.id) {
            Task(priority: .background) {
                do {
                    PhotoStorageManager.shared.storePhotos(
                        fridgePhoto: savedRecipe.beforePhoto,
                        mealPhoto: savedRecipe.afterPhoto,
                        for: recipe.id
                    )
                    
                    await MainActor.run {
                        PhotoMigrationCoordinator.shared.completeMigration(for: recipe.id)
                        print("📸 RecipePhotoView: Successfully migrated photos for recipe \(recipe.id)")
                    }
                    
                    // Refresh cache after successful migration
                    await refreshCache()
                } catch {
                    await MainActor.run {
                        PhotoMigrationCoordinator.shared.failMigration(for: recipe.id)
                        print("⚠️ RecipePhotoView: Failed to migrate photos for recipe \(recipe.id): \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Photo Migration Coordinator
/// Prevents duplicate photo migrations for the same recipe
@MainActor
class PhotoMigrationCoordinator: ObservableObject {
    static let shared = PhotoMigrationCoordinator()
    
    private var migratedRecipes: Set<UUID> = []
    private var activeMigrations: Set<UUID> = []
    
    private init() {}
    
    func isAlreadyMigrated(_ recipeId: UUID) -> Bool {
        return migratedRecipes.contains(recipeId)
    }
    
    func isCurrentlyMigrating(_ recipeId: UUID) -> Bool {
        return activeMigrations.contains(recipeId)
    }
    
    func startMigration(for recipeId: UUID) -> Bool {
        guard !migratedRecipes.contains(recipeId) && !activeMigrations.contains(recipeId) else {
            return false // Already migrated or migration in progress
        }
        activeMigrations.insert(recipeId)
        return true
    }
    
    func completeMigration(for recipeId: UUID) {
        activeMigrations.remove(recipeId)
        migratedRecipes.insert(recipeId)
    }
    
    func failMigration(for recipeId: UUID) {
        activeMigrations.remove(recipeId)
        // Don't mark as migrated on failure so it can be retried
    }
}

// MARK: - Photo Fetch Coordinator
/// Prevents duplicate photo fetch requests for the same recipe
@MainActor
class PhotoFetchCoordinator: ObservableObject {
    private var activeFetches: Set<UUID> = []
    private var completionHandlers: [UUID: [((before: UIImage?, after: UIImage?)?) -> Void]] = [:]
    
    func isAlreadyFetching(_ recipeId: UUID) -> Bool {
        return activeFetches.contains(recipeId)
    }
    
    func startFetch(for recipeId: UUID) {
        activeFetches.insert(recipeId)
    }
    
    func completeFetch(for recipeId: UUID, photos: (before: UIImage?, after: UIImage?)) {
        activeFetches.remove(recipeId)
        
        // Notify all waiting handlers
        if let handlers = completionHandlers[recipeId] {
            for handler in handlers {
                handler(photos)
            }
            completionHandlers[recipeId] = nil
        }
    }
    
    func failFetch(for recipeId: UUID, error: Error) {
        activeFetches.remove(recipeId)
        
        // Notify all waiting handlers with nil
        if let handlers = completionHandlers[recipeId] {
            for handler in handlers {
                handler(nil)
            }
            completionHandlers[recipeId] = nil
        }
    }
    
    func onFetchComplete(for recipeId: UUID, handler: @escaping ((before: UIImage?, after: UIImage?)?) -> Void) {
        if completionHandlers[recipeId] == nil {
            completionHandlers[recipeId] = []
        }
        completionHandlers[recipeId]?.append(handler)
    }
}

// MARK: - Compact Version for Grid Cards
struct CompactRecipePhotoView: View {
    let recipe: Recipe
    @State private var beforePhoto: UIImage?
    @State private var afterPhoto: UIImage?
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    @EnvironmentObject var appState: AppState

    var body: some View {
        RecipePhotoView(
            recipe: recipe,
            width: 140,
            height: 140,
            showLabels: false
        )
    }
}
