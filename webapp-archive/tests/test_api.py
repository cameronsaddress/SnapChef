import pytest
import json
from unittest.mock import Mock, patch
from utils.api import detect_ingredients, generate_meals, generate_video_script, generate_challenge_idea

class TestGrokAPI:
    """Test Grok 4 API integration"""
    
    @patch('utils.api.client')
    def test_detect_ingredients_success(self, mock_client):
        """Test successful ingredient detection"""
        # Mock API response
        mock_response = Mock()
        mock_response.choices = [Mock(message=Mock(content='["eggs", "milk", "cheese", "tomatoes"]'))]
        mock_client.chat.completions.create.return_value = mock_response
        
        # Test
        result = detect_ingredients("base64_image_data")
        
        assert isinstance(result, list)
        assert len(result) == 4
        assert "eggs" in result
        assert "milk" in result
    
    @patch('utils.api.client')
    def test_detect_ingredients_fallback(self, mock_client):
        """Test fallback when API fails"""
        # Mock API error
        mock_client.chat.completions.create.side_effect = Exception("API Error")
        
        # Test - should return mock data
        result = detect_ingredients("base64_image_data")
        
        assert isinstance(result, list)
        assert len(result) > 0
        assert "eggs" in result  # Check for mock data
    
    @patch('utils.api.client')
    def test_generate_meals_success(self, mock_client):
        """Test successful meal generation"""
        # Mock meal data
        mock_meals = [
            {
                "name": "Quick Scramble",
                "description": "Easy egg scramble",
                "recipe": ["Heat pan", "Scramble eggs"],
                "nutrition": {"calories": 200}
            }
        ]
        
        mock_response = Mock()
        mock_response.choices = [Mock(message=Mock(content=json.dumps(mock_meals)))]
        mock_client.chat.completions.create.return_value = mock_response
        
        # Test
        ingredients = ["eggs", "milk"]
        result = generate_meals(ingredients, dietary_preferences=["vegetarian"])
        
        assert isinstance(result, list)
        assert len(result) >= 1
        assert "name" in result[0]
        assert "recipe" in result[0]
    
    def test_generate_meals_with_preferences(self):
        """Test meal generation with dietary preferences"""
        ingredients = ["tofu", "vegetables", "rice"]
        dietary_prefs = ["vegan", "gluten-free"]
        
        # Even with mock data, function should handle preferences
        result = generate_meals(ingredients, dietary_prefs)
        
        assert isinstance(result, list)
        assert len(result) > 0
    
    @patch('utils.api.client')
    def test_generate_video_script(self, mock_client):
        """Test video script generation"""
        mock_response = Mock()
        mock_response.choices = [Mock(message=Mock(content="Shot 1: Show ingredients..."))]
        mock_client.chat.completions.create.return_value = mock_response
        
        recipe = {"name": "Test Recipe", "ingredients": ["eggs", "milk"]}
        result = generate_video_script(recipe)
        
        assert isinstance(result, str)
        assert len(result) > 0
    
    def test_generate_challenge_idea(self):
        """Test challenge generation"""
        result = generate_challenge_idea()
        
        assert isinstance(result, dict)
        assert "name" in result
        assert "description" in result
        assert "points" in result

class TestAPIMocking:
    """Test API mock data generation"""
    
    def test_mock_meals_structure(self):
        """Test structure of mock meal data"""
        from utils.api import get_mock_meals
        
        meals = get_mock_meals(["pasta", "vegetables"], ["vegetarian"])
        
        assert len(meals) == 3  # Should return 3 meals
        
        for meal in meals:
            assert "name" in meal
            assert "description" in meal
            assert "recipe" in meal
            assert isinstance(meal["recipe"], list)
            assert "nutrition" in meal
            assert "share_caption" in meal
            assert "#SnapChefChallenge" in meal["share_caption"]