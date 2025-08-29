#!/usr/bin/env python3

import cairosvg
from PIL import Image
import io
import os

# Path to the SVG and output directory
svg_path = "chef_hat_icon.svg"
output_dir = "SnapChef/Design/Assets.xcassets/AppIcon.appiconset"

# Icon sizes needed (filename: actual_pixel_size)
icon_sizes = {
    "icon_20x20@2x.png": 40,
    "icon_20x20@3x.png": 60,
    "icon_29x29@2x.png": 58,
    "icon_29x29@3x.png": 87,
    "icon_40x40@2x.png": 80,
    "icon_40x40@3x.png": 120,
    "icon_60x60@2x.png": 120,
    "icon_60x60@3x.png": 180,
    "icon_20x20@1x.png": 20,
    "icon_20x20@2x-ipad.png": 40,
    "icon_29x29@1x.png": 29,
    "icon_29x29@2x-ipad.png": 58,
    "icon_40x40@1x.png": 40,
    "icon_40x40@2x-ipad.png": 80,
    "icon_76x76@1x.png": 76,
    "icon_76x76@2x.png": 152,
    "icon_83.5x83.5@2x.png": 167,
    "icon_1024x1024.png": 1024
}

print(f"Generating app icons from {svg_path}...")

# Read the SVG file
with open(svg_path, 'r') as f:
    svg_content = f.read()

# Generate each icon size
for filename, size in icon_sizes.items():
    output_path = os.path.join(output_dir, filename)
    
    print(f"Generating {filename} ({size}x{size})...")
    
    # Convert SVG to PNG at the target size
    png_data = cairosvg.svg2png(
        bytestring=svg_content.encode('utf-8'),
        output_width=size,
        output_height=size
    )
    
    # Open with PIL for any additional processing
    img = Image.open(io.BytesIO(png_data))
    
    # Ensure it's in RGBA mode
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Save the PNG
    img.save(output_path, 'PNG', optimize=True)
    print(f"  ✓ Saved to {output_path}")

print(f"\n✅ Successfully generated {len(icon_sizes)} app icons!")
