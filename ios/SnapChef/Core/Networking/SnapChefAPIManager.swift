// SnapChefAPIManager.swift

import Foundation
import UIKit // For UIImage

// MARK: - API Key
// The API key is now securely stored in the Keychain
// Fallback key is only used if Keychain access fails (should never happen in normal use)
private let FALLBACK_API_KEY = "5380e4b60818cf237678fccfd4b8f767d1c94"

// MARK: - API Error Handling
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidRequestData
    case noData
    case serverError(statusCode: Int, message: String)
    case decodingError(String)
    case authenticationError // For 401 Unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The server URL is invalid."
        case .invalidRequestData: return "Failed to encode request data."
        case .noData: return "No data received from the server."
        case .serverError(let code, let message): return "Server error \(code): \(message)"
        case .decodingError(let details): return "Failed to decode server response: \(details)"
        case .authenticationError: return "Authentication failed. Please check your app's API key."
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
class SnapChefAPIManager {
    static let shared = SnapChefAPIManager() // Singleton instance
    
    private let serverBaseURL = "https://snapchef-server.onrender.com"
    private let session = URLSession.shared

    private init() {} // Private initializer for singleton

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
        numberOfRecipes: Int?
    ) -> URLRequest? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Set the authentication header using the securely stored key
        let apiKey = KeychainManager.shared.getAPIKey() ?? FALLBACK_API_KEY
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
                return nil
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

        // Append image_file
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to get JPEG data from image")
            return nil
        }
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
        completion: @escaping (Result<APIResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(serverBaseURL)/analyze_fridge_image") else {
            completion(.failure(APIError.invalidURL))
            return
        }

        guard let request = createMultipartRequest(
            url: url,
            image: image,
            sessionId: sessionId,
            dietaryRestrictions: dietaryRestrictions,
            foodType: foodType,
            difficultyPreference: difficultyPreference,
            healthPreference: healthPreference,
            mealType: mealType,
            cookingTimePreference: cookingTimePreference,
            numberOfRecipes: numberOfRecipes
        ) else {
            completion(.failure(APIError.invalidRequestData))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.noData))
                return
            }

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
                completion(.success(apiResponse))
            } catch {
                print("Decoding Error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response: \(responseString)")
                }
                completion(.failure(APIError.decodingError(error.localizedDescription)))
            }
        }.resume()
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
            createdAt: Date()
        )
    }
}