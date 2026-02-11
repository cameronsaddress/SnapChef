#!/usr/bin/env python3
"""
Test script that mimics iOS app's API submission to SnapChef server.
This tests the multipart/form-data request format and verifies the response structure.
"""

import requests
import json
import uuid
import os
from pathlib import Path
from typing import Dict, List, Optional
import pprint

# API Configuration
API_BASE_URL = "https://snapchef-server.onrender.com"
API_ENDPOINT = "/analyze_fridge_image"
API_KEY = os.environ.get("SNAPCHEF_API_KEY", "")

# Test image path
TEST_IMAGE_PATH = Path(__file__).parent / "webapp-archive" / "assets" / "fridge.jpg"


def test_api_submission(
    image_path: Path,
    dietary_restrictions: List[str] = None,
    food_type: Optional[str] = None,
    difficulty_preference: Optional[str] = None,
    health_preference: Optional[str] = None,
    meal_type: Optional[str] = None,
    cooking_time_preference: Optional[str] = None,
    number_of_recipes: Optional[int] = None
) -> Dict:
    """
    Test the API submission mimicking the iOS app's request format.
    
    Args:
        image_path: Path to the test image
        dietary_restrictions: List of dietary restrictions (e.g., ["vegetarian", "gluten-free"])
        food_type: Cuisine type (e.g., "Italian", "Mexican")
        difficulty_preference: Recipe difficulty (e.g., "easy", "medium", "hard")
        health_preference: Health focus (e.g., "healthy", "balanced", "indulgent")
        meal_type: Type of meal (e.g., "breakfast", "lunch", "dinner")
        cooking_time_preference: Time preference (e.g., "quick", "under 30 mins")
        number_of_recipes: Number of recipes to generate
    
    Returns:
        API response as dictionary
    """
    
    # Verify image exists
    if not image_path.exists():
        raise FileNotFoundError(f"Test image not found at: {image_path}")
    
    print(f"✓ Found test image at: {image_path}")
    print(f"  Image size: {image_path.stat().st_size / 1024:.1f} KB")
    
    # Generate session ID (mimicking iOS UUID().uuidString)
    session_id = str(uuid.uuid4())
    print(f"\n✓ Generated session ID: {session_id}")

    if not API_KEY:
        raise RuntimeError("SNAPCHEF_API_KEY is not set. Export it before running this script.")
    
    # Prepare headers with authentication
    headers = {
        "X-App-API-Key": API_KEY
    }
    
    # Prepare multipart form data
    files = {
        'image_file': ('photo.jpg', open(image_path, 'rb'), 'image/jpeg')
    }
    
    # Prepare form fields (matching iOS implementation)
    data = {
        'session_id': session_id
    }
    
    # Handle dietary restrictions as JSON string (matching iOS implementation)
    if dietary_restrictions:
        data['dietary_restrictions'] = json.dumps(dietary_restrictions)
    else:
        data['dietary_restrictions'] = "[]"
    
    # Add optional fields if provided
    if food_type:
        data['food_type'] = food_type
    if difficulty_preference:
        data['difficulty_preference'] = difficulty_preference
    if health_preference:
        data['health_preference'] = health_preference
    if meal_type:
        data['meal_type'] = meal_type
    if cooking_time_preference:
        data['cooking_time_preference'] = cooking_time_preference
    if number_of_recipes:
        data['number_of_recipes'] = str(number_of_recipes)
    
    print("\n📤 Request Details:")
    print(f"  URL: {API_BASE_URL}{API_ENDPOINT}")
    print("  Headers: {'X-App-API-Key': '<redacted>'}")
    print(f"  Form Data:")
    for key, value in data.items():
        print(f"    {key}: {value}")
    
    # Make the request
    print("\n🚀 Sending request to server...")
    try:
        response = requests.post(
            f"{API_BASE_URL}{API_ENDPOINT}",
            headers=headers,
            files=files,
            data=data,
            timeout=60  # 60 second timeout
        )
        
        # Close the file
        files['image_file'][1].close()
        
        print(f"\n📥 Response Status: {response.status_code}")
        print(f"  Response Time: {response.elapsed.total_seconds():.2f} seconds")
        
        if response.status_code == 200:
            response_data = response.json()
            print("\n✅ Success! API Response Structure:")
            
            # Validate response structure matches expected format
            validate_response_structure(response_data)
            
            # Pretty print the response
            print("\n📋 Full Response:")
            pprint.pprint(response_data, indent=2, width=120)
            
            # Extract and display key information
            print_recipe_summary(response_data)
            
            return response_data
            
        else:
            print(f"\n❌ Error: {response.status_code}")
            print(f"Response: {response.text}")
            return None
            
    except requests.exceptions.Timeout:
        print("\n❌ Request timed out after 60 seconds")
        return None
    except requests.exceptions.ConnectionError:
        print("\n❌ Could not connect to server. Is it running?")
        return None
    except Exception as e:
        print(f"\n❌ Unexpected error: {type(e).__name__}: {e}")
        return None


def validate_response_structure(response: Dict) -> None:
    """Validate that the response matches the expected structure."""
    
    print("\n🔍 Validating Response Structure:")
    
    # Check top-level fields
    assert 'data' in response, "Missing 'data' field"
    assert 'message' in response, "Missing 'message' field"
    print("  ✓ Top-level structure valid")
    
    data = response['data']
    
    # Check GrokParsedResponse fields
    assert 'image_analysis' in data, "Missing 'image_analysis' field"
    assert 'ingredients' in data, "Missing 'ingredients' field"
    assert 'recipes' in data, "Missing 'recipes' field"
    print("  ✓ Data structure valid")
    
    # Check ImageAnalysis structure
    image_analysis = data['image_analysis']
    assert 'is_food_image' in image_analysis, "Missing 'is_food_image' field"
    assert 'confidence' in image_analysis, "Missing 'confidence' field"
    assert 'image_description' in image_analysis, "Missing 'image_description' field"
    print("  ✓ Image analysis structure valid")
    
    # Check Recipe structure (if recipes exist)
    if data['recipes']:
        recipe = data['recipes'][0]
        required_fields = ['id', 'name', 'description', 'difficulty', 'instructions']
        for field in required_fields:
            assert field in recipe, f"Missing '{field}' field in recipe"
        print("  ✓ Recipe structure valid")
    
    print("\n✅ All response structures validated successfully!")


def print_recipe_summary(response: Dict) -> None:
    """Print a summary of the recipes returned."""
    
    data = response['data']
    
    print("\n🍳 Recipe Generation Summary:")
    print(f"  Image Analysis:")
    print(f"    - Is Food Image: {data['image_analysis']['is_food_image']}")
    print(f"    - Confidence: {data['image_analysis']['confidence']}")
    print(f"    - Description: {data['image_analysis']['image_description'][:100]}...")
    
    print(f"\n  Ingredients Found: {len(data['ingredients'])}")
    for i, ingredient in enumerate(data['ingredients'][:5]):  # Show first 5
        print(f"    {i+1}. {ingredient['name']} - {ingredient['quantity']} {ingredient['unit']}")
    if len(data['ingredients']) > 5:
        print(f"    ... and {len(data['ingredients']) - 5} more")
    
    print(f"\n  Recipes Generated: {len(data['recipes'])}")
    for i, recipe in enumerate(data['recipes']):
        print(f"\n  Recipe {i+1}: {recipe['name']}")
        print(f"    - Difficulty: {recipe['difficulty']}")
        print(f"    - Description: {recipe['description'][:100]}...")
        if recipe.get('prep_time'):
            print(f"    - Prep Time: {recipe['prep_time']} min")
        if recipe.get('cook_time'):
            print(f"    - Cook Time: {recipe['cook_time']} min")
        if recipe.get('servings'):
            print(f"    - Servings: {recipe['servings']}")
        if recipe.get('nutrition'):
            nutrition = recipe['nutrition']
            print(f"    - Nutrition: {nutrition.get('calories', 'N/A')} cal, "
                  f"{nutrition.get('protein', 'N/A')}g protein, "
                  f"{nutrition.get('carbs', 'N/A')}g carbs, "
                  f"{nutrition.get('fat', 'N/A')}g fat")
        print(f"    - Instructions: {len(recipe['instructions'])} steps")




if __name__ == "__main__":
    # Run a single test with moderate preferences
    print("=" * 80)
    print("🧪 SNAPCHEF API TEST - Mimicking iOS App Submission")
    print("=" * 80)
    
    result = test_api_submission(
        TEST_IMAGE_PATH,
        dietary_restrictions=["vegetarian"],
        food_type="Italian",
        difficulty_preference="medium",
        health_preference="balanced",
        meal_type="dinner",
        cooking_time_preference="under 30 mins",
        number_of_recipes=3
    )
    
    if result:
        print("\n\n✅ API test completed successfully!")
        print("The iOS app integration should work correctly with this API response structure.")
    else:
        print("\n\n❌ API test failed. Please check the server logs and configuration.")
