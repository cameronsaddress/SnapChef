import Foundation
import UIKit
import CryptoKit
import AdSupport
import AppTrackingTransparency

class DeviceManager: ObservableObject {
    @Published var deviceId: String = ""
    @Published var freeUsesRemaining: Int = 3
    @Published var hasUnlimitedAccess: Bool = false
    @Published var isBlocked: Bool = false
    
    private let keychain = KeychainService()
    private let deviceIdKey = "com.snapchef.deviceId"
    private let freeUsesKey = "com.snapchef.freeUses"
    
    init() {
        loadDeviceId()
    }
    
    func checkDeviceStatus() {
        Task {
            await fetchDeviceStatus()
        }
    }
    
    private func loadDeviceId() {
        if let existingId = keychain.get(deviceIdKey) {
            self.deviceId = existingId
        } else {
            self.deviceId = generateDeviceFingerprint()
            keychain.set(deviceId, forKey: deviceIdKey)
        }
    }
    
    private func generateDeviceFingerprint() -> String {
        var fingerprint = ""
        
        // Device model and OS version
        fingerprint += UIDevice.current.model
        fingerprint += UIDevice.current.systemVersion
        fingerprint += UIDevice.current.name
        
        // Screen resolution
        let screen = UIScreen.main
        fingerprint += "\(screen.bounds.width)x\(screen.bounds.height)"
        fingerprint += "\(screen.scale)"
        
        // Vendor ID (persists until app uninstall)
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            fingerprint += vendorId
        }
        
        // Locale and timezone
        fingerprint += Locale.current.identifier
        fingerprint += TimeZone.current.identifier
        
        // System uptime for additional entropy
        fingerprint += "\(ProcessInfo.processInfo.systemUptime)"
        
        // Create SHA256 hash
        let inputData = Data(fingerprint.utf8)
        let hashed = SHA256.hash(data: inputData)
        
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func consumeFreeUse() async -> Bool {
        guard freeUsesRemaining > 0 else { return false }
        
        do {
            let response = try await NetworkManager.shared.consumeFreeUse(deviceId: deviceId)
            
            DispatchQueue.main.async {
                self.freeUsesRemaining = response.remainingUses
                self.isBlocked = response.isBlocked
            }
            
            return !response.isBlocked && response.success
        } catch {
            print("Error consuming free use: \(error)")
            return false
        }
    }
    
    private func fetchDeviceStatus() async {
        do {
            let status = try await NetworkManager.shared.getDeviceStatus(deviceId: deviceId)
            
            DispatchQueue.main.async {
                self.freeUsesRemaining = status.freeUsesRemaining
                self.isBlocked = status.isBlocked
                self.hasUnlimitedAccess = status.hasSubscription
            }
        } catch {
            print("Error fetching device status: \(error)")
        }
    }
    
    func requestTrackingPermission() {
        ATTrackingManager.requestTrackingAuthorization { status in
            print("Tracking authorization status: \(status)")
        }
    }
}

// Keychain wrapper for secure storage
class KeychainService {
    func set(_ value: String, forKey key: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}