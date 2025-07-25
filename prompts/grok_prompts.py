"""
Grok4 LLM Prompts for SnapChef App
This module contains all prompts, schemas, and messages for the Grok4 integration.
"""

import json
from typing import List, Dict, Any

# System prompt for ingredient detection from fridge images
INGREDIENT_DETECTION_PROMPT = """You are an expert culinary AI assistant with advanced computer vision capabilities. Your task is to analyze kitchen images (fridge, pantry, counter) and identify ONLY food-related items.

CRITICAL REQUIREMENTS:
1. ONLY identify items that are edible food, beverages, or cooking ingredients
2. The image MUST show the inside of a fridge, pantry, kitchen counter, or food storage area
3. If the image shows no food items or is not a kitchen/food storage image, return an empty ingredients list
4. DO NOT make up or assume ingredients that aren't clearly visible
5. If the image quality is too poor to identify items, return an empty list

INSTRUCTIONS FOR VALID KITCHEN IMAGES:
1. Carefully examine the image for ALL visible food items, ingredients, condiments, and beverages
2. Identify each item by its most common culinary name
3. Estimate quantities based on package size, container type, or visible amount
4. Categorize items appropriately (produce, dairy, protein, condiments, etc.)
5. Consider partial containers and estimate remaining amounts
6. Note any items that appear expired or unusable
7. Be thorough - even small condiments and seasonings are important for recipe generation

IMPORTANT GUIDELINES:
- If you see branded products, identify the actual ingredient (e.g., "whole milk" not "Brand X Milk")
- For produce, note ripeness if relevant (e.g., "ripe avocados" vs "unripe avocados")
- For proteins, specify cut/type (e.g., "chicken breast", "ground beef", "salmon fillet")
- Include common fridge staples even if partially obscured
- If uncertain about quantity, provide a reasonable estimate with unit
- Return detection_confidence as "low" if image is unclear or few items visible
- Return an empty ingredients array if no food items are detected

Return your analysis in the exact JSON format specified below."""

# System prompt for recipe generation based on ingredients
RECIPE_GENERATION_PROMPT = """You are a creative culinary expert and professional chef AI. Your mission is to generate exciting, practical dinner recipes using the available ingredients provided.

YOUR PERSONALITY:
- Enthusiastic and encouraging
- Creative but practical
- Health-conscious while keeping meals delicious
- Knowledgeable about various cuisines and cooking techniques
- Supportive of home cooks of all skill levels

RECIPE GENERATION GUIDELINES:
1. Create 5 complete dinner ideas, each with a main dish and complementary side dish
2. Prioritize using ingredients that need to be used soon (if freshness info provided)
3. Ensure recipes are practical for home cooking
4. Vary the cuisines and cooking methods across the 5 options
5. Consider dietary balance (protein, vegetables, carbs)
6. Provide clear, step-by-step instructions that a home cook can follow
7. Include helpful tips for each recipe
8. Generate engaging social media captions that would make people want to try the recipe

RECIPE REQUIREMENTS:
- Use primarily the provided ingredients (okay to assume basic pantry staples like oil, salt, pepper, basic spices)
- Keep total cooking time reasonable (15-60 minutes for most recipes)
- Provide accurate nutritional estimates
- Tag recipes appropriately (e.g., "quick", "healthy", "comfort food", "date night")
- Make instructions clear and numbered
- Include specific measurements and cooking times/temperatures

CREATIVITY FACTORS:
- Suggest interesting flavor combinations
- Include at least one "restaurant-style" recipe
- Provide one quick weeknight option (under 30 min)
- Include one healthier/lighter option
- Suggest one comfort food option

Return your recipes in the exact JSON format specified below."""

# JSON Schema for ingredient detection response
INGREDIENT_DETECTION_SCHEMA = {
    "type": "object",
    "properties": {
        "ingredients": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Common culinary name of the ingredient"
                    },
                    "estimated_quantity": {
                        "type": "number",
                        "description": "Numerical quantity estimate"
                    },
                    "unit": {
                        "type": "string",
                        "description": "Unit of measurement (e.g., 'oz', 'cups', 'pieces', 'lb')"
                    },
                    "category": {
                        "type": "string",
                        "enum": ["produce", "dairy", "protein", "grains", "condiments", "beverages", "frozen", "snacks", "other"],
                        "description": "Category of the ingredient"
                    },
                    "freshness": {
                        "type": "string",
                        "enum": ["fresh", "good", "use soon", "questionable"],
                        "description": "Optional freshness indicator"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Optional notes about the ingredient (e.g., 'opened', 'half full')"
                    }
                },
                "required": ["name", "estimated_quantity", "unit", "category"]
            }
        },
        "total_items": {
            "type": "integer",
            "description": "Total number of ingredients detected"
        },
        "detection_confidence": {
            "type": "string",
            "enum": ["high", "medium", "low"],
            "description": "Overall confidence in detection accuracy"
        }
    },
    "required": ["ingredients", "total_items", "detection_confidence"]
}

# JSON Schema for recipe generation response
RECIPE_GENERATION_SCHEMA = {
    "type": "object",
    "properties": {
        "recipes": {
            "type": "array",
            "maxItems": 5,
            "minItems": 5,
            "items": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Creative, appetizing recipe name"
                    },
                    "description": {
                        "type": "string",
                        "description": "Brief, enticing description of the dish"
                    },
                    "main_dish": {
                        "type": "string",
                        "description": "Name of the main dish component"
                    },
                    "side_dish": {
                        "type": "string",
                        "description": "Name of the side dish component"
                    },
                    "total_time": {
                        "type": "integer",
                        "description": "Total time in minutes"
                    },
                    "prep_time": {
                        "type": "integer",
                        "description": "Preparation time in minutes"
                    },
                    "cook_time": {
                        "type": "integer",
                        "description": "Cooking time in minutes"
                    },
                    "servings": {
                        "type": "integer",
                        "description": "Number of servings"
                    },
                    "difficulty": {
                        "type": "string",
                        "enum": ["easy", "medium", "hard"],
                        "description": "Difficulty level"
                    },
                    "ingredients_used": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "ingredient": {"type": "string"},
                                "amount": {"type": "string"},
                                "preparation": {"type": "string", "description": "e.g., 'diced', 'sliced'"}
                            },
                            "required": ["ingredient", "amount"]
                        }
                    },
                    "instructions": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "step_number": {"type": "integer"},
                                "instruction": {"type": "string"},
                                "time": {"type": "string", "description": "Optional time for this step"}
                            },
                            "required": ["step_number", "instruction"]
                        }
                    },
                    "nutrition_info": {
                        "type": "object",
                        "properties": {
                            "calories": {"type": "integer"},
                            "protein_g": {"type": "number"},
                            "carbs_g": {"type": "number"},
                            "fat_g": {"type": "number"},
                            "fiber_g": {"type": "number"},
                            "sodium_mg": {"type": "integer"}
                        },
                        "required": ["calories", "protein_g", "carbs_g", "fat_g"]
                    },
                    "tips": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Helpful cooking tips or variations"
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Recipe tags for categorization"
                    },
                    "share_caption": {
                        "type": "string",
                        "description": "Engaging social media caption for sharing"
                    }
                },
                "required": [
                    "name", "description", "main_dish", "side_dish", 
                    "total_time", "prep_time", "cook_time", "servings", 
                    "difficulty", "ingredients_used", "instructions", 
                    "nutrition_info", "tips", "tags", "share_caption"
                ]
            }
        },
        "generation_notes": {
            "type": "string",
            "description": "Any notes about ingredient substitutions or assumptions made"
        }
    },
    "required": ["recipes"]
}

# Progress messages for camera processing screen
CAMERA_PROGRESS_MESSAGES = [
    "🔍 Analyzing your fridge with AI superpowers...",
    "🤖 Oh man, this is going to be good!",
    "👨‍🍳 Consulting with virtual Gordon Ramsay...",
    "🥗 Calculating optimal flavor combinations...",
    "🍳 Summoning the recipe gods...",
    "🧠 AI brain is cooking up something special...",
    "🎯 Targeting maximum deliciousness...",
    "🔮 Predicting your new favorite dinner...",
    "🚀 Launching culinary creativity mode...",
    "🎨 Painting your perfect meal plan...",
    "⚡ Supercharging your dinner options...",
    "🌟 Manifesting Michelin-star worthy ideas...",
    "🧪 Mixing up some culinary chemistry...",
    "🎪 Performing kitchen magic tricks...",
    "🏆 Competing for 'Best Dinner Award'...",
    "🎲 Rolling for epic meal inspiration...",
    "🌈 Following the rainbow to Flavor Town...",
    "🎭 Rehearsing your dinner performance...",
    "🔥 Firing up the creativity engines...",
    "🎪 Juggling ingredients like a pro...",
    "🏃‍♂️ Racing to find the perfect recipe...",
    "🧩 Solving the dinner puzzle...",
    "💡 Illuminating brilliant meal ideas...",
    "🎵 Composing a symphony of flavors...",
    "🏗️ Building your dinner masterpiece...",
    "🌊 Surfing the waves of culinary inspiration...",
    "🎯 Locking onto taste bud targets...",
    "🚁 Airlifting gourmet ideas your way...",
    "💫 Wishing upon a dinner star...",
    "🔬 Conducting delicious experiments..."
]

# Helper functions for prompt formatting
def format_ingredient_detection_prompt(additional_context: str = "") -> str:
    """
    Format the complete ingredient detection prompt with optional context.
    
    Args:
        additional_context: Any additional context to include in the prompt
        
    Returns:
        Formatted prompt string
    """
    prompt = INGREDIENT_DETECTION_PROMPT
    if additional_context:
        prompt += f"\n\nADDITIONAL CONTEXT:\n{additional_context}"
    
    prompt += f"\n\nRETURN FORMAT:\n{json.dumps(INGREDIENT_DETECTION_SCHEMA, indent=2)}"
    return prompt

def format_recipe_generation_prompt(ingredients: List[Any], 
                                  dietary_preferences: str = "",
                                  cuisine_preferences: str = "") -> str:
    """
    Format the complete recipe generation prompt with ingredients and preferences.
    
    Args:
        ingredients: List of ingredients (can be strings or dicts)
        dietary_preferences: Any dietary restrictions or preferences
        cuisine_preferences: Preferred cuisines or cooking styles
        
    Returns:
        Formatted prompt string
    """
    prompt = RECIPE_GENERATION_PROMPT
    
    # Add ingredients list
    prompt += "\n\nAVAILABLE INGREDIENTS:\n"
    for ing in ingredients:
        if isinstance(ing, dict):
            prompt += f"- {ing['name']}: {ing.get('estimated_quantity', ing.get('quantity', 'some'))} {ing.get('unit', '')}"
            if ing.get('freshness') == 'use soon':
                prompt += " (use soon)"
        else:
            # Handle simple string ingredients
            prompt += f"- {ing}"
        prompt += "\n"
    
    # Add preferences if provided
    if dietary_preferences:
        prompt += f"\nDIETARY PREFERENCES:\n{dietary_preferences}\n"
    
    if cuisine_preferences:
        prompt += f"\nCUISINE PREFERENCES:\n{cuisine_preferences}\n"
    
    prompt += f"\n\nRETURN FORMAT:\n{json.dumps(RECIPE_GENERATION_SCHEMA, indent=2)}"
    return prompt

def get_random_progress_message() -> str:
    """
    Get a random progress message for the camera processing screen.
    
    Returns:
        Random progress message string
    """
    import random
    return random.choice(CAMERA_PROGRESS_MESSAGES)

def validate_ingredient_response(response: str) -> Dict[str, Any]:
    """
    Validate and parse the ingredient detection response.
    
    Args:
        response: The response string from the LLM
        
    Returns:
        Dict with ingredients list and metadata if valid, None otherwise
    """
    try:
        # Try to parse JSON from the response
        import re
        
        # Look for JSON object in the response - allow empty ingredients array
        json_match = re.search(r'\{[^{}]*"ingredients"\s*:\s*\[[^\]]*\][^{}]*\}', response, re.DOTALL)
        if json_match:
            data = json.loads(json_match.group())
            
            # Validate required keys
            required_keys = ['ingredients', 'total_items', 'detection_confidence']
            if all(key in data for key in required_keys):
                # Convert to simpler format for API
                ingredients = []
                for ing in data.get('ingredients', []):
                    if ing.get('name'):  # Only add if has a name
                        ingredients.append({
                            "name": ing.get('name', ''),
                            "quantity": str(ing.get('estimated_quantity', '')),
                            "unit": ing.get('unit', ''),
                            "category": ing.get('category', 'other')
                        })
                
                return {
                    "ingredients": ingredients,
                    "confidence": data.get('detection_confidence', 'low'),
                    "total_items": len(ingredients)
                }
    except:
        pass
    
    return None

def validate_recipe_response(response: str) -> List[Dict[str, Any]]:
    """
    Validate and parse the recipe generation response.
    
    Args:
        response: The response string from the LLM
        
    Returns:
        List of recipe dictionaries if valid, None otherwise
    """
    try:
        # Try to parse JSON from the response
        import re
        
        # Look for JSON object or array in the response
        json_match = re.search(r'\{[^{}]*"recipes"\s*:\s*\[[^\]]+\][^{}]*\}|\[[^\[\]]*\{[^{}]+\}[^\[\]]*\]', response, re.DOTALL)
        if json_match:
            data = json.loads(json_match.group())
            
            # Handle both object with recipes key and direct array
            if isinstance(data, dict) and 'recipes' in data:
                recipes = data['recipes']
            elif isinstance(data, list):
                recipes = data
            else:
                return None
            
            # Convert to expected format, filling in any missing fields
            formatted_recipes = []
            for recipe in recipes[:5]:  # Take max 5 recipes
                # Handle different instruction formats
                instructions = recipe.get('instructions', [])
                if isinstance(instructions, list) and len(instructions) > 0:
                    if isinstance(instructions[0], dict):
                        # Already in correct format
                        instruction_list = [inst.get('instruction', '') for inst in instructions]
                    else:
                        # Simple string list
                        instruction_list = instructions
                else:
                    instruction_list = []
                
                # Handle nutrition info
                nutrition = recipe.get('nutrition_info', recipe.get('nutrition', {}))
                
                formatted_recipe = {
                    "name": recipe.get('name', 'Untitled Recipe'),
                    "description": recipe.get('description', ''),
                    "main_dish": recipe.get('main_dish', recipe.get('name', '')),
                    "side_dish": recipe.get('side_dish', ''),
                    "total_time": recipe.get('total_time', 30),
                    "prep_time": recipe.get('prep_time', 10),
                    "cook_time": recipe.get('cook_time', 20),
                    "servings": recipe.get('servings', 4),
                    "difficulty": recipe.get('difficulty', 'medium'),
                    "ingredients_used": recipe.get('ingredients_used', recipe.get('ingredients', [])),
                    "instructions": instruction_list,
                    "nutrition": {
                        "calories": nutrition.get('calories', nutrition.get('calories_per_serving', 0)),
                        "protein": nutrition.get('protein_g', nutrition.get('protein', 0)),
                        "carbs": nutrition.get('carbs_g', nutrition.get('carbs', 0)),
                        "fat": nutrition.get('fat_g', nutrition.get('fat', 0))
                    },
                    "tips": recipe.get('tips', recipe.get('tip', '')),
                    "tags": recipe.get('tags', []),
                    "share_caption": recipe.get('share_caption', f"Just made {recipe.get('name', 'this amazing dish')}! 🍳✨ #SnapChefChallenge")
                }
                formatted_recipes.append(formatted_recipe)
            
            return formatted_recipes if len(formatted_recipes) > 0 else None
    except:
        pass
    
    return None

# Example usage and testing
if __name__ == "__main__":
    # Example: Format ingredient detection prompt
    detection_prompt = format_ingredient_detection_prompt(
        additional_context="The image shows the main compartment of a standard refrigerator."
    )
    print("=== Ingredient Detection Prompt ===")
    print(detection_prompt[:500] + "...\n")
    
    # Example: Format recipe generation prompt
    example_ingredients = [
        {"name": "chicken breast", "estimated_quantity": 2, "unit": "lb", "category": "protein"},
        {"name": "bell peppers", "estimated_quantity": 3, "unit": "pieces", "category": "produce"},
        {"name": "onion", "estimated_quantity": 2, "unit": "pieces", "category": "produce"},
        {"name": "garlic", "estimated_quantity": 1, "unit": "head", "category": "produce"},
        {"name": "rice", "estimated_quantity": 2, "unit": "cups", "category": "grains"}
    ]
    
    recipe_prompt = format_recipe_generation_prompt(
        ingredients=example_ingredients,
        dietary_preferences="Low sodium preferred",
        cuisine_preferences="Open to all cuisines, especially Asian and Mediterranean"
    )
    print("=== Recipe Generation Prompt ===")
    print(recipe_prompt[:500] + "...\n")
    
    # Show a few progress messages
    print("=== Sample Progress Messages ===")
    for _ in range(5):
        print(get_random_progress_message())