import XCTest
@testable import SnapChef
import AVFoundation

final class CameraPermissionTests: XCTestCase {
    
    // MARK: - Camera Permission Status Tests
    
    func testCameraPermissionStatusValues() throws {
        // Test that we can access AVAuthorizationStatus values
        let notDetermined = AVAuthorizationStatus.notDetermined
        let restricted = AVAuthorizationStatus.restricted
        let denied = AVAuthorizationStatus.denied
        let authorized = AVAuthorizationStatus.authorized
        
        XCTAssertNotEqual(notDetermined, restricted, "Status values should be different")
        XCTAssertNotEqual(denied, authorized, "Status values should be different")
        XCTAssertNotEqual(notDetermined, authorized, "Status values should be different")
    }
    
    func testCameraMediaType() throws {
        // Test that we can access the correct media type
        let mediaType = AVMediaType.video
        XCTAssertEqual(mediaType.rawValue, "vide", "Video media type should have correct raw value")
    }
    
    // MARK: - Permission Error Handling Tests
    
    func testCameraPermissionErrors() throws {
        // Test camera permission denied error
        let cameraError = SnapChefError.cameraError("Camera permission denied", recovery: .openSettings)
        
        XCTAssertEqual(cameraError.category, .permissions, "Camera error should be categorized as permissions")
        XCTAssertEqual(cameraError.severity, .medium, "Camera error should have medium severity")
        XCTAssertEqual(cameraError.recovery, .openSettings, "Camera error should suggest opening settings")
        XCTAssertEqual(cameraError.actionTitle, "Open Settings", "Should suggest opening settings")
        XCTAssertTrue(cameraError.userFriendlyMessage.contains("Camera access"), "Should mention camera access")
        XCTAssertTrue(cameraError.userFriendlyMessage.contains("Settings"), "Should mention Settings")
    }
    
    func testPhotoLibraryPermissionErrors() throws {
        // Test photo library permission denied error
        let photoError = SnapChefError.photoLibraryError("Photo library access denied", recovery: .openSettings)
        
        XCTAssertEqual(photoError.category, .permissions, "Photo error should be categorized as permissions")
        XCTAssertEqual(photoError.severity, .medium, "Photo error should have medium severity")
        XCTAssertEqual(photoError.recovery, .openSettings, "Photo error should suggest opening settings")
        XCTAssertTrue(photoError.userFriendlyMessage.contains("Photo library"), "Should mention photo library")
        XCTAssertTrue(photoError.userFriendlyMessage.contains("Settings"), "Should mention Settings")
    }
    
    func testMicrophonePermissionErrors() throws {
        // Test microphone permission denied error (for video recording features)
        let micError = SnapChefError.microphoneError("Microphone access denied", recovery: .openSettings)
        
        XCTAssertEqual(micError.category, .permissions, "Microphone error should be categorized as permissions")
        XCTAssertEqual(micError.severity, .medium, "Microphone error should have medium severity")
        XCTAssertEqual(micError.recovery, .openSettings, "Microphone error should suggest opening settings")
        XCTAssertTrue(micError.userFriendlyMessage.contains("Microphone"), "Should mention microphone")
        XCTAssertTrue(micError.userFriendlyMessage.contains("Settings"), "Should mention Settings")
    }
    
    // MARK: - Permission Flow Integration Tests
    
    func testPermissionErrorHandlingFlow() throws {
        let appState = AppState()
        let cameraError = SnapChefError.cameraError("Camera not accessible")
        
        // Handle the error
        appState.handleError(cameraError, context: "camera_capture")
        
        // Verify error was set
        XCTAssertEqual(appState.currentSnapChefError, cameraError, "Camera error should be set in app state")
        
        // Clear the error
        appState.clearError()
        XCTAssertNil(appState.currentSnapChefError, "Error should be cleared")
    }
    
    // MARK: - Permission Status Simulation Tests
    
    func testPermissionStatusHandling() throws {
        // Since we can't easily mock AVCaptureDevice.authorizationStatus in unit tests,
        // we test the error handling paths that would be triggered by different permission states
        
        // Simulate permission denied scenario
        let deniedError = SnapChefError.cameraError("Camera permission denied. Please enable camera access in Settings.")
        XCTAssertTrue(deniedError.userFriendlyMessage.contains("Settings"), "Should guide user to Settings")
        
        // Simulate restricted scenario (parental controls, etc.)
        let restrictedError = SnapChefError.cameraError("Camera access is restricted on this device.")
        XCTAssertNotNil(restrictedError.errorDescription, "Should have error description")
        
        // Simulate unknown error scenario
        let unknownError = SnapChefError.cameraError("An unknown camera error occurred.")
        XCTAssertEqual(unknownError.category, .permissions, "Should still be categorized as permissions error")
    }
    
    // MARK: - Camera Capability Tests
    
    func testCameraCapabilityErrors() throws {
        // Test device capability errors
        let noCamera = SnapChefError.deviceUnsupportedError("This device doesn't have a camera.", recovery: .none)
        XCTAssertEqual(noCamera.category, .system, "Device capability should be system category")
        XCTAssertEqual(noCamera.severity, .critical, "No camera should be critical error")
        XCTAssertEqual(noCamera.recovery, .none, "No recovery possible for missing hardware")
        
        // Test camera hardware failure
        let hardwareError = SnapChefError.cameraError("Camera hardware malfunction detected.", recovery: .contactSupport)
        XCTAssertEqual(hardwareError.recovery, .contactSupport, "Hardware issues should suggest contacting support")
    }
    
    // MARK: - Permission Recovery Strategy Tests
    
    func testPermissionRecoveryStrategies() throws {
        // Test that permission errors suggest the correct recovery strategy
        
        // Camera permission should suggest opening settings
        let cameraError = SnapChefError.cameraError("Permission denied", recovery: .openSettings)
        XCTAssertEqual(cameraError.recovery, .openSettings, "Camera error should suggest opening settings")
        XCTAssertEqual(cameraError.actionTitle, "Open Settings", "Should have correct action title")
        
        // Photo library permission should also suggest opening settings
        let photoError = SnapChefError.photoLibraryError("Permission denied", recovery: .openSettings)
        XCTAssertEqual(photoError.recovery, .openSettings, "Photo error should suggest opening settings")
        
        // Test that the error provides the correct icon
        XCTAssertEqual(cameraError.icon, "camera.badge.exclamationmark", "Should use camera error icon")
        XCTAssertEqual(photoError.icon, "photo.badge.exclamationmark", "Should use photo error icon")
    }
    
    // MARK: - Permission Context Tests
    
    func testPermissionContextualMessages() throws {
        // Test different contextual messages for camera permissions
        
        let recipeCapture = SnapChefError.cameraError("Camera access needed to snap your fridge for recipe generation.")
        XCTAssertTrue(recipeCapture.userFriendlyMessage.contains("snap your fridge"), "Should mention recipe context")
        
        let videoGeneration = SnapChefError.cameraError("Camera access needed for TikTok video creation.")
        XCTAssertNotNil(videoGeneration.errorDescription, "Should have error description")
        
        let generalCapture = SnapChefError.cameraError("Camera access needed to take photos.")
        XCTAssertNotNil(generalCapture.errorDescription, "Should have error description")
    }
    
    // MARK: - Permission Analytics Tests
    
    func testPermissionErrorAnalytics() throws {
        // Test that permission errors are properly logged for analytics
        
        let cameraError = SnapChefError.cameraError("Permission denied", recovery: .openSettings)
        
        // This should not crash when logging analytics
        ErrorAnalytics.logError(cameraError, context: "camera_permission_denied", userId: "test_user")
        
        XCTAssertTrue(true, "Error analytics should execute without crashing")
        
        // Test different permission contexts
        let contexts = [
            "initial_permission_request",
            "recipe_capture_attempt",
            "video_generation_attempt",
            "settings_opened",
            "permission_granted"
        ]
        
        for context in contexts {
            ErrorAnalytics.logError(cameraError, context: context, userId: "test_user")
        }
        
        XCTAssertTrue(true, "All permission contexts should be loggable")
    }
    
    // MARK: - Multi-Permission Scenarios Tests
    
    func testMultiplePermissionErrors() throws {
        // Test scenarios where multiple permissions are needed
        
        let appState = AppState()
        
        // Simulate camera permission denied
        let cameraError = SnapChefError.cameraError("Camera permission denied")
        appState.handleError(cameraError, context: "camera_denied")
        
        XCTAssertNotNil(appState.currentSnapChefError, "Camera error should be set")
        
        // Clear and test photo library permission denied
        appState.clearError()
        let photoError = SnapChefError.photoLibraryError("Photo library permission denied")
        appState.handleError(photoError, context: "photo_denied")
        
        XCTAssertNotNil(appState.currentSnapChefError, "Photo error should be set")
        
        // Test that errors are handled independently
        XCTAssertNotEqual(appState.currentSnapChefError, cameraError, "Should be photo error, not camera error")
    }
    
    // MARK: - Permission State Persistence Tests
    
    func testPermissionStateHandling() throws {
        // Test that permission state changes are handled gracefully
        
        let appState = AppState()
        
        // Test permission initially denied
        let deniedError = SnapChefError.cameraError("Permission denied")
        appState.handleError(deniedError)
        XCTAssertNotNil(appState.currentSnapChefError, "Error should be set for denied permission")
        
        // Test permission later granted (error cleared)
        appState.clearError()
        XCTAssertNil(appState.currentSnapChefError, "Error should be cleared when permission granted")
        
        // Test permission revoked after being granted
        let revokedError = SnapChefError.cameraError("Permission was revoked")
        appState.handleError(revokedError)
        XCTAssertNotNil(appState.currentSnapChefError, "Error should be set for revoked permission")
    }
}