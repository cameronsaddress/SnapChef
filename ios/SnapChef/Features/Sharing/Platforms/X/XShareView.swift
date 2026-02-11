//
//  XShareView.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import UIKit

struct XShareView: View {
    let content: ShareContent
    @Environment(\.dismiss) var dismiss
    @State private var tweetText = ""
    @State private var isGenerating = false
    @State private var generatedImage: UIImage?
    @State private var errorMessage: String?
    @State private var tweetCopied = false
    @State private var includeHashtags = true
    
    private let maxCharacters = 280
    private let imageCharacters = 24 // Characters used by image URL
    
    var body: some View {
        NavigationStack {
            ZStack {
                // X (Twitter) black background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with X branding
                    VStack(spacing: 16) {
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Image(systemName: "x.square.fill")
                                    .font(.system(size: 20))
                                Text("Post to X")
                                    .font(.system(size: 20, weight: .bold))
                            }
                            .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Invisible spacer for balance
                            Color.clear
                                .frame(width: 30, height: 30)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(Color.black)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Large Preview
                            VStack(spacing: 12) {
                                Text("Preview")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // X Tweet Preview
                                XTweetPreview(
                                    text: tweetText.isEmpty ? generateTweetText() : tweetText,
                                    image: generatedImage,
                                    includeHashtags: includeHashtags
                                )
                                .frame(height: UIScreen.main.bounds.height * 0.4)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(hex: "#16181C")) // X dark gray
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                            }
                            .padding(.horizontal, 20)
                            
                            // Tweet Composer Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Compose Tweet")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    // Character counter
                                    CharacterCounter(
                                        current: tweetText.count + (includeHashtags ? 40 : 0),
                                        max: maxCharacters,
                                        includeImage: true
                                    )
                                }
                                
                                TextEditor(text: $tweetText)
                                    .frame(height: 120)
                                    .padding(12)
                                    .background(Color(hex: "#16181C"))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .onAppear {
                                        if tweetText.isEmpty {
                                            tweetText = generateTweetText()
                                        }
                                    }
                                
                                // Hashtag toggle
                                Toggle("Include hashtags", isOn: $includeHashtags)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .tint(Color(hex: "#1D9BF0")) // Twitter Blue
                                
                                // Hashtag preview
                                if includeHashtags {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(getHashtags(), id: \.self) { hashtag in
                                                Text("#\(hashtag)")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(Color(hex: "#1D9BF0"))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color(hex: "#1D9BF0").opacity(0.1))
                                                    )
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Share Button
                            VStack(spacing: 8) {
                                Button(action: generateAndShare) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(hex: "#1D9BF0"), // Twitter Blue
                                                        Color(hex: "#1A8CD8")
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
                                                Text("Post to X")
                                            }
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        }
                                    }
                                }
                                .disabled(isGenerating || tweetText.count + (includeHashtags ? 40 : 0) > maxCharacters)
                                
                                if tweetCopied {
                                    Text("Tweet copied to clipboard!")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
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
    }
    
    // MARK: - Helper Methods
    
    private func generateTweetText() -> String {
        switch content.type {
        case .recipe(let recipe):
            let emoji = getRecipeEmoji(for: recipe)
            return "Just turned my fridge into \(recipe.name) \(emoji)\n\nMade with SnapChef - download on the App Store!"
            
        case .achievement(let achievementName):
            return "🏆 \(achievementName) unlocked!\n\nLevel up your cooking game with SnapChef - download on the App Store"
            
        case .challenge(let challenge):
            let challengeLink = SocialShareManager.shared.generateChallengeInviteLink(challengeID: challenge.id).absoluteString
            return "Challenge crushed: \(challenge.title) ✅\n\nWho's next?\n\(challengeLink)"
            
        default:
            return "Made with SnapChef - turn your fridge into feast! 🍳\nDownload on the App Store"
        }
    }
    
    private func getHashtags() -> [String] {
        switch content.type {
        case .recipe(let recipe):
            let mainTag = recipe.tags.first ?? "Cooking"
            return ["SnapChef", "FridgeToFeast", mainTag.replacingOccurrences(of: " ", with: "")]
        case .achievement:
            return ["SnapChef", "CookingWin", "Achievement"]
        case .challenge:
            return ["SnapChefChallenge", "CookingChallenge"]
        default:
            return ["SnapChef", "CookingApp"]
        }
    }
    
    private func getRecipeEmoji(for recipe: Recipe) -> String {
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
    
    private func generateAndShare() {
        isGenerating = true
        
        Task {
            do {
                // Generate image using Instagram's content generator
                // X/Twitter prefers modern, clean visuals
                let image = try await InstagramContentGenerator.shared.generateContent(
                    template: .modern,
                    content: content,
                    isStory: false,
                    backgroundColor: Color.black,
                    sticker: nil
                )
                
                await MainActor.run {
                    self.generatedImage = image
                    self.isGenerating = false
                    self.shareToX()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func shareToX() {
        guard let image = generatedImage else { return }
        
        // Prepare tweet text with hashtags
        var fullTweet = tweetText
        if includeHashtags {
            let hashtags = getHashtags().map { "#\($0)" }.joined(separator: " ")
            fullTweet += "\n\n\(hashtags)"
        }
        
        // Copy tweet to clipboard
        UIPasteboard.general.string = fullTweet
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tweetCopied = true
        }
        
        // Hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                tweetCopied = false
            }
        }
        
        // Save image to photo library
        SafePhotoSaver.shared.saveImageToPhotoLibrary(image) { success, error in
            if success {
                // Open X app with pre-filled text
                let encodedText = fullTweet.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                
                // Try X app first
                if let xURL = URL(string: "twitter://post?message=\(encodedText)") {
                    UIApplication.shared.open(xURL) { success in
                        if !success {
                            // Fallback to web
                            if let webURL = URL(string: "https://twitter.com/intent/tweet?text=\(encodedText)") {
                                UIApplication.shared.open(webURL)
                            }
                        }
                    }
                }
                
                // Create activity for successful X share
                Task {
                    await createXShareActivity()
                }
                
                self.dismiss()
            } else {
                self.errorMessage = error ?? "Failed to save image"
            }
        }
    }
    
    // MARK: - Activity Creation
    private func createXShareActivity() async {
        guard UnifiedAuthManager.shared.isAuthenticated,
              let userID = UnifiedAuthManager.shared.currentUser?.recordID else {
            return
        }
        
        var activityType = "xPostShared"
        var metadata: [String: Any] = ["platform": "x"]
        
        // Add content-specific metadata
        switch content.type {
        case .recipe(let recipe):
            activityType = "recipeXPostShared"
            metadata["recipeId"] = recipe.id.uuidString
            metadata["recipeName"] = recipe.name
        case .achievement(let achievementName):
            activityType = "achievementXPostShared"
            metadata["achievementName"] = achievementName
        case .challenge(let challenge):
            activityType = "challengeXPostShared"
            metadata["challengeId"] = challenge.id
            metadata["challengeName"] = challenge.title
        default:
            break
        }
        
        do {
            try await CloudKitService.shared.createActivity(
                type: activityType,
                actorID: userID,
                recipeID: metadata["recipeId"] as? String,
                recipeName: metadata["recipeName"] as? String,
                challengeID: metadata["challengeId"] as? String,
                challengeName: metadata["challengeName"] as? String
            )
        } catch {
            print("Failed to create X share activity: \(error)")
        }
    }
}

// MARK: - Character Counter
struct CharacterCounter: View {
    let current: Int
    let max: Int
    let includeImage: Bool
    
    private var remaining: Int {
        let total = current + (includeImage ? 24 : 0)
        return max - total
    }
    
    private var color: Color {
        if remaining < 0 {
            return .red
        } else if remaining < 20 {
            return .orange
        } else {
            return Color(hex: "#1D9BF0")
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if includeImage {
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
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

// MARK: - Tweet Preview
struct XTweetPreview: View {
    let text: String
    let image: UIImage?
    let includeHashtags: Bool
    
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
                            .foregroundColor(Color(hex: "#1D9BF0"))
                    }
                    
                    Text("SnapChef App · now")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "ellipsis")
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Tweet text
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .lineSpacing(4)
            
            // Hashtags
            if includeHashtags {
                Text("#SnapChef #FridgeToFeast #CookingApp")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#1D9BF0"))
            }
            
            // Image preview
            if image != nil {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 180)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
            
            Spacer()
            
            // Engagement bar
            HStack(spacing: 40) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                    Text("12")
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath")
                    Text("3")
                }
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                    Text("42")
                }
                Image(systemName: "square.and.arrow.up")
            }
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
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
