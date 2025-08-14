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

/// Memory management and optimization as specified in requirements
public final class MemoryOptimizer: @unchecked Sendable {
    
    public static let shared = MemoryOptimizer()
    
    // MARK: - Memory Monitoring
    // PREMIUM FIX: Added detailed logging to track memory during premium renders
    private let logger = Logger(subsystem: "com.snapchef.viral", category: "memory")
    private var memoryWarningObserver: NSObjectProtocol?
    private var isMonitoring = false
    
    // Fix: Thread-safe lock for pixelBufferPools dictionary access
    private let poolsLock = NSLock()
    
    // MARK: - Optimization Techniques (Requirements)
    
    // 1. Reuse CVPixelBuffer pools
    // PREMIUM FIX: Added pool reuse for per-frame premium effects like particles/zooms
    private var pixelBufferPools: [String: CVPixelBufferPool] = [:]
    
    // 2. Cache CIContext
    // PREMIUM FIX: Used Metal for thread-safe premium filter chaining
    private lazy var sharedCIContext: CIContext = {
        // Create proper color spaces for CIContext - use sRGB for consistency with photos
        let workingColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        
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
    
    /// Force memory cleanup when needed
    // PREMIUM FIX: Enhanced for premium phases (e.g., after particle generation)
    public func forceMemoryCleanup() {
        autoreleasepool {
            // Clear pixel buffer pools with thread-safe lock
            poolsLock.lock()
            pixelBufferPools.removeAll()
            poolsLock.unlock()
            
            // Force garbage collection
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
            
            logger.info("Forced memory cleanup completed")
        }
    }
    
    // MARK: - CIContext Management
    public func getCIContext() -> CIContext {
        return sharedCIContext
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
        for spec in filters {
            guard let filter = CIFilter(name: spec.name) else { continue }
            filter.setValue(processed, forKey: kCIInputImageKey)
            for (key, value) in spec.params {
                filter.setValue(value.value, forKey: key)
            }
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
        let usage = getCurrentMemoryUsage() / (1024 * 1024)
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
        
        // Emergency cleanup
        autoreleasepool {
            // Clear pixel buffer pools with thread-safe lock
            poolsLock.lock()
            let poolCount = pixelBufferPools.count
            pixelBufferPools.removeAll()
            poolsLock.unlock()
            
            // Force garbage collection
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
            
            logger.info("Emergency cleanup: cleared \(poolCount) pixel buffer pools")
        }
        
        // Post notification for other components to clean up
        NotificationCenter.default.post(
            name: Notification.Name("ViralVideoMemoryWarning"),
            object: nil
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
            
            // Clear any cached data in CIContext
            // Note: CIContext doesn't have a public clear method, but releasing it forces cleanup
            
            logger.info("All resources cleaned up")
        }
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