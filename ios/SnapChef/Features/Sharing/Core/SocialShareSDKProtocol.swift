//
//  SocialShareSDKProtocol.swift
//  SnapChef
//
//  Protocol for all social media SDK integrations
//

import Foundation
import UIKit

// MARK: - Share Content Types

struct SDKShareContent {
    enum ContentType {
        case image(UIImage)
        case video(URL)
        case text(String)
        case link(URL)
        case multipleImages([UIImage])
    }
    
    let type: ContentType
    let caption: String?
    let hashtags: [String]?
    let mentionedUsers: [String]?
    
    init(type: ContentType, caption: String? = nil, hashtags: [String]? = nil, mentionedUsers: [String]? = nil) {
        self.type = type
        self.caption = caption
        self.hashtags = hashtags
        self.mentionedUsers = mentionedUsers
    }
}

// MARK: - Platform Types

enum SDKPlatform: String, CaseIterable {
    case tiktok = "TikTok"
    case instagram = "Instagram"
    case facebook = "Facebook"
    case twitter = "X"
    case snapchat = "Snapchat"
    case messages = "Messages"
    
    var iconName: String {
        switch self {
        case .tiktok: return "music.note"
        case .instagram: return "camera.fill"
        case .facebook: return "f.circle.fill"
        case .twitter: return "x.circle.fill"
        case .snapchat: return "ghost.fill"
        case .messages: return "message.fill"
        }
    }
    
    var brandColor: String {
        switch self {
        case .tiktok: return "#000000"
        case .instagram: return "#E4405F"
        case .facebook: return "#1877F2"
        case .twitter: return "#000000"
        case .snapchat: return "#FFFC00"
        case .messages: return "#34C759"
        }
    }
}

// MARK: - SDK Errors

enum SDKError: LocalizedError {
    case notConfigured
    case notInstalled
    case permissionDenied
    case contentTypeNotSupported
    case authenticationRequired
    case networkError
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "SDK is not properly configured"
        case .notInstalled:
            return "App is not installed on this device"
        case .permissionDenied:
            return "Permission was denied by the user"
        case .contentTypeNotSupported:
            return "This content type is not supported by the platform"
        case .authenticationRequired:
            return "Authentication is required to share"
        case .networkError:
            return "Network error occurred"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - SDK Protocol

@MainActor
protocol SocialShareSDKProtocol {
    /// Check if the platform app is installed and available
    func isAvailable() -> Bool
    
    /// Share content to the platform
    func share(content: SDKShareContent) async throws
    
    /// Authenticate user with the platform (optional)
    func authenticate() async throws -> Bool
    
    /// Get platform-specific configuration requirements
    func getConfigurationRequirements() -> [String: String]
}

// MARK: - SDK Manager

@MainActor
final class SocialSDKManager {
    static let shared = SocialSDKManager()
    
    private var sdks: [SDKPlatform: SocialShareSDKProtocol] = [:]
    
    private init() {}
    
    /// Register an SDK for a platform
    func register(platform: SDKPlatform, sdk: SocialShareSDKProtocol) {
        sdks[platform] = sdk
    }
    
    /// Check if a platform is available
    func isAvailable(platform: SDKPlatform) -> Bool {
        guard let sdk = sdks[platform] else { return false }
        return sdk.isAvailable()
    }
    
    /// Share content to a platform
    func share(to platform: SDKPlatform, content: SDKShareContent) async throws {
        guard let sdk = sdks[platform] else {
            throw SDKError.notConfigured
        }
        
        guard sdk.isAvailable() else {
            throw SDKError.notInstalled
        }
        
        try await sdk.share(content: content)
    }
    
    /// Authenticate with a platform
    func authenticate(platform: SDKPlatform) async throws -> Bool {
        guard let sdk = sdks[platform] else {
            throw SDKError.notConfigured
        }
        
        return try await sdk.authenticate()
    }
    
    /// Get all available platforms
    func getAvailablePlatforms() -> [SDKPlatform] {
        return SDKPlatform.allCases.filter { isAvailable(platform: $0) }
    }
}