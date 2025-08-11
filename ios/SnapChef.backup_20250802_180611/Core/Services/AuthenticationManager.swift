import SwiftUI
import AuthenticationServices
// import GoogleSignIn  // TODO: Add GoogleSignIn package dependency
// import FBSDKCoreKit  // TODO: Add Facebook SDK package dependency
// import FBSDKLoginKit

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var showAuthSheet: Bool = false
    @Published var showUsernameSetup: Bool = false
    @Published var temporaryUsername: String = "Chef\(Int.random(in: 10000...99999))"
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
        // TODO: Implement when GoogleSignIn package is added
        throw AuthError.missingConfiguration
        /*
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String else {
            throw AuthError.missingConfiguration
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        
        let authData = GoogleAuthData(
            userId: result.user.userID ?? "",
            email: result.user.profile?.email,
            name: result.user.profile?.name,
            idToken: result.user.idToken?.tokenString
        )
        
        try await authenticateWithBackend(provider: .google, authData: authData)
        */
    }
    
    func signInWithFacebook(presentingViewController: UIViewController) async throws {
        // TODO: Implement when Facebook SDK is added
        throw AuthError.missingConfiguration
        /*
        let loginManager = LoginManager()
        
        do {
            let result = try await loginManager.logIn(permissions: ["public_profile", "email"], from: presentingViewController)
            
            guard let token = result?.token else {
                throw AuthError.invalidCredential
            }
            
            // Get user info
            let request = GraphRequest(graphPath: "me", parameters: ["fields": "id, name, email"])
            let graphResult = try await request.start()
            
            let authData = FacebookAuthData(
                userId: graphResult.userId ?? "",
                email: graphResult.email,
                name: graphResult.name,
                accessToken: token.tokenString
            )
            
            try await authenticateWithBackend(provider: .facebook, authData: authData)
        } catch {
            throw AuthError.unknown
        }
        */
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
        
        // Sign out from Google if needed
        // GIDSignIn.sharedInstance.signOut()  // TODO: Enable when GoogleSignIn is added
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
        if var user = currentUser {
            var updatedUser = user
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

enum AuthRequiredFeature {
    case basicRecipes
    case challenges
    case leaderboard
    case socialSharing
    case teams
    case streaks
    case premiumFeatures
    
    var title: String {
        switch self {
        case .basicRecipes: return "Basic Recipes"
        case .challenges: return "Challenges"
        case .leaderboard: return "Leaderboard"
        case .socialSharing: return "Social Sharing"
        case .teams: return "Teams"
        case .streaks: return "Streaks"
        case .premiumFeatures: return "Premium Features"
        }
    }
    
    var requiresAuth: Bool {
        switch self {
        case .basicRecipes:
            return false
        case .challenges, .leaderboard, .socialSharing, .teams, .streaks, .premiumFeatures:
            return true
        }
    }
}

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