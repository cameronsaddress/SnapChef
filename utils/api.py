import os
import base64
import json
from openai import OpenAI
from typing import List, Dict, Optional, Any
import streamlit as st
from prompts import (
    format_ingredient_detection_prompt,
    format_recipe_generation_prompt,
    INGREDIENT_DETECTION_SCHEMA as INGREDIENT_SCHEMA,
    RECIPE_GENERATION_SCHEMA as RECIPE_SCHEMA,
    validate_ingredient_response,
    validate_recipe_response
)
from prompts.combined_prompt import get_combined_prompt, parse_combined_response

# Initialize Grok client
api_key = os.getenv("XAI_API_KEY")
if api_key:
    client = OpenAI(
        api_key=api_key,
        base_url="https://api.x.ai/v1"
    )
else:
    client = None  # Will use mock data

def encode_image_to_base64(image_bytes) -> str:
    """Convert image bytes to base64 string"""
    return base64.b64encode(image_bytes).decode('utf-8')

@st.cache_data(ttl=3600)
def detect_ingredients(image_base64: str) -> Dict[str, Any]:
    """Detect ingredients from fridge/pantry photo using Grok 4"""
    if not client:
        # Return error if no API key
        return {
            "ingredients": [],
            "error": "API key not configured. Please set up your XAI_API_KEY.",
            "confidence": "none"
        }
    
    try:
        # Get the formatted prompt
        prompt = format_ingredient_detection_prompt()
        
        # Log API call for debugging (remove in production)
        print(f"Making API call to Grok Vision with image size: {len(image_base64)} characters")
        
        response = client.chat.completions.create(
            model="grok-2-latest",  # Use Grok 2 for non-vision tasks
            messages=[
                {
                    "role": "system",
                    "content": prompt
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{image_base64}",
                                "detail": "high"
                            }
                        },
                        {
                            "type": "text",
                            "text": f"Please analyze this image and identify any food ingredients. If this is not a kitchen/fridge/pantry image or no food items are visible, return an empty ingredients list. Return the result in the following JSON format:\n{json.dumps(INGREDIENT_SCHEMA, indent=2)}"
                        }
                    ]
                }
            ],
            temperature=0.7,
            max_tokens=1000,
            response_format={"type": "text"}  # Ensure we get text response
        )
        
        # Parse the response
        content = response.choices[0].message.content
        print(f"Received response from API: {content[:200]}...")  # Log first 200 chars
        
        # Store raw response for debugging
        st.session_state.raw_ingredient_response = content
        
        # Validate and extract JSON
        result = validate_ingredient_response(content)
        if result:
            # Check if we actually found ingredients
            if len(result['ingredients']) == 0:
                return {
                    "ingredients": [],
                    "error": "No food ingredients detected in the image. Please take a photo of your fridge, pantry, or kitchen ingredients.",
                    "confidence": result.get('confidence', 'low')
                }
            return {
                "ingredients": result['ingredients'],
                "confidence": result.get('confidence', 'medium'),
                "total_items": result.get('total_items', len(result['ingredients']))
            }
        
        # If parsing failed completely
        return {
            "ingredients": [],
            "error": "Failed to analyze the image. Please try again with a clearer photo.",
            "confidence": "low"
        }
            
    except Exception as e:
        # Return error instead of mock data
        return {
            "ingredients": [],
            "error": f"Error analyzing image: {str(e)}",
            "confidence": "none"
        }

def get_mock_ingredients() -> List[Dict]:
    """Return mock ingredient data for development"""
    return [
        {"name": "eggs", "quantity": "12", "unit": "count", "category": "dairy"},
        {"name": "milk", "quantity": "1", "unit": "gallon", "category": "dairy"},
        {"name": "cheddar cheese", "quantity": "8", "unit": "oz", "category": "dairy"},
        {"name": "tomatoes", "quantity": "4", "unit": "medium", "category": "produce"},
        {"name": "chicken breast", "quantity": "2", "unit": "lbs", "category": "protein"},
        {"name": "pasta", "quantity": "1", "unit": "box", "category": "grains"},
        {"name": "onions", "quantity": "3", "unit": "medium", "category": "produce"},
        {"name": "garlic", "quantity": "1", "unit": "head", "category": "produce"}
    ]

@st.cache_data(ttl=3600)
def generate_meals(ingredients: List[Dict], dietary_preferences: List[str] = None, cuisine_preferences: str = None) -> List[Dict]:
    """Generate 5 dinner ideas with main dish + side dish using detected ingredients"""
    if not client:
        # Return mock data if no API key
        return get_mock_meals_v2()
    
    try:
        # Convert ingredient objects to simple list for prompt
        ingredient_list = [ing['name'] for ing in ingredients]
        
        # Get the formatted prompt
        prompt = format_recipe_generation_prompt(
            ingredients=ingredient_list,
            dietary_preferences=', '.join(dietary_preferences) if dietary_preferences else None,
            cuisine_preferences=cuisine_preferences
        )
        
        response = client.chat.completions.create(
            model="grok-2-latest",  # Use latest Grok 2 model for text generation
            messages=[
                {
                    "role": "system", 
                    "content": prompt
                },
                {
                    "role": "user",
                    "content": f"Based on these ingredients, please generate 5 dinner ideas (each with a main dish and side dish) in the following JSON format:\n{json.dumps(RECIPE_SCHEMA, indent=2)}"
                }
            ],
            temperature=0.8,
            max_tokens=4000,
            response_format={"type": "text"}  # Ensure we get text response
        )
        
        content = response.choices[0].message.content
        print(f"Recipe generation response: {content[:500]}...")  # Debug log
        
        # Store raw response for debugging
        st.session_state.raw_recipe_response = content
        
        # Validate and extract JSON
        recipes = validate_recipe_response(content)
        if recipes and len(recipes) >= 5:
            return recipes[:5]  # Return exactly 5 recipes
        
        # Try to extract any JSON array from response
        try:
            start = content.find('[')
            end = content.rfind(']') + 1
            if start >= 0 and end > start:
                meals = json.loads(content[start:end])
                if isinstance(meals, list) and len(meals) > 0:
                    return meals[:5]
        except:
            pass
        
        # Return empty list if parsing fails (no mock data)
        print("Failed to parse recipe response, returning empty list")
        return []
        
    except Exception as e:
        st.error(f"Error generating meals: {str(e)}")
        # Store error for debugging
        st.session_state.raw_recipe_response = f"Error: {str(e)}"
        return []  # Return empty list instead of mock data

def generate_video_script(recipe: Dict) -> str:
    """Generate TikTok-style video script for a recipe"""
    if not client:
        return f"Quick recipe video: Show ingredients → Fast cooking montage → Final dish reveal! 🍳✨ #SnapChefChallenge"
    
    try:
        prompt = f"""Create a 15-30 second TikTok video script for this recipe: {recipe['name']}
        
        Ingredients used: {', '.join(recipe.get('ingredients', []))}
        
        Make it energetic, engaging, and viral-worthy. Include:
        - Hook in first 3 seconds
        - Quick visual instructions
        - Call to action
        - Relevant hashtags
        
        Format as a shot-by-shot script."""
        
        response = client.chat.completions.create(
            model="grok-4",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.9,
            max_tokens=500
        )
        
        return response.choices[0].message.content
        
    except Exception as e:
        return f"Quick recipe video: Show ingredients → Fast cooking montage → Final dish reveal! 🍳✨ #SnapChefChallenge"

def generate_challenge_idea() -> Dict:
    """Generate a daily challenge idea"""
    if not client:
        # Return default challenge if no API key
        return {
            "name": "Fridge Raid Friday",
            "description": "Make something delicious with your leftover ingredients!",
            "rules": ["Use at least 3 leftovers", "No grocery shopping allowed", "Share your before & after"],
            "hashtag": "#FridgeRaidFriday",
            "points": 40
        }
    
    try:
        prompt = """Create a fun, viral-worthy cooking challenge for SnapChef users.
        
        Include:
        1. name: Catchy challenge name
        2. description: What users need to do
        3. rules: Clear rules (2-3 points)
        4. hashtag: Unique hashtag
        5. points: Points awarded for completion
        
        Make it achievable with common fridge ingredients.
        Return as JSON object."""
        
        response = client.chat.completions.create(
            model="grok-4",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.9,
            max_tokens=300
        )
        
        content = response.choices[0].message.content
        try:
            # Extract JSON
            start = content.find('{')
            end = content.rfind('}') + 1
            if start >= 0 and end > start:
                return json.loads(content[start:end])
        except:
            pass
        
        # Fallback
        return {
            "name": "Mystery Meal Monday",
            "description": "Create a meal using only 5 ingredients from your fridge!",
            "rules": ["Use exactly 5 ingredients", "Share a photo of your creation", "Tag a friend to try"],
            "hashtag": "#MysteryMealMonday",
            "points": 50
        }
        
    except Exception as e:
        return {
            "name": "Fridge Raid Friday",
            "description": "Make something delicious with your leftover ingredients!",
            "rules": ["Use at least 3 leftovers", "No grocery shopping allowed", "Share your before & after"],
            "hashtag": "#FridgeRaidFriday",
            "points": 40
        }

@st.cache_data(ttl=3600)
def analyze_fridge_and_generate_recipes(image_base64: str, dietary_preferences: List[str] = None) -> Dict[str, Any]:
    """Single API call to detect ingredients and generate recipes using vision model"""
    if not client:
        return {
            "ingredients": [],
            "recipes": [],
            "error": "API key not configured. Please set up your XAI_API_KEY."
        }
    
    try:
        # Get the combined prompt
        prompt = get_combined_prompt()
        
        # Add dietary preferences if provided
        if dietary_preferences:
            prompt += f"\n\nDIETARY PREFERENCES: {', '.join(dietary_preferences)}"
        
        print(f"Making combined API call with image size: {len(image_base64)} characters")
        
        response = client.chat.completions.create(
            model="grok-4-0709",  # Using Grok 4 model for vision + text
            messages=[
                {
                    "role": "system",
                    "content": prompt
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{image_base64}",
                                "detail": "high"
                            }
                        },
                        {
                            "type": "text",
                            "text": "Please analyze this fridge/pantry image and provide both ingredient detection and recipe generation as specified in the prompt."
                        }
                    ]
                }
            ],
            temperature=0.7,
            max_tokens=4000
        )
        
        # Parse the response
        content = response.choices[0].message.content
        print(f"Received combined response: {content[:200]}...")
        
        # Store raw response for debugging
        st.session_state.raw_combined_response = content
        
        # Parse the combined response
        result = parse_combined_response(content)
        
        # Check if we got valid data
        if not result["ingredients"] and not result.get("image_analysis", {}).get("is_food_image", True):
            return {
                "ingredients": [],
                "recipes": [],
                "error": "No food ingredients detected. Please take a photo of your fridge, pantry, or kitchen ingredients."
            }
        
        return result
        
    except Exception as e:
        print(f"Error in combined API call: {str(e)}")
        return {
            "ingredients": [],
            "recipes": [],
            "error": f"Error analyzing image: {str(e)}"
        }

def get_mock_meals_v2() -> List[Dict]:
    """Return mock meal data for development - 5 complete dinner ideas"""
    return [
        {
            "name": "Herb-Crusted Chicken & Roasted Vegetables",
            "description": "Juicy chicken breast with a crispy herb crust, served with perfectly roasted seasonal vegetables",
            "main_dish": "Herb-Crusted Chicken Breast",
            "side_dish": "Honey-Glazed Roasted Root Vegetables",
            "total_time": 45,
            "prep_time": 15,
            "cook_time": 30,
            "servings": 4,
            "difficulty": "medium",
            "ingredients_used": [
                {"name": "chicken breast", "amount": "4 pieces"},
                {"name": "garlic", "amount": "4 cloves"},
                {"name": "onions", "amount": "2 medium"},
                {"name": "tomatoes", "amount": "2 large"}
            ],
            "instructions": [
                "Preheat oven to 400°F (200°C)",
                "Season chicken breasts with salt, pepper, and minced garlic",
                "Create herb crust with breadcrumbs and dried herbs",
                "Press herb mixture onto chicken breasts",
                "Cut vegetables into uniform pieces",
                "Toss vegetables with olive oil, salt, and honey",
                "Bake chicken for 25-30 minutes until golden",
                "Roast vegetables alongside chicken",
                "Let chicken rest for 5 minutes before serving",
                "Plate chicken with roasted vegetables"
            ],
            "nutrition": {
                "calories": 420,
                "protein": 35,
                "carbs": 28,
                "fat": 18
            },
            "tips": "Pound chicken to even thickness for uniform cooking",
            "tags": ["healthy", "protein-rich", "gluten-free-option"],
            "share_caption": "Just made this incredible herb-crusted chicken dinner! 🍗✨ The kitchen smells AMAZING! Who else is winning at dinner tonight? #SnapChefChallenge #WhatsInYourFridge #HomeCooking #DinnerWin"
        },
        {
            "name": "Creamy Tomato Pasta & Garlic Bread",
            "description": "Rich and creamy tomato pasta with fresh basil, paired with crispy homemade garlic bread",
            "main_dish": "Creamy Tomato Basil Pasta",
            "side_dish": "Crispy Garlic Bread",
            "total_time": 30,
            "prep_time": 10,
            "cook_time": 20,
            "servings": 4,
            "difficulty": "easy",
            "ingredients_used": [
                {"name": "pasta", "amount": "1 lb"},
                {"name": "tomatoes", "amount": "4 medium"},
                {"name": "garlic", "amount": "6 cloves"},
                {"name": "milk", "amount": "1/2 cup"},
                {"name": "cheese", "amount": "1 cup"}
            ],
            "instructions": [
                "Bring large pot of salted water to boil",
                "Cook pasta according to package directions",
                "Dice tomatoes and mince garlic",
                "Sauté garlic in olive oil until fragrant",
                "Add diced tomatoes and simmer for 10 minutes",
                "Add milk and cheese to create creamy sauce",
                "Prepare garlic butter with minced garlic",
                "Spread on bread slices and toast until golden",
                "Drain pasta and toss with sauce",
                "Serve pasta hot with garlic bread on the side"
            ],
            "nutrition": {
                "calories": 480,
                "protein": 18,
                "carbs": 65,
                "fat": 16
            },
            "tips": "Save some pasta water to adjust sauce consistency",
            "tags": ["comfort-food", "vegetarian", "family-favorite"],
            "share_caption": "Comfort food at its finest! 🍝 This creamy tomato pasta is giving me all the cozy vibes. Perfect dinner for tonight! #SnapChefChallenge #WhatsInYourFridge #PastaLove #ComfortFood"
        },
        {
            "name": "Cheesy Vegetable Frittata & Fresh Salad",
            "description": "Fluffy egg frittata loaded with vegetables and cheese, served with a crisp garden salad",
            "main_dish": "Garden Vegetable Frittata",
            "side_dish": "Mixed Green Salad with Vinaigrette",
            "total_time": 35,
            "prep_time": 15,
            "cook_time": 20,
            "servings": 6,
            "difficulty": "easy",
            "ingredients_used": [
                {"name": "eggs", "amount": "8 large"},
                {"name": "cheese", "amount": "1.5 cups"},
                {"name": "onions", "amount": "1 medium"},
                {"name": "tomatoes", "amount": "2 medium"},
                {"name": "milk", "amount": "1/4 cup"}
            ],
            "instructions": [
                "Preheat oven to 375°F (190°C)",
                "Whisk eggs with milk, salt, and pepper",
                "Dice onions and tomatoes",
                "Sauté onions until softened",
                "Add tomatoes and cook briefly",
                "Pour egg mixture over vegetables in oven-safe pan",
                "Sprinkle cheese on top",
                "Bake for 15-20 minutes until set",
                "Prepare salad with fresh greens",
                "Whisk simple vinaigrette and toss with salad"
            ],
            "nutrition": {
                "calories": 320,
                "protein": 22,
                "carbs": 12,
                "fat": 20
            },
            "tips": "Use a cast iron skillet for best results",
            "tags": ["brunch", "vegetarian", "meal-prep"],
            "share_caption": "Brunch for dinner? YES PLEASE! 🍳 This veggie frittata is so fluffy and delicious! Perfect for using up those fridge ingredients. #SnapChefChallenge #WhatsInYourFridge #EggcellentDinner"
        },
        {
            "name": "Chicken Stir-Fry & Egg Fried Rice",
            "description": "Quick and flavorful chicken stir-fry with colorful vegetables, served over homemade egg fried rice",
            "main_dish": "Garlic Ginger Chicken Stir-Fry",
            "side_dish": "Vegetable Egg Fried Rice",
            "total_time": 25,
            "prep_time": 10,
            "cook_time": 15,
            "servings": 4,
            "difficulty": "easy",
            "ingredients_used": [
                {"name": "chicken breast", "amount": "1 lb"},
                {"name": "eggs", "amount": "3"},
                {"name": "onions", "amount": "1 large"},
                {"name": "garlic", "amount": "4 cloves"},
                {"name": "leftover rice or pasta", "amount": "3 cups cooked"}
            ],
            "instructions": [
                "Cut chicken into bite-sized pieces",
                "Prepare all vegetables - dice onions, mince garlic",
                "Heat wok or large pan over high heat",
                "Stir-fry chicken until cooked through",
                "Remove chicken and scramble eggs",
                "Add cold rice and break up clumps",
                "Stir-fry rice with vegetables",
                "Return chicken to pan",
                "Season with soy sauce and sesame oil",
                "Serve immediately while hot"
            ],
            "nutrition": {
                "calories": 380,
                "protein": 28,
                "carbs": 42,
                "fat": 12
            },
            "tips": "Use day-old rice for best fried rice texture",
            "tags": ["quick", "asian-inspired", "one-pan"],
            "share_caption": "Takeout who? 🥡 This homemade stir-fry is better than delivery! Ready in 25 minutes using just my fridge ingredients! #SnapChefChallenge #WhatsInYourFridge #StirFryNight #QuickDinner"
        },
        {
            "name": "Loaded Veggie Quesadillas & Tomato Salsa",
            "description": "Crispy cheese quesadillas stuffed with seasoned vegetables, served with fresh tomato salsa",
            "main_dish": "Three-Cheese Vegetable Quesadillas",
            "side_dish": "Fresh Chunky Tomato Salsa",
            "total_time": 20,
            "prep_time": 10,
            "cook_time": 10,
            "servings": 4,
            "difficulty": "easy",
            "ingredients_used": [
                {"name": "cheese", "amount": "2 cups shredded"},
                {"name": "onions", "amount": "1 medium"},
                {"name": "tomatoes", "amount": "3 large"},
                {"name": "garlic", "amount": "2 cloves"},
                {"name": "tortillas or flatbread", "amount": "8"}
            ],
            "instructions": [
                "Dice onions and sauté until caramelized",
                "Prepare fresh salsa with diced tomatoes",
                "Add minced garlic and lime juice to salsa",
                "Heat griddle or large pan",
                "Layer cheese and vegetables on tortilla",
                "Fold tortilla and cook until golden",
                "Flip and cook other side until crispy",
                "Cut into wedges",
                "Serve hot with fresh salsa",
                "Garnish with sour cream if available"
            ],
            "nutrition": {
                "calories": 340,
                "protein": 16,
                "carbs": 32,
                "fat": 18
            },
            "tips": "Don't overfill quesadillas to prevent spillage",
            "tags": ["mexican-inspired", "vegetarian", "quick"],
            "share_caption": "Quesadilla night is the BEST night! 🌮 These loaded veggie quesadillas are crispy, cheesy perfection! Who's coming over? #SnapChefChallenge #WhatsInYourFridge #QuesadillaLove #MeatlessMonday"
        }
    ]