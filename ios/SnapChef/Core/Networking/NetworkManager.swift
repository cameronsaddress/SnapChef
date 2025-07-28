import Foundation
import UIKit

class NetworkManager {
    static let shared = NetworkManager()
    
    private var baseURL: String = ""
    private var session: URLSession
    private let keychain = KeychainService()
    private let authTokenKey = "com.snapchef.authToken"
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }
    
    func configure() {
        #if DEBUG
        baseURL = "https://api-dev.snapchef.app"
        #else
        baseURL = "https://api.snapchef.app"
        #endif
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
    
    func authenticate(provider: AuthProvider, authData: Any) async throws -> AuthResponse {
        let endpoint = "\(baseURL)/api/v1/auth/\(provider.rawValue)"
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(authData as! Encodable)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        return try await post(endpoint, body: json)
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
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = keychain.get(authTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add additional headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    private func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U, additionalHeaders: [String: String] = [:]) async throws -> T {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = keychain.get(authTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add additional headers
        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    private func post<T: Decodable>(_ endpoint: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = keychain.get(authTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
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
    case invalidInput
    case invalidResponse
    case httpError(Int)
    case decodingError
    case unknown
    
    var errorDescription: String? {
        switch self {
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