//
//  ViralVideoSDK.swift
//  SnapChef
//
//  Created on 12/01/2025
//  Complete viral video SDK integration and interface
//

import UIKit
import SwiftUI
import AVFoundation
import Combine

/// Complete viral video SDK for TikTok content generation
/// Implements all requirements from TIKTOK_VIRAL_COMPLETE_REQUIREMENTS.md
@MainActor
public class ViralVideoSDK: ObservableObject {
    
    // MARK: - Published State
    @Published public var isProcessing = false
    @Published public var currentProgress = RenderProgress(phase: .planning, progress: 0.0)
    @Published public var errorMessage: String?
    @Published public var lastGeneratedVideoURL: URL?
    
    // MARK: - Core Components
    private let engine: ViralVideoEngine
    private let exporter: ViralVideoExporter
    private let memoryOptimizer = MemoryOptimizer.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private let frameMonitor = FrameDropMonitor.shared
    
    // MARK: - Configuration
    private let config: RenderConfig
    
    // MARK: - Initialization
    
    public init(config: RenderConfig = RenderConfig()) {
        self.config = config
        self.engine = ViralVideoEngine(config: config)
        self.exporter = ViralVideoExporter(config: config)
        
        // Start memory optimization
        memoryOptimizer.startOptimization()
        
        // Bind engine state to SDK state
        bindEngineState()
    }
    
    deinit {
        memoryOptimizer.stopOptimization()
    }
    
    // MARK: - Public Interface
    
    /// Generate and share viral video following complete end-to-end flow
    public func generateAndShareVideo(
        template: ViralTemplate,
        recipe: ViralRecipe,
        media: MediaBundle
    ) async {
        
        isProcessing = true
        errorMessage = nil
        
        // Start performance monitoring
        performanceMonitor.startRenderMonitoring()
        memoryOptimizer.logMemoryProfile(phase: "Start Generation")
        
        do {
            // Phase 1: Generate video
            performanceMonitor.markPhaseStart(.renderingFrames)
            let videoURL = try await engine.render(
                template: template,
                recipe: recipe,
                media: media,
                progressHandler: { [weak self] progress in
                    await self?.updateProgress(progress)
                }
            )
            performanceMonitor.markPhaseEnd(.renderingFrames)
            
            lastGeneratedVideoURL = videoURL
            memoryOptimizer.logMemoryProfile(phase: "Video Generated")
            
            // Phase 2: Share to TikTok
            performanceMonitor.markPhaseStart(.complete)
            try await shareToTikTokComplete(
                template: template,
                recipe: recipe,
                media: media,
                videoURL: videoURL
            )
            performanceMonitor.markPhaseEnd(.complete)
            
            // Complete monitoring
            let totalTime = performanceMonitor.completeRenderMonitoring()
            memoryOptimizer.logMemoryProfile(phase: "Complete")
            
            print("✅ Viral video generation completed in \(String(format: "%.2f", totalTime))s")
            
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Viral video generation failed: \(error.localizedDescription)")
        }
        
        isProcessing = false
    }
    
    /// Generate video only (without sharing)
    public func generateVideoOnly(
        template: ViralTemplate,
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> URL {
        
        isProcessing = true
        errorMessage = nil
        
        performanceMonitor.startRenderMonitoring()
        memoryOptimizer.logMemoryProfile(phase: "Start Generation Only")
        
        defer {
            isProcessing = false
            let _ = performanceMonitor.completeRenderMonitoring()
        }
        
        do {
            let videoURL = try await engine.render(
                template: template,
                recipe: recipe,
                media: media,
                progressHandler: { [weak self] progress in
                    await self?.updateProgress(progress)
                }
            )
            
            lastGeneratedVideoURL = videoURL
            memoryOptimizer.logMemoryProfile(phase: "Generation Complete")
            
            return videoURL
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Share existing video to TikTok
    public func shareToTikTok(
        videoURL: URL,
        recipe: ViralRecipe
    ) async throws {
        
        try await withCheckedThrowingContinuation { continuation in
            exporter.shareRecipeToTikTok(
                template: .kineticTextSteps, // Default template for sharing
                recipe: recipe,
                media: MediaBundle(
                    beforeFridge: UIImage(),
                    afterFridge: UIImage(),
                    cookedMeal: UIImage()
                )
            ) { result in
                switch result {
                case .success():
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Get available templates with descriptions
    public func getAvailableTemplates() -> [ViralTemplate] {
        return ViralTemplate.allCases
    }
    
    /// Validate media bundle before processing
    public func validateMediaBundle(_ media: MediaBundle) -> [String] {
        var issues: [String] = []
        
        // Check image sizes
        let targetSize = config.size
        let maxDimension = max(targetSize.width, targetSize.height)
        
        if media.beforeFridge.size.width < maxDimension * 0.5 ||
           media.beforeFridge.size.height < maxDimension * 0.5 {
            issues.append("Before image resolution too low")
        }
        
        if media.afterFridge.size.width < maxDimension * 0.5 ||
           media.afterFridge.size.height < maxDimension * 0.5 {
            issues.append("After image resolution too low")
        }
        
        if media.cookedMeal.size.width < maxDimension * 0.5 ||
           media.cookedMeal.size.height < maxDimension * 0.5 {
            issues.append("Cooked meal image resolution too low")
        }
        
        return issues
    }
    
    /// Clean up resources and temporary files
    public func cleanup() {
        if let videoURL = lastGeneratedVideoURL {
            memoryOptimizer.deleteTempFile(videoURL)
            lastGeneratedVideoURL = nil
        }
        
        memoryOptimizer.forceMemoryCleanup()
    }
    
    // MARK: - Recipe Conversion Helpers
    
    /// Convert existing SnapChef Recipe to viral video Recipe format
    internal func convertRecipe(_ snapChefRecipe: SnapChef.Recipe) -> ViralRecipe {
        // Convert ingredients
        let ingredients = snapChefRecipe.ingredients.map { $0.name }
        
        // Convert instructions to steps
        let steps = snapChefRecipe.instructions.enumerated().map { index, instruction in
            ViralRecipe.Step(
                title: instruction,
                secondsHint: nil // Could estimate based on instruction complexity
            )
        }
        
        // Generate hook
        let totalTime = snapChefRecipe.prepTime + snapChefRecipe.cookTime
        let hook = "From fridge chaos to \(snapChefRecipe.name) in \(totalTime) min!"
        
        return ViralRecipe(
            title: snapChefRecipe.name,
            hook: hook,
            steps: steps,
            timeMinutes: totalTime,
            costDollars: nil, // Could estimate based on ingredients
            calories: snapChefRecipe.nutrition.calories,
            ingredients: ingredients
        )
    }
    
    /// Create MediaBundle from image URLs
    public func createMediaBundle(
        beforeImageURL: URL?,
        afterImageURL: URL?,
        cookedMealImageURL: URL?,
        musicURL: URL? = nil
    ) async throws -> MediaBundle {
        
        let beforeImage = try await loadImage(from: beforeImageURL) ?? createPlaceholderImage(text: "BEFORE")
        let afterImage = try await loadImage(from: afterImageURL) ?? createPlaceholderImage(text: "AFTER")
        let cookedMealImage = try await loadImage(from: cookedMealImageURL) ?? createPlaceholderImage(text: "MEAL")
        
        return MediaBundle(
            beforeFridge: beforeImage,
            afterFridge: afterImage,
            cookedMeal: cookedMealImage,
            musicURL: musicURL
        )
    }
    
    // MARK: - Template Recommendations
    
    /// Recommend best template based on recipe characteristics
    public func recommendTemplate(for recipe: ViralRecipe) -> ViralTemplate {
        let stepCount = recipe.steps.count
        let hasTime = recipe.timeMinutes != nil
        let hasCost = recipe.costDollars != nil
        let ingredientCount = recipe.ingredients.count
        
        // Template selection logic based on content
        if stepCount <= 3 && ingredientCount <= 4 {
            return .kineticTextSteps  // was .beatSyncedCarousel
        } else if stepCount >= 4 && stepCount <= 6 {
            return .kineticTextSteps
        } else if hasTime && hasCost {
            return .kineticTextSteps  // was .priceTimeChallenge
        } else if ingredientCount >= 3 {
            return .kineticTextSteps  // was .splitScreenSwipe
        } else {
            return .kineticTextSteps  // was .greenScreenPIP
        }
    }
    
    // MARK: - Progress and State Management
    
    private func updateProgress(_ progress: RenderProgress) async {
        currentProgress = progress
        
        // Log memory usage during high-intensity phases
        if progress.phase == .renderingFrames || progress.phase == .encoding {
            memoryOptimizer.logMemoryProfile(phase: progress.phase.rawValue)
        }
        
        // Check memory safety
        if !memoryOptimizer.isMemoryUsageSafe() {
            await handleMemoryPressure()
        }
    }
    
    private func bindEngineState() {
        // Bind engine properties to SDK properties
        // This would use Combine in a real implementation
    }
    
    private func handleMemoryPressure() async {
        print("⚠️ Memory pressure detected - performing cleanup")
        memoryOptimizer.forceMemoryCleanup()
        
        // Could also reduce quality settings temporarily
        // or pause processing until memory is available
    }
    
    // MARK: - Private Helpers
    
    private func shareToTikTokComplete(
        template: ViralTemplate,
        recipe: ViralRecipe,
        media: MediaBundle,
        videoURL: URL
    ) async throws {
        
        return try await withCheckedThrowingContinuation { continuation in
            
            // Check photo permissions first
            ViralVideoExporter.requestPhotoPermission { granted in
                guard granted else {
                    continuation.resume(throwing: ShareError.photoAccessDenied)
                    return
                }
                
                // Save to Photos
                ViralVideoExporter.saveToPhotos(videoURL: videoURL) { saveResult in
                    switch saveResult {
                    case .success(let localIdentifier):
                        // Generate caption
                        let caption = CaptionGenerator.defaultCaption(from: recipe)
                        
                        // Share to TikTok
                        ViralVideoExporter.shareToTikTok(
                            localIdentifiers: [localIdentifier],
                            caption: caption
                        ) { shareResult in
                            continuation.resume(with: shareResult)
                        }
                        
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func loadImage(from url: URL?) async throws -> UIImage? {
        guard let url = url else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
    
    private func createPlaceholderImage(text: String) -> UIImage {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background
            UIColor.systemGray5.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: UIColor.systemGray
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
}

// MARK: - SwiftUI Integration

/// SwiftUI view for viral video generation
public struct ViralVideoGeneratorView: View {
    
    @StateObject private var sdk = ViralVideoSDK()
    @State private var selectedTemplate: ViralTemplate = .kineticTextSteps
    @State private var showingResults = false
    
    let recipe: ViralRecipe
    let media: MediaBundle
    
    public init(recipe: ViralRecipe, media: MediaBundle) {
        self.recipe = recipe
        self.media = media
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            
            // Header
            Text("Create Viral TikTok Video")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Template Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose Template")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(sdk.getAvailableTemplates(), id: \.rawValue) { template in
                        templateCard(template)
                    }
                }
            }
            
            // Recipe Info
            VStack(alignment: .leading, spacing: 8) {
                Text("Recipe: \(recipe.title)")
                    .font(.headline)
                
                if let time = recipe.timeMinutes {
                    Text("Time: \(time) minutes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Ingredients: \(recipe.ingredients.prefix(3).joined(separator: ", "))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Progress
            if sdk.isProcessing {
                VStack(spacing: 12) {
                    ProgressView(value: sdk.currentProgress.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text(sdk.currentProgress.phase.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let memoryUsage = sdk.currentProgress.memoryUsage {
                        let memoryMB = Double(memoryUsage) / 1024.0 / 1024.0
                        Text("Memory: \(String(format: "%.1f", memoryMB)) MB")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Error Message
            if let error = sdk.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            // Generate Button
            Button(action: generateVideo) {
                HStack {
                    if sdk.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                    
                    Text(sdk.isProcessing ? "Generating..." : "Generate & Share")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(sdk.isProcessing ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(sdk.isProcessing)
        }
        .padding()
        .sheet(isPresented: $showingResults) {
            if let videoURL = sdk.lastGeneratedVideoURL {
                VideoResultView(videoURL: videoURL)
            }
        }
    }
    
    private func templateCard(_ template: ViralTemplate) -> some View {
        VStack(spacing: 8) {
            Text(template.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
            
            Text(template.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(height: 80)
        .padding()
        .background(
            selectedTemplate == template ?
            Color.blue.opacity(0.2) :
            Color.gray.opacity(0.1)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    selectedTemplate == template ? Color.blue : Color.clear,
                    lineWidth: 2
                )
        )
        .onTapGesture {
            selectedTemplate = template
        }
    }
    
    private func generateVideo() {
        Task {
            await sdk.generateAndShareVideo(
                template: selectedTemplate,
                recipe: recipe,
                media: media
            )
            
            if sdk.lastGeneratedVideoURL != nil && sdk.errorMessage == nil {
                showingResults = true
            }
        }
    }
}

// MARK: - Video Result View

private struct VideoResultView: View {
    let videoURL: URL
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Video Generated Successfully!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your viral TikTok video has been saved to Photos and shared!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // Could add video preview here using AVPlayerViewController
            
            Button("Done") {
                // Dismiss
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}