#!/usr/bin/env python3
"""
Generate app icon for SnapChef
Creates a simple gradient icon with the app initial
"""

from PIL import Image, ImageDraw, ImageFont
import json
import os

def create_gradient(size, color1, color2):
    """Create a gradient background"""
    img = Image.new('RGB', (size, size), color1)
    draw = ImageDraw.Draw(img)
    
    for i in range(size):
        # Calculate color for this line
        ratio = i / size
        r = int(color1[0] * (1 - ratio) + color2[0] * ratio)
        g = int(color1[1] * (1 - ratio) + color2[1] * ratio)
        b = int(color1[2] * (1 - ratio) + color2[2] * ratio)
        
        draw.line([(0, i), (size, i)], fill=(r, g, b))
    
    return img

def create_app_icon(size):
    """Create app icon with gradient and S letter"""
    # Colors from app
    purple1 = (102, 126, 234)  # #667eea
    purple2 = (118, 75, 162)   # #764ba2
    
    # Create gradient background
    img = create_gradient(size, purple1, purple2)
    draw = ImageDraw.Draw(img)
    
    # Add rounded corners mask
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = int(size * 0.225)  # iOS standard corner radius
    mask_draw.rounded_rectangle([(0, 0), (size, size)], radius=corner_radius, fill=255)
    
    # Apply mask
    output = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    output.paste(img, (0, 0))
    output.putalpha(mask)
    
    # Draw S letter
    draw = ImageDraw.Draw(output)
    
    # Try to use a nice font, fall back to default if not available
    font_size = int(size * 0.6)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        font = ImageFont.load_default()
    
    # Draw the S
    text = "S"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    position = ((size - text_width) // 2, (size - text_height) // 2 - int(size * 0.05))
    
    # Add subtle shadow
    shadow_offset = int(size * 0.02)
    draw.text((position[0] + shadow_offset, position[1] + shadow_offset), text, 
              font=font, fill=(0, 0, 0, 80))
    
    # Draw main text
    draw.text(position, text, font=font, fill=(255, 255, 255, 255))
    
    return output

# Icon sizes required for iOS
icon_sizes = [
    (20, 2), (20, 3),  # Notification
    (29, 2), (29, 3),  # Settings
    (40, 2), (40, 3),  # Spotlight
    (60, 2), (60, 3),  # App
    (1024, 1),         # App Store
]

# Create output directory
output_dir = "SnapChef/Design/Assets.xcassets/AppIcon.appiconset"
os.makedirs(output_dir, exist_ok=True)

# Generate icons
contents = {
    "images": [],
    "info": {
        "author": "xcode",
        "version": 1
    }
}

for base_size, scale in icon_sizes:
    size = base_size * scale
    
    # Create icon
    icon = create_app_icon(size)
    
    # Save icon
    filename = f"icon_{base_size}x{base_size}@{scale}x.png"
    if base_size == 1024:
        filename = "icon_1024x1024.png"
    
    filepath = os.path.join(output_dir, filename)
    icon.save(filepath, "PNG")
    
    # Add to contents.json
    image_entry = {
        "filename": filename,
        "idiom": "iphone" if base_size != 1024 else "ios-marketing",
        "scale": f"{scale}x" if base_size != 1024 else "1x",
        "size": f"{base_size}x{base_size}"
    }
    
    contents["images"].append(image_entry)
    
    print(f"Created {filename}")

# Save contents.json
with open(os.path.join(output_dir, "Contents.json"), "w") as f:
    json.dump(contents, f, indent=2)

print(f"\nApp icons generated successfully in {output_dir}")
print("Icons created with purple gradient and 'S' letter")