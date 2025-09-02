import Foundation
import Security

/// Manages secure storage of sensitive data in the iOS Keychain
@MainActor
class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    // MARK: - Identifiers for secure storage
    private let apiKeyIdentifier = "com.snapchef.api.key"
    private let tiktokClientSecretIdentifier = "com.snapchef.tiktok.client.secret"
    private let googleClientIdIdentifier = "com.snapchef.google.client.id"
    private let authTokenIdentifier = "com.snapchef.auth.token"

    /// Stores the API key in the keychain
    func storeAPIKey(_ key: String) {
        // print("🔐 KeychainManager: Storing API key with length \(key.count)")
        let data = key.data(using: .utf8)!
        
        // First delete any existing item to ensure clean state
        deleteAPIKey()
        
        // Now add the new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKeyIdentifier,
            kSecAttrService as String: "com.snapchef.app", // Add service identifier
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        // print("🔐 KeychainManager: Add status = \(addStatus)")
        
        if addStatus == noErr {
            // print("✅ API key successfully stored in keychain")
        } else {
            print("❌ Failed to store API key, error code: \(addStatus)")
        }
    }

    /// Retrieves the API key from the keychain
    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKeyIdentifier,
            kSecAttrService as String: "com.snapchef.app", // Match service identifier
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        // print("🔐 KeychainManager: Get API key status = \(status)")

        if status == noErr {
            if let data = dataTypeRef as? Data,
               let key = String(data: data, encoding: .utf8) {
                // print("🔐 KeychainManager: Retrieved API key with length \(key.count)")
                return key
            }
        }
        
        // print("🔐 KeychainManager: No API key found in keychain")
        return nil
    }

    /// Deletes the API key from the keychain (if needed for testing)
    func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKeyIdentifier,
            kSecAttrService as String: "com.snapchef.app" // Match service identifier
        ]

        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus == noErr {
            // print("🔐 KeychainManager: Successfully deleted API key")
        } else if deleteStatus == errSecItemNotFound {
            // print("🔐 KeychainManager: No API key to delete")
        } else {
            // print("🔐 KeychainManager: Delete status = \(deleteStatus)")
        }
    }

    /// Ensures the API key is available from secure configuration
    func ensureAPIKeyExists() {
        if getAPIKey() == nil {
            // API key should be configured through secure means:
            // 1. Environment variables during build
            // 2. Server-side configuration fetch
            // 3. Manual configuration in app settings
            print("⚠️ WARNING: No API key found in keychain.")
            print("📋 Set SNAPCHEF_API_KEY environment variable in Xcode:")
            print("   Edit Scheme → Run → Arguments → Environment Variables")
        }
    }
    
    /// Rotates API key (useful if key is compromised)
    func rotateAPIKey(_ newKey: String) {
        deleteAPIKey()
        storeAPIKey(newKey)
        
        // Clear any cached network sessions
        URLSession.shared.configuration.urlCache?.removeAllCachedResponses()
        
        print("🔄 API key rotated successfully")
    }
    
    /// Checks if API key appears to be valid format
    func validateAPIKeyFormat() -> Bool {
        guard let key = getAPIKey() else { return false }
        
        // Basic validation: not empty, reasonable length, no spaces
        return !key.isEmpty &&
               key.count >= 20 &&
               key.count <= 100 &&
               !key.contains(" ") &&
               !key.contains("your-api-key-here") &&
               !key.contains("YOUR_API_KEY")
    }
    
    // MARK: - Generic Secure Storage Methods
    
    /// Store any sensitive string value securely in keychain
    func store(value: String, forKey identifier: String) -> Bool {
        let data = value.data(using: .utf8)!
        
        // First, try to update if it exists
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: data
        ]
        
        let updateStatus = SecItemUpdate(
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: identifier
            ] as CFDictionary,
            updateQuery as CFDictionary
        )
        
        // If update failed (item doesn't exist), add it
        if updateStatus == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: identifier,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            return SecItemAdd(addQuery as CFDictionary, nil) == noErr
        }
        
        return updateStatus == noErr
    }
    
    /// Retrieve any sensitive string value from keychain
    func getValue(forKey identifier: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == noErr {
            if let data = dataTypeRef as? Data,
               let value = String(data: data, encoding: .utf8) {
                return value
            }
        }
        
        return nil
    }
    
    /// Delete any value from keychain
    func deleteValue(forKey identifier: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier
        ]
        
        return SecItemDelete(query as CFDictionary) == noErr
    }
    
    // MARK: - Specific Secure Storage Methods
    
    /// Store TikTok client secret securely
    func storeTikTokClientSecret(_ secret: String) -> Bool {
        return store(value: secret, forKey: tiktokClientSecretIdentifier)
    }
    
    /// Retrieve TikTok client secret
    func getTikTokClientSecret() -> String? {
        return getValue(forKey: tiktokClientSecretIdentifier)
    }
    
    /// Store Google client ID securely
    func storeGoogleClientId(_ clientId: String) -> Bool {
        return store(value: clientId, forKey: googleClientIdIdentifier)
    }
    
    /// Retrieve Google client ID
    func getGoogleClientId() -> String? {
        return getValue(forKey: googleClientIdIdentifier)
    }
    
    /// Store authentication token securely
    func storeAuthToken(_ token: String) -> Bool {
        return store(value: token, forKey: authTokenIdentifier)
    }
    
    /// Retrieve authentication token
    func getAuthToken() -> String? {
        return getValue(forKey: authTokenIdentifier)
    }
    
    /// Delete authentication token (for logout)
    func deleteAuthToken() -> Bool {
        return deleteValue(forKey: authTokenIdentifier)
    }
    
    // MARK: - Security Audit Methods
    
    /// Check if all required secrets are configured
    func auditSecurityConfiguration() -> [String] {
        var missingSecrets: [String] = []
        
        if getAPIKey() == nil {
            missingSecrets.append("API Key")
        }
        
        if getTikTokClientSecret() == nil {
            missingSecrets.append("TikTok Client Secret")
        }
        
        if getGoogleClientId() == nil {
            missingSecrets.append("Google Client ID")
        }
        
        return missingSecrets
    }
    
    /// Clear all stored secrets (for security reset)
    func clearAllSecrets() {
        deleteAPIKey()
        _ = deleteValue(forKey: tiktokClientSecretIdentifier)
        _ = deleteValue(forKey: googleClientIdIdentifier)
        _ = deleteAuthToken()
    }
    
    /// Clear all keychain data (for account deletion)
    func clearAll() {
        clearAllSecrets()
        // Clear any additional keychain items
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.snapchef.app"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
