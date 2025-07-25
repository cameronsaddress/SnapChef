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
        
        /* Center content */
        h2 {
            text-align: center;
            color: white !important;
            margin-bottom: 2rem !important;
        }
        
        /* Mode toggle buttons */
        .stTabs [data-baseweb="tab-list"] {
            gap: 1rem;
            justify-content: center;
            background: transparent;
            border-bottom: none;
        }
        
        .stTabs [data-baseweb="tab"] {
            background: rgba(255, 255, 255, 0.1) !important;
            color: white !important;
            border-radius: 50px !important;
            padding: 0.75rem 2rem !important;
            border: 1px solid rgba(255, 255, 255, 0.2) !important;
        }
        
        .stTabs [aria-selected="true"] {
            background: rgba(255, 255, 255, 0.2) !important;
        }
        
        /* Progress bar styling */
        .stProgress > div > div > div > div {
            background: linear-gradient(90deg, #25F4EE 0%, #FE2C55 100%) !important;
        }
        
        /* Camera input styling */
        .stCameraInput {
            margin: 2rem auto;
            max-width: 600px;
        }
        
        /* File uploader styling */
        .stFileUploader {
            margin: 2rem auto;
            max-width: 600px;
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Initialize states
    if 'photo_taken' not in st.session_state:
        st.session_state.photo_taken = False
    if 'processing' not in st.session_state:
        st.session_state.processing = False
    
    # Back button
    col1, col2, col3 = st.columns([1, 10, 1])
    with col1:
        if st.button("← Back", key="back_btn"):
            st.session_state.photo_taken = False
            st.session_state.processing = False
            st.session_state.current_page = 'landing'
            st.rerun()
    
    # Title
    st.markdown("## 📸 Snap Your Fridge")
    
    # Tabs for Camera/Upload
    tab1, tab2 = st.tabs(["Camera", "Upload"])
    
    with tab1:
        # Camera input
        photo = st.camera_input("Take a photo of your fridge")
        
        if photo and not st.session_state.photo_taken:
            st.session_state.photo = photo
            st.session_state.photo_taken = True
            st.session_state.processing = True
            st.rerun()
    
    with tab2:
        # File uploader
        uploaded = st.file_uploader(
            "Upload a photo of your fridge",
            type=['jpg', 'jpeg', 'png', 'webp']
        )
        
        if uploaded and not st.session_state.photo_taken:
            st.session_state.photo = uploaded
            st.session_state.photo_taken = True
            st.session_state.processing = True
            st.rerun()
    
    # Process photo if taken
    if st.session_state.processing:
        process_photo_with_progress()

def process_photo_with_progress():
    """Process photo with progress bar"""
    
    # Show processing UI
    st.markdown("## 🎯 Analyzing Your Ingredients")
    
    # Progress bar
    progress_bar = st.progress(0)
    status_text = st.empty()
    
    try:
        # Step 1: Prepare image
        status_text.text("📸 Processing image...")
        progress_bar.progress(10)
        time.sleep(0.5)
        
        # Get photo bytes
        photo_bytes = st.session_state.photo.getvalue() if hasattr(st.session_state.photo, 'getvalue') else st.session_state.photo.read()
        
        # Optimize image
        img = Image.open(io.BytesIO(photo_bytes))
        max_size = (1920, 1920)
        if img.size[0] > max_size[0] or img.size[1] > max_size[1]:
            img.thumbnail(max_size, Image.Resampling.LANCZOS)
            img_byte_arr = io.BytesIO()
            img.save(img_byte_arr, format=img.format or 'JPEG', quality=85)
            photo_bytes = img_byte_arr.getvalue()
        
        progress_bar.progress(25)
        
        # Step 2: Encode image
        status_text.text("🔍 Detecting ingredients...")
        photo_base64 = encode_image_to_base64(photo_bytes)
        progress_bar.progress(40)
        time.sleep(0.5)
        
        # Step 3: Detect ingredients
        ingredients = detect_ingredients(photo_base64)
        progress_bar.progress(60)
        
        # Show detected ingredients
        if ingredients:
            status_text.text(f"✅ Found {len(ingredients)} ingredients!")
            time.sleep(1)
        
        # Step 4: Generate recipes
        status_text.text("👨‍🍳 Creating personalized recipes...")
        progress_bar.progress(80)
        
        recipes = generate_meals(ingredients, st.session_state.get('dietary_preferences', []))
        progress_bar.progress(100)
        
        # Success!
        status_text.text("✨ Recipes ready!")
        time.sleep(0.5)
        
        # Store results
        st.session_state.detected_ingredients = ingredients
        st.session_state.generated_recipes = recipes
        st.session_state.processing_complete = True
        
        # Update user stats
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
        status_text.empty()
        st.error(f"❌ Oops! Something went wrong: {str(e)}")
        
        col1, col2, col3 = st.columns([1, 1, 1])
        with col2:
            if st.button("🔄 Try Again", use_container_width=True):
                st.session_state.photo_taken = False
                st.session_state.processing = False
                st.session_state.photo = None
                st.rerun()