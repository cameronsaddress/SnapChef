//
//  InstagramShareView.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import UIKit
import Photos

struct InstagramShareView: View {
    let content: ShareContent
    let isStory: Bool
    @Environment(\.dismiss) var dismiss
    @State private var selectedTemplate: InstagramTemplate = .classic
    @State private var backgroundColor: Color = Color(hex: "#E4405F")
    @State private var isGenerating = false
    @State private var generatedImage: UIImage?
    @State private var showingShareOptions = false
    @State private var selectedSticker: StickerType?
    @State private var captionText = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Instagram gradient background
                LinearGradient(
                    colors: [
                        Color(hex: "#833AB4"),
                        Color(hex: "#C13584"),
                        Color(hex: "#E1306C"),
                        Color(hex: "#FD1D1D"),
                        Color(hex: "#F77737")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24, weight: .bold))
                                Text(isStory ? "Instagram Story" : "Instagram Post")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            
                            Text(isStory ? "Create an engaging story" : "Design your perfect post")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 20)
                        
                        // Template Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose a template")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(InstagramTemplate.allCases, id: \.self) { template in
                                        InstagramTemplateCard(
                                            template: template,
                                            isSelected: selectedTemplate == template,
                                            action: {
                                                selectedTemplate = template
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Preview
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Preview")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            InstagramPreview(
                                content: content,
                                template: selectedTemplate,
                                isStory: isStory,
                                backgroundColor: backgroundColor
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        if isStory {
                            // Story Stickers
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Add Stickers")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(StickerType.allCases, id: \.self) { sticker in
                                            StickerOption(
                                                sticker: sticker,
                                                isSelected: selectedSticker == sticker,
                                                action: {
                                                    selectedSticker = sticker
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        } else {
                            // Post Caption
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Caption")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                TextEditor(text: $captionText)
                                    .frame(height: 100)
                                    .padding(12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .onAppear {
                                        if captionText.isEmpty {
                                            captionText = generateCaption()
                                        }
                                    }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Background Color Picker
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Background Color")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(InstagramColors.all, id: \.self) { color in
                                        ColorOption(
                                            color: color,
                                            isSelected: backgroundColor == color,
                                            action: {
                                                backgroundColor = color
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Hashtags
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Suggested Hashtags")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(suggestedHashtags, id: \.self) { hashtag in
                                    InstagramHashtag(hashtag: hashtag)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Generate and Share Button
                        Button(action: generateAndShare) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#833AB4"),
                                                Color(hex: "#E1306C")
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
                                        Text(isStory ? "Share to Story" : "Share to Instagram")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isGenerating)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        generateAndShare()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
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
    }
    
    private var suggestedHashtags: [String] {
        var hashtags = ["SnapChef", "HomeCooking", "FoodStagram", "RecipeOfTheDay"]
        
        if case .recipe(let recipe) = content.type {
            hashtags.append(contentsOf: [
                "InstaFood",
                "\(recipe.difficulty.rawValue.capitalized)Recipe",
                "CookingReels",
                "FoodLover",
                "RecipeShare"
            ])
        }
        
        if isStory {
            hashtags.append("Stories")
        } else {
            hashtags.append("FoodPost")
        }
        
        return hashtags
    }
    
    private func generateCaption() -> String {
        switch content.type {
        case .recipe(let recipe):
            return """
            🍳 \(recipe.name)
            
            ⏱ Ready in \(recipe.prepTime + recipe.cookTime) minutes
            🔥 Difficulty: \(recipe.difficulty.rawValue.capitalized)
            
            Made with @SnapChef - Turn your fridge into amazing recipes with AI!
            
            #SnapChef #HomeCooking #RecipeOfTheDay
            """
        default:
            return "Made with @SnapChef 🍳✨"
        }
    }
    
    private func generateContent() {
        isGenerating = true
        
        Task {
            do {
                // Generate image based on template
                let image = try await InstagramContentGenerator.shared.generateContent(
                    template: selectedTemplate,
                    content: content,
                    isStory: isStory,
                    backgroundColor: backgroundColor,
                    sticker: selectedSticker
                )
                
                await MainActor.run {
                    generatedImage = image
                    isGenerating = false
                    showingShareOptions = true
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
        // If image is already generated, share directly
        if let image = generatedImage {
            shareToInstagram()
        } else {
            // Generate image first, then share
            isGenerating = true
            
            Task {
                do {
                    // Generate image based on template
                    let image = try await InstagramContentGenerator.shared.generateContent(
                        template: selectedTemplate,
                        content: content,
                        isStory: isStory,
                        backgroundColor: backgroundColor,
                        sticker: selectedSticker
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
        
        if isStory {
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
        // Enhanced caption with call-to-action
        var fullCaption = captionText
        fullCaption += "\n\n📱 Try SnapChef: snapchef.app"
        fullCaption += "\n#MadeWithSnapChef"
        
        // Copy caption to clipboard
        UIPasteboard.general.string = fullCaption
        
        // Save image to photo library with proper permission handling
        saveImageAndOpenInstagram(image: image)
    }
    
    private func saveImageAndOpenInstagram(image: UIImage) {
        // First normalize the image to ensure it's in the right format
        let normalizedImage = normalizeImage(image)
        
        // Request authorization directly - don't check status first as it might crash
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    // Have permission, save the image
                    self.performImageSave(normalizedImage)
                    
                case .denied:
                    self.errorMessage = "Photo library access denied. Please go to Settings > Privacy & Security > Photos and allow SnapChef to add photos."
                    
                case .restricted:
                    self.errorMessage = "Photo library access is restricted on this device."
                    
                case .notDetermined:
                    // This shouldn't happen after requestAuthorization, but handle it
                    self.errorMessage = "Unable to determine photo library permission status."
                    
                @unknown default:
                    self.errorMessage = "Unable to access photo library."
                }
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
    
    private func performImageSave(_ image: UIImage) {
        // Image is already normalized before being passed here
        PHPhotoLibrary.shared().performChanges({
            _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
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
                    self.dismiss()
                } else {
                    self.errorMessage = "Failed to save image: \(error?.localizedDescription ?? "Unknown error")"
                }
            }
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