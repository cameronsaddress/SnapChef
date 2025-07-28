"""
SnapChef Prompts Package
Contains all prompts and schemas for LLM interactions.
"""

from .grok_prompts import (
    # Main prompts
    INGREDIENT_DETECTION_PROMPT,
    RECIPE_GENERATION_PROMPT,
    
    # JSON schemas
    INGREDIENT_DETECTION_SCHEMA,
    RECIPE_GENERATION_SCHEMA,
    
    # Progress messages
    CAMERA_PROGRESS_MESSAGES,
    
    # Helper functions
    format_ingredient_detection_prompt,
    format_recipe_generation_prompt,
    get_random_progress_message,
    validate_ingredient_response,
    validate_recipe_response
)

__all__ = [
    'INGREDIENT_DETECTION_PROMPT',
    'RECIPE_GENERATION_PROMPT',
    'INGREDIENT_DETECTION_SCHEMA',
    'RECIPE_GENERATION_SCHEMA',
    'CAMERA_PROGRESS_MESSAGES',
    'format_ingredient_detection_prompt',
    'format_recipe_generation_prompt',
    'get_random_progress_message',
    'validate_ingredient_response',
    'validate_recipe_response'
]