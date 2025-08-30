//
//  InstagramShareView.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import UIKit

struct InstagramShareView: View {
    let content: ShareContent
    let isStory: Bool
    @Environment(\.dismiss) var dismiss
    @State private var shareMode: ShareMode = .feed
    @State private var isGenerating = false
    @State private var generatedImage: UIImage?
    @State private var captionText = ""
    @State private var errorMessage: String?
    @State private var storyBackgroundStyle: StoryBackgroundStyle = .photo
    @State private var showTextOverlay = true
    @State private var captionCopied = false
    
    enum ShareMode: String, CaseIterable {
        case feed = "Feed"
        case story = "Story"
    }
    
    enum StoryBackgroundStyle: String, CaseIterable {
        case photo = "Photo"
        case gradient = "Gradient"
        case solid = "Solid"
    }
    
    init(content: ShareContent, isStory: Bool) {
        print("🔍 InstagramShareView init - beforeImage: \(content.beforeImage != nil), afterImage: \(content.afterImage != nil)")
        if let before = content.beforeImage {
            print("🔍 InstagramShareView init - beforeImage size: \(before.size)")
        }
        self.content = content
        self.isStory = isStory
        _shareMode = State(initialValue: isStory ? .story : .feed)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Clean white background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with segmented control
                    VStack(spacing: 16) {
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 30, height: 30)
                            }
                            
                            Spacer()
                            
                            Text("Share to Instagram")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Invisible spacer for balance
                            Color.clear
                                .frame(width: 30, height: 30)
                        }
                        .padding(.horizontal)
                        
                        // Segmented Control
                        Picker("Share Mode", selection: $shareMode) {
                            ForEach(ShareMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(Color(UIColor.systemBackground))
                    
                    ScrollView {
                        VStack(spacing: 24) {

                            // Large Preview (70% of screen)
                            VStack(spacing: 12) {
                                Text("Preview")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Preview with shadow
                                InstagramPreview(
                                    content: content,
                                    template: getAutoTemplate(),
                                    isStory: shareMode == .story,
                                    backgroundColor: getBackgroundColor()
                                )
                                .frame(height: UIScreen.main.bounds.height * 0.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.systemBackground))
                                        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                                )
                            }
                            .padding(.horizontal, 20)

                            // Mode-specific options
                            if shareMode == .feed {
                                // Caption Section for Feed
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Caption")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Text("\(captionText.count)/2200")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(captionText.count > 2200 ? .red : .secondary)
                                    }
                                    
                                    TextEditor(text: $captionText)
                                        .frame(height: 120)
                                        .padding(12)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .foregroundColor(.primary)
                                        .scrollContentBackground(.hidden)
                                        .onAppear {
                                            if captionText.isEmpty {
                                                captionText = generateCaption()
                                            }
                                        }
                                    
                                    // Inline hashtags
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(getTopHashtags(), id: \.self) { hashtag in
                                                Text("#\(hashtag)")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(Color(hex: "#FF0050"))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color(hex: "#FF0050").opacity(0.1))
                                                    )
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            } else {
                                // Story Options
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Background Style")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 12) {
                                        ForEach(StoryBackgroundStyle.allCases, id: \.self) { style in
                                            Button(action: { storyBackgroundStyle = style }) {
                                                VStack(spacing: 8) {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(getStylePreview(style))
                                                        .frame(width: 60, height: 90)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .stroke(
                                                                    storyBackgroundStyle == style ? Color(hex: "#FF0050") : Color.clear,
                                                                    lineWidth: 2
                                                                )
                                                        )
                                                    
                                                    Text(style.rawValue)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(.primary)
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    
                                    Toggle("Show Text Overlay", isOn: $showTextOverlay)
                                        .font(.system(size: 14, weight: .medium))
                                        .tint(Color(hex: "#FF0050"))
                                }
                                .padding(.horizontal, 20)
                            }


                            // Share Button
                            VStack(spacing: 8) {
                                Button(action: generateAndShare) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(hex: "#FF0050"),
                                                        Color(hex: "#00F2EA")
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(height: 56)
                                        
                                        if isGenerating {
                                            HStack(spacing: 12) {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                Text("Creating...")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                            }
                                        } else {
                                            HStack(spacing: 8) {
                                                Image(systemName: "square.and.arrow.up")
                                                Text(shareMode == .story ? "Share to Story" : "Share to Instagram")
                                            }
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        }
                                    }
                                }
                                .disabled(isGenerating)
                                
                                if captionCopied {
                                    Text("Caption copied to clipboard!")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .transition(.opacity.combined(with: .scale))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .onAppear {
            print("🔍 DEBUG: InstagramShareView appeared")
        }
    }

    // MARK: - Helper Methods
    
    private func getAutoTemplate() -> InstagramTemplate {
        switch content.type {
        case .recipe:
            return .classic // Use recipe template
        case .achievement, .challenge, .profile, .teamInvite, .leaderboard:
            return .modern // Use achievement template
        }
    }
    
    private func getBackgroundColor() -> Color {
        switch storyBackgroundStyle {
        case .photo:
            return Color.clear
        case .gradient:
            return Color(hex: "#FF0050")
        case .solid:
            return Color(hex: "#00F2EA")
        }
    }
    
    private func getStylePreview(_ style: StoryBackgroundStyle) -> some ShapeStyle {
        switch style {
        case .photo:
            return LinearGradient(
                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gradient:
            return LinearGradient(
                colors: [Color(hex: "#FF0050"), Color(hex: "#00F2EA")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solid:
            return LinearGradient(
                colors: [Color(hex: "#00F2EA")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func getTopHashtags() -> [String] {
        switch content.type {
        case .recipe(let recipe):
            // Use tags or difficulty instead of cuisine
            let mainTag = recipe.tags.first ?? "Homemade"
            return ["SnapChef", "FridgeToFeast", mainTag, "\(recipe.difficulty.rawValue)Recipe"]
        case .achievement:
            return ["SnapChef", "CookingWin", "Achievement"]
        case .challenge:
            return ["SnapChefChallenge", "CookingChallenge"]
        default:
            return ["SnapChef", "CookingApp"]
        }
    }

    private func generateCaption() -> String {
        switch content.type {
        case .recipe(let recipe):
            let totalTime = recipe.prepTime + recipe.cookTime
            let emoji = getRecipeEmoji(for: recipe)
            let primaryHashtag = (recipe.tags.first ?? "Homemade").replacingOccurrences(of: " ", with: "")
            
            return """
Just turned my sad fridge into \(recipe.name) 🎉

\(emoji) \(totalTime) min magic
📱 Get SnapChef on the App Store!

#\(primaryHashtag) #SnapChef #FridgeToFeast
"""
            
        case .achievement(let achievementName):
            return """
🏆 \(achievementName) unlocked!

Level up your kitchen game 👨‍🍳
📱 Download SnapChef on the App Store

#SnapChef #CookingWin
"""
            
        case .challenge(let challenge):
            return """
Challenge crushed: \(challenge.title) ✅

Who's next? 💪
📱 Join me on SnapChef (App Store)

#SnapChefChallenge
"""
            
        default:
            return """
Made with SnapChef 🍳
📱 Get it on the App Store!

#SnapChef
"""
        }
    }
    
    private func getRecipeEmoji(for recipe: Recipe) -> String {
        // Return emoji based on tags or recipe name
        let lowerTags = recipe.tags.map { $0.lowercased() }.joined(separator: " ")
        let lowerName = recipe.name.lowercased()
        let combined = lowerTags + " " + lowerName
        
        switch combined {
        case let c where c.contains("pasta") || c.contains("italian"):
            return "🍝"
        case let c where c.contains("taco") || c.contains("mexican"):
            return "🌮"
        case let c where c.contains("asian") || c.contains("chinese") || c.contains("stir-fry"):
            return "🥢"
        case let c where c.contains("curry") || c.contains("indian"):
            return "🍛"
        case let c where c.contains("burger") || c.contains("american"):
            return "🍔"
        case let c where c.contains("salad"):
            return "🥗"
        case let c where c.contains("soup"):
            return "🍲"
        default:
            return "🍳"
        }
    }

    private func generateContent() {
        isGenerating = true
        
        Task {
            do {
                // Generate image based on auto-selected template
                let image = try await InstagramContentGenerator.shared.generateContent(
                    template: getAutoTemplate(),
                    content: content,
                    isStory: shareMode == .story,
                    backgroundColor: getBackgroundColor(),
                    sticker: showTextOverlay && shareMode == .story ? .location : nil
                )
                
                await MainActor.run {
                    generatedImage = image
                    isGenerating = false
                    // Note: showingShareOptions was removed in the new design
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func generateAndShare() {
        print("🔍 InstagramShareView.generateAndShare - content has beforeImage: \(content.beforeImage != nil), afterImage: \(content.afterImage != nil)")
        
        // If image is already generated, share directly
        if generatedImage != nil {
            shareToInstagram()
        } else {
            // Generate image first, then share
            isGenerating = true
            
            Task {
                do {
                    let template = getAutoTemplate()
                    print("🔍 InstagramShareView.generateAndShare - using template: \(template)")
                    
                    // Generate image based on auto-selected template
                    let image = try await InstagramContentGenerator.shared.generateContent(
                        template: template,
                        content: content,
                        isStory: shareMode == .story,
                        backgroundColor: getBackgroundColor(),
                        sticker: showTextOverlay && shareMode == .story ? .location : nil
                    )
                    
                    await MainActor.run {
                        self.generatedImage = image
                        self.isGenerating = false
                        // Immediately share after generation
                        self.shareToInstagram()
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isGenerating = false
                    }
                }
            }
        }
    }

    private func shareToInstagram() {
        guard let image = generatedImage else { return }
        
        // Show caption copied feedback for feed posts
        if shareMode == .feed {
            UIPasteboard.general.string = captionText
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                captionCopied = true
            }
            
            // Hide after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    captionCopied = false
                }
            }
        }
        
        if shareMode == .story {
            shareToInstagramStory(image: image)
        } else {
            shareToInstagramFeed(image: image)
        }
    }

    private func shareToInstagramStory(image: UIImage) {
        guard let imageData = image.pngData() else { return }

        // Enhanced pasteboard items with attribution
        var pasteboardItems: [[String: Any]] = [[
            "com.instagram.sharedSticker.stickerImage": imageData,
            "com.instagram.sharedSticker.backgroundTopColor": "#FF0050",  // SnapChef brand colors
            "com.instagram.sharedSticker.backgroundBottomColor": "#00F2EA"
        ]]

        // Add deep link for attribution
        if let deepLink = content.deepLink {
            pasteboardItems[0]["com.instagram.sharedSticker.contentURL"] = deepLink.absoluteString
        } else {
            pasteboardItems[0]["com.instagram.sharedSticker.contentURL"] = "https://snapchef.app"
        }

        let pasteboardOptions = [
            UIPasteboard.OptionsKey.expirationDate: Date().addingTimeInterval(300)
        ]

        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)

        // Try with source application parameter for better attribution
        if let url = URL(string: "instagram-stories://share?source_application=com.snapchefapp.app") {
            UIApplication.shared.open(url) { success in
                if !success {
                    // Fallback to basic Instagram Stories
                    if let fallbackURL = URL(string: "instagram-stories://share") {
                        UIApplication.shared.open(fallbackURL)
                    }
                }
            }
        }
    }

    private func shareToInstagramFeed(image: UIImage) {
        // Caption is already in clipboard from shareToInstagram()
        // Save image to photo library with proper permission handling
        saveImageAndOpenInstagram(image: image)
    }

    private func saveImageAndOpenInstagram(image: UIImage) {
        // First normalize the image to ensure it's in the right format
        let normalizedImage = normalizeImage(image)

        // Use the SafePhotoSaver which doesn't import Photos framework
        SafePhotoSaver.shared.saveImageToPhotoLibrary(normalizedImage) { success, error in
            if success {
                // Open Instagram library after saving
                if let url = URL(string: "instagram://library") {
                    UIApplication.shared.open(url) { success in
                        if !success {
                            // Fallback to basic Instagram open
                            if let fallbackURL = URL(string: "instagram://") {
                                UIApplication.shared.open(fallbackURL)
                            }
                        }
                    }
                }
                // Create activity for successful Instagram share
                Task {
                    await createInstagramShareActivity(isStory: true)
                }
                
                // Create activity for successful Instagram share
                Task {
                    await createInstagramShareActivity(isStory: false)
                }
                
                self.dismiss()
            } else {
                self.errorMessage = error ?? "Failed to save image"
            }
        }
    }

    private func normalizeImage(_ image: UIImage) -> UIImage {
        // Create a new opaque image context (true = opaque, no alpha channel)
        UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
        defer { UIGraphicsEndImageContext() }

        // Fill with white background first
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: image.size))

        // Draw the image on top with normal blend mode
        image.draw(in: CGRect(origin: .zero, size: image.size), blendMode: .normal, alpha: 1.0)

        // Get the normalized image
        guard let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            // If normalization fails, return original
            return image
        }

        return normalizedImage
    }
    
    // MARK: - Activity Creation
    private func createInstagramShareActivity(isStory: Bool) async {
        guard UnifiedAuthManager.shared.isAuthenticated,
              let userID = UnifiedAuthManager.shared.currentUser?.recordID else {
            return
        }
        
        var activityType = isStory ? "instagramStoryShared" : "instagramFeedShared"
        var metadata: [String: Any] = ["platform": "instagram", "isStory": isStory]
        
        // Add content-specific metadata
        switch content.type {
        case .recipe(let recipe):
            activityType = isStory ? "recipeInstagramStoryShared" : "recipeInstagramFeedShared"
            metadata["recipeId"] = recipe.id.uuidString
            metadata["recipeName"] = recipe.name
        case .achievement(let achievementName):
            activityType = isStory ? "achievementInstagramStoryShared" : "achievementInstagramFeedShared"
            metadata["achievementName"] = achievementName
        case .challenge(let challenge):
            activityType = isStory ? "challengeInstagramStoryShared" : "challengeInstagramFeedShared"
            metadata["challengeId"] = challenge.id
            metadata["challengeName"] = challenge.title
        case .profile:
            activityType = isStory ? "profileInstagramStoryShared" : "profileInstagramFeedShared"
        case .teamInvite(let teamName, let joinCode):
            activityType = isStory ? "teamInviteInstagramStoryShared" : "teamInviteInstagramFeedShared"
            metadata["teamName"] = teamName
            metadata["joinCode"] = joinCode
        case .leaderboard:
            activityType = isStory ? "leaderboardInstagramStoryShared" : "leaderboardInstagramFeedShared"
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
            print("Failed to create Instagram share activity: \(error)")
        }
    }
}

// MARK: - Template Card
struct InstagramTemplateCard: View {
    let template: InstagramTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(template.gradient)
                    .frame(width: 80, height: 120)
                    .overlay(
                        Image(systemName: template.icon)
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color.white : Color.clear,
                                lineWidth: 3
                            )
                    )

                Text(template.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Color Option
struct ColorOption: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sticker Option
struct StickerOption: View {
    let sticker: StickerType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(sticker.emoji)
                    .font(.system(size: 32))

                Text(sticker.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(width: 70, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Instagram Hashtag
struct InstagramHashtag: View {
    let hashtag: String
    @State private var isSelected = false

    var body: some View {
        Button(action: { isSelected.toggle() }) {
            Text("#\(hashtag)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? Color.white
                        : Color.white.opacity(0.2)
                )
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    InstagramShareView(
        content: ShareContent(
            type: .recipe(MockDataProvider.shared.mockRecipe())
        ),
        isStory: true
    )
}
