#!/bin/bash

# SnapChef iOS Build Script

echo "Building SnapChef iOS app..."

# Clean build folder
echo "Cleaning build folder..."
xcodebuild clean -project SnapChef.xcodeproj -scheme SnapChef

# Build for simulator
echo "Building for iOS Simulator..."
xcodebuild build \
    -project SnapChef.xcodeproj \
    -scheme SnapChef \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
    -configuration Debug

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
else
    echo "❌ Build failed!"
    exit 1
fi