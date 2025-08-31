//
//  BrandedSharePopup.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import Combine
import CloudKit
import TikTokOpenShareSDK

struct BrandedSharePopup: View {
    @StateObject private var shareService = ShareService.shared
    @ObservedObject var authManager = UnifiedAuthManager.shared
    @State private var selectedPlatform: SharePlatformType?
    @State private var showingPlatformView = false
    @State private var animationScale: CGFloat = 0.8
    @State private var animationOpacity: Double = 0
    @State private var hasSharedToFeed = false
    
    // TikTok direct share states
    @State private var showAfterPhotoPrompt = false
    @State private var showVideoGeneration = false
    @State private var showAfterPhotoCamera = false
    @State private var capturedAfterPhoto: UIImage?
    @State private var currentRecipe: Recipe?
    @State private var currentBeforeImage: UIImage?
    @State private var currentAfterImage: UIImage?
    
    // Instagram share content with photos
    @State private var instagramShareContent: ShareContent?
    
    @Environment(\.dismiss) var dismiss

    let content: ShareContent

    // Platform grid layout - 3 columns for better visibility
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    // Show all major platforms for consistent experience
    private var displayPlatforms: [SharePlatformType] {
        // Always show these platforms, regardless of installation
        // Users expect to see them and we'll handle fallbacks
        return [
            .tiktok,
            .instagram,
            .instagramStory,
            .twitter,
            .messages,
            .copy
        ]
    }

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dismiss()
                    }
                }

            // Popup content
            VStack(spacing: 0) {
                // Handle bar
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Title
                Text("Share your creation")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)

                // Subtitle
                Text("Choose where to share your masterpiece")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 24)

                // Platform grid
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(displayPlatforms, id: \.self) { platform in
                        PlatformButton(
                            platform: platform,
                            isSelected: selectedPlatform == platform,
                            action: {
                                handlePlatformSelection(platform)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)

                // Cancel button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dismiss()
                    }
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(radius: 20)
            )
            .padding(.horizontal, 16)
            .scaleEffect(animationScale)
            .opacity(animationOpacity)
            .onAppear {
                print("🔍 DEBUG: BrandedSharePopup appeared")
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    animationScale = 1.0
                    animationOpacity = 1.0
                }
                
                // Automatically share to user's followers' feeds when popup opens
                if !hasSharedToFeed {
                    Task {
                        await shareToFollowersFeed()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPlatformView) {
            if let platform = selectedPlatform {
                platformSpecificView(for: platform)
            }
        }
        .sheet(isPresented: $showAfterPhotoPrompt) {
            AfterPhotoPromptView(
                onCapture: {
                    showAfterPhotoPrompt = false // Close the prompt first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showAfterPhotoCamera = true
                    }
                },
                onSkip: {
                    showAfterPhotoPrompt = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showVideoGeneration = true
                    }
                    // Static share will be handled in video generation view
                }
            )
        }
        .fullScreenCover(isPresented: $showVideoGeneration) {
            if let recipe = currentRecipe {
                VideoGenerationView(
                    recipe: recipe,
                    beforeImage: currentBeforeImage,
                    afterImage: capturedAfterPhoto ?? currentAfterImage,
                    onComplete: { videoURL in
                        // Store the video URL and dismiss everything
                        let savedURL = videoURL
                        
                        // First dismiss the video generation view
                        showVideoGeneration = false
                        
                        // Then dismiss the popup after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                            
                            // Finally open share sheet after everything is dismissed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                openTikTokWithVideo(savedURL)
                            }
                        }
                    },
                    onError: { error in
                        print("Video generation failed: \(error)")
                        showVideoGeneration = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            dismiss()
                        }
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showAfterPhotoCamera) {
            AfterPhotoCameraCapture(image: $capturedAfterPhoto)
                .ignoresSafeArea()
                .onDisappear {
                    // When camera closes, check if we captured a photo
                    if let photo = capturedAfterPhoto, let recipe = currentRecipe {
                        // Save after photo
                        PhotoStorageManager.shared.storeMealPhoto(photo, for: recipe.id)
                        currentAfterImage = photo
                        
                        // Show video generation after a small delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showVideoGeneration = true
                        }
                    }
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DismissSharePopup"))) { _ in
            dismiss()
        }
    }

    private func handlePlatformSelection(_ platform: SharePlatformType) {
        selectedPlatform = platform

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Check if app is available or use fallback
        if platform.isAvailable || shouldShowCustomView(platform) {
            // Handle platform-specific actions
            switch platform {
            case .tiktok:
                // Direct TikTok sharing without TikTokShareView
                if case .recipe(let recipe) = content.type {
                    currentRecipe = recipe
                    let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
                    currentBeforeImage = photos?.fridgePhoto ?? photos?.pantryPhoto
                    currentAfterImage = photos?.mealPhoto
                    
                    // Don't dismiss the popup - let it stay open while we show the flow
                    if currentAfterImage == nil {
                        showAfterPhotoPrompt = true
                    } else {
                        showVideoGeneration = true
                    }
                }
                
            case .instagram, .instagramStory:
                print("🔍 BrandedSharePopup: Instagram share for \(content.type)")
                print("🔍 BrandedSharePopup: Input content has beforeImage: \(content.beforeImage != nil), afterImage: \(content.afterImage != nil)")
                
                // Load photos for Instagram share
                if case .recipe(let recipe) = content.type {
                    print("🔍 BrandedSharePopup: Loading photos for recipe \(recipe.id)")
                    let photos = PhotoStorageManager.shared.getPhotos(for: recipe.id)
                    print("🔍 BrandedSharePopup: PhotoStorage returned - fridge: \(photos?.fridgePhoto != nil), pantry: \(photos?.pantryPhoto != nil), meal: \(photos?.mealPhoto != nil)")
                    
                    let beforeImage = photos?.fridgePhoto ?? photos?.pantryPhoto ?? content.beforeImage
                    let afterImage = photos?.mealPhoto ?? content.afterImage
                    
                    print("🔍 BrandedSharePopup: Final images - before: \(beforeImage != nil), after: \(afterImage != nil)")
                    if let before = beforeImage {
                        print("🔍 BrandedSharePopup: beforeImage size: \(before.size)")
                    }
                    
                    // Create new ShareContent with photos
                    instagramShareContent = ShareContent(
                        type: content.type,
                        beforeImage: beforeImage,
                        afterImage: afterImage,
                        text: content.text
                    )
                } else {
                    // For non-recipe content, use original content
                    instagramShareContent = content
                }
                
                // Show platform-specific view
                showingPlatformView = true

            case .twitter:
                // Show X-specific view
                showingPlatformView = true

            case .facebook, .whatsapp:
                // Try direct share or fallback to web
                Task {
                    await shareService.share(to: platform)
                    if !platform.isAvailable {
                        // Show instructions or web fallback
                        showWebFallback(for: platform)
                    } else {
                        dismiss()
                    }
                }

            case .messages:
                // Show message composer
                showingPlatformView = true

            case .copy:
                // Direct copy to clipboard
                Task {
                    await shareService.share(to: platform)
                    
                    // Create activity for content sharing via copy
                    await createShareActivity(platform: platform)
                    
                    dismiss()
                }
            }
        } else {
            // Platform not available and no custom view - use web fallback
            showWebFallback(for: platform)
        }
    }

    private func shouldShowCustomView(_ platform: SharePlatformType) -> Bool {
        // These platforms have custom views that work even without the app
        switch platform {
        case .instagram, .instagramStory, .twitter, .messages:
            return true
        default:
            return false
        }
    }

    private func showWebFallback(for platform: SharePlatformType) {
        // Open web version or show instructions
        // This will be handled by ShareService
        Task {
            await shareService.share(to: platform)
        }
    }

    @ViewBuilder
    private func platformSpecificView(for platform: SharePlatformType) -> some View {
        switch platform {
        case .tiktok:
            TikTokShareView(content: content)  // Use the template selection view
        case .instagram:
            // Use instagramShareContent which has photos loaded
            InstagramShareView(content: instagramShareContent ?? content, isStory: false)
        case .instagramStory:
            // Use instagramShareContent which has photos loaded
            InstagramShareView(content: instagramShareContent ?? content, isStory: true)
        case .twitter:
            XShareView(content: content)
        case .messages:
            MessagesShareView(content: content)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Activity Creation
    private func createShareActivity(platform: SharePlatformType) async {
        guard UnifiedAuthManager.shared.isAuthenticated,
              let userID = UnifiedAuthManager.shared.currentUser?.recordID,
              let userName = UnifiedAuthManager.shared.currentUser?.displayName else {
            return
        }
        
        var activityType = "contentShared"
        var metadata: [String: Any] = ["platform": platform.rawValue]
        
        // Determine content type and add specific metadata
        switch content.type {
        case .recipe(let recipe):
            activityType = "recipeShared"
            metadata["recipeId"] = recipe.id.uuidString
            metadata["recipeName"] = recipe.name
        case .achievement(let achievementName):
            activityType = "achievementShared"
            metadata["achievementName"] = achievementName
        case .challenge(let challenge):
            activityType = "challengeShared"
            metadata["challengeId"] = challenge.id
            metadata["challengeName"] = challenge.title
        case .profile:
            activityType = "profileShared"
        case .teamInvite(let teamName, let joinCode):
            activityType = "teamInviteShared"
            metadata["teamName"] = teamName
            metadata["joinCode"] = joinCode
        case .leaderboard:
            activityType = "leaderboardShared"
        }
        
        do {
            try await CloudKitSyncService.shared.createActivity(
                type: activityType,
                actorID: userID,
                recipeID: metadata["recipeId"] as? String,
                recipeName: metadata["recipeName"] as? String,
                challengeID: metadata["challengeId"] as? String,
                challengeName: metadata["challengeName"] as? String
            )
        } catch {
            print("Failed to create share activity: \(error)")
        }
    }
    
    // MARK: - Share to Followers Feed
    private func shareToFollowersFeed() async {
        guard authManager.isAuthenticated,
              let currentUserID = authManager.currentUser?.recordID,
              let currentUserName = authManager.currentUser?.displayName else {
            print("❌ Cannot share to feed: User not authenticated")
            return
        }
        
        // Mark that we've shared to prevent duplicate shares
        hasSharedToFeed = true
        
        // Determine the activity type and metadata based on content type
        var activityType = "recipeShared"
        var recipeID: String?
        var recipeName: String?
        var challengeID: String?
        var challengeName: String?
        
        switch content.type {
        case .recipe(let recipe):
            activityType = "recipeShared"
            recipeID = recipe.id.uuidString
            recipeName = recipe.name
            print("📤 Creating activity for recipe '\(recipe.name)'")
            
        case .challenge(let challenge):
            activityType = "challengeShared"
            challengeID = challenge.id
            challengeName = challenge.title
            print("📤 Creating activity for challenge '\(challenge.title)'")
            
        case .achievement(let achievementName):
            activityType = "achievementShared"
            print("📤 Creating activity for achievement '\(achievementName)'")
            
        case .leaderboard:
            activityType = "leaderboardShared"
            print("📤 Creating activity for leaderboard share")
            
        default:
            print("📤 Creating activity for content share")
        }
        
        do {
            // Create a single public activity that will appear in followers' feeds
            // The feed system will automatically show this to followers
            // No targetUserID means it's a public activity from this user
            try await CloudKitSyncService.shared.createActivity(
                type: activityType,
                actorID: currentUserID,
                targetUserID: nil,  // No specific target - this is a public activity
                recipeID: recipeID,
                recipeName: recipeName,
                challengeID: challengeID,
                challengeName: challengeName
            )
            
            print("✅ Activity created successfully - will appear in followers' feeds")
            
        } catch {
            print("❌ Failed to create activity: \(error)")
        }
    }
    
    // MARK: - TikTok Helper Functions
    private func openTikTokWithVideo(_ videoURL: URL) {
        // Use TikTok ShareKit API directly
        print("🎬 TikTok: Starting TikTok ShareKit share")
        
        Task {
            do {
                // First save to Photos to get localIdentifier (required by TikTok ShareKit)
                let localIdentifier = try await saveVideoToPhotos(videoURL)
                print("✅ Video saved to Photos with identifier: \(localIdentifier)")
                
                // Generate caption based on content
                let caption = generateTikTokCaption()
                
                // Share to TikTok using ShareKit
                await shareToTikTokApp(localIdentifier: localIdentifier, caption: caption)
                
            } catch {
                print("❌ Failed to share to TikTok: \(error)")
                // Fallback to share sheet if TikTok share fails
                await showShareSheetFallback(videoURL)
            }
        }
    }
    
    private func saveVideoToPhotos(_ videoURL: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            ViralVideoExporter.saveToPhotos(videoURL: videoURL) { result in
                switch result {
                case .success(let identifier):
                    continuation.resume(returning: identifier)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func shareToTikTokApp(localIdentifier: String, caption: String) async {
        await withCheckedContinuation { continuation in
            ViralVideoExporter.shareToTikTok(
                localIdentifiers: [localIdentifier],
                caption: caption
            ) { result in
                switch result {
                case .success:
                    print("✅ TikTok ShareKit: Video shared successfully")
                case .failure(let error):
                    print("❌ TikTok ShareKit error: \(error)")
                }
                continuation.resume()
            }
        }
    }
    
    private func generateTikTokCaption() -> String {
        switch content.type {
        case .recipe(let recipe):
            return "From fridge chaos to \(recipe.name)! 🤖✨ Made with @SnapChefApp #SnapChef #AIRecipes #CookingHacks #FoodWaste #SmartCooking"
        default:
            return "Made with @SnapChefApp 🤖✨ #SnapChef #AIRecipes #CookingHacks"
        }
    }
    
    @MainActor
    private func showShareSheetFallback(_ videoURL: URL) async {
        // Fallback to share sheet if TikTok ShareKit fails
        let items: [Any] = [videoURL]
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        activityVC.excludedActivityTypes = [
            .print,
            .assignToContact,
            .addToReadingList,
            .openInIBooks,
            .markupAsPDF
        ]
        
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootVC = window.rootViewController {
            
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            topVC.present(activityVC, animated: true) {
                print("🎬 Fallback: Share sheet presented")
            }
        }
    }
}

// MARK: - Platform Button
struct PlatformButton: View {
    let platform: SharePlatformType
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon container
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    platform.brandColor.opacity(0.8),
                                    platform.brandColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: platform.brandColor.opacity(0.3),
                            radius: isPressed ? 2 : 8,
                            y: isPressed ? 1 : 4
                        )

                    Image(systemName: platform.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)

                // Platform name
                Text(platform.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - After Photo Prompt View
struct AfterPhotoPromptView: View {
    let onCapture: () -> Void
    let onSkip: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("📸 Add Your Final Dish?")
                .font(.title2.bold())
            
            // Description
            Text("Show off your cooking! Add a photo of the finished meal for a complete before/after video.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Camera icon
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding()
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: onCapture) {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: onSkip) {
                    Text("Skip for Now")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .presentationDetents([.height(400)])
    }
}

// MARK: - Video Generation View
struct VideoGenerationView: View {
    let recipe: Recipe
    let beforeImage: UIImage?
    let afterImage: UIImage?
    let onComplete: (URL) -> Void
    let onError: (Error) -> Void
    
    @State private var progress: Double = 0
    @State private var statusMessage = "Preparing your video..."
    @State private var isGenerating = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Title
                Text("Creating Your TikTok")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                // Progress indicator
                if isGenerating {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(y: 2)
                        .padding(.horizontal, 40)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                }
                
                // Status message
                Text(statusMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Recipe info
                VStack(alignment: .leading, spacing: 8) {
                    Label(recipe.name, systemImage: "fork.knife")
                    Label("\(recipe.prepTime + recipe.cookTime) minutes", systemImage: "clock")
                    Label("\(recipe.ingredients.count) ingredients", systemImage: "cart")
                }
                .font(.caption)
                .foregroundColor(.gray)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                
                // Cancel button
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.red)
                .padding(.top)
            }
            .padding()
        }
        .onAppear {
            // Use detached task to prevent cancellation
            Task.detached {
                await generateVideo()
            }
        }
    }
    
    func generateVideo() async {
        print("🎬 VideoGenerationView: Starting video generation")
        print("🎬 VideoGenerationView: Has before image: \(beforeImage != nil)")
        print("🎬 VideoGenerationView: Has after image: \(afterImage != nil)")
        
        await MainActor.run {
            isGenerating = true
        }
        
        // If no after image, generate static share
        if afterImage == nil {
            print("🎬 VideoGenerationView: No after image, generating static share")
            await MainActor.run {
                statusMessage = "Creating share image..."
            }
            await generateStaticShare()
            return
        }
        
        // Create ShareContent
        let content = ShareContent(
            type: .recipe(recipe),
            beforeImage: beforeImage,
            afterImage: afterImage
        )
        
        // Get render inputs
        guard let renderInputs = content.toRenderInputs() else {
            print("🎬 VideoGenerationView: Failed to get render inputs")
            await MainActor.run {
                onError(NSError(domain: "SnapChef", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to prepare video content"]))
                dismiss()
            }
            return
        }
        
        do {
            print("🎬 VideoGenerationView: Starting video engine render")
            await MainActor.run {
                statusMessage = "Generating video frames..."
                progress = 0.1
            }
            
            // Generate video with progress updates
            let videoEngine = ViralVideoEngine()
            
            // Run video generation and progress animation in parallel
            async let videoURL = videoEngine.render(
                template: .kineticTextSteps,
                recipe: renderInputs.recipe,
                media: renderInputs.media
            )
            
            // Animate progress while video generates
            async let _ : Void = {
                for i in stride(from: 0.2, through: 0.9, by: 0.1) {
                    await MainActor.run {
                        self.progress = i
                        if i < 0.4 {
                            self.statusMessage = "Rendering frames..."
                        } else if i < 0.7 {
                            self.statusMessage = "Adding effects..."
                        } else {
                            self.statusMessage = "Finalizing video..."
                        }
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second per step
                }
            }()
            
            // Wait for video to complete
            let finalURL = try await videoURL
            
            print("🎬 VideoGenerationView: Video generated successfully at: \(finalURL)")
            
            await MainActor.run {
                progress = 1.0
                statusMessage = "Video ready!"
                onComplete(finalURL)
                dismiss()
            }
        } catch {
            print("🎬 VideoGenerationView: Video generation failed: \(error)")
            await MainActor.run {
                onError(error)
                dismiss()
            }
        }
    }
    
    func generateStaticShare() async {
        do {
            let shareImage = createRecipeShareImage(
                recipe: recipe,
                fridgePhoto: beforeImage
            )
            
            // Save to temp
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("share_\(UUID().uuidString).jpg")
            
            if let jpegData = shareImage.jpegData(compressionQuality: 0.9) {
                try jpegData.write(to: tempURL)
                
                await MainActor.run {
                    onComplete(tempURL)
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                onError(error)
                dismiss()
            }
        }
    }
    
    func createRecipeShareImage(recipe: Recipe, fridgePhoto: UIImage?) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background gradient
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor] as CFArray
            let locations: [CGFloat] = [0, 1]
            
            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors,
                locations: locations
            ) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint.zero,
                    end: CGPoint(x: 0, y: size.height),
                    options: []
                )
            }
            
            // Fridge photo (if available)
            if let fridge = fridgePhoto {
                let imageRect = CGRect(x: 40, y: 100, width: 1000, height: 1000)
                
                // Add shadow
                context.cgContext.setShadow(offset: CGSize(width: 0, height: 10), blur: 20)
                UIColor.white.setFill()
                UIBezierPath(roundedRect: imageRect, cornerRadius: 20).fill()
                
                // Draw image
                context.cgContext.setShadow(offset: .zero, blur: 0)
                let path = UIBezierPath(roundedRect: imageRect, cornerRadius: 20)
                path.addClip()
                fridge.draw(in: imageRect)
            }
            
            // Text overlay
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = 10
            
            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 60),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let title = "From Fridge Chaos to\n\(recipe.name)!"
            title.draw(in: CGRect(x: 40, y: 1150, width: 1000, height: 200),
                      withAttributes: titleAttributes)
            
            // Features
            let featuresAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .paragraphStyle: paragraphStyle
            ]
            
            let features = "🤖 AI-Powered Recipes\n📸 Just Snap Your Fridge\n🍳 Personalized For You\n⏱ \(recipe.prepTime + recipe.cookTime) Minutes"
            features.draw(in: CGRect(x: 40, y: 1350, width: 1000, height: 400),
                         withAttributes: featuresAttributes)
            
            // SnapChef branding
            let brandingAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 48),
                .foregroundColor: UIColor.white
            ]
            
            "SNAPCHEF".draw(in: CGRect(x: 40, y: 1800, width: 1000, height: 100),
                           withAttributes: brandingAttributes)
        }
    }
}

// MARK: - Preview
#Preview {
    BrandedSharePopup(
        content: ShareContent(
            type: .recipe(MockDataProvider.shared.mockRecipe())
        )
    )
}
