import Foundation
import UIKit

@MainActor
final class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    private let backgroundQueue = DispatchQueue(label: "com.snapchef.background", qos: .utility)
    private let imageProcessingQueue = DispatchQueue(label: "com.snapchef.imageProcessing", qos: .userInitiated)
    private let particleUpdateQueue = DispatchQueue(label: "com.snapchef.particles", qos: .utility)
    
    private init() {}
    
    // MARK: - Image Processing
    
    /// Process images off main thread for better performance
    func processImage<T>(_ image: UIImage, operation: @escaping (UIImage) -> T) async -> T {
        return await withCheckedContinuation { continuation in
            imageProcessingQueue.async {
                let result = operation(image)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Resize image for optimal performance
    func resizeImage(_ image: UIImage, targetSize: CGSize) async -> UIImage? {
        return await processImage(image) { image in
            return image.resized(to: targetSize)
        }
    }
    
    /// Compress image for sharing/storage
    func compressImage(_ image: UIImage, quality: CGFloat = 0.8) async -> Data? {
        return await processImage(image) { image in
            return image.jpegData(compressionQuality: quality)
        }
    }
    
    // MARK: - Data Processing
    
    /// Perform heavy data operations in background
    func performDataOperation<T>(_ operation: @escaping () -> T) async -> T {
        return await withCheckedContinuation { continuation in
            backgroundQueue.async {
                let result = operation()
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Process large collections in batches
    func processBatch<T, R>(_ items: [T], batchSize: Int = 10, operation: @escaping ([T]) -> [R]) async -> [R] {
        return await performDataOperation {
            var results: [R] = []
            let batches = items.chunked(into: batchSize)
            
            for batch in batches {
                let batchResults = operation(batch)
                results.append(contentsOf: batchResults)
            }
            
            return results
        }
    }
    
    // MARK: - Particle System Optimization
    
    /// Update particles in background for better performance
    func updateParticles<T>(_ particles: [T], updateOperation: @escaping (T) -> T?) async -> [T] {
        guard !particles.isEmpty else { return [] }
        
        return await withCheckedContinuation { continuation in
            particleUpdateQueue.async {
                let updatedParticles = particles.compactMap(updateOperation)
                continuation.resume(returning: updatedParticles)
            }
        }
    }
    
    // MARK: - Memory Management
    
    /// Clean up resources in background
    func performCleanup(_ cleanupOperation: @escaping () -> Void) {
        backgroundQueue.async {
            cleanupOperation()
        }
    }
    
    /// Monitor memory usage and trigger cleanup if needed
    func monitorMemoryUsage() {
        backgroundQueue.async {
            let memoryInfo = self.getCurrentMemoryUsage()
            
            if memoryInfo.usageInMB > 300 { // 300MB threshold
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .memoryPressureDetected,
                        object: nil,
                        userInfo: ["usage": memoryInfo]
                    )
                }
            }
        }
    }
    
    private func getCurrentMemoryUsage() -> MemoryInfo {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        let usageInBytes = kerr == KERN_SUCCESS ? info.resident_size : 0
        let usageInMB = Double(usageInBytes) / 1024.0 / 1024.0
        
        return MemoryInfo(usageInBytes: Int64(usageInBytes), usageInMB: usageInMB)
    }
    
    // MARK: - Animation Optimization
    
    /// Throttle animation updates for better performance
    func throttleAnimation<T>(
        _ value: T,
        interval: TimeInterval = 0.016, // 60 FPS
        operation: @escaping (T) -> Void
    ) {
        backgroundQueue.asyncAfter(deadline: .now() + interval) {
            DispatchQueue.main.async {
                operation(value)
            }
        }
    }
    
    // MARK: - Task Coordination
    
    /// Execute multiple tasks concurrently with limited concurrency
    func executeConcurrentTasks<T>(
        _ tasks: [() async -> T],
        maxConcurrency: Int = 3
    ) async -> [T] {
        return await withTaskGroup(of: T.self, returning: [T].self) { group in
            var results: [T] = []
            var taskIterator = tasks.makeIterator()
            
            // Start initial tasks up to max concurrency
            for _ in 0..<min(maxConcurrency, tasks.count) {
                if let task = taskIterator.next() {
                    group.addTask {
                        await task()
                    }
                }
            }
            
            // As tasks complete, start new ones
            for await result in group {
                results.append(result)
                
                if let nextTask = taskIterator.next() {
                    group.addTask {
                        await nextTask()
                    }
                }
            }
            
            return results
        }
    }
}

// MARK: - Supporting Types

struct MemoryInfo {
    let usageInBytes: Int64
    let usageInMB: Double
}

extension Notification.Name {
    static let memoryPressureDetected = Notification.Name("memoryPressureDetected")
}

// MARK: - Extensions

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Performance Monitor

@MainActor
class PerformanceMonitor: ObservableObject {
    @Published var fps: Double = 60.0
    @Published var memoryUsage: Double = 0.0
    @Published var isPerformanceGood: Bool = true
    
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    
    func startMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.add(to: .main, forMode: .common)
        
        // Monitor memory usage every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await self.updateMemoryUsage()
            }
        }
    }
    
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateFPS(displayLink: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }
        
        frameCount += 1
        let elapsed = displayLink.timestamp - lastTimestamp
        
        if elapsed >= 1.0 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            lastTimestamp = displayLink.timestamp
            
            isPerformanceGood = fps > 50.0 && memoryUsage < 400.0
        }
    }
    
    private func updateMemoryUsage() async {
        let memoryInfo = await BackgroundTaskManager.shared.performDataOperation {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
            
            let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_,
                             task_flavor_t(MACH_TASK_BASIC_INFO),
                             $0,
                             &count)
                }
            }
            
            return kerr == KERN_SUCCESS ? Double(info.resident_size) / 1024.0 / 1024.0 : 0.0
        }
        
        memoryUsage = memoryInfo
    }
    
    deinit {
        stopMonitoring()
    }
}