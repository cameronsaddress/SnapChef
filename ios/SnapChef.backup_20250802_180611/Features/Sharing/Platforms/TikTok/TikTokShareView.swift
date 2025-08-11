//
//  TikTokShareView.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import AVKit
import Photos

struct TikTokShareView: View {
    let content: ShareContent
    @Environment(\.dismiss) var dismiss
    @StateObject private var videoGenerator = TikTokVideoGenerator()
    @State private var selectedTemplate: TikTokTemplate = .beforeAfterReveal
    @State private var isGenerating = false
    @State private var generatedVideoURL: URL?
    @State private var showingVideoPreview = false
    @State private var errorMessage: String?
    @State private var generationProgress: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(hex: "#000000"),
                        Color(hex: "#1a1a1a")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // TikTok branding header
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 24, weight: .bold))
                                Text("TikTok Video Generator")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            
                            Text("Create a viral cooking video")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // Template Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose a template")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(TikTokTemplate.allCases, id: \.self) { template in
                                        TemplateCard(
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
                        
                        // Preview Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Preview")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TemplatePreview(
                                template: selectedTemplate,
                                content: content
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Trending Audio Suggestions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Trending Sounds")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                ForEach(TrendingAudio.suggestions, id: \.id) { audio in
                                    TrendingAudioRow(audio: audio)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Hashtag Recommendations
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recommended Hashtags")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(recommendedHashtags, id: \.self) { hashtag in
                                    HashtagChip(hashtag: hashtag)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Generate Button
                        Button(action: generateVideo) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
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
                                        Text("Generating... \(Int(generationProgress * 100))%")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                } else {
                                    Text("Generate TikTok Video")
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
                    if generatedVideoURL != nil {
                        Button("Share") {
                            shareToTikTok()
                        }
                        .foregroundColor(Color(hex: "#FF0050"))
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingVideoPreview) {
            if let videoURL = generatedVideoURL {
                VideoPreviewView(videoURL: videoURL)
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
    
    private var recommendedHashtags: [String] {
        var hashtags = ["FridgeChallenge", "SnapChef", "CookingHack", "RecipeOfTheDay"]
        
        switch content.type {
        case .recipe(let recipe):
            hashtags.append(contentsOf: [
                "HomeCooking",
                "\(recipe.difficulty.rawValue.capitalized)Recipe",
                "FoodTok",
                "CookingVideo",
                "QuickRecipe"
            ])
        case .challenge:
            hashtags.append(contentsOf: [
                "CookingChallenge",
                "ChefChallenge",
                "FoodChallenge"
            ])
        default:
            hashtags.append("FoodLover")
        }
        
        return hashtags
    }
    
    private func generateVideo() {
        isGenerating = true
        generationProgress = 0
        
        Task {
            do {
                // Generate video based on template
                let videoURL = try await videoGenerator.generateVideo(
                    template: selectedTemplate,
                    content: content,
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
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
    
    private func shareToTikTok() {
        guard let videoURL = generatedVideoURL else { return }
        
        // Save video to photo library first
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            // Open TikTok
                            if let url = URL(string: "tiktok://") {
                                UIApplication.shared.open(url)
                            }
                        } else {
                            errorMessage = "Failed to save video: \(error?.localizedDescription ?? "Unknown error")"
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    errorMessage = "Photo library access denied"
                }
            }
        }
    }
}

// MARK: - Template Card
struct TemplateCard: View {
    let template: TikTokTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Template preview thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: template.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 150)
                    .overlay(
                        Image(systemName: template.icon)
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color(hex: "#FF0050") : Color.clear,
                                lineWidth: 3
                            )
                    )
                
                Text(template.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Template Preview
struct TemplatePreview: View {
    let template: TikTokTemplate
    let content: ShareContent
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
                .frame(height: 400)
            
            VStack {
                Text(template.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                
                // Mock preview based on template
                template.previewContent(content)
            }
        }
    }
}

// MARK: - Trending Audio Row
struct TrendingAudioRow: View {
    let audio: TrendingAudio
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#FF0050"))
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(audio.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(audio.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("\(audio.useCount)K")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Hashtag Chip
struct HashtagChip: View {
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
                        ? Color(hex: "#00F2EA")
                        : Color.white.opacity(0.1)
                )
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for row in result.rows {
            for item in row.items {
                let x = bounds.minX + item.x
                let y = bounds.minY + row.y
                item.view.place(at: CGPoint(x: x, y: y), proposal: .init(item.size))
            }
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var rows: [Row] = []
        
        struct Row {
            var items: [Item] = []
            var y: CGFloat = 0
            var height: CGFloat = 0
        }
        
        struct Item {
            var view: LayoutSubview
            var size: CGSize
            var x: CGFloat
        }
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentRow = Row()
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxX: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && !currentRow.items.isEmpty {
                    currentRow.y = y
                    rows.append(currentRow)
                    y += currentRow.height + spacing
                    currentRow = Row()
                    x = 0
                }
                
                currentRow.items.append(Item(view: subview, size: size, x: x))
                currentRow.height = max(currentRow.height, size.height)
                x += size.width + spacing
                maxX = max(maxX, x - spacing)
            }
            
            if !currentRow.items.isEmpty {
                currentRow.y = y
                rows.append(currentRow)
                y += currentRow.height
            }
            
            size = CGSize(width: maxX, height: y)
        }
    }
}

// MARK: - Video Preview
struct VideoPreviewView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
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

// MARK: - Preview
#Preview {
    TikTokShareView(
        content: ShareContent(
            type: .recipe(MockDataProvider.shared.mockRecipe())
        )
    )
}