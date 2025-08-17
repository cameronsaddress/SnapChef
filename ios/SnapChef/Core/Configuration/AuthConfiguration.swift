import Foundation

struct AuthConfiguration {
    // Google Sign-In Configuration (Not implemented in production)
    // Google Sign-In is not available - Apple Sign-In is the primary authentication method

    // Facebook App Configuration (Not implemented in production)
    // Facebook SDK is not available - Apple Sign-In is the primary authentication method
    static let facebookDisplayName = "SnapChef"

    // Apple Sign-In Configuration
    // No additional configuration needed - uses bundle identifier

    // Backend API Configuration
    static let authEndpoint = "\(NetworkConfiguration.baseURL)/auth"

    // User Data Storage
    struct UserData {
        static let noPasswordStored = true // We never store passwords
        static let minUsernameLength = 3
        static let maxUsernameLength = 20
        static let usernameRegex = "^[a-zA-Z0-9_]+$"
    }

    // Features that require authentication
    struct RequiresAuth {
        static let challenges = true
        static let leaderboard = true
        static let socialSharing = true
        static let teams = true
        static let streaks = true
        static let premiumFeatures = true
        static let basicRecipes = false // Free to use without auth
    }
}
