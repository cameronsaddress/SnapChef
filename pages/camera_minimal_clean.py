import streamlit as st
from streamlit_extras.let_it_rain import rain
import time
from PIL import Image
import io
from utils.api import encode_image_to_base64, analyze_fridge_and_generate_recipes
from utils.session import update_streak, add_points
from prompts import get_random_progress_message

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
        
        /* Camera/File uploader container - responsive */
        .stCameraInput, .stFileUploader {
            margin: 2rem auto;
            max-width: 90vw;
            width: 100%;
        }
        
        /* Mobile responsive adjustments */
        @media (max-width: 768px) {
            .stCameraInput, .stFileUploader {
                margin: 1rem auto;
                max-width: 95vw;
            }
            
            .main .block-container {
                padding-top: 1rem !important;
                padding-left: 1rem !important;
                padding-right: 1rem !important;
                max-width: 100% !important;
            }
            
            .camera-header {
                font-size: 2rem;
                margin-bottom: 1rem;
            }
        }
        
        /* Hide default camera label */
        .stCameraInput > label {
            display: none !important;
        }
        
        /* Camera container styling */
        .stCameraInput > div {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
        }
        
        /* Round camera preview - responsive sizing */
        .stCameraInput video {
            border-radius: 20px !important;
            overflow: hidden !important;
            width: 100% !important;
            max-width: 90vw !important;
            height: auto !important;
            aspect-ratio: 4/3;
            object-fit: cover;
        }
        
        .stCameraInput img {
            border-radius: 20px !important;
            overflow: hidden !important;
            width: 100% !important;
            max-width: 90vw !important;
            height: auto !important;
        }
        
        /* Mobile camera adjustments */
        @media (max-width: 768px) {
            .stCameraInput video,
            .stCameraInput img {
                border-radius: 16px !important;
                max-width: 95vw !important;
                aspect-ratio: 3/4; /* Portrait orientation for mobile */
            }
        }
        
        /* Style the camera button container */
        .stCameraInput > div > div:last-child {
            width: 100%;
            display: flex;
            justify-content: center;
            margin-top: 1rem;
        }
        
        /* Page header */
        .camera-header {
            font-size: 3rem;
            font-weight: 800;
            text-align: center;
            margin-bottom: 2rem;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            letter-spacing: -0.02em;
            color: white;
            text-decoration: none !important;
        }
        
        /* Remove any link styling */
        h1.camera-header a {
            text-decoration: none !important;
            color: white !important;
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
        
        /* Floating emojis */
        @keyframes float {
            0% { transform: translateY(0px) rotate(0deg); opacity: 0.1; }
            50% { transform: translateY(-20px) rotate(180deg); opacity: 0.15; }
            100% { transform: translateY(0px) rotate(360deg); opacity: 0.1; }
        }
        
        .floating-emoji {
            position: fixed;
            animation: float 6s ease-in-out infinite;
            pointer-events: none;
            z-index: 0;
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Add floating food emojis
    st.markdown("""
    <div class="floating-emoji" style="top: 10%; left: 5%; font-size: 80px; animation-delay: 0s;">🍳</div>
    <div class="floating-emoji" style="top: 20%; right: 10%; font-size: 60px; animation-delay: 2s;">🥗</div>
    <div class="floating-emoji" style="bottom: 30%; left: 15%; font-size: 70px; animation-delay: 4s;">🍝</div>
    <div class="floating-emoji" style="bottom: 20%; right: 5%; font-size: 90px; animation-delay: 1s;">🥘</div>
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
    
    # Add styled header
    st.markdown('<h1 class="camera-header">Take a photo of your fridge</h1>', unsafe_allow_html=True)
    
    # Process photo if taken - show progress above camera
    if st.session_state.processing:
        process_photo_with_progress()
    else:
        # Camera input without label - with back camera preference
        # Note: Streamlit doesn't directly support camera selection,
        # but we can add a data attribute that some browsers may respect
        photo = st.camera_input("", 
                               label_visibility="hidden",
                               key="camera_input",
                               help="Take a photo of your fridge or pantry")
        
        # Add JavaScript to try to use back camera (environment facing)
        st.markdown("""
        <script>
        // Try to use back camera on mobile devices
        document.addEventListener('DOMContentLoaded', function() {
            const videoElements = document.querySelectorAll('video');
            videoElements.forEach(video => {
                if (video && video.srcObject) {
                    const tracks = video.srcObject.getTracks();
                    tracks.forEach(track => {
                        const constraints = track.getConstraints();
                        // Try to set facingMode to environment (back camera)
                        if (track.kind === 'video') {
                            track.applyConstraints({
                                facingMode: { ideal: 'environment' }
                            }).catch(e => console.log('Could not apply camera constraints:', e));
                        }
                    });
                }
            });
        });
        </script>
        """, unsafe_allow_html=True)
        
        if photo and not st.session_state.photo_taken:
            st.session_state.photo = photo
            st.session_state.photo_taken = True
            st.session_state.processing = True
            st.rerun()

def process_photo_with_progress():
    """Process photo with progress bar"""
    
    # Style for progress container
    st.markdown("""
        <style>
        /* Processing container above camera - responsive */
        .processing-container {
            background: rgba(0, 0, 0, 0.2);
            backdrop-filter: blur(10px);
            padding: 1.5rem;
            border-radius: 20px;
            text-align: center;
            max-width: 90vw;
            margin: 0 auto 2rem auto;
        }
        
        @media (max-width: 768px) {
            .processing-container {
                padding: 1rem;
                margin: 0 auto 1rem auto;
                max-width: 95vw;
            }
        }
        
        /* Style progress bar */
        .stProgress {
            max-width: 400px;
            margin: 0 auto;
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Create processing container above camera
    with st.container():
        st.markdown('<div class="processing-container">', unsafe_allow_html=True)
        
        # Progress bar and status
        progress_bar = st.progress(0)
        status_placeholder = st.empty()
        
        st.markdown('</div>', unsafe_allow_html=True)
    
    # Show the camera preview with the captured image in a container matching camera size
    if hasattr(st.session_state, 'photo') and st.session_state.photo:
        # Add styling for the captured image
        st.markdown("""
            <style>
            /* Container to match camera size - responsive */
            .image-container {
                max-width: 90vw;
                width: 100%;
                margin: 0 auto;
            }
            
            /* Round the captured image */
            .image-container .stImage > img {
                border-radius: 20px !important;
                width: 100%;
                height: auto;
                max-width: 90vw;
            }
            
            /* Mobile adjustments for captured image */
            @media (max-width: 768px) {
                .image-container {
                    max-width: 95vw;
                }
                
                .image-container .stImage > img {
                    border-radius: 16px !important;
                    max-width: 95vw;
                }
            }
            </style>
        """, unsafe_allow_html=True)
        
        # Create responsive container for captured image
        st.markdown('<div class="image-container">', unsafe_allow_html=True)
        st.image(st.session_state.photo, use_container_width=True)
        st.markdown('</div>', unsafe_allow_html=True)
    
    try:
        # Progress messages array
        messages = [
            ("📸 Analyzing your fridge with AI superpowers...", 10),
            (get_random_progress_message(), 20),
            ("🔍 Detecting ingredients...", 30),
            (get_random_progress_message(), 40),
            ("🤖 Oh man, this is going to be good!", 50),
            (get_random_progress_message(), 60),
            ("👨‍🍳 Consulting with virtual Gordon Ramsay...", 70),
            (get_random_progress_message(), 80),
            ("✨ Adding a pinch of culinary magic...", 90),
            ("🎉 Your personalized recipes are ready!", 100)
        ]
        
        # Show initial message
        status_placeholder.markdown(f'<p class="status-text" style="color: white; font-size: 1.2rem; margin-top: 1rem;">{messages[0][0]}</p>', unsafe_allow_html=True)
        progress_bar.progress(messages[0][1])
        time.sleep(0.8)
        
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
        
        # Show second message
        status_placeholder.markdown(f'<p class="status-text" style="color: white; font-size: 1.2rem; margin-top: 1rem;">{messages[1][0]}</p>', unsafe_allow_html=True)
        progress_bar.progress(messages[1][1])
        time.sleep(0.8)
        
        # Encode image
        photo_base64 = encode_image_to_base64(photo_bytes)
        
        # Show detecting message
        status_placeholder.markdown(f'<p class="status-text" style="color: white; font-size: 1.2rem; margin-top: 1rem;">{messages[2][0]}</p>', unsafe_allow_html=True)
        progress_bar.progress(messages[2][1])
        time.sleep(0.5)
        
        # Make single API call for ingredients and recipes
        status_placeholder.markdown(f'<p class="status-text" style="color: white; font-size: 1.2rem; margin-top: 1rem;">🤖 Analyzing your fridge and creating personalized recipes...</p>', unsafe_allow_html=True)
        progress_bar.progress(20)
        
        # Single API call
        result = analyze_fridge_and_generate_recipes(
            photo_base64, 
            st.session_state.get('dietary_preferences', [])
        )
        
        # Check if analysis was successful
        if 'error' in result or (len(result.get('ingredients', [])) == 0 and len(result.get('recipes', [])) == 0):
            # Stop progress bar and show error
            progress_bar.progress(30)
            
            error_msg = result.get('error', 'No ingredients found in the image.')
            status_placeholder.markdown(f'<p class="status-text" style="color: #ff6b6b; font-size: 1.2rem; margin-top: 1rem;">❌ {error_msg}</p>', unsafe_allow_html=True)
            
            # Wait a moment for user to read the error
            time.sleep(2)
            
            # Clear progress bar and status
            progress_bar.empty()
            status_placeholder.empty()
            
            # Show error in standard Streamlit error box
            st.error(f"❌ {error_msg}")
            
            # Add helpful tips
            if "No food ingredients detected" in error_msg:
                st.info("💡 Tips for better results:\n"
                       "- Make sure the photo shows the inside of your fridge or pantry\n"
                       "- Ensure good lighting and clear visibility of items\n"
                       "- Try to capture multiple ingredients in one shot")
            
            # Add retry button
            col1, col2, col3 = st.columns([1, 2, 1])
            with col2:
                if st.button("📸 Take Another Photo", use_container_width=True, key="retry_photo"):
                    st.session_state.photo_taken = False
                    st.session_state.processing = False
                    st.session_state.photo = None
                    st.rerun()
            return
        
        # Extract data from result
        ingredients = result.get('ingredients', [])
        recipes = result.get('recipes', [])
        
        # Show progress messages
        for i in range(3, 8):
            status_placeholder.markdown(f'<p class="status-text" style="color: white; font-size: 1.2rem; margin-top: 1rem;">{messages[i][0]}</p>', unsafe_allow_html=True)
            progress_bar.progress(messages[i][1])
            time.sleep(0.6)
        
        # Show final messages
        for i in range(7, 10):
            status_placeholder.markdown(f'<p class="status-text" style="color: white; font-size: 1.2rem; margin-top: 1rem;">{messages[i][0]}</p>', unsafe_allow_html=True)
            progress_bar.progress(messages[i][1])
            time.sleep(0.6)
        
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
        # Stop and clear the progress bar
        progress_bar.empty()
        status_placeholder.empty()
        
        # Show detailed error message
        error_message = str(e)
        if "API" in error_message or "api_key" in error_message:
            st.error("❌ API Error: Please check your API key configuration.")
        elif "connection" in error_message.lower() or "network" in error_message.lower():
            st.error("❌ Network Error: Please check your internet connection.")
        else:
            st.error(f"❌ Oops! Something went wrong: {error_message}")
        
        # Add helpful message
        st.info("💡 Tip: Make sure you have a stable internet connection and your API key is properly configured.")
        
        # Retry button
        col1, col2, col3 = st.columns([1, 2, 1])
        with col2:
            if st.button("🔄 Try Again", use_container_width=True):
                st.session_state.photo_taken = False
                st.session_state.processing = False
                st.session_state.photo = None
                st.rerun()