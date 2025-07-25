import streamlit as st
from streamlit_extras.let_it_rain import rain
import time
from PIL import Image
import io
from utils.api import encode_image_to_base64, detect_ingredients, generate_meals
from utils.session import update_streak, add_points

def show_camera():
    # Minimalist camera UI with gradient background
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        /* Gradient background matching landing page */
        .stApp {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        
        /* Remove all default padding and margins */
        .main > div {
            padding: 0 !important;
        }
        
        .block-container {
            padding: 1rem !important;
            max-width: 100% !important;
        }
        
        /* Hide default Streamlit elements */
        section[data-testid="stSidebar"] {
            display: none;
        }
        
        /* Back button styling */
        .back-btn {
            position: fixed;
            top: 20px;
            left: 20px;
            z-index: 100;
        }
        
        .back-btn button {
            background: rgba(255, 255, 255, 0.2) !important;
            border: 2px solid rgba(255, 255, 255, 0.3) !important;
            color: white !important;
            padding: 0.5rem 1.5rem !important;
            border-radius: 50px !important;
            font-weight: 600 !important;
            backdrop-filter: blur(10px) !important;
        }
        
        /* Camera container - full height */
        .camera-wrapper {
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            padding: 2rem;
            margin-top: -80px; /* Compensate for header space */
        }
        
        /* Mode toggle */
        .mode-toggle {
            margin-bottom: 2rem;
        }
        
        /* Camera frame container */
        .camera-frame-container {
            position: relative;
            max-width: 500px;
            width: 100%;
            aspect-ratio: 4/3;
        }
        
        /* Camera frame background */
        .camera-frame {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.3);
            border-radius: 30px;
            backdrop-filter: blur(20px);
            overflow: hidden;
            z-index: 1;
        }
        
        /* Camera viewfinder corners */
        .camera-corner {
            position: absolute;
            width: 40px;
            height: 40px;
            border: 3px solid rgba(255, 255, 255, 0.6);
            z-index: 3;
        }
        
        .corner-tl {
            top: 20px;
            left: 20px;
            border-right: none;
            border-bottom: none;
        }
        
        .corner-tr {
            top: 20px;
            right: 20px;
            border-left: none;
            border-bottom: none;
        }
        
        .corner-bl {
            bottom: 20px;
            left: 20px;
            border-right: none;
            border-top: none;
        }
        
        .corner-br {
            bottom: 20px;
            right: 20px;
            border-left: none;
            border-top: none;
        }
        
        /* Camera input positioning */
        .camera-input-container {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 2;
            padding: 20px;
        }
        
        /* Hide Streamlit camera label and border */
        .stCameraInput {
            position: relative;
        }
        
        .stCameraInput > label {
            display: none !important;
        }
        
        .stCameraInput video,
        .stCameraInput img {
            border-radius: 10px !important;
            max-width: 100% !important;
            max-height: 100% !important;
            object-fit: cover !important;
        }
        
        /* File uploader styling */
        .stFileUploader {
            background: transparent !important;
        }
        
        .stFileUploader > div > div {
            background: rgba(255, 255, 255, 0.1) !important;
            border: 2px dashed rgba(255, 255, 255, 0.3) !important;
            border-radius: 20px !important;
            color: white !important;
        }
        
        /* iOS-style camera button */
        .camera-button-wrapper {
            position: absolute;
            bottom: 30px;
            left: 50%;
            transform: translateX(-50%);
            z-index: 10;
        }
        
        .ios-camera-button {
            width: 70px;
            height: 70px;
            border-radius: 50%;
            background: white;
            border: 4px solid rgba(255, 255, 255, 0.3);
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
            position: relative;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        
        .ios-camera-button:hover {
            transform: scale(0.95);
        }
        
        .ios-camera-button:active {
            transform: scale(0.9);
        }
        
        .ios-camera-button::before {
            content: '';
            position: absolute;
            top: 6px;
            left: 6px;
            right: 6px;
            bottom: 6px;
            border-radius: 50%;
            background: white;
            box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        
        /* Button text */
        .button-text {
            color: white;
            text-align: center;
            margin-top: 10px;
            font-size: 14px;
            opacity: 0.8;
        }
        
        /* Mode buttons */
        .stButton > button {
            background: rgba(255, 255, 255, 0.1) !important;
            color: white !important;
            border: 1px solid rgba(255, 255, 255, 0.2) !important;
            font-weight: 600 !important;
            transition: all 0.3s ease !important;
        }
        
        .stButton > button:hover {
            background: rgba(255, 255, 255, 0.2) !important;
        }
        
        /* Processing overlay */
        .processing-overlay {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.8);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 9999;
        }
        
        .processing-content {
            text-align: center;
            color: white;
        }
        
        .processing-spinner {
            width: 60px;
            height: 60px;
            border: 4px solid rgba(255, 255, 255, 0.2);
            border-top-color: white;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto 20px;
        }
        
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        
        /* Mobile responsive */
        @media (max-width: 768px) {
            .camera-wrapper {
                padding: 1rem;
                margin-top: -60px;
            }
            
            .camera-frame-container {
                max-width: 90vw;
            }
            
            .ios-camera-button {
                width: 60px;
                height: 60px;
            }
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Initialize states
    if 'camera_mode' not in st.session_state:
        st.session_state.camera_mode = 'camera'
    if 'photo_taken' not in st.session_state:
        st.session_state.photo_taken = False
    if 'processing' not in st.session_state:
        st.session_state.processing = False
    
    # Back button - floating position
    st.markdown('<div class="back-btn">', unsafe_allow_html=True)
    if st.button("← Back", key="back_btn"):
        st.session_state.photo_taken = False
        st.session_state.processing = False
        st.session_state.current_page = 'landing'
        st.rerun()
    st.markdown('</div>', unsafe_allow_html=True)
    
    # Main camera wrapper
    st.markdown('<div class="camera-wrapper">', unsafe_allow_html=True)
    
    # Mode toggle
    st.markdown('<div class="mode-toggle">', unsafe_allow_html=True)
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        mode_col1, mode_col2 = st.columns(2)
        with mode_col1:
            if st.button("📸 Camera", key="camera_mode_btn", use_container_width=True):
                st.session_state.camera_mode = 'camera'
                st.rerun()
        with mode_col2:
            if st.button("📤 Upload", key="upload_mode_btn", use_container_width=True):
                st.session_state.camera_mode = 'upload'
                st.rerun()
    st.markdown('</div>', unsafe_allow_html=True)
    
    # Camera frame container
    camera_container = st.container()
    
    with camera_container:
        # Create the frame structure
        st.markdown("""
        <div class="camera-frame-container">
            <div class="camera-frame"></div>
            <div class="camera-corner corner-tl"></div>
            <div class="camera-corner corner-tr"></div>
            <div class="camera-corner corner-bl"></div>
            <div class="camera-corner corner-br"></div>
            <div class="camera-input-container">
        """, unsafe_allow_html=True)
        
        # Camera or Upload input inside the frame
        if not st.session_state.photo_taken:
            if st.session_state.camera_mode == 'camera':
                camera_input = st.camera_input("Take a photo", label_visibility="hidden", key="camera_widget")
                if camera_input:
                    st.session_state.photo = camera_input
                    st.session_state.photo_taken = True
                    st.rerun()
            else:
                uploaded = st.file_uploader(
                    "Drop your photo here",
                    type=['jpg', 'jpeg', 'png', 'webp'],
                    key="file_uploader",
                    label_visibility="hidden"
                )
                if uploaded:
                    st.session_state.photo = uploaded
                    st.session_state.photo_taken = True
                    st.rerun()
        else:
            # Show the captured/uploaded photo
            if not st.session_state.processing:
                st.image(st.session_state.photo, use_container_width=True)
        
        st.markdown('</div>', unsafe_allow_html=True)  # Close camera-input-container
        
        # Camera button - positioned at bottom of frame
        if not st.session_state.photo_taken:
            # Waiting state
            st.markdown("""
            <div class="camera-button-wrapper">
                <div class="ios-camera-button"></div>
                <div class="button-text">Waiting for photo...</div>
            </div>
            """, unsafe_allow_html=True)
        elif not st.session_state.processing:
            # Photo taken - show analyze button
            if st.button("", key="hidden_analyze_btn"):
                st.session_state.processing = True
                st.rerun()
            
            st.markdown("""
            <div class="camera-button-wrapper" onclick="document.querySelector('[data-testid=\\"hidden_analyze_btn\\"]').click()">
                <div class="ios-camera-button"></div>
                <div class="button-text">Tap to analyze</div>
            </div>
            """, unsafe_allow_html=True)
        
        st.markdown('</div>', unsafe_allow_html=True)  # Close camera-frame-container
    
    # Retake button - outside frame when photo is taken
    if st.session_state.photo_taken and not st.session_state.processing:
        st.markdown("<br>", unsafe_allow_html=True)
        col1, col2, col3 = st.columns([1, 2, 1])
        with col2:
            if st.button("↻ Retake Photo", key="retake_btn", use_container_width=True):
                st.session_state.photo_taken = False
                st.session_state.photo = None
                st.rerun()
    
    st.markdown('</div>', unsafe_allow_html=True)  # Close camera-wrapper
    
    # Process photo if needed
    if st.session_state.processing:
        process_photo()

def process_photo():
    """Process the photo and redirect to results"""
    # Show processing overlay
    st.markdown("""
    <div class="processing-overlay">
        <div class="processing-content">
            <div class="processing-spinner"></div>
            <h2 style="color: white; margin-bottom: 10px;">Analyzing your ingredients...</h2>
            <p style="color: rgba(255, 255, 255, 0.8);">This magic takes just a moment ✨</p>
        </div>
    </div>
    """, unsafe_allow_html=True)
    
    # Simulate processing time
    time.sleep(2)
    
    try:
        # Process the image
        photo_bytes = st.session_state.photo.getvalue() if hasattr(st.session_state.photo, 'getvalue') else st.session_state.photo.read()
        
        # Optimize image
        img = Image.open(io.BytesIO(photo_bytes))
        max_size = (1920, 1920)
        if img.size[0] > max_size[0] or img.size[1] > max_size[1]:
            img.thumbnail(max_size, Image.Resampling.LANCZOS)
            img_byte_arr = io.BytesIO()
            img.save(img_byte_arr, format=img.format or 'JPEG', quality=85)
            photo_bytes = img_byte_arr.getvalue()
        
        # Encode and detect ingredients
        photo_base64 = encode_image_to_base64(photo_bytes)
        ingredients = detect_ingredients(photo_base64)
        
        # Generate recipes
        recipes = generate_meals(ingredients, st.session_state.get('dietary_preferences', []))
        
        # Store results
        st.session_state.detected_ingredients = ingredients
        st.session_state.generated_recipes = recipes
        st.session_state.processing_complete = True
        
        # Update stats
        update_streak()
        add_points(10, "Generated recipes")
        
        # Navigate to results page
        st.session_state.current_page = 'results'
        st.rerun()
        
    except Exception as e:
        st.error(f"Oops! Something went wrong: {str(e)}")
        st.session_state.processing = False
        if st.button("Try Again"):
            st.session_state.photo_taken = False
            st.session_state.photo = None
            st.rerun()