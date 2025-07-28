import os
from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, Boolean, JSON, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from sqlalchemy.sql import func

Base = declarative_base()

# Database URL from environment
DATABASE_URL = os.getenv('DATABASE_URL', 'sqlite:///snapchef.db')

# Create engine
engine = create_engine(DATABASE_URL, echo=False)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

class User(Base):
    __tablename__ = 'users'
    
    id = Column(Integer, primary_key=True)
    username = Column(String(50), unique=True, nullable=False)
    email = Column(String(100), unique=True, nullable=False)
    name = Column(String(100))
    password_hash = Column(String(255))
    subscription_tier = Column(String(20), default='free')
    stripe_customer_id = Column(String(100))
    points = Column(Integer, default=0)
    cooking_streak = Column(Integer, default=0)
    last_cook_date = Column(DateTime)
    dietary_preferences = Column(JSON, default=list)
    referral_code = Column(String(20), unique=True)
    referred_by = Column(String(20))
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())
    
    # Relationships
    recipes = relationship("Recipe", back_populates="user")
    challenges = relationship("ChallengeParticipation", back_populates="user")
    badges = relationship("UserBadge", back_populates="user")
    votes = relationship("Vote", back_populates="user")

class Recipe(Base):
    __tablename__ = 'recipes'
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    ingredients = Column(JSON)
    meal_name = Column(String(200))
    meal_description = Column(String(1000))
    recipe_steps = Column(JSON)
    nutritional_info = Column(JSON)
    image_url = Column(String(500))
    is_shared = Column(Boolean, default=False)
    share_count = Column(Integer, default=0)
    vote_count = Column(Integer, default=0)
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="recipes")
    votes = relationship("Vote", back_populates="recipe")

class Challenge(Base):
    __tablename__ = 'challenges'
    
    id = Column(Integer, primary_key=True)
    name = Column(String(200))
    description = Column(String(1000))
    challenge_type = Column(String(50))  # daily, weekly, special
    start_date = Column(DateTime)
    end_date = Column(DateTime)
    points_reward = Column(Integer)
    badge_reward = Column(String(100))
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    participants = relationship("ChallengeParticipation", back_populates="challenge")

class ChallengeParticipation(Base):
    __tablename__ = 'challenge_participations'
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    challenge_id = Column(Integer, ForeignKey('challenges.id'))
    recipe_id = Column(Integer, ForeignKey('recipes.id'))
    completed = Column(Boolean, default=False)
    completion_date = Column(DateTime)
    
    # Relationships
    user = relationship("User", back_populates="challenges")
    challenge = relationship("Challenge", back_populates="participants")

class Badge(Base):
    __tablename__ = 'badges'
    
    id = Column(Integer, primary_key=True)
    name = Column(String(100), unique=True)
    description = Column(String(500))
    icon = Column(String(50))
    points_required = Column(Integer)
    special_condition = Column(String(200))

class UserBadge(Base):
    __tablename__ = 'user_badges'
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    badge_id = Column(Integer, ForeignKey('badges.id'))
    earned_date = Column(DateTime, server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="badges")

class Vote(Base):
    __tablename__ = 'votes'
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    recipe_id = Column(Integer, ForeignKey('recipes.id'))
    vote_type = Column(String(20))  # upvote, downvote
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="votes")
    recipe = relationship("Recipe", back_populates="votes")

class DailyUsage(Base):
    __tablename__ = 'daily_usage'
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'))
    date = Column(DateTime, default=datetime.now().date())
    meals_generated = Column(Integer, default=0)

def init_db():
    """Initialize database tables"""
    Base.metadata.create_all(bind=engine)

def get_db():
    """Get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_user(username, email, name, password_hash, referral_code):
    """Create a new user"""
    db = SessionLocal()
    try:
        user = User(
            username=username,
            email=email,
            name=name,
            password_hash=password_hash,
            referral_code=referral_code
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user
    finally:
        db.close()

def get_user_by_username(username):
    """Get user by username"""
    db = SessionLocal()
    try:
        return db.query(User).filter(User.username == username).first()
    finally:
        db.close()

def update_user_points(user_id, points_to_add):
    """Update user points"""
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            user.points += points_to_add
            db.commit()
            return user.points
    finally:
        db.close()

def check_and_update_daily_usage(user_id):
    """Check and update daily usage"""
    db = SessionLocal()
    try:
        today = datetime.now().date()
        usage = db.query(DailyUsage).filter(
            DailyUsage.user_id == user_id,
            DailyUsage.date == today
        ).first()
        
        if not usage:
            usage = DailyUsage(user_id=user_id, date=today, meals_generated=0)
            db.add(usage)
        
        usage.meals_generated += 1
        db.commit()
        return usage.meals_generated
    finally:
        db.close()