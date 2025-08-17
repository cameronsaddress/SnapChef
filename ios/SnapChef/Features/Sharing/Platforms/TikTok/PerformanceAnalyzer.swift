//
//  PerformanceAnalyzer.swift
//  SnapChef
//
//  Created on 12/01/2025
//  Advanced performance monitoring and analytics for viral video rendering
//

import Foundation
import AVFoundation
import UIKit
import os.log
import MetricKit

// MARK: - Performance Analyzer

/// Advanced performance monitoring with detailed metrics and analytics  
public final class PerformanceAnalyzer: NSObject, @unchecked Sendable {
    public static let shared = PerformanceAnalyzer()

    private let logger = Logger(subsystem: "com.snapchef.viral", category: "performance")
    private var sessionMetrics: SessionMetrics?
    private var renderingMetrics: [RenderingMetric] = []
    private let metricsQueue = DispatchQueue(label: "com.snapchef.viral.metrics", qos: .utility)

    // MetricKit subscriber for system-level metrics
    private var metricSubscriber: Any? // MXMetricSubscriber not available

    override private init() {
        super.init()
        setupMetricKit()
    }

    // MARK: - Session Tracking

    public func startSession() {
        // Use generic device info to avoid MainActor issues
        let deviceModel = "iOS Device"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        sessionMetrics = SessionMetrics(
            sessionId: UUID().uuidString,
            startTime: Date(),
            deviceModel: deviceModel,
            osVersion: osVersion,
            memoryCapacity: ProcessInfo.processInfo.physicalMemory
        )

        logger.info("Performance session started: \(self.sessionMetrics?.sessionId ?? "unknown")")
    }

    public func endSession() {
        guard let session = sessionMetrics else { return }

        session.endTime = Date()
        session.totalRenderingOperations = renderingMetrics.count

        logSessionSummary(session)

        // Reset for next session
        sessionMetrics = nil
        renderingMetrics.removeAll()
    }

    // MARK: - Rendering Metrics

    public func startRenderingMetric(
        template: ViralTemplate,
        config: RenderConfig
    ) -> String {
        let metricId = UUID().uuidString
        let metric = RenderingMetric(
            id: metricId,
            template: template,
            config: config,
            startTime: Date()
        )

        metricsQueue.async {
            self.renderingMetrics.append(metric)
        }

        logger.info("Started rendering metric: \(metricId) for template: \(template.rawValue)")
        return metricId
    }

    public func updateRenderingMetric(
        id: String,
        phase: RenderPhase,
        progress: Double,
        memoryUsage: UInt64
    ) {
        metricsQueue.async {
            guard let index = self.renderingMetrics.firstIndex(where: { $0.id == id }) else {
                return
            }

            let metric = self.renderingMetrics[index]
            metric.updatePhase(phase, progress: progress, memoryUsage: memoryUsage)

            // Check for performance violations
            Task { @MainActor in
                self.checkPerformanceViolations(metric)
            }
        }
    }

    public func completeRenderingMetric(
        id: String,
        success: Bool,
        outputFileSize: Int64? = nil,
        error: Error? = nil
    ) {
        metricsQueue.async {
            guard let index = self.renderingMetrics.firstIndex(where: { $0.id == id }) else {
                return
            }

            let metric = self.renderingMetrics[index]
            metric.complete(success: success, outputFileSize: outputFileSize, error: error)

            Task { @MainActor in
                self.logRenderingMetricSummary(metric)
            }

            // Update session metrics
            self.sessionMetrics?.updateWith(metric)
        }
    }

    // MARK: - Performance Analysis

    public func analyzePerformance() -> PerformanceReport {
        let completedMetrics = renderingMetrics.filter { $0.isCompleted }

        return PerformanceReport(
            sessionId: self.sessionMetrics?.sessionId ?? "unknown",
            totalOperations: completedMetrics.count,
            successRate: calculateSuccessRate(completedMetrics),
            averageRenderTime: calculateAverageRenderTime(completedMetrics),
            averageMemoryUsage: calculateAverageMemoryUsage(completedMetrics),
            averageFileSize: calculateAverageFileSize(completedMetrics),
            performanceViolations: getPerformanceViolations(completedMetrics),
            templatePerformance: analyzeTemplatePerformance(completedMetrics),
            recommendations: generateRecommendations(completedMetrics)
        )
    }

    // MARK: - Private Implementation

    private func setupMetricKit() {
        if #available(iOS 13.0, *) {
            let subscriber = MetricKitSubscriber()
            metricSubscriber = subscriber
            MXMetricManager.shared.add(subscriber)
        }
    }

    private func checkPerformanceViolations(_ metric: RenderingMetric) {
        let currentTime = Date().timeIntervalSince(metric.startTime)

        // Check render time violation
        if currentTime > ExportSettings.maxRenderTime {
            let violation = PerformanceViolation(
                type: .renderTimeExceeded,
                metric: metric.id,
                value: currentTime,
                threshold: ExportSettings.maxRenderTime,
                timestamp: Date()
            )

            metric.violations.append(violation)
            logger.warning("Render time violation: \(currentTime)s > \(ExportSettings.maxRenderTime)s")
        }

        // Check memory violation
        if let memoryUsage = metric.phaseMetrics.last?.memoryUsage,
           memoryUsage > ExportSettings.maxMemoryUsage {
            let violation = PerformanceViolation(
                type: .memoryLimitExceeded,
                metric: metric.id,
                value: Double(memoryUsage),
                threshold: Double(ExportSettings.maxMemoryUsage),
                timestamp: Date()
            )

            metric.violations.append(violation)
            logger.warning("Memory violation: \(memoryUsage) bytes > \(ExportSettings.maxMemoryUsage) bytes")
        }
    }

    private func logSessionSummary(_ session: SessionMetrics) {
        let duration = session.endTime?.timeIntervalSince(session.startTime) ?? 0

        logger.info("""
        📊 Session Summary:
           ID: \(session.sessionId)
           Duration: \(String(format: "%.2f", duration))s
           Operations: \(session.totalRenderingOperations)
           Success Rate: \(String(format: "%.1f", session.successRate * 100))%
           Avg Render Time: \(String(format: "%.3f", session.averageRenderTime))s
           Avg Memory: \(String(format: "%.1f", session.averageMemoryUsage / 1_024 / 1_024))MB
        """)
    }

    private func logRenderingMetricSummary(_ metric: RenderingMetric) {
        let duration = metric.endTime?.timeIntervalSince(metric.startTime) ?? 0
        let maxMemory = metric.phaseMetrics.max(by: { $0.memoryUsage < $1.memoryUsage })?.memoryUsage ?? 0

        logger.info("""
        🎬 Rendering Complete:
           Template: \(metric.template.rawValue)
           Duration: \(String(format: "%.3f", duration))s
           Success: \(metric.success)
           Max Memory: \(String(format: "%.1f", Double(maxMemory) / 1_024 / 1_024))MB
           File Size: \(metric.outputFileSize.map { String(format: "%.1f", Double($0) / 1_024 / 1_024) + "MB" } ?? "N/A")
           Violations: \(metric.violations.count)
        """)
    }

    // MARK: - Analytics Calculations

    private func calculateSuccessRate(_ metrics: [RenderingMetric]) -> Double {
        guard !metrics.isEmpty else { return 0 }
        let successCount = metrics.filter { $0.success }.count
        return Double(successCount) / Double(metrics.count)
    }

    private func calculateAverageRenderTime(_ metrics: [RenderingMetric]) -> TimeInterval {
        guard !metrics.isEmpty else { return 0 }
        let totalTime = metrics.compactMap { metric in
            metric.endTime?.timeIntervalSince(metric.startTime)
        }.reduce(0, +)
        return totalTime / Double(metrics.count)
    }

    private func calculateAverageMemoryUsage(_ metrics: [RenderingMetric]) -> Double {
        guard !metrics.isEmpty else { return 0 }
        let totalMemory = metrics.compactMap { metric in
            metric.phaseMetrics.max(by: { $0.memoryUsage < $1.memoryUsage })?.memoryUsage
        }.reduce(0, +)
        return Double(totalMemory) / Double(metrics.count)
    }

    private func calculateAverageFileSize(_ metrics: [RenderingMetric]) -> Double {
        let fileSizes = metrics.compactMap { $0.outputFileSize }
        guard !fileSizes.isEmpty else { return 0 }
        return Double(fileSizes.reduce(0, +)) / Double(fileSizes.count)
    }

    private func getPerformanceViolations(_ metrics: [RenderingMetric]) -> [PerformanceViolation] {
        return metrics.flatMap { $0.violations }
    }

    private func analyzeTemplatePerformance(_ metrics: [RenderingMetric]) -> [TemplatePerformance] {
        let groupedMetrics = Dictionary(grouping: metrics) { $0.template }

        return groupedMetrics.map { template, templateMetrics in
            TemplatePerformance(
                template: template,
                operationCount: templateMetrics.count,
                successRate: calculateSuccessRate(templateMetrics),
                averageRenderTime: calculateAverageRenderTime(templateMetrics),
                averageMemoryUsage: calculateAverageMemoryUsage(templateMetrics),
                averageFileSize: calculateAverageFileSize(templateMetrics)
            )
        }
    }

    private func generateRecommendations(_ metrics: [RenderingMetric]) -> [String] {
        var recommendations: [String] = []

        // Check overall success rate
        let successRate = calculateSuccessRate(metrics)
        if successRate < 0.95 {
            recommendations.append("Success rate (\(String(format: "%.1f", successRate * 100))%) is below target (95%). Consider implementing error recovery improvements.")
        }

        // Check render times
        let avgRenderTime = calculateAverageRenderTime(metrics)
        if avgRenderTime > ExportSettings.maxRenderTime {
            recommendations.append("Average render time (\(String(format: "%.3f", avgRenderTime))s) exceeds target (\(ExportSettings.maxRenderTime)s). Consider optimizing rendering pipeline.")
        }

        // Check memory usage
        let avgMemory = calculateAverageMemoryUsage(metrics)
        if avgMemory > Double(ExportSettings.maxMemoryUsage) * 0.8 {
            recommendations.append("Memory usage (\(String(format: "%.1f", avgMemory / 1_024 / 1_024))MB) is approaching limit. Consider memory optimization.")
        }

        // Check file sizes
        let avgFileSize = calculateAverageFileSize(metrics)
        if avgFileSize > Double(ExportSettings.targetFileSize) {
            recommendations.append("Average file size (\(String(format: "%.1f", avgFileSize / 1_024 / 1_024))MB) exceeds target. Consider compression optimization.")
        }

        return recommendations
    }
}

// MARK: - Data Models

public final class SessionMetrics: @unchecked Sendable {
    let sessionId: String
    let startTime: Date
    let deviceModel: String
    let osVersion: String
    let memoryCapacity: UInt64

    var endTime: Date?
    var totalRenderingOperations: Int = 0
    var successRate: Double = 0
    var averageRenderTime: TimeInterval = 0
    var averageMemoryUsage: Double = 0

    init(sessionId: String, startTime: Date, deviceModel: String, osVersion: String, memoryCapacity: UInt64) {
        self.sessionId = sessionId
        self.startTime = startTime
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.memoryCapacity = memoryCapacity
    }

    func updateWith(_ metric: RenderingMetric) {
        // Update aggregated metrics
        // This would be implemented with proper averaging logic
    }
}

public final class RenderingMetric: @unchecked Sendable {
    let id: String
    let template: ViralTemplate
    let config: RenderConfig
    let startTime: Date

    var endTime: Date?
    var success: Bool = false
    var outputFileSize: Int64?
    var error: Error?
    var phaseMetrics: [PhaseMetric] = []
    var violations: [PerformanceViolation] = []

    var isCompleted: Bool {
        return endTime != nil
    }

    init(id: String, template: ViralTemplate, config: RenderConfig, startTime: Date) {
        self.id = id
        self.template = template
        self.config = config
        self.startTime = startTime
    }

    func updatePhase(_ phase: RenderPhase, progress: Double, memoryUsage: UInt64) {
        let phaseMetric = PhaseMetric(
            phase: phase,
            progress: progress,
            memoryUsage: memoryUsage,
            timestamp: Date()
        )
        phaseMetrics.append(phaseMetric)
    }

    func complete(success: Bool, outputFileSize: Int64?, error: Error?) {
        self.endTime = Date()
        self.success = success
        self.outputFileSize = outputFileSize
        self.error = error
    }
}

public struct PhaseMetric {
    let phase: RenderPhase
    let progress: Double
    let memoryUsage: UInt64
    let timestamp: Date
}

public struct PerformanceViolation {
    let type: ViolationType
    let metric: String
    let value: Double
    let threshold: Double
    let timestamp: Date

    enum ViolationType {
        case renderTimeExceeded
        case memoryLimitExceeded
        case fileSizeExceeded
    }
}

public struct PerformanceReport {
    let sessionId: String
    let totalOperations: Int
    let successRate: Double
    let averageRenderTime: TimeInterval
    let averageMemoryUsage: Double
    let averageFileSize: Double
    let performanceViolations: [PerformanceViolation]
    let templatePerformance: [TemplatePerformance]
    let recommendations: [String]
}

public struct TemplatePerformance {
    let template: ViralTemplate
    let operationCount: Int
    let successRate: Double
    let averageRenderTime: TimeInterval
    let averageMemoryUsage: Double
    let averageFileSize: Double
}

// MARK: - MetricKit Subscriber

@available(iOS 13.0, *)
private class MetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            if let cpuMetrics = payload.cpuMetrics {
                // Log CPU usage data
                Logger(subsystem: "com.snapchef.viral", category: "system").info(
                    "CPU Metrics - Cumulative Time: \(cpuMetrics.cumulativeCPUTime)"
                )
            }

            if let memoryMetrics = payload.memoryMetrics {
                // Log memory usage data
                Logger(subsystem: "com.snapchef.viral", category: "system").info(
                    "Memory Metrics - Peak Physical: \(memoryMetrics.peakMemoryUsage)"
                )
            }
        }
    }
}
