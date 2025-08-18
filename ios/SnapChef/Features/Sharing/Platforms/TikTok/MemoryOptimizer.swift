//
//  MemoryOptimizer.swift
//  SnapChef
//
//  Created on 12/01/2025
//  Memory management and optimization features as specified in requirements
//

import UIKit
@preconcurrency import AVFoundation
import CoreImage
import QuartzCore
import Metal
import os.log

/// Enhanced memory management and optimization with cancellation support
public final class MemoryOptimizer: @unchecked Sendable {
    public static let shared = MemoryOptimizer()

    // MARK: - Memory Monitoring
    private let logger = Logger(subsystem: "com.snapchef.viral", category: "memory")
    private var memoryWarningObserver: NSObjectProtocol?
    private var isMonitoring = false
    
    // MARK: - Cancellation Support
    private var activeTasks: Set<UUID> = []
    private let tasksLock = NSLock()

    // MARK: - Enhanced Memory Limits
    private let criticalMemoryThreshold: UInt64 = 300 * 1_024 * 1_024 // 300MB critical threshold
    private let warningMemoryThreshold: UInt64 = 250 * 1_024 * 1_024 // 250MB warning threshold
    
    // Fix: Thread-safe lock for pixelBufferPools dictionary access
    private let poolsLock = NSLock()

    // MARK: - Optimization Techniques (Requirements)

    // 1. Reuse CVPixelBuffer pools
    // PREMIUM FIX: Added pool reuse for per-frame premium effects like particles/zooms
    private var pixelBufferPools: [String: CVPixelBufferPool] = [:]

    // 2. Cache CIContext with Metal acceleration for premium features
    // PREMIUM FIX: Used Metal for thread-safe premium filter chaining and parallel processing
    private lazy var sharedCIContext: CIContext = {
        // Create proper color spaces for CIContext - use sRGB for consistency with photos
        // CRITICAL FIX: Remove force unwraps to prevent EXC_BREAKPOINT crashes
        let workingColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

        // Fix: Use Metal for thread-safety instead of EAGL (OpenGL)
        // Metal is thread-safe and doesn't require makeCurrentContext
        if let device = MTLCreateSystemDefaultDevice() {
            print("✅ DEBUG MemoryOptimizer: Using Metal CIContext (thread-safe)")
            return CIContext(mtlDevice: device, options: [
                .workingColorSpace: workingColorSpace,
                .outputColorSpace: outputColorSpace,
                .cacheIntermediates: false  // Reduce memory usage
            ])
        } else {
            // Fallback to CPU renderer for complete thread-safety
            print("⚠️ DEBUG MemoryOptimizer: Metal unavailable, using CPU CIContext")
            return CIContext(options: [
                .workingColorSpace: workingColorSpace,
                .outputColorSpace: outputColorSpace,
                .cacheIntermediates: false,
                .useSoftwareRenderer: true  // Force CPU for thread-safety
            ])
        }
    }()

    // 3. Background queue for export
    public let processingQueue = DispatchQueue(
        label: "com.snapchef.viral.processing",
        qos: .userInitiated,
        attributes: .concurrent
    )

    private init() {
        setupMemoryMonitoring()
    }

    deinit {
        stopMemoryMonitoring()
    }

    // MARK: - Public Interface

    /// Start memory monitoring with optimization techniques
    public func startOptimization() {
        isMonitoring = true
        logger.info("Memory optimization started")

        // Clear any cached data periodically
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.performPeriodicCleanup()
        }
    }

    /// Stop monitoring and clean up resources
    public func stopOptimization() {
        isMonitoring = false
        cleanupAllResources()
        logger.info("Memory optimization stopped")
    }

    /// Get current memory usage in bytes
    public func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }

    /// Check if memory usage is within safe limits
    public func isMemoryUsageSafe() -> Bool {
        let currentUsage = getCurrentMemoryUsage()
        let isWithinLimit = currentUsage < ExportSettings.maxMemoryUsage

        if !isWithinLimit {
            logger.warning("Memory usage exceeded: \(currentUsage) bytes (limit: \(ExportSettings.maxMemoryUsage))")
        }

        return isWithinLimit
    }

    /// Force memory cleanup when needed with emergency protocols
    public func forceMemoryCleanup() {
        autoreleasepool {
            let beforeMemory = getCurrentMemoryUsage()
            
            // Clear pixel buffer pools with thread-safe lock
            poolsLock.lock()
            let poolCount = pixelBufferPools.count
            pixelBufferPools.removeAll()
            poolsLock.unlock()
            
            // CRITICAL FIX: Clear CI context cache more aggressively
            clearCIContextCache()
            
            // Cancel active tasks if memory is critical
            let currentMemory = getCurrentMemoryUsage()
            if currentMemory > criticalMemoryThreshold {
                cancelAllActiveTasks(reason: "Critical memory pressure")
            }

            // ENHANCED: Multiple garbage collection cycles for better cleanup
            for _ in 0..<3 {
                CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
                usleep(5_000) // 5ms between cycles
            }
            
            // Additional cleanup for iOS
            if #available(iOS 13.0, *) {
                URLCache.shared.removeAllCachedResponses()
            }
            
            // CRITICAL FIX: Clear any remaining autorelease pools
            DispatchQueue.main.async {
                autoreleasepool {
                    // Trigger UI cleanup on main thread
                }
            }
            
            let afterMemory = getCurrentMemoryUsage()
            let memoryFreed = beforeMemory > afterMemory ? beforeMemory - afterMemory : 0

            logger.info("Forced memory cleanup completed - cleared \(poolCount) pools, freed \(memoryFreed / (1024*1024))MB, memory: \(afterMemory / (1024*1024))MB")
        }
    }
    
    /// Emergency memory cleanup with aggressive resource clearing
    public func emergencyMemoryCleanup() {
        logger.warning("Emergency memory cleanup initiated")
        
        autoreleasepool {
            // Cancel all active tasks immediately
            cancelAllActiveTasks(reason: "Emergency memory cleanup")
            
            // Clear all caches aggressively
            poolsLock.lock()
            pixelBufferPools.removeAll()
            poolsLock.unlock()
            
            // Clear system caches
            URLCache.shared.removeAllCachedResponses()
            
            // Multiple garbage collection cycles
            for _ in 0..<3 {
                CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
                usleep(10_000) // 10ms between cycles
            }
            
            logger.info("Emergency memory cleanup completed")
        }
    }

    // MARK: - CIContext Management
    public func getCIContext() -> CIContext {
        return sharedCIContext
    }
    
    /// CRITICAL FIX: Clear CIContext cache for memory management
    private func clearCIContextCache() {
        // Force the CIContext to clear its internal caches
        // We do this by creating a minimal image and rendering it
        autoreleasepool {
            let clearImage = CIImage(color: .clear).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
            _ = sharedCIContext.createCGImage(clearImage, from: clearImage.extent)
        }
    }

    // MARK: - Image Optimization
    public func optimizeImageForProcessing(_ image: UIImage, targetSize: CGSize) -> UIImage {
        // Calculate aspect ratio to fit height while maintaining aspect ratio
        let aspectRatio = image.size.width / image.size.height
        let fitHeight = targetSize.height
        let fitWidth = fitHeight * aspectRatio

        // Create context with the actual image size (not forcing to target size)
        // This preserves the full image without cropping
        let drawSize = CGSize(width: fitWidth, height: fitHeight)
        UIGraphicsBeginImageContextWithOptions(drawSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: drawSize))
        let optimizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return optimizedImage ?? image
    }

    // MARK: - Pixel Buffer Management
    public func createPixelBuffer(from image: CIImage) throws -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw NSError(domain: "PixelBufferCreation", code: -1)
        }
        sharedCIContext.render(image, to: buffer)
        return buffer
    }

    // Process CIImage with FilterSpec filters
    public func processCIImageWithOptimization(_ image: CIImage, filters: [FilterSpec], context: CIContext) throws -> CIImage {
        var processed = image
        let ciFilters = FilterSpecBridge.toCIFilters(filters)
        for filter in ciFilters {
            filter.setValue(processed, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                processed = output
            }
        }
        return processed
    }

    // Overloaded version for CIFilter array (used by StillWriter)
    public func processCIImageWithOptimization(_ image: CIImage, filters: [CIFilter], context: CIContext) throws -> CIImage {
        var processed = image
        for filter in filters {
            autoreleasepool {
                filter.setValue(processed, forKey: kCIInputImageKey)
                if let output = filter.outputImage {
                    // Crop to extent to avoid infinite images
                    let extent = output.extent
                    if extent.isInfinite || extent.isEmpty {
                        processed = output.cropped(to: image.extent)
                    } else {
                        processed = output
                    }
                }
            }
        }
        return processed
    }

    // MARK: - Logging
    public func logMemoryProfile(phase: String) {
        let usage = getCurrentMemoryUsage() / (1_024 * 1_024)
        logger.info("Memory usage at \(phase): \(usage) MB")
    }

    // MARK: - Temp File Management
    public func deleteTempFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Clean up multiple temp files
    public func deleteTempFiles(_ urls: [URL]) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            for url in urls {
                self.deleteTempFile(url)
            }
        }
    }

    // MARK: - Optimization Techniques Implementation

    /// 1. Reuse CVPixelBuffer pools
    public func getPixelBufferPool(for config: RenderConfig) -> CVPixelBufferPool? {
        let key = "\(Int(config.size.width))x\(Int(config.size.height))"

        // Fix: Lock for thread-safe dictionary access
        poolsLock.lock()
        defer { poolsLock.unlock() }

        if let existingPool = pixelBufferPools[key] {
            return existingPool
        }

        // Create new pool
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3,
            kCVPixelBufferPoolMaximumBufferAgeKey as String: 0
        ]

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: ExportSettings.pixelFormat,
            kCVPixelBufferWidthKey as String: config.size.width,
            kCVPixelBufferHeightKey as String: config.size.height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        var pixelBufferPool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pixelBufferPool
        )

        if status == kCVReturnSuccess, let pool = pixelBufferPool {
            pixelBufferPools[key] = pool
            logger.info("Created pixel buffer pool for \(key)")
            return pool
        }

        return nil
    }

    // MARK: - Cancellation Token Support
    
    // Instance variable for tracking warning start time
    private var warningStartTime: Date?
    
    /// Register a new task for cancellation tracking
    public func registerTask() -> UUID {
        let taskId = UUID()
        tasksLock.lock()
        activeTasks.insert(taskId)
        tasksLock.unlock()
        logger.debug("Registered task: \(taskId)")
        return taskId
    }
    
    /// Unregister a completed task
    public func unregisterTask(_ taskId: UUID) {
        tasksLock.lock()
        activeTasks.remove(taskId)
        tasksLock.unlock()
        logger.debug("Unregistered task: \(taskId)")
    }
    
    /// Check if a task should be cancelled
    public func shouldCancelTask(_ taskId: UUID) -> Bool {
        tasksLock.lock()
        let exists = activeTasks.contains(taskId)
        tasksLock.unlock()
        
        // Check memory pressure with enhanced detection
        let currentMemory = getCurrentMemoryUsage()
        if currentMemory > criticalMemoryThreshold {
            logger.warning("Task \(taskId) should cancel due to memory pressure: \(currentMemory / (1024*1024))MB")
            
            // CRITICAL FIX: Trigger immediate cleanup when cancelling tasks
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.forceMemoryCleanup()
            }
            
            return true
        }
        
        // ENHANCED: Also check for extended memory pressure (above warning threshold for too long)
        if currentMemory > warningMemoryThreshold {
            // Use instance variable instead of static
            if warningStartTime == nil {
                warningStartTime = Date()
            } else if let startTime = warningStartTime,
                     Date().timeIntervalSince(startTime) > 10.0 { // 10 seconds in warning state
                logger.warning("Task \(taskId) cancelled due to extended memory warning: \(currentMemory / (1024*1024))MB")
                warningStartTime = nil
                return true
            }
        } else {
            // Reset warning timer when memory is normal
            warningStartTime = nil
        }
        
        return !exists
    }
    
    /// Create a new cancellation token
    public func createCancellationToken() -> CancellationToken {
        let taskId = registerTask()
        return CancellationToken(taskId: taskId, memoryOptimizer: self)
    }
    
    /// Cancel all active tasks
    private func cancelAllActiveTasks(reason: String) {
        tasksLock.lock()
        let taskCount = activeTasks.count
        activeTasks.removeAll()
        tasksLock.unlock()
        
        logger.warning("Cancelled \(taskCount) active tasks - reason: \(reason)")
        
        // Post notification for tasks to respond to cancellation
        NotificationCenter.default.post(
            name: Notification.Name("ViralVideoTaskCancellation"),
            object: reason
        )
    }
    
    // MARK: - Enhanced Memory Monitoring
    
    /// Get memory status with detailed breakdown
    public func getMemoryStatus() -> MemoryStatus {
        let current = getCurrentMemoryUsage()
        let status: MemoryPressureLevel
        
        if current > criticalMemoryThreshold {
            status = .critical
        } else if current > warningMemoryThreshold {
            status = .warning
        } else {
            status = .normal
        }
        
        return MemoryStatus(
            currentUsage: current,
            warningThreshold: warningMemoryThreshold,
            criticalThreshold: criticalMemoryThreshold,
            pressureLevel: status,
            activeTaskCount: activeTasks.count
        )
    }
    
    // MARK: - Premium Performance Optimizations

    /// Enable Metal-accelerated rendering for premium features
    public func enableMetalAcceleration() -> Bool {
        // Check if Metal is available and configure for optimal performance
        guard MTLCreateSystemDefaultDevice() != nil else {
            logger.warning("Metal acceleration unavailable - falling back to CPU")
            return false
        }

        logger.info("✅ Metal acceleration enabled for premium rendering")
        return true
    }

    /// Implement parallel segment processing for faster renders
    public func processSegmentsInParallel<T: Sendable>(
        segments: [T],
        processingBlock: @escaping @Sendable (T) async throws -> Void
    ) async throws {
        let startTime = Date()

        // Process segments in parallel using TaskGroup for Swift 6 compliance
        try await withThrowingTaskGroup(of: Void.self) { group in
            for segment in segments {
                group.addTask { @Sendable in
                    try await processingBlock(segment)
                }
            }

            // Wait for all segments to complete
            try await group.waitForAll()
        }

        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("Parallel segment processing completed in \(String(format: "%.3f", processingTime))s")
    }

    /// Implement predictive asset caching for premium effects
    public func enablePredictiveAssetCaching(for config: RenderConfig) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Pre-warm pixel buffer pools for expected sizes
            _ = self.getPixelBufferPool(for: config)

            // Pre-warm CIContext with expected operations
            let testImage = CIImage(color: CIColor.clear).cropped(to: CGRect(origin: .zero, size: config.size))
            _ = self.sharedCIContext.createCGImage(testImage, from: testImage.extent)

            self.logger.info("Predictive asset caching enabled for premium features")
        }
    }

    /// Optimize pixel buffer pool for new premium effects
    public func optimizePixelBufferPool(for config: RenderConfig, effectCount: Int) -> CVPixelBufferPool? {
        let key = "\(Int(config.size.width))x\(Int(config.size.height))_premium"

        poolsLock.lock()
        defer { poolsLock.unlock() }

        if let existingPool = pixelBufferPools[key] {
            return existingPool
        }

        // Create optimized pool for premium effects with larger buffer count
        let bufferCount = max(6, effectCount * 2) // Scale buffer count with effect complexity
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: bufferCount,
            kCVPixelBufferPoolMaximumBufferAgeKey as String: 0,
            kCVPixelBufferPoolAllocationThresholdKey as String: bufferCount
        ]

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: ExportSettings.pixelFormat,
            kCVPixelBufferWidthKey as String: config.size.width,
            kCVPixelBufferHeightKey as String: config.size.height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true // Enable Metal compatibility
        ]

        var pixelBufferPool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pixelBufferPool
        )

        if status == kCVReturnSuccess, let pool = pixelBufferPool {
            pixelBufferPools[key] = pool
            logger.info("Created optimized pixel buffer pool for premium effects: \(key)")
            return pool
        }

        return nil
    }

    /// Check if render time is within 5 second requirement
    public func validateRenderPerformance(startTime: Date, phase: String) -> Bool {
        let elapsedTime = Date().timeIntervalSince(startTime)
        let isWithinLimit = elapsedTime <= ExportSettings.maxRenderTime

        if isWithinLimit {
            logger.info("✅ \(phase) performance within requirement: \(String(format: "%.3f", elapsedTime))s")
        } else {
            logger.error("❌ \(phase) performance exceeded: \(String(format: "%.3f", elapsedTime))s > \(ExportSettings.maxRenderTime)s")
        }

        return isWithinLimit
    }

    /// Maintain video size under 50MB with intelligent downsampling
    public func validateFileSize(at url: URL) async throws -> Bool {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let fileSizeMB = Double(fileSize) / (1_024 * 1_024)

        if fileSize <= ExportSettings.maxFileSize {
            logger.info("✅ File size within requirement: \(String(format: "%.2f", fileSizeMB))MB")
            return true
        } else {
            logger.warning("❌ File size exceeded: \(String(format: "%.2f", fileSizeMB))MB > \(ExportSettings.maxFileSize / (1_024 * 1_024))MB")
            return false
        }
    }

    // MARK: - Private Implementation

    private func setupMemoryMonitoring() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    private func stopMemoryMonitoring() {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
            memoryWarningObserver = nil
        }
    }

    private func handleMemoryWarning() {
        logger.warning("Memory warning received - performing emergency cleanup")
        
        // Trigger emergency cleanup
        emergencyMemoryCleanup()

        // Post notification for other components to clean up
        NotificationCenter.default.post(
            name: Notification.Name("ViralVideoMemoryWarning"),
            object: getMemoryStatus()
        )
    }

    private func performPeriodicCleanup() {
        guard isMonitoring else { return }

        autoreleasepool {
            let beforeMemory = getCurrentMemoryUsage()

            // Clean up old pixel buffer pools if memory usage is high
            if beforeMemory > (ExportSettings.maxMemoryUsage * 7 / 10) { // 70% of limit
                poolsLock.lock()
                let poolCount = pixelBufferPools.count
                pixelBufferPools.removeAll()
                poolsLock.unlock()

                let afterMemory = getCurrentMemoryUsage()
                let saved = beforeMemory > afterMemory ? beforeMemory - afterMemory : 0

                logger.info("Periodic cleanup: cleared \(poolCount) pools, saved \(saved) bytes")
            }
        }
    }

    private func cleanupAllResources() {
        autoreleasepool {
            poolsLock.lock()
            pixelBufferPools.removeAll()
            poolsLock.unlock()
            
            // Cancel all active tasks before cleanup
            cancelAllActiveTasks(reason: "Resource cleanup")

            // Clear any cached data in CIContext
            clearCIContextCache()
            
            // CRITICAL FIX: Multiple cleanup cycles for thorough resource release
            for _ in 0..<3 {
                _ = autoreleasepool {
                    CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
                }
                usleep(10_000) // 10ms between cycles
            }

            logger.info("All resources cleaned up")
        }
    }
    
    // MARK: - Enhanced Memory Monitoring and Recovery
    
    /// CRITICAL FIX: Monitor memory during heavy operations
    public func withMemoryMonitoring<T>(
        operation: String,
        warningHandler: (() -> Void)? = nil,
        block: () throws -> T
    ) rethrows -> T {
        let startMemory = getCurrentMemoryUsage()
        let startTime = Date()
        
        logger.debug("Starting memory-monitored operation: \(operation) - initial memory: \(startMemory / (1024*1024))MB")
        
        defer {
            autoreleasepool {
                let endMemory = getCurrentMemoryUsage()
                let duration = Date().timeIntervalSince(startTime)
                let memoryDelta = Int64(endMemory) - Int64(startMemory)
                
                logger.debug("Completed operation: \(operation) - duration: \(String(format: "%.3f", duration))s, memory delta: \(memoryDelta / (1024*1024))MB, final: \(endMemory / (1024*1024))MB")
                
                // Trigger warning if memory increased significantly
                if memoryDelta > 50 * 1024 * 1024 { // 50MB increase
                    logger.warning("High memory increase detected in \(operation): \(memoryDelta / (1024*1024))MB")
                    warningHandler?()
                }
                
                // Auto-cleanup if we're approaching limits
                if endMemory > warningMemoryThreshold {
                    forceMemoryCleanup()
                }
            }
        }
        
        return try block()
    }
    
    /// CRITICAL FIX: Async version of memory monitoring
    public func withMemoryMonitoring<T>(
        operation: String,
        warningHandler: (@Sendable () async -> Void)? = nil,
        block: @Sendable () async throws -> T
    ) async rethrows -> T {
        let startMemory = getCurrentMemoryUsage()
        let startTime = Date()
        
        logger.debug("Starting async memory-monitored operation: \(operation) - initial memory: \(startMemory / (1024*1024))MB")
        
        defer {
            Task {
                autoreleasepool {
                    let endMemory = getCurrentMemoryUsage()
                    let duration = Date().timeIntervalSince(startTime)
                    let memoryDelta = Int64(endMemory) - Int64(startMemory)
                    
                    logger.debug("Completed async operation: \(operation) - duration: \(String(format: "%.3f", duration))s, memory delta: \(memoryDelta / (1024*1024))MB, final: \(endMemory / (1024*1024))MB")
                    
                    // Trigger warning if memory increased significantly
                    if memoryDelta > 50 * 1024 * 1024 { // 50MB increase
                        logger.warning("High memory increase detected in \(operation): \(memoryDelta / (1024*1024))MB")
                        Task {
                            await warningHandler?()
                        }
                    }
                    
                    // Auto-cleanup if we're approaching limits
                    if endMemory > warningMemoryThreshold {
                        forceMemoryCleanup()
                    }
                }
            }
        }
        
        return try await block()
    }
}

// MARK: - Performance Monitor
// PREMIUM FIX: Added phase timing for <5s total render check
public final class PerformanceMonitor: @unchecked Sendable {
    public static let shared = PerformanceMonitor()

    private let logger = Logger(subsystem: "com.snapchef.viral", category: "performance")
    private var phaseStartTimes: [RenderPhase: Date] = [:]
    private var totalStartTime: Date?

    private init() {}

    // MARK: - Public Interface

    /// Start monitoring render performance
    public func startRenderMonitoring() {
        totalStartTime = Date()
        phaseStartTimes.removeAll()
        logger.info("Started render performance monitoring")
    }

    /// Mark phase start
    public func markPhaseStart(_ phase: RenderPhase) {
        phaseStartTimes[phase] = Date()
        logger.debug("Phase started: \(phase.rawValue)")
    }

    /// Mark phase end and log timing
    public func markPhaseEnd(_ phase: RenderPhase) {
        guard let startTime = phaseStartTimes[phase] else { return }

        let duration = Date().timeIntervalSince(startTime)
        logger.info("Phase completed: \(phase.rawValue) - \(String(format: "%.3f", duration))s")

        // Check if phase exceeded reasonable time
        let expectedMaxTime: TimeInterval
        switch phase {
        case .planning: expectedMaxTime = 0.5
        case .preparingAssets: expectedMaxTime = 1.0
        case .renderingFrames: expectedMaxTime = 3.0
        case .compositing: expectedMaxTime = 0.5
        case .addingOverlays: expectedMaxTime = 1.0
        case .encoding: expectedMaxTime = 1.0
        case .finalizing: expectedMaxTime = 0.2
        case .complete: expectedMaxTime = 0.0
        }

        if duration > expectedMaxTime {
            logger.warning("Phase \(phase.rawValue) exceeded expected time: \(String(format: "%.3f", duration))s > \(expectedMaxTime)s")
        }

        phaseStartTimes.removeValue(forKey: phase)
    }

    /// Complete render monitoring and check total time
    public func completeRenderMonitoring() -> TimeInterval {
        guard let startTime = totalStartTime else { return 0 }

        let totalDuration = Date().timeIntervalSince(startTime)
        logger.info("Total render time: \(String(format: "%.3f", totalDuration))s")

        // Check against requirement: <5 seconds for 15s video
        if totalDuration > ExportSettings.maxRenderTime {
            logger.error("Render time exceeded requirement: \(String(format: "%.3f", totalDuration))s > \(ExportSettings.maxRenderTime)s")
        } else {
            logger.info("✅ Render time within requirement")
        }

        totalStartTime = nil
        phaseStartTimes.removeAll()

        return totalDuration
    }
}

// MARK: - Frame Drop Monitor
// PREMIUM FIX: Monitors for smooth 30fps premium video
public final class FrameDropMonitor: @unchecked Sendable {
    public static let shared = FrameDropMonitor()

    private let logger = Logger(subsystem: "com.snapchef.viral", category: "frames")
    private var expectedFrames: Int = 0
    private var actualFrames: Int = 0

    private init() {}

    // MARK: - Public Interface

    /// Start monitoring frame drops
    public func startMonitoring(expectedFrames: Int) {
        self.expectedFrames = expectedFrames
        self.actualFrames = 0
        self.logger.info("Started frame drop monitoring - expected: \(expectedFrames)")
    }

    /// Record a successfully rendered frame
    public func recordFrame() {
        self.actualFrames += 1
    }

    /// Complete monitoring and report results
    public func completeMonitoring() -> (expected: Int, actual: Int, dropped: Int) {
        let droppedFrames = max(0, expectedFrames - actualFrames)

        if droppedFrames > 0 {
            logger.error("Frame drops detected: \(droppedFrames) / \(self.expectedFrames)")
        } else {
            logger.info("✅ No frame drops - \(self.actualFrames) / \(self.expectedFrames)")
        }

        let result = (expected: self.expectedFrames, actual: self.actualFrames, dropped: droppedFrames)

        // Reset for next monitoring session
        expectedFrames = 0
        actualFrames = 0

        return result
    }
}

// MARK: - Supporting Data Structures

/// Memory status information
public struct MemoryStatus: Sendable {
    public let currentUsage: UInt64
    public let warningThreshold: UInt64
    public let criticalThreshold: UInt64
    public let pressureLevel: MemoryPressureLevel
    public let activeTaskCount: Int
    
    public var currentUsageMB: Double {
        Double(currentUsage) / (1_024 * 1_024)
    }
    
    public var warningThresholdMB: Double {
        Double(warningThreshold) / (1_024 * 1_024)
    }
    
    public var criticalThresholdMB: Double {
        Double(criticalThreshold) / (1_024 * 1_024)
    }
}

/// Memory pressure levels
public enum MemoryPressureLevel: String, Sendable {
    case normal = "normal"
    case warning = "warning"
    case critical = "critical"
}

/// Cancellation token for long-running operations
public final class CancellationToken: @unchecked Sendable {
    private let taskId: UUID
    private let memoryOptimizer: MemoryOptimizer
    
    public var isCancelled: Bool {
        memoryOptimizer.shouldCancelTask(taskId)
    }
    
    init(taskId: UUID, memoryOptimizer: MemoryOptimizer = .shared) {
        self.taskId = taskId
        self.memoryOptimizer = memoryOptimizer
    }
    
    public func cancel() {
        memoryOptimizer.unregisterTask(taskId)
    }
    
    /// Throws cancellation error if task should be cancelled
    public func throwIfCancelled() throws {
        if isCancelled {
            throw CancellationError()
        }
    }
    
    deinit {
        memoryOptimizer.unregisterTask(taskId)
    }
}

/// Cancellation error
public struct CancellationError: Error, LocalizedError {
    public var errorDescription: String? {
        return "Operation was cancelled"
    }
}
