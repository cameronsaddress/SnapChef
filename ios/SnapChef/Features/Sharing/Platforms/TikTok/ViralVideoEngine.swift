// REPLACE ENTIRE FILE: ViralVideoEngine.swift

import UIKit
@preconcurrency import AVFoundation
import CoreMedia
import Combine

@MainActor
public final class ViralVideoEngine: ObservableObject {
    @Published public var isRendering = false
    @Published public var currentProgress = RenderProgress(phase: .planning, progress: 0)
    @Published public var errorMessage: String?
    @Published public var memoryStatus = MemoryStatus(
        currentUsage: 0,
        warningThreshold: 250 * 1_024 * 1_024,
        criticalThreshold: 300 * 1_024 * 1_024,
        pressureLevel: .normal,
        activeTaskCount: 0
    )

    public let config: RenderConfig
    private let renderer: ViralVideoRenderer
    private let planner: RenderPlanner
    private var cancellationToken: CancellationToken?
    private let memoryOptimizer = MemoryOptimizer.shared

    public init(config: RenderConfig = RenderConfig()) {
        var configWithScale = config
        configWithScale.contentsScale = UIScreen.main.scale
        self.config = configWithScale
        self.renderer = ViralVideoRenderer(config: configWithScale)
        self.planner = RenderPlanner(config: configWithScale)
        MemoryOptimizer.shared.startOptimization()
    }

    deinit { MemoryOptimizer.shared.stopOptimization() }

    public func render(template: ViralTemplate, recipe: ViralRecipe, media: MediaBundle,
                       progressHandler: @escaping @Sendable (RenderProgress) async -> Void = { _ in }) async throws -> URL {
        // Create cancellation token for this render operation
        cancellationToken = memoryOptimizer.createCancellationToken()
        
        let startTime = Date()
        print("[ViralVideoEngine] \(startTime): Starting render process with cancellation support")

        isRendering = true
        defer {
            // CRITICAL FIX: Proper cleanup in defer block
            autoreleasepool {
                isRendering = false
                cancellationToken?.cancel()
                cancellationToken = nil
                
                // Force memory cleanup after render
                memoryOptimizer.forceMemoryCleanup()
                
                let endTime = Date()
                print("[ViralVideoEngine] \(endTime): Render process completed in \(endTime.timeIntervalSince(startTime))s")
            }
        }
        
        // Validate inputs before starting
        try validateRenderInputs(template: template, recipe: recipe, media: media)
        
        // Monitor memory throughout the process
        updateMemoryStatus()

        print("[ViralVideoEngine] \(Date()): Starting planning phase")
        try cancellationToken?.throwIfCancelled()
        try await update(.planning, 0.05, handler: progressHandler)

        print("[ViralVideoEngine] \(Date()): Creating render plan")
        try cancellationToken?.throwIfCancelled()
        let plan = try await planner.createRenderPlan(template: template, recipe: recipe, media: media)
        print("[ViralVideoEngine] \(Date()): Render plan created with \(plan.items.count) items")
        try await update(.renderingFrames, 0.1, handler: progressHandler)

        print("[ViralVideoEngine] \(Date()): Starting renderer.render()")
        try cancellationToken?.throwIfCancelled()
        
        // CRITICAL FIX: Use weak self to prevent retain cycles and add comprehensive error handling
        do {
            let url = try await renderer.render(plan: plan, config: config, cancellationToken: cancellationToken) { [weak self] p in
                Task { [weak self] in
                    guard let self = self else { return }
                    try? await self.update(.renderingFrames, p, handler: progressHandler)
                }
            }
            print("[ViralVideoEngine] \(Date()): Renderer.render() completed, output URL: \(url)")
            try await update(.finalizing, 1.0, handler: progressHandler)
            
            // Validate output file
            try validateOutputFile(url: url)
            
            return url
        } catch is CancellationError {
            print("[ViralVideoEngine] Render cancelled by user or memory pressure")
            let snapChefError = SnapChefError.videoGenerationError("Video generation was cancelled.", recovery: .retry)
            ErrorAnalytics.logError(snapChefError, context: "viral_video_cancelled")
            throw snapChefError
        } catch {
            print("[ViralVideoEngine] Render failed: \(error)")
            let snapChefError = SnapChefError.videoGenerationError(
                "Failed to generate video: \(error.localizedDescription)",
                recovery: .retry
            )
            ErrorAnalytics.logError(snapChefError, context: "viral_video_render_error")
            throw snapChefError
        }
    }

    /// Cancel the current render operation
    public func cancelRender() {
        cancellationToken?.cancel()
        print("[ViralVideoEngine] Render operation cancelled by user")
    }
    
    /// Update memory status with proper resource management
    private func updateMemoryStatus() {
        autoreleasepool {
            memoryStatus = memoryOptimizer.getMemoryStatus()
            
            // Trigger emergency cleanup if critical
            if memoryStatus.pressureLevel == .critical {
                print("[ViralVideoEngine] Critical memory pressure detected: \(memoryStatus.currentUsageMB)MB")
                memoryOptimizer.emergencyMemoryCleanup()
                
                // Cancel current operation if memory is still critical after cleanup
                let updatedStatus = memoryOptimizer.getMemoryStatus()
                if updatedStatus.pressureLevel == .critical {
                    cancellationToken?.cancel()
                    print("[ViralVideoEngine] Cancelling render due to persistent memory pressure")
                }
                
                memoryStatus = updatedStatus
            }
        }
    }
    
    @MainActor
    private func update(_ phase: RenderPhase, _ p: Double,
                        handler: @escaping @Sendable (RenderProgress) async -> Void) async throws {
        // Check for cancellation
        try cancellationToken?.throwIfCancelled()
        
        // Update memory status
        updateMemoryStatus()
        
        let mem = memoryOptimizer.getCurrentMemoryUsage()
        currentProgress = RenderProgress(phase: phase, progress: p, memoryUsage: mem)
        let progCopy = RenderProgress(phase: phase, progress: p, memoryUsage: mem)
        await handler(progCopy)
        
        // Handle memory pressure with proper error handling
        if memoryStatus.pressureLevel == .critical {
            print("[ViralVideoEngine] Throwing cancellation due to critical memory: \(memoryStatus.currentUsageMB)MB")
            throw CancellationError()
        } else if memoryStatus.pressureLevel == .warning {
            print("[ViralVideoEngine] Warning memory level, forcing cleanup: \(memoryStatus.currentUsageMB)MB")
            memoryOptimizer.forceMemoryCleanup()
        }
    }
    
    // MARK: - Validation Helpers
    
    /// Validate render inputs before starting
    private func validateRenderInputs(template: ViralTemplate, recipe: ViralRecipe, media: MediaBundle) throws {
        // Validate template - now just verify it's valid
        // No scenes property anymore, template is just an enum case
        
        // Validate recipe
        guard !recipe.title.isEmpty else {
            throw SnapChefError.videoGenerationError("Recipe title is required for video generation.", recovery: .none)
        }
        
        guard !recipe.steps.isEmpty else {
            throw SnapChefError.videoGenerationError("Recipe steps are required for video generation.", recovery: .none)
        }
        
        // Validate media bundle
        guard media.beforeFridge.cgImage != nil else {
            throw SnapChefError.videoGenerationError("Before fridge image is corrupted.", recovery: .retry)
        }
        
        guard media.afterFridge.cgImage != nil else {
            throw SnapChefError.videoGenerationError("After fridge image is corrupted.", recovery: .retry)
        }
        
        guard media.cookedMeal.cgImage != nil else {
            throw SnapChefError.videoGenerationError("Cooked meal image is corrupted.", recovery: .retry)
        }
        
        // Check available storage space
        let availableSpace = getAvailableStorageSpace()
        let requiredSpace: Int64 = 100 * 1024 * 1024 // 100MB minimum
        
        guard availableSpace > requiredSpace else {
            throw SnapChefError.storageError(
                "Insufficient storage space. Need at least 100MB to generate video.",
                recovery: .clearData
            )
        }
        
        print("[ViralVideoEngine] Input validation passed")
    }
    
    /// Validate output file after rendering
    private func validateOutputFile(url: URL) throws {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SnapChefError.videoGenerationError("Output video file was not created.", recovery: .retry)
        }
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                guard fileSize > 1024 else { // Must be at least 1KB
                    throw SnapChefError.videoGenerationError("Generated video file is too small or corrupted.", recovery: .retry)
                }
                print("[ViralVideoEngine] Output validation passed: \(fileSize) bytes")
            }
        } catch {
            throw SnapChefError.videoGenerationError(
                "Could not validate output video file: \(error.localizedDescription)",
                recovery: .retry
            )
        }
    }
    
    /// Get available storage space
    private func getAvailableStorageSpace() -> Int64 {
        do {
            guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return 0
            }
            let values = try documentDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return Int64(values.volumeAvailableCapacity ?? 0)
        } catch {
            print("[ViralVideoEngine] Could not determine available storage: \(error)")
            return 0
        }
    }
}
