// SnapChefAPIManager.swift

import Foundation
import UIKit

private func apiDebugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}

// MARK: - UIImage Extension for Resizing
extension UIImage {
    /// Resizes the image to fit within the specified maximum dimension while maintaining aspect ratio
    func resized(withMaxDimension maxDimension: CGFloat) -> UIImage {
        let size = self.size

        // If image is already smaller than max dimension, return original
        if size.width <= maxDimension && size.height <= maxDimension {
            return self
        }

        // Calculate the scaling factor
        let widthRatio = maxDimension / size.width
        let heightRatio = maxDimension / size.height
        let scaleFactor = min(widthRatio, heightRatio)

        // Calculate new size
        let newSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )

        // Create resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage
    }
} // For UIImage

// MARK: - API Key
// The API key is now securely stored in the Keychain
// If Keychain access fails, the app should handle it gracefully without exposing keys
// private let FALLBACK_API_KEY removed for security - never hardcode API keys

// MARK: - API Error Handling
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidRequestData
    case noData
    case serverError(statusCode: Int, message: String)
    case decodingError(String)
    case authenticationError // For 401 Unauthorized
    case unauthorized(String) // For missing API key
    case notFoodImage(String) // For non-fridge/pantry photos
    case noIngredientsDetected(String) // For food images with no detectable ingredients

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The server URL is invalid."
        case .invalidRequestData: return "Failed to encode request data."
        case .noData: return "No data received from the server."
        case .serverError(let code, let message): return "Server error \(code): \(message)"
        case .decodingError(let details): return "Failed to decode server response: \(details)"
        case .authenticationError: return "Authentication failed. Please check your app's API key."
        case .unauthorized(let message): return message
        case .notFoodImage(let message): return message
        case .noIngredientsDetected(let message): return message
        }
    }
}

// MARK: - Data Extension for Multipart Form
extension Data {
    /// Appends a string to the data, encoding it as UTF-8.
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - API Response Models (to match FastAPI Pydantic models)

@MainActor
struct APIResponse: Codable {
    let data: GrokParsedResponse
    let message: String
}

struct GrokParsedResponse: Codable {
    let image_analysis: ImageAnalysis
    let ingredients: [IngredientAPI]
    let recipes: [RecipeAPI]
}

struct ImageAnalysis: Codable {
    let is_food_image: Bool
    let confidence: String
    let image_description: String
}

struct IngredientAPI: Codable {
    let name: String
    let quantity: String
    let unit: String
    let category: String
    let freshness: String
    let location: String? // Optional as per your Pydantic model
}

struct RecipeAPI: Codable, Identifiable {
    let id: String // Matches the UUID string from Python
    let name: String
    let description: String
    let main_dish: String?
    let side_dish: String?
    let total_time: Int?
    let prep_time: Int?
    let cook_time: Int?
    let servings: Int?
    let difficulty: String
    let ingredients_used: [IngredientUsed]? // Optional as per your Pydantic model
    let instructions: [String]
    let nutrition: NutritionAPI? // Optional as per your Pydantic model
    let tips: String? // Optional as per your Pydantic model
    let tags: [String]? // Optional as per your Pydantic model
    let share_caption: String? // Optional as per your Pydantic model
    
    // Detective fields for enhanced Fridge Snap results
    let cooking_techniques: [String]?
    let flavor_profile: FlavorProfileAPI?
    let secret_ingredients: [String]?
    let pro_tips: [String]?
    let visual_clues: [String]?
}

struct IngredientUsed: Codable {
    let name: String
    let amount: String
}

struct NutritionAPI: Codable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let fiber: Int?
    let sugar: Int?
    let sodium: Int?
}

struct FlavorProfileAPI: Codable {
    let sweet: Int?
    let salty: Int?
    let sour: Int?
    let bitter: Int?
    let umami: Int?
}

// MARK: - SnapChefAPIManager
@MainActor
final class SnapChefAPIManager {
    // Fix for Swift concurrency issue with @MainActor singletons
    static let shared: SnapChefAPIManager = {
        let instance = SnapChefAPIManager()
        return instance
    }()

    private static let fallbackServerBaseURL = "https://snapchef-server.onrender.com"
    private let serverBaseURL: String
    private let session: URLSession
    private var lastWarmupAttemptAt: Date?
    private let warmupCooldownSeconds: TimeInterval = 90

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120 // 2 minutes timeout
        configuration.timeoutIntervalForResource = 120
        self.serverBaseURL = Self.resolvedServerBaseURL()
        self.session = URLSession(configuration: configuration)
    } // Private initializer for singleton

    private static func resolvedServerBaseURL() -> String {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String else {
            return fallbackServerBaseURL
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallbackServerBaseURL }
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    func ensureCredentialsConfigured() throws {
        guard appAPIKeyCredential() != nil else {
            throw APIError.unauthorized("Missing SNAPCHEF_API_KEY (or APP_API_KEY). Configure the app API key in build settings or runtime environment.")
        }
    }

    /// Pre-warm Render by touching /health before expensive camera uploads.
    func warmupBackendIfNeeded(force: Bool = false) async {
        let now = Date()
        if !force, let lastWarmupAttemptAt,
           now.timeIntervalSince(lastWarmupAttemptAt) < warmupCooldownSeconds {
            return
        }
        lastWarmupAttemptAt = now

        guard let url = URL(string: "\(serverBaseURL)/health") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8

        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                apiDebugLog("🔥 Backend warmup /health status: \(httpResponse.statusCode)")
            }
        } catch {
            apiDebugLog("⚠️ Backend warmup failed: \(error.localizedDescription)")
        }
    }

    enum RecipeGenerationMilestone: Sendable {
        case requestPrepared
        case requestSent
        case responseReceived
        case responseDecoded
        case completed
        case failed
    }

    private struct APICredential {
        let headerField: String
        let headerValue: String
        let mode: String
    }

    private func appAPIKeyCredential() -> APICredential? {
        if let apiKey = KeychainManager.shared.getAPIKey()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !apiKey.isEmpty {
            return APICredential(
                headerField: "X-App-API-Key",
                headerValue: apiKey,
                mode: "legacy_api_key"
            )
        }
        return nil
    }

    private func bearerCredential() -> APICredential? {
        if let authToken = KeychainManager.shared.getAuthToken()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !authToken.isEmpty {
            return APICredential(
                headerField: "Authorization",
                headerValue: "Bearer \(authToken)",
                mode: "bearer_token"
            )
        }

        return nil
    }

    private func preferredCredential() -> APICredential? {
        appAPIKeyCredential() ?? bearerCredential()
    }

    private func applyAuthenticationHeaders(
        to request: inout URLRequest,
        requiresAppAPIKey: Bool = false
    ) throws {
        let credential = requiresAppAPIKey ? appAPIKeyCredential() : preferredCredential()
        guard let credential else {
            let message = requiresAppAPIKey
                ? "Missing SNAPCHEF_API_KEY (or APP_API_KEY). Configure the app API key to call SnapChef rendering endpoints."
                : "API credentials missing. Sign in again or configure the API key."
            throw APIError.unauthorized(message)
        }
        request.setValue(credential.headerValue, forHTTPHeaderField: credential.headerField)
        request.setValue(credential.mode, forHTTPHeaderField: "X-SnapChef-Auth-Mode")
    }

    /// Creates a multipart/form-data URLRequest for the API.
    private func createMultipartRequest(
        url: URL,
        image: UIImage,
        sessionId: String,
        dietaryRestrictions: [String],
        foodType: String?,
        difficultyPreference: String?,
        healthPreference: String?,
        mealType: String?,
        cookingTimePreference: String?,
        numberOfRecipes: Int?,
        existingRecipeNames: [String],
        foodPreferences: [String],
        llmProvider: String? = nil
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        try applyAuthenticationHeaders(to: &request, requiresAppAPIKey: true)
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var httpBody = Data()

        // Helper to append form fields
        func appendFormField(name: String, value: String) {
            httpBody.append("--\(boundary)\r\n")
            httpBody.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            httpBody.append("\(value)\r\n")
        }

        // Append session_id
        appendFormField(name: "session_id", value: sessionId)

        // Append dietary_restrictions (as a JSON array string)
        if !dietaryRestrictions.isEmpty {
            guard let restrictionsData = try? JSONSerialization.data(withJSONObject: dietaryRestrictions, options: []) else {
                apiDebugLog("Failed to serialize dietary restrictions")
                throw APIError.invalidRequestData
            }
            guard let restrictionsString = String(data: restrictionsData, encoding: .utf8) else {
                apiDebugLog("Failed to convert dietary restrictions to string")
                throw APIError.invalidRequestData
            }
            appendFormField(name: "dietary_restrictions", value: restrictionsString)
        } else {
            // Send an empty JSON array string if no restrictions, to match FastAPI's default
            appendFormField(name: "dietary_restrictions", value: "[]")
        }

        // Append new optional parameters if they exist
        if let foodType = foodType {
            appendFormField(name: "food_type", value: foodType)
        }
        if let difficultyPreference = difficultyPreference {
            appendFormField(name: "difficulty_preference", value: difficultyPreference)
        }
        if let healthPreference = healthPreference {
            appendFormField(name: "health_preference", value: healthPreference)
        }
        if let mealType = mealType {
            appendFormField(name: "meal_type", value: mealType)
        }
        if let cookingTimePreference = cookingTimePreference {
            appendFormField(name: "cooking_time_preference", value: cookingTimePreference)
        }
        if let numberOfRecipes = numberOfRecipes {
            appendFormField(name: "number_of_recipes", value: String(numberOfRecipes))
        }
        if let llmProvider = llmProvider {
            appendFormField(name: "llm_provider", value: llmProvider)
        }

        // Append existing recipe names to avoid duplicates
        if !existingRecipeNames.isEmpty {
            guard let existingRecipesData = try? JSONSerialization.data(withJSONObject: existingRecipeNames, options: []) else {
                apiDebugLog("Failed to serialize existing recipe names")
                throw APIError.invalidRequestData
            }
            guard let existingRecipesString = String(data: existingRecipesData, encoding: .utf8) else {
                apiDebugLog("Failed to convert existing recipes to string")
                throw APIError.invalidRequestData
            }
            appendFormField(name: "existing_recipe_names", value: existingRecipesString)
        }

        // Append food preferences
        if !foodPreferences.isEmpty {
            guard let preferencesData = try? JSONSerialization.data(withJSONObject: foodPreferences, options: []) else {
                apiDebugLog("Failed to serialize food preferences")
                throw APIError.invalidRequestData
            }
            guard let preferencesString = String(data: preferencesData, encoding: .utf8) else {
                apiDebugLog("Failed to convert food preferences to string")
                throw APIError.invalidRequestData
            }
            appendFormField(name: "food_preferences", value: preferencesString)
        }

        // Resize image to max 2048x2048 to reduce file size while maintaining quality
        let resizedImage = image.resized(withMaxDimension: 2_048)

        // Log original and resized dimensions
        apiDebugLog("Original image size: \(image.size.width)x\(image.size.height)")
        apiDebugLog("Resized image size: \(resizedImage.size.width)x\(resizedImage.size.height)")

        // Append image_file with 80% JPEG compression
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            apiDebugLog("Failed to get JPEG data from image")
            throw APIError.invalidRequestData
        }

        // Log final file size
        let fileSizeMB = Double(imageData.count) / (1_024 * 1_024)
        apiDebugLog("Final image file size: \(String(format: "%.2f", fileSizeMB)) MB")
        httpBody.append("--\(boundary)\r\n")
        httpBody.append("Content-Disposition: form-data; name=\"image_file\"; filename=\"photo.jpg\"\r\n")
        httpBody.append("Content-Type: image/jpeg\r\n\r\n")
        httpBody.append(imageData)
        httpBody.append("\r\n")

        // Final boundary
        httpBody.append("--\(boundary)--\r\n")
        request.httpBody = httpBody

        return request
    }

    /// Sends image and preferences to the backend for recipe generation.
    func sendImageForRecipeGeneration(
        image: UIImage,
        sessionId: String,
        dietaryRestrictions: [String],
        foodType: String? = nil,
        difficultyPreference: String? = nil,
        healthPreference: String? = nil,
        mealType: String? = nil,
        cookingTimePreference: String? = nil,
        numberOfRecipes: Int? = nil,
        existingRecipeNames: [String] = [],
        foodPreferences: [String] = [],
        llmProvider: String? = nil,
        lifecycle: (@Sendable (RecipeGenerationMilestone) -> Void)? = nil,
        completion: @escaping @Sendable (Result<APIResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(serverBaseURL)/analyze_fridge_image") else {
            lifecycle?(.failed)
            completion(.failure(APIError.invalidURL))
            return
        }

        apiDebugLog("📡 API Request to: \(url.absoluteString)")
        apiDebugLog("📡 API key configured: \(KeychainManager.shared.getAPIKey() != nil)")

        let request: URLRequest
        do {
            request = try createMultipartRequest(
                url: url,
                image: image,
                sessionId: sessionId,
                dietaryRestrictions: dietaryRestrictions,
                foodType: foodType,
                difficultyPreference: difficultyPreference,
                healthPreference: healthPreference,
                mealType: mealType,
                cookingTimePreference: cookingTimePreference,
                numberOfRecipes: numberOfRecipes,
                existingRecipeNames: existingRecipeNames,
                foodPreferences: foodPreferences,
                llmProvider: llmProvider
            )
            lifecycle?(.requestPrepared)
        } catch {
            lifecycle?(.failed)
            completion(.failure(error))
            return
        }

        apiDebugLog("📡 Sending request with session ID: \(sessionId)")
        apiDebugLog("📡 Request body size: \(request.httpBody?.count ?? 0) bytes")

        lifecycle?(.requestSent)
        Task {
            do {
                let response = try await self.executeRecipeGenerationRequest(
                    request: request,
                    lifecycle: lifecycle,
                    debugContext: "single_image",
                    notFoodImageMessage: "Hmm, this doesn't look like a fridge or pantry photo. Let's try again with a clear shot of your ingredients! 📸",
                    noIngredientsMessage: "I couldn't spot any ingredients in this photo. Try taking a clearer shot of your fridge or pantry with better lighting! 💡"
                )
                lifecycle?(.completed)
                completion(.success(response))
            } catch {
                lifecycle?(.failed)
                completion(.failure(error))
            }
        }
    }

    /// Send both fridge and pantry images for recipe generation
    func sendBothImagesForRecipeGeneration(
        fridgeImage: UIImage,
        pantryImage: UIImage,
        sessionId: String,
        dietaryRestrictions: [String],
        foodType: String? = nil,
        difficultyPreference: String? = nil,
        healthPreference: String? = nil,
        mealType: String? = nil,
        cookingTimePreference: String? = nil,
        numberOfRecipes: Int? = nil,
        existingRecipeNames: [String] = [],
        foodPreferences: [String] = [],
        llmProvider: String? = nil,
        lifecycle: (@Sendable (RecipeGenerationMilestone) -> Void)? = nil,
        completion: @escaping @Sendable (Result<APIResponse, Error>) -> Void
    ) {
        // For now, use the same endpoint but send both images
        // The backend should be updated to handle both images
        guard let url = URL(string: "\(serverBaseURL)/analyze_fridge_image") else {
            lifecycle?(.failed)
            completion(.failure(APIError.invalidURL))
            return
        }

        apiDebugLog("📡 API Request to: \(url.absoluteString)")
        apiDebugLog("📡 API key configured: \(KeychainManager.shared.getAPIKey() != nil)")
        apiDebugLog("📡 Sending both fridge and pantry images")

        let request: URLRequest
        do {
            request = try createMultipartRequestWithBothImages(
                url: url,
                fridgeImage: fridgeImage,
                pantryImage: pantryImage,
                sessionId: sessionId,
                dietaryRestrictions: dietaryRestrictions,
                foodType: foodType,
                difficultyPreference: difficultyPreference,
                healthPreference: healthPreference,
                mealType: mealType,
                cookingTimePreference: cookingTimePreference,
                numberOfRecipes: numberOfRecipes,
                existingRecipeNames: existingRecipeNames,
                foodPreferences: foodPreferences,
                llmProvider: llmProvider
            )
            lifecycle?(.requestPrepared)
        } catch {
            lifecycle?(.failed)
            completion(.failure(error))
            return
        }

        apiDebugLog("📡 Sending request with session ID: \(sessionId)")
        apiDebugLog("📡 Request body size: \(request.httpBody?.count ?? 0) bytes")

        lifecycle?(.requestSent)
        Task {
            do {
                let response = try await self.executeRecipeGenerationRequest(
                    request: request,
                    lifecycle: lifecycle,
                    debugContext: "dual_image",
                    notFoodImageMessage: "Hmm, one or both of these photos don't look like fridge or pantry shots. Let's try again with clear photos of your ingredients! 📸",
                    noIngredientsMessage: "I couldn't spot any ingredients in these photos. Try taking clearer shots of your fridge and pantry with better lighting! 💡"
                )
                lifecycle?(.completed)
                completion(.success(response))
            } catch {
                lifecycle?(.failed)
                completion(.failure(error))
            }
        }
    }

    /// Create multipart request with both fridge and pantry images
    private func createMultipartRequestWithBothImages(
        url: URL,
        fridgeImage: UIImage,
        pantryImage: UIImage,
        sessionId: String,
        dietaryRestrictions: [String],
        foodType: String?,
        difficultyPreference: String?,
        healthPreference: String?,
        mealType: String?,
        cookingTimePreference: String?,
        numberOfRecipes: Int?,
        existingRecipeNames: [String],
        foodPreferences: [String],
        llmProvider: String? = nil
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        try applyAuthenticationHeaders(to: &request, requiresAppAPIKey: true)
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var httpBody = Data()

        // Helper to append form fields
        func appendFormField(name: String, value: String) {
            httpBody.append("--\(boundary)\r\n")
            httpBody.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            httpBody.append("\(value)\r\n")
        }

        // Append session_id
        appendFormField(name: "session_id", value: sessionId)

        // Append dietary_restrictions (as a JSON array string)
        if !dietaryRestrictions.isEmpty {
            guard let restrictionsData = try? JSONSerialization.data(withJSONObject: dietaryRestrictions, options: []) else {
                apiDebugLog("Failed to serialize dietary restrictions")
                throw APIError.invalidRequestData
            }
            guard let restrictionsString = String(data: restrictionsData, encoding: .utf8) else {
                apiDebugLog("Failed to convert dietary restrictions to string")
                throw APIError.invalidRequestData
            }
            appendFormField(name: "dietary_restrictions", value: restrictionsString)
        } else {
            // Send an empty JSON array string if no restrictions, to match FastAPI's default
            appendFormField(name: "dietary_restrictions", value: "[]")
        }

        // Append new optional parameters if they exist
        if let foodType = foodType {
            appendFormField(name: "food_type", value: foodType)
        }
        if let difficultyPreference = difficultyPreference {
            appendFormField(name: "difficulty_preference", value: difficultyPreference)
        }
        if let healthPreference = healthPreference {
            appendFormField(name: "health_preference", value: healthPreference)
        }
        if let mealType = mealType {
            appendFormField(name: "meal_type", value: mealType)
        }
        if let cookingTimePreference = cookingTimePreference {
            appendFormField(name: "cooking_time_preference", value: cookingTimePreference)
        }
        if let numberOfRecipes = numberOfRecipes {
            appendFormField(name: "number_of_recipes", value: String(numberOfRecipes))
        }
        if let llmProvider = llmProvider {
            appendFormField(name: "llm_provider", value: llmProvider)
        }

        // Append existing recipe names to avoid duplicates
        if !existingRecipeNames.isEmpty {
            guard let existingRecipesData = try? JSONSerialization.data(withJSONObject: existingRecipeNames, options: []) else {
                apiDebugLog("Failed to serialize existing recipe names")
                throw APIError.invalidRequestData
            }
            guard let existingRecipesString = String(data: existingRecipesData, encoding: .utf8) else {
                apiDebugLog("Failed to convert existing recipes to string")
                throw APIError.invalidRequestData
            }
            appendFormField(name: "existing_recipe_names", value: existingRecipesString)
        }

        // Append food preferences
        if !foodPreferences.isEmpty {
            guard let preferencesData = try? JSONSerialization.data(withJSONObject: foodPreferences, options: []) else {
                apiDebugLog("Failed to serialize food preferences")
                throw APIError.invalidRequestData
            }
            guard let preferencesString = String(data: preferencesData, encoding: .utf8) else {
                apiDebugLog("Failed to convert food preferences to string")
                throw APIError.invalidRequestData
            }
            appendFormField(name: "food_preferences", value: preferencesString)
        }

        // Resize images to max 2048x2048 to reduce file size while maintaining quality
        let resizedFridgeImage = fridgeImage.resized(withMaxDimension: 2_048)
        let resizedPantryImage = pantryImage.resized(withMaxDimension: 2_048)

        // Log original and resized dimensions
        apiDebugLog("Fridge image - Original: \(fridgeImage.size.width)x\(fridgeImage.size.height), Resized: \(resizedFridgeImage.size.width)x\(resizedFridgeImage.size.height)")
        apiDebugLog("Pantry image - Original: \(pantryImage.size.width)x\(pantryImage.size.height), Resized: \(resizedPantryImage.size.width)x\(resizedPantryImage.size.height)")

        // Append fridge image file with 80% JPEG compression
        guard let fridgeImageData = resizedFridgeImage.jpegData(compressionQuality: 0.8) else {
            apiDebugLog("Failed to convert fridge image to JPEG data")
            throw APIError.invalidRequestData
        }

        httpBody.append("--\(boundary)\r\n")
        httpBody.append("Content-Disposition: form-data; name=\"fridge_image\"; filename=\"fridge.jpg\"\r\n")
        httpBody.append("Content-Type: image/jpeg\r\n\r\n")
        httpBody.append(fridgeImageData)
        httpBody.append("\r\n")

        apiDebugLog("Fridge image data size: \(fridgeImageData.count) bytes (\(String(format: "%.2f", Double(fridgeImageData.count) / 1_024 / 1_024)) MB)")

        // Append pantry image file with 80% JPEG compression
        guard let pantryImageData = resizedPantryImage.jpegData(compressionQuality: 0.8) else {
            apiDebugLog("Failed to convert pantry image to JPEG data")
            throw APIError.invalidRequestData
        }

        httpBody.append("--\(boundary)\r\n")
        httpBody.append("Content-Disposition: form-data; name=\"pantry_image\"; filename=\"pantry.jpg\"\r\n")
        httpBody.append("Content-Type: image/jpeg\r\n\r\n")
        httpBody.append(pantryImageData)
        httpBody.append("\r\n")

        apiDebugLog("Pantry image data size: \(pantryImageData.count) bytes (\(String(format: "%.2f", Double(pantryImageData.count) / 1_024 / 1_024)) MB)")

        // Close the multipart form
        httpBody.append("--\(boundary)--\r\n")

        request.httpBody = httpBody
        apiDebugLog("Total request body size: \(httpBody.count) bytes (\(String(format: "%.2f", Double(httpBody.count) / 1_024 / 1_024)) MB)")

        return request
    }

    /// Enhanced API request with comprehensive error handling and retry logic
    private func performAPIRequest<T: Codable & Sendable>(
        request: URLRequest,
        responseType: T.Type,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0
    ) async throws -> T {
        let operationId = "api_\(UUID().uuidString.prefix(8))"
        
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await self.executeRequestWithRetry(
                    request: request,
                    responseType: responseType,
                    operationId: operationId,
                    maxRetries: maxRetries,
                    baseDelay: baseDelay
                )
            }
            
            for try await result in group {
                group.cancelAll()
                return result
            }
            
            throw SnapChefError.unknown("Request group completed without result")
        }
    }
    
    /// Execute request with exponential backoff retry logic
    private func executeRequestWithRetry<T: Codable>(
        request: URLRequest,
        responseType: T.Type,
        operationId: String,
        maxRetries: Int,
        baseDelay: TimeInterval
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SnapChefError.networkError("Invalid response type")
                }
                
                // Handle HTTP errors with enhanced status code mapping
                if let error = handleHTTPStatusCode(httpResponse.statusCode, data: data) {
                    
                    // Don't retry on certain errors
                    if case .authenticationError = error {
                        throw error
                    }
                    if case .unauthorizedError = error {
                        throw error
                    }
                    if case .validationError = error {
                        throw error
                    }
                    
                    // For retryable errors, store and continue to retry logic
                    lastError = error
                    
                    // Log retry attempt
                    ErrorAnalytics.logError(error, context: "api_retry_attempt_\(attempt + 1)_\(operationId)")
                    
                    if attempt < maxRetries - 1 {
                        let delay = retryDelay(for: attempt + 1, statusCode: httpResponse.statusCode, response: httpResponse, responseData: data)
                        apiDebugLog("[API] Retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    } else {
                        throw error
                    }
                }
                
                // Success case - decode response
                do {
                    let decoded = try JSONDecoder().decode(responseType, from: data)
                    apiDebugLog("[API] Request succeeded on attempt \(attempt + 1)")
                    return decoded
                } catch {
                    let decodingError = SnapChefError.apiError(
                        "Failed to parse server response: \(error.localizedDescription)",
                        statusCode: httpResponse.statusCode,
                        recovery: .retry
                    )
                    throw decodingError
                }
                
            } catch {
                lastError = error
                
                // Handle network-level errors
                if let nsError = error as NSError? {
                    let snapChefError: SnapChefError
                    
                    switch nsError.code {
                    case NSURLErrorTimedOut:
                        snapChefError = .timeoutError("Request timed out. Please check your connection.")
                    case NSURLErrorNotConnectedToInternet:
                        snapChefError = .networkError("No internet connection. Please check your network.")
                    case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                        snapChefError = .networkError("Cannot reach server. Please try again later.")
                    case NSURLErrorNetworkConnectionLost:
                        snapChefError = .networkError("Network connection lost. Please try again.")
                    default:
                        snapChefError = .networkError("Network error: \(error.localizedDescription)")
                    }
                    
                    ErrorAnalytics.logError(snapChefError, context: "network_error_attempt_\(attempt + 1)_\(operationId)")
                    
                    // Don't retry on certain network errors
                    if nsError.code == NSURLErrorNotConnectedToInternet {
                        throw snapChefError
                    }
                    
                    if attempt < maxRetries - 1 {
                        let delay = calculateBackoffDelay(attempt: attempt, baseDelay: baseDelay)
                        apiDebugLog("[API] Network error, retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    } else {
                        throw snapChefError
                    }
                } else {
                    // Other errors (e.g., SnapChefError already)
                    if attempt < maxRetries - 1 {
                        let delay = calculateBackoffDelay(attempt: attempt, baseDelay: baseDelay)
                        apiDebugLog("[API] Error, retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    } else {
                        throw error
                    }
                }
            }
        }
        
        // If we get here, all retries failed
        throw lastError ?? SnapChefError.unknown("All retry attempts failed")
    }
    
    /// Calculate exponential backoff delay with jitter
    private func calculateBackoffDelay(attempt: Int, baseDelay: TimeInterval) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0.1...0.3) * exponentialDelay
        let maxDelay: TimeInterval = 30.0 // Cap at 30 seconds
        return min(exponentialDelay + jitter, maxDelay)
    }
    
    /// Handles HTTP status codes and returns appropriate SnapChef errors
    private func handleHTTPStatusCode(_ statusCode: Int, data: Data?) -> SnapChefError? {
        switch statusCode {
        case 200...299:
            return nil // Success
        case 400:
            let message = extractErrorMessage(from: data) ?? "Invalid request. Please check your input."
            return .validationError(message, fields: [])
        case 401:
            return .authenticationError("Server authentication failed. The app's API key may be incorrect.")
        case 403:
            return .unauthorizedError("Access denied. Please check your permissions.")
        case 404:
            return .apiError("Service not found. Please try again later.", statusCode: statusCode, recovery: .contactSupport)
        case 409:
            return .apiError("Conflict detected. Please refresh and try again.", statusCode: statusCode, recovery: .retry)
        case 413:
            return .validationError("Image file is too large. Please use a smaller image.", fields: ["image"])
        case 422:
            let message = extractErrorMessage(from: data) ?? "Invalid data provided."
            return .validationError(message, fields: [])
        case 429:
            let retryAfter = extractRetryAfter(from: data) ?? 60
            return .rateLimitError("Too many requests. Please wait a moment before trying again.", retryAfter: retryAfter)
        case 500:
            return .apiError("Internal server error. Our team has been notified.", statusCode: statusCode, recovery: .retry)
        case 501:
            return .apiError("Feature not implemented. Please contact support.", statusCode: statusCode, recovery: .contactSupport)
        case 502:
            return .apiError("Bad gateway. Please try again in a moment.", statusCode: statusCode, recovery: .retry)
        case 503:
            let retryAfter = extractRetryAfter(from: data) ?? 300
            return .apiError("Service temporarily unavailable for maintenance.", statusCode: statusCode, recovery: .retryAfter(TimeInterval(retryAfter)))
        case 504:
            return .timeoutError("Gateway timeout. Please try again.")
        default:
            let message: String
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                message = "Server error (\(statusCode)): \(responseString)"
            } else {
                message = "Unexpected server error (\(statusCode))"
            }
            return .apiError(message, statusCode: statusCode, recovery: .retry)
        }
    }
    
    /// Extract error message from response data
    private func extractErrorMessage(from data: Data?) -> String? {
        guard let data = data else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Try common error message fields
                if let message = json["message"] as? String { return message }
                if let error = json["error"] as? String { return error }
                if let detail = json["detail"] as? String { return detail }
                
                // Handle FastAPI validation errors
                if let validationErrors = json["detail"] as? [[String: Any]] {
                    let messages = validationErrors.compactMap { error in
                        if let msg = error["msg"] as? String,
                           let loc = error["loc"] as? [Any] {
                            let location = loc.compactMap { "\($0)" }.joined(separator: ".")
                            return "\(location): \(msg)"
                        }
                        return error["msg"] as? String
                    }
                    if !messages.isEmpty {
                        return messages.joined(separator: "; ")
                    }
                }
            }
        } catch {
            // If JSON parsing fails, return raw string if readable
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    /// Extract retry-after value from response data
    private func extractRetryAfter(from data: Data?) -> TimeInterval? {
        guard let data = data else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let retryAfter = json["retry_after"] as? TimeInterval { return retryAfter }
                if let retryAfter = json["retryAfter"] as? TimeInterval { return retryAfter }
                if let retryAfter = json["retry-after"] as? TimeInterval { return retryAfter }
            }
        } catch {
            // Ignore JSON parsing errors
        }
        
        return nil
    }

    private func shouldRetryRequest(error: Error?, statusCode: Int?) -> Bool {
        if let statusCode {
            return statusCode == 429 || (500...599).contains(statusCode)
        }

        if let urlError = error as? URLError {
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

        return false
    }

    private func retryBackoffDelay(for attempt: Int) -> TimeInterval {
        let exponent = Double(max(0, attempt - 1))
        return min(0.8 * pow(2.0, exponent), 3.2)
    }

    private func retryDelay(
        for attempt: Int,
        statusCode: Int?,
        response: HTTPURLResponse? = nil,
        responseData: Data? = nil
    ) -> TimeInterval {
        let baseline = retryBackoffDelay(for: attempt)

        if let retryAfter = retryAfterSeconds(response: response, responseData: responseData) {
            return min(max(retryAfter, baseline), 30)
        }

        guard let statusCode else { return baseline }
        switch statusCode {
        case 503:
            return min(max(Double(attempt) * 2.5, baseline), 12)
        case 429:
            return min(max(Double(attempt) * 1.8, baseline), 10)
        case 500...599:
            return min(max(Double(attempt) * 1.2, baseline), 8)
        default:
            return baseline
        }
    }

    private func retryAfterSeconds(response: HTTPURLResponse?, responseData: Data?) -> TimeInterval? {
        if let retryAfterHeader = response?.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !retryAfterHeader.isEmpty {
            if let seconds = TimeInterval(retryAfterHeader), seconds > 0 {
                return seconds
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
            if let date = formatter.date(from: retryAfterHeader) {
                return max(0, date.timeIntervalSinceNow)
            }
        }

        if let responseData, let retryAfter = extractRetryAfter(from: responseData), retryAfter > 0 {
            return retryAfter
        }

        return nil
    }

    private func normalizeRequestError(_ error: Error) -> Error {
        if let apiError = error as? APIError {
            return apiError
        }
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return APIError.serverError(statusCode: -1, message: "Request timed out. The server may be slow or unresponsive.")
        }
        return error
    }

    private func executeRecipeGenerationRequest(
        request: URLRequest,
        lifecycle: (@Sendable (RecipeGenerationMilestone) -> Void)?,
        debugContext: String,
        notFoodImageMessage: String,
        noIngredientsMessage: String
    ) async throws -> APIResponse {
        // Render cold-starts can take 20-40s; give the broker a few more chances before surfacing
        // the "chef is busy" failure to the user.
        let maxAttempts = 6
        var attempt = 1

        while true {
            let startTime = Date()
            do {
                let (data, response) = try await session.data(for: request)
                let elapsed = Date().timeIntervalSince(startTime)
                apiDebugLog("📡 \(debugContext) request attempt \(attempt) completed in \(String(format: "%.2f", elapsed)) seconds")

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.noData
                }

                apiDebugLog("📡 \(debugContext) status code: \(httpResponse.statusCode)")
                lifecycle?(.responseReceived)

                if httpResponse.statusCode == 401 {
                    let fallback = String(data: data, encoding: .utf8) ?? "Invalid or missing API credentials."
                    let message = extractErrorMessage(from: data) ?? fallback
                    throw APIError.unauthorized(message)
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    if shouldRetryRequest(error: nil, statusCode: httpResponse.statusCode), attempt < maxAttempts {
                        let delay = retryDelay(
                            for: attempt,
                            statusCode: httpResponse.statusCode,
                            response: httpResponse,
                            responseData: data
                        )
                        apiDebugLog("🔁 Retrying \(debugContext) request (\(attempt + 1)/\(maxAttempts)) in \(String(format: "%.1f", delay))s due to HTTP \(httpResponse.statusCode)")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        attempt += 1
                        continue
                    }
                    let fallback = String(data: data, encoding: .utf8) ?? "N/A"
                    let responseMessage = extractErrorMessage(from: data) ?? fallback
                    throw APIError.serverError(statusCode: httpResponse.statusCode, message: responseMessage)
                }

                let apiResponse: APIResponse
                do {
                    apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
                } catch {
                    throw APIError.decodingError(error.localizedDescription)
                }

                lifecycle?(.responseDecoded)
                apiDebugLog("✅ \(debugContext) response decoded")
                apiDebugLog("✅ Image analysis - is_food_image: \(apiResponse.data.image_analysis.is_food_image), confidence: \(apiResponse.data.image_analysis.confidence)")
                apiDebugLog("✅ Found \(apiResponse.data.recipes.count) recipes")
                apiDebugLog("✅ Found \(apiResponse.data.ingredients.count) ingredients")

                if !apiResponse.data.image_analysis.is_food_image {
                    throw APIError.notFoodImage(notFoodImageMessage)
                }
                if apiResponse.data.ingredients.isEmpty {
                    throw APIError.noIngredientsDetected(noIngredientsMessage)
                }
                if !apiResponse.data.ingredients.isEmpty && apiResponse.data.recipes.isEmpty {
                    throw APIError.noIngredientsDetected("I found some ingredients but couldn't create recipes. This might be due to very limited ingredients or dietary restrictions being too specific. Try with more ingredients or adjust your preferences! 🥘")
                }

                return apiResponse
            } catch {
                if let urlError = error as? URLError, urlError.code == .timedOut, attempt >= 2 {
                    // A timed-out attempt already waited for the full request timeout; avoid compounding
                    // into multi-minute retry loops.
                    throw normalizeRequestError(error)
                }
                if shouldRetryRequest(error: error, statusCode: nil), attempt < maxAttempts {
                    let delay = retryDelay(for: attempt, statusCode: nil)
                    apiDebugLog("🔁 Retrying \(debugContext) request (\(attempt + 1)/\(maxAttempts)) in \(String(format: "%.1f", delay))s due to network error: \(error.localizedDescription)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                    continue
                }
                throw normalizeRequestError(error)
            }
        }
    }

    /// Convert SnapChefError to APIError for backward compatibility
    private func convertSnapChefErrorToAPIError(_ snapChefError: SnapChefError) -> APIError {
        switch snapChefError {
        case .networkError(let message, _):
            return APIError.serverError(statusCode: -1, message: message)
        case .apiError(let message, let statusCode, _):
            return APIError.serverError(statusCode: statusCode ?? 500, message: message)
        case .timeoutError(let message, _):
            return APIError.serverError(statusCode: 408, message: message)
        case .authenticationError(_, _):
            return APIError.authenticationError
        case .unauthorizedError(let message, _):
            return APIError.unauthorized(message)
        case .validationError(let message, _):
            return APIError.decodingError(message)
        case .rateLimitError(let message, _):
            return APIError.serverError(statusCode: 429, message: message)
        case .imageProcessingError(let message, _):
            return APIError.notFoodImage(message)
        case .recipeGenerationError(let message, _):
            return APIError.noIngredientsDetected(message)
        default:
            return APIError.serverError(statusCode: 500, message: snapChefError.errorDescription ?? "Unknown error")
        }
    }
    
    // MARK: - Recipe Detective API
    
    /// Analyzes a restaurant meal photo to reverse-engineer the recipe
    func analyzeRestaurantMeal(
        image: UIImage,
        sessionID: String,
        llmProvider: LLMProvider = .gemini
    ) async throws -> DetectiveRecipeResponse {
        guard let url = URL(string: "\(serverBaseURL)/analyze_meal_photo") else {
            throw APIError.invalidURL
        }
        
        apiDebugLog("🔍 Detective API Request to: \(url.absoluteString)")
        apiDebugLog("🔍 Using LLM Provider: \(llmProvider.rawValue)")
        
        let request = try createDetectiveMultipartRequest(
            url: url,
            image: image,
            sessionID: sessionID,
            llmProvider: llmProvider
        )
        
        apiDebugLog("🔍 Sending detective analysis request with session ID: \(sessionID)")
        apiDebugLog("🔍 Request body size: \(request.httpBody?.count ?? 0) bytes")

        // Detective calls hit the same Render broker; allow a few more retries for cold-start recovery.
        let maxAttempts = 6
        var attempt = 1

        while true {
            let startTime = Date()
            do {
                let (data, response) = try await session.data(for: request)
                let elapsed = Date().timeIntervalSince(startTime)
                apiDebugLog("🔍 Detective request attempt \(attempt) completed in \(String(format: "%.2f", elapsed)) seconds")

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.noData
                }

                apiDebugLog("🔍 Detective response status code: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 401 {
                    let fallback = String(data: data, encoding: .utf8) ?? "Invalid or missing API credentials."
                    let message = self.extractErrorMessage(from: data) ?? fallback
                    throw APIError.unauthorized(message)
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    if shouldRetryRequest(error: nil, statusCode: httpResponse.statusCode), attempt < maxAttempts {
                        let delay = retryDelay(
                            for: attempt,
                            statusCode: httpResponse.statusCode,
                            response: httpResponse,
                            responseData: data
                        )
                        apiDebugLog("🔁 Retrying detective analysis (\(attempt + 1)/\(maxAttempts)) in \(String(format: "%.1f", delay))s due to HTTP \(httpResponse.statusCode)")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        attempt += 1
                        continue
                    }
                    let fallback = String(data: data, encoding: .utf8) ?? "N/A"
                    let responseMessage = self.extractErrorMessage(from: data) ?? fallback
                    throw APIError.serverError(statusCode: httpResponse.statusCode, message: responseMessage)
                }

                let detectiveResponse = try JSONDecoder().decode(DetectiveRecipeResponse.self, from: data)
                apiDebugLog("✅ Successfully decoded detective response")
                apiDebugLog("✅ Success: \(detectiveResponse.success)")

                if let recipe = detectiveResponse.detectiveRecipe {
                    apiDebugLog("✅ Recipe: \(recipe.name)")
                    apiDebugLog("✅ Confidence: \(recipe.confidenceScore)%")
                    apiDebugLog("✅ Original dish: \(recipe.originalDishName)")
                }

                return detectiveResponse
            } catch {
                if let urlError = error as? URLError, urlError.code == .timedOut, attempt >= 2 {
                    throw normalizeRequestError(error)
                }
                if shouldRetryRequest(error: error, statusCode: nil), attempt < maxAttempts {
                    let delay = retryDelay(for: attempt, statusCode: nil)
                    apiDebugLog("🔁 Retrying detective analysis (\(attempt + 1)/\(maxAttempts)) in \(String(format: "%.1f", delay))s due to network error: \(error.localizedDescription)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                    continue
                }
                throw normalizeRequestError(error)
            }
        }
    }
    
    /// Create multipart request for detective analysis
    private func createDetectiveMultipartRequest(
        url: URL,
        image: UIImage,
        sessionID: String,
        llmProvider: LLMProvider
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        try applyAuthenticationHeaders(to: &request, requiresAppAPIKey: true)
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var httpBody = Data()
        
        // Helper to append form fields
        func appendFormField(name: String, value: String) {
            httpBody.append("--\(boundary)\r\n")
            httpBody.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            httpBody.append("\(value)\r\n")
        }
        
        // Required fields for detective analysis
        appendFormField(name: "session_id", value: sessionID)
        appendFormField(name: "analysis_type", value: "detective")
        appendFormField(name: "llm_provider", value: llmProvider.rawValue)
        
        // Resize image to optimize for analysis
        let resizedImage = image.resized(withMaxDimension: 2_048)
        apiDebugLog("🔍 Detective image - Original: \(image.size.width)x\(image.size.height), Resized: \(resizedImage.size.width)x\(resizedImage.size.height)")
        
        // Append image file with high quality for better analysis
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.9) else {
            throw APIError.invalidRequestData
        }
        
        let fileSizeMB = Double(imageData.count) / (1_024 * 1_024)
        apiDebugLog("🔍 Detective image file size: \(String(format: "%.2f", fileSizeMB)) MB")
        
        httpBody.append("--\(boundary)\r\n")
        httpBody.append("Content-Disposition: form-data; name=\"meal_image\"; filename=\"meal.jpg\"\r\n")
        httpBody.append("Content-Type: image/jpeg\r\n\r\n")
        httpBody.append(imageData)
        httpBody.append("\r\n")
        
        // Final boundary
        httpBody.append("--\(boundary)--\r\n")
        request.httpBody = httpBody
        
        return request
    }
    
    /// Converts DetectiveRecipeAPI to DetectiveRecipe model
    func convertAPIDetectiveRecipeToDetectiveRecipe(_ apiRecipe: DetectiveRecipeAPI) -> DetectiveRecipe {
        // Convert ingredients from new API structure
        let ingredients = apiRecipe.ingredients.map { ingredient in
            Ingredient(
                id: UUID(),
                name: ingredient.name,
                quantity: ingredient.amount,
                unit: ingredient.preparation,
                isAvailable: true
            )
        }
        
        // Convert nutrition from new API structure
        let nutrition = Nutrition(
            calories: apiRecipe.nutrition.calories,
            protein: apiRecipe.nutrition.protein,
            carbs: apiRecipe.nutrition.carbs,
            fat: apiRecipe.nutrition.fat,
            fiber: nil,
            sugar: nil,
            sodium: nil
        )
        
        // Convert difficulty
        let difficulty: Recipe.Difficulty
        switch apiRecipe.difficulty.lowercased() {
        case "easy":
            difficulty = .easy
        case "medium":
            difficulty = .medium
        case "hard":
            difficulty = .hard
        default:
            difficulty = .medium
        }
        
        // Extract dietary info from tags
        let tags = apiRecipe.tags
        let dietaryInfo = DietaryInfo(
            isVegetarian: tags.contains { $0.lowercased().contains("vegetarian") },
            isVegan: tags.contains { $0.lowercased().contains("vegan") },
            isGlutenFree: tags.contains { $0.lowercased().contains("gluten-free") || $0.lowercased().contains("gluten free") },
            isDairyFree: tags.contains { $0.lowercased().contains("dairy-free") || $0.lowercased().contains("dairy free") }
        )
        
        // Convert flavor profile
        let flavorProfile = DetectiveFlavorProfile(
            sweet: apiRecipe.flavorProfile.sweet,
            salty: apiRecipe.flavorProfile.salty,
            sour: apiRecipe.flavorProfile.sour,
            bitter: apiRecipe.flavorProfile.bitter,
            umami: apiRecipe.flavorProfile.umami
        )
        
        // Get the current user's ID for ownership
        let currentUserID = UnifiedAuthManager.shared.currentUser?.recordID
        
        // Generate a new unique ID for each detective recipe instead of using the API's hardcoded ID
        // This prevents conflicts when multiple detective recipes are created
        return DetectiveRecipe(
            id: UUID(), // Always generate a new UUID
            ownerID: currentUserID,
            name: apiRecipe.name,
            description: apiRecipe.description,
            ingredients: ingredients,
            instructions: apiRecipe.instructions,
            cookTime: apiRecipe.cookTime,
            prepTime: apiRecipe.prepTime,
            servings: apiRecipe.servings,
            difficulty: difficulty,
            nutrition: nutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: tags,
            dietaryInfo: dietaryInfo,
            confidenceScore: Double(apiRecipe.confidenceScore),
            originalDishName: apiRecipe.originalDishName,
            restaurantStyle: apiRecipe.restaurantStyle,
            analyzedAt: Date(),
            cookingTechniques: apiRecipe.cookingTechniques,
            flavorProfile: flavorProfile,
            secretIngredients: apiRecipe.secretIngredients,
            proTips: apiRecipe.proTips,
            visualClues: apiRecipe.visualClues,
            shareCaption: apiRecipe.shareCaption
        )
    }

    /// Converts API Recipe model to app's Recipe model
    func convertAPIRecipeToAppRecipe(_ apiRecipe: RecipeAPI) -> Recipe {
        // Convert ingredients
        let ingredients = (apiRecipe.ingredients_used ?? []).map { ingredientUsed in
            Ingredient(
                id: UUID(),
                name: ingredientUsed.name,
                quantity: ingredientUsed.amount,
                unit: nil,
                isAvailable: true
            )
        }

        // Convert nutrition
        let nutrition = Nutrition(
            calories: apiRecipe.nutrition?.calories ?? 0,
            protein: apiRecipe.nutrition?.protein ?? 0,
            carbs: apiRecipe.nutrition?.carbs ?? 0,
            fat: apiRecipe.nutrition?.fat ?? 0,
            fiber: apiRecipe.nutrition?.fiber,
            sugar: apiRecipe.nutrition?.sugar,
            sodium: apiRecipe.nutrition?.sodium
        )

        // Convert difficulty
        let difficulty: Recipe.Difficulty
        switch apiRecipe.difficulty.lowercased() {
        case "easy":
            difficulty = .easy
        case "medium":
            difficulty = .medium
        case "hard":
            difficulty = .hard
        default:
            difficulty = .medium
        }

        // Extract dietary info from tags
        let tags = apiRecipe.tags ?? []
        let dietaryInfo = DietaryInfo(
            isVegetarian: tags.contains { $0.lowercased().contains("vegetarian") },
            isVegan: tags.contains { $0.lowercased().contains("vegan") },
            isGlutenFree: tags.contains { $0.lowercased().contains("gluten-free") || $0.lowercased().contains("gluten free") },
            isDairyFree: tags.contains { $0.lowercased().contains("dairy-free") || $0.lowercased().contains("dairy free") }
        )

        // Convert flavor profile from API (optional)
        let flavorProfile: FlavorProfile?
        if let apiFlavorProfile = apiRecipe.flavor_profile {
            flavorProfile = FlavorProfile(
                sweet: apiFlavorProfile.sweet ?? 5,
                salty: apiFlavorProfile.salty ?? 5,
                sour: apiFlavorProfile.sour ?? 5,
                bitter: apiFlavorProfile.bitter ?? 5,
                umami: apiFlavorProfile.umami ?? 5
            )
        } else {
            flavorProfile = nil
        }

        // 🔍 DEBUG: Log enhanced fields during conversion
        apiDebugLog("🔍 CONVERTING API RECIPE '\(apiRecipe.name)' TO RECIPE MODEL:")
        apiDebugLog("🔍   - Raw cooking_techniques from API: \(apiRecipe.cooking_techniques ?? [])")
        apiDebugLog("🔍   - Raw secret_ingredients from API: \(apiRecipe.secret_ingredients ?? [])")
        apiDebugLog("🔍   - Raw pro_tips from API: \(apiRecipe.pro_tips ?? [])")
        apiDebugLog("🔍   - Raw visual_clues from API: \(apiRecipe.visual_clues ?? [])")
        apiDebugLog("🔍   - Raw share_caption from API: \"\(apiRecipe.share_caption ?? "")\"")
        apiDebugLog("🔍   - Converted flavor_profile: \(flavorProfile != nil ? "PRESENT" : "NIL")")

        // Get the current user's ID for ownership
        let currentUserID = UnifiedAuthManager.shared.currentUser?.recordID
        
        let convertedRecipe = Recipe(
            id: UUID(uuidString: apiRecipe.id) ?? UUID(),
            ownerID: currentUserID,
            name: apiRecipe.name,
            description: apiRecipe.description,
            ingredients: ingredients,
            instructions: apiRecipe.instructions,
            cookTime: apiRecipe.cook_time ?? 0,
            prepTime: apiRecipe.prep_time ?? 0,
            servings: apiRecipe.servings ?? 4,
            difficulty: difficulty,
            nutrition: nutrition,
            imageURL: nil,
            createdAt: Date(),
            tags: tags,
            dietaryInfo: dietaryInfo,
            isDetectiveRecipe: false, // Fridge Snap recipes
            cookingTechniques: apiRecipe.cooking_techniques ?? [],
            flavorProfile: flavorProfile,
            secretIngredients: apiRecipe.secret_ingredients ?? [],
            proTips: apiRecipe.pro_tips ?? [],
            visualClues: apiRecipe.visual_clues ?? [],
            shareCaption: apiRecipe.share_caption ?? ""
        )
        
        // 🔍 DEBUG: Log the final converted Recipe model values
        apiDebugLog("🔍 FINAL CONVERTED RECIPE MODEL VALUES:")
        apiDebugLog("🔍   - cookingTechniques: \(convertedRecipe.cookingTechniques.isEmpty ? "EMPTY" : "\(convertedRecipe.cookingTechniques)")")
        apiDebugLog("🔍   - flavorProfile: \(convertedRecipe.flavorProfile != nil ? "PRESENT" : "NIL")")
        apiDebugLog("🔍   - secretIngredients: \(convertedRecipe.secretIngredients.isEmpty ? "EMPTY" : "\(convertedRecipe.secretIngredients)")")
        apiDebugLog("🔍   - proTips: \(convertedRecipe.proTips.isEmpty ? "EMPTY" : "\(convertedRecipe.proTips)")")
        apiDebugLog("🔍   - visualClues: \(convertedRecipe.visualClues.isEmpty ? "EMPTY" : "\(convertedRecipe.visualClues)")")
        apiDebugLog("🔍   - shareCaption: \(convertedRecipe.shareCaption.isEmpty ? "EMPTY" : "\"\(convertedRecipe.shareCaption)\"")")
        
        return convertedRecipe
    }
}

// MARK: - LLM Provider Enum
enum LLMProvider: String, CaseIterable, Sendable {
    case gemini = "gemini"
    case grok = "grok"
    case openai = "openai"
    
    var displayName: String {
        switch self {
        case .gemini:
            return "Gemini"
        case .grok:
            return "Grok"
        case .openai:
            return "OpenAI"
        }
    }
}
