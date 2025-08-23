import SwiftUI
import AuthenticationServices
// Note: Google Sign-In and Facebook SDK not implemented - using Apple Sign-In only for production

@MainActor
final class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var showAuthSheet: Bool = false
    @Published var showUsernameSetup: Bool = false
    @Published var temporaryUsername: String = "Chef\(Int.random(in: 10_000...99_999))"
    @Published var profileImage: UIImage?

    private let keychain = KeychainService()
    private let authTokenKey = "com.snapchef.authToken"

    init() {
        checkAuthStatus()
    }

    private func checkAuthStatus() {
        if let token = keychain.get(authTokenKey) {
            validateToken(token)
        }
    }

    private func validateToken(_ token: String) {
        Task {
            do {
                let user = try await NetworkManager.shared.validateToken(token)
                self.currentUser = user
                self.isAuthenticated = true
            } catch {
                self.keychain.delete(self.authTokenKey)
                self.isAuthenticated = false
            }
        }
    }

    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredential
        }

        let userId = appleIDCredential.user
        let email = appleIDCredential.email
        let fullName = appleIDCredential.fullName

        let authData = AppleAuthData(
            userId: userId,
            email: email,
            givenName: fullName?.givenName,
            familyName: fullName?.familyName,
            identityToken: appleIDCredential.identityToken
        )

        try await authenticateWithBackend(provider: .apple, authData: authData)
    }

    func signInWithGoogle(presentingViewController: UIViewController) async throws {
        // Google Sign-In not implemented in production - use Apple Sign-In instead
        print("⚠️ Google Sign-In not available - redirecting to Apple Sign-In")
        throw AuthError.missingConfiguration
    }

    func signInWithFacebook(presentingViewController: UIViewController) async throws {
        // Facebook SDK not implemented in production - use Apple Sign-In instead
        print("⚠️ Facebook Sign-In not available - redirecting to Apple Sign-In")
        throw AuthError.missingConfiguration
    }

    private func authenticateWithBackend<T: Encodable>(provider: AuthProvider, authData: T) async throws {
        let response = try await NetworkManager.shared.authenticate(
            provider: provider,
            authData: authData
        )

        self.keychain.set(response.token, forKey: self.authTokenKey)
        self.currentUser = response.user
        self.isAuthenticated = true
        self.showAuthSheet = false

        // Check if user needs to set up username
        if response.user.username.hasPrefix("Chef") && response.user.username.count == 10 {
            // User has a temporary username, show setup
            self.showUsernameSetup = true
        }
    }

    func signOut() {
        keychain.delete(authTokenKey)
        currentUser = nil
        isAuthenticated = false

        // Note: Only Apple Sign-In is supported in production
    }

    func promptForAuthIfNeeded(deviceManager: DeviceManager) {
        if !isAuthenticated && deviceManager.freeUsesRemaining == 0 && !deviceManager.hasUnlimitedAccess {
            showAuthSheet = true
        }
    }

    // Check if authentication is required for specific features
    func isAuthRequiredFor(feature: AuthRequiredFeature) -> Bool {
        switch feature {
        case .challenges, .leaderboard, .socialSharing, .teams, .streaks, .premiumFeatures:
            return !isAuthenticated
        case .basicRecipes:
            return false // Basic recipe generation doesn't require auth
        }
    }

    // Update username after setup
    func updateUsername(_ username: String) {
        if let user = currentUser {
            _ = user
            // Create a new user with updated username
            currentUser = User(
                id: user.id,
                email: user.email,
                name: user.name,
                username: username,
                profileImageURL: user.profileImageURL,
                subscription: user.subscription,
                credits: user.credits,
                deviceId: user.deviceId,
                createdAt: user.createdAt,
                lastLoginAt: user.lastLoginAt,
                totalPoints: user.totalPoints,
                currentStreak: user.currentStreak,
                longestStreak: user.longestStreak,
                challengesCompleted: user.challengesCompleted,
                recipesShared: user.recipesShared,
                isProfilePublic: user.isProfilePublic,
                showOnLeaderboard: user.showOnLeaderboard
            )
        }
    }

    // Update profile image
    func updateProfileImage(_ image: UIImage) {
        self.profileImage = image
        // In a real app, you'd upload this to CloudKit or your backend
    }

    func promptAuthForFeature(_ feature: AuthRequiredFeature) {
        if isAuthRequiredFor(feature: feature) {
            showAuthSheet = true
        }
    }
}

enum AuthProvider: String {
    case apple = "apple"
    case google = "google"
    case facebook = "facebook"
}

// AuthRequiredFeature enum moved to UnifiedAuthManager.swift to avoid duplication

enum AuthError: LocalizedError {
    case invalidCredential
    case missingConfiguration
    case networkError
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid authentication credentials"
        case .missingConfiguration:
            return "Missing configuration for authentication"
        case .networkError:
            return "Network error during authentication"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

struct AppleAuthData: Encodable {
    let userId: String
    let email: String?
    let givenName: String?
    let familyName: String?
    let identityToken: Data?
}

struct GoogleAuthData: Encodable {
    let userId: String
    let email: String?
    let name: String?
    let idToken: String?
}

struct FacebookAuthData: Encodable {
    let userId: String
    let email: String?
    let name: String?
    let accessToken: String
}

struct AuthResponse: Decodable {
    let token: String
    let user: User
}
