// REPLACE ENTIRE FILE: TikTokShareView.swift

import SwiftUI
import AVKit
import Photos
import UIKit

struct TikTokShareView: View {
    let content: ShareContent
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = ViralVideoEngine()
    private let template: ViralTemplate = .kineticTextSteps
    @State private var isGenerating = false
    @State private var videoURL: URL?
    @State private var error: String?
    @State private var showSuccess = false
    @State private var showConfetti = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        
                        if isGenerating {
                            premiumProgressIndicator
                        } else if showSuccess {
                            successState
                        } else {
                            hashtagChips
                        }
                        
                        Button(action: generate) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14).fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.078, blue: 0.576),  // Hot Pink
                                            Color(red: 0.6, green: 0.196, blue: 0.8),   // Purple
                                            Color(red: 0.0, green: 1.0, blue: 1.0)      // Cyan
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                ).frame(height: 56)
                                
                                if isGenerating {
                                    HStack(spacing: 10) {
                                        PulsingProgressView()
                                        Text(getProgressText())
                                    }.foregroundColor(.white)
                                } else if showSuccess {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .scaleEffect(showSuccess ? 1.2 : 1.0)
                                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showSuccess)
                                        Text("Shared to TikTok!")
                                    }.foregroundColor(.white)
                                } else {
                                    Text("Generate & Share to TikTok").bold().foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isGenerating || showSuccess)
                        .scaleEffect(isGenerating ? 0.98 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: isGenerating)
                        .padding(.bottom, 40)
                    }.padding(.horizontal, 20)
                }
                
                // Confetti overlay
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 0.5), value: showConfetti)
                }
            }
            .navigationTitle("TikTok Video")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.foregroundColor(.white) }
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private var hashtagChips: some View {
        let optimizedTags = generateSmartHashtags()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Optimized Hashtags (15 max)").font(.headline).foregroundColor(.white)
            Text("70% trending • 30% niche • Always #SnapChef #FoodTok #FridgeChallenge")
                .font(.caption)
                .foregroundColor(.gray)
            Wrap(optimizedTags, spacing: 8) { 
                Text("#\($0)")
                    .padding(.horizontal,10)
                    .padding(.vertical,6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .foregroundColor(.white) 
            }
        }
    }
    
    /// Generate smart hashtag selection based on recipe and current trends
    private func generateSmartHashtags() -> [String] {
        guard case .recipe(let recipe) = content.type else {
            // Default hashtags for non-recipe content
            return Array(HashtagOptimizer.generateOptimalHashtags()
                .components(separatedBy: " ")
                .compactMap { $0.hasPrefix("#") ? String($0.dropFirst()) : nil }
                .prefix(15))
        }
        
        // Create ViralRecipe from recipe data
        let viralRecipe = ViralRecipe(
            title: recipe.name,
            hook: nil,
            steps: recipe.instructions.map { ViralRecipe.Step($0) },
            timeMinutes: recipe.cookTime + recipe.prepTime,
            costDollars: nil,
            calories: recipe.nutrition.calories,
            ingredients: recipe.ingredients.map { $0.name }
        )
        
        // Generate recipe-specific hashtags
        return Array(HashtagOptimizer.generateRecipeSpecificHashtags(recipe: viralRecipe)
            .components(separatedBy: " ")
            .compactMap { $0.hasPrefix("#") ? String($0.dropFirst()) : nil }
            .prefix(15))
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) { Image(systemName:"music.note").font(.system(size: 22, weight: .bold)); Text("TikTok Video Generator").font(.system(size: 22, weight: .bold)) }.foregroundColor(.white)
            Text("Auto-shares to TikTok after generation").foregroundColor(.gray).font(.subheadline)
        }.padding(.top, 18)
    }
    
    private func getProgressText() -> String {
        let phase = engine.currentProgress.phase.rawValue.capitalized
        if phase.contains("Rendering") {
            return "Rendering Video..."
        } else if videoURL != nil {
            return "Sharing to TikTok..."
        } else {
            return phase
        }
    }
    
    private func isPhaseComplete(current: RenderPhase, target: RenderPhase) -> Bool {
        let phases: [RenderPhase] = [.preparingAssets, .planning, .renderingFrames, .compositing, .addingOverlays, .encoding, .finalizing, .complete]
        guard let currentIndex = phases.firstIndex(of: current),
              let targetIndex = phases.firstIndex(of: target) else {
            return false
        }
        return currentIndex > targetIndex
    }
    
    // MARK: - Premium UI Components
    
    private var premiumProgressIndicator: some View {
        VStack(spacing: 25) {
            // Animated SnapChef logo
            AnimatedSnapChefLogo()
            
            // Progress phases with emojis
            VStack(spacing: 15) {
                let currentPhase = engine.currentProgress.phase
                let phases: [(RenderPhase, String, String)] = [
                    (.preparingAssets, "📸", "Analyzing your photos"),
                    (.planning, "🎯", "Planning the perfect video"),
                    (.renderingFrames, "🎬", "Creating magic frames"),
                    (.compositing, "✨", "Compositing layers"),
                    (.addingOverlays, "🎨", "Adding viral overlays"),
                    (.encoding, "📦", "Encoding for TikTok"),
                    (.finalizing, "🚀", "Finalizing masterpiece")
                ]
                
                ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                    let (phaseType, emoji, description) = phase
                    let isActive = currentPhase == phaseType
                    let isComplete = isPhaseComplete(current: currentPhase, target: phaseType)
                    
                    HStack(spacing: 15) {
                        Text(emoji)
                            .font(.title2)
                            .scaleEffect(isActive ? 1.3 : 1.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).repeatForever(autoreverses: true), value: isActive)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(description)
                                .font(.headline)
                                .foregroundColor(isComplete ? .green : isActive ? .white : .gray)
                            
                            if isActive {
                                ProgressView(value: engine.currentProgress.progress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                                    .scaleEffect(y: 0.8)
                            }
                        }
                        
                        Spacer()
                        
                        if isComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isActive)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isComplete)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.pink.opacity(0.5), .purple.opacity(0.5), .cyan.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private var successState: some View {
        VStack(spacing: 20) {
            // Success animation
            VStack(spacing: 15) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .scaleEffect(showSuccess ? 1.0 : 0.3)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showSuccess)
                
                Text("Video Created Successfully!")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .opacity(showSuccess ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5).delay(0.3), value: showSuccess)
                
                Text("Your viral TikTok video is ready to go!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .opacity(showSuccess ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5).delay(0.5), value: showSuccess)
            }
        }
        .padding()
    }

    private func generate() {
        guard let inputs = content.toRenderInputs() else { return }
        let (recipe, media) = inputs
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        isGenerating = true
        Task {
            do {
                let url = try await engine.render(template: template, recipe: recipe, media: media) { _ in }
                self.videoURL = url
                
                // Success haptic feedback
                await MainActor.run {
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                    
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showSuccess = true
                        showConfetti = true
                    }
                    
                    // Hide confetti after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showConfetti = false
                        }
                    }
                }
                
                // Automatically share to TikTok after generation
                await shareToTikTokAutomatically(url: url)
            } catch { 
                await MainActor.run {
                    // Error haptic feedback
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                    
                    self.error = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }

    @MainActor
    private func shareToTikTokAutomatically(url: URL) async {
        // Request photo permission first
        let hasPermission = await withCheckedContinuation { continuation in
            ViralVideoExporter.requestPhotoPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard hasPermission else {
            self.error = "Photo access denied"
            self.isGenerating = false
            return
        }
        
        // Save video to Photos
        let saveResult = await withCheckedContinuation { continuation in
            ViralVideoExporter.saveToPhotos(videoURL: url) { result in
                continuation.resume(returning: result)
            }
        }
        
        switch saveResult {
        case .success(let identifier):
            // Share to TikTok with viral caption generation
            let caption: String
            if case .recipe(let recipe) = content.type {
                let viralRecipe = ViralRecipe(
                    title: recipe.name,
                    hook: nil,
                    steps: recipe.instructions.map { ViralRecipe.Step($0) },
                    timeMinutes: recipe.cookTime + recipe.prepTime,
                    costDollars: nil,
                    calories: recipe.nutrition.calories,
                    ingredients: recipe.ingredients.map { $0.name }
                )
                caption = ViralCaptionGenerator.generateRecipeCaption(recipe: viralRecipe)
            } else {
                caption = ViralCaptionGenerator.generateViralCaption(baseCaption: "Check out this amazing recipe transformation!")
            }
            
            let shareResult = await withCheckedContinuation { continuation in
                ViralVideoExporter.shareToTikTok(localIdentifiers: [identifier], caption: caption) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch shareResult {
            case .success:
                // Success - TikTok app should now be open
                self.isGenerating = false
                // Optionally dismiss the view since TikTok is now open
                dismiss()
            case .failure(let error):
                self.error = error.localizedDescription
                self.isGenerating = false
            }
            
        case .failure(let error):
            self.error = error.localizedDescription
            self.isGenerating = false
        }
    }
}

// Simple wrapping layout using LazyVGrid for Swift 6 compatibility
struct Wrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    
    init(_ d: Data, spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        data = d
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: spacing)], spacing: spacing) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
            }
        }
        .frame(maxHeight: 120)
    }
}

// MARK: - Premium Animated Components

struct AnimatedSnapChefLogo: View {
    @State private var animate = false
    @State private var gradientOffset = 0.0
    
    var body: some View {
        Text("SNAPCHEF!")
            .font(.system(size: 32, weight: .heavy, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.078, blue: 0.576),  // Hot Pink
                        Color(red: 0.6, green: 0.196, blue: 0.8),   // Purple
                        Color(red: 0.0, green: 1.0, blue: 1.0)      // Cyan
                    ],
                    startPoint: .init(x: gradientOffset - 0.5, y: 0),
                    endPoint: .init(x: gradientOffset + 0.5, y: 0)
                )
            )
            .shadow(color: .cyan.opacity(0.6), radius: 8, x: 0, y: 0)
            .scaleEffect(animate ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)
            .onAppear {
                animate = true
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    gradientOffset = 1.0
                }
            }
    }
}

struct PulsingProgressView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                LinearGradient(
                    colors: [.cyan, .purple, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 20, height: 20)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// ConfettiView is already defined in RecipeResultsView.swift