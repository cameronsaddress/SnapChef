import Foundation
import UIKit
import CryptoKit
import AdSupport
import AppTrackingTransparency

@MainActor
final class DeviceManager: ObservableObject {
    @Published var deviceId: String = ""
    @Published var freeUsesRemaining: Int = 3
    @Published var freeSavesRemaining: Int = 3
    @Published var hasUnlimitedAccess: Bool = false
    @Published var isBlocked: Bool = false
    
    // MARK: - Performance Settings
    @Published var isLowPowerModeEnabled: Bool = false
    @Published var animationsEnabled: Bool = true
    @Published var particleEffectsEnabled: Bool = true
    @Published var continuousAnimationsEnabled: Bool = true
    @Published var heavyEffectsEnabled: Bool = true

    private let keychain = KeychainService()
    private let deviceIdKey = "com.snapchef.deviceId"
    private let freeUsesKey = "com.snapchef.freeUses"
    private let freeSavesKey = "com.snapchef.freeSaves"
    private let defaultFreeUses = 3
    private let defaultFreeSaves = 3

    init() {
        loadDeviceId()
        loadFreeUses()
        loadFreeSaves()
        loadPerformanceSettings()
        setupLowPowerModeObserver()
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

    private func loadFreeUses() {
        let savedCount = UserDefaults.standard.object(forKey: freeUsesKey) as? Int
        if let savedCount {
            freeUsesRemaining = max(0, savedCount)
        } else {
            freeUsesRemaining = defaultFreeUses
            UserDefaults.standard.set(defaultFreeUses, forKey: freeUsesKey)
        }
    }

    private func loadFreeSaves() {
        let savedCount = UserDefaults.standard.object(forKey: freeSavesKey) as? Int
        if let savedCount {
            freeSavesRemaining = max(0, savedCount)
        } else {
            freeSavesRemaining = defaultFreeSaves
            UserDefaults.standard.set(defaultFreeSaves, forKey: freeSavesKey)
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

            self.freeUsesRemaining = response.remainingUses
            self.isBlocked = response.isBlocked
            UserDefaults.standard.set(self.freeUsesRemaining, forKey: self.freeUsesKey)

            return !response.isBlocked && response.success
        } catch {
            print("Error consuming free use from backend, falling back to local quota: \(error)")
            self.freeUsesRemaining = max(0, self.freeUsesRemaining - 1)
            self.isBlocked = self.freeUsesRemaining <= 0
            UserDefaults.standard.set(self.freeUsesRemaining, forKey: self.freeUsesKey)
            return !self.isBlocked
        }
    }

    func consumeFreeSave() async -> Bool {
        guard freeSavesRemaining > 0 else { return false }
        self.freeSavesRemaining -= 1
        UserDefaults.standard.set(self.freeSavesRemaining, forKey: self.freeSavesKey)
        return true
    }

    private func fetchDeviceStatus() async {
        do {
            let status = try await NetworkManager.shared.getDeviceStatus(deviceId: deviceId)

            self.freeUsesRemaining = max(0, status.freeUsesRemaining)
            self.isBlocked = status.isBlocked
            self.hasUnlimitedAccess = status.hasSubscription
            UserDefaults.standard.set(self.freeUsesRemaining, forKey: self.freeUsesKey)
        } catch {
            print("Error fetching device status: \(error)")
            // Keep local quota state when backend status is unavailable.
            self.isBlocked = self.freeUsesRemaining <= 0
        }
    }

    func requestTrackingPermission() {
        ATTrackingManager.requestTrackingAuthorization { status in
            print("Tracking authorization status: \(status)")
        }
    }
    
    // MARK: - Performance Management
    
    private func loadPerformanceSettings() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        animationsEnabled = UserDefaults.standard.object(forKey: "animationsEnabled") as? Bool ?? true
        particleEffectsEnabled = UserDefaults.standard.object(forKey: "particleEffectsEnabled") as? Bool ?? true
        continuousAnimationsEnabled = UserDefaults.standard.object(forKey: "continuousAnimationsEnabled") as? Bool ?? true
        heavyEffectsEnabled = UserDefaults.standard.object(forKey: "heavyEffectsEnabled") as? Bool ?? true
        
        // Auto-disable heavy effects in low power mode
        if isLowPowerModeEnabled {
            applyLowPowerModeSettings()
        }
    }
    
    private func setupLowPowerModeObserver() {
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePowerStateChange()
            }
        }
    }
    
    private func handlePowerStateChange() {
        let wasLowPowerMode = isLowPowerModeEnabled
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        if isLowPowerModeEnabled && !wasLowPowerMode {
            applyLowPowerModeSettings()
        } else if !isLowPowerModeEnabled && wasLowPowerMode {
            restoreNormalModeSettings()
        }
    }
    
    private func applyLowPowerModeSettings() {
        particleEffectsEnabled = false
        continuousAnimationsEnabled = false
        heavyEffectsEnabled = false
        
        // Save low power state overrides
        UserDefaults.standard.set(false, forKey: "particleEffectsEnabled_lowPower")
        UserDefaults.standard.set(false, forKey: "continuousAnimationsEnabled_lowPower")
        UserDefaults.standard.set(false, forKey: "heavyEffectsEnabled_lowPower")
    }
    
    private func restoreNormalModeSettings() {
        // Restore previous settings or defaults
        particleEffectsEnabled = UserDefaults.standard.object(forKey: "particleEffectsEnabled") as? Bool ?? true
        continuousAnimationsEnabled = UserDefaults.standard.object(forKey: "continuousAnimationsEnabled") as? Bool ?? true
        heavyEffectsEnabled = UserDefaults.standard.object(forKey: "heavyEffectsEnabled") as? Bool ?? true
    }
    
    func setAnimationsEnabled(_ enabled: Bool) {
        animationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "animationsEnabled")
    }
    
    func setParticleEffectsEnabled(_ enabled: Bool) {
        particleEffectsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "particleEffectsEnabled")
    }
    
    func setContinuousAnimationsEnabled(_ enabled: Bool) {
        continuousAnimationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "continuousAnimationsEnabled")
    }
    
    func setHeavyEffectsEnabled(_ enabled: Bool) {
        heavyEffectsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "heavyEffectsEnabled")
    }
    
    // Performance utility methods
    var shouldShowParticles: Bool {
        return particleEffectsEnabled && !isLowPowerModeEnabled
    }
    
    var shouldUseContinuousAnimations: Bool {
        return continuousAnimationsEnabled && !isLowPowerModeEnabled
    }
    
    var shouldUseHeavyEffects: Bool {
        return heavyEffectsEnabled && !isLowPowerModeEnabled
    }
    
    var recommendedParticleCount: Int {
        if isLowPowerModeEnabled { return 0 }
        if !particleEffectsEnabled { return 0 }
        if !heavyEffectsEnabled { return 5 }
        return 15 // Normal count
    }
    
    var recommendedAnimationDuration: Double {
        if isLowPowerModeEnabled { return 0.1 }
        if !animationsEnabled { return 0.0 }
        return 0.3 // Normal duration
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
