import Foundation
import UIKit

@MainActor
class NetworkManager {
    static let shared = NetworkManager()
    private static let fallbackBaseURL = "https://snapchef-server.onrender.com"

    private var baseURL: String = NetworkManager.fallbackBaseURL
    private var session: URLSession
    private let maxRetryAttempts = 3
    private let retryableHTTPStatusCodes: Set<Int> = [408, 425, 429, 500, 502, 503, 504]

    private init() {
        let configuration = URLSessionConfiguration.default
        // Render cold-starts can exceed 30 seconds; align with SnapChefAPIManager.
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }

    func configure() {
        if let configuredBaseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let normalized = normalizeBaseURL(configuredBaseURL) {
            baseURL = normalized
        } else {
            baseURL = NetworkManager.fallbackBaseURL
        }
    }

    func checkServerHealth() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    // MARK: - Recipe Generation

    func analyzeImage(_ image: UIImage, deviceId: String) async throws -> RecipeGenerationResponse {
        // Use mock data in debug mode
        if MockDataProvider.shared.useMockData {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            return MockDataProvider.shared.mockRecipeResponse()
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NetworkError.invalidInput
        }

        let base64String = imageData.base64EncodedString()

        let request = RecipeGenerationRequest(
            imageBase64: base64String,
            dietaryPreferences: [],
            mealType: nil,
            servings: 2
        )

        let endpoint = "\(baseURL)/api/v1/analyze"
        return try await post(endpoint, body: request, additionalHeaders: ["X-Device-ID": deviceId])
    }

    // MARK: - Device Management

    func getDeviceStatus(deviceId: String) async throws -> DeviceStatus {
        if MockDataProvider.shared.useMockData {
            return MockDataProvider.shared.mockDeviceStatus()
        }

        let endpoint = "\(baseURL)/api/v1/device/\(deviceId)/status"
        return try await get(endpoint)
    }

    func consumeFreeUse(deviceId: String) async throws -> FreeUseResponse {
        if MockDataProvider.shared.useMockData {
            return FreeUseResponse(success: true, remainingUses: 2, isBlocked: false)
        }

        let endpoint = "\(baseURL)/api/v1/device/\(deviceId)/consume"
        return try await post(endpoint, body: EmptyRequest())
    }

    // MARK: - Authentication

    func authenticate<T: Encodable>(provider: AuthProvider, authData: T) async throws -> AuthResponse {
        let endpoint = "\(baseURL)/api/v1/auth/\(provider.rawValue)"
        return try await post(endpoint, body: authData)
    }

    func validateToken(_ token: String) async throws -> User {
        let endpoint = "\(baseURL)/api/v1/auth/validate"
        return try await get(endpoint, headers: ["Authorization": "Bearer \(token)"])
    }

    // MARK: - Share Tracking

    func trackShare(recipeId: String, platform: String) async throws -> ShareResponse {
        let endpoint = "\(baseURL)/api/v1/share"
        let body = ["recipeId": recipeId, "platform": platform]
        return try await post(endpoint, body: body)
    }

    // MARK: - Generic HTTP Methods

    private func get<T: Decodable>(_ endpoint: String, headers: [String: String] = [:]) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyDefaultHeaders(to: &request, additionalHeaders: headers)

        let (data, _) = try await performDataRequest(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U, additionalHeaders: [String: String] = [:]) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyDefaultHeaders(to: &request, additionalHeaders: additionalHeaders)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, _) = try await performDataRequest(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ endpoint: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyDefaultHeaders(to: &request)

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await performDataRequest(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func normalizeBaseURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasSuffix("/") {
            return String(trimmed.dropLast())
        }
        return trimmed
    }

    private func applyDefaultHeaders(
        to request: inout URLRequest,
        additionalHeaders: [String: String] = [:]
    ) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // App API key (required by Render broker for most endpoints).
        if let apiKey = KeychainManager.shared.getAPIKey()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-App-API-Key")
        }

        // Bearer auth (optional).
        if let token = KeychainManager.shared.getAuthToken()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Call-site overrides last.
        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private func performDataRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 1

        while true {
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    if shouldRetry(statusCode: httpResponse.statusCode, error: nil), attempt < maxRetryAttempts {
                        try await Task.sleep(nanoseconds: retryDelayNanoseconds(for: attempt))
                        attempt += 1
                        continue
                    }
                    throw NetworkError.httpError(httpResponse.statusCode)
                }

                return (data, httpResponse)
            } catch {
                if shouldRetry(statusCode: nil, error: error), attempt < maxRetryAttempts {
                    try await Task.sleep(nanoseconds: retryDelayNanoseconds(for: attempt))
                    attempt += 1
                    continue
                }
                throw error
            }
        }
    }

    private func shouldRetry(statusCode: Int?, error: Error?) -> Bool {
        if let statusCode {
            return retryableHTTPStatusCodes.contains(statusCode)
        }

        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut,
             .notConnectedToInternet,
             .networkConnectionLost,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private func retryDelayNanoseconds(for attempt: Int) -> UInt64 {
        let delay = min(0.6 * pow(2.0, Double(attempt - 1)), 2.4)
        return UInt64(delay * 1_000_000_000)
    }
}

// MARK: - Response Models

struct DeviceStatus: Decodable {
    let deviceId: String
    let freeUsesRemaining: Int
    let isBlocked: Bool
    let hasSubscription: Bool
}

struct FreeUseResponse: Decodable {
    let success: Bool
    let remainingUses: Int
    let isBlocked: Bool
}

struct ShareResponse: Decodable {
    let success: Bool
    let creditsEarned: Int
    let totalCredits: Int
}

struct EmptyRequest: Encodable {}

// MARK: - Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidInput
    case invalidResponse
    case httpError(Int)
    case decodingError
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidInput:
            return "Invalid input data"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .unknown:
            return "Unknown network error"
        }
    }
}
