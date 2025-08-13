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
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    @EnvironmentObject var appState: AppState
    
    init(recipe: Recipe, width: CGFloat? = nil, height: CGFloat = 100, showLabels: Bool = true) {
        self.recipe = recipe
        self.width = width
        self.height = height
        self.showLabels = showLabels
    }
    
    // Computed properties to simplify complex conditionals
    private var storedPhotos: PhotoStorageManager.RecipePhotos? {
        PhotoStorageManager.shared.getPhotos(for: recipe.id)
    }
    
    private var savedRecipe: SavedRecipe? {
        appState.savedRecipesWithPhotos.first(where: { $0.recipe.id == recipe.id })
    }
    
    private var displayBeforePhoto: UIImage? {
        // Use PhotoStorageManager as primary source
        if let storedPhoto = storedPhotos?.fridgePhoto {
            return storedPhoto
        }
        // Fall back to CloudKit photo
        if let cloudKitPhoto = beforePhoto {
            return cloudKitPhoto
        }
        // Legacy fallback to appState
        return savedRecipe?.beforePhoto
    }
    
    private var displayAfterPhoto: UIImage? {
        // Use PhotoStorageManager as primary source
        if let storedPhoto = storedPhotos?.mealPhoto {
            return storedPhoto
        }
        // Fall back to CloudKit photo
        if let cloudKitPhoto = afterPhoto {
            return cloudKitPhoto
        }
        // Legacy fallback to appState
        return savedRecipe?.afterPhoto
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
        .onAppear {
            loadPhotosFromCloudKit()
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
                        Color(hex: "#667eea") ?? .purple,
                        Color(hex: "#764ba2") ?? .purple
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
                .font(.system(size: height * 0.25))
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
                .font(.system(size: height * 0.2))
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
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: UUID())
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
        Task {
            do {
                isLoadingPhotos = true
                let photos = try await cloudKitRecipeManager.fetchRecipePhotos(for: recipe.id.uuidString)
                
                await MainActor.run {
                    self.beforePhoto = photos.before
                    self.afterPhoto = photos.after
                    
                    // Store CloudKit photos in PhotoStorageManager (single source of truth)
                    if photos.before != nil || photos.after != nil {
                        PhotoStorageManager.shared.storePhotos(
                            fridgePhoto: photos.before,
                            mealPhoto: photos.after,
                            for: recipe.id
                        )
                        print("📸 RecipePhotoView: Stored CloudKit photos in PhotoStorageManager for recipe \(recipe.id)")
                    }
                    
                    self.isLoadingPhotos = false
                }
            } catch {
                print("Failed to load photos from CloudKit: \(error)")
                await MainActor.run {
                    self.isLoadingPhotos = false
                }
            }
        }
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