import pytest
from datetime import datetime, timedelta
from utils.gamification import (
    award_points, check_badges, calculate_streak_bonus,
    generate_daily_challenge, calculate_user_stats,
    get_next_milestone, BADGES, POINT_VALUES
)
import streamlit as st

class TestPointSystem:
    """Test point awarding system"""
    
    def setup_method(self):
        """Reset session state before each test"""
        if hasattr(st, 'session_state'):
            st.session_state.clear()
    
    def test_award_points_valid_action(self):
        """Test awarding points for valid action"""
        st.session_state.user_points = 100
        
        points = award_points('upload_photo')
        
        assert points == POINT_VALUES['upload_photo']
        assert st.session_state.user_points == 105
    
    def test_award_points_invalid_action(self):
        """Test awarding points for invalid action"""
        st.session_state.user_points = 100
        
        points = award_points('invalid_action')
        
        assert points == 0
        assert st.session_state.user_points == 100
    
    def test_daily_points_tracking(self):
        """Test daily points are tracked separately"""
        st.session_state.user_points = 0
        st.session_state.points_today = 0
        
        award_points('cook_meal')
        award_points('share_recipe')
        
        assert st.session_state.points_today == 30

class TestBadgeSystem:
    """Test badge checking and awarding"""
    
    def test_first_meal_badge(self):
        """Test first meal badge condition"""
        user_stats = {'meals_created': 0}
        assert not BADGES['first_meal']['condition'](user_stats)
        
        user_stats['meals_created'] = 1
        assert BADGES['first_meal']['condition'](user_stats)
    
    def test_week_warrior_badge(self):
        """Test streak badge condition"""
        user_stats = {'cooking_streak': 6}
        assert not BADGES['week_warrior']['condition'](user_stats)
        
        user_stats['cooking_streak'] = 7
        assert BADGES['week_warrior']['condition'](user_stats)
    
    def test_check_badges_new_badge(self):
        """Test checking for new badges"""
        st.session_state.badges = []
        user_stats = {'meals_created': 1}
        
        earned = check_badges(user_stats)
        
        assert len(earned) >= 1
        assert earned[0]['id'] == 'first_meal'
    
    def test_check_badges_already_earned(self):
        """Test no duplicate badges"""
        st.session_state.badges = [{'id': 'first_meal'}]
        user_stats = {'meals_created': 1}
        
        earned = check_badges(user_stats)
        
        assert len(earned) == 0

class TestStreakSystem:
    """Test streak bonus calculations"""
    
    def test_streak_bonus_tiers(self):
        """Test different streak bonus tiers"""
        assert calculate_streak_bonus(0) == 0
        assert calculate_streak_bonus(3) == 10
        assert calculate_streak_bonus(7) == 15
        assert calculate_streak_bonus(14) == 25
        assert calculate_streak_bonus(30) == 50

class TestChallenges:
    """Test challenge generation"""
    
    def test_generate_daily_challenge(self):
        """Test daily challenge generation"""
        challenge = generate_daily_challenge()
        
        assert 'name' in challenge
        assert 'description' in challenge
        assert 'rules' in challenge
        assert isinstance(challenge['rules'], list)
        assert 'points' in challenge
        assert 'hashtag' in challenge
    
    def test_daily_challenge_consistency(self):
        """Test same challenge returned for same day"""
        challenge1 = generate_daily_challenge()
        challenge2 = generate_daily_challenge()
        
        assert challenge1['name'] == challenge2['name']

class TestUserStats:
    """Test user statistics calculation"""
    
    def test_calculate_user_stats(self):
        """Test comprehensive stats calculation"""
        st.session_state.saved_recipes = [1, 2, 3]
        st.session_state.shares = 5
        st.session_state.cooking_streak = 7
        st.session_state.user_points = 500
        st.session_state.badges = [1, 2]
        
        stats = calculate_user_stats()
        
        assert stats['meals_created'] == 3
        assert stats['recipes_shared'] == 5
        assert stats['cooking_streak'] == 7
        assert stats['total_points'] == 500
        assert stats['badges_earned'] == 2
        assert stats['money_saved'] == 15  # 3 meals * $5
        assert stats['food_waste_prevented'] == 1.5  # 3 meals * 0.5 lbs

class TestMilestones:
    """Test milestone tracking"""
    
    def test_next_milestone_calculation(self):
        """Test getting next milestone"""
        st.session_state.user_points = 150
        
        milestone = get_next_milestone()
        
        assert milestone['points_needed'] == 100  # 250 - 150
        assert milestone['total_points'] == 250
        assert milestone['progress'] == 0.6  # 150/250
    
    def test_max_milestone_reached(self):
        """Test when all milestones reached"""
        st.session_state.user_points = 10000
        
        milestone = get_next_milestone()
        
        assert milestone['points_needed'] == 0
        assert milestone['progress'] == 1.0