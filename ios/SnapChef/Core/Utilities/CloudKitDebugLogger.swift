import Foundation
import CloudKit
import os.log

/// Centralized CloudKit debug logging system
/// Only logs errors in DEBUG mode to avoid production noise
final class CloudKitDebugLogger: @unchecked Sendable {
    static let shared = CloudKitDebugLogger()
    
    private let logger = Logger(subsystem: "com.snapchef.app", category: "CloudKit")
    private var operationStats: [String: OperationStats] = [:]
    
    private struct OperationStats {
        var successCount: Int = 0
        var failureCount: Int = 0
        var totalDuration: TimeInterval = 0
        var operations: [OperationLog] = []
    }
    
    private struct OperationLog {
        let timestamp: Date
        let operation: String
        let recordType: String?
        let success: Bool
        let duration: TimeInterval
        let error: Error?
    }
    
    private init() {}
    
    // MARK: - Save Operations
    
    func logSaveStart(recordType: String, database: String, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        // Only log errors, not start operations
        #endif
    }
    
    func logSaveSuccess(recordType: String, recordID: String? = nil, database: String, duration: TimeInterval, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        // Only log errors, not successes
        updateStats(operation: "save", recordType: recordType, success: true, duration: duration, error: nil)
        #endif
    }
    
    func logSaveFailure(recordType: String, database: String, error: Error, duration: TimeInterval, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        logger.error("❌ SAVE FAILED: \(recordType) to \(database) | Error: \(error.localizedDescription) | Duration: \(String(format: "%.2f", duration))s | \(file.split(separator: "/").last ?? ""):\(line) | \(function)")
        
        updateStats(operation: "save", recordType: recordType, success: false, duration: duration, error: error)
        
        // Throw assertion failure in debug for critical errors
        if isCriticalError(error) {
            assertionFailure("CloudKit SAVE failed with critical error: \(error)")
        }
        #endif
    }
    
    // MARK: - Fetch Operations
    
    func logFetchStart(recordType: String?, query: String? = nil, database: String, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        // Only log errors, not start operations
        #endif
    }
    
    func logFetchSuccess(recordType: String?, recordCount: Int, database: String, duration: TimeInterval, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        // Only log errors, not successes
        let typeString = recordType ?? "multiple"
        updateStats(operation: "fetch", recordType: typeString, success: true, duration: duration, error: nil)
        #endif
    }
    
    func logFetchFailure(recordType: String?, database: String, error: Error, duration: TimeInterval, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        let typeString = recordType ?? "unknown"
        logger.error("❌ FETCH FAILED: \(typeString) from \(database) | Error: \(error.localizedDescription) | Duration: \(String(format: "%.2f", duration))s | \(file.split(separator: "/").last ?? ""):\(line) | \(function)")
        
        updateStats(operation: "fetch", recordType: typeString, success: false, duration: duration, error: error)
        
        // Throw assertion failure in debug for critical errors
        if isCriticalError(error) {
            assertionFailure("CloudKit FETCH failed with critical error: \(error)")
        }
        #endif
    }
    
    // MARK: - Delete Operations
    
    func logDeleteStart(recordType: String, recordID: String, database: String, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        // Only log errors, not start operations
        #endif
    }
    
    func logDeleteSuccess(recordType: String, recordID: String, database: String, duration: TimeInterval, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        // Only log errors, not successes
        updateStats(operation: "delete", recordType: recordType, success: true, duration: duration, error: nil)
        #endif
    }
    
    func logDeleteFailure(recordType: String, recordID: String, database: String, error: Error, duration: TimeInterval, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        logger.error("❌ DELETE FAILED: \(recordType) [\(recordID)] from \(database) | Error: \(error.localizedDescription) | Duration: \(String(format: "%.2f", duration))s | \(file.split(separator: "/").last ?? ""):\(line) | \(function)")
        
        updateStats(operation: "delete", recordType: recordType, success: false, duration: duration, error: error)
        
        // Throw assertion failure in debug for critical errors
        if isCriticalError(error) {
            assertionFailure("CloudKit DELETE failed with critical error: \(error)")
        }
        #endif
    }
    
    // MARK: - Query Operations
    
    func logQueryStart(query: CKQuery, database: String, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        // Only log errors, not start operations
        #endif
    }
    
    func logQuerySuccess(query: CKQuery, resultCount: Int, database: String, duration: TimeInterval, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        // Only log errors, not successes
        updateStats(operation: "query", recordType: query.recordType, success: true, duration: duration, error: nil)
        #endif
    }
    
    func logQueryFailure(query: CKQuery, database: String, error: Error, duration: TimeInterval, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        logger.error("❌ QUERY FAILED: \(query.recordType) from \(database) | Error: \(error.localizedDescription) | Duration: \(String(format: "%.2f", duration))s | \(file.split(separator: "/").last ?? ""):\(line) | \(function)")
        
        updateStats(operation: "query", recordType: query.recordType, success: false, duration: duration, error: error)
        
        // Throw assertion failure in debug for critical errors
        if isCriticalError(error) {
            assertionFailure("CloudKit QUERY failed with critical error: \(error)")
        }
        #endif
    }
    
    // MARK: - Subscription Operations
    
    func logSubscriptionCreated(subscriptionID: String, recordType: String, database: String, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        // Only log errors, not successes
        #endif
    }
    
    func logSubscriptionFailed(subscriptionID: String, recordType: String, database: String, error: Error, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        logger.error("❌ SUBSCRIPTION FAILED: \(subscriptionID) for \(recordType) in \(database) | Error: \(error.localizedDescription) | \(file.split(separator: "/").last ?? ""):\(line)")
        
        // Throw assertion failure in debug for critical errors
        if isCriticalError(error) {
            assertionFailure("CloudKit SUBSCRIPTION failed with critical error: \(error)")
        }
        #endif
    }
    
    // MARK: - Error Analysis
    
    private func isCriticalError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        
        switch ckError.code {
        case .internalError,
             .serverRejectedRequest,
             .invalidArguments,
             .permissionFailure,
             .unknownItem,
             .badDatabase:
            return true
        case .networkUnavailable,
             .networkFailure,
             .serviceUnavailable,
             .requestRateLimited,
             .zoneBusy,
             .batchRequestFailed:
            return false  // These are recoverable
        default:
            return false
        }
    }
    
    // MARK: - Statistics
    
    private func updateStats(operation: String, recordType: String, success: Bool, duration: TimeInterval, error: Error?) {
        let key = "\(operation)_\(recordType)"
        
        if operationStats[key] == nil {
            operationStats[key] = OperationStats()
        }
        
        if success {
            operationStats[key]?.successCount += 1
        } else {
            operationStats[key]?.failureCount += 1
        }
        
        operationStats[key]?.totalDuration += duration
        operationStats[key]?.operations.append(
            OperationLog(
                timestamp: Date(),
                operation: operation,
                recordType: recordType,
                success: success,
                duration: duration,
                error: error
            )
        )
        
        // Keep only last 100 operations per type
        if let count = operationStats[key]?.operations.count, count > 100 {
            operationStats[key]?.operations.removeFirst(count - 100)
        }
    }
    
    func printStatistics() {
        #if DEBUG
        logger.info("📊 CloudKit Operation Statistics:")
        for (key, stats) in operationStats {
            let avgDuration = stats.totalDuration / Double(stats.successCount + stats.failureCount)
            let successRate = Double(stats.successCount) / Double(stats.successCount + stats.failureCount) * 100
            
            logger.info("  \(key): ✅ \(stats.successCount) | ❌ \(stats.failureCount) | Success Rate: \(String(format: "%.1f", successRate))% | Avg Duration: \(String(format: "%.2f", avgDuration))s")
        }
        #endif
    }
    
    private func getRecentErrors(limit: Int = 10) -> [OperationLog] {
        var errors: [OperationLog] = []
        
        for (_, stats) in operationStats {
            errors.append(contentsOf: stats.operations.filter { !$0.success })
        }
        
        return Array(errors.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
    
    // MARK: - Convenience Methods
    
    func databaseName(for database: CKDatabase) -> String {
        switch database.databaseScope {
        case .public:
            return "publicDB"
        case .private:
            return "privateDB"
        case .shared:
            return "sharedDB"
        @unknown default:
            return "unknownDB"
        }
    }
}

// MARK: - Convenience Extensions

extension CKDatabase {
    var debugName: String {
        CloudKitDebugLogger.shared.databaseName(for: self)
    }
}