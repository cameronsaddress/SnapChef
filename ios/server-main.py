# server-main.py
"""
Updated FastAPI server that matches iOS app requirements.
To deploy: 
1. Rename this to main.py
2. Rename server-prompt.py to prompt.py
3. Update environment variables in Render:
   - APP_API_KEY=5380e4b60818cf237678fccfd4b8f767d1c94
   - GROK_API_KEY=<your-grok-api-key>
"""
import os
import base64
import json
import re
from typing import List, Dict, Any, Optional
import uuid

from fastapi import FastAPI, HTTPException, Request, Response, status, UploadFile, File, Form, Depends
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import httpx

# In production, this would be: from prompt import COMBINED_PROMPT
# For deployment, rename server-prompt.py to prompt.py

# --- Configuration ---
GROK_API_KEY = os.environ.get("GROK_API_KEY")
# iOS app authentication key
APP_API_KEY = os.environ.get("APP_API_KEY")  # Set this in Render's environment variables

# Grok Vision API endpoint (same as OpenAI format)
GROK_VISION_API_URL = "https://api.x.ai/v1/chat/completions"

# --- Pydantic Models (Same as original) ---
class Nutrition(BaseModel):
    calories: int = 0
    protein: int = 0
    carbs: int = 0
    fat: int = 0
    fiber: Optional[int] = None
    sugar: Optional[int] = None
    sodium: Optional[int] = None

class IngredientUsed(BaseModel):
    name: str
    amount: str

class Recipe(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    description: str
    main_dish: Optional[str] = None
    side_dish: Optional[str] = None
    total_time: Optional[int] = None
    prep_time: Optional[int] = None
    cook_time: Optional[int] = None
    servings: Optional[int] = None
    difficulty: str
    ingredients_used: Optional[List[IngredientUsed]] = []
    instructions: List[str]
    nutrition: Optional[Nutrition] = None
    tips: Optional[str] = None
    tags: Optional[List[str]] = []
    share_caption: Optional[str] = None

class ImageAnalysis(BaseModel):
    is_food_image: bool
    confidence: str
    image_description: str

class Ingredient(BaseModel):
    name: str
    quantity: str
    unit: str
    category: str
    freshness: str
    location: Optional[str] = None

class GrokParsedResponse(BaseModel):
    image_analysis: ImageAnalysis
    ingredients: List[Ingredient]
    recipes: List[Recipe]

class APIResponse(BaseModel):
    data: GrokParsedResponse
    message: str = "Recipe generation successful."

# --- FastAPI App Initialization ---
app = FastAPI(
    title="SnapChef Grok Vision API Proxy",
    description="Secure backend for SnapChef iOS app to process images and generate recipes using Grok Vision API.",
    version="1.0.0"
)

# --- Dependency Check ---
@app.on_event("startup")
async def startup_event():
    """
    Ensures that the GROK_API_KEY and APP_API_KEY environment variables are set before the server starts.
    """
    if not GROK_API_KEY:
        raise ValueError("GROK_API_KEY environment variable is not set. Please set it in Render's environment variables.")
    if not APP_API_KEY:
        raise ValueError("APP_API_KEY environment variable is not set. Please set it in Render's environment variables for app authentication.")
    print("FastAPI server starting...")

# --- API Key Authentication Dependency ---
async def get_app_api_key(request: Request):
    """
    Dependency to validate the API key sent from the mobile app.
    Expects the key in the 'X-App-API-Key' header.
    """
    api_key = request.headers.get("X-App-API-Key")
    if not api_key or api_key != APP_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing X-App-API-Key header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return api_key

# --- Helper Function to Build Dynamic Prompt ---
def build_dynamic_prompt(base_prompt: str, preferences: Dict[str, Any]) -> str:
    """
    Builds a dynamic prompt by adding user preferences only if they are provided.
    """
    # Start with the base prompt
    full_prompt = base_prompt
    
    # Only add user preferences section if there are any preferences
    has_preferences = any([
        preferences.get("dietary_restrictions"),
        preferences.get("food_type"),
        preferences.get("difficulty_preference"),
        preferences.get("health_preference"),
        preferences.get("meal_type"),
        preferences.get("cooking_time_preference"),
        preferences.get("number_of_recipes") != 5  # Default is 5
    ])
    
    if has_preferences:
        full_prompt += "\n\n--- USER PREFERENCES ---\n"
        
        if preferences.get("dietary_restrictions"):
            restrictions = ", ".join(preferences["dietary_restrictions"])
            full_prompt += f"DIETARY RESTRICTIONS: {restrictions}\n"
            full_prompt += "IMPORTANT: All recipes MUST strictly adhere to these dietary restrictions. Do not include any ingredients that violate these restrictions.\n"
        
        if preferences.get("food_type"):
            full_prompt += f"CUISINE PREFERENCE: Focus on {preferences['food_type']} cuisine/food style.\n"
        
        if preferences.get("difficulty_preference"):
            difficulty_map = {
                "easy": "simple recipes with minimal steps and basic techniques",
                "medium": "moderate difficulty recipes with some cooking techniques",
                "hard": "complex recipes that may require advanced techniques or longer preparation"
            }
            full_prompt += f"DIFFICULTY: Generate {difficulty_map.get(preferences['difficulty_preference'], preferences['difficulty_preference'])}.\n"
        
        if preferences.get("health_preference"):
            health_map = {
                "healthy": "Focus on nutritious, balanced recipes with vegetables and lean proteins",
                "balanced": "Create well-rounded recipes with a mix of nutrients",
                "indulgent": "Include comfort foods and richer recipes"
            }
            full_prompt += f"HEALTH FOCUS: {health_map.get(preferences['health_preference'], preferences['health_preference'])}.\n"
        
        if preferences.get("meal_type"):
            full_prompt += f"MEAL TYPE: Generate recipes suitable for {preferences['meal_type']}.\n"
        
        if preferences.get("cooking_time_preference"):
            time_map = {
                "quick": "Keep total cooking time under 20 minutes",
                "under 30 mins": "Keep total cooking time under 30 minutes",
                "under 60 mins": "Keep total cooking time under 60 minutes",
                "any": "No time restrictions"
            }
            full_prompt += f"TIME CONSTRAINT: {time_map.get(preferences['cooking_time_preference'], 'No specific time constraint')}.\n"
        
        num_recipes = preferences.get("number_of_recipes", 5)
        if num_recipes != 5:
            full_prompt += f"NUMBER OF RECIPES: Generate exactly {num_recipes} recipes (not the default 5).\n"
        
        full_prompt += "------------------------\n"
    
    return full_prompt

# --- Helper Function for LLM Call ---
async def call_grok_vision_api(
    image_base64: str,
    session_id: str,
    additional_prompt_context: Dict[str, Any] = {}
) -> Dict[str, Any]:
    """
    Constructs the payload and calls the Grok Vision API.
    Handles potential API errors and parses the response.
    """
    if not GROK_API_KEY:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="API key not configured on server.")

    # Import the base prompt
    # In production after renaming: from prompt import COMBINED_PROMPT
    try:
        from server_prompt import COMBINED_PROMPT
    except ImportError:
        # Fallback for production when files are renamed
        from prompt import COMBINED_PROMPT
    
    # Build dynamic prompt with user preferences
    full_prompt = build_dynamic_prompt(COMBINED_PROMPT, additional_prompt_context)

    headers = {
        "Authorization": f"Bearer {GROK_API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": "grok-2-vision-1212",  # Latest Grok vision model
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": full_prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}}
                ]
            }
        ],
        "max_tokens": 4000,  # Increased for detailed recipes
        "temperature": 0.7,
        "response_format": {"type": "json_object"}
    }

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(GROK_VISION_API_URL, headers=headers, json=payload, timeout=90.0)
            response.raise_for_status()
            grok_response_data = response.json()

            llm_content_str = grok_response_data.get("choices", [{}])[0].get("message", {}).get("content")

            if not llm_content_str:
                raise ValueError("Grok API response did not contain expected content.")

            parsed_llm_content = json.loads(llm_content_str)
            return parsed_llm_content

    except httpx.RequestError as e:
        print(f"[{session_id}] HTTP Request Error to Grok API: {e}")
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=f"Failed to connect to Grok API: {e}")
    except httpx.HTTPStatusError as e:
        print(f"[{session_id}] Grok API returned HTTP error: {e.response.status_code} - {e.response.text}")
        raise HTTPException(status_code=e.response.status_code, detail=f"Grok API error: {e.response.text}")
    except json.JSONDecodeError as e:
        print(f"[{session_id}] Failed to decode JSON from Grok API response: {e}. Raw response: {llm_content_str}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Invalid JSON response from Grok API: {e}. Check LLM output format.")
    except Exception as e:
        print(f"[{session_id}] An unexpected error occurred during Grok API call: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"An unexpected error occurred: {e}")

# --- API Endpoint ---
@app.post("/analyze_fridge_image", response_model=APIResponse)
async def analyze_fridge_image(
    session_id: str = Form(..., description="Unique session ID from the client app (UUID recommended)"),
    dietary_restrictions: Optional[str] = Form("[]", description="JSON string of dietary restrictions, e.g., '[\"vegetarian\", \"gluten-free\"]'"),
    food_type: Optional[str] = Form(None, description="Preferred food type/cuisine (e.g., 'American', 'Mexican')"),
    difficulty_preference: Optional[str] = Form(None, description="Preferred recipe difficulty (e.g., 'easy', 'medium', 'hard')"),
    health_preference: Optional[str] = Form(None, description="Preferred health focus (e.g., 'healthy', 'indulgent', 'balanced')"),
    meal_type: Optional[str] = Form(None, description="Preferred meal type (e.g., 'breakfast', 'lunch', 'dinner', 'snack')"),
    cooking_time_preference: Optional[str] = Form(None, description="Preferred cooking time (e.g., 'quick', 'under 30 mins', 'any')"),
    number_of_recipes: Optional[int] = Form(5, description="Number of recipes to generate (default 5)"),
    image_file: UploadFile = File(..., description="Image of fridge/pantry as a file upload"),
    api_key: str = Depends(get_app_api_key)  # Authentication dependency
):
    """
    Receives an image (e.g., of a fridge/pantry), analyzes it for ingredients,
    and generates recipes using the Grok Vision API, incorporating user preferences.
    The Grok API key is securely managed on the server.
    Requires 'X-App-API-Key' header for authentication.
    """
    # Read image bytes and base64 encode
    image_bytes = await image_file.read()
    image_base64 = base64.b64encode(image_bytes).decode('utf-8')
    mime_type = image_file.content_type

    print(f"[{session_id}] Received request. Image MIME type: {mime_type}")
    print(f"[{session_id}] Dietary restrictions (raw): {dietary_restrictions}")

    # Parse dietary_restrictions from JSON string to List[str]
    parsed_dietary_restrictions: List[str] = []
    if dietary_restrictions and dietary_restrictions.strip() != "[]":
        try:
            parsed_dietary_restrictions = json.loads(dietary_restrictions)
            if not isinstance(parsed_dietary_restrictions, list):
                raise ValueError("Dietary restrictions must be a JSON array string.")
            parsed_dietary_restrictions = [str(item) for item in parsed_dietary_restrictions]
        except json.JSONDecodeError:
            print(f"[{session_id}] Warning: Could not parse dietary_restrictions as JSON: {dietary_restrictions}")
            # Try to handle as comma-separated string as fallback
            parsed_dietary_restrictions = [r.strip() for r in dietary_restrictions.split(",") if r.strip()]
        except ValueError as e:
            print(f"[{session_id}] Warning: Invalid dietary_restrictions format: {e}")
            parsed_dietary_restrictions = []

    # Collect all preferences into a dictionary for the LLM call
    additional_prompt_context = {
        "dietary_restrictions": parsed_dietary_restrictions,
        "food_type": food_type,
        "difficulty_preference": difficulty_preference,
        "health_preference": health_preference,
        "meal_type": meal_type,
        "cooking_time_preference": cooking_time_preference,
        "number_of_recipes": number_of_recipes
    }

    # Log the preferences for debugging
    print(f"[{session_id}] User preferences: {json.dumps(additional_prompt_context, indent=2)}")

    try:
        grok_parsed_response_dict = await call_grok_vision_api(
            image_base64,
            session_id,
            additional_prompt_context=additional_prompt_context
        )
        
        # Validate and create response
        grok_parsed_response = GrokParsedResponse(**grok_parsed_response_dict)

        # Ensure all recipes have IDs
        for recipe in grok_parsed_response.recipes:
            if not recipe.id:
                recipe.id = str(uuid.uuid4())

        return APIResponse(data=grok_parsed_response)

    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"[{session_id}] Unhandled error processing request: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"An unexpected server error occurred: {e}")

# --- Health Check Endpoint ---
@app.get("/health", response_model=Dict[str, str])
async def health_check():
    return {"status": "ok", "message": "SnapChef Grok Vision API Proxy is running."}