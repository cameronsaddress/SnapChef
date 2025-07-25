# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
SnapChef is a viral web app that transforms fridge/pantry photos into personalized recipes using AI, with built-in social sharing and gamification features.

## Key Commands

### Development
```bash
# Install dependencies
pip install -r requirements.txt

# Run the app locally
streamlit run main.py

# Run tests
pytest tests/

# Run specific test
pytest tests/test_api.py::test_grok_integration
```

### Environment Setup
```bash
# Create .env file with required variables
XAI_API_KEY=your_xai_api_key
STRIPE_API_KEY=your_stripe_key
STRIPE_WEBHOOK_SECRET=your_webhook_secret
DATABASE_URL=sqlite:///snapchef.db
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
S3_BUCKET_NAME=snapchef-uploads
```

## Architecture

### Core Components
1. **main.py** - Entry point, handles routing and session management
2. **pages/** - Modular Streamlit pages (home, upload, recipes, challenges, profile)
3. **utils/** - Shared utilities:
   - `api.py` - Grok 4 API integration
   - `database.py` - SQLAlchemy models and queries
   - `storage.py` - S3/Firebase file handling
   - `auth.py` - User authentication
   - `social.py` - Social media sharing
   - `gamification.py` - Points, badges, challenges

### Data Flow
1. User uploads photo → Base64 encoding → Grok API for ingredient detection
2. Ingredient list → Grok API for meal generation with dietary preferences
3. Generated meals → Display with share options → Track engagement

### Virality Hooks
- Post-recipe share prompts with FOMO messaging
- Auto-generated TikTok/Instagram content
- Daily challenges with leaderboards
- Referral system with point rewards
- Cooking streaks and badges

### Subscription Tiers
- Free: 1 meal/day
- Basic ($4.99/mo): 2 meals/day
- Premium ($9.99/mo): Unlimited + exclusive features

## Testing Strategy
- Unit tests for API mocking and core logic
- Integration tests for user flows
- Performance tests for image processing
- Security tests for file uploads and auth