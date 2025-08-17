import XCTest
@testable import SnapChef
import CloudKit

@MainActor
final class ErrorHandlerTests: XCTestCase {
    
    var globalErrorHandler: GlobalErrorHandler!
    
    override func setUpWithError() throws {
        globalErrorHandler = GlobalErrorHandler.shared
        globalErrorHandler.clearHistory()
        globalErrorHandler.clearError()
    }
    
    override func tearDownWithError() throws {
        globalErrorHandler.clearHistory()
        globalErrorHandler.clearError()
        globalErrorHandler = nil
    }
    
    // MARK: - SnapChefError Tests
    
    func testSnapChefErrorEquality() throws {
        let error1 = SnapChefError.networkError("Connection failed")
        let error2 = SnapChefError.networkError("Connection failed")
        let error3 = SnapChefError.networkError("Different message")
        let error4 = SnapChefError.apiError("API failed", statusCode: 500)
        
        XCTAssertEqual(error1, error2, "Same network errors should be equal")
        XCTAssertNotEqual(error1, error3, "Network errors with different messages should not be equal")
        XCTAssertNotEqual(error1, error4, "Different error types should not be equal")
    }
    
    func testSnapChefErrorDescriptions() throws {
        let networkError = SnapChefError.networkError("Network is down")
        XCTAssertEqual(networkError.errorDescription, "Network is down")
        
        let apiError = SnapChefError.apiError("Server error", statusCode: 500)
        XCTAssertEqual(apiError.errorDescription, "Server error")
        
        let authError = SnapChefError.authenticationError("Invalid token")
        XCTAssertEqual(authError.errorDescription, "Invalid token")
        
        let cameraError = SnapChefError.cameraError("Camera permission denied")
        XCTAssertEqual(cameraError.errorDescription, "Camera permission denied")
    }
    
    func testSnapChefErrorUserFriendlyMessages() throws {
        let networkError = SnapChefError.networkError("Connection timeout")
        XCTAssertEqual(networkError.userFriendlyMessage, "We're having trouble connecting. Please check your internet and try again.")
        
        let rateLimitError = SnapChefError.rateLimitError("Too many requests", retryAfter: 120)
        XCTAssertTrue(rateLimitError.userFriendlyMessage.contains("2 minutes"), "Should show retry time in minutes")
        
        let cameraError = SnapChefError.cameraError("No permission")
        XCTAssertTrue(cameraError.userFriendlyMessage.contains("Camera access"), "Should mention camera access")
        XCTAssertTrue(cameraError.userFriendlyMessage.contains("Settings"), "Should mention Settings")
        
        let validationError = SnapChefError.validationError("Invalid email format", fields: ["email"])
        XCTAssertEqual(validationError.userFriendlyMessage, "Invalid email format")
        
        let unknownError = SnapChefError.unknown("Something went wrong")
        XCTAssertEqual(unknownError.userFriendlyMessage, "Something unexpected happened. Please try again.")
    }
    
    func testSnapChefErrorActionTitles() throws {
        let retryError = SnapChefError.networkError("Network failed", recovery: .retry)
        XCTAssertEqual(retryError.actionTitle, "Retry")
        
        let authError = SnapChefError.authenticationError("Not authenticated", recovery: .reauthenticate)
        XCTAssertEqual(authError.actionTitle, "Sign In")
        
        let settingsError = SnapChefError.cameraError("No permission", recovery: .openSettings)
        XCTAssertEqual(settingsError.actionTitle, "Open Settings")
        
        let subscriptionError = SnapChefError.subscriptionError("Expired", recovery: .manageSubscription)
        XCTAssertEqual(subscriptionError.actionTitle, "Manage Subscription")
        
        let supportError = SnapChefError.unknown("Critical error", recovery: .contactSupport)
        XCTAssertEqual(supportError.actionTitle, "Contact Support")
    }
    
    func testSnapChefErrorIcons() throws {
        let networkError = SnapChefError.networkError("Network failed")
        XCTAssertEqual(networkError.icon, "wifi.slash")
        
        let authError = SnapChefError.authenticationError("Auth failed")
        XCTAssertEqual(authError.icon, "person.crop.circle.badge.exclamationmark")
        
        let cameraError = SnapChefError.cameraError("Camera failed")
        XCTAssertEqual(cameraError.icon, "camera.badge.exclamationmark")
        
        let recipeError = SnapChefError.recipeGenerationError("Recipe failed")
        XCTAssertEqual(recipeError.icon, "fork.knife.circle.fill")
        
        let videoError = SnapChefError.videoGenerationError("Video failed")
        XCTAssertEqual(videoError.icon, "video.badge.exclamationmark")
    }
    
    func testSnapChefErrorSeverity() throws {
        let lowError = SnapChefError.invalidInput("Invalid input")
        XCTAssertEqual(lowError.severity, .low)
        
        let mediumError = SnapChefError.networkError("Network failed")
        XCTAssertEqual(mediumError.severity, .medium)
        
        let highError = SnapChefError.authenticationError("Auth failed")
        XCTAssertEqual(highError.severity, .high)
        
        let criticalError = SnapChefError.lowMemoryError("Out of memory")
        XCTAssertEqual(criticalError.severity, .critical)
    }
    
    func testSnapChefErrorCategory() throws {
        let networkError = SnapChefError.networkError("Network failed")
        XCTAssertEqual(networkError.category, .network)
        
        let authError = SnapChefError.authenticationError("Auth failed")
        XCTAssertEqual(authError.category, .authentication)
        
        let permissionError = SnapChefError.cameraError("Permission denied")
        XCTAssertEqual(permissionError.category, .permissions)
        
        let storageError = SnapChefError.storageError("Storage failed")
        XCTAssertEqual(storageError.category, .storage)
        
        let validationError = SnapChefError.validationError("Validation failed")
        XCTAssertEqual(validationError.category, .validation)
        
        let processingError = SnapChefError.imageProcessingError("Processing failed")
        XCTAssertEqual(processingError.category, .processing)
    }
    
    // MARK: - CloudKit Error Handler Tests
    
    func testCloudKitErrorUserFriendlyMessages() throws {
        let networkError = CKError(.networkUnavailable)
        let message = CloudKitErrorHandler.userFriendlyMessage(for: networkError)
        XCTAssertTrue(message.contains("internet connection"), "Should mention internet connection")
        
        let authError = CKError(.notAuthenticated)
        let authMessage = CloudKitErrorHandler.userFriendlyMessage(for: authError)
        XCTAssertTrue(authMessage.contains("iCloud"), "Should mention iCloud")
        
        let quotaError = CKError(.quotaExceeded)
        let quotaMessage = CloudKitErrorHandler.userFriendlyMessage(for: quotaError)
        XCTAssertTrue(quotaMessage.contains("storage"), "Should mention storage")
    }
    
    func testCloudKitErrorToSnapChefError() throws {
        let networkError = CKError(.networkUnavailable)
        let snapChefError = CloudKitErrorHandler.snapChefError(from: networkError)
        
        switch snapChefError {
        case .networkError:
            XCTAssertTrue(true, "Should convert to network error")
        default:
            XCTFail("Should convert to network error")
        }
        
        let authError = CKError(.notAuthenticated)
        let snapChefAuthError = CloudKitErrorHandler.snapChefError(from: authError)
        
        switch snapChefAuthError {
        case .authenticationError:
            XCTAssertTrue(true, "Should convert to authentication error")
        default:
            XCTFail("Should convert to authentication error")
        }
    }
    
    // MARK: - Global Error Handler Tests
    
    func testGlobalErrorHandlerSingleton() throws {
        let handler1 = GlobalErrorHandler.shared
        let handler2 = GlobalErrorHandler.shared
        
        XCTAssertTrue(handler1 === handler2, "GlobalErrorHandler should be a singleton")
    }
    
    func testGlobalErrorHandlerHandleError() throws {
        let testError = SnapChefError.networkError("Test error")
        
        globalErrorHandler.handleError(testError, context: "test_context")
        
        XCTAssertEqual(globalErrorHandler.currentError, testError, "Current error should be set")
        XCTAssertEqual(globalErrorHandler.errorHistory.count, 1, "Error should be added to history")
        XCTAssertEqual(globalErrorHandler.errorHistory.first, testError, "First error in history should match")
    }
    
    func testGlobalErrorHandlerClearError() throws {
        let testError = SnapChefError.networkError("Test error")
        globalErrorHandler.handleError(testError)
        
        XCTAssertNotNil(globalErrorHandler.currentError, "Error should be set")
        
        globalErrorHandler.clearError()
        
        XCTAssertNil(globalErrorHandler.currentError, "Current error should be cleared")
        XCTAssertFalse(globalErrorHandler.errorHistory.isEmpty, "History should not be cleared")
    }
    
    func testGlobalErrorHandlerClearHistory() throws {
        let testError1 = SnapChefError.networkError("Test error 1")
        let testError2 = SnapChefError.apiError("Test error 2")
        
        globalErrorHandler.handleError(testError1)
        globalErrorHandler.handleError(testError2)
        
        XCTAssertEqual(globalErrorHandler.errorHistory.count, 2, "Should have 2 errors in history")
        
        globalErrorHandler.clearHistory()
        
        XCTAssertTrue(globalErrorHandler.errorHistory.isEmpty, "History should be cleared")
    }
    
    func testGlobalErrorHandlerHistoryLimit() throws {
        // Add more than 50 errors to test the limit
        for i in 1...55 {
            let error = SnapChefError.networkError("Error \(i)")
            globalErrorHandler.handleError(error)
        }
        
        XCTAssertEqual(globalErrorHandler.errorHistory.count, 50, "History should be limited to 50 errors")
        
        // Check that the oldest errors were removed
        let firstError = globalErrorHandler.errorHistory.first
        if case .networkError(let message, _) = firstError {
            XCTAssertEqual(message, "Error 6", "First error should be Error 6 (oldest 5 should be removed)")
        } else {
            XCTFail("First error should be a network error")
        }
        
        let lastError = globalErrorHandler.errorHistory.last
        if case .networkError(let message, _) = lastError {
            XCTAssertEqual(message, "Error 55", "Last error should be Error 55")
        } else {
            XCTFail("Last error should be a network error")
        }
    }
    
    // MARK: - Retry Manager Tests
    
    func testRetryManagerSingleton() throws {
        let manager1 = RetryManager.shared
        let manager2 = RetryManager.shared
        
        XCTAssertTrue(manager1 === manager2, "RetryManager should be a singleton")
    }
    
    func testRetryManagerCanRetry() throws {
        let operationId = "test_operation"
        let retryManager = RetryManager.shared
        
        // Initially should be able to retry
        XCTAssertTrue(retryManager.canRetry(for: operationId), "Should be able to retry initially")
        
        // Reset retries for clean test
        retryManager.resetRetries(for: operationId)
        XCTAssertTrue(retryManager.canRetry(for: operationId), "Should be able to retry after reset")
    }
    
    func testRetryManagerResetRetries() throws {
        let operationId = "test_reset_operation"
        let retryManager = RetryManager.shared
        
        retryManager.resetRetries(for: operationId)
        
        // Should be able to retry after reset
        XCTAssertTrue(retryManager.canRetry(for: operationId), "Should be able to retry after reset")
    }
    
    // MARK: - Error Recovery Strategy Tests
    
    func testErrorRecoveryStrategyEquality() throws {
        XCTAssertEqual(ErrorRecoveryStrategy.none, ErrorRecoveryStrategy.none)
        XCTAssertEqual(ErrorRecoveryStrategy.retry, ErrorRecoveryStrategy.retry)
        XCTAssertEqual(ErrorRecoveryStrategy.retryAfter(60), ErrorRecoveryStrategy.retryAfter(60))
        XCTAssertNotEqual(ErrorRecoveryStrategy.retryAfter(60), ErrorRecoveryStrategy.retryAfter(120))
        XCTAssertNotEqual(ErrorRecoveryStrategy.retry, ErrorRecoveryStrategy.none)
    }
    
    // MARK: - Error with Rate Limiting Tests
    
    func testRateLimitErrorWithRetryAfter() throws {
        let rateLimitError = SnapChefError.rateLimitError("Rate limited", retryAfter: 300)
        
        XCTAssertEqual(rateLimitError.recovery, .retryAfter(300), "Should have retry after recovery")
        XCTAssertTrue(rateLimitError.userFriendlyMessage.contains("5 minutes"), "Should show 5 minutes in message")
        XCTAssertEqual(rateLimitError.actionTitle, "Retry Later")
    }
    
    func testRateLimitErrorWithoutRetryAfter() throws {
        let rateLimitError = SnapChefError.rateLimitError("Rate limited", retryAfter: nil)
        
        XCTAssertEqual(rateLimitError.recovery, .retryAfter(60), "Should default to 60 seconds")
        XCTAssertTrue(rateLimitError.userFriendlyMessage.contains("moment"), "Should show 'moment' when no specific time")
    }
    
    // MARK: - Error Analytics Tests
    
    func testErrorAnalyticsLogError() throws {
        let testError = SnapChefError.networkError("Analytics test error")
        
        // This should not crash
        ErrorAnalytics.logError(testError, context: "test_analytics", userId: "test_user")
        
        XCTAssertTrue(true, "Error analytics should execute without crashing")
    }
    
    // MARK: - API Error Status Code Handling Tests
    
    func testAPIErrorStatusCodeHandling() throws {
        let apiManager = SnapChefAPIManager.shared
        
        // Test 400 error
        let badRequestError = apiManager.handleHTTPStatusCode(400, data: nil)
        if case .validationError(let message, _) = badRequestError {
            XCTAssertTrue(message.contains("Invalid request"), "Should contain invalid request message")
        } else {
            XCTFail("Should return validation error for 400 status")
        }
        
        // Test 401 error
        let unauthorizedError = apiManager.handleHTTPStatusCode(401, data: nil)
        if case .authenticationError(let message) = unauthorizedError {
            XCTAssertTrue(message.contains("Authentication failed"), "Should contain auth failed message")
        } else {
            XCTFail("Should return authentication error for 401 status")
        }
        
        // Test 429 error
        let rateLimitError = apiManager.handleHTTPStatusCode(429, data: nil)
        if case .rateLimitError(let message, _) = rateLimitError {
            XCTAssertTrue(message.contains("Too many requests"), "Should contain rate limit message")
        } else {
            XCTFail("Should return rate limit error for 429 status")
        }
        
        // Test 500 error
        let serverError = apiManager.handleHTTPStatusCode(500, data: nil)
        if case .apiError(let message, _, _) = serverError {
            XCTAssertTrue(message.contains("temporarily unavailable"), "Should contain server error message")
        } else {
            XCTFail("Should return API error for 500 status")
        }
    }
}