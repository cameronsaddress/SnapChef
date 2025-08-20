#!/bin/bash

# SnapChef Social Features Testing Script
# This script helps set up multiple simulators for testing social features

echo "🧑‍🍳 SnapChef Social Testing Setup"
echo "================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to create and boot simulator
create_simulator() {
    local name=$1
    local device_type=${2:-"iPhone 16 Pro"}
    
    echo -e "${YELLOW}Creating simulator: $name${NC}"
    
    # Check if simulator exists
    if xcrun simctl list devices | grep -q "$name"; then
        echo -e "${GREEN}Simulator $name already exists${NC}"
        # Get the UDID
        UDID=$(xcrun simctl list devices | grep "$name" | grep -E -o '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
    else
        # Create new simulator
        UDID=$(xcrun simctl create "$name" "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro" "com.apple.CoreSimulator.SimRuntime.iOS-18-0")
        echo -e "${GREEN}Created simulator $name with UDID: $UDID${NC}"
    fi
    
    # Boot the simulator
    echo "Booting $name..."
    xcrun simctl boot $UDID 2>/dev/null || echo "Simulator already booted"
    
    # Open Simulator app for this device
    open -a Simulator --args -CurrentDeviceUDID $UDID
    
    return 0
}

# Function to install app on simulator
install_app() {
    local udid=$1
    local app_path=$2
    
    if [ -f "$app_path" ]; then
        echo -e "${YELLOW}Installing SnapChef on simulator $udid${NC}"
        xcrun simctl install $udid "$app_path"
        echo -e "${GREEN}Installation complete${NC}"
    else
        echo -e "${RED}App not found at $app_path${NC}"
        echo "Please build the app first with:"
        echo "xcodebuild -scheme SnapChef -configuration Debug -derivedDataPath build"
    fi
}

# Main script
echo ""
echo "1️⃣  Setting up test simulators..."
echo ""

# Create 3 test simulators
create_simulator "SnapChef Chef 1"
sleep 2
create_simulator "SnapChef Chef 2"
sleep 2
create_simulator "SnapChef Chef 3"

echo ""
echo "2️⃣  Simulators created and booted!"
echo ""
echo "3️⃣  Next steps:"
echo "   1. Sign into each simulator with different Apple IDs:"
echo "      - Simulator 1: Settings → Sign in with Apple ID #1"
echo "      - Simulator 2: Settings → Sign in with Apple ID #2"
echo "      - Simulator 3: Settings → Sign in with Apple ID #3"
echo ""
echo "   2. Build and run SnapChef on each simulator:"
echo "      - In Xcode, select each simulator as destination"
echo "      - Press Cmd+R to build and run"
echo ""
echo "   3. Create test users:"
echo "      - Chef 1: Username 'mainchef'"
echo "      - Chef 2: Username 'friendchef'"
echo "      - Chef 3: Username 'newchef'"
echo ""
echo "4️⃣  Test social interactions:"
echo "   - Follow each other"
echo "   - Create and share recipes"
echo "   - Like and comment on recipes"
echo "   - Check activity feeds"
echo ""
echo -e "${GREEN}✅ Setup complete! Happy testing!${NC}"

# Optional: Launch SnapChef directly if built
# Uncomment these lines if you have the app built
# APP_PATH="~/Library/Developer/Xcode/DerivedData/SnapChef-*/Build/Products/Debug-iphonesimulator/SnapChef.app"
# for UDID in $(xcrun simctl list devices | grep "SnapChef Chef" | grep -E -o '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'); do
#     install_app $UDID $APP_PATH
#     xcrun simctl launch $UDID com.snapchef.app
# done