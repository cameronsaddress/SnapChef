import Foundation
import SwiftUI
import TikTokOpenAuthSDK
import TikTokOpenSDKCore
import os

// Import the TikTokAuthManager if needed for proper reference
// This helps with the compilation when TikTokContentPostingAPI references it

/// TikTok OAuth Authentication Manager
/// Handles TikTok OAuth flow with secure token storage and user profile management
@MainActor
final class TikTokAuthManager: ObservableObject, @unchecked Sendable {
    // MARK: - Singleton
    static let shared: TikTokAuthManager = {
        let instance = TikTokAuthManager()
        return instance
    }()

    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var currentUser: TikTokUser?
    @Published var showError = false
    @Published var errorMessage = ""

    // MARK: - Private Properties
    private let keychainKey = "com.snapchef.tiktok.tokens"
    private let redirectURI = "snapchef://tiktok-auth-callback"

    // TikTok OAuth Configuration
    private var clientID: String {
        return Bundle.main.object(forInfoDictionaryKey: "TikTokClientKey") as? String ?? ""
    }

    private var clientSecret: String {
        return Bundle.main.object(forInfoDictionaryKey: "TikTokClientSecret") as? String ?? ""
    }

    // OAuth URLs
    private let authBaseURL = "https://www.tiktok.com/v2/auth/authorize/"
    private let tokenURL = "https://open.tiktokapis.com/v2/oauth/token/"
    private let refreshURL = "https://open.tiktokapis.com/v2/oauth/token/"
    private let userInfoURL = "https://open.tiktokapis.com/v2/user/info/"

    // OAuth Scopes
    private let requiredScopes: Set<String> = [
        "user.info.basic",
        "video.publish",
        "video.upload"
    ]

    // MARK: - Initialization
    private init() {
        loadStoredTokens()
    }

    // MARK: - Public Authentication Methods

    /// Initiates TikTok OAuth authentication flow
    /// - Returns: TikTokUser if authentication succeeds
    func authenticate() async throws -> TikTokUser {
        isLoading = true
        defer { isLoading = false }

        return try await withCheckedThrowingContinuation { continuation in
            let authRequest = TikTokAuthRequest(
                scopes: requiredScopes,
                redirectURI: redirectURI
            )

            authRequest.send { [weak self] response in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume(throwing: TikTokAuthError.authenticationFailed)
                        return
                    }

                    if let authResponse = response as? TikTokAuthResponse {
                        do {
                            let user = try await self.handleAuthResponse(authResponse)
                            continuation.resume(returning: user)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    } else {
                        continuation.resume(throwing: TikTokAuthError.authenticationFailed)
                    }
                }
            }
        }
    }

    /// Refreshes the current access token with retry logic
    /// - Parameter maxRetries: Maximum number of retry attempts
    /// - Throws: TikTokAuthError if refresh fails after all retries
    func refreshToken(maxRetries: Int = 3) async throws {
        guard let tokens = getStoredTokens(),
              let refreshToken = tokens.refreshToken else {
            throw TikTokAuthError.noRefreshToken
        }

        isLoading = true
        defer { isLoading = false }

        let parameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret
        ]

        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                let tokenResponse: TokenResponse = try await performTokenRequest(parameters: parameters)

                let newTokens = TikTokTokens(
                    accessToken: tokenResponse.access_token,
                    refreshToken: tokenResponse.refresh_token ?? refreshToken,
                    expiresIn: tokenResponse.expires_in,
                    tokenType: tokenResponse.token_type,
                    scope: tokenResponse.scope,
                    createdAt: Date()
                )

                storeTokens(newTokens)

                // Fetch updated user profile
                let user = try await fetchUserProfile(accessToken: tokenResponse.access_token)
                await updateUserProfile(user)

                return // Success!

            } catch {
                lastError = error

                // If this is a 401 or 403, the refresh token is invalid - don't retry
                if let urlError = error as? URLError {
                    if urlError.code == .userAuthenticationRequired {
                        break
                    }
                } else if error.localizedDescription.contains("401") ||
                          error.localizedDescription.contains("403") ||
                          error.localizedDescription.contains("invalid_grant") {
                    break
                }

                // Wait before retrying (exponential backoff)
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt)) // 2, 4, 8 seconds
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // All retries failed, clear tokens and throw error
        clearStoredTokens()
        await MainActor.run {
            self.isAuthenticated = false
            self.currentUser = nil
        }

        throw TikTokAuthError.tokenRefreshFailed
    }

    /// Signs out the current user
    func logout() {
        currentUser = nil
        isAuthenticated = false
        clearStoredTokens()

        // Also clear from CloudKit if integrated
        if CloudKitAuthManager.shared.currentUser != nil {
            Task {
                do {
                    try await clearTikTokIntegration()
                } catch {
                    // Log error but don't fail logout
                    os_log("Failed to clear TikTok integration from CloudKit: %@", log: .default, type: .error, error.localizedDescription)
                }
            }
        }
    }

    /// Checks if user is currently authenticated
    /// - Returns: Boolean indicating authentication status
    func isAuthenticatedUser() -> Bool {
        guard let tokens = getStoredTokens() else { return false }
        return !isTokenExpired(tokens)
    }

    /// Checks if the access token is expired or near expiry
    /// - Parameter tokens: TikTok tokens to check
    /// - Returns: True if token is expired or will expire within 5 minutes
    func isTokenExpired(_ tokens: TikTokTokens) -> Bool {
        let expirationDate = tokens.createdAt.addingTimeInterval(TimeInterval(tokens.expiresIn))
        let bufferTime: TimeInterval = 300 // 5 minutes buffer
        return Date() > expirationDate.addingTimeInterval(-bufferTime)
    }

    /// Ensures we have a valid access token, refreshing if necessary
    /// - Returns: Valid access token
    /// - Throws: TikTokAuthError if unable to get valid token
    func ensureValidToken() async throws -> String {
        guard let tokens = getStoredTokens() else {
            throw TikTokAuthError.notAuthenticated
        }

        // If token is expired or near expiry, try to refresh
        if isTokenExpired(tokens) {
            if tokens.refreshToken != nil {
                try await refreshToken()
                guard let refreshedTokens = getStoredTokens() else {
                    throw TikTokAuthError.tokenRefreshFailed
                }
                return refreshedTokens.accessToken
            } else {
                // No refresh token, clear stored tokens and require re-authentication
                clearStoredTokens()
                await MainActor.run {
                    self.isAuthenticated = false
                    self.currentUser = nil
                }
                throw TikTokAuthError.tokenExpiredNoRefresh
            }
        }

        return tokens.accessToken
    }
    
    /// Get current tokens (public accessor for TikTokShareView)
    /// - Returns: Current TikTok tokens if available
    public func getCurrentTokens() -> TikTokTokens? {
        return getStoredTokens()
    }

    /// Fetches current user profile
    /// - Returns: TikTokUser if successful
    func getUserProfile() async throws -> TikTokUser {
        guard let tokens = getStoredTokens() else {
            throw TikTokAuthError.notAuthenticated
        }

        // Check if token needs refresh
        let expirationDate = tokens.createdAt.addingTimeInterval(TimeInterval(tokens.expiresIn))
        if Date() > expirationDate {
            try await refreshToken()
            guard let refreshedTokens = getStoredTokens() else {
                throw TikTokAuthError.notAuthenticated
            }
            return try await fetchUserProfile(accessToken: refreshedTokens.accessToken)
        }

        return try await fetchUserProfile(accessToken: tokens.accessToken)
    }

    // MARK: - Private Helper Methods

    /// Handles the OAuth response from TikTok
    private func handleAuthResponse(_ response: TikTokAuthResponse) async throws -> TikTokUser {
        guard response.errorCode == .noError,
              let authCode = response.authCode else {
            throw TikTokAuthError.authenticationFailed
        }

        // Exchange authorization code for access token
        let tokenResponse = try await exchangeCodeForToken(authCode: authCode)

        // Store tokens securely
        let tokens = TikTokTokens(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token,
            expiresIn: tokenResponse.expires_in,
            tokenType: tokenResponse.token_type,
            scope: tokenResponse.scope,
            createdAt: Date()
        )
        storeTokens(tokens)

        // Fetch user profile
        let user = try await fetchUserProfile(accessToken: tokenResponse.access_token)
        await updateUserProfile(user)

        // Update CloudKit integration if user is authenticated
        await updateCloudKitIntegration(user: user)

        return user
    }

    /// Exchanges authorization code for access token
    private func exchangeCodeForToken(authCode: String) async throws -> TokenResponse {
        let parameters = [
            "grant_type": "authorization_code",
            "code": authCode,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "client_secret": clientSecret
        ]

        return try await performTokenRequest(parameters: parameters)
    }

    /// Performs token request to TikTok API with enhanced error handling
    private func performTokenRequest(parameters: [String: String]) async throws -> TokenResponse {
        guard let url = URL(string: tokenURL) else {
            throw TikTokAuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        // Convert parameters to URL encoded string
        let paramString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = paramString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TikTokAuthError.tokenRequestFailed
        }

        // Enhanced error handling for different status codes
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401:
            throw TikTokAuthError.refreshTokenInvalid
        case 400:
            // Parse error response for more details
            if let errorData = try? JSONDecoder().decode(TikTokErrorResponse.self, from: data) {
                throw TikTokAuthError.tokenRequestFailedWithDetails(errorData.error_description ?? "Bad request")
            }
            throw TikTokAuthError.tokenRequestFailed
        case 429:
            throw TikTokAuthError.rateLimited
        default:
            throw TikTokAuthError.tokenRequestFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse
    }

    /// Fetches user profile from TikTok API
    private func fetchUserProfile(accessToken: String) async throws -> TikTokUser {
        guard let url = URL(string: userInfoURL) else {
            throw TikTokAuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TikTokAuthError.userProfileFetchFailed
        }

        let userResponse = try JSONDecoder().decode(UserInfoResponse.self, from: data)
        return TikTokUser(from: userResponse.data)
    }

    /// Updates the current user profile
    private func updateUserProfile(_ user: TikTokUser) async {
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }

    /// Updates CloudKit with TikTok integration
    private func updateCloudKitIntegration(user: TikTokUser) async {
        guard let cloudKitUser = CloudKitAuthManager.shared.currentUser else { return }

        // Store TikTok user info in CloudKit user profile
        // This would require adding TikTok fields to the CloudKit User schema
        // For now, we'll just log the integration
        os_log("TikTok authenticated for CloudKit user: %@", log: .default, type: .info, cloudKitUser.displayName)
        os_log("TikTok user: %@", log: .default, type: .info, user.displayName)
    }

    /// Clears TikTok integration from CloudKit
    private func clearTikTokIntegration() async throws {
        // This would update CloudKit to remove TikTok integration
        // Implementation would depend on CloudKit schema updates
        os_log("Clearing TikTok integration from CloudKit", log: .default, type: .info)
    }

    // MARK: - Token Storage Methods

    /// Stores tokens securely in Keychain
    private func storeTokens(_ tokens: TikTokTokens) {
        do {
            let data = try JSONEncoder().encode(tokens)

            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: keychainKey,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]

            // Delete existing item
            SecItemDelete(query as CFDictionary)

            // Add new item
            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess {
                os_log("Failed to store TikTok tokens: %d", log: .default, type: .error, status)
            }
        } catch {
            os_log("Failed to encode TikTok tokens: %@", log: .default, type: .error, error.localizedDescription)
        }
    }

    /// Retrieves stored tokens from Keychain
    private func getStoredTokens() -> TikTokTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess,
              let data = dataTypeRef as? Data else {
            return nil
        }

        do {
            return try JSONDecoder().decode(TikTokTokens.self, from: data)
        } catch {
            os_log("Failed to decode stored TikTok tokens: %@", log: .default, type: .error, error.localizedDescription)
            return nil
        }
    }

    /// Loads stored tokens and updates authentication state
    private func loadStoredTokens() {
        if let tokens = getStoredTokens() {
            let expirationDate = tokens.createdAt.addingTimeInterval(TimeInterval(tokens.expiresIn))
            if Date() < expirationDate {
                isAuthenticated = true

                // Fetch current user profile
                Task {
                    do {
                        let user = try await fetchUserProfile(accessToken: tokens.accessToken)
                        await updateUserProfile(user)
                    } catch {
                        // Token might be invalid, try refresh if available
                        if tokens.refreshToken != nil {
                            do {
                                try await refreshToken()
                            } catch {
                                await MainActor.run {
                                    self.isAuthenticated = false
                                }
                            }
                        } else {
                            await MainActor.run {
                                self.isAuthenticated = false
                            }
                        }
                    }
                }
            }
        }
    }

    /// Clears stored tokens from Keychain
    private func clearStoredTokens() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Data Models

/// TikTok OAuth tokens
struct TikTokTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let scope: String
    let createdAt: Date
}

/// TikTok token response from API
struct TokenResponse: Codable, Sendable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let token_type: String
    let scope: String
}

/// TikTok user info response
struct UserInfoResponse: Codable, Sendable {
    let data: UserData

    struct UserData: Codable, Sendable {
        let user: UserInfo

        struct UserInfo: Codable, Sendable {
            let open_id: String
            let union_id: String?
            let avatar_url: String?
            let avatar_url_100: String?
            let avatar_large_url: String?
            let display_name: String
            let bio_description: String?
            let profile_deep_link: String?
            let is_verified: Bool?
            let follower_count: Int?
            let following_count: Int?
            let likes_count: Int?
            let video_count: Int?
        }
    }
}

/// TikTok error response model
struct TikTokErrorResponse: Codable, Sendable {
    let error: String?
    let error_description: String?
    let error_code: Int?
}

/// TikTok user model
struct TikTokUser: Identifiable, Codable, Sendable {
    let id = UUID()
    let openID: String
    let unionID: String?
    let displayName: String
    let avatarURL: String?
    let avatarURL100: String?
    let avatarLargeURL: String?
    let bioDescription: String?
    let profileDeepLink: String?
    let isVerified: Bool
    let followerCount: Int
    let followingCount: Int
    let likesCount: Int
    let videoCount: Int

    init(from userData: UserInfoResponse.UserData) {
        self.openID = userData.user.open_id
        self.unionID = userData.user.union_id
        self.displayName = userData.user.display_name
        self.avatarURL = userData.user.avatar_url
        self.avatarURL100 = userData.user.avatar_url_100
        self.avatarLargeURL = userData.user.avatar_large_url
        self.bioDescription = userData.user.bio_description
        self.profileDeepLink = userData.user.profile_deep_link
        self.isVerified = userData.user.is_verified ?? false
        self.followerCount = userData.user.follower_count ?? 0
        self.followingCount = userData.user.following_count ?? 0
        self.likesCount = userData.user.likes_count ?? 0
        self.videoCount = userData.user.video_count ?? 0
    }
}

// MARK: - Error Types

enum TikTokAuthError: LocalizedError, Sendable {
    case authenticationFailed
    case invalidURL
    case tokenRequestFailed
    case tokenRequestFailedWithDetails(String)
    case userProfileFetchFailed
    case notAuthenticated
    case noRefreshToken
    case tokenRefreshFailed
    case tokenExpiredNoRefresh
    case refreshTokenInvalid
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "TikTok authentication failed. Please try signing in again."
        case .invalidURL:
            return "Invalid TikTok API URL"
        case .tokenRequestFailed:
            return "Failed to obtain access token"
        case .tokenRequestFailedWithDetails(let details):
            return "Failed to obtain access token: \(details)"
        case .userProfileFetchFailed:
            return "Failed to fetch user profile"
        case .notAuthenticated:
            return "Please sign in to TikTok to continue"
        case .noRefreshToken:
            return "No refresh token available"
        case .tokenRefreshFailed:
            return "Your TikTok session has expired. Please sign in again."
        case .tokenExpiredNoRefresh:
            return "Your TikTok session has expired. Please sign in again."
        case .refreshTokenInvalid:
            return "Your TikTok session is no longer valid. Please sign in again."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        }
    }

    var requiresReAuthentication: Bool {
        switch self {
        case .tokenExpiredNoRefresh, .refreshTokenInvalid, .tokenRefreshFailed, .notAuthenticated:
            return true
        default:
            return false
        }
    }
}