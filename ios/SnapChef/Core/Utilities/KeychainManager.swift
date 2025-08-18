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
        let data = key.data(using: .utf8)!

        // First, try to update if it exists
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKeyIdentifier,
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: apiKeyIdentifier
            ] as CFDictionary,
            updateQuery as CFDictionary
        )

        // If update failed (item doesn't exist), add it
        if updateStatus == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: apiKeyIdentifier,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]

            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    /// Retrieves the API key from the keychain
    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKeyIdentifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == noErr {
            if let data = dataTypeRef as? Data,
               let key = String(data: data, encoding: .utf8) {
                return key
            }
        }

        return nil
    }

    /// Deletes the API key from the keychain (if needed for testing)
    func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKeyIdentifier
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Ensures the API key is available from secure configuration
    func ensureAPIKeyExists() {
        if getAPIKey() == nil {
            // API key should be configured through secure means:
            // 1. Environment variables during build
            // 2. Server-side configuration fetch
            // 3. Manual configuration in app settings
            print("⚠️ WARNING: No API key found in keychain. Configure API key through secure means.")
            print("📋 Use storeAPIKey(_:) method to securely store your API key.")
        }
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
}
