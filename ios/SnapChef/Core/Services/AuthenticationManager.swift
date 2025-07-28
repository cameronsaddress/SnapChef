import SwiftUI
import AuthenticationServices
import GoogleSignIn

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var showAuthSheet: Bool = false
    
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
                DispatchQueue.main.async {
                    self.currentUser = user
                    self.isAuthenticated = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.keychain.delete(self.authTokenKey)
                    self.isAuthenticated = false
                }
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
    }
    
    private func authenticateWithBackend<T: Encodable>(provider: AuthProvider, authData: T) async throws {
        let response = try await NetworkManager.shared.authenticate(
            provider: provider,
            authData: authData
        )
        
        DispatchQueue.main.async {
            self.keychain.set(response.token, forKey: self.authTokenKey)
            self.currentUser = response.user
            self.isAuthenticated = true
            self.showAuthSheet = false
        }
    }
    
    func signOut() {
        keychain.delete(authTokenKey)
        currentUser = nil
        isAuthenticated = false
        
        // Sign out from Google if needed
        GIDSignIn.sharedInstance.signOut()
    }
    
    func promptForAuthIfNeeded(deviceManager: DeviceManager) {
        if !isAuthenticated && deviceManager.freeUsesRemaining == 0 && !deviceManager.hasUnlimitedAccess {
            showAuthSheet = true
        }
    }
}

enum AuthProvider: String {
    case apple = "apple"
    case google = "google"
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

struct AuthResponse: Decodable {
    let token: String
    let user: User
}