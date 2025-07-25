import streamlit as st
from datetime import datetime

def init_session_state():
    """Initialize session state variables"""
    defaults = {
        'authenticated': False,
        'username': None,
        'name': None,
        'user_id': None,
        'subscription_tier': 'free',
        'daily_meals_used': 0,
        'daily_meal_limit': 1,
        'user_points': 0,
        'cooking_streak': 0,
        'last_cook_date': None,
        'badges': [],
        'dietary_preferences': [],
        'ingredient_history': [],
        'generated_recipes': [],
        'shared_posts': [],
        'referral_code': None,
        'referred_by': None,
        'challenge_participation': [],
        'votes_cast': [],
        'votes_received': 0
    }
    
    for key, default_value in defaults.items():
        if key not in st.session_state:
            st.session_state[key] = default_value

def check_daily_limit():
    """Check if user has reached their daily meal generation limit"""
    tier_limits = {
        'free': 1,
        'basic': 2,
        'premium': float('inf')
    }
    
    limit = tier_limits.get(st.session_state.subscription_tier, 1)
    return st.session_state.daily_meals_used < limit

def increment_daily_usage():
    """Increment daily meal usage counter"""
    st.session_state.daily_meals_used += 1

def reset_daily_usage():
    """Reset daily usage counter (call this at midnight)"""
    st.session_state.daily_meals_used = 0

def update_streak():
    """Update cooking streak based on activity"""
    today = datetime.now().date()
    last_cook = st.session_state.last_cook_date
    
    if last_cook is None:
        st.session_state.cooking_streak = 1
    elif (today - last_cook).days == 1:
        st.session_state.cooking_streak += 1
    elif (today - last_cook).days > 1:
        st.session_state.cooking_streak = 1
    
    st.session_state.last_cook_date = today

def add_points(points, reason=""):
    """Add points to user's total"""
    st.session_state.user_points += points
    return st.session_state.user_points

def add_badge(badge_name, badge_icon):
    """Award a badge to the user"""
    badge = {'name': badge_name, 'icon': badge_icon, 'earned_date': datetime.now()}
    if badge_name not in [b['name'] for b in st.session_state.badges]:
        st.session_state.badges.append(badge)
        return True
    return False