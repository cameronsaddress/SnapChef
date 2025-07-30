# SnapChef API Documentation

## Overview

SnapChef uses a FastAPI backend hosted on Render that integrates with the Grok Vision API for intelligent recipe generation from food photos.

## Base Configuration

### Server Details
- **Production URL**: `https://snapchef-server.onrender.com`
- **Development URL**: `https://api-dev.snapchef.app`
- **API Version**: v1
- **Protocol**: HTTPS only

### Authentication
All API requests require authentication via API key:

```
Header: X-App-API-Key
Value: [Stored in iOS Keychain]
```

## Endpoints

### 1. Analyze Fridge Image

**Endpoint**: `POST /analyze_fridge_image`

**Description**: Analyzes a photo of fridge/pantry contents and returns personalized recipe suggestions.

#### Request

**Content-Type**: `multipart/form-data`

**Parameters**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `image_file` | File | Yes | JPEG image of fridge/pantry (max 10MB) |
| `session_id` | String | Yes | UUID for tracking user session |
| `dietary_restrictions` | JSON Array | No | List of dietary restrictions |
| `food_type` | String | No | Preferred cuisine type |
| `difficulty_preference` | String | No | `easy`, `medium`, `hard` |
| `health_preference` | String | No | `healthy`, `balanced`, `indulgent` |
| `meal_type` | String | No | `breakfast`, `lunch`, `dinner`, `snack` |
| `cooking_time_preference` | String | No | `quick`, `moderate`, `leisurely` |
| `number_of_recipes` | String | No | Number of recipes to return (default: 3) |

**Example Request**:
```swift
let formData = MultipartFormData()
formData.append(imageData, withName: "image_file", fileName: "fridge.jpg", mimeType: "image/jpeg")
formData.append(sessionId.data(using: .utf8)!, withName: "session_id")
formData.append("[\"vegetarian\", \"gluten-free\"]".data(using: .utf8)!, withName: "dietary_restrictions")
formData.append("Italian".data(using: .utf8)!, withName: "food_type")
formData.append("easy".data(using: .utf8)!, withName: "difficulty_preference")
```

#### Response

**Content-Type**: `application/json`

**Success Response (200)**:
```json
{
  "data": {
    "image_analysis": {
      "detected_items": ["tomatoes", "mozzarella", "basil", "pasta"],
      "freshness_score": 0.85,
      "quantity_estimate": "sufficient for 2-3 meals"
    },
    "ingredients": [
      {
        "name": "tomatoes",
        "quantity": "4 medium",
        "category": "produce",
        "alternatives": ["canned tomatoes", "cherry tomatoes"]
      }
    ],
    "recipes": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "name": "Classic Margherita Pasta",
        "description": "A simple yet delicious Italian pasta dish",
        "cuisine_type": "Italian",
        "meal_type": "dinner",
        "difficulty": "easy",
        "prep_time": 10,
        "cook_time": 20,
        "total_time": 30,
        "servings": 4,
        "ingredients": [
          "400g pasta",
          "4 tomatoes, diced",
          "200g mozzarella",
          "Fresh basil leaves",
          "2 cloves garlic",
          "Olive oil",
          "Salt and pepper"
        ],
        "instructions": [
          "Bring a large pot of salted water to boil",
          "Cook pasta according to package directions",
          "Meanwhile, heat olive oil and sauté garlic",
          "Add tomatoes and cook until soft",
          "Drain pasta and combine with sauce",
          "Top with mozzarella and basil"
        ],
        "tips": [
          "Use San Marzano tomatoes for best flavor",
          "Save pasta water to adjust sauce consistency"
        ],
        "tags": ["vegetarian", "quick", "italian"],
        "nutrition": {
          "calories": 420,
          "protein": 16,
          "fat": 12,
          "carbs": 65,
          "fiber": 4,
          "sugar": 8,
          "sodium": 320
        },
        "image_url": null,
        "rating": 4.5,
        "matched_ingredients": ["tomatoes", "mozzarella", "basil"],
        "missing_ingredients": ["garlic", "pasta"],
        "shopping_list": ["garlic", "pasta", "olive oil"]
      }
    ]
  },
  "message": "Successfully analyzed image and generated recipes"
}
```

**Error Responses**:

- **400 Bad Request**: Invalid request data
```json
{
  "detail": "Invalid image format. Please upload a JPEG or PNG image."
}
```

- **401 Unauthorized**: Invalid or missing API key
```json
{
  "detail": "Invalid API key"
}
```

- **413 Payload Too Large**: Image file too big
```json
{
  "detail": "Image size exceeds 10MB limit"
}
```

- **429 Too Many Requests**: Rate limit exceeded
```json
{
  "detail": "Rate limit exceeded. Please try again later."
}
```

- **500 Internal Server Error**: Server or Grok API error
```json
{
  "detail": "Failed to process image. Please try again."
}
```

### 2. Health Check

**Endpoint**: `GET /health`

**Description**: Check if the API server is running.

**Response**:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2024-01-20T12:00:00Z"
}
```

## Data Models

### Recipe Model
```swift
struct Recipe: Codable {
    let id: String
    let name: String
    let description: String
    let cuisineType: String
    let mealType: String
    let difficulty: String
    let prepTime: Int
    let cookTime: Int
    let totalTime: Int
    let servings: Int
    let ingredients: [String]
    let instructions: [String]
    let tips: [String]
    let tags: [String]
    let nutrition: Nutrition?
    let imageUrl: String?
    let rating: Double?
    let matchedIngredients: [String]
    let missingIngredients: [String]
    let shoppingList: [String]
}

struct Nutrition: Codable {
    let calories: Int
    let protein: Int
    let fat: Int
    let carbs: Int
    let fiber: Int?
    let sugar: Int?
    let sodium: Int?
}
```

### Ingredient Model
```swift
struct Ingredient: Codable {
    let name: String
    let quantity: String
    let category: String
    let alternatives: [String]?
}
```

## Best Practices

### Request Optimization
1. **Image Compression**: Compress images to ~80% JPEG quality before upload
2. **Image Size**: Resize images to max 2048x2048 pixels
3. **Caching**: Cache recipe results locally to reduce API calls
4. **Session Management**: Reuse session IDs for the same user

### Error Handling
```swift
do {
    let recipes = try await SnapChefAPIManager.shared.sendImageForRecipeGeneration(
        image: capturedImage,
        preferences: userPreferences
    )
} catch let error as APIError {
    switch error {
    case .authenticationError:
        // Refresh API key from Keychain
    case .serverError(let code, let message):
        // Show user-friendly error
    default:
        // Generic error handling
    }
}
```

### Rate Limiting
- **Free tier**: 100 requests per day
- **Pro tier**: 1000 requests per day
- **Headers returned**: `X-RateLimit-Remaining`, `X-RateLimit-Reset`

### Timeouts
- **Connection timeout**: 10 seconds
- **Request timeout**: 30 seconds
- **Large image processing**: Up to 60 seconds

## iOS Implementation

### Network Configuration
```swift
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 30
configuration.timeoutIntervalForResource = 60
configuration.waitsForConnectivity = true
```

### Multipart Form Creation
```swift
private func createMultipartFormData(
    image: UIImage,
    parameters: [String: String]
) -> Data {
    var body = Data()
    let boundary = UUID().uuidString
    
    // Add image
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"image_file\"; filename=\"fridge.jpg\"\r\n")
    body.append("Content-Type: image/jpeg\r\n\r\n")
    body.append(image.jpegData(compressionQuality: 0.8)!)
    body.append("\r\n")
    
    // Add parameters
    for (key, value) in parameters {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
        body.append("\(value)\r\n")
    }
    
    body.append("--\(boundary)--\r\n")
    return body
}
```

## Testing

### Test Endpoints
- Development server: `https://api-dev.snapchef.app`
- Use test API key for development

### Mock Responses
The iOS app includes `MockDataProvider` for offline testing and UI development.

## Security Considerations

1. **API Key Storage**: Store in iOS Keychain, never in code
2. **Certificate Pinning**: Implement for production
3. **Request Signing**: Consider HMAC for additional security
4. **Data Encryption**: All data transmitted over HTTPS
5. **PII Handling**: No personal information in image uploads

## Monitoring

### Analytics Events
- `api_request_sent`
- `api_response_received`
- `api_error_occurred`
- `image_upload_started`
- `recipe_generated`

### Performance Metrics
- Average response time: < 3 seconds
- Image upload time: < 5 seconds
- Success rate target: > 95%