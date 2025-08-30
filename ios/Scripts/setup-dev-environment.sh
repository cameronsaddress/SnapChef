#!/bin/bash

# SnapChef Development Environment Setup Script
# ==============================================

echo "🚀 Setting up SnapChef development environment..."
echo ""

# Check if we're in the right directory
if [ ! -f "SnapChef.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the ios directory"
    echo "   cd /path/to/snapchef/ios"
    echo "   ./Scripts/setup-dev-environment.sh"
    exit 1
fi

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ Created .env file"
    echo ""
    echo "⚠️  IMPORTANT: Edit .env and add your API keys"
    echo "   Required keys:"
    echo "   - SNAPCHEF_API_KEY"
    echo "   - TIKTOK_CLIENT_SECRET (optional)"
    echo ""
    # Open in default text editor
    if command -v code &> /dev/null; then
        code .env
    elif command -v nano &> /dev/null; then
        nano .env
    else
        echo "📝 Please open .env in your text editor"
    fi
else
    echo "✅ .env file already exists"
fi

# Check if API key is set
if [ -f .env ]; then
    if grep -q "your-api-key-here" .env; then
        echo ""
        echo "❌ Please update the API key in .env file"
        echo "   Replace 'your-api-key-here' with your actual API key"
        exit 1
    fi
fi

echo ""
echo "📱 Next steps:"
echo "1. Open SnapChef.xcodeproj in Xcode"
echo "2. Edit Scheme → Run → Arguments → Environment Variables"
echo "3. Add SNAPCHEF_API_KEY with your API key value"
echo "4. Build and run the project"
echo ""
echo "✅ Development environment setup complete!"
echo ""
echo "🔒 Security reminder:"
echo "   - Never commit .env or API keys to git"
echo "   - The .gitignore is configured to prevent this"
echo "   - Use different API keys for dev/staging/production"