import streamlit as st
import streamlit_authenticator as stauth
import yaml
from yaml.loader import SafeLoader
import os
import secrets
from utils.database import create_user, get_user_by_username

def init_auth():
    """Initialize authentication system"""
    # For development, we'll use a simple config
    # In production, this should be stored in a database
    
    # Check if config file exists
    config_path = '.streamlit/auth_config.yaml'
    
    if not os.path.exists(config_path):
        # Create default config
        os.makedirs('.streamlit', exist_ok=True)
        default_config = {
            'credentials': {
                'usernames': {
                    'demo_user': {
                        'email': 'demo@snapchef.com',
                        'name': 'Demo User',
                        'password': '$2b$12$iWXWnWQn5FY3WYGmFkwJr.YfHKCrQKHXWQz5YzYXsCh5TcCr7fYPa'  # password: demo123
                    }
                }
            },
            'cookie': {
                'name': 'snapchef_auth',
                'key': secrets.token_urlsafe(32),
                'expiry_days': 30
            },
            'preauthorized': {
                'emails': []
            }
        }
        
        with open(config_path, 'w') as file:
            yaml.dump(default_config, file)
    
    # Load config
    with open(config_path) as file:
        config = yaml.load(file, Loader=SafeLoader)
    
    authenticator = stauth.Authenticate(
        config['credentials'],
        config['cookie']['name'],
        config['cookie']['key'],
        config['cookie']['expiry_days']
    )
    
    return authenticator

def check_auth():
    """Check if user is authenticated"""
    return st.session_state.get('authentication_status', False)

def generate_referral_code(username):
    """Generate unique referral code for user"""
    return f"{username[:3].upper()}{secrets.token_urlsafe(4)[:4].upper()}"

def process_referral(referral_code, new_user_id):
    """Process referral and award points"""
    from utils.database import SessionLocal, User, update_user_points
    
    db = SessionLocal()
    try:
        # Find user with referral code
        referrer = db.query(User).filter(User.referral_code == referral_code).first()
        if referrer:
            # Award points to referrer
            update_user_points(referrer.id, 50)
            
            # Update new user's referred_by field
            new_user = db.query(User).filter(User.id == new_user_id).first()
            if new_user:
                new_user.referred_by = referral_code
                db.commit()
            
            return True
    finally:
        db.close()
    
    return False

def update_subscription(user_id, tier):
    """Update user subscription tier"""
    from utils.database import SessionLocal, User
    
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            user.subscription_tier = tier
            db.commit()
            return True
    finally:
        db.close()
    
    return False