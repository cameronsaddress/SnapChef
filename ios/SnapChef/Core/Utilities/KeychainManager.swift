import Foundation
import Security

/// Manages secure storage of sensitive data in the iOS Keychain
@MainActor
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    private let apiKeyIdentifier = "com.snapchef.api.key"
    
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
    
    /// Ensures the API key is available, storing the default if not present
    func ensureAPIKeyExists() {
        if getAPIKey() == nil {
            // Store the default API key on first launch
            storeAPIKey("5380e4b60818cf237678fccfd4b8f767d1c94")
        }
    }
}