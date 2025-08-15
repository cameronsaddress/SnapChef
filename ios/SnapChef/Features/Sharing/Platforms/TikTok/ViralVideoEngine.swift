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

    public let config: RenderConfig
    private let renderer: ViralVideoRenderer
    private let planner: RenderPlanner

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
        let startTime = Date()
        print("[ViralVideoEngine] \(startTime): Starting render process")
        
        isRendering = true
        defer { 
            isRendering = false
            let endTime = Date()
            print("[ViralVideoEngine] \(endTime): Render process completed in \(endTime.timeIntervalSince(startTime))s")
        }
        
        print("[ViralVideoEngine] \(Date()): Starting planning phase")
        try await update(.planning, 0.05, handler: progressHandler)

        print("[ViralVideoEngine] \(Date()): Creating render plan")
        let plan = try await planner.createRenderPlan(template: template, recipe: recipe, media: media)
        print("[ViralVideoEngine] \(Date()): Render plan created with \(plan.items.count) items")
        try await update(.renderingFrames, 0.1, handler: progressHandler)

        print("[ViralVideoEngine] \(Date()): Starting renderer.render()")
        let url = try await renderer.render(plan: plan, config: config) { p in
            Task { try? await self.update(.renderingFrames, p, handler: progressHandler) }
        }
        print("[ViralVideoEngine] \(Date()): Renderer.render() completed, output URL: \(url)")
        try await update(.finalizing, 1.0, handler: progressHandler)
        return url
    }

    @MainActor
    private func update(_ phase: RenderPhase, _ p: Double,
                        handler: @escaping @Sendable (RenderProgress) async -> Void) async throws {
        let mem = MemoryOptimizer.shared.getCurrentMemoryUsage()
        currentProgress = RenderProgress(phase: phase, progress: p, memoryUsage: mem)
        let progCopy = RenderProgress(phase: phase, progress: p, memoryUsage: mem)
        await handler(progCopy)
        if !MemoryOptimizer.shared.isMemoryUsageSafe() { MemoryOptimizer.shared.forceMemoryCleanup() }
    }
}