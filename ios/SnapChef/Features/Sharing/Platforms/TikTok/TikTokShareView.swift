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
    @State private var buttonShake = false
    @State private var selectedHashtags: [String] = [] // Array to maintain selection order for FIFO
    @State private var showRetryAlert = false
    @State private var currentTikTokError: TikTokExportError?
    @State private var retryAction: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        
                        if isGenerating {
                            premiumProgressIndicator
                        } else if showSuccess {
                            successState
                        } else {
                            hashtagChips
                        }
                        
                        generateButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }
                
                // Confetti overlay
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 0.5), value: showConfetti)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { 
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            // Start button shake animation after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                startButtonShake()
            }
        }
        .alert("Error", isPresented: .constant(error != nil && currentTikTokError == nil)) { 
            Button("OK") { error = nil } 
        } message: { 
            Text(error ?? "") 
        }
        .alert("Video Generation Issue", isPresented: $showRetryAlert) {
            if let tikTokError = currentTikTokError, tikTokError.isRetryable {
                Button("Retry") {
                    showRetryAlert = false
                    retryAction?()
                }
                Button("Cancel") {
                    showRetryAlert = false
                    currentTikTokError = nil
                    retryAction = nil
                }
            } else {
                Button("OK") {
                    showRetryAlert = false
                    currentTikTokError = nil
                    retryAction = nil
                }
            }
        } message: {
            if let tikTokError = currentTikTokError {
                Text(tikTokError.userFriendlyMessage)
            }
        }
    }

    private var hashtagChips: some View {
        let optimizedTags = generateSmartHashtags()
        return VStack(alignment: .leading, spacing: 16) {
            // Header section
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Hashtags")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Choose hashtags for your TikTok video • \(selectedHashtags.count)/5 selected")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Hashtag grid with selectable chips
            VStack(alignment: .leading, spacing: 12) {
                let rows = optimizedTags.chunked(into: 3)
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 8) {
                        ForEach(Array(row.enumerated()), id: \.offset) { tagIndex, tag in
                            SelectableHashtagChip(
                                hashtag: tag,
                                isSelected: selectedHashtags.contains(tag)
                            ) {
                                toggleHashtagSelection(tag)
                            }
                        }
                        Spacer()
                    }
                }
            }
            
            // Selection actions
            HStack(spacing: 12) {
                Button("Select All") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedHashtags = Array(optimizedTags.prefix(5))
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.cyan)
                
                Button("Clear All") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedHashtags.removeAll()
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.pink)
                
                Spacer()
                
                Text("\(selectedHashtags.count)/5")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            // Pre-select exactly 5 most popular hashtags
            selectedHashtags = Array(optimizedTags.prefix(5))
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
        VStack(spacing: 12) {
            // Main title with icon
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.078, blue: 0.576),
                                    Color(red: 0.6, green: 0.196, blue: 0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TikTok Video Generator")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Select hashtags, generate video, then auto-share to TikTok")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            // Progress indicator
            HStack(spacing: 16) {
                StepIndicator(number: "1", title: "Generate", isCompleted: showSuccess, isActive: !showSuccess)
                
                ConnectorLine(isCompleted: showSuccess)
                
                StepIndicator(number: "2", title: "Share", isCompleted: false, isActive: showSuccess)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
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
        Task {
            await performGeneration()
        }
    }
    
    private func performGeneration() async {
        guard let inputs = content.toRenderInputs() else { return }
        let (recipe, media) = inputs
        
        await MainActor.run {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
            
            isGenerating = true
        }
        
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
            
            // Automatically share to TikTok after generation with selected hashtags
            await shareToTikTokAutomatically(url: url)
        } catch { 
                await MainActor.run {
                    // Error haptic feedback
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                    
                    // Handle TikTokExportError specifically
                    if let tikTokError = error as? TikTokExportError {
                        self.currentTikTokError = tikTokError
                        if tikTokError.isRetryable {
                            self.retryAction = {
                                Task {
                                    await self.performGeneration()
                                }
                            }
                            self.showRetryAlert = true
                        } else {
                            self.showRetryAlert = true
                        }
                    } else {
                        self.error = error.localizedDescription
                    }
                    self.isGenerating = false
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
            self.currentTikTokError = TikTokExportError.photoAccessDenied
            self.showRetryAlert = true
            self.retryAction = {
                Task {
                    await self.shareToTikTokAutomatically(url: url)
                }
            }
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
            // Share to TikTok with viral caption generation and selected hashtags
            let caption: String
            let selectedHashtagsString = selectedHashtags.isEmpty ? "" : "\n\n" + selectedHashtags.map { "#\($0)" }.joined(separator: " ")
            
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
                // Generate base caption without hashtags and add our selected ones
                let baseCaptionWithHashtags = ViralCaptionGenerator.generateRecipeCaption(recipe: viralRecipe)
                // Remove the automatically generated hashtags and replace with selected ones
                let baseCaptionComponents = baseCaptionWithHashtags.components(separatedBy: "\n\n")
                let captionWithoutHashtags = baseCaptionComponents.dropLast(2).joined(separator: "\n\n") // Remove hashtags and app link
                caption = captionWithoutHashtags + selectedHashtagsString + "\n\nDownload: apps.apple.com/snapchef"
            } else {
                let baseCaptionWithHashtags = ViralCaptionGenerator.generateViralCaption(baseCaption: "Check out this amazing recipe transformation!")
                // Remove the automatically generated hashtags and replace with selected ones
                let baseCaptionComponents = baseCaptionWithHashtags.components(separatedBy: "\n\n")
                let captionWithoutHashtags = baseCaptionComponents.dropLast(2).joined(separator: "\n\n") // Remove hashtags and app link
                caption = captionWithoutHashtags + selectedHashtagsString + "\n\nDownload: apps.apple.com/snapchef"
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
                
                // Auto-dismiss both TikTokShareView and parent share view
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Dismiss TikTokShareView
                    dismiss()
                    
                    // Also dismiss the parent BrandedSharePopup
                    NotificationCenter.default.post(
                        name: Notification.Name("DismissSharePopup"),
                        object: nil
                    )
                }
                
            case .failure(let error):
                // Handle TikTok sharing errors with user-friendly messages
                self.currentTikTokError = error
                self.showRetryAlert = true
                self.isGenerating = false
            }
            
        case .failure(let error):
            // Handle TikTokExportError specifically for better UX
            self.currentTikTokError = error
            if error.isRetryable {
                self.retryAction = {
                    Task {
                        await self.shareToTikTokAutomatically(url: url)
                    }
                }
            }
            self.showRetryAlert = true
            self.isGenerating = false
        }
    }
    
    // MARK: - UI Components
    
    private var generateButton: some View {
        Button(action: generate) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.078, blue: 0.576),  // Hot Pink
                                Color(red: 0.6, green: 0.196, blue: 0.8),   // Purple
                                Color(red: 0.0, green: 1.0, blue: 1.0)      // Cyan
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 60)
                    .shadow(
                        color: Color(red: 1.0, green: 0.078, blue: 0.576).opacity(0.3),
                        radius: 15,
                        y: 8
                    )
                
                if isGenerating {
                    HStack(spacing: 12) {
                        PulsingProgressView()
                        Text(getProgressText())
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                } else if showSuccess {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .scaleEffect(showSuccess ? 1.2 : 1.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showSuccess)
                        Text("Shared to TikTok!")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                } else {
                    VStack(spacing: 4) {
                        Text("Generate & Share to TikTok")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        if selectedHashtags.isEmpty {
                            Text("(Select hashtags first)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                }
            }
        }
        .disabled(isGenerating || showSuccess)
        .scaleEffect(isGenerating ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isGenerating)
        .modifier(ShakeEffect(shakeNumber: buttonShake ? 2 : 0))
    }
    
    // MARK: - Helper Functions
    
    private func startButtonShake() {
        withAnimation(.default) {
            buttonShake = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            buttonShake = false
            
            // Repeat every 8-12 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 8...12)) {
                startButtonShake()
            }
        }
    }
    
    private func toggleHashtagSelection(_ hashtag: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let index = selectedHashtags.firstIndex(of: hashtag) {
                // Remove if already selected
                selectedHashtags.remove(at: index)
            } else {
                // Add new hashtag with FIFO logic (max 5)
                if selectedHashtags.count >= 5 {
                    // Remove oldest selection (first item) and add new one
                    selectedHashtags.removeFirst()
                }
                selectedHashtags.append(hashtag)
            }
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Supporting Views

struct SelectableHashtagChip: View {
    let hashtag: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("#\(hashtag)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .black : .white)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [Color.cyan, Color.cyan.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: isPressed ? 
                                [Color.white.opacity(0.2), Color.white.opacity(0.15)] :
                                [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.cyan.opacity(0.8) : Color.white.opacity(isPressed ? 0.3 : 0.15),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct StepIndicator: View {
    let number: String
    let title: String
    let isCompleted: Bool
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        isCompleted ? LinearGradient(
                            colors: [Color.green, Color.green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        isActive ? LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.078, blue: 0.576).opacity(0.8),
                                Color(red: 0.6, green: 0.196, blue: 0.8).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) : LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text(number)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(isActive ? 1.0 : 0.6))
        }
    }
}

struct ConnectorLine: View {
    let isCompleted: Bool
    
    var body: some View {
        Rectangle()
            .fill(isCompleted ? Color.green : Color.white.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}


// Array extension for chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
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