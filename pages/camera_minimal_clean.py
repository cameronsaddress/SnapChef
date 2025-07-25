import streamlit as st
from streamlit_extras.let_it_rain import rain
import time
from PIL import Image
import io
from utils.api import encode_image_to_base64, detect_ingredients, generate_meals
from utils.session import update_streak, add_points

def show_camera():
    # Apply gradient background and minimal styling
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        /* Gradient background */
        .stApp {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        
        /* Remove top padding */
        .main .block-container {
            padding-top: 2rem !important;
            max-width: 600px !important;
            margin: 0 auto !important;
        }
        
        /* Back button styling */
        .stButton > button {
            background: rgba(255, 255, 255, 0.2) !important;
            border: 2px solid rgba(255, 255, 255, 0.3) !important;
            color: white !important;
            font-weight: 600 !important;
            backdrop-filter: blur(10px) !important;
        }
        
        .stButton > button:hover {
            background: rgba(255, 255, 255, 0.3) !important;
        }
        
        /* Progress bar styling */
        .stProgress > div > div > div > div {
            background: linear-gradient(90deg, #25F4EE 0%, #FE2C55 100%) !important;
        }
        
        /* Camera/File uploader container */
        .stCameraInput, .stFileUploader {
            margin: 4rem auto;
            max-width: 500px;
        }
        
        /* Status text */
        h3 {
            text-align: center;
            color: white !important;
            margin: 2rem 0 !important;
        }
        
        .status-text {
            text-align: center;
            color: rgba(255, 255, 255, 0.9);
            font-size: 1.1rem;
            margin: 1rem 0;
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Initialize states
    if 'photo_taken' not in st.session_state:
        st.session_state.photo_taken = False
    if 'processing' not in st.session_state:
        st.session_state.processing = False
    
    # Back button
    if st.button("← Back", key="back_btn"):
        st.session_state.photo_taken = False
        st.session_state.processing = False
        st.session_state.current_page = 'landing'
        st.rerun()
    
    # Just show the camera input - no title or tabs
    photo = st.camera_input("Take a photo of your fridge")
    
    if photo and not st.session_state.photo_taken:
        st.session_state.photo = photo
        st.session_state.photo_taken = True
        st.session_state.processing = True
        st.rerun()
    
    # Process photo if taken
    if st.session_state.processing:
        process_photo_with_progress()

def process_photo_with_progress():
    """Process photo with progress bar"""
    
    # Progress bar
    progress_bar = st.progress(0)
    status_placeholder = st.empty()
    
    try:
        # Step 1: Process image
        status_placeholder.markdown('<p class="status-text">Processing image...</p>', unsafe_allow_html=True)
        progress_bar.progress(10)
        time.sleep(0.5)
        
        # Get photo bytes
        photo_bytes = st.session_state.photo.getvalue()
        
        # Optimize image
        img = Image.open(io.BytesIO(photo_bytes))
        max_size = (1920, 1920)
        if img.size[0] > max_size[0] or img.size[1] > max_size[1]:
            img.thumbnail(max_size, Image.Resampling.LANCZOS)
            img_byte_arr = io.BytesIO()
            img.save(img_byte_arr, format=img.format or 'JPEG', quality=85)
            photo_bytes = img_byte_arr.getvalue()
        
        progress_bar.progress(25)
        
        # Step 2: Detect ingredients
        status_placeholder.markdown('<p class="status-text">Detecting ingredients...</p>', unsafe_allow_html=True)
        photo_base64 = encode_image_to_base64(photo_bytes)
        progress_bar.progress(40)
        time.sleep(0.5)
        
        ingredients = detect_ingredients(photo_base64)
        progress_bar.progress(60)
        
        if ingredients:
            status_placeholder.markdown(f'<p class="status-text">Found {len(ingredients)} ingredients!</p>', unsafe_allow_html=True)
            time.sleep(1)
        
        # Step 3: Generate recipes
        status_placeholder.markdown('<p class="status-text">Creating personalized recipes...</p>', unsafe_allow_html=True)
        progress_bar.progress(80)
        
        recipes = generate_meals(ingredients, st.session_state.get('dietary_preferences', []))
        progress_bar.progress(100)
        
        status_placeholder.markdown('<p class="status-text">Recipes ready!</p>', unsafe_allow_html=True)
        time.sleep(0.5)
        
        # Store results
        st.session_state.detected_ingredients = ingredients
        st.session_state.generated_recipes = recipes
        st.session_state.processing_complete = True
        
        # Update stats
        update_streak()
        add_points(10, "Generated recipes")
        
        # Celebration
        rain(emoji="✨", font_size=20, falling_speed=5, animation_length=1)
        
        # Navigate to results
        time.sleep(1)
        st.session_state.current_page = 'results'
        st.rerun()
        
    except Exception as e:
        progress_bar.empty()
        status_placeholder.empty()
        st.error(f"❌ Oops! Something went wrong: {str(e)}")
        
        if st.button("🔄 Try Again", use_container_width=True):
            st.session_state.photo_taken = False
            st.session_state.processing = False
            st.session_state.photo = None
            st.rerun()