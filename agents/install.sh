#!/bin/bash

# SnapChef AI Agents Installation Script
# This script installs the SnapChef agents to Claude Code

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Claude agents directory
CLAUDE_AGENTS_DIR="$HOME/.claude/agents"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🤖 SnapChef AI Agents Installer"
echo "================================"
echo ""

# Check if Claude agents directory exists
if [ ! -d "$CLAUDE_AGENTS_DIR" ]; then
    echo -e "${YELLOW}Creating Claude agents directory...${NC}"
    mkdir -p "$CLAUDE_AGENTS_DIR"
fi

# Categories to install
CATEGORIES=("engineering" "design" "marketing" "social-media" "testing" "product")

# Count total agents
TOTAL_AGENTS=0
for category in "${CATEGORIES[@]}"; do
    if [ -d "$SCRIPT_DIR/$category" ]; then
        count=$(find "$SCRIPT_DIR/$category" -name "*.md" -type f | wc -l)
        TOTAL_AGENTS=$((TOTAL_AGENTS + count))
    fi
done

echo "Found $TOTAL_AGENTS agents to install"
echo ""

# Install agents by category
INSTALLED=0
for category in "${CATEGORIES[@]}"; do
    if [ -d "$SCRIPT_DIR/$category" ]; then
        echo -e "${GREEN}Installing $category agents...${NC}"
        
        # Create category directory if it doesn't exist
        mkdir -p "$CLAUDE_AGENTS_DIR/$category"
        
        # Copy all .md files from this category
        for agent_file in "$SCRIPT_DIR/$category"/*.md; do
            if [ -f "$agent_file" ]; then
                agent_name=$(basename "$agent_file")
                cp "$agent_file" "$CLAUDE_AGENTS_DIR/$category/"
                echo "  ✓ Installed $category/$agent_name"
                INSTALLED=$((INSTALLED + 1))
            fi
        done
    fi
done

echo ""
echo -e "${GREEN}✨ Installation Complete!${NC}"
echo "Installed $INSTALLED agents to $CLAUDE_AGENTS_DIR"
echo ""

# List installed agents
echo "📦 Installed Agents:"
echo "-------------------"
for category in "${CATEGORIES[@]}"; do
    if [ -d "$CLAUDE_AGENTS_DIR/$category" ]; then
        echo ""
        echo "[$category]"
        for agent_file in "$CLAUDE_AGENTS_DIR/$category"/*.md; do
            if [ -f "$agent_file" ]; then
                agent_name=$(basename "$agent_file" .md)
                # Extract description from file
                description=$(grep "^description:" "$agent_file" | head -1 | cut -d':' -f2- | sed 's/^ //' | cut -d'\' -f1)
                echo "  • $agent_name"
            fi
        done
    fi
done

echo ""
echo "🔄 Next Steps:"
echo "-------------"
echo "1. Restart Claude Code for agents to become available"
echo "2. Agents will be automatically triggered based on your tasks"
echo "3. You can also explicitly request specific agents"
echo ""
echo "📚 For more information, see agents/README.md"
echo ""

# Optional: Show agent usage example
echo "💡 Example Usage:"
echo "----------------"
echo 'User: "I need to optimize our TikTok videos"'
echo 'Claude: "I'"'"'ll use the tiktok-specialist agent to help with that..."'
echo ""

# Check if running on macOS and offer to restart Claude Code
if [[ "$OSTYPE" == "darwin"* ]]; then
    read -p "Would you like to restart Claude Code now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Check if Claude Code is running
        if pgrep -x "Claude" > /dev/null; then
            echo "Restarting Claude Code..."
            killall "Claude" 2>/dev/null || true
            sleep 2
            open -a "Claude"
            echo -e "${GREEN}Claude Code restarted successfully!${NC}"
        else
            echo -e "${YELLOW}Claude Code is not currently running${NC}"
        fi
    fi
fi

echo ""
echo -e "${GREEN}🎉 Setup complete! Happy coding with your new AI agents!${NC}"