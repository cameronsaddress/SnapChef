#!/usr/bin/env python3
"""
iOS App Icon Generator
Reads Contents.json from AppIcon.appiconset and generates all required icon sizes
"""

import json
import os
import sys
import subprocess
from pathlib import Path
from PIL import Image
import cairosvg
import io

def svg_to_pil_image(svg_path, width, height):
    """Convert SVG to PIL Image at specified size"""
    png_data = cairosvg.svg2png(url=str(svg_path), output_width=width, output_height=height)
    return Image.open(io.BytesIO(png_data))

def generate_icons(source_svg, contents_json_path):
    """Generate all iOS app icons based on Contents.json"""
    
    # Read Contents.json
    with open(contents_json_path, 'r') as f:
        contents = json.load(f)
    
    # Get the directory where icons should be saved
    icon_dir = Path(contents_json_path).parent
    
    # Process each icon entry
    for image_info in contents.get('images', []):
        filename = image_info.get('filename')
        if not filename:
            continue
            
        # Parse size from the image info or filename
        size_str = image_info.get('size', '')
        scale_str = image_info.get('scale', '1x')
        
        if size_str:
            # Parse size like "20x20" or "83.5x83.5"
            width = float(size_str.split('x')[0])
            height = float(size_str.split('x')[1] if 'x' in size_str else size_str.split('x')[0])
            
            # Parse scale like "2x" or "3x"
            scale = int(scale_str.replace('x', ''))
            
            # Calculate actual pixel dimensions
            pixel_width = int(width * scale)
            pixel_height = int(height * scale)
        else:
            # For ios-marketing or other special cases, parse from filename
            if '1024' in filename:
                pixel_width = pixel_height = 1024
            else:
                continue
        
        print(f"Generating {filename}: {pixel_width}x{pixel_height}px")
        
        # Generate the icon
        output_path = icon_dir / filename
        
        # Convert SVG to PNG at the required size
        img = svg_to_pil_image(source_svg, pixel_width, pixel_height)
        
        # Special handling for App Store icon (1024x1024) - no alpha channel
        if pixel_width == 1024 and pixel_height == 1024:
            # Remove alpha channel for App Store
            if img.mode in ('RGBA', 'LA'):
                background = Image.new('RGB', img.size, (255, 255, 255))
                background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
                img = background
        
        # Save the icon
        img.save(output_path, 'PNG', optimize=True)
    
    print(f"\n✅ Generated all icons in {icon_dir}")

def main():
    # Check if Pillow and cairosvg are installed
    try:
        import PIL
        import cairosvg
    except ImportError:
        print("Installing required packages...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow", "cairosvg"])
        print("Packages installed. Please run the script again.")
        sys.exit(0)
    
    # Paths
    source_svg = Path(__file__).parent / "chef_hat_icon.svg"
    contents_json = Path(__file__).parent / "SnapChef/Design/Assets.xcassets/AppIcon.appiconset/Contents.json"
    
    if not source_svg.exists():
        print(f"Error: Source SVG not found at {source_svg}")
        sys.exit(1)
    
    if not contents_json.exists():
        print(f"Error: Contents.json not found at {contents_json}")
        sys.exit(1)
    
    generate_icons(source_svg, contents_json)

if __name__ == "__main__":
    main()