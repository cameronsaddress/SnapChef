import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from utils.database import (
    Base, User, Recipe, Challenge, Badge,
    create_user, get_user_by_username, update_user_points,
    check_and_update_daily_usage
)
from datetime import datetime

class TestDatabase:
    """Test database operations"""
    
    @pytest.fixture
    def test_db(self):
        """Create test database"""
        engine = create_engine('sqlite:///:memory:')
        Base.metadata.create_all(engine)
        TestSessionLocal = sessionmaker(bind=engine)
        return TestSessionLocal()
    
    def test_create_user(self, test_db):
        """Test user creation"""
        user = User(
            username="testuser",
            email="test@example.com",
            name="Test User",
            password_hash="hashed_password",
            referral_code="TEST123"
        )
        
        test_db.add(user)
        test_db.commit()
        
        # Verify user was created
        saved_user = test_db.query(User).filter_by(username="testuser").first()
        assert saved_user is not None
        assert saved_user.email == "test@example.com"
        assert saved_user.points == 0
        assert saved_user.subscription_tier == "free"
    
    def test_user_relationships(self, test_db):
        """Test user relationships"""
        # Create user
        user = User(username="chef1", email="chef@example.com", name="Chef")
        test_db.add(user)
        test_db.commit()
        
        # Create recipe for user
        recipe = Recipe(
            user_id=user.id,
            ingredients=["eggs", "milk"],
            meal_name="Scrambled Eggs",
            meal_description="Simple scrambled eggs"
        )
        test_db.add(recipe)
        test_db.commit()
        
        # Test relationship
        assert len(user.recipes) == 1
        assert user.recipes[0].meal_name == "Scrambled Eggs"
    
    def test_update_points(self, test_db):
        """Test updating user points"""
        user = User(username="pointuser", email="points@example.com", name="Points", points=100)
        test_db.add(user)
        test_db.commit()
        
        # Update points
        user.points += 50
        test_db.commit()
        
        # Verify update
        updated_user = test_db.query(User).filter_by(username="pointuser").first()
        assert updated_user.points == 150
    
    def test_recipe_creation(self, test_db):
        """Test recipe creation"""
        user = User(username="recipeuser", email="recipe@example.com", name="Recipe")
        test_db.add(user)
        test_db.commit()
        
        recipe = Recipe(
            user_id=user.id,
            ingredients=["pasta", "tomatoes", "cheese"],
            meal_name="Pasta Marinara",
            meal_description="Classic pasta dish",
            recipe_steps=["Boil pasta", "Make sauce", "Combine"],
            nutritional_info={"calories": 400, "protein": 15},
            is_shared=True,
            share_count=5
        )
        test_db.add(recipe)
        test_db.commit()
        
        # Verify recipe
        saved_recipe = test_db.query(Recipe).filter_by(meal_name="Pasta Marinara").first()
        assert saved_recipe is not None
        assert len(saved_recipe.ingredients) == 3
        assert saved_recipe.share_count == 5
    
    def test_challenge_creation(self, test_db):
        """Test challenge creation"""
        challenge = Challenge(
            name="5 Ingredient Challenge",
            description="Create meal with 5 ingredients",
            challenge_type="daily",
            start_date=datetime.now(),
            end_date=datetime.now(),
            points_reward=50,
            badge_reward="5_ingredient_master"
        )
        test_db.add(challenge)
        test_db.commit()
        
        # Verify challenge
        saved_challenge = test_db.query(Challenge).first()
        assert saved_challenge.name == "5 Ingredient Challenge"
        assert saved_challenge.points_reward == 50
    
    def test_badge_system(self, test_db):
        """Test badge creation"""
        badge = Badge(
            name="Master Chef",
            description="Created 100 recipes",
            icon="👨‍🍳",
            points_required=1000
        )
        test_db.add(badge)
        test_db.commit()
        
        # Verify badge
        saved_badge = test_db.query(Badge).filter_by(name="Master Chef").first()
        assert saved_badge is not None
        assert saved_badge.points_required == 1000

class TestDatabaseHelpers:
    """Test database helper functions"""
    
    def test_get_user_by_username_exists(self, monkeypatch):
        """Test getting existing user"""
        # Mock the database query
        mock_user = User(username="testuser", email="test@example.com")
        
        def mock_query(*args, **kwargs):
            class MockQuery:
                def filter(self, *args):
                    return self
                def first(self):
                    return mock_user
            return MockQuery()
        
        # Would need to properly mock SessionLocal
        # For now, this shows the test structure
    
    def test_daily_usage_tracking(self):
        """Test daily usage limit tracking"""
        # This would test the check_and_update_daily_usage function
        # Ensuring it properly tracks daily meal generation
        pass