//
//  TikTokShareViewEnhanced.swift
//  SnapChef
//
//  Enhanced TikTok sharing with viral optimization
//

import SwiftUI
import AVKit
import Photos

struct TikTokShareViewEnhanced: View {
    let content: ShareContent
    @Environment(\.dismiss) var dismiss
    @StateObject private var videoGenerator = TikTokVideoGeneratorEnhanced()
    
    // Template selection
    @State private var selectedTemplate: TikTokTemplate = .beforeAfterReveal
    
    // Audio selection
    @State private var selectedAudio: TrendingAudio?
    @State private var showAudioPicker = false
    
    // Hashtag selection
    @State private var selectedHashtags: Set<String> = []
    @State private var customHashtag = ""
    
    // Video generation
    @State private var isGenerating = false
    @State private var generatedVideoURL: URL?
    @State private var showingVideoPreview = false
    @State private var errorMessage: String?
    @State private var generationProgress: Double = 0
    
    // Quick share options
    @State private var showQuickShareOptions = false
    @State private var selectedQuickShare: QuickShareOption = .createVideo
    
    enum QuickShareOption: String, CaseIterable {
        case createVideo = "Create Video"
        case quickPost = "Quick Post"
        
        var icon: String {
            switch self {
            case .createVideo: return "video.fill"
            case .quickPost: return "paperplane.fill"
            }
        }
        
        var description: String {
            switch self {
            case .createVideo: return "Full video creation with effects"
            case .quickPost: return "Simple card with link to app"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // TikTok-style gradient background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(hex: "#1a1a1a") ?? .black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if !showQuickShareOptions {
                    mainContentView
                } else {
                    quickShareOptionsView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if generatedVideoURL != nil {
                        Button("Share") {
                            shareToTikTok()
                        }
                        .foregroundColor(Color(hex: "#FF0050"))
                        .fontWeight(.bold)
                    }
                }
            }
        }
        .onAppear {
            showQuickShareOptions = true
            setupDefaultHashtags()
        }
        .sheet(isPresented: $showingVideoPreview) {
            if let videoURL = generatedVideoURL {
                TikTokVideoPreviewView(videoURL: videoURL) {
                    // On preview completion
                    shareToTikTok()
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
    
    // MARK: - Quick Share Options View
    
    private var quickShareOptionsView: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color(hex: "#FF0050"))
                
                Text("Share to TikTok")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Choose how you want to share")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .padding(.top, 60)
            
            // Options
            VStack(spacing: 20) {
                ForEach(QuickShareOption.allCases, id: \.self) { option in
                    Button(action: {
                        selectedQuickShare = option
                        withAnimation(.spring()) {
                            showQuickShareOptions = false
                        }
                        
                        if option == .quickPost {
                            performQuickShare()
                        }
                    }) {
                        HStack(spacing: 20) {
                            Image(systemName: option.icon)
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "#00F2EA"))
                                .frame(width: 60)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(option.rawValue)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(option.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                headerSection
                
                // Template Selection
                templateSection
                
                // Preview
                previewSection
                
                // Audio Selection
                audioSection
                
                // Hashtag Selection
                hashtagSection
                
                // Tips for Virality
                viralTipsSection
                
                // Generate Button
                generateButton
            }
            .padding(.bottom, 40)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(hex: "#FF0050"))
                
                Text("TikTok Video Generator")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Text("Create a viral cooking video")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            // Status message
            if !videoGenerator.statusMessage.isEmpty {
                Text(videoGenerator.statusMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#00F2EA"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill((Color(hex: "#00F2EA") ?? Color.cyan).opacity(0.2))
                    )
            }
        }
        .padding(.top, 20)
    }
    
    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a template")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TikTokTemplate.allCases, id: \.self) { template in
                        TemplateCardEnhanced(
                            template: template,
                            isSelected: selectedTemplate == template,
                            action: {
                                withAnimation(.spring()) {
                                    selectedTemplate = template
                                }
                                HapticFeedback.selection()
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            TemplatePreviewEnhanced(
                template: selectedTemplate,
                content: content
            )
            .frame(height: 450)
        }
        .padding(.horizontal, 20)
    }
    
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trending Sounds")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showAudioPicker.toggle() }) {
                    Text("Browse All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#00F2EA"))
                }
            }
            
            VStack(spacing: 12) {
                ForEach(TrendingAudio.suggestions.prefix(3), id: \.id) { audio in
                    TrendingAudioRowEnhanced(
                        audio: audio,
                        isSelected: selectedAudio?.id == audio.id,
                        action: {
                            selectedAudio = selectedAudio?.id == audio.id ? nil : audio
                            HapticFeedback.selection()
                        }
                    )
                }
            }
            
            // Viral tip
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
                
                Text("Using trending sounds increases views by 120%")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.1))
            )
        }
        .padding(.horizontal, 20)
    }
    
    private var hashtagSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hashtags")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            // Recommended hashtags
            FlowLayout(spacing: 8) {
                ForEach(recommendedHashtags, id: \.self) { hashtag in
                    HashtagChipEnhanced(
                        hashtag: hashtag,
                        isSelected: selectedHashtags.contains(hashtag),
                        action: {
                            if selectedHashtags.contains(hashtag) {
                                selectedHashtags.remove(hashtag)
                            } else {
                                selectedHashtags.insert(hashtag)
                            }
                            HapticFeedback.selection()
                        }
                    )
                }
            }
            
            // Custom hashtag input
            HStack {
                TextField("Add custom hashtag", text: $customHashtag)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                    )
                
                Button(action: addCustomHashtag) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#00F2EA"))
                }
                .disabled(customHashtag.isEmpty)
            }
            
            // Selected count
            Text("\(selectedHashtags.count)/30 hashtags selected")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
    }
    
    private var viralTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🚀 Viral Tips")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 10) {
                ViralTipRow(icon: "clock", text: "Post between 6-10am or 7-11pm")
                ViralTipRow(icon: "hand.thumbsup", text: "Hook viewers in first 3 seconds")
                ViralTipRow(icon: "music.note", text: "Sync transitions to beat drops")
                ViralTipRow(icon: "text.bubble", text: "Add captions for accessibility")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 20)
    }
    
    private var generateButton: some View {
        Button(action: generateVideo) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FF0050") ?? .red,
                                Color(hex: "#00F2EA") ?? .cyan
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 60)
                
                if isGenerating {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        
                        Text("Generating... \(Int(generationProgress * 100))%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: geometry.size.width * generationProgress, height: 4)
                            }
                        }
                        .frame(width: 100, height: 4)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                        
                        Text("Generate TikTok Video")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .disabled(isGenerating)
        .scaleEffect(isGenerating ? 0.98 : 1.0)
        .animation(.spring(), value: isGenerating)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Methods
    
    private var recommendedHashtags: [String] {
        var hashtags = [
            "FridgeChallenge",
            "SnapChef",
            "CookingHack",
            "RecipeOfTheDay",
            "FoodTok",
            "HomeCooking",
            "QuickRecipe",
            "FoodWaste",
            "CookingVideo",
            "ViralRecipe",
            "EasyRecipe",
            "FYP"
        ]
        
        if case .recipe(let recipe) = content.type {
            // Only add difficulty-specific hashtag if it's not already in the list
            let difficultyTag = "\(recipe.difficulty.rawValue.capitalized)Recipe"
            if !hashtags.contains(difficultyTag) {
                hashtags.append(difficultyTag)
            }
            
            if recipe.prepTime + recipe.cookTime <= 30 {
                hashtags.append("30MinuteMeals")
            }
        }
        
        return hashtags
    }
    
    private func setupDefaultHashtags() {
        // Auto-select high-performing hashtags
        selectedHashtags = Set(["FridgeChallenge", "SnapChef", "FoodTok", "FYP"])
    }
    
    private func addCustomHashtag() {
        let cleaned = customHashtag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        if !cleaned.isEmpty && selectedHashtags.count < 30 {
            selectedHashtags.insert(cleaned)
            customHashtag = ""
            HapticFeedback.success()
        }
    }
    
    private func generateVideo() {
        isGenerating = true
        generationProgress = 0
        
        Task {
            do {
                let videoURL = try await videoGenerator.generateVideo(
                    template: selectedTemplate,
                    content: content,
                    selectedAudio: selectedAudio,
                    selectedHashtags: Array(selectedHashtags),
                    progress: { progress in
                        await MainActor.run {
                            generationProgress = progress
                        }
                    }
                )
                
                await MainActor.run {
                    generatedVideoURL = videoURL
                    isGenerating = false
                    showingVideoPreview = true
                    HapticFeedback.success()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                    HapticFeedback.error()
                }
            }
        }
    }
    
    private func performQuickShare() {
        // Quick share implementation - simple card with link
        let shareText = """
        🍳 I just turned my fridge into an amazing recipe with @snapchef!
        
        \(selectedHashtags.map { "#\($0)" }.joined(separator: " "))
        
        Download SnapChef: https://snapchef.app
        """
        
        UIPasteboard.general.string = shareText
        
        // Open TikTok
        if let url = URL(string: "tiktok://") {
            UIApplication.shared.open(url) { success in
                if !success {
                    // Fallback to web
                    if let webURL = URL(string: "https://www.tiktok.com") {
                        UIApplication.shared.open(webURL)
                    }
                }
            }
        }
        
        dismiss()
    }
    
    private func shareToTikTok() {
        guard let videoURL = generatedVideoURL else { return }
        
        // Save to photo library using completion handler API (more compatible)
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            if status == .authorized || status == .limited {
                PHPhotoLibrary.shared().performChanges({
                    _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            // Copy hashtags to clipboard
                            let hashtagText = selectedHashtags.map { "#\($0)" }.joined(separator: " ")
                            UIPasteboard.general.string = """
                            \(hashtagText)
                            
                            Made with @snapchef 🍳
                            """
                            
                            // Open TikTok
                            if let url = URL(string: "tiktok://") {
                                UIApplication.shared.open(url)
                            }
                            
                            HapticFeedback.success()
                            dismiss()
                        } else {
                            errorMessage = "Failed to save video: \(error?.localizedDescription ?? "Unknown error")"
                            HapticFeedback.error()
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    errorMessage = "Photo library access denied. Please enable in Settings."
                    HapticFeedback.error()
                }
            }
        }
    }
}

// MARK: - Enhanced Components

struct TemplateCardEnhanced: View {
    let template: TikTokTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: template.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 160)
                    
                    VStack(spacing: 8) {
                        Image(systemName: template.icon)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Viral indicator
                        if template == .beforeAfterReveal {
                            Label("HOT", systemImage: "flame.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.red)
                                )
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color(hex: "#FF0050") ?? .red : Color.clear,
                            lineWidth: 3
                        )
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3), value: isSelected)
                
                Text(template.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 110)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TemplatePreviewEnhanced: View {
    let template: TikTokTemplate
    let content: ShareContent
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
            
            // Template-specific preview
            template.previewContent(content)
            
            // Play button overlay
            if !isPlaying {
                Button(action: { isPlaying.toggle() }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // TikTok UI overlay
            VStack {
                HStack {
                    Spacer()
                    
                    // Right side actions
                    VStack(spacing: 20) {
                        TikTokActionButton(icon: "heart.fill", count: "234K")
                        TikTokActionButton(icon: "message.fill", count: "1.2K")
                        TikTokActionButton(icon: "bookmark.fill", count: "45K")
                        TikTokActionButton(icon: "arrowshape.turn.up.right.fill", count: "Share")
                    }
                    .padding(.trailing, 12)
                }
                
                Spacer()
                
                // Bottom info
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("@snapchef")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(template.description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct TikTokActionButton: View {
    let icon: String
    let count: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.white)
            
            Text(count)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

struct TrendingAudioRowEnhanced: View {
    let audio: TrendingAudio
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [Color(hex: "#FF0050") ?? .red, Color(hex: "#00F2EA") ?? .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isSelected ? "music.note" : "music.note")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(audio.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(audio.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(audio.useCount)K")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("uses")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#00F2EA"))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(hex: "#FF0050") ?? .red : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HashtagChipEnhanced: View {
    let hashtag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("#")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? .black : Color(hex: "#00F2EA"))
                
                Text(hashtag)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .black : .white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? Color(hex: "#00F2EA") ?? .cyan
                            : Color.white.opacity(0.1)
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : Color.white.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct ViralTipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#00F2EA"))
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

struct TikTokVideoPreviewView: View {
    let videoURL: URL
    let onShare: () -> Void
    @State private var player: AVPlayer?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            player?.seek(to: .zero)
                            player?.play()
                        }) {
                            Label("Replay", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                        
                        Button(action: onShare) {
                            Label("Share to TikTok", systemImage: "paperplane.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#00F2EA") ?? .cyan)
                                )
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                player = AVPlayer(url: videoURL)
                player?.play()
            }
            .onDisappear {
                player?.pause()
            }
        }
    }
}

// MARK: - Haptic Feedback

@MainActor
struct HapticFeedback {
    static func selection() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}