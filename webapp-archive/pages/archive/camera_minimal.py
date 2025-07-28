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
        
        /* Remove default padding */
        .main > div {
            padding-top: 1rem;
        }
        
        /* Back button styling */
        .back-button {
            background: rgba(255, 255, 255, 0.2);
            border: 2px solid rgba(255, 255, 255, 0.3);
            color: white;
            padding: 0.5rem 1.5rem;
            border-radius: 50px;
            font-weight: 600;
            backdrop-filter: blur(10px);
            transition: all 0.3s ease;
        }
        
        .back-button:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-1px);
        }
        
        /* Camera frame container */
        .camera-container {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 80vh;
            padding: 2rem;
        }
        
        /* Camera frame */
        .camera-frame {
            background: rgba(0, 0, 0, 0.3);
            border-radius: 30px;
            padding: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            backdrop-filter: blur(20px);
            max-width: 500px;
            width: 100%;
            aspect-ratio: 4/3;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
            overflow: hidden;
        }
        
        /* Camera viewfinder corners */
        .camera-frame::before,
        .camera-frame::after {
            content: '';
            position: absolute;
            width: 40px;
            height: 40px;
            border: 3px solid rgba(255, 255, 255, 0.5);
        }
        
        .camera-frame::before {
            top: 20px;
            left: 20px;
            border-right: none;
            border-bottom: none;
        }
        
        .camera-frame::after {
            bottom: 20px;
            right: 20px;
            border-left: none;
            border-top: none;
        }
        
        /* Additional corners */
        .corner-tl {
            position: absolute;
            top: 20px;
            right: 20px;
            width: 40px;
            height: 40px;
            border: 3px solid rgba(255, 255, 255, 0.5);
            border-left: none;
            border-bottom: none;
        }
        
        .corner-bl {
            position: absolute;
            bottom: 20px;
            left: 20px;
            width: 40px;
            height: 40px;
            border: 3px solid rgba(255, 255, 255, 0.5);
            border-right: none;
            border-top: none;
        }
        
        /* iOS-style camera button */
        .camera-button-container {
            margin-top: 40px;
            display: flex;
            justify-content: center;
        }
        
        .ios-camera-button {
            width: 80px;
            height: 80px;
            border-radius: 50%;
            background: white;
            border: 4px solid rgba(255, 255, 255, 0.3);
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
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
        
        /* Camera/Upload toggle */
        .mode-toggle {
            margin-bottom: 30px;
            display: flex;
            gap: 20px;
            background: rgba(255, 255, 255, 0.1);
            padding: 8px;
            border-radius: 100px;
            backdrop-filter: blur(10px);
        }
        
        .mode-button {
            padding: 12px 24px;
            border-radius: 100px;
            background: transparent;
            color: white;
            border: none;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .mode-button.active {
            background: rgba(255, 255, 255, 0.2);
        }
        
        /* Hide Streamlit defaults */
        .stCameraInput > label {
            display: none !important;
        }
        
        .stCameraInput > div {
            background: transparent !important;
            border: none !important;
        }
        
        .stFileUploader {
            background: transparent !important;
        }
        
        .stFileUploader > div > div {
            background: rgba(255, 255, 255, 0.1) !important;
            border: 2px dashed rgba(255, 255, 255, 0.3) !important;
            border-radius: 20px !important;
        }
        
        /* Status text */
        .status-text {
            color: white;
            font-size: 18px;
            font-weight: 600;
            text-align: center;
            margin: 20px 0;
        }
        
        /* Button overrides for Streamlit */
        .stButton > button {
            background: transparent !important;
            border: none !important;
            padding: 0 !important;
            height: auto !important;
        }
        
        /* Image preview in frame */
        .camera-frame img {
            max-width: 100%;
            max-height: 100%;
            object-fit: contain;
            border-radius: 10px;
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
            .camera-frame {
                max-width: 90vw;
            }
            
            .ios-camera-button {
                width: 70px;
                height: 70px;
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
    
    # Back button - top left
    col1, col2, col3 = st.columns([1, 10, 1])
    with col1:
        if st.button("← Back", key="back_btn"):
            st.session_state.photo_taken = False
            st.session_state.processing = False
            st.session_state.current_page = 'landing'
            st.rerun()
    
    # Camera container
    st.markdown('<div class="camera-container">', unsafe_allow_html=True)
    
    # Mode toggle (Camera / Upload)
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
    
    # Camera frame with viewfinder corners
    st.markdown("""
    <div class="camera-frame">
        <div class="corner-tl"></div>
        <div class="corner-bl"></div>
    """, unsafe_allow_html=True)
    
    # Camera or Upload input
    if st.session_state.camera_mode == 'camera':
        camera_input = st.camera_input("Take a photo", label_visibility="hidden", key="camera_widget")
        
        if camera_input and not st.session_state.photo_taken:
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
        
        if uploaded and not st.session_state.photo_taken:
            st.session_state.photo = uploaded
            st.session_state.photo_taken = True
            st.rerun()
    
    st.markdown('</div>', unsafe_allow_html=True)
    
    # Show photo if taken
    if st.session_state.photo_taken and not st.session_state.processing:
        # Display the photo in the frame
        col1, col2, col3 = st.columns([1, 2, 1])
        with col2:
            st.image(st.session_state.photo, use_container_width=True)
        
        # iOS-style camera button (now acts as "Use this photo")
        st.markdown('<div class="camera-button-container">', unsafe_allow_html=True)
        
        col1, col2, col3 = st.columns([1, 2, 1])
        with col2:
            button_col1, button_col2, button_col3 = st.columns([1, 2, 1])
            with button_col2:
                if st.button("", key="use_photo_btn"):
                    st.session_state.processing = True
                    st.rerun()
        
        # Add the visual button
        st.markdown("""
        <div style="text-align: center; margin-top: -60px;">
            <div class="ios-camera-button" onclick="document.querySelector('[data-testid=\\"use_photo_btn\\"]').click()"></div>
            <p style="color: white; margin-top: 15px; font-size: 16px; opacity: 0.8;">Tap to analyze</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.markdown('</div>', unsafe_allow_html=True)
        
        # Retake button
        col1, col2, col3 = st.columns([1, 2, 1])
        with col2:
            if st.button("↻ Retake", key="retake_btn", use_container_width=True):
                st.session_state.photo_taken = False
                st.session_state.photo = None
                st.rerun()
    
    elif not st.session_state.processing:
        # Show capture button when no photo taken
        st.markdown('<div class="camera-button-container">', unsafe_allow_html=True)
        st.markdown("""
        <div style="text-align: center;">
            <div class="ios-camera-button"></div>
            <p style="color: white; margin-top: 15px; font-size: 16px; opacity: 0.8;">Waiting for photo...</p>
        </div>
        """, unsafe_allow_html=True)
        st.markdown('</div>', unsafe_allow_html=True)
    
    st.markdown('</div>', unsafe_allow_html=True)
    
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