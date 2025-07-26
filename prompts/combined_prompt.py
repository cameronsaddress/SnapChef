"""
Combined prompt for single API call to detect ingredients and generate recipes
"""

import json

COMBINED_PROMPT = """You are an expert culinary AI assistant with advanced computer vision capabilities. You will analyze a fridge/pantry image and provide both ingredient detection AND recipe generation in a single response.

TASK 1: INGREDIENT DETECTION
First, analyze the image to identify food items:
- ONLY identify items that are edible food, beverages, or cooking ingredients
- The image MUST show the inside of a fridge, pantry, kitchen counter, or food storage area
- If the image shows no food items or is not a kitchen/food storage image, return an empty ingredients list
- DO NOT make up or assume ingredients that aren't clearly visible
- For each ingredient, estimate quantities and categorize appropriately

TASK 2: RECIPE GENERATION
Based on the detected ingredients, generate 5 complete dinner ideas:
- Each recipe should have a main dish and complementary side dish
- Use primarily the detected ingredients (assume basic pantry staples like oil, salt, pepper)
- Vary the cuisines and cooking methods
- Keep total cooking time reasonable (15-60 minutes)
- Make recipes practical for home cooking
- Include clear, numbered instructions

RESPONSE FORMAT:
Return your complete analysis in the following JSON structure:

{
  "image_analysis": {
    "is_food_image": true/false,
    "confidence": "high/medium/low",
    "image_description": "Brief description of what you see"
  },
  "ingredients": [
    {
      "name": "ingredient name",
      "quantity": "estimated amount",
      "unit": "oz/cups/pieces/etc",
      "category": "produce/dairy/protein/grains/condiments/beverages/frozen/other",
      "freshness": "fresh/good/use soon/questionable"
    }
  ],
  "recipes": [
    {
      "name": "Recipe Name",
      "description": "Brief, enticing description",
      "main_dish": "Main dish name",
      "side_dish": "Side dish name",
      "total_time": 45,
      "prep_time": 15,
      "cook_time": 30,
      "servings": 4,
      "difficulty": "easy/medium/hard",
      "ingredients_used": [
        {"name": "ingredient", "amount": "quantity"}
      ],
      "instructions": [
        "Step 1 instruction",
        "Step 2 instruction"
      ],
      "nutrition": {
        "calories": 400,
        "protein": 25,
        "carbs": 45,
        "fat": 15
      },
      "tips": "Helpful cooking tip",
      "tags": ["healthy", "quick", "family-friendly"],
      "share_caption": "Social media caption with emojis"
    }
  ]
}

IMPORTANT:
- If no food items are detected, return empty ingredients and recipes arrays
- Generate recipes ONLY if ingredients were detected
- Be creative but realistic with recipes
- Ensure all recipes can be made with the detected ingredients
"""

def get_combined_prompt():
    """Get the combined prompt for single API call"""
    return COMBINED_PROMPT

def parse_combined_response(response: str) -> dict:
    """Parse the combined response into ingredients and recipes"""
    try:
        # Try to parse as JSON
        data = json.loads(response)
        
        return {
            "ingredients": data.get("ingredients", []),
            "recipes": data.get("recipes", []),
            "image_analysis": data.get("image_analysis", {}),
            "raw_response": response
        }
    except json.JSONDecodeError:
        # Try to extract JSON from the response
        import re
        json_match = re.search(r'\{.*\}', response, re.DOTALL)
        if json_match:
            try:
                data = json.loads(json_match.group())
                return {
                    "ingredients": data.get("ingredients", []),
                    "recipes": data.get("recipes", []),
                    "image_analysis": data.get("image_analysis", {}),
                    "raw_response": response
                }
            except:
                pass
    
    return {
        "ingredients": [],
        "recipes": [],
        "image_analysis": {"error": "Failed to parse response"},
        "raw_response": response
    }