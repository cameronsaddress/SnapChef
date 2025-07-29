import Foundation
import UIKit
import CryptoKit
import AdSupport
import AppTrackingTransparency

@MainActor
class DeviceManager: ObservableObject {
    @Published var deviceId: String = ""
    @Published var freeUsesRemaining: Int = 7
    @Published var freeSavesRemaining: Int = 10 // Increased for testing
    @Published var hasUnlimitedAccess: Bool = false
    @Published var isBlocked: Bool = false
    
    private let keychain = KeychainService()
    private let deviceIdKey = "com.snapchef.deviceId"
    private let freeUsesKey = "com.snapchef.freeUses"
    private let freeSavesKey = "com.snapchef.freeSaves"
    
    init() {
        loadDeviceId()
        loadFreeSaves()
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
    
    private func loadFreeSaves() {
        let savedCount = UserDefaults.standard.integer(forKey: freeSavesKey)
        if savedCount > 0 {
            freeSavesRemaining = savedCount
        } else {
            // First time - set to 5 free saves
            freeSavesRemaining = 10
            UserDefaults.standard.set(5, forKey: freeSavesKey)
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
        
        // For development, mock the API response
        #if DEBUG
        // Simulate API delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Decrement the free uses locally
        DispatchQueue.main.async {
            self.freeUsesRemaining -= 1
            self.isBlocked = false
        }
        
        return true
        #else
        do {
            let response = try await NetworkManager.shared.consumeFreeUse(deviceId: deviceId)
            
            self.freeUsesRemaining = response.remainingUses
            self.isBlocked = response.isBlocked
            
            return !response.isBlocked && response.success
        } catch {
            print("Error consuming free use: \(error)")
            return false
        }
        #endif
    }
    
    func consumeFreeSave() async -> Bool {
        guard freeSavesRemaining > 0 else { return false }
        
        // For development, mock the API response
        #if DEBUG
        // Simulate API delay
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Decrement the free saves locally
        DispatchQueue.main.async {
            self.freeSavesRemaining -= 1
            UserDefaults.standard.set(self.freeSavesRemaining, forKey: self.freeSavesKey)
        }
        
        return true
        #else
        // In production, this would call the API
        DispatchQueue.main.async {
            self.freeSavesRemaining -= 1
            UserDefaults.standard.set(self.freeSavesRemaining, forKey: self.freeSavesKey)
        }
        return true
        #endif
    }
    
    private func fetchDeviceStatus() async {
        do {
            let status = try await NetworkManager.shared.getDeviceStatus(deviceId: deviceId)
            
            self.freeUsesRemaining = status.freeUsesRemaining
            self.isBlocked = status.isBlocked
            self.hasUnlimitedAccess = status.hasSubscription
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