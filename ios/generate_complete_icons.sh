#!/bin/bash

# Complete iOS app icon generation script with all sizes
# Usage: ./generate_complete_icons.sh source_image.jpg

SOURCE_IMAGE=$1
OUTPUT_DIR="SnapChef/Design/Assets.xcassets/AppIcon.appiconset"

if [ -z "$SOURCE_IMAGE" ]; then
    echo "Usage: ./generate_complete_icons.sh source_image.jpg"
    exit 1
fi

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: Source image not found at $SOURCE_IMAGE"
    exit 1
fi

echo "Generating complete app icon set from $SOURCE_IMAGE..."

# iPhone Notification icons
echo "Generating iPhone notification icons..."
magick "$SOURCE_IMAGE" -resize 40x40 "$OUTPUT_DIR/icon_20x20@2x.png"
magick "$SOURCE_IMAGE" -resize 60x60 "$OUTPUT_DIR/icon_20x20@3x.png"

# iPhone Settings icons
echo "Generating iPhone settings icons..."
magick "$SOURCE_IMAGE" -resize 58x58 "$OUTPUT_DIR/icon_29x29@2x.png"
magick "$SOURCE_IMAGE" -resize 87x87 "$OUTPUT_DIR/icon_29x29@3x.png"

# iPhone Spotlight icons
echo "Generating iPhone spotlight icons..."
magick "$SOURCE_IMAGE" -resize 80x80 "$OUTPUT_DIR/icon_40x40@2x.png"
magick "$SOURCE_IMAGE" -resize 120x120 "$OUTPUT_DIR/icon_40x40@3x.png"

# iPhone App icons
echo "Generating iPhone app icons..."
magick "$SOURCE_IMAGE" -resize 120x120 "$OUTPUT_DIR/icon_60x60@2x.png"
magick "$SOURCE_IMAGE" -resize 180x180 "$OUTPUT_DIR/icon_60x60@3x.png"

# iPad icons
echo "Generating iPad icons..."
magick "$SOURCE_IMAGE" -resize 20x20 "$OUTPUT_DIR/icon_20x20@1x.png"
magick "$SOURCE_IMAGE" -resize 40x40 "$OUTPUT_DIR/icon_20x20@2x-ipad.png"
magick "$SOURCE_IMAGE" -resize 29x29 "$OUTPUT_DIR/icon_29x29@1x.png"
magick "$SOURCE_IMAGE" -resize 58x58 "$OUTPUT_DIR/icon_29x29@2x-ipad.png"
magick "$SOURCE_IMAGE" -resize 40x40 "$OUTPUT_DIR/icon_40x40@1x.png"
magick "$SOURCE_IMAGE" -resize 80x80 "$OUTPUT_DIR/icon_40x40@2x-ipad.png"
magick "$SOURCE_IMAGE" -resize 76x76 "$OUTPUT_DIR/icon_76x76@1x.png"
magick "$SOURCE_IMAGE" -resize 152x152 "$OUTPUT_DIR/icon_76x76@2x.png"
magick "$SOURCE_IMAGE" -resize 167x167 "$OUTPUT_DIR/icon_83.5x83.5@2x.png"

# App Store icon
echo "Generating App Store icon..."
magick "$SOURCE_IMAGE" -resize 1024x1024 "$OUTPUT_DIR/icon_1024x1024.png"

echo "✅ Complete app icon set generated successfully!"
echo ""
echo "Generated icons:"
echo "  iPhone Notification: 20x20@2x, 20x20@3x"
echo "  iPhone Settings: 29x29@2x, 29x29@3x"
echo "  iPhone Spotlight: 40x40@2x, 40x40@3x"
echo "  iPhone App: 60x60@2x, 60x60@3x"
echo "  iPad Notification: 20x20@1x, 20x20@2x"
echo "  iPad Settings: 29x29@1x, 29x29@2x"
echo "  iPad Spotlight: 40x40@1x, 40x40@2x"
echo "  iPad App: 76x76@1x, 76x76@2x, 83.5x83.5@2x"
echo "  App Store: 1024x1024"