//
//  MemoryOptimizer.swift
//  SnapChef
//
//  Created on 12/01/2025
//  Memory management and optimization features as specified in requirements
//

import UIKit
import AVFoundation
import CoreImage
import QuartzCore
import Metal
import os.log

/// Memory management and optimization as specified in requirements
public final class MemoryOptimizer: @unchecked Sendable {
    
    public static let shared = MemoryOptimizer()
    
    // MARK: - Memory Monitoring
    
    private let logger = Logger(subsystem: "com.snapchef.viral", category: "memory")
    private var memoryWarningObserver: NSObjectProtocol?
    private var isMonitoring = false
    
    // Fix: Thread-safe lock for pixelBufferPools dictionary access
    private let poolsLock = NSLock()
    
    // MARK: - Optimization Techniques (Requirements)
    
    // 1. Reuse CVPixelBuffer pools
    private var pixelBufferPools: [String: CVPixelBufferPool] = [:]
    
    // 2. Cache CIContext
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
    
    /// 2. Get cached CIContext
    public func getCIContext() -> CIContext {
        // Debug: Log context type to verify it's not EAGL
        print("📝 DEBUG MemoryOptimizer: Context type: \(String(describing: type(of: sharedCIContext)))")
        return sharedCIContext
    }
    
    /// 4. Delete temp files immediately
    public func deleteTempFile(_ url: URL) {
        processingQueue.async {
            do {
                try FileManager.default.removeItem(at: url)
                self.logger.debug("Deleted temp file: \(url.lastPathComponent)")
            } catch {
                self.logger.error("Failed to delete temp file \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
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
    
    /// 5. Profile with Instruments (development helper)
    public func logMemoryProfile(phase: String) {
        let memoryUsage = getCurrentMemoryUsage()
        let memoryMB = Double(memoryUsage) / 1024.0 / 1024.0
        
        logger.info("Memory Profile [\(phase)]: \(String(format: "%.2f", memoryMB)) MB")
        
        // Log warning if approaching limit
        if memoryUsage > (ExportSettings.maxMemoryUsage * 8 / 10) { // 80% of limit
            logger.warning("Memory usage approaching limit: \(String(format: "%.2f", memoryMB)) MB")
        }
    }
    
    // MARK: - Memory Optimization Strategies
    
    /// Optimize image for processing - resize with aspect fill to prevent transparency
    public func optimizeImageForProcessing(_ image: UIImage, targetSize: CGSize) -> UIImage {
        // Fix: Force CGImage backing for CI-backed images to ensure drawing works on background
        print("📝 DEBUG MemoryOptimizer: Input has CGImage: \(image.cgImage != nil)")
        
        guard let cgImage = image.cgImage else {
            print("❌ DEBUG MemoryOptimizer: Input image has no CGImage - forcing CGImage creation")
            // Try to force CGImage creation for CI-backed images
            if let ciImage = image.ciImage {
                let context = getCIContext()
                let extent = ciImage.extent
                if let generatedCGImage = context.createCGImage(ciImage, from: extent) {
                    print("✅ DEBUG MemoryOptimizer: Successfully created CGImage from CIImage")
                    let uiImageWithCG = UIImage(cgImage: generatedCGImage, scale: image.scale, orientation: image.imageOrientation)
                    return optimizeImageForProcessing(uiImageWithCG, targetSize: targetSize)
                }
            }
            print("❌ DEBUG MemoryOptimizer: Cannot create CGImage - returning original")
            return image
        }
        
        // Create UIImage with guaranteed CGImage backing
        let uiImageWithCG = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        
        // Fix: Use thread-safe UIGraphicsImageRenderer for background queue compatibility
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true  // Ensure no transparency
        format.scale = 1.0    // Use 1.0 scale for consistent size
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        let optimizedImage = renderer.image { context in
            // Debug: Confirm renderer context is working
            print("📝 DEBUG MemoryOptimizer: Renderer context created successfully")
            
            // Fill with black background to ensure no transparent areas
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            
            // Calculate aspect fill to cover entire area (clip edges if needed)
            let aspectRatio = image.size.width / image.size.height
            let targetRatio = targetSize.width / targetSize.height
            
            var drawRect: CGRect
            if aspectRatio > targetRatio {
                // Image is wider - fit height, clip width
                let drawWidth = targetSize.height * aspectRatio
                drawRect = CGRect(x: (targetSize.width - drawWidth) / 2, y: 0,
                                width: drawWidth, height: targetSize.height)
            } else {
                // Image is taller - fit width, clip height
                let drawHeight = targetSize.width / aspectRatio
                drawRect = CGRect(x: 0, y: (targetSize.height - drawHeight) / 2,
                                width: targetSize.width, height: drawHeight)
            }
            
            // Draw image with aspect fill using CG-backed version (will clip edges if needed)
            uiImageWithCG.draw(in: drawRect)
            
            // Premium: Add subtle vignette for beatSyncedCarousel (edge darkening effect)
            // Simple gradient vignette using Core Graphics for thread safety
            let vignetteLayer = CAGradientLayer()
            vignetteLayer.frame = CGRect(origin: .zero, size: targetSize)
            vignetteLayer.colors = [
                UIColor.black.withAlphaComponent(0.0).cgColor,
                UIColor.black.withAlphaComponent(0.3).cgColor
            ]
            vignetteLayer.locations = [0.7, 1.0]
            vignetteLayer.type = .radial
            vignetteLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            vignetteLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
            
            // Render vignette gradient onto the image
            vignetteLayer.render(in: context.cgContext)
        }
        
        // Debug: Log the optimized image size
        print("📝 DEBUG MemoryOptimizer: Optimized image from \(image.size) to \(optimizedImage.size)")
        
        return optimizedImage
    }
    
    /// Process CIImage with memory optimization
    public func processCIImageWithOptimization(
        _ image: CIImage,
        filters: [CIFilter],
        context: CIContext? = nil
    ) throws -> CIImage {
        
        _ = context ?? getCIContext()  // Context is available but not used in current implementation
        var processedImage = image
        
        // Process filters in batches to manage memory
        for filter in filters {
            autoreleasepool {
                filter.setValue(processedImage, forKey: kCIInputImageKey)
                
                if let output = filter.outputImage {
                    // Crop to extent to avoid infinite images
                    let extent = output.extent
                    if extent.isInfinite || extent.isEmpty {
                        processedImage = output.cropped(to: image.extent)
                    } else {
                        processedImage = output
                    }
                }
            }
        }
        
        return processedImage
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

/// Performance monitoring for render time optimization
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

/// Monitor for detecting dropped frames during rendering
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