import Foundation

/// DEPRECATED: Use CloudKitSyncEngine instead
/// This file is kept for backward compatibility during migration
/// Will be removed in a future update
///
/// Stores failed sync operations for retry on next app launch
@available(*, deprecated, message: "Use CloudKitSyncEngine instead")
@MainActor
class PersistentSyncQueue {
    static let shared = PersistentSyncQueue()
    private let failedOperationsKey = "failed_sync_operations_v1"
    private let maxRetryCount = 3
    
    struct FailedOperation: Codable {
        let operation: RecipeSyncQueue.SyncOperation
        let failureDate: Date
        let retryCount: Int
    }
    
    private init() {}
    
    /// Add a failed operation to the persistent queue
    func addFailedOperation(_ operation: RecipeSyncQueue.SyncOperation) async {
        var operations = getFailedOperations()
        
        // Check if this operation already exists
        if let index = operations.firstIndex(where: { $0.operation.recipeId == operation.recipeId }) {
            // Update retry count
            var existingOp = operations[index]
            let newRetryCount = existingOp.retryCount + 1
            
            // If exceeded max retries, remove it
            if newRetryCount >= maxRetryCount {
                print("❌ Operation for recipe \(operation.recipeId) exceeded max retries, removing from queue")
                operations.remove(at: index)
            } else {
                // Update with new retry count
                operations[index] = FailedOperation(
                    operation: operation,
                    failureDate: Date(),
                    retryCount: newRetryCount
                )
            }
        } else {
            // Add new failed operation
            operations.append(FailedOperation(
                operation: operation,
                failureDate: Date(),
                retryCount: 0
            ))
        }
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(operations) {
            UserDefaults.standard.set(data, forKey: failedOperationsKey)
            print("💾 Saved \(operations.count) failed operations to persistent queue")
        }
    }
    
    /// Get all failed operations
    func getFailedOperations() -> [FailedOperation] {
        guard let data = UserDefaults.standard.data(forKey: failedOperationsKey),
              let operations = try? JSONDecoder().decode([FailedOperation].self, from: data) else {
            return []
        }
        return operations
    }
    
    /// Retry all failed operations
    func retryAllFailedOperations() async {
        let operations = getFailedOperations()
        guard !operations.isEmpty else { return }
        
        print("🔄 Retrying \(operations.count) failed sync operations...")
        
        // Clear the queue first
        clearFailedOperations()
        
        // Re-queue each operation
        for failedOp in operations {
            // Skip if too old (> 7 days)
            if Date().timeIntervalSince(failedOp.failureDate) > 7 * 24 * 60 * 60 {
                print("⏭ Skipping old operation from \(failedOp.failureDate)")
                continue
            }
            
            // Re-queue for sync
            await RecipeSyncQueue.shared.requeue(failedOp.operation)
        }
    }
    
    /// Clear all failed operations
    func clearFailedOperations() {
        UserDefaults.standard.removeObject(forKey: failedOperationsKey)
        print("🗑 Cleared all failed operations from persistent queue")
    }
    
    /// Get count of failed operations
    func getFailedOperationCount() -> Int {
        return getFailedOperations().count
    }
    
    /// Remove a specific failed operation
    func removeFailedOperation(for recipeId: String) {
        var operations = getFailedOperations()
        operations.removeAll { $0.operation.recipeId == recipeId }
        
        if let data = try? JSONEncoder().encode(operations) {
            UserDefaults.standard.set(data, forKey: failedOperationsKey)
        }
    }
}