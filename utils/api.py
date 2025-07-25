import os
import base64
import json
from openai import OpenAI
from typing import List, Dict, Optional
import streamlit as st

# Initialize Grok client
client = OpenAI(
    api_key=os.getenv("XAI_API_KEY"),
    base_url="https://api.x.ai/v1"
)

def encode_image_to_base64(image_bytes) -> str:
    """Convert image bytes to base64 string"""
    return base64.b64encode(image_bytes).decode('utf-8')

@st.cache_data(ttl=3600)
def detect_ingredients(image_base64: str) -> List[str]:
    """Detect ingredients from fridge/pantry photo using Grok 4"""
    try:
        response = client.chat.completions.create(
            model="grok-4",
            messages=[{
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
                        "text": """Identify all food items and ingredients visible in this fridge/pantry photo. 
                        Be thorough and specific. List them as a JSON array of strings.
                        Example format: ["eggs", "milk", "carrots", "chicken breast", "pasta"]"""
                    }
                ]
            }],
            temperature=0.7,
            max_tokens=500
        )
        
        # Parse the response
        content = response.choices[0].message.content
        # Extract JSON from the response
        try:
            # Find JSON array in the response
            start = content.find('[')
            end = content.rfind(']') + 1
            if start >= 0 and end > start:
                ingredients = json.loads(content[start:end])
                return ingredients
        except:
            # Fallback: split by common delimiters
            ingredients = [item.strip() for item in content.replace('\n', ',').split(',') if item.strip()]
            return ingredients
            
    except Exception as e:
        st.error(f"Error detecting ingredients: {str(e)}")
        # Return mock data for development
        return ["eggs", "milk", "cheese", "tomatoes", "chicken", "pasta", "onions", "garlic"]

@st.cache_data(ttl=3600)
def generate_meals(ingredients: List[str], dietary_preferences: List[str] = None, count: int = 3) -> List[Dict]:
    """Generate meal ideas using detected ingredients"""
    try:
        diet_text = f" Filter for these dietary preferences: {', '.join(dietary_preferences)}." if dietary_preferences else ""
        
        prompt = f"""Given these ingredients: {', '.join(ingredients)}
        
        Generate {count} creative meal ideas that use ONLY these ingredients (no additional ingredients required).{diet_text}
        
        For each meal, provide:
        1. name: Creative meal name
        2. description: Brief appealing description
        3. recipe: Step-by-step cooking instructions
        4. prep_time: Preparation time in minutes
        5. cook_time: Cooking time in minutes
        6. servings: Number of servings
        7. nutrition: Estimated nutritional info (calories, protein, carbs, fat)
        8. difficulty: easy/medium/hard
        9. tags: Array of tags (e.g., "quick", "healthy", "comfort food")
        10. share_caption: A viral-worthy caption for social media with emojis and hashtags
        
        Return as a JSON array of meal objects.
        Include #SnapChefChallenge and #WhatsInYourFridge hashtags in share_caption."""
        
        response = client.chat.completions.create(
            model="grok-4",
            messages=[{
                "role": "user",
                "content": prompt
            }],
            temperature=0.8,
            max_tokens=2000
        )
        
        content = response.choices[0].message.content
        
        # Extract JSON from response
        try:
            start = content.find('[')
            end = content.rfind(']') + 1
            if start >= 0 and end > start:
                meals = json.loads(content[start:end])
                return meals
        except:
            pass
        
        # Return mock data if parsing fails
        return get_mock_meals(ingredients, dietary_preferences)
        
    except Exception as e:
        st.error(f"Error generating meals: {str(e)}")
        return get_mock_meals(ingredients, dietary_preferences)

def generate_video_script(recipe: Dict) -> str:
    """Generate TikTok-style video script for a recipe"""
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

def get_mock_meals(ingredients: List[str], dietary_preferences: List[str] = None) -> List[Dict]:
    """Return mock meal data for development"""
    return [
        {
            "name": "Quick Veggie Stir-Fry",
            "description": "A colorful and healthy stir-fry using your fresh vegetables",
            "recipe": [
                "Heat oil in a large pan",
                "Add chopped vegetables",
                "Stir-fry for 5-7 minutes",
                "Season with soy sauce and garlic",
                "Serve hot"
            ],
            "prep_time": 10,
            "cook_time": 10,
            "servings": 2,
            "nutrition": {
                "calories": 250,
                "protein": 8,
                "carbs": 35,
                "fat": 10
            },
            "difficulty": "easy",
            "tags": ["quick", "healthy", "vegetarian"],
            "share_caption": "Just whipped up this amazing stir-fry with leftovers! 🥦🥕 Who else is team #NoFoodWaste? Try the #SnapChefChallenge #WhatsInYourFridge #HealthyEating"
        },
        {
            "name": "Protein Power Bowl",
            "description": "A satisfying bowl packed with protein and flavor",
            "recipe": [
                "Cook your protein of choice",
                "Prepare a base of grains or greens",
                "Add fresh vegetables",
                "Top with a simple sauce",
                "Garnish and enjoy"
            ],
            "prep_time": 15,
            "cook_time": 20,
            "servings": 1,
            "nutrition": {
                "calories": 450,
                "protein": 35,
                "carbs": 40,
                "fat": 15
            },
            "difficulty": "medium",
            "tags": ["protein", "meal-prep", "nutritious"],
            "share_caption": "Meal prep game strong! 💪 This power bowl is giving me LIFE! Who's joining the #SnapChefChallenge? #WhatsInYourFridge #MealPrep #HealthyLifestyle"
        },
        {
            "name": "Comfort Pasta Fusion",
            "description": "A cozy pasta dish that brings comfort to any day",
            "recipe": [
                "Boil pasta according to package",
                "Sauté available vegetables",
                "Mix pasta with veggies",
                "Add cheese or cream if available",
                "Season to taste"
            ],
            "prep_time": 5,
            "cook_time": 15,
            "servings": 3,
            "nutrition": {
                "calories": 380,
                "protein": 12,
                "carbs": 55,
                "fat": 12
            },
            "difficulty": "easy",
            "tags": ["comfort-food", "quick", "family-friendly"],
            "share_caption": "Comfort food mode: ACTIVATED! 🍝✨ Made this with whatever was in my fridge and it's *chef's kiss* #SnapChefChallenge #WhatsInYourFridge #ComfortFood #HomeCooking"
        }
    ]