import streamlit as st
from streamlit_extras.let_it_rain import rain
import time
from PIL import Image
import io
from utils.api import encode_image_to_base64, detect_ingredients, generate_meals
from utils.session import update_streak, add_points

def show_camera():
    # CSS to fix layout issues
    st.markdown("""
        <style>
        /* Import font */
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        /* Full page gradient background */
        .stApp {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        
        /* CRITICAL: Remove ALL padding and margins */
        .main > div:first-child {
            padding-top: 0 !important;
        }
        
        .main .block-container {
            padding: 0 !important;
            max-width: 100% !important;
        }
        
        /* Hide all default Streamlit elements */
        #MainMenu {visibility: hidden;}
        header {visibility: hidden;}
        footer {visibility: hidden;}
        
        /* Fix the weird spacing issue */
        .main > div > div > div {
            gap: 0 !important;
        }
        
        /* Full viewport container */
        .camera-page {
            min-height: 100vh;
            width: 100vw;
            position: relative;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 2rem;
            box-sizing: border-box;
        }
        
        /* Back button - absolute positioning */
        .back-button {
            position: absolute;
            top: 20px;
            left: 20px;
            background: rgba(255, 255, 255, 0.2);
            border: 2px solid rgba(255, 255, 255, 0.3);
            color: white;
            padding: 0.5rem 1.5rem;
            border-radius: 50px;
            font-weight: 600;
            backdrop-filter: blur(10px);
            cursor: pointer;
            text-decoration: none;
            transition: all 0.3s ease;
            z-index: 100;
        }
        
        .back-button:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-1px);
        }
        
        /* Mode toggle */
        .mode-selector {
            margin-bottom: 2rem;
            display: flex;
            gap: 1rem;
        }
        
        .mode-btn {
            background: rgba(255, 255, 255, 0.1);
            color: white;
            padding: 0.75rem 1.5rem;
            border-radius: 50px;
            border: 1px solid rgba(255, 255, 255, 0.2);
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .mode-btn.active {
            background: rgba(255, 255, 255, 0.2);
        }
        
        /* Camera frame */
        .camera-container {
            position: relative;
            width: 100%;
            max-width: 500px;
            aspect-ratio: 4/3;
        }
        
        .camera-frame {
            position: absolute;
            inset: 0;
            background: rgba(0, 0, 0, 0.3);
            border-radius: 30px;
            backdrop-filter: blur(20px);
            overflow: hidden;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        /* Viewfinder corners */
        .corner {
            position: absolute;
            width: 40px;
            height: 40px;
            border: 3px solid rgba(255, 255, 255, 0.6);
            pointer-events: none;
            z-index: 5;
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
        
        /* Camera content */
        .camera-content {
            position: relative;
            width: 100%;
            height: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        /* Hide Streamlit elements */
        .stCameraInput > label {
            display: none !important;
        }
        
        .stCameraInput video,
        .stCameraInput img,
        .stImage img {
            max-width: 100% !important;
            max-height: 100% !important;
            object-fit: contain !important;
            border-radius: 10px !important;
        }
        
        /* iOS Camera Button */
        .capture-button {
            position: absolute;
            bottom: 30px;
            left: 50%;
            transform: translateX(-50%);
            width: 70px;
            height: 70px;
            background: white;
            border-radius: 50%;
            border: 4px solid rgba(255, 255, 255, 0.3);
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
            cursor: pointer;
            transition: all 0.2s ease;
            z-index: 10;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .capture-button::before {
            content: '';
            width: 58px;
            height: 58px;
            background: white;
            border-radius: 50%;
            box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        
        .capture-button:hover {
            transform: translateX(-50%) scale(0.95);
        }
        
        .capture-button:active {
            transform: translateX(-50%) scale(0.9);
        }
        
        .button-label {
            position: absolute;
            bottom: -25px;
            left: 50%;
            transform: translateX(-50%);
            color: white;
            font-size: 14px;
            white-space: nowrap;
            opacity: 0.8;
        }
        
        /* Retake button */
        .retake-container {
            margin-top: 2rem;
        }
        
        /* Override Streamlit button styles */
        .stButton > button {
            background: rgba(255, 255, 255, 0.1) !important;
            color: white !important;
            border: 1px solid rgba(255, 255, 255, 0.2) !important;
            font-weight: 600 !important;
            padding: 0.75rem 2rem !important;
            border-radius: 50px !important;
        }
        
        .stButton > button:hover {
            background: rgba(255, 255, 255, 0.2) !important;
        }
        
        /* File uploader */
        .stFileUploader > div > div {
            background: rgba(255, 255, 255, 0.1) !important;
            border: 2px dashed rgba(255, 255, 255, 0.3) !important;
            color: white !important;
        }
        
        /* Processing overlay */
        .processing-overlay {
            position: fixed;
            inset: 0;
            background: rgba(0, 0, 0, 0.8);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 9999;
        }
        
        @media (max-width: 768px) {
            .camera-page {
                padding: 1rem;
            }
            
            .camera-container {
                max-width: 90vw;
            }
            
            .capture-button {
                width: 60px;
                height: 60px;
            }
            
            .capture-button::before {
                width: 48px;
                height: 48px;
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
    
    # Main container
    st.markdown('<div class="camera-page">', unsafe_allow_html=True)
    
    # Back button
    st.markdown("""
        <a href="#" class="back-button" onclick="window.parent.postMessage({type: 'streamlit:setComponentValue', key: 'back_clicked', value: true}, '*'); return false;">
            ← Back
        </a>
    """, unsafe_allow_html=True)
    
    # Back button handler
    back_placeholder = st.empty()
    if back_placeholder.button("←", key="hidden_back_btn"):
        st.session_state.photo_taken = False
        st.session_state.processing = False
        st.session_state.current_page = 'landing'
        st.rerun()
    
    # Mode selector
    mode_container = st.container()
    with mode_container:
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
    
    # Camera container
    camera_col1, camera_col2, camera_col3 = st.columns([1, 3, 1])
    
    with camera_col2:
        # Frame HTML
        st.markdown("""
            <div class="camera-container">
                <div class="camera-frame">
                    <div class="corner corner-tl"></div>
                    <div class="corner corner-tr"></div>
                    <div class="corner corner-bl"></div>
                    <div class="corner corner-br"></div>
                    <div class="camera-content" id="camera-content">
        """, unsafe_allow_html=True)
        
        # Camera/Upload input
        if not st.session_state.photo_taken:
            if st.session_state.camera_mode == 'camera':
                photo = st.camera_input("Take a photo", label_visibility="hidden", key="camera_widget")
                if photo:
                    st.session_state.photo = photo
                    st.session_state.photo_taken = True
                    st.rerun()
            else:
                uploaded = st.file_uploader(
                    "Drop your photo here",
                    type=['jpg', 'jpeg', 'png', 'webp'],
                    label_visibility="hidden",
                    key="file_uploader"
                )
                if uploaded:
                    st.session_state.photo = uploaded
                    st.session_state.photo_taken = True
                    st.rerun()
        else:
            # Show the photo
            if not st.session_state.processing:
                st.image(st.session_state.photo, use_container_width=True)
        
        # Close camera content div
        st.markdown('</div>', unsafe_allow_html=True)
        
        # Camera button
        if not st.session_state.photo_taken:
            st.markdown("""
                <div class="capture-button">
                    <span class="button-label">Waiting...</span>
                </div>
            """, unsafe_allow_html=True)
        elif not st.session_state.processing:
            # Hidden button for click handling
            if st.button("", key="analyze_btn"):
                st.session_state.processing = True
                st.rerun()
            
            st.markdown("""
                <div class="capture-button" onclick="document.querySelector('[data-testid=\\"analyze_btn\\"]').click();">
                    <span class="button-label">Tap to analyze</span>
                </div>
            """, unsafe_allow_html=True)
        
        # Close camera frame and container
        st.markdown("""
                </div>
            </div>
        """, unsafe_allow_html=True)
        
        # Retake button
        if st.session_state.photo_taken and not st.session_state.processing:
            st.markdown('<div class="retake-container">', unsafe_allow_html=True)
            if st.button("↻ Retake Photo", key="retake", use_container_width=True):
                st.session_state.photo_taken = False
                st.session_state.photo = None
                st.rerun()
            st.markdown('</div>', unsafe_allow_html=True)
    
    # Close main container
    st.markdown('</div>', unsafe_allow_html=True)
    
    # Process if needed
    if st.session_state.processing:
        process_photo()

def process_photo():
    """Process the photo and redirect to results"""
    # Show processing overlay
    st.markdown("""
    <div class="processing-overlay">
        <div style="text-align: center; color: white;">
            <div style="width: 60px; height: 60px; border: 4px solid rgba(255,255,255,0.2); 
                        border-top-color: white; border-radius: 50%; margin: 0 auto 20px;
                        animation: spin 1s linear infinite;"></div>
            <h2>Analyzing your ingredients...</h2>
            <p style="opacity: 0.8;">This magic takes just a moment ✨</p>
        </div>
    </div>
    <style>
    @keyframes spin {
        to { transform: rotate(360deg); }
    }
    </style>
    """, unsafe_allow_html=True)
    
    time.sleep(2)
    
    try:
        # Process image
        photo_bytes = st.session_state.photo.getvalue() if hasattr(st.session_state.photo, 'getvalue') else st.session_state.photo.read()
        
        # Optimize
        img = Image.open(io.BytesIO(photo_bytes))
        max_size = (1920, 1920)
        if img.size[0] > max_size[0] or img.size[1] > max_size[1]:
            img.thumbnail(max_size, Image.Resampling.LANCZOS)
            img_byte_arr = io.BytesIO()
            img.save(img_byte_arr, format=img.format or 'JPEG', quality=85)
            photo_bytes = img_byte_arr.getvalue()
        
        # API calls
        photo_base64 = encode_image_to_base64(photo_bytes)
        ingredients = detect_ingredients(photo_base64)
        recipes = generate_meals(ingredients, st.session_state.get('dietary_preferences', []))
        
        # Store results
        st.session_state.detected_ingredients = ingredients
        st.session_state.generated_recipes = recipes
        st.session_state.processing_complete = True
        
        # Update stats
        update_streak()
        add_points(10, "Generated recipes")
        
        # Navigate to results
        st.session_state.current_page = 'results'
        st.rerun()
        
    except Exception as e:
        st.error(f"Oops! Something went wrong: {str(e)}")
        st.session_state.processing = False
        if st.button("Try Again"):
            st.session_state.photo_taken = False
            st.session_state.photo = None
            st.rerun()