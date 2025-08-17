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
            isRendering = false
            cancellationToken?.cancel()
            cancellationToken = nil
            let endTime = Date()
            print("[ViralVideoEngine] \(endTime): Render process completed in \(endTime.timeIntervalSince(startTime))s")
        }
        
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
        let url = try await renderer.render(plan: plan, config: config, cancellationToken: cancellationToken) { p in
            Task { try? await self.update(.renderingFrames, p, handler: progressHandler) }
        }
        print("[ViralVideoEngine] \(Date()): Renderer.render() completed, output URL: \(url)")
        try await update(.finalizing, 1.0, handler: progressHandler)
        return url
    }

    /// Cancel the current render operation
    public func cancelRender() {
        cancellationToken?.cancel()
        print("[ViralVideoEngine] Render operation cancelled by user")
    }
    
    /// Update memory status
    private func updateMemoryStatus() {
        memoryStatus = memoryOptimizer.getMemoryStatus()
        
        // Trigger emergency cleanup if critical
        if memoryStatus.pressureLevel == .critical {
            memoryOptimizer.emergencyMemoryCleanup()
            updateMemoryStatus() // Update after cleanup
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
        
        // Handle memory pressure
        if memoryStatus.pressureLevel == .critical {
            throw CancellationError()
        } else if memoryStatus.pressureLevel == .warning {
            memoryOptimizer.forceMemoryCleanup()
        }
    }
}
