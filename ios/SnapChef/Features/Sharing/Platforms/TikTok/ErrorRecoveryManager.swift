//
//  ErrorRecoveryManager.swift
//  SnapChef
//
//  Created on 12/01/2025
//  Comprehensive error recovery mechanisms with retry logic and fallback strategies
//

import Foundation
import AVFoundation
import UIKit
import os.log

// MARK: - Error Recovery Manager

/// Comprehensive error recovery with retry logic and fallback strategies
public final class ErrorRecoveryManager: @unchecked Sendable {
    
    public static let shared = ErrorRecoveryManager()
    
    private let logger = Logger(subsystem: "com.snapchef.viral", category: "recovery")
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    // Track retry attempts per operation type
    private var retryAttempts: [String: Int] = [:]
    private let retryQueue = DispatchQueue(label: "com.snapchef.viral.retry", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Execute operation with retry logic and exponential backoff
    public func executeWithRetry<T>(
        operation: @escaping @Sendable () async throws -> T,
        operationId: String,
        fallbackStrategy: FallbackStrategy? = nil
    ) async throws -> T {
        
        let currentAttempts = retryAttempts[operationId] ?? 0
        
        do {
            let result = try await operation()
            
            // Reset retry count on success
            retryAttempts[operationId] = 0
            logger.info("Operation succeeded: \(operationId)")
            
            return result
            
        } catch {
            logger.warning("Operation failed: \(operationId), attempt \(currentAttempts + 1), error: \(error.localizedDescription)")
            
            // Check if we should retry
            if shouldRetry(error: error, attempts: currentAttempts) {
                retryAttempts[operationId] = currentAttempts + 1
                
                // Calculate exponential backoff delay
                let delay = calculateRetryDelay(attempt: currentAttempts)
                logger.info("Retrying operation: \(operationId) after \(delay)s delay")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                return try await executeWithRetry(
                    operation: operation,
                    operationId: operationId,
                    fallbackStrategy: fallbackStrategy
                )
            } else {
                // Max retries exceeded, try fallback strategy
                if let fallback = fallbackStrategy {
                    logger.info("Attempting fallback strategy for: \(operationId)")
                    return try await executeFallbackStrategy(fallback, originalError: error)
                } else {
                    // Reset retry count and throw error
                    retryAttempts[operationId] = 0
                    throw RecoveryError.maxRetriesExceeded(operationId, error)
                }
            }
        }
    }
    
    /// Handle specific rendering errors with contextual recovery
    public func handleRenderingError(
        _ error: Error,
        template: ViralTemplate,
        recipe: ViralRecipe,
        media: MediaBundle
    ) async throws -> RecoveryAction {
        
        logger.error("Handling rendering error: \(error.localizedDescription)")
        
        switch error {
        case ViralVideoError.memoryLimitExceeded:
            return await handleMemoryPressureError(template: template, recipe: recipe, media: media)
            
        case ViralVideoError.renderingFailed(let message):
            return await handleRenderingFailure(message: message, template: template)
            
        case ViralVideoError.exportFailed:
            return await handleExportFailure(template: template)
            
        case ViralVideoError.fileSizeExceeded:
            return await handleFileSizeError(template: template)
            
        case ViralVideoError.invalidDuration:
            return await handleDurationError(template: template)
            
        default:
            return await handleGenericError(error)
        }
    }
    
    // MARK: - Fallback Strategies
    
    public enum FallbackStrategy: Sendable {
        case reduceQuality
        case simplifyTemplate
        case useStaticImages
        case fallbackToBasicExport
        case skipOptionalFeatures
    }
    
    public enum RecoveryAction: Sendable {
        case retry
        case retryWithReducedQuality
        case retryWithSimplifiedTemplate
        case useAlternativeTemplate(ViralTemplate)
        case showErrorToUser(String)
        case cancelOperation
    }
    
    // MARK: - Private Implementation
    
    private func shouldRetry(error: Error, attempts: Int) -> Bool {
        // Don't retry if max attempts reached
        guard attempts < maxRetryAttempts else { return false }
        
        // Check error type for retry eligibility
        switch error {
        case ViralVideoError.memoryLimitExceeded:
            return attempts < 2 // Only retry memory errors twice
            
        case ViralVideoError.renderingCancelled:
            return false // Don't retry cancelled operations
            
        case ViralVideoError.invalidConfiguration:
            return false // Don't retry configuration errors
            
        case ViralVideoError.missingAssets:
            return false // Don't retry missing asset errors
            
        case let exportError as ExportError:
            switch exportError {
            case .renderTimeExceeded:
                return attempts < 1 // Only retry time exceeded once
            case .cannotCreateExportSession, .noVideoTrack, .invalidFrameRate:
                return false // Don't retry these errors
            default:
                return true
            }
            
        case let shareError as ShareError:
            switch shareError {
            case .photoAccessDenied, .tiktokNotInstalled:
                return false // Don't retry permission/installation errors
            default:
                return true
            }
            
        default:
            return true // Retry other errors
        }
    }
    
    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff: 1s, 2s, 4s
        return baseRetryDelay * pow(2.0, Double(attempt))
    }
    
    private func executeFallbackStrategy<T>(_ strategy: FallbackStrategy, originalError: Error) async throws -> T {
        switch strategy {
        case .reduceQuality:
            // This would be handled by the calling code
            throw RecoveryError.fallbackNotApplicable(strategy, originalError)
            
        case .simplifyTemplate:
            throw RecoveryError.fallbackNotApplicable(strategy, originalError)
            
        case .useStaticImages:
            throw RecoveryError.fallbackNotApplicable(strategy, originalError)
            
        case .fallbackToBasicExport:
            throw RecoveryError.fallbackNotApplicable(strategy, originalError)
            
        case .skipOptionalFeatures:
            throw RecoveryError.fallbackNotApplicable(strategy, originalError)
        }
    }
    
    // MARK: - Specific Error Handlers
    
    private func handleMemoryPressureError(
        template: ViralTemplate,
        recipe: ViralRecipe,
        media: MediaBundle
    ) async -> RecoveryAction {
        
        // Force memory cleanup
        MemoryOptimizer.shared.forceMemoryCleanup()
        
        // Check if memory is now safe
        if MemoryOptimizer.shared.isMemoryUsageSafe() {
            logger.info("Memory pressure resolved, suggesting retry")
            return .retry
        } else {
            logger.warning("Memory pressure persists, suggesting quality reduction")
            return .retryWithReducedQuality
        }
    }
    
    private func handleRenderingFailure(message: String, template: ViralTemplate) async -> RecoveryAction {
        logger.error("Rendering failure: \(message)")
        
        // Check if we can simplify the template
        if template == .kineticTextSteps || template == .greenScreenPIP {
            return .retryWithSimplifiedTemplate
        } else {
            // Try a simpler template
            return .useAlternativeTemplate(.beatSyncedCarousel)
        }
    }
    
    private func handleExportFailure(template: ViralTemplate) async -> RecoveryAction {
        logger.error("Export failure for template: \(template.rawValue)")
        
        // Try with reduced quality settings
        return .retryWithReducedQuality
    }
    
    private func handleFileSizeError(template: ViralTemplate) async -> RecoveryAction {
        logger.warning("File size exceeded for template: \(template.rawValue)")
        
        // Always retry with reduced quality for file size issues
        return .retryWithReducedQuality
    }
    
    private func handleDurationError(template: ViralTemplate) async -> RecoveryAction {
        logger.error("Duration error for template: \(template.rawValue)")
        
        // Try a template with different duration
        switch template {
        case .kineticTextSteps, .greenScreenPIP:
            return .useAlternativeTemplate(.splitScreenSwipe) // Shorter template
        default:
            return .retryWithSimplifiedTemplate
        }
    }
    
    private func handleGenericError(_ error: Error) async -> RecoveryAction {
        logger.error("Generic error: \(error.localizedDescription)")
        
        // For unknown errors, show to user
        return .showErrorToUser("An unexpected error occurred. Please try again.")
    }
    
    // MARK: - Recovery Utilities
    
    /// Reset retry attempts for a specific operation
    public func resetRetryAttempts(for operationId: String) {
        retryAttempts[operationId] = 0
    }
    
    /// Clear all retry attempt tracking
    public func clearAllRetryAttempts() {
        retryAttempts.removeAll()
    }
    
    /// Get current retry attempts for operation
    public func getRetryAttempts(for operationId: String) -> Int {
        return retryAttempts[operationId] ?? 0
    }
}

// MARK: - Recovery Error Types

public enum RecoveryError: LocalizedError {
    case maxRetriesExceeded(String, Error)
    case fallbackNotApplicable(ErrorRecoveryManager.FallbackStrategy, Error)
    case recoveryStrategyFailed(ErrorRecoveryManager.FallbackStrategy, Error)
    
    public var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded(let operationId, let originalError):
            return "Operation '\(operationId)' failed after maximum retry attempts: \(originalError.localizedDescription)"
        case .fallbackNotApplicable(let strategy, let originalError):
            return "Fallback strategy '\(strategy)' not applicable for error: \(originalError.localizedDescription)"
        case .recoveryStrategyFailed(let strategy, let originalError):
            return "Recovery strategy '\(strategy)' failed for error: \(originalError.localizedDescription)"
        }
    }
}

// MARK: - Quality Reducer

/// Utility to reduce quality settings for recovery scenarios
public struct QualityReducer {
    
    public static func createReducedQualityConfig(from config: RenderConfig) -> RenderConfig {
        var reducedConfig = config
        
        // Reduce resolution to 720p for memory savings
        reducedConfig.size = CGSize(width: 720, height: 1280)
        
        // Reduce frame rate slightly
        reducedConfig.fps = 24
        
        // Reduce font sizes
        reducedConfig.hookFontSize *= 0.9
        reducedConfig.stepsFontSize *= 0.9
        reducedConfig.countersFontSize *= 0.9
        reducedConfig.ctaFontSize *= 0.9
        reducedConfig.ingredientFontSize *= 0.9
        
        return reducedConfig
    }
    
    public static func createReducedQualityExportSettings() -> [String: Any] {
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 720,
            AVVideoHeightKey: 1280,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000, // Reduced from 10Mbps to 6Mbps
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel, // Use baseline instead of high
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCAVLC, // Use CAVLC instead of CABAC
                AVVideoExpectedSourceFrameRateKey: 24
            ]
        ]
    }
}

// MARK: - Template Simplifier

/// Utility to create simplified versions of templates for recovery
public struct TemplateSimplifier {
    
    public static func simplifyTemplate(_ template: ViralTemplate) -> ViralTemplate {
        switch template {
        case .kineticTextSteps:
            return .beatSyncedCarousel // Simpler template
        case .greenScreenPIP:
            return .splitScreenSwipe // Remove PIP complexity
        case .priceTimeChallenge:
            return .beatSyncedCarousel // Remove sticker animations
        default:
            return .beatSyncedCarousel // Fallback to simplest template
        }
    }
    
    public static func getAlternativeTemplate(for template: ViralTemplate) -> ViralTemplate {
        switch template {
        case .beatSyncedCarousel:
            return .splitScreenSwipe
        case .splitScreenSwipe:
            return .beatSyncedCarousel
        case .kineticTextSteps:
            return .priceTimeChallenge
        case .priceTimeChallenge:
            return .kineticTextSteps
        case .greenScreenPIP:
            return .beatSyncedCarousel
        case .test:
            return .beatSyncedCarousel  // Test template fallback
        }
    }
}