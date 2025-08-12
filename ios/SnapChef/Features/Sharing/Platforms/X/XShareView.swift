//
//  XShareView.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import UIKit
import Photos

struct XShareView: View {
    let content: ShareContent
    @Environment(\.dismiss) var dismiss
    @State private var tweetText = ""
    @State private var selectedStyle: XTweetStyle = .classic
    @State private var includeImage = true
    @State private var includeStats = true
    @State private var includeHashtags = true
    @State private var selectedHashtags: Set<String> = []
    @State private var isGenerating = false
    @State private var generatedImage: UIImage?
    @State private var characterCount: Int = 0
    @State private var showingShareConfirmation = false
    
    private let maxCharacters = 280
    private let imageCharacters = 24 // Characters used by image URL
    
    var body: some View {
        NavigationStack {
            ZStack {
                // X (Twitter) dark theme background
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "x.square.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Post to X")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Craft the perfect post")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // Tweet Composer
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Compose your post")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            // Tweet text editor
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                
                                TextEditor(text: $tweetText)
                                    .frame(minHeight: 120)
                                    .padding(12)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .onChange(of: tweetText) { _ in
                                        updateCharacterCount()
                                    }
                                    .onAppear {
                                        if tweetText.isEmpty {
                                            tweetText = generateTweetText()
                                            updateCharacterCount()
                                        }
                                    }
                                
                                if tweetText.isEmpty {
                                    Text("What's happening?")
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                            
                            // Character count
                            HStack {
                                Spacer()
                                CharacterCountView(
                                    current: characterCount,
                                    max: maxCharacters,
                                    includeImage: includeImage
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Style Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Post style")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(XTweetStyle.allCases, id: \.self) { style in
                                        XStyleCard(
                                            style: style,
                                            isSelected: selectedStyle == style,
                                            action: {
                                                selectedStyle = style
                                                tweetText = generateTweetText()
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Options
                        VStack(spacing: 12) {
                            ToggleOption(
                                title: "Include image",
                                subtitle: "Add a visual preview",
                                isOn: $includeImage,
                                icon: "photo"
                            )
                            
                            ToggleOption(
                                title: "Include stats",
                                subtitle: "Show recipe details",
                                isOn: $includeStats,
                                icon: "chart.bar"
                            )
                            
                            ToggleOption(
                                title: "Include hashtags",
                                subtitle: "Increase visibility",
                                isOn: $includeHashtags,
                                icon: "number"
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Hashtags
                        if includeHashtags {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Hashtags")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(suggestedHashtags, id: \.self) { hashtag in
                                        XHashtag(
                                            hashtag: hashtag,
                                            isSelected: selectedHashtags.contains(hashtag),
                                            action: {
                                                if selectedHashtags.contains(hashtag) {
                                                    selectedHashtags.remove(hashtag)
                                                } else {
                                                    selectedHashtags.insert(hashtag)
                                                }
                                                tweetText = generateTweetText()
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Preview
                        if includeImage {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Preview")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                XTweetPreview(
                                    text: tweetText,
                                    image: generatedImage,
                                    style: selectedStyle
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Post Button
                        Button(action: postToX) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(hex: "#1DA1F2"))
                                    .frame(height: 48)
                                
                                if isGenerating {
                                    HStack(spacing: 12) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Text("Preparing...")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                } else {
                                    Text("Post")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isGenerating || characterCount > maxCharacters)
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
                    if characterCount <= maxCharacters {
                        Button("Post") {
                            postToX()
                        }
                        .foregroundColor(Color(hex: "#1DA1F2"))
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .alert("Posted!", isPresented: $showingShareConfirmation) {
            Button("View on X") {
                openX()
            }
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("Your post has been copied to clipboard. Open X to paste and share!")
        }
    }
    
    private var suggestedHashtags: [String] {
        var hashtags = ["SnapChef", "HomeCooking", "RecipeOfTheDay", "FoodTwitter", "CookingTime"]
        
        if case .recipe(let recipe) = content.type {
            hashtags.append(contentsOf: [
                "FoodBlogger",
                "\(recipe.difficulty.rawValue.capitalized)Recipe",
                "Foodie",
                "RecipeShare"
            ])
            
            // Add difficulty-specific hashtags
            if recipe.difficulty == .easy {
                hashtags.append("EasyRecipe")
            } else if recipe.difficulty == .hard {
                hashtags.append("ChallengingRecipe")
            }
        }
        
        return hashtags
    }
    
    private func generateTweetText() -> String {
        guard case .recipe(let recipe) = content.type else {
            return "Check out what I made with @SnapChef! 🍳"
        }
        
        var text = ""
        
        switch selectedStyle {
        case .classic:
            text = "Just made \(recipe.name) with @SnapChef! 🍳"
            
        case .thread:
            text = "🧵 How to make \(recipe.name) (a thread)\n\n1/"
            
        case .viral:
            text = "POV: You used AI to turn your sad fridge into \(recipe.name) ✨"
            
        case .professional:
            text = "New recipe: \(recipe.name)\n\nA \(recipe.difficulty.rawValue) dish that takes just \(recipe.prepTime + recipe.cookTime) minutes."
            
        case .funny:
            let funnyIntros = [
                "My fridge: 😭\n@SnapChef: Hold my spatula",
                "Nobody:\nAbsolutely nobody:\nMe at 2am:",
                "Therapist: So what brings you joy?\nMe:",
                "Breaking: Local person actually cooks instead of ordering takeout"
            ]
            text = "\(funnyIntros.randomElement()!) \n\n\(recipe.name) achieved 🎉"
        }
        
        // Add stats if enabled
        if includeStats {
            text += "\n\n⏱ \(recipe.prepTime + recipe.cookTime) min"
            text += "\n🔥 \(recipe.nutrition.calories) cal"
            text += "\n👥 Serves \(recipe.servings)"
        }
        
        // Add hashtags if enabled
        if includeHashtags && !selectedHashtags.isEmpty {
            let hashtagsText = selectedHashtags.map { "#\($0)" }.joined(separator: " ")
            text += "\n\n\(hashtagsText)"
        }
        
        return text
    }
    
    private func updateCharacterCount() {
        var count = tweetText.count
        if includeImage {
            count += imageCharacters
        }
        characterCount = count
    }
    
    private func postToX() {
        isGenerating = true
        
        Task {
            // Generate image if needed
            if includeImage {
                do {
                    let image = try await XContentGenerator.shared.generateImage(
                        for: content,
                        style: selectedStyle
                    )
                    
                    await MainActor.run {
                        generatedImage = image
                        
                        // Save image to photos with proper permission handling
                        saveImageToPhotoLibrary(image)
                    }
                } catch {
                    print("Failed to generate image: \(error)")
                }
            }
            
            await MainActor.run {
                // Copy text to clipboard
                UIPasteboard.general.string = tweetText
                
                isGenerating = false
                showingShareConfirmation = true
            }
        }
    }
    
    private func openX() {
        // Try to open X app, fallback to web
        if let url = URL(string: "twitter://post?message=\(tweetText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url) { success in
                if !success {
                    // Fallback to web
                    if let webUrl = URL(string: "https://twitter.com/intent/tweet?text=\(tweetText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                        UIApplication.shared.open(webUrl)
                    }
                }
            }
        }
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) {
        // Check current authorization status first
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            // Already have permission, save the image
            PHPhotoLibrary.shared().performChanges({
                _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if !success {
                    print("Failed to save image to X share: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
            
        case .notDetermined:
            // Need to request permission
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    PHPhotoLibrary.shared().performChanges({
                        _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }) { success, error in
                        if !success {
                            print("Failed to save image to X share: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                }
            }
            
        case .denied, .restricted:
            print("Photo library access denied for X share")
            
        @unknown default:
            print("Unknown photo library authorization status")
        }
    }
}

// MARK: - Supporting Types
enum XTweetStyle: String, CaseIterable {
    case classic = "Classic"
    case thread = "Thread"
    case viral = "Viral"
    case professional = "Professional"
    case funny = "Funny"
    
    var icon: String {
        switch self {
        case .classic: return "text.bubble"
        case .thread: return "text.append"
        case .viral: return "flame"
        case .professional: return "briefcase"
        case .funny: return "face.smiling"
        }
    }
}

// MARK: - Components
struct XStyleCard: View {
    let style: XTweetStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: style.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .black : .white)
                
                Text(style.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .black : .white)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "#1DA1F2") : Color.white.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ToggleOption: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#1DA1F2"))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#1DA1F2")))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct XHashtag: View {
    let hashtag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("#\(hashtag)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .black : Color(hex: "#1DA1F2"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? Color(hex: "#1DA1F2")
                        : Color(hex: "#1DA1F2").opacity(0.1)
                )
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CharacterCountView: View {
    let current: Int
    let max: Int
    let includeImage: Bool
    
    private var remaining: Int {
        max - current
    }
    
    private var color: Color {
        if remaining < 0 {
            return .red
        } else if remaining < 20 {
            return .orange
        } else {
            return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if includeImage {
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Text("\(remaining)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
            
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                
                Circle()
                    .trim(from: 0, to: min(CGFloat(current) / CGFloat(max), 1.0))
                    .stroke(color, lineWidth: 2)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 20, height: 20)
        }
    }
}

struct XTweetPreview: View {
    let text: String
    let image: UIImage?
    let style: XTweetStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Mock tweet header
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text("SC")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("SnapChef")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#1DA1F2"))
                    }
                    
                    Text("@snapchef · now")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
            }
            
            // Tweet text
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .lineSpacing(4)
            
            // Image preview placeholder
            if image != nil {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
            
            // Engagement bar
            HStack(spacing: 40) {
                Image(systemName: "bubble.left")
                Image(systemName: "arrow.2.squarepath")
                Image(systemName: "heart")
                Image(systemName: "chart.bar")
                Image(systemName: "square.and.arrow.up")
            }
            .font(.system(size: 18))
            .foregroundColor(.gray)
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.black)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    XShareView(
        content: ShareContent(
            type: .recipe(MockDataProvider.shared.mockRecipe())
        )
    )
}