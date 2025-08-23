// SnapChefAPIManager.swift

import Foundation
import UIKit

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

    private let serverBaseURL = "https://snapchef-server.onrender.com"
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120 // 2 minutes timeout
        configuration.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: configuration)
    } // Private initializer for singleton

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

        // Set the authentication header using the securely stored key
        guard let apiKey = KeychainManager.shared.getAPIKey() else {
            throw APIError.unauthorized("API key not found. Please reinstall the app.")
        }
        request.setValue(apiKey, forHTTPHeaderField: "X-App-API-Key")
        print("🔑 API Key being sent in header: \(apiKey.prefix(10))...")
        
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
                print("Failed to serialize dietary restrictions")
                throw APIError.invalidRequestData
            }
            guard let restrictionsString = String(data: restrictionsData, encoding: .utf8) else {
                print("Failed to convert dietary restrictions to string")
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
                print("Failed to serialize existing recipe names")
                throw APIError.invalidRequestData
            }
            guard let existingRecipesString = String(data: existingRecipesData, encoding: .utf8) else {
                print("Failed to convert existing recipes to string")
                throw APIError.invalidRequestData
            }
            appendFormField(name: "existing_recipe_names", value: existingRecipesString)
        }

        // Append food preferences
        if !foodPreferences.isEmpty {
            guard let preferencesData = try? JSONSerialization.data(withJSONObject: foodPreferences, options: []) else {
                print("Failed to serialize food preferences")
                throw APIError.invalidRequestData
            }
            guard let preferencesString = String(data: preferencesData, encoding: .utf8) else {
                print("Failed to convert food preferences to string")
                throw APIError.invalidRequestData
            }
            appendFormField(name: "food_preferences", value: preferencesString)
        }

        // Resize image to max 2048x2048 to reduce file size while maintaining quality
        let resizedImage = image.resized(withMaxDimension: 2_048)

        // Log original and resized dimensions
        print("Original image size: \(image.size.width)x\(image.size.height)")
        print("Resized image size: \(resizedImage.size.width)x\(resizedImage.size.height)")

        // Append image_file with 80% JPEG compression
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            print("Failed to get JPEG data from image")
            throw APIError.invalidRequestData
        }

        // Log final file size
        let fileSizeMB = Double(imageData.count) / (1_024 * 1_024)
        print("Final image file size: \(String(format: "%.2f", fileSizeMB)) MB")
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
        completion: @escaping @Sendable (Result<APIResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(serverBaseURL)/analyze_fridge_image") else {
            completion(.failure(APIError.invalidURL))
            return
        }

        print("📡 API Request to: \(url.absoluteString)")
        let apiKey = KeychainManager.shared.getAPIKey()
        print("📡 API Key: \(apiKey != nil ? "[Found - \(apiKey!.prefix(10))...]" : "Not found")")
        print("📡 API Key Length: \(apiKey?.count ?? 0) characters")

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
        } catch {
            completion(.failure(error))
            return
        }

        print("📡 Sending request with session ID: \(sessionId)")
        print("📡 Request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("📡 Request body size: \(request.httpBody?.count ?? 0) bytes")

        let startTime = Date()
        session.dataTask(with: request) { data, response, error in
            let elapsed = Date().timeIntervalSince(startTime)
            print("📡 Request completed in \(String(format: "%.2f", elapsed)) seconds")

            if let error = error {
                print("❌ API Network Error: \(error.localizedDescription)")
                print("❌ Error details: \(error)")
                print("❌ Error domain: \((error as NSError).domain)")
                print("❌ Error code: \((error as NSError).code)")

                // Check if it's a timeout error
                if (error as NSError).code == NSURLErrorTimedOut {
                    print("❌ Request timed out after \(elapsed) seconds")
                    completion(.failure(APIError.serverError(statusCode: -1, message: "Request timed out. The server may be slow or unresponsive.")))
                } else {
                    completion(.failure(error))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                completion(.failure(APIError.noData))
                return
            }

            print("📡 Response status code: \(httpResponse.statusCode)")
            print("📡 Response headers: \(httpResponse.allHeaderFields)")

            // Handle authentication failure specifically
            if httpResponse.statusCode == 401 {
                completion(.failure(APIError.authenticationError))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let responseData = data.map { String(data: $0, encoding: .utf8) ?? "" } ?? "N/A"
                completion(.failure(APIError.serverError(statusCode: httpResponse.statusCode, message: responseData)))
                return
            }

            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }

            do {
                let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
                print("✅ Successfully decoded API response")
                print("✅ Image analysis - is_food_image: \(apiResponse.data.image_analysis.is_food_image), confidence: \(apiResponse.data.image_analysis.confidence)")
                print("✅ Found \(apiResponse.data.recipes.count) recipes")
                print("✅ Found \(apiResponse.data.ingredients.count) ingredients")
                
                // 🔍 DEBUG: Log raw JSON response for enhanced fields analysis
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔍 RAW SERVER RESPONSE:")
                    print("🔍 \(responseString)")
                } else {
                    print("🔍 Could not convert response data to string")
                }
                
                // 🔍 DEBUG: Log enhanced fields in each recipe from server response
                for (index, recipe) in apiResponse.data.recipes.enumerated() {
                    print("🔍 RECIPE \(index + 1) ENHANCED FIELDS FROM SERVER:")
                    print("🔍   - cooking_techniques: \(recipe.cooking_techniques?.isEmpty == false ? "\(recipe.cooking_techniques!)" : "EMPTY/NIL")")
                    print("🔍   - flavor_profile: \(recipe.flavor_profile != nil ? "PRESENT" : "NIL")")
                    if let fp = recipe.flavor_profile {
                        print("🔍     • sweet: \(fp.sweet ?? -1), salty: \(fp.salty ?? -1), sour: \(fp.sour ?? -1), bitter: \(fp.bitter ?? -1), umami: \(fp.umami ?? -1)")
                    }
                    print("🔍   - secret_ingredients: \(recipe.secret_ingredients?.isEmpty == false ? "\(recipe.secret_ingredients!)" : "EMPTY/NIL")")
                    print("🔍   - pro_tips: \(recipe.pro_tips?.isEmpty == false ? "\(recipe.pro_tips!)" : "EMPTY/NIL")")
                    print("🔍   - visual_clues: \(recipe.visual_clues?.isEmpty == false ? "\(recipe.visual_clues!)" : "EMPTY/NIL")")
                    print("🔍   - share_caption: \(recipe.share_caption?.isEmpty == false ? "\"\(recipe.share_caption!)\"" : "EMPTY/NIL")")
                }
                
                // Check if the image analysis indicates this is not a food image
                if !apiResponse.data.image_analysis.is_food_image {
                    let friendlyMessage = "Hmm, this doesn't look like a fridge or pantry photo. Let's try again with a clear shot of your ingredients! 📸"
                    completion(.failure(APIError.notFoodImage(friendlyMessage)))
                    return
                }
                
                // Check if we detected ingredients but got no recipes
                if apiResponse.data.ingredients.isEmpty {
                    let friendlyMessage = "I couldn't spot any ingredients in this photo. Try taking a clearer shot of your fridge or pantry with better lighting! 💡"
                    completion(.failure(APIError.noIngredientsDetected(friendlyMessage)))
                    return
                }
                
                // Check if we have ingredients but no recipes (another edge case)
                if !apiResponse.data.ingredients.isEmpty && apiResponse.data.recipes.isEmpty {
                    let friendlyMessage = "I found some ingredients but couldn't create recipes. This might be due to very limited ingredients or dietary restrictions being too specific. Try with more ingredients or adjust your preferences! 🥘"
                    completion(.failure(APIError.noIngredientsDetected(friendlyMessage)))
                    return
                }
                
                completion(.success(apiResponse))
            } catch {
                print("❌ Decoding Error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Raw response: \(responseString)")
                }
                completion(.failure(APIError.decodingError(error.localizedDescription)))
            }
        }.resume()
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
        completion: @escaping @Sendable (Result<APIResponse, Error>) -> Void
    ) {
        // For now, use the same endpoint but send both images
        // The backend should be updated to handle both images
        guard let url = URL(string: "\(serverBaseURL)/analyze_fridge_image") else {
            completion(.failure(APIError.invalidURL))
            return
        }

        print("📡 API Request to: \(url.absoluteString)")
        let apiKey = KeychainManager.shared.getAPIKey()
        print("📡 API Key: \(apiKey != nil ? "[Found - \(apiKey!.prefix(10))...]" : "Not found")")
        print("📡 API Key Length: \(apiKey?.count ?? 0) characters")
        print("📡 Sending both fridge and pantry images")

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
        } catch {
            completion(.failure(error))
            return
        }

        print("📡 Sending request with session ID: \(sessionId)")
        print("📡 Request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("📡 Request body size: \(request.httpBody?.count ?? 0) bytes")

        let startTime = Date()
        session.dataTask(with: request) { data, response, error in
            let elapsed = Date().timeIntervalSince(startTime)
            print("📡 Request completed in \(String(format: "%.2f", elapsed)) seconds")

            if let error = error {
                print("❌ API Network Error: \(error.localizedDescription)")
                print("❌ Error details: \(error)")
                print("❌ Error domain: \((error as NSError).domain)")
                print("❌ Error code: \((error as NSError).code)")

                // Check if it's a timeout error
                if (error as NSError).code == NSURLErrorTimedOut {
                    print("❌ Request timed out after \(elapsed) seconds")
                    completion(.failure(APIError.serverError(statusCode: -1, message: "Request timed out. The server may be slow or unresponsive.")))
                } else {
                    completion(.failure(error))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                completion(.failure(APIError.noData))
                return
            }

            print("📡 Response status code: \(httpResponse.statusCode)")
            print("📡 Response headers: \(httpResponse.allHeaderFields)")

            // Handle authentication failure specifically
            if httpResponse.statusCode == 401 {
                completion(.failure(APIError.authenticationError))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let responseData = data.map { String(data: $0, encoding: .utf8) ?? "" } ?? "N/A"
                completion(.failure(APIError.serverError(statusCode: httpResponse.statusCode, message: responseData)))
                return
            }

            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }

            do {
                let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
                print("✅ Successfully decoded API response for both images")
                print("✅ Image analysis - is_food_image: \(apiResponse.data.image_analysis.is_food_image), confidence: \(apiResponse.data.image_analysis.confidence)")
                print("✅ Found \(apiResponse.data.recipes.count) recipes")
                print("✅ Found \(apiResponse.data.ingredients.count) ingredients")
                
                // Check if the image analysis indicates this is not a food image
                if !apiResponse.data.image_analysis.is_food_image {
                    let friendlyMessage = "Hmm, one or both of these photos don't look like fridge or pantry shots. Let's try again with clear photos of your ingredients! 📸"
                    completion(.failure(APIError.notFoodImage(friendlyMessage)))
                    return
                }
                
                // Check if we detected ingredients but got no recipes
                if apiResponse.data.ingredients.isEmpty {
                    let friendlyMessage = "I couldn't spot any ingredients in these photos. Try taking clearer shots of your fridge and pantry with better lighting! 💡"
                    completion(.failure(APIError.noIngredientsDetected(friendlyMessage)))
                    return
                }
                
                // Check if we have ingredients but no recipes
                if !apiResponse.data.ingredients.isEmpty && apiResponse.data.recipes.isEmpty {
                    let friendlyMessage = "I found some ingredients but couldn't create recipes. This might be due to very limited ingredients or dietary restrictions being too specific. Try with more ingredients or adjust your preferences! 🥘"
                    completion(.failure(APIError.noIngredientsDetected(friendlyMessage)))
                    return
                }
                
                completion(.success(apiResponse))
            } catch {
                print("❌ Decoding Error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Raw response: \(responseString)")
                }
                completion(.failure(APIError.decodingError(error.localizedDescription)))
            }
        }.resume()
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

        // Set the authentication header using the securely stored key
        guard let apiKey = KeychainManager.shared.getAPIKey() else {
            throw APIError.unauthorized("API key not found. Please reinstall the app.")
        }
        request.setValue(apiKey, forHTTPHeaderField: "X-App-API-Key")
        print("🔑 API Key being sent in header: \(apiKey.prefix(10))...")
        
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
                print("Failed to serialize dietary restrictions")
                throw APIError.invalidRequestData
            }
            guard let restrictionsString = String(data: restrictionsData, encoding: .utf8) else {
                print("Failed to convert dietary restrictions to string")
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
                print("Failed to serialize existing recipe names")
                throw APIError.invalidRequestData
            }
            guard let existingRecipesString = String(data: existingRecipesData, encoding: .utf8) else {
                print("Failed to convert existing recipes to string")
                throw APIError.invalidRequestData
            }
            appendFormField(name: "existing_recipe_names", value: existingRecipesString)
        }

        // Append food preferences
        if !foodPreferences.isEmpty {
            guard let preferencesData = try? JSONSerialization.data(withJSONObject: foodPreferences, options: []) else {
                print("Failed to serialize food preferences")
                throw APIError.invalidRequestData
            }
            guard let preferencesString = String(data: preferencesData, encoding: .utf8) else {
                print("Failed to convert food preferences to string")
                throw APIError.invalidRequestData
            }
            appendFormField(name: "food_preferences", value: preferencesString)
        }

        // Resize images to max 2048x2048 to reduce file size while maintaining quality
        let resizedFridgeImage = fridgeImage.resized(withMaxDimension: 2_048)
        let resizedPantryImage = pantryImage.resized(withMaxDimension: 2_048)

        // Log original and resized dimensions
        print("Fridge image - Original: \(fridgeImage.size.width)x\(fridgeImage.size.height), Resized: \(resizedFridgeImage.size.width)x\(resizedFridgeImage.size.height)")
        print("Pantry image - Original: \(pantryImage.size.width)x\(pantryImage.size.height), Resized: \(resizedPantryImage.size.width)x\(resizedPantryImage.size.height)")

        // Append fridge image file with 80% JPEG compression
        guard let fridgeImageData = resizedFridgeImage.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert fridge image to JPEG data")
            throw APIError.invalidRequestData
        }

        httpBody.append("--\(boundary)\r\n")
        httpBody.append("Content-Disposition: form-data; name=\"fridge_image\"; filename=\"fridge.jpg\"\r\n")
        httpBody.append("Content-Type: image/jpeg\r\n\r\n")
        httpBody.append(fridgeImageData)
        httpBody.append("\r\n")

        print("Fridge image data size: \(fridgeImageData.count) bytes (\(String(format: "%.2f", Double(fridgeImageData.count) / 1_024 / 1_024)) MB)")

        // Append pantry image file with 80% JPEG compression
        guard let pantryImageData = resizedPantryImage.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert pantry image to JPEG data")
            throw APIError.invalidRequestData
        }

        httpBody.append("--\(boundary)\r\n")
        httpBody.append("Content-Disposition: form-data; name=\"pantry_image\"; filename=\"pantry.jpg\"\r\n")
        httpBody.append("Content-Type: image/jpeg\r\n\r\n")
        httpBody.append(pantryImageData)
        httpBody.append("\r\n")

        print("Pantry image data size: \(pantryImageData.count) bytes (\(String(format: "%.2f", Double(pantryImageData.count) / 1_024 / 1_024)) MB)")

        // Close the multipart form
        httpBody.append("--\(boundary)--\r\n")

        request.httpBody = httpBody
        print("Total request body size: \(httpBody.count) bytes (\(String(format: "%.2f", Double(httpBody.count) / 1_024 / 1_024)) MB)")

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
                    if case .authenticationError = error,
                       case .unauthorizedError = error,
                       case .validationError = error {
                        throw error
                    }
                    
                    // For retryable errors, store and continue to retry logic
                    lastError = error
                    
                    // Log retry attempt
                    ErrorAnalytics.logError(error, context: "api_retry_attempt_\(attempt + 1)_\(operationId)")
                    
                    if attempt < maxRetries - 1 {
                        let delay = calculateBackoffDelay(attempt: attempt, baseDelay: baseDelay)
                        print("[API] Retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    } else {
                        throw error
                    }
                }
                
                // Success case - decode response
                do {
                    let decoded = try JSONDecoder().decode(responseType, from: data)
                    print("[API] Request succeeded on attempt \(attempt + 1)")
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
                        print("[API] Network error, retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    } else {
                        throw snapChefError
                    }
                } else {
                    // Other errors (e.g., SnapChefError already)
                    if attempt < maxRetries - 1 {
                        let delay = calculateBackoffDelay(attempt: attempt, baseDelay: baseDelay)
                        print("[API] Error, retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")
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
        
        print("🔍 Detective API Request to: \(url.absoluteString)")
        print("🔍 Using LLM Provider: \(llmProvider.rawValue)")
        
        let request = try createDetectiveMultipartRequest(
            url: url,
            image: image,
            sessionID: sessionID,
            llmProvider: llmProvider
        )
        
        print("🔍 Sending detective analysis request with session ID: \(sessionID)")
        print("🔍 Request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("🔍 Request body size: \(request.httpBody?.count ?? 0) bytes")
        
        let startTime = Date()
        
        return try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                let elapsed = Date().timeIntervalSince(startTime)
                print("🔍 Detective request completed in \(String(format: "%.2f", elapsed)) seconds")
                
                if let error = error {
                    print("❌ Detective API Network Error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response type")
                    continuation.resume(throwing: APIError.noData)
                    return
                }
                
                print("🔍 Detective response status code: \(httpResponse.statusCode)")
                
                // Handle authentication failure
                if httpResponse.statusCode == 401 {
                    continuation.resume(throwing: APIError.authenticationError)
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let responseData = data.map { String(data: $0, encoding: .utf8) ?? "" } ?? "N/A"
                    continuation.resume(throwing: APIError.serverError(statusCode: httpResponse.statusCode, message: responseData))
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: APIError.noData)
                    return
                }
                
                do {
                    let detectiveResponse = try JSONDecoder().decode(DetectiveRecipeResponse.self, from: data)
                    print("✅ Successfully decoded detective response")
                    print("✅ Success: \(detectiveResponse.success)")
                    
                    if let recipe = detectiveResponse.detectiveRecipe {
                        print("✅ Recipe: \(recipe.name)")
                        print("✅ Confidence: \(recipe.confidenceScore)%")
                        print("✅ Original dish: \(recipe.originalDishName)")
                    }
                    
                    continuation.resume(returning: detectiveResponse)
                } catch {
                    print("❌ Detective Decoding Error: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Raw response: \(responseString)")
                    }
                    continuation.resume(throwing: APIError.decodingError(error.localizedDescription))
                }
            }.resume()
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
        
        // Set the authentication header
        guard let apiKey = KeychainManager.shared.getAPIKey() else {
            throw APIError.unauthorized("API key not found. Please reinstall the app.")
        }
        request.setValue(apiKey, forHTTPHeaderField: "X-App-API-Key")
        print("🔑 Detective API Key being sent: \(apiKey.prefix(10))...")
        
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
        print("🔍 Detective image - Original: \(image.size.width)x\(image.size.height), Resized: \(resizedImage.size.width)x\(resizedImage.size.height)")
        
        // Append image file with high quality for better analysis
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.9) else {
            throw APIError.invalidRequestData
        }
        
        let fileSizeMB = Double(imageData.count) / (1_024 * 1_024)
        print("🔍 Detective image file size: \(String(format: "%.2f", fileSizeMB)) MB")
        
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
        
        return DetectiveRecipe(
            id: UUID(uuidString: apiRecipe.id) ?? UUID(),
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
        print("🔍 CONVERTING API RECIPE '\(apiRecipe.name)' TO RECIPE MODEL:")
        print("🔍   - Raw cooking_techniques from API: \(apiRecipe.cooking_techniques ?? [])")
        print("🔍   - Raw secret_ingredients from API: \(apiRecipe.secret_ingredients ?? [])")
        print("🔍   - Raw pro_tips from API: \(apiRecipe.pro_tips ?? [])")
        print("🔍   - Raw visual_clues from API: \(apiRecipe.visual_clues ?? [])")
        print("🔍   - Raw share_caption from API: \"\(apiRecipe.share_caption ?? "")\"")
        print("🔍   - Converted flavor_profile: \(flavorProfile != nil ? "PRESENT" : "NIL")")

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
        print("🔍 FINAL CONVERTED RECIPE MODEL VALUES:")
        print("🔍   - cookingTechniques: \(convertedRecipe.cookingTechniques.isEmpty ? "EMPTY" : "\(convertedRecipe.cookingTechniques)")")
        print("🔍   - flavorProfile: \(convertedRecipe.flavorProfile != nil ? "PRESENT" : "NIL")")
        print("🔍   - secretIngredients: \(convertedRecipe.secretIngredients.isEmpty ? "EMPTY" : "\(convertedRecipe.secretIngredients)")")
        print("🔍   - proTips: \(convertedRecipe.proTips.isEmpty ? "EMPTY" : "\(convertedRecipe.proTips)")")
        print("🔍   - visualClues: \(convertedRecipe.visualClues.isEmpty ? "EMPTY" : "\(convertedRecipe.visualClues)")")
        print("🔍   - shareCaption: \(convertedRecipe.shareCaption.isEmpty ? "EMPTY" : "\"\(convertedRecipe.shareCaption)\"")")
        
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
