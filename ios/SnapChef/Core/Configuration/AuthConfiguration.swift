import Foundation

struct AuthConfiguration {
    // Google Sign-In Configuration
    static let googleClientID = "YOUR_GOOGLE_CLIENT_ID" // TODO: Add from Google Cloud Console
    
    // Facebook App Configuration
    static let facebookAppID = "YOUR_FACEBOOK_APP_ID" // TODO: Add from Facebook Developer Console
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