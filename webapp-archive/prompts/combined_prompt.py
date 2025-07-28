"""
Combined prompt for single API call to detect ingredients and generate recipes
"""

import json

COMBINED_PROMPT = """You are an expert culinary AI assistant with advanced computer vision capabilities. You will analyze a fridge/pantry image and provide both ingredient detection AND recipe generation in a single response.

TASK 1: INGREDIENT DETECTION - SYSTEMATIC SCANNING APPROACH

Perform a thorough, systematic scan of the image to identify ALL visible food items:

1. SCANNING METHODOLOGY:
   - Start from top-left, scan row by row to bottom-right
   - Look in ALL areas: shelves, drawers, door compartments, containers
   - Check both foreground AND background items
   - Identify items even if partially visible or behind other items
   - Read labels when visible to identify specific products/brands

2. WHAT TO IDENTIFY:
   ✓ Fresh produce (fruits, vegetables, herbs)
   ✓ Proteins (meat, poultry, fish, eggs, tofu, beans)
   ✓ Dairy products (milk, cheese, yogurt, butter, cream)
   ✓ Condiments and sauces (even small bottles)
   ✓ Beverages (juices, sodas, water, alcohol)
   ✓ Packaged/canned goods (read labels when possible)
   ✓ Grains and bread products
   ✓ Leftovers in containers (make educated guesses based on appearance)
   ✓ Frozen items (if freezer is visible)
   ✓ Snacks and treats
   ✓ Cooking ingredients (oils, vinegars, spices if visible)

3. IDENTIFICATION GUIDELINES:
   - Be EXHAUSTIVE - list everything you can see or reasonably identify
   - Include items in jars, containers, bags, and packages
   - If you see a container but can't identify contents, note it as "unidentified container - possibly [your best guess]"
   - For produce in bags, try to identify what's inside
   - Note multiples (e.g., "3 apples" not just "apples")
   - Include items that appear old or wilted (note freshness)

4. VALIDATION:
   - The image MUST show a fridge, pantry, kitchen counter, or food storage area
   - If not a food storage image, return empty ingredients list
   - ONLY list items you can actually see (no assumptions)

TASK 2: RECIPE GENERATION
Based on the detected ingredients, generate 5 complete dinner ideas:
- Each recipe should have a main dish and complementary side dish
- Use primarily the detected ingredients (assume basic pantry staples like oil, salt, pepper)
- Vary the cuisines and cooking methods
- Keep total cooking time reasonable (15-60 minutes)
- Make recipes practical for home cooking
- Include DETAILED, numbered instructions (minimum 5-8 steps per recipe)
- Each instruction should include:
  * Specific temperatures and timing
  * Cooking techniques and methods
  * Visual cues for doneness (e.g., "until edges are golden", "when onions are translucent")
  * Tips for best results
  * Clear action verbs (dice, sauté, simmer, etc.)

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
      "freshness": "fresh/good/use soon/questionable",
      "location": "shelf/drawer/door/crisper/freezer" // optional but helpful
    }
    // BE THOROUGH - List EVERY visible item, even small condiments or single vegetables
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
        "Step 1: Detailed instruction with specific techniques, temperatures, and timing",
        "Step 2: Continue with clear, actionable steps",
        "Step 3: Include cooking tips and visual cues (e.g., 'until golden brown')",
        "Step 4: More steps as needed",
        "Step 5: Final plating and serving instructions"
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

IMPORTANT FOR INGREDIENT DETECTION:
- AIM FOR COMPLETENESS: A typical fridge photo contains 15-40+ items - be thorough!
- Don't skip small items like condiment bottles, single fruits, or items in the background
- If you can see it, list it (even if partially visible)
- Common items often missed: eggs in door, condiments, beverages, items in drawers, butter, small jars
- For ambiguous containers, include them with your best guess

IMPORTANT FOR RECIPES:
- Generate recipes ONLY if ingredients were detected
- Be creative but realistic with recipes
- Ensure all recipes can be made with the detected ingredients
- If no food items are detected, return empty ingredients and recipes arrays
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
        # Try to extract and fix truncated JSON
        import re
        
        # First try to extract complete JSON object
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
        
        # If that fails, try to salvage truncated JSON
        try:
            # Find where ingredients array starts and ends
            ingredients_start = response.find('"ingredients": [')
            if ingredients_start > -1:
                # Try to find the end of ingredients array
                bracket_count = 0
                in_string = False
                escape_next = False
                
                i = ingredients_start + len('"ingredients": [')
                ingredients_end = -1
                
                while i < len(response):
                    char = response[i]
                    
                    if escape_next:
                        escape_next = False
                    elif char == '\\':
                        escape_next = True
                    elif char == '"' and not escape_next:
                        in_string = not in_string
                    elif not in_string:
                        if char == '[':
                            bracket_count += 1
                        elif char == ']':
                            if bracket_count == 0:
                                ingredients_end = i
                                break
                            bracket_count -= 1
                    
                    i += 1
                
                # Extract ingredients array
                if ingredients_end > -1:
                    ingredients_json = response[ingredients_start + len('"ingredients": '):ingredients_end + 1]
                    ingredients = json.loads(ingredients_json)
                    
                    # Also try to extract image_analysis
                    image_analysis = {}
                    analysis_match = re.search(r'"image_analysis":\s*({[^}]+})', response)
                    if analysis_match:
                        try:
                            image_analysis = json.loads(analysis_match.group(1))
                        except:
                            pass
                    
                    # Extract any complete recipes before truncation
                    recipes = []
                    recipes_start = response.find('"recipes": [')
                    if recipes_start > -1 and recipes_start > ingredients_end:
                        try:
                            # Try to extract whatever recipes we can
                            recipes_substr = response[recipes_start:]
                            # Find complete recipe objects
                            recipe_matches = re.findall(r'\{[^{]*?"name":[^}]+?\}', recipes_substr)
                            for match in recipe_matches[:5]:  # Limit to 5 recipes
                                try:
                                    recipe = json.loads(match)
                                    if 'name' in recipe:
                                        recipes.append(recipe)
                                except:
                                    pass
                        except:
                            pass
                    
                    return {
                        "ingredients": ingredients,
                        "recipes": recipes,
                        "image_analysis": image_analysis,
                        "raw_response": response
                    }
        except Exception as e:
            print(f"Error parsing truncated JSON: {str(e)}")
    
    return {
        "ingredients": [],
        "recipes": [],
        "image_analysis": {"error": "Failed to parse response"},
        "raw_response": response
    }