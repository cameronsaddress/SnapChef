import XCTest
@testable import SnapChef
import AuthenticationServices

@MainActor
final class AuthenticationManagerTests: XCTestCase {
    
    var authManager: AuthenticationManager!
    
    override func setUpWithError() throws {
        authManager = AuthenticationManager()
    }
    
    override func tearDownWithError() throws {
        authManager = nil
    }
    
    // MARK: - Initialization Tests
    
    func testAuthenticationManagerInitialization() throws {
        XCTAssertFalse(authManager.isAuthenticated, "Should not be authenticated initially")
        XCTAssertNil(authManager.currentUser, "Current user should be nil initially")
        XCTAssertFalse(authManager.showAuthSheet, "Auth sheet should not be shown initially")
        XCTAssertFalse(authManager.showUsernameSetup, "Username setup should not be shown initially")
        XCTAssertNil(authManager.profileImage, "Profile image should be nil initially")
    }
    
    func testTemporaryUsernameGeneration() throws {
        let username = authManager.temporaryUsername
        
        XCTAssertTrue(username.hasPrefix("Chef"), "Temporary username should start with 'Chef'")
        XCTAssertEqual(username.count, 9, "Temporary username should be 9 characters long (Chef + 5 digits)")
        
        // Extract the number part
        let numberPart = String(username.dropFirst(4))
        XCTAssertNotNil(Int(numberPart), "Number part should be a valid integer")
        
        if let number = Int(numberPart) {
            XCTAssertGreaterThanOrEqual(number, 10_000, "Number should be at least 10,000")
            XCTAssertLessThanOrEqual(number, 99_999, "Number should be at most 99,999")
        }
    }
    
    // MARK: - Authentication State Tests
    
    func testSignOut() throws {
        // Simulate authenticated state
        authManager.isAuthenticated = true
        
        authManager.signOut()
        
        XCTAssertFalse(authManager.isAuthenticated, "Should not be authenticated after sign out")
        XCTAssertNil(authManager.currentUser, "Current user should be nil after sign out")
    }
    
    // MARK: - Authentication Requirements Tests
    
    func testAuthRequiredForFeatures() throws {
        // Test when not authenticated
        authManager.isAuthenticated = false
        
        XCTAssertTrue(authManager.isAuthRequiredFor(feature: .challenges), "Challenges should require auth")
        XCTAssertTrue(authManager.isAuthRequiredFor(feature: .leaderboard), "Leaderboard should require auth")
        XCTAssertTrue(authManager.isAuthRequiredFor(feature: .socialSharing), "Social sharing should require auth")
        XCTAssertTrue(authManager.isAuthRequiredFor(feature: .teams), "Teams should require auth")
        XCTAssertTrue(authManager.isAuthRequiredFor(feature: .streaks), "Streaks should require auth")
        XCTAssertTrue(authManager.isAuthRequiredFor(feature: .premiumFeatures), "Premium features should require auth")
        XCTAssertFalse(authManager.isAuthRequiredFor(feature: .basicRecipes), "Basic recipes should not require auth")
        
        // Test when authenticated
        authManager.isAuthenticated = true
        
        XCTAssertFalse(authManager.isAuthRequiredFor(feature: .challenges), "Challenges should not require auth when authenticated")
        XCTAssertFalse(authManager.isAuthRequiredFor(feature: .leaderboard), "Leaderboard should not require auth when authenticated")
        XCTAssertFalse(authManager.isAuthRequiredFor(feature: .socialSharing), "Social sharing should not require auth when authenticated")
        XCTAssertFalse(authManager.isAuthRequiredFor(feature: .teams), "Teams should not require auth when authenticated")
        XCTAssertFalse(authManager.isAuthRequiredFor(feature: .streaks), "Streaks should not require auth when authenticated")
        XCTAssertFalse(authManager.isAuthRequiredFor(feature: .premiumFeatures), "Premium features should not require auth when authenticated")
        XCTAssertFalse(authManager.isAuthRequiredFor(feature: .basicRecipes), "Basic recipes should not require auth when authenticated")
    }
    
    func testPromptAuthForFeature() throws {
        authManager.isAuthenticated = false
        authManager.showAuthSheet = false
        
        // Test prompting for a feature that requires auth
        authManager.promptAuthForFeature(.challenges)
        
        XCTAssertTrue(authManager.showAuthSheet, "Auth sheet should be shown when prompting for auth-required feature")
        
        // Reset
        authManager.showAuthSheet = false
        authManager.isAuthenticated = true
        
        // Test prompting when already authenticated
        authManager.promptAuthForFeature(.challenges)
        
        XCTAssertFalse(authManager.showAuthSheet, "Auth sheet should not be shown when already authenticated")
        
        // Test prompting for a feature that doesn't require auth
        authManager.isAuthenticated = false
        authManager.promptAuthForFeature(.basicRecipes)
        
        XCTAssertFalse(authManager.showAuthSheet, "Auth sheet should not be shown for features that don't require auth")
    }
    
    // MARK: - User Management Tests
    
    func testUpdateUsername() throws {
        // Create a mock user with temporary username
        let mockUser = User(
            id: "test-id",
            email: "test@example.com",
            name: "Test User",
            username: "Chef12345",
            profileImageURL: nil,
            subscription: .free,
            credits: 10,
            deviceId: "test-device",
            createdAt: Date(),
            lastLoginAt: Date(),
            totalPoints: 0,
            currentStreak: 0,
            longestStreak: 0,
            challengesCompleted: 0,
            recipesShared: 0,
            isProfilePublic: true,
            showOnLeaderboard: true
        )
        
        authManager.currentUser = mockUser
        
        let newUsername = "TestUserName"
        authManager.updateUsername(newUsername)
        
        XCTAssertEqual(authManager.currentUser?.username, newUsername, "Username should be updated")
        XCTAssertEqual(authManager.currentUser?.email, "test@example.com", "Other user properties should remain unchanged")
        XCTAssertEqual(authManager.currentUser?.id, "test-id", "User ID should remain unchanged")
    }
    
    func testUpdateProfileImage() throws {
        // Create a test image
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.blue.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        XCTAssertNotNil(testImage, "Test image should be created")
        
        authManager.updateProfileImage(testImage!)
        
        XCTAssertEqual(authManager.profileImage, testImage, "Profile image should be updated")
    }
    
    // MARK: - AuthRequiredFeature Enum Tests
    
    func testAuthRequiredFeatureTitles() throws {
        XCTAssertEqual(AuthRequiredFeature.basicRecipes.title, "Basic Recipes")
        XCTAssertEqual(AuthRequiredFeature.challenges.title, "Challenges")
        XCTAssertEqual(AuthRequiredFeature.leaderboard.title, "Leaderboard")
        XCTAssertEqual(AuthRequiredFeature.socialSharing.title, "Social Sharing")
        XCTAssertEqual(AuthRequiredFeature.teams.title, "Teams")
        XCTAssertEqual(AuthRequiredFeature.streaks.title, "Streaks")
        XCTAssertEqual(AuthRequiredFeature.premiumFeatures.title, "Premium Features")
    }
    
    func testAuthRequiredFeatureRequiresAuth() throws {
        XCTAssertFalse(AuthRequiredFeature.basicRecipes.requiresAuth, "Basic recipes should not require auth")
        XCTAssertTrue(AuthRequiredFeature.challenges.requiresAuth, "Challenges should require auth")
        XCTAssertTrue(AuthRequiredFeature.leaderboard.requiresAuth, "Leaderboard should require auth")
        XCTAssertTrue(AuthRequiredFeature.socialSharing.requiresAuth, "Social sharing should require auth")
        XCTAssertTrue(AuthRequiredFeature.teams.requiresAuth, "Teams should require auth")
        XCTAssertTrue(AuthRequiredFeature.streaks.requiresAuth, "Streaks should require auth")
        XCTAssertTrue(AuthRequiredFeature.premiumFeatures.requiresAuth, "Premium features should require auth")
    }
    
    // MARK: - AuthProvider Enum Tests
    
    func testAuthProviderRawValues() throws {
        XCTAssertEqual(AuthProvider.apple.rawValue, "apple")
        XCTAssertEqual(AuthProvider.google.rawValue, "google")
        XCTAssertEqual(AuthProvider.facebook.rawValue, "facebook")
    }
    
    // MARK: - AuthError Tests
    
    func testAuthErrorDescriptions() throws {
        XCTAssertEqual(AuthError.invalidCredential.errorDescription, "Invalid authentication credentials")
        XCTAssertEqual(AuthError.missingConfiguration.errorDescription, "Missing configuration for authentication")
        XCTAssertEqual(AuthError.networkError.errorDescription, "Network error during authentication")
        XCTAssertEqual(AuthError.unknown.errorDescription, "An unknown error occurred")
    }
    
    // MARK: - Auth Data Models Tests
    
    func testAppleAuthDataCreation() throws {
        let appleAuthData = AppleAuthData(
            userId: "apple-user-id",
            email: "user@example.com",
            givenName: "John",
            familyName: "Doe",
            identityToken: "token".data(using: .utf8)
        )
        
        XCTAssertEqual(appleAuthData.userId, "apple-user-id")
        XCTAssertEqual(appleAuthData.email, "user@example.com")
        XCTAssertEqual(appleAuthData.givenName, "John")
        XCTAssertEqual(appleAuthData.familyName, "Doe")
        XCTAssertNotNil(appleAuthData.identityToken)
    }
    
    func testGoogleAuthDataCreation() throws {
        let googleAuthData = GoogleAuthData(
            userId: "google-user-id",
            email: "user@gmail.com",
            name: "Jane Smith",
            idToken: "google-id-token"
        )
        
        XCTAssertEqual(googleAuthData.userId, "google-user-id")
        XCTAssertEqual(googleAuthData.email, "user@gmail.com")
        XCTAssertEqual(googleAuthData.name, "Jane Smith")
        XCTAssertEqual(googleAuthData.idToken, "google-id-token")
    }
    
    func testFacebookAuthDataCreation() throws {
        let facebookAuthData = FacebookAuthData(
            userId: "facebook-user-id",
            email: "user@facebook.com",
            name: "Bob Johnson",
            accessToken: "facebook-access-token"
        )
        
        XCTAssertEqual(facebookAuthData.userId, "facebook-user-id")
        XCTAssertEqual(facebookAuthData.email, "user@facebook.com")
        XCTAssertEqual(facebookAuthData.name, "Bob Johnson")
        XCTAssertEqual(facebookAuthData.accessToken, "facebook-access-token")
    }
    
    // MARK: - Mock Authentication Tests
    
    func testGoogleSignInNotImplemented() async throws {
        // Create a mock view controller
        let viewController = UIViewController()
        
        do {
            _ = try await authManager.signInWithGoogle(presentingViewController: viewController)
            XCTFail("Google sign-in should throw an error since it's not implemented")
        } catch {
            XCTAssertTrue(error is AuthError, "Should throw AuthError")
            if let authError = error as? AuthError {
                XCTAssertEqual(authError, AuthError.missingConfiguration, "Should throw missingConfiguration error")
            }
        }
    }
    
    func testFacebookSignInNotImplemented() async throws {
        // Create a mock view controller
        let viewController = UIViewController()
        
        do {
            _ = try await authManager.signInWithFacebook(presentingViewController: viewController)
            XCTFail("Facebook sign-in should throw an error since it's not implemented")
        } catch {
            XCTAssertTrue(error is AuthError, "Should throw AuthError")
            if let authError = error as? AuthError {
                XCTAssertEqual(authError, AuthError.missingConfiguration, "Should throw missingConfiguration error")
            }
        }
    }
}