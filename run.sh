#!/bin/bash

# SnapChef Development Runner Script

echo "🍳 Starting SnapChef Development Server..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found! Copying from .env.example..."
    cp .env.example .env
    echo "📝 Please edit .env with your API keys before continuing."
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# Check for required environment variables
if [ -z "$XAI_API_KEY" ] || [ "$XAI_API_KEY" = "your_xai_api_key_here" ]; then
    echo "❌ Error: XAI_API_KEY not set in .env file"
    echo "Please add your xAI API key to continue."
    exit 1
fi

# Create necessary directories
mkdir -p uploads/recipe_photos
mkdir -p uploads/recipe_videos
mkdir -p .streamlit

# Install dependencies if needed
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install/update dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Initialize database
echo "🗄️  Initializing database..."
python -c "from utils.database import init_db; init_db()"

# Run the app
echo "🚀 Launching SnapChef on http://localhost:8501"
streamlit run app.py