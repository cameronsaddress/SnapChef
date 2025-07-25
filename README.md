# 🍳 SnapChef - Turn Your Fridge Into Delicious Meals!

SnapChef is a viral web app that transforms photos of your fridge/pantry into personalized recipes using AI, with built-in social sharing and gamification features.

## Features

- 📸 **Smart Ingredient Detection**: Upload a photo and AI identifies all ingredients
- 🍽️ **Personalized Recipes**: Get meal ideas based on what you have
- 🎮 **Gamification**: Points, badges, streaks, and challenges
- 📱 **Social Sharing**: One-tap sharing to TikTok, Instagram, and more
- 💰 **Freemium Model**: Free tier with paid upgrades
- 🏆 **Daily Challenges**: Community challenges with leaderboards

## Quick Start

1. Clone the repository:
```bash
git clone https://github.com/yourusername/snapchef.git
cd snapchef
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your API keys
```

4. Run the app:
```bash
streamlit run app.py
```

## Environment Variables

Create a `.env` file with:
```
XAI_API_KEY=your_xai_api_key
STRIPE_API_KEY=your_stripe_key
DATABASE_URL=sqlite:///snapchef.db
```

## Project Structure

```
snapchef/
├── main.py              # Entry point
├── pages/               # Streamlit pages
│   ├── home.py         # Landing page
│   ├── upload.py       # Photo upload & meal generation
│   ├── recipes.py      # Recipe management
│   ├── challenges.py   # Challenges & leaderboards
│   └── profile.py      # User profile & settings
├── utils/              # Core utilities
│   ├── api.py         # Grok 4 API integration
│   ├── database.py    # Database models
│   ├── auth.py        # Authentication
│   ├── social.py      # Social sharing
│   └── gamification.py # Points & badges
└── tests/             # Test suite
```

## Subscription Tiers

- **Free**: 1 meal/day
- **Basic ($4.99/mo)**: 2 meals/day + save recipes
- **Premium ($9.99/mo)**: Unlimited + exclusive features

## Development

Run tests:
```bash
pytest tests/
```

## Deployment

Deploy to Streamlit Cloud:
1. Push to GitHub
2. Connect to Streamlit Cloud
3. Set environment variables
4. Deploy!

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see LICENSE file for details