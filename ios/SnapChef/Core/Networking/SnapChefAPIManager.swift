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

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The server URL is invalid."
        case .invalidRequestData: return "Failed to encode request data."
        case .noData: return "No data received from the server."
        case .serverError(let code, let message): return "Server error \(code): \(message)"
        case .decodingError(let details): return "Failed to decode server response: \(details)"
        case .authenticationError: return "Authentication failed. Please check your app's API key."
        case .unauthorized(let message): return message
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
            let restrictionsString = String(data: restrictionsData, encoding: .utf8)!
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
            let existingRecipesString = String(data: existingRecipesData, encoding: .utf8)!
            appendFormField(name: "existing_recipe_names", value: existingRecipesString)
        }

        // Append food preferences
        if !foodPreferences.isEmpty {
            guard let preferencesData = try? JSONSerialization.data(withJSONObject: foodPreferences, options: []) else {
                print("Failed to serialize food preferences")
                throw APIError.invalidRequestData
            }
            let preferencesString = String(data: preferencesData, encoding: .utf8)!
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
        completion: @escaping (Result<APIResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(serverBaseURL)/analyze_fridge_image") else {
            completion(.failure(APIError.invalidURL))
            return
        }

        print("📡 API Request to: \(url.absoluteString)")
        print("📡 API Key: \(KeychainManager.shared.getAPIKey() != nil ? "[REDACTED]" : "Not found")")

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

        let startTime = Date()
        session.dataTask(with: request) { data, response, error in
            let elapsed = Date().timeIntervalSince(startTime)
            print("📡 Request completed in \(String(format: "%.2f", elapsed)) seconds")

            if let error = error {
                print("❌ API Error: \(error.localizedDescription)")
                print("❌ Error details: \(error)")

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
                print("✅ Found \(apiResponse.data.recipes.count) recipes")
                print("✅ Found \(apiResponse.data.ingredients.count) ingredients")
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
        completion: @escaping (Result<APIResponse, Error>) -> Void
    ) {
        // For now, use the same endpoint but send both images
        // The backend should be updated to handle both images
        guard let url = URL(string: "\(serverBaseURL)/analyze_fridge_image") else {
            completion(.failure(APIError.invalidURL))
            return
        }

        print("📡 API Request to: \(url.absoluteString)")
        print("📡 API Key: \(KeychainManager.shared.getAPIKey() != nil ? "[REDACTED]" : "Not found")")
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

        let startTime = Date()
        session.dataTask(with: request) { data, response, error in
            let elapsed = Date().timeIntervalSince(startTime)
            print("📡 Request completed in \(String(format: "%.2f", elapsed)) seconds")

            if let error = error {
                print("❌ API Error: \(error.localizedDescription)")
                print("❌ Error details: \(error)")

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
                print("✅ Found \(apiResponse.data.recipes.count) recipes")
                print("✅ Found \(apiResponse.data.ingredients.count) ingredients")
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
            let restrictionsString = String(data: restrictionsData, encoding: .utf8)!
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
            let existingRecipesString = String(data: existingRecipesData, encoding: .utf8)!
            appendFormField(name: "existing_recipe_names", value: existingRecipesString)
        }

        // Append food preferences
        if !foodPreferences.isEmpty {
            guard let preferencesData = try? JSONSerialization.data(withJSONObject: foodPreferences, options: []) else {
                print("Failed to serialize food preferences")
                throw APIError.invalidRequestData
            }
            let preferencesString = String(data: preferencesData, encoding: .utf8)!
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

        return Recipe(
            id: UUID(uuidString: apiRecipe.id) ?? UUID(),
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
            dietaryInfo: dietaryInfo
        )
    }
}
