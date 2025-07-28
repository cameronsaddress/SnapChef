"""
Test images for development
"""
import base64
from io import BytesIO
from PIL import Image
try:
    import requests
except ImportError:
    requests = None

def get_test_fridge_image():
    """
    Get the test fridge image from assets directory
    """
    import os
    
    # Path to the fridge.jpg in assets directory
    current_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    image_path = os.path.join(current_dir, 'assets', 'fridge.jpg')
    
    try:
        # Read the image file
        with open(image_path, 'rb') as f:
            return f.read()
    except FileNotFoundError:
        # Fallback: Return a simple test image if file not found
        img = Image.new('RGB', (400, 300), color='white')
        
        # Save to bytes
        img_byte_arr = BytesIO()
        img.save(img_byte_arr, format='JPEG')
        img_byte_arr = img_byte_arr.getvalue()
        
        return img_byte_arr