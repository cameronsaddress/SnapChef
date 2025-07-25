import streamlit as st
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import random

# Point values for different actions
POINT_VALUES = {
    'upload_photo': 5,
    'generate_meal': 10,
    'cook_meal': 20,
    'share_recipe': 10,
    'complete_daily_challenge': 50,
    'complete_weekly_challenge': 200,
    'maintain_streak_7': 100,
    'maintain_streak_30': 500,
    'first_recipe': 50,
    'referral_signup': 50,
    'get_upvote': 2,
    'win_contest': 300
}

# Badge definitions
BADGES = {
    'first_meal': {
        'name': 'First Meal',
        'icon': '🍳',
        'description': 'Created your first meal',
        'condition': lambda stats: stats.get('meals_created', 0) >= 1,
        'points': 50,
        'rarity': 'common'
    },
    'week_warrior': {
        'name': 'Week Warrior',
        'icon': '📅',
        'description': '7-day cooking streak',
        'condition': lambda stats: stats.get('cooking_streak', 0) >= 7,
        'points': 100,
        'rarity': 'rare'
    },
    'social_chef': {
        'name': 'Social Chef',
        'icon': '📱',
        'description': 'Shared 10 recipes',
        'condition': lambda stats: stats.get('recipes_shared', 0) >= 10,
        'points': 75,
        'rarity': 'uncommon'
    },
    'zero_hero': {
        'name': 'Zero Hero',
        'icon': '♻️',
        'description': 'Zero waste for a week',
        'condition': lambda stats: stats.get('zero_waste_days', 0) >= 7,
        'points': 200,
        'rarity': 'epic'
    },
    'viral_sensation': {
        'name': 'Viral Sensation',
        'icon': '🔥',
        'description': 'Recipe got 1K+ views',
        'condition': lambda stats: stats.get('max_recipe_views', 0) >= 1000,
        'points': 500,
        'rarity': 'legendary'
    },
    'master_chef': {
        'name': 'Master Chef',
        'icon': '👨‍🍳',
        'description': 'Created 100 recipes',
        'condition': lambda stats: stats.get('meals_created', 0) >= 100,
        'points': 300,
        'rarity': 'epic'
    },
    'penny_pincher': {
        'name': 'Penny Pincher',
        'icon': '💰',
        'description': 'Saved $100 on groceries',
        'condition': lambda stats: stats.get('money_saved', 0) >= 100,
        'points': 150,
        'rarity': 'rare'
    },
    'challenge_champion': {
        'name': 'Challenge Champion',
        'icon': '🏆',
        'description': 'Won 5 challenges',
        'condition': lambda stats: stats.get('challenges_won', 0) >= 5,
        'points': 250,
        'rarity': 'epic'
    }
}

def award_points(action: str, user_id: Optional[int] = None) -> int:
    """Award points for an action"""
    points = POINT_VALUES.get(action, 0)
    
    if points > 0:
        # Update session state
        current_points = st.session_state.get('user_points', 0)
        st.session_state.user_points = current_points + points
        
        # Track daily points
        today_points = st.session_state.get('points_today', 0)
        st.session_state.points_today = today_points + points
        
        # Show notification
        st.success(f"+{points} points for {action.replace('_', ' ')}!")
        
        # Check for level up
        check_level_up(st.session_state.user_points)
        
    return points

def check_badges(user_stats: Dict) -> List[Dict]:
    """Check which badges the user has earned"""
    earned_badges = []
    
    for badge_id, badge_info in BADGES.items():
        if badge_info['condition'](user_stats):
            # Check if already earned
            current_badges = st.session_state.get('badges', [])
            if not any(b['id'] == badge_id for b in current_badges):
                earned_badges.append({
                    'id': badge_id,
                    'name': badge_info['name'],
                    'icon': badge_info['icon'],
                    'description': badge_info['description'],
                    'points': badge_info['points'],
                    'rarity': badge_info['rarity'],
                    'earned_date': datetime.now()
                })
                
                # Award badge points
                award_points('earn_badge', badge_info['points'])
    
    return earned_badges

def check_level_up(total_points: int) -> Optional[Dict]:
    """Check if user has leveled up"""
    levels = [
        {'level': 1, 'name': 'Novice Chef', 'points': 0},
        {'level': 2, 'name': 'Home Cook', 'points': 100},
        {'level': 3, 'name': 'Kitchen Expert', 'points': 300},
        {'level': 4, 'name': 'Recipe Master', 'points': 600},
        {'level': 5, 'name': 'Culinary Artist', 'points': 1000},
        {'level': 6, 'name': 'Food Wizard', 'points': 1500},
        {'level': 7, 'name': 'Master Chef', 'points': 2500},
        {'level': 8, 'name': 'Celebrity Chef', 'points': 4000},
        {'level': 9, 'name': 'Iron Chef', 'points': 6000},
        {'level': 10, 'name': 'Legendary Chef', 'points': 10000}
    ]
    
    current_level = st.session_state.get('user_level', 1)
    
    for level_info in reversed(levels):
        if total_points >= level_info['points'] and level_info['level'] > current_level:
            st.session_state.user_level = level_info['level']
            st.balloons()
            st.success(f"🎉 Level Up! You're now a {level_info['name']}!")
            return level_info
    
    return None

def calculate_streak_bonus(streak_days: int) -> int:
    """Calculate bonus points for streak"""
    if streak_days >= 30:
        return 50
    elif streak_days >= 14:
        return 25
    elif streak_days >= 7:
        return 15
    elif streak_days >= 3:
        return 10
    else:
        return 0

def generate_daily_challenge() -> Dict:
    """Generate a random daily challenge"""
    challenges = [
        {
            'type': 'ingredient_limit',
            'name': '5-Ingredient Challenge',
            'description': 'Create a delicious meal using only 5 ingredients or less',
            'rules': ['Use maximum 5 ingredients', 'Salt, pepper, and oil don\'t count', 'Share the final result'],
            'points': 50,
            'hashtag': '#5IngredientChallenge'
        },
        {
            'type': 'time_limit',
            'name': '15-Minute Meal Sprint',
            'description': 'Make a complete meal in 15 minutes or less',
            'rules': ['Total cook time under 15 minutes', 'Must be a full meal', 'Include prep time'],
            'points': 60,
            'hashtag': '#15MinuteMeals'
        },
        {
            'type': 'cuisine',
            'name': 'Around the World',
            'description': 'Create a dish from a different cuisine using your fridge items',
            'rules': ['Choose any world cuisine', 'Use authentic techniques', 'Explain the inspiration'],
            'points': 70,
            'hashtag': '#AroundTheWorldChallenge'
        },
        {
            'type': 'leftover',
            'name': 'Leftover Transformation',
            'description': 'Turn yesterday\'s leftovers into today\'s masterpiece',
            'rules': ['Use at least 50% leftovers', 'Create something completely different', 'No additional shopping'],
            'points': 80,
            'hashtag': '#LeftoverMagic'
        },
        {
            'type': 'healthy',
            'name': 'Nutrition Champion',
            'description': 'Create a meal with all 5 food groups',
            'rules': ['Include protein, grains, vegetables, fruits, dairy', 'Keep it under 500 calories', 'Make it Instagram-worthy'],
            'points': 65,
            'hashtag': '#HealthyEating'
        }
    ]
    
    # Get today's challenge (deterministic based on date)
    today_index = datetime.now().timetuple().tm_yday % len(challenges)
    return challenges[today_index]

def calculate_user_stats() -> Dict:
    """Calculate comprehensive user statistics"""
    stats = {
        'meals_created': len(st.session_state.get('saved_recipes', [])),
        'recipes_shared': st.session_state.get('shares', 0),
        'cooking_streak': st.session_state.get('cooking_streak', 0),
        'total_points': st.session_state.get('user_points', 0),
        'challenges_completed': len(st.session_state.get('completed_challenges', [])),
        'badges_earned': len(st.session_state.get('badges', [])),
        'money_saved': calculate_money_saved(),
        'food_waste_prevented': calculate_food_waste_prevented(),
        'community_rank': get_community_rank(),
        'level': st.session_state.get('user_level', 1)
    }
    
    return stats

def calculate_money_saved() -> float:
    """Calculate estimated money saved"""
    # Estimate $5 saved per home-cooked meal vs eating out
    meals = len(st.session_state.get('saved_recipes', []))
    return meals * 5

def calculate_food_waste_prevented() -> float:
    """Calculate estimated food waste prevented"""
    # Estimate 0.5 lbs saved per meal
    meals = len(st.session_state.get('saved_recipes', []))
    return meals * 0.5

def get_community_rank() -> int:
    """Get user's rank in community"""
    # In production, query database for actual rank
    # For now, return mock rank based on points
    points = st.session_state.get('user_points', 0)
    
    if points >= 5000:
        return random.randint(1, 50)
    elif points >= 2000:
        return random.randint(51, 200)
    elif points >= 1000:
        return random.randint(201, 500)
    elif points >= 500:
        return random.randint(501, 1000)
    else:
        return random.randint(1001, 5000)

def get_next_milestone() -> Dict:
    """Get the next milestone for the user"""
    current_points = st.session_state.get('user_points', 0)
    
    milestones = [
        {'points': 100, 'reward': 'Unlock recipe filters'},
        {'points': 250, 'reward': 'Custom meal preferences'},
        {'points': 500, 'reward': 'Priority support'},
        {'points': 1000, 'reward': 'Beta features access'},
        {'points': 2000, 'reward': 'VIP community status'},
        {'points': 5000, 'reward': 'SnapChef Ambassador'}
    ]
    
    for milestone in milestones:
        if current_points < milestone['points']:
            return {
                'points_needed': milestone['points'] - current_points,
                'total_points': milestone['points'],
                'reward': milestone['reward'],
                'progress': current_points / milestone['points']
            }
    
    return {
        'points_needed': 0,
        'total_points': 10000,
        'reward': 'Legendary Status',
        'progress': 1.0
    }

def show_achievement_notification(achievement: Dict):
    """Display achievement notification"""
    st.success(f"🏆 Achievement Unlocked: {achievement['name']}!")
    st.info(f"{achievement['icon']} {achievement['description']}")
    st.balloons()
    
    # Award points
    if 'points' in achievement:
        award_points('achievement', achievement['points'])