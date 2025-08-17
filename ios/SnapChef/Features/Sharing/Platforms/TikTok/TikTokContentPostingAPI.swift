//
//  TikTokContentPostingAPI.swift
//  SnapChef
//
//  TikTok Content Posting API Service - Direct Post with caption/hashtags support
//  Implements TikTok's Content Posting API for automated video uploads
//

import Foundation
import UIKit
import Network

/// TikTok Content Posting API Service for Direct Post functionality
/// Supports video uploads with captions, hashtags, and URL sharing methods
@MainActor
public final class TikTokContentPostingAPI: ObservableObject {
    // MARK: - Singleton
    public static let shared = TikTokContentPostingAPI()

    // MARK: - Published Properties
    @Published public var isUploading = false
    @Published public var uploadProgress: Double = 0.0
    @Published public var lastError: TikTokAPIError?

    // MARK: - API Configuration
    private let baseURL = "https://open.tiktokapis.com"
    private let apiVersion = "v2"
    private var accessToken: String?
    private var clientKey: String = "YOUR_CLIENT_KEY" // Should be stored securely

    // MARK: - Network Session
    private let session: URLSession
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        // Configure URLSession for API calls
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 300.0 // 5 minutes for video uploads
        self.session = URLSession(configuration: config)

        // Start network monitoring
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Authentication

    /// Set OAuth access token for API calls
    public func setAccessToken(_ token: String) {
        self.accessToken = token
    }

    /// Check if we have a valid access token
    public var hasValidToken: Bool {
        return accessToken != nil && !accessToken!.isEmpty
    }

    /// Ensures we have a valid access token, refreshing if necessary
    /// - Returns: Valid access token
    /// - Throws: TikTokAPIError if unable to get valid token
    private func ensureValidToken() async throws -> String {
        // Delegate to TikTokAuthManager for proper token management
        return try await TikTokAuthManager.shared.ensureValidToken()
    }

    // MARK: - Caption Builder

    /// Build TikTok caption with hashtags, text, and link
    /// - Parameters:
    ///   - text: Base caption text
    ///   - hashtags: Array of hashtags (without # prefix)
    ///   - appLink: Optional app store link
    /// - Returns: Formatted caption string (max 2200 UTF-16 characters)
    public func buildCaption(text: String, hashtags: [String], appLink: String? = nil) -> String {
        var caption = text

        // Add hashtags
        if !hashtags.isEmpty {
            let hashtagString = hashtags.map { "#\($0)" }.joined(separator: " ")
            caption += "\n\n\(hashtagString)"
        }

        // Add app link if provided
        if let link = appLink {
            caption += "\n\n📱 \(link)"
        }

        // Ensure we don't exceed TikTok's caption limit (2_200 UTF-16 characters)
        if caption.utf16.count > 2_200 {
            let maxLength = 2_200 - (appLink?.count ?? 0) - 10 // Reserve space for link + ellipsis
            let truncatedText = String(caption.prefix(maxLength))
            caption = truncatedText + "..."

            if let link = appLink {
                caption += "\n\n📱 \(link)"
            }
        }

        return caption
    }

    /// Parse hashtags automatically from title field
    /// - Parameter title: Recipe title or content title
    /// - Returns: Array of relevant hashtags
    public func parseHashtagsFromTitle(_ title: String) -> [String] {
        var hashtags: [String] = ["SnapChef", "FoodTok", "Recipe"]

        let lowercaseTitle = title.lowercased()

        // Add cuisine-based hashtags
        if lowercaseTitle.contains("italian") { hashtags.append("ItalianFood") }
        if lowercaseTitle.contains("mexican") { hashtags.append("MexicanFood") }
        if lowercaseTitle.contains("asian") { hashtags.append("AsianFood") }
        if lowercaseTitle.contains("chinese") { hashtags.append("ChineseFood") }

        // Add cooking method hashtags
        if lowercaseTitle.contains("grilled") { hashtags.append("Grilled") }
        if lowercaseTitle.contains("baked") { hashtags.append("Baked") }
        if lowercaseTitle.contains("fried") { hashtags.append("Fried") }
        if lowercaseTitle.contains("sauteed") { hashtags.append("Sauteed") }

        return self.addMealTypeHashtags(hashtags, title: lowercaseTitle)
    }

    /// Helper method to add meal type and ingredient hashtags
    private func addMealTypeHashtags(_ hashtags: [String], title: String) -> [String] {
        var updatedHashtags = hashtags

        // Add meal type hashtags
        if title.contains("breakfast") { updatedHashtags.append("Breakfast") }
        if title.contains("lunch") { updatedHashtags.append("Lunch") }
        if title.contains("dinner") { updatedHashtags.append("Dinner") }
        if title.contains("dessert") { updatedHashtags.append("Dessert") }

        // Add ingredient-based hashtags
        if title.contains("chicken") { updatedHashtags.append("Chicken") }
        if title.contains("beef") { updatedHashtags.append("Beef") }
        if title.contains("pasta") { updatedHashtags.append("Pasta") }
        if title.contains("rice") { updatedHashtags.append("Rice") }

        return Array(updatedHashtags.prefix(10)) // Limit to 10 hashtags
    }

    // MARK: - Direct Post API

    /// Initialize Direct Post for video upload
    /// - Parameters:
    ///   - title: Post title (used for caption via post_info.title)
    ///   - privacy: Privacy level (PUBLIC_TO_EVERYONE, MUTUAL_FOLLOW_FRIEND, SELF_ONLY)
    ///   - disableComment: Whether to disable comments
    ///   - disableDuet: Whether to disable duets
    ///   - disableStitch: Whether to disable stitches
    /// - Returns: InitDirectPostResponse with publish_id and upload_url
    public func initDirectPost(
        title: String,
        privacy: PrivacyLevel = .publicToEveryone,
        disableComment: Bool = false,
        disableDuet: Bool = false,
        disableStitch: Bool = false
    ) async throws -> InitDirectPostResponse {
        // Ensure we have a valid token before making the request
        let validToken = try await ensureValidToken()
        self.accessToken = validToken

        let url = URL(string: "\(baseURL)/\(apiVersion)/post/publish/video/init/")!

        // Build post_info with caption in title field
        let hashtags = parseHashtagsFromTitle(title)
        let caption = buildCaption(text: title, hashtags: hashtags, appLink: "apps.apple.com/snapchef")

        let postInfo = PostInfo(
            title: caption, // TikTok uses title field for caption
            privacy_level: privacy,
            disable_comment: disableComment,
            disable_duet: disableDuet,
            disable_stitch: disableStitch,
            video_cover_timestamp_ms: 1_000 // 1 second into video for thumbnail
        )

        let requestBody = InitDirectPostRequest(
            post_info: postInfo,
            source_info: SourceInfo(
                source: "FILE_UPLOAD", // Support both FILE_UPLOAD and PULL_FROM_URL
                video_url: nil, // For FILE_UPLOAD, video_url should be nil
                video_size: nil,
                chunk_size: 10 * 1_024 * 1_024, // 10MB chunks
                total_chunk_count: nil
            )
        )

        return try await performAPIRequest(url: url, method: "POST", body: requestBody)
    }

    /// Upload video file via chunks
    /// - Parameters:
    ///   - videoURL: Local video file URL
    ///   - uploadURL: Upload URL from initDirectPost
    ///   - progressCallback: Progress callback (0.0 to 1.0)
    /// - Returns: Success indicator
    public func uploadVideoFile(
        videoURL: URL,
        uploadURL: String,
        progressCallback: @escaping (Double) -> Void = { _ in }
    ) async throws -> Bool {
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
        }

        defer {
            Task { @MainActor in
                isUploading = false
                uploadProgress = 1.0
            }
        }

        // Read video file data
        let videoData: Data
        do {
            videoData = try Data(contentsOf: videoURL)
        } catch {
            throw TikTokAPIError.fileError("Cannot read video file: \(error.localizedDescription)")
        }

        // Validate file size (TikTok limit: 4GB for videos)
        let maxSize = 4 * 1_024 * 1_024 * 1_024 // 4GB
        guard videoData.count <= maxSize else {
            throw TikTokAPIError.fileTooLarge("Video file exceeds 4GB limit")
        }

        let chunkSize = 10 * 1_024 * 1_024 // 10MB chunks
        let totalChunks = (videoData.count + chunkSize - 1) / chunkSize

        guard let url = URL(string: uploadURL) else {
            throw TikTokAPIError.invalidURL("Invalid upload URL")
        }

        // Upload chunks sequentially
        for chunkIndex in 0..<totalChunks {
            let startOffset = chunkIndex * chunkSize
            let endOffset = min(startOffset + chunkSize, videoData.count)
            let chunkData = videoData.subdata(in: startOffset..<endOffset)

            try await uploadChunk(
                data: chunkData,
                chunkIndex: chunkIndex,
                totalChunks: totalChunks,
                uploadURL: url
            )

            // Update progress
            let progress = Double(chunkIndex + 1) / Double(totalChunks)
            await MainActor.run {
                uploadProgress = progress
            }
            progressCallback(progress)
        }

        return true
    }

    /// Upload video from URL (PULL_FROM_URL method)
    /// - Parameters:
    ///   - videoURL: Remote video URL
    ///   - title: Post title for caption
    ///   - privacy: Privacy level
    /// - Returns: Publish ID for status checking
    public func uploadVideoFromURL(
        videoURL: String,
        title: String,
        privacy: PrivacyLevel = .publicToEveryone
    ) async throws -> String {
        guard hasValidToken else {
            throw TikTokAPIError.unauthorized("No access token available")
        }

        let url = URL(string: "\(baseURL)/\(apiVersion)/post/publish/video/init/")!

        // Build caption with hashtags
        let hashtags = parseHashtagsFromTitle(title)
        let caption = buildCaption(text: title, hashtags: hashtags, appLink: "apps.apple.com/snapchef")

        let postInfo = PostInfo(
            title: caption,
            privacy_level: privacy,
            disable_comment: false,
            disable_duet: false,
            disable_stitch: false,
            video_cover_timestamp_ms: 1_000
        )

        let requestBody = InitDirectPostRequest(
            post_info: postInfo,
            source_info: SourceInfo(
                source: "PULL_FROM_URL",
                video_url: videoURL,
                video_size: nil,
                chunk_size: nil,
                total_chunk_count: nil
            )
        )

        let response: InitDirectPostResponse = try await performAPIRequest(url: url, method: "POST", body: requestBody)
        return response.data.publish_id
    }

    /// Check upload/publish status
    /// - Parameter publishId: Publish ID from initDirectPost
    /// - Returns: Current status of the upload/publish process
    public func checkPublishStatus(publishId: String) async throws -> PublishStatusResponse {
        guard hasValidToken else {
            throw TikTokAPIError.unauthorized("No access token available")
        }

        let url = URL(string: "\(baseURL)/\(apiVersion)/post/publish/status/fetch/")!

        let requestBody = StatusCheckRequest(publish_id: publishId)

        return try await performAPIRequest(url: url, method: "POST", body: requestBody)
    }

    // MARK: - OAuth Token Management

    /// Refresh OAuth token if needed
    /// - Parameter refreshToken: Refresh token
    /// - Returns: New access token
    public func refreshToken(_ refreshToken: String) async throws -> String {
        let url = URL(string: "\(baseURL)/\(apiVersion)/oauth/token/")!

        let requestBody = TokenRefreshRequest(
            client_key: clientKey,
            client_secret: "YOUR_CLIENT_SECRET", // Should be stored securely
            grant_type: "refresh_token",
            refresh_token: refreshToken
        )

        let response: TikTokTokenResponse = try await performAPIRequest(url: url, method: "POST", body: requestBody)

        // Store new token
        self.accessToken = response.access_token

        return response.access_token
    }

    // MARK: - Convenience Methods

    /// Upload video with ShareContent (integrates with existing sharing system)
    /// - Parameters:
    ///   - content: ShareContent from existing sharing system
    ///   - videoURL: Local video file URL
    ///   - progressCallback: Upload progress callback
    /// - Returns: Publish ID for status checking
    public func uploadWithShareContent(
        content: ShareContent,
        videoURL: URL,
        progressCallback: @escaping (Double) -> Void = { _ in }
    ) async throws -> String {
        // Extract title and build caption
        let title: String
        switch content.type {
        case .recipe(let recipe):
            title = "🔥 \(recipe.name) made from fridge ingredients!"
        case .challenge(let challenge):
            title = "🏆 Completed: \(challenge.title)"
        case .achievement(let badge):
            title = "🎯 Achievement unlocked: \(badge)"
        case .profile:
            title = "👨‍🍳 Check out my SnapChef profile!"
        case .teamInvite(let teamName, _):
            title = "🏆 Join my cooking team: \(teamName)"
        }

        // Initialize direct post
        let initResponse = try await initDirectPost(title: title)

        // Upload video file
        _ = try await uploadVideoFile(
            videoURL: videoURL,
            uploadURL: initResponse.data.upload_url,
            progressCallback: progressCallback
        )

        return initResponse.data.publish_id
    }

    // MARK: - Private Methods

    private func uploadChunk(
        data: Data,
        chunkIndex: Int,
        totalChunks: Int,
        uploadURL: URL
    ) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        let rangeHeader = "bytes \(chunkIndex * data.count)-\((chunkIndex + 1) * data.count - 1)/\(totalChunks * data.count)"
        request.setValue(rangeHeader, forHTTPHeaderField: "Content-Range")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TikTokAPIError.networkError("Invalid response type")
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw TikTokAPIError.uploadFailed("Chunk upload failed with status: \(httpResponse.statusCode)")
        }
    }

    private func performAPIRequest<T: Codable, R: Codable>(
        url: URL,
        method: String,
        body: T
    ) async throws -> R {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        // Encode request body
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .useDefaultKeys
            request.httpBody = try encoder.encode(body)
        } catch {
            throw TikTokAPIError.encodingError("Failed to encode request: \(error.localizedDescription)")
        }

        // Perform request
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TikTokAPIError.networkError("Invalid response type")
        }

        // Handle HTTP errors
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"

            switch httpResponse.statusCode {
            case 401:
                // Clear the stored token so hasValidToken returns false
                self.accessToken = nil
                throw TikTokAPIError.unauthorized("Your TikTok session has expired. Please sign in again.")
            case 403:
                throw TikTokAPIError.forbidden("Insufficient permissions")
            case 429:
                throw TikTokAPIError.rateLimited("Rate limit exceeded")
            default:
                throw TikTokAPIError.serverError("Server error (\(httpResponse.statusCode)): \(errorMessage)")
            }
        }

        // Decode response
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            return try decoder.decode(R.self, from: data)
        } catch {
            throw TikTokAPIError.decodingError("Failed to decode response: \(error.localizedDescription)")
        }
    }
}

// MARK: - Data Models

public enum PrivacyLevel: String, Codable, Sendable {
    case publicToEveryone = "PUBLIC_TO_EVERYONE"
    case mutualFollowFriend = "MUTUAL_FOLLOW_FRIEND"
    case selfOnly = "SELF_ONLY"
}

public struct PostInfo: Codable, Sendable {
    let title: String
    let privacy_level: PrivacyLevel
    let disable_comment: Bool
    let disable_duet: Bool
    let disable_stitch: Bool
    let video_cover_timestamp_ms: Int
}

public struct SourceInfo: Codable, Sendable {
    let source: String // "FILE_UPLOAD" or "PULL_FROM_URL"
    let video_url: String?
    let video_size: Int?
    let chunk_size: Int?
    let total_chunk_count: Int?
}

public struct InitDirectPostRequest: Codable, Sendable {
    let post_info: PostInfo
    let source_info: SourceInfo
}

public struct InitDirectPostResponse: Codable, Sendable {
    let data: InitDirectPostData
    let error: APIErrorResponse?
}

public struct InitDirectPostData: Codable, Sendable {
    let publish_id: String
    let upload_url: String
}

public struct StatusCheckRequest: Codable, Sendable {
    let publish_id: String
}

public struct PublishStatusResponse: Codable, Sendable {
    let data: PublishStatusData
    let error: APIErrorResponse?
}

public struct PublishStatusData: Codable, Sendable {
    let status: String // "PROCESSING_UPLOAD", "PROCESSING_DOWNLOAD", "PROCESSING", "SENT_TO_USER_INBOX", "FAILED"
    let fail_reason: String?
    let publicaly_available_post_id: [String]?
}

public struct TokenRefreshRequest: Codable, Sendable {
    let client_key: String
    let client_secret: String
    let grant_type: String
    let refresh_token: String
}

public struct TikTokTokenResponse: Codable, Sendable {
    let access_token: String
    let expires_in: Int
    let refresh_token: String
    let refresh_expires_in: Int
    let token_type: String
    let scope: String
}

public struct APIErrorResponse: Codable, Sendable {
    let code: String
    let message: String
    let log_id: String
}

// MARK: - Error Types

public enum TikTokAPIError: LocalizedError, Sendable {
    case unauthorized(String)
    case forbidden(String)
    case rateLimited(String)
    case serverError(String)
    case networkError(String)
    case encodingError(String)
    case decodingError(String)
    case fileError(String)
    case fileTooLarge(String)
    case invalidURL(String)
    case uploadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized(let message),
             .forbidden(let message),
             .rateLimited(let message),
             .serverError(let message),
             .networkError(let message),
             .encodingError(let message),
             .decodingError(let message),
             .fileError(let message),
             .fileTooLarge(let message),
             .invalidURL(let message),
             .uploadFailed(let message):
            return message
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .serverError, .networkError, .uploadFailed:
            return true
        default:
            return false
        }
    }
}
