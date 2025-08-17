//
//  KeychainProfileManager.swift
//  SnapChef
//
//  Created by Claude on 2025-01-16.
//  Progressive Authentication Implementation
//

import Foundation
import Security

/// Secure storage manager for anonymous user profiles using iOS Keychain
/// Handles persistence, encryption, and migration of user data
@MainActor
final class KeychainProfileManager: @unchecked Sendable {
    // MARK: - Singleton

    static let shared = KeychainProfileManager()

    // MARK: - Constants

    private let serviceName = "com.snapchef.profile"
    private let accountName = "anonymous_profile"
    private let accessGroup: String? = nil // Can be set for app group sharing

    // MARK: - Private Initialization

    private init() {}

    // MARK: - Public Interface

    /// Saves an anonymous user profile to the Keychain
    /// - Parameter profile: The profile to save
    /// - Returns: True if save was successful, false otherwise
    func saveProfile(_ profile: AnonymousUserProfile) -> Bool {
        do {
            // Encode profile to JSON data
            let profileData = try JSONEncoder().encode(profile)

            // Create Keychain query
            let query = createKeychainQuery()

            // Check if item already exists
            if keychainItemExists() {
                // Update existing item
                let attributesToUpdate: [String: Any] = [
                    kSecValueData as String: profileData
                ]

                let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

                if status == errSecSuccess {
                    return true
                } else {
                    return false
                }
            } else {
                // Add new item
                var addQuery = query
                addQuery[kSecValueData as String] = profileData

                let status = SecItemAdd(addQuery as CFDictionary, nil)

                if status == errSecSuccess {
                    return true
                } else {
                    return false
                }
            }
        } catch {
            return false
        }
    }

    /// Loads the anonymous user profile from the Keychain
    /// - Returns: The stored profile, or nil if none exists or error occurred
    func loadProfile() -> AnonymousUserProfile? {
        let query = createKeychainQuery()
        var queryResult: AnyObject?

        // Add return data attribute
        var loadQuery = query
        loadQuery[kSecReturnData as String] = true
        loadQuery[kSecMatchLimit as String] = kSecMatchLimitOne

        let status = SecItemCopyMatching(loadQuery as CFDictionary, &queryResult)

        guard status == errSecSuccess else {
            return nil
        }

        guard let profileData = queryResult as? Data else {
            return nil
        }

        do {
            let profile = try JSONDecoder().decode(AnonymousUserProfile.self, from: profileData)
            return profile
        } catch {
            return nil
        }
    }

    /// Deletes the anonymous user profile from the Keychain
    /// - Returns: True if deletion was successful, false otherwise
    func deleteProfile() -> Bool {
        let query = createKeychainQuery()
        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            return true
        } else {
            return false
        }
    }

    /// Migrates anonymous profile data when user authenticates
    /// Updates the profile state and optionally changes the account identifier
    /// - Parameter userID: The authenticated user's ID
    func migrateToAuthenticated(userID: String) {
        guard var profile = loadProfile() else {
            return
        }

        // Update authentication state
        profile.authenticationState = .authenticated
        profile.addAuthPromptEvent(context: "migration", action: "completed")

        // Save updated profile
        _ = saveProfile(profile)

        // Note: In a more complex implementation, you might want to:
        // 1. Create a new Keychain entry with user-specific account name
        // 2. Transfer data to CloudKit
        // 3. Delete the anonymous profile after successful migration
        // 4. Handle migration rollback on failure
    }

    // MARK: - Helper Methods

    /// Creates the base Keychain query dictionary
    /// - Returns: Dictionary with Keychain query parameters
    private func createKeychainQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Add access group if specified (for app group sharing)
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    /// Checks if a Keychain item already exists
    /// - Returns: True if item exists, false otherwise
    private func keychainItemExists() -> Bool {
        let query = createKeychainQuery()
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Profile Management Extensions

extension KeychainProfileManager {
    /// Creates a new anonymous profile if none exists
    /// - Returns: New or existing profile
    func getOrCreateProfile() -> AnonymousUserProfile {
        if let existingProfile = loadProfile() {
            return existingProfile
        } else {
            let newProfile = AnonymousUserProfile()
            _ = saveProfile(newProfile)
            return newProfile
        }
    }

    /// Updates specific profile metrics safely
    /// - Parameter updater: Closure that modifies the profile
    /// - Returns: True if update was successful
    func updateProfile(_ updater: (inout AnonymousUserProfile) -> Void) -> Bool {
        guard var profile = loadProfile() else {
            return false
        }

        updater(&profile)
        return saveProfile(profile)
    }

    /// Safely increments a counter in the profile
    /// - Parameter keyPath: KeyPath to the counter to increment
    /// - Returns: True if increment was successful
    func incrementCounter(_ keyPath: WritableKeyPath<AnonymousUserProfile, Int>) -> Bool {
        return updateProfile { profile in
            profile[keyPath: keyPath] += 1
            profile.updateLastActive()
        }
    }

    /// Adds an authentication prompt event to the profile
    /// - Parameters:
    ///   - context: Context where prompt was shown
    ///   - action: Action taken by user
    /// - Returns: True if event was recorded successfully
    func recordAuthPromptEvent(context: String, action: String) -> Bool {
        return updateProfile { profile in
            profile.addAuthPromptEvent(context: context, action: action)
        }
    }

    /// Updates the authentication state of the profile
    /// - Parameter state: New authentication state
    /// - Returns: True if state was updated successfully
    func updateAuthenticationState(_ state: AnonymousUserProfile.AuthenticationState) -> Bool {
        return updateProfile { profile in
            profile.authenticationState = state
        }
    }
}

// MARK: - Analytics Extensions

extension KeychainProfileManager {
    /// Gets analytics data from the stored profile
    /// - Returns: Dictionary with analytics metrics
    func getAnalyticsData() -> [String: Any] {
        guard let profile = loadProfile() else {
            return [:]
        }

        return [
            "deviceID": profile.deviceID.uuidString,
            "daysSinceFirstLaunch": profile.daysSinceFirstLaunch,
            "daysSinceLastActive": profile.daysSinceLastActive,
            "appOpenCount": profile.appOpenCount,
            "recipesCreatedCount": profile.recipesCreatedCount,
            "videosGeneratedCount": profile.videosGeneratedCount,
            "videosSharedCount": profile.videosSharedCount,
            "engagementScore": profile.engagementScore,
            "authenticationState": profile.authenticationState.rawValue,
            "totalPromptEvents": profile.authPromptHistory.count,
            "hasShownSocialInterest": profile.hasShownSocialInterest,
            "hasShownGamificationInterest": profile.hasShownGamificationInterest,
            "isInOptimalAuthWindow": profile.isInOptimalAuthWindow
        ]
    }

    /// Exports profile data for debugging or support
    /// - Returns: JSON string of profile data
    func exportProfileData() -> String? {
        guard let profile = loadProfile() else {
            return nil
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(profile)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

// MARK: - Debugging Extensions

#if DEBUG
extension KeychainProfileManager {
    /// Prints detailed profile information for debugging
    func debugPrintProfile() {
        guard let profile = loadProfile() else {
            return
        }

        print("🐛 KeychainProfileManager Debug Info:")
        print("   Device ID: \(profile.deviceID)")
        print("   First Launch: \(profile.firstLaunchDate)")
        print("   Days Since First Launch: \(profile.daysSinceFirstLaunch)")
        print("   App Opens: \(profile.appOpenCount)")
        print("   Recipes Created: \(profile.recipesCreatedCount)")
        print("   Videos Generated: \(profile.videosGeneratedCount)")
        print("   Videos Shared: \(profile.videosSharedCount)")
        print("   Engagement Score: \(String(format: "%.2f", profile.engagementScore))")
        print("   Auth State: \(profile.authenticationState.rawValue)")
        print("   Prompt Events: \(profile.authPromptHistory.count)")
        print("   In Optimal Auth Window: \(profile.isInOptimalAuthWindow)")
    }

    /// Resets the profile for testing purposes
    func resetProfileForTesting() {
        _ = deleteProfile()
        _ = getOrCreateProfile()
    }
}
#endif
