import streamlit as st
from streamlit_extras.let_it_rain import rain
import time
from PIL import Image
import io
from utils.api import encode_image_to_base64, detect_ingredients, generate_meals
from utils.session import update_streak, add_points

def show_camera():
    # Apply full-page gradient and remove padding
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        /* Full gradient background */
        .stApp {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        
        /* Remove ALL padding - this is the key */
        .main .block-container {
            padding-top: 0 !important;
            padding-bottom: 0 !important;
            padding-left: 1rem !important;
            padding-right: 1rem !important;
            max-width: 100% !important;
        }
        
        /* Remove the top space */
        .stApp > header {
            display: none !important;
        }
        
        /* Hide hamburger menu */
        .stApp [data-testid="stToolbar"] {
            display: none !important;
        }
        
        /* Full height for main content */
        .main {
            padding: 0 !important;
        }
        
        /* Back button */
        .back-btn {
            position: fixed;
            top: 20px;
            left: 20px;
            z-index: 999;
            background: rgba(255, 255, 255, 0.2);
            border: 2px solid rgba(255, 255, 255, 0.3);
            color: white;
            padding: 0.5rem 1.5rem;
            border-radius: 50px;
            font-weight: 600;
            backdrop-filter: blur(10px);
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .back-btn:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-1px);
        }
        
        /* Main container */
        .camera-page-container {
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 2rem 0;
        }
        
        /* Mode buttons */
        .stButton > button {
            background: rgba(255, 255, 255, 0.1) !important;
            color: white !important;
            border: 1px solid rgba(255, 255, 255, 0.2) !important;
            font-weight: 600 !important;
            border-radius: 50px !important;
            padding: 0.75rem 1.5rem !important;
            transition: all 0.3s ease !important;
        }
        
        .stButton > button:hover {
            background: rgba(255, 255, 255, 0.2) !important;
            transform: translateY(-1px) !important;
        }
        
        /* Camera frame styling */
        .camera-frame-wrapper {
            position: relative;
            width: 100%;
            max-width: 500px;
            margin: 2rem auto;
        }
        
        .camera-frame {
            background: rgba(0, 0, 0, 0.3);
            border-radius: 30px;
            padding: 20px;
            backdrop-filter: blur(20px);
            position: relative;
            aspect-ratio: 4/3;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
        }
        
        /* Viewfinder corners */
        .corner {
            position: absolute;
            width: 40px;
            height: 40px;
            border: 3px solid rgba(255, 255, 255, 0.6);
            pointer-events: none;
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
        
        /* Camera widget styling */
        .stCameraInput {
            margin: 0 !important;
        }
        
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
        
        /* File uploader */
        .stFileUploader {
            margin: 0 !important;
        }
        
        .stFileUploader label {
            display: none !important;
        }
        
        .stFileUploader > div > div {
            background: rgba(255, 255, 255, 0.1) !important;
            border: 2px dashed rgba(255, 255, 255, 0.3) !important;
            color: white !important;
            border-radius: 20px !important;
        }
        
        /* iOS Camera Button */
        .ios-button-container {
            position: absolute;
            bottom: -40px;
            left: 50%;
            transform: translateX(-50%);
            z-index: 10;
        }
        
        .ios-camera-btn {
            width: 70px;
            height: 70px;
            background: white;
            border-radius: 50%;
            border: 4px solid rgba(255, 255, 255, 0.3);
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
            cursor: pointer;
            position: relative;
            transition: all 0.2s ease;
        }
        
        .ios-camera-btn::before {
            content: '';
            position: absolute;
            top: 6px;
            left: 6px;
            right: 6px;
            bottom: 6px;
            background: white;
            border-radius: 50%;
            box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        
        .ios-camera-btn:hover {
            transform: scale(0.95);
        }
        
        .ios-camera-btn:active {
            transform: scale(0.9);
        }
        
        .btn-label {
            position: absolute;
            bottom: -25px;
            left: 50%;
            transform: translateX(-50%);
            color: white;
            font-size: 14px;
            white-space: nowrap;
            opacity: 0.8;
            text-align: center;
        }
        
        /* Processing overlay */
        .processing {
            position: fixed;
            inset: 0;
            background: rgba(0, 0, 0, 0.8);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 9999;
        }
        
        @media (max-width: 768px) {
            .camera-frame-wrapper {
                max-width: 90vw;
            }
            
            .ios-camera-btn {
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
    
    # Back button HTML
    st.markdown("""
        <a href="#" class="back-btn" onclick="document.querySelector('[data-testid=\\"back_button\\"]').click(); return false;">
            ← Back
        </a>
    """, unsafe_allow_html=True)
    
    # Hidden back button for functionality
    if st.button("", key="back_button", type="secondary"):
        st.session_state.photo_taken = False
        st.session_state.processing = False
        st.session_state.current_page = 'landing'
        st.rerun()
    
    # Add spacing from top
    st.markdown("<div style='height: 80px;'></div>", unsafe_allow_html=True)
    
    # Mode selector
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        mode_col1, mode_col2 = st.columns(2)
        with mode_col1:
            if st.button("📸 Camera", key="cam_btn", use_container_width=True):
                st.session_state.camera_mode = 'camera'
                st.rerun()
        with mode_col2:
            if st.button("📤 Upload", key="upl_btn", use_container_width=True):
                st.session_state.camera_mode = 'upload'
                st.rerun()
    
    # Camera container with frame
    col1, col2, col3 = st.columns([1, 3, 1])
    
    with col2:
        # Create container for camera frame
        camera_container = st.container()
        
        with camera_container:
            # Add frame HTML before camera widget
            st.markdown("""
                <div class="camera-frame-wrapper">
                    <div class="camera-frame">
                        <div class="corner corner-tl"></div>
                        <div class="corner corner-tr"></div>
                        <div class="corner corner-bl"></div>
                        <div class="corner corner-br"></div>
            """, unsafe_allow_html=True)
            
            # Camera/Upload widget goes here - it will be rendered inside the frame
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
                
                # Waiting state button
                st.markdown("""
                        <div class="ios-button-container">
                            <div class="ios-camera-btn">
                                <div class="btn-label">Waiting...</div>
                            </div>
                        </div>
                    </div>
                </div>
                """, unsafe_allow_html=True)
            else:
                # Show the photo
                if not st.session_state.processing:
                    st.image(st.session_state.photo, use_container_width=True)
                    
                    # Analyze button
                    st.markdown("""
                        <div class="ios-button-container" onclick="document.querySelector('[data-testid=\\"analyze_button\\"]').click();">
                            <div class="ios-camera-btn">
                                <div class="btn-label">Tap to analyze</div>
                            </div>
                        </div>
                    </div>
                </div>
                """, unsafe_allow_html=True)
                    
                    # Hidden analyze button
                    if st.button("", key="analyze_button"):
                        st.session_state.processing = True
                        st.rerun()
        
        # Retake button outside frame
        if st.session_state.photo_taken and not st.session_state.processing:
            st.markdown("<br><br><br>", unsafe_allow_html=True)
            if st.button("↻ Retake Photo", key="retake", use_container_width=True):
                st.session_state.photo_taken = False
                st.session_state.photo = None
                st.rerun()
    
    # Process if needed
    if st.session_state.processing:
        process_photo()

def process_photo():
    """Process the photo and redirect to results"""
    # Processing overlay
    st.markdown("""
    <div class="processing">
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