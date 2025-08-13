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
    @StateObject private var viralEngine = ViralVideoSDK()  // Use the new viral video engine
    @State private var selectedTemplate: ViralTemplate = .kineticTextSteps  // Default to kinetic text template
    @State private var isGenerating = false
    @State private var generatedVideoURL: URL?
    @State private var showingVideoPreview = false
    @State private var errorMessage: String?
    
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
                        
                        // Single Template - Kinetic Text Only
                        // Template tiles removed - focusing on kinetic text template only
                        
                        // Preview Section - Kinetic Text Template
                        VStack(spacing: 16) {
                            // No title, just the preview
                            TemplatePreview(
                                template: .kineticTextSteps,  // Always use kinetic text
                                content: content
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Trending sounds section removed
                        
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
                                        Text("\(viralEngine.currentProgress.phase.rawValue)")
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
        
        Task {
            do {
                // Convert content to required format
                let (viralRecipe, mediaBundle) = try await convertContentToViralFormat(content)
                
                // Use the ViralVideoSDK to generate video with proper template
                let videoURL = try await viralEngine.generateVideoOnly(
                    template: selectedTemplate,
                    recipe: viralRecipe,
                    media: mediaBundle
                )
                
                await MainActor.run {
                    generatedVideoURL = videoURL
                    isGenerating = false
                }
                
                // Automatically save and open TikTok
                await saveAndShareToTikTok(videoURL: videoURL)
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
    
    private func convertContentToViralFormat(_ content: ShareContent) async throws -> (ViralRecipe, MediaBundle) {
        // Convert Recipe to viral format
        var viralRecipe: ViralRecipe
        
        switch content.type {
        case .recipe(let recipe):
            // Convert recipe steps to viral format
            let steps = recipe.instructions.enumerated().map { index, instruction in
                ViralRecipe.Step(
                    title: instruction,
                    secondsHint: Double(30 + index * 15) // Estimate time per step
                )
            }
            
            viralRecipe = ViralRecipe(
                title: recipe.name,
                hook: "Turn your fridge chaos into \(recipe.name) in \(recipe.prepTime + recipe.cookTime) minutes!",
                steps: Array(steps.prefix(7)), // Limit to 7 steps max
                timeMinutes: recipe.prepTime + recipe.cookTime,
                costDollars: 10, // Estimate
                calories: recipe.nutrition.calories,
                ingredients: recipe.ingredients.map { $0.name }
            )
            
        default:
            // Fallback for non-recipe content
            viralRecipe = ViralRecipe(
                title: "SnapChef Creation",
                hook: "Check out what I made with SnapChef!",
                steps: [
                    ViralRecipe.Step(title: "Open fridge", secondsHint: 5),
                    ViralRecipe.Step(title: "Take photo", secondsHint: 5),
                    ViralRecipe.Step(title: "Get recipe", secondsHint: 5),
                    ViralRecipe.Step(title: "Cook", secondsHint: 30),
                    ViralRecipe.Step(title: "Enjoy!", secondsHint: 5)
                ],
                timeMinutes: 15,
                costDollars: 10,
                calories: 400,
                ingredients: ["Your fridge ingredients"]
            )
        }
        
        // Create media bundle with proper photos
        print("📸 TikTokShareView: Creating MediaBundle:")
        print("    - content.beforeImage (fridge): \(content.beforeImage != nil ? "✅ Available (\(content.beforeImage!.size))" : "❌ Missing")")
        print("    - content.afterImage (meal): \(content.afterImage != nil ? "✅ Available (\(content.afterImage!.size))" : "❌ Missing")")
        
        // Validate and prepare photos for video generation
        let (validFridge, validMeal) = PhotoValidator.preparePhotosForVideo(
            fridgePhoto: content.beforeImage,
            mealPhoto: content.afterImage
        )
        
        // WARNING: If photos are nil or invalid, we're creating placeholders which show as black with text
        let fridgePhoto: UIImage
        let mealPhoto: UIImage
        
        if let validFridgePhoto = validFridge {
            fridgePhoto = validFridgePhoto
            print("📸 Using validated fridge photo: \(validFridgePhoto.size)")
        } else {
            print("⚠️ WARNING: No valid fridge photo available, creating placeholder")
            fridgePhoto = createPlaceholderImage(text: "BEFORE")
        }
        
        if let validMealPhoto = validMeal {
            mealPhoto = validMealPhoto
            print("📸 Using validated meal photo: \(validMealPhoto.size)")
        } else {
            print("⚠️ WARNING: No valid meal photo available, creating placeholder")
            mealPhoto = createPlaceholderImage(text: "AFTER")
        }
        
        // Create MediaBundle - using meal photo for both afterFridge and cookedMeal
        // TODO: Refactor MediaBundle to remove afterFridge
        let mediaBundle = MediaBundle(
            beforeFridge: fridgePhoto,
            afterFridge: mealPhoto,  // Using meal photo since afterFridge isn't a real concept
            cookedMeal: mealPhoto
        )
        
        print("📸 TikTokShareView: MediaBundle created:")
        print("    - beforeFridge: \(fridgePhoto.size)")
        print("    - cookedMeal: \(mealPhoto.size)")
        
        return (viralRecipe, mediaBundle)
    }
    
    private func createPlaceholderImage(text: String) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Black background
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Draw text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 120, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func saveAndShareToTikTok(videoURL: URL) async {
        // Generate caption with hashtags
        let caption = generateCaption()
        
        // Copy caption to clipboard
        await MainActor.run {
            UIPasteboard.general.string = caption
        }
        
        // Use TikTokShareService to save and open TikTok
        await MainActor.run {
            TikTokShareService.shareRecipeToTikTok(
                videoURL: videoURL,
                customCaption: caption
            ) { result in
                switch result {
                case .success():
                    // Successfully saved and opened TikTok
                    DispatchQueue.main.async {
                        // Dismiss the view after successful share
                        self.dismiss()
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to share: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func generateCaption() -> String {
        var caption = ""
        
        // Add content-specific text
        switch content.type {
        case .recipe(let recipe):
            caption = "🔥 MY FRIDGE CHALLENGE 🔥\n"
            caption += "Just made \(recipe.name) in \(recipe.prepTime + recipe.cookTime) minutes!\n\n"
        case .challenge(let challenge):
            caption = "🏆 CHALLENGE COMPLETED 🏆\n"
            caption += "\(challenge.title)\n\n"
        default:
            caption = "Check out what I made with SnapChef! 🍳\n\n"
        }
        
        // Add hashtags
        let hashtags = recommendedHashtags.map { "#\($0)" }.joined(separator: " ")
        caption += hashtags
        caption += "\n\n📱 Made with @SnapChef"
        
        return caption
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

// MARK: - Viral Template Card
struct ViralTemplateCard: View {
    let template: ViralTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Template preview thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: gradientColors(for: template),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 150)
                    .overlay(
                        Image(systemName: icon(for: template))
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
                
                Text(name(for: template))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func gradientColors(for template: ViralTemplate) -> [Color] {
        switch template {
        // Only supporting kinetic text
        case .kineticTextSteps:
            return [Color(hex: "#667eea"), Color(hex: "#764ba2")]
        // Commented out other templates
        // case .beatSyncedCarousel:
        //     return [Color(hex: "#FF0050"), Color(hex: "#00F2EA")]
        // case .splitScreenSwipe:
        //     return [Color(hex: "#F77737"), Color(hex: "#F9A825")]
        // case .priceTimeChallenge:
        //     return [Color(hex: "#43e97b"), Color(hex: "#38f9d7")]
        // case .greenScreenPIP:
        //     return [Color(hex: "#fa709a"), Color(hex: "#fee140")]
        // case .test:
        //     return [Color.orange, Color.yellow]  // Bright orange-yellow for visibility
        }
    }
    
    private func icon(for template: ViralTemplate) -> String {
        switch template {
        case .kineticTextSteps: return "text.bubble"
        // Commented out other templates
        // case .beatSyncedCarousel: return "music.note"
        // case .splitScreenSwipe: return "arrow.left.arrow.right"
        // case .priceTimeChallenge: return "dollarsign.circle"
        // case .greenScreenPIP: return "camera.on.rectangle"
        // case .test: return "photo.on.rectangle"
        }
    }
    
    private func name(for template: ViralTemplate) -> String {
        switch template {
        case .kineticTextSteps: return "Kinetic Text"
        // Commented out other templates
        // case .beatSyncedCarousel: return "Beat Sync"
        // case .splitScreenSwipe: return "Split Screen"
        // case .priceTimeChallenge: return "Price Challenge"
        // case .greenScreenPIP: return "Green Screen"
        // case .test: return "Test (Photos Only)"
        }
    }
}

// MARK: - Template Card (Old - Keep for compatibility)
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
    let template: ViralTemplate
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
                previewContent(for: template, content: content)
            }
        }
    }
    
    @ViewBuilder
    private func previewContent(for template: ViralTemplate, content: ShareContent) -> some View {
        switch template {
        // Only supporting kinetic text template
        // case .beatSyncedCarousel:
        //     BeforeAfterPreview(content: content)
        // case .splitScreenSwipe:
        //     SplitScreenPreview(content: content)
        case .kineticTextSteps:
            QuickRecipePreview(content: content)
        // case .priceTimeChallenge:
        //     TimelapsePreview(content: content)
        // case .greenScreenPIP:
        //     Ingredients360Preview(content: content)
        // case .test:
        //     TestTemplatePreview(content: content)
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