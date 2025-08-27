#!/bin/bash

# Script to generate all required iOS app icon sizes from a source image
# Usage: ./generate_app_icons.sh source_image.png

SOURCE_IMAGE=$1
OUTPUT_DIR="SnapChef/Design/Assets.xcassets/AppIcon.appiconset"

if [ -z "$SOURCE_IMAGE" ]; then
    echo "Usage: ./generate_app_icons.sh source_image.png"
    echo "Please provide the path to your source image (should be at least 1024x1024)"
    exit 1
fi

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: Source image not found at $SOURCE_IMAGE"
    exit 1
fi

echo "Generating app icons from $SOURCE_IMAGE..."

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "ImageMagick is not installed. Installing via Homebrew..."
    brew install imagemagick
fi

# Generate all required sizes
echo "Generating icon_20x20@2x.png (40x40)..."
convert "$SOURCE_IMAGE" -resize 40x40 "$OUTPUT_DIR/icon_20x20@2x.png"

echo "Generating icon_20x20@3x.png (60x60)..."
convert "$SOURCE_IMAGE" -resize 60x60 "$OUTPUT_DIR/icon_20x20@3x.png"

echo "Generating icon_29x29@2x.png (58x58)..."
convert "$SOURCE_IMAGE" -resize 58x58 "$OUTPUT_DIR/icon_29x29@2x.png"

echo "Generating icon_29x29@3x.png (87x87)..."
convert "$SOURCE_IMAGE" -resize 87x87 "$OUTPUT_DIR/icon_29x29@3x.png"

echo "Generating icon_40x40@2x.png (80x80)..."
convert "$SOURCE_IMAGE" -resize 80x80 "$OUTPUT_DIR/icon_40x40@2x.png"

echo "Generating icon_40x40@3x.png (120x120)..."
convert "$SOURCE_IMAGE" -resize 120x120 "$OUTPUT_DIR/icon_40x40@3x.png"

echo "Generating icon_60x60@2x.png (120x120)..."
convert "$SOURCE_IMAGE" -resize 120x120 "$OUTPUT_DIR/icon_60x60@2x.png"

echo "Generating icon_60x60@3x.png (180x180)..."
convert "$SOURCE_IMAGE" -resize 180x180 "$OUTPUT_DIR/icon_60x60@3x.png"

echo "Generating icon_76x76@2x.png (152x152)..."
convert "$SOURCE_IMAGE" -resize 152x152 "$OUTPUT_DIR/icon_76x76@2x.png"

echo "Generating icon_1024x1024.png (1024x1024)..."
convert "$SOURCE_IMAGE" -resize 1024x1024 "$OUTPUT_DIR/icon_1024x1024.png"

echo "✅ All app icons generated successfully!"
echo "The icons have been saved to: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Build the app in Xcode to see the new icon"
echo "2. Clean build folder if the icon doesn't update (Shift+Cmd+K)"