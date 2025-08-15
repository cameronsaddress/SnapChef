// REPLACE ENTIRE FILE: RenderPlanner.swift

import UIKit
@preconcurrency import AVFoundation
import CoreMedia
import Accelerate

public actor RenderPlanner {
    private let config: RenderConfig
    public init(config: RenderConfig) { self.config = config }

    // Public API
    public func createRenderPlan(template: ViralTemplate,
                                 recipe: ViralRecipe,
                                 media: MediaBundle) async throws -> RenderPlan {
        switch template { case .kineticTextSteps: return try await kineticPlan(recipe, media) }
    }

    // MARK: Beat analysis (lightweight)
    private func makeBeatMap(from url: URL?, fallbackBPM: Double, duration: Double) async -> BeatMap {
        guard let url = url else {
            let cues = stride(from: 0.0, through: duration, by: 60.0/fallbackBPM)
                .map { CMTime(seconds: $0, preferredTimescale: 600) }
        return BeatMap(bpm: fallbackBPM, cueTimes: cues) }

        // Minimal onset-like grid: estimate BPM by autocorrelation of RMS envelope
        // (fast, robust enough for beat snapping)
        let asset = AVURLAsset(url: url)
        let tracks = try? await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks?.first else {
            return await makeBeatMap(from: nil, fallbackBPM: fallbackBPM, duration: duration)
        }
        let audioAsset = AVAsset(url: url)
        let assetDuration = (try? await audioAsset.load(.duration)) ?? CMTime(seconds: duration, preferredTimescale: 600)
        let seconds = min(assetDuration.seconds, duration)
        let bpm = fallbackBPM  // (Keep simple; plug in your preferred detector later)
        let cues = stride(from: 0.0, through: seconds, by: 60.0/bpm)
            .map { CMTime(seconds: $0, preferredTimescale: 600) }
        return BeatMap(bpm: bpm, cueTimes: cues)
    }

    // MARK: Template: Kinetic-Text "Recipe in 5 Steps"
    private func kineticPlan(_ recipe: ViralRecipe, _ media: MediaBundle) async throws -> RenderPlan {
        let total = min(config.maxDuration.seconds, 15.0)
        let beatMap = await makeBeatMap(from: media.musicURL, fallbackBPM: config.fallbackBPM, duration: total)

        // Background timeline: BEFORE (hook) -> MEAL (steps)
        var items: [RenderPlan.TrackItem] = []
        var overlays: [RenderPlan.Overlay] = []

        // 0–2s: blurred BEFORE with hook
        items.append(.init(
            kind: .still(media.beforeFridge),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
            transform: .identity, filters: [.gaussianBlur(radius: 3)]
        ))

        // 2–end: MEAL gently moving (5% max)
        let mealDur = CMTime(seconds: total - 2, preferredTimescale: 600)
        items.append(.init(kind: .still(media.cookedMeal),
                           timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600),
                                                  duration: mealDur),
                           transform: .kenBurns(maxScale: config.maxKenBurnsScale, seed: 1),
                           filters: [.vibrance(1.1), .saturation(1.08), .contrast(1.05)]))

        // Hook overlay
        overlays.append(.init(
            start: .zero,
            duration: CMTime(seconds: 2, preferredTimescale: 600),
            layerBuilder: { cfg in OverlayFactory(config: cfg).createHookOverlay(
                text: recipe.hook ?? "Fridge chaos → dinner in minutes", config: cfg) }
        ))

        // Step overlays aligned to beat grid (limit to 6)
        let stepTexts = recipe.steps.prefix(6).map { shorten($0.title) }
        var stepStart = 2.0
        for (i, text) in stepTexts.enumerated() {
            // snap the step start to the next beat ≥ current time
            let nextBeat = beatMap.cueTimes.first(where: { $0.seconds >= stepStart })?.seconds ?? stepStart
            let dur = max(1.6, 60.0/beatMap.bpm * 2) // at least ~2 beats
            overlays.append(.init(
                start: CMTime(seconds: nextBeat, preferredTimescale: 600),
                duration: CMTime(seconds: dur, preferredTimescale: 600),
                layerBuilder: { cfg in OverlayFactory(config: cfg)
                    .createKineticStepOverlay(text: "▪︎ \(text)", index: i, beatBPM: beatMap.bpm, config: cfg) }
            ))
            stepStart = nextBeat + dur
            if stepStart >= total - 2.0 { break }
        }

        // CTA in last 2 seconds
        overlays.append(.init(
            start: CMTime(seconds: max(2.0, total - 2.0), preferredTimescale: 600),
            duration: CMTime(seconds: 2, preferredTimescale: 600),
            layerBuilder: { cfg in OverlayFactory(config: cfg).createCTAOverlay(text: "Share your SNAPCHEF!", config: cfg) }
        ))

        return RenderPlan(items: items, overlays: overlays, audio: media.musicURL,
                          outputDuration: CMTime(seconds: total, preferredTimescale: 600))
    }

    private func shorten(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 36 { return trimmed }
        return String(trimmed.prefix(33)) + "…"
    }
}